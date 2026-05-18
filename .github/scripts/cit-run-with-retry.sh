#!/usr/bin/env bash
# Run Google's cloud-image-tests inside a container, retrying in a different
# GCP zone if the failure is a recoverable zone-capacity or
# shape-availability error. Real test failures and other errors exit
# immediately without retry.
#
# Inputs are passed via environment variables (set by the composite action
# at .github/actions/cit-run-with-retry/action.yml):
#
#   RUNTIME              docker | podman
#   PROJECT              GCP project ID
#   IMAGE                cloud-image-tests -images value
#   FILTER               cloud-image-tests -filter regex
#   SHAPE_FLAG           full flag string, e.g. "-x86_shape c4-standard-8"
#                        (intentionally word-split into two args below)
#   PARALLEL_COUNT       optional; empty -> flag omitted
#   PARALLEL_STAGGER     optional; empty -> flag omitted
#   FIRST_ATTEMPT_ZONE   optional; empty -> first attempt omits -zone
#   ZONES                space-separated fallback list
#   MAX_ATTEMPTS         hard cap on attempts
#   RETRY_DELAY_SECONDS  fixed delay between attempts
#   CREDS_PATH           host path to GCP creds JSON
#   QUOTA_LOG_FILE       optional JSONL file to append quota-failure records to.
#                        Used by the workflow to aggregate a quota summary.

set -uo pipefail

RETRYABLE_PATTERN="ZONE_RESOURCE_POOL_EXHAUSTED(_WITH_DETAILS)?|does not have enough resources available to fulfill the request|Machine type [^ ]+ does not exist in zone|/machineTypes/[^ ]+ was not found|Code: INTERNAL_ERROR|Please try again or contact Google Support|Code: QUOTA_EXCEEDED|Quota '[^']+' exceeded"
QUOTA_PATTERN="Quota '[^']+' exceeded"

: "${RUNTIME:?RUNTIME required}"
: "${PROJECT:?PROJECT required}"
: "${IMAGE:?IMAGE required}"
: "${FILTER:?FILTER required}"
: "${CREDS_PATH:?CREDS_PATH required}"
SHAPE_FLAG="${SHAPE_FLAG:-}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"
RANDOMIZE_ZONES="${RANDOMIZE_ZONES:-true}"

# Extract just the shape name from SHAPE_FLAG (e.g. "-x86_shape c4-standard-8"
# -> "c4-standard-8"). Empty when no shape is pinned (CIT picks internally).
SHAPE_NAME=""
if [[ -n "${SHAPE_FLAG}" ]]; then
  # shellcheck disable=SC2034  # _ is the throwaway flag token
  read -r _ SHAPE_NAME _ <<< "${SHAPE_FLAG}"
fi

# Append one JSONL record per quota failure found in $1 (the captured log)
# to ${QUOTA_LOG_FILE}. Each record carries: shape, attempted zone, the
# quota's location (region/zone parsed from the message), the quota name,
# and a timestamp. Aggregated end-of-run by the summarize-quota-failures
# job in the workflow.
record_quota_failures() {
  local log_file="$1"
  [[ -z "${QUOTA_LOG_FILE:-}" ]] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  [[ -f "${log_file}" ]] || return 0

  local now
  now=$(date -u +%FT%TZ)

  # Extract (quota_name, location) pairs from each matching line. Location is
  # parsed from "in region X" / "in zone X"; falls back to the attempted zone.
  while IFS=$'\t' read -r quota_name location; do
    [[ -z "${quota_name}" ]] && continue
    [[ -z "${location}" ]] && location="${zone}"
    jq -nc \
      --arg shape "${SHAPE_NAME:-unknown}" \
      --arg zone "${zone:-}" \
      --arg location "${location}" \
      --arg quota "${quota_name}" \
      --arg time "${now}" \
      '{shape: $shape, zone: $zone, location: $location, quota: $quota, time: $time}' \
      >> "${QUOTA_LOG_FILE}"
  done < <(grep -E "${QUOTA_PATTERN}" "${log_file}" | awk '
    {
      qstart = index($0, "Quota \x27")
      if (qstart == 0) next
      rest = substr($0, qstart + 7)
      qend = index(rest, "\x27")
      if (qend == 0) next
      quota = substr(rest, 1, qend - 1)
      loc = ""
      if (match($0, /in (region|zone) [a-z0-9-]+/)) {
        loc = substr($0, RSTART, RLENGTH)
        sub(/in (region|zone) /, "", loc)
      }
      print quota "\t" loc
    }
  ')
}

# Optionally shuffle the fallback zone list so retries spread across zones
# rather than always hitting the same one first. first_attempt_zone is added
# afterward, so it stays pinned to the head when set.
if [[ "${RANDOMIZE_ZONES}" == "true" && -n "${ZONES:-}" ]]; then
  # Intentional word splitting: ZONES is a space-separated list and each
  # zone needs to be its own printf argument so shuf has lines to shuffle.
  # shellcheck disable=SC2086
  ZONES=$(printf '%s\n' ${ZONES} | shuf | tr '\n' ' ')
fi

attempts=()
if [[ -n "${FIRST_ATTEMPT_ZONE:-}" ]]; then
  attempts+=("${FIRST_ATTEMPT_ZONE}")
fi
for z in ${ZONES:-}; do
  skip=0
  for existing in "${attempts[@]}"; do
    [[ "${existing}" == "${z}" ]] && { skip=1; break; }
  done
  (( skip == 0 )) && attempts+=("${z}")
done
# If no zones were configured at all, fall back to a single auto-pick attempt.
(( ${#attempts[@]} == 0 )) && attempts+=("")

# Default cap: try every distinct zone in the list.
MAX_ATTEMPTS="${MAX_ATTEMPTS:-${#attempts[@]}}"
[[ -z "${MAX_ATTEMPTS}" ]] && MAX_ATTEMPTS="${#attempts[@]}"

exit_code=1
for i in "${!attempts[@]}"; do
  attempt_num=$(( i + 1 ))
  (( attempt_num > MAX_ATTEMPTS )) && break
  zone="${attempts[i]}"
  zone_arg=()
  [[ -n "${zone}" ]] && zone_arg=(-zone "${zone}")

  # Pre-flight: when both a zone and a shape are pinned, ask GCP whether the
  # shape exists in that zone before paying the CIT setup cost. Skips ahead
  # on mismatch without burning the retry-delay sleep.
  if [[ -n "${zone}" && -n "${SHAPE_NAME}" ]] && command -v gcloud >/dev/null 2>&1; then
    if ! gcloud compute machine-types describe "${SHAPE_NAME}" \
           --zone="${zone}" \
           --project="${PROJECT}" \
           --format='value(name)' \
           --quiet >/dev/null 2>&1; then
      echo "::warning::Shape '${SHAPE_NAME}' not offered in zone '${zone}'; skipping (attempt ${attempt_num}/${MAX_ATTEMPTS})"
      continue
    fi
  fi

  log=$(mktemp)
  echo "::group::cloud-image-tests attempt ${attempt_num}/${MAX_ATTEMPTS} zone='${zone:-auto}'"
  set -o pipefail
  # shellcheck disable=SC2086  # SHAPE_FLAG and PARALLEL_* are intentionally
  # word-split so flag+value become two args.
  "${RUNTIME}" run \
    -v "${CREDS_PATH}:/creds/auth.json" \
    -e GOOGLE_APPLICATION_CREDENTIALS=/creds/auth.json \
    gcr.io/compute-image-tools/cloud-image-tests:latest \
    -project "${PROJECT}" \
    ${PARALLEL_COUNT:+-parallel_count ${PARALLEL_COUNT}} \
    ${PARALLEL_STAGGER:+-parallel_stagger ${PARALLEL_STAGGER}} \
    -filter "${FILTER}" \
    -images "${IMAGE}" \
    ${SHAPE_FLAG} \
    "${zone_arg[@]}" 2>&1 | tee "${log}"
  exit_code=${PIPESTATUS[0]}
  set +o pipefail
  echo "::endgroup::"

  # Log any quota failures *before* the retry decision so the end-of-run
  # summary captures every quota hit, including ones that ultimately
  # succeeded on a later zone with more headroom.
  record_quota_failures "${log}"

  if (( exit_code == 0 )); then
    rm -f "${log}"
    exit 0
  fi

  if grep -E -q "${RETRYABLE_PATTERN}" "${log}"; then
    if (( attempt_num >= MAX_ATTEMPTS )) || (( attempt_num >= ${#attempts[@]} )); then
      echo "::error::Retryable failure in zone '${zone:-auto}' but no attempts left (exit ${exit_code})"
      rm -f "${log}"
      exit "${exit_code}"
    fi
    echo "::warning::Retryable failure in zone '${zone:-auto}' (exit ${exit_code}); waiting ${RETRY_DELAY_SECONDS}s before next zone"
    rm -f "${log}"
    sleep "${RETRY_DELAY_SECONDS}"
    continue
  fi

  echo "::error::Non-retryable failure (exit ${exit_code}); not switching zones"
  rm -f "${log}"
  exit "${exit_code}"
done

echo "::error::Exhausted attempts (${attempt_num}/${MAX_ATTEMPTS})"
exit "${exit_code}"
