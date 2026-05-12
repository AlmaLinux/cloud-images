#!/usr/bin/env bash
# AlmaLinux GenericCloud build + test pipeline driver.
#
# Sequentially dispatches the two workflows that build and test AlmaLinux
# GenericCloud (.qcow2) images:
#   1. .github/workflows/gencloud-build.yml - "GenericCloud: Build Image"
#   2. .github/workflows/gencloud-test.yml  - "GenericCloud: Test Image"   (per .qcow2 URL)
#
# Mirrors the almalinux-gencloud-build-test skill. Run from the cloud-images
# repo root; gh must be authenticated against the AlmaLinux/cloud-images
# repository.
#
# Usage:
#   tools/gencloud-build-test.sh [-v <MAJOR>] [-d <YYYYMMDDhhmmss>] [-y]
#
# Options:
#   -v, --version <MAJOR>            AlmaLinux major version. One of:
#                                    10-kitten, 10, 9, 8. Prompts (defaulting
#                                    to 10) if not given.
#   -d, --date-time-stamp <STAMP>    Custom YYYYMMDDhhmmss stamp to pin every
#                                    artifact in the build matrix to the same
#                                    instant. If omitted, gencloud-build.yml
#                                    generates one at dispatch.
#   -y, --yes                        Skip the per-step confirmation prompts.
#   -h, --help                       Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
DATE_TIME_STAMP=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/gencloud-build-test.sh [-v <MAJOR>] [-d <YYYYMMDDhhmmss>] [-y]

Drives the two-step AlmaLinux GenericCloud build + test pipeline:
  1. GenericCloud: Build Image (gencloud-build.yml)
  2. GenericCloud: Test Image  (gencloud-test.yml, per .qcow2 URL)

Options:
  -v, --version <MAJOR>          AlmaLinux major version: 10-kitten, 10, 9, 8.
                                 Prompted (defaulting to 10) if not given.
  -d, --date-time-stamp <STAMP>  Custom YYYYMMDDhhmmss stamp; passed verbatim
                                 to gencloud-build.yml so every matrix leg
                                 shares it. Defaults to the workflow's own
                                 auto-generated value if omitted.
  -y, --yes                      Skip confirmation prompts.
  -h, --help                     Show this help.
EOF
}

die()  { echo "[Error] $*"  >&2; exit 1; }
info() { echo "[Info]  $*"; }
warn() { echo "[Warn]  $*"  >&2; }

confirm() {
  local prompt="$1"
  [[ "${ASSUME_YES}" -eq 1 ]] && return 0
  if [[ ! -t 0 ]]; then
    die "Confirmation needed (\"${prompt}\") but stdin is not a tty. Re-run with --yes."
  fi
  local ans
  read -r -p "${prompt} [Y/n] " ans
  case "${ans:-Y}" in
    [Yy]*|"") return 0 ;;
    *)        return 1 ;;
  esac
}

# Timestamp 60 seconds in the past, in ISO-8601 UTC. The backdate absorbs
# clock skew between this host and GitHub's run-creation timestamps so the
# subsequent `[.[]|select(.createdAt > since)]` JQ filter doesn't reject a
# run created at almost the same wall-clock instant as our dispatch.
since_iso() {
  date -u -d '60 seconds ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -v-60S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Poll for a dispatched run to materialise in the run list. Filtered to the
# current user and a timestamp captured BEFORE dispatch.
wait_for_new_run() {
  local workflow="$1" since="$2" run_id=""
  for _ in $(seq 1 24); do
    sleep 5
    run_id=$(gh run list --workflow="${workflow}" --limit 5 \
              --json databaseId,createdAt \
              --jq "[.[] | select(.createdAt > \"${since}\")] | sort_by(.createdAt) | last | .databaseId // empty")
    [[ -n "${run_id}" ]] && { echo "${run_id}"; return 0; }
  done
  return 1
}

# Run-level log ZIP via the API (per-job text files inside). Used for the
# build run, where the summary URLs are spread across multiple matrix jobs.
run_log_zip() {
  local run_id="$1" tmp
  tmp=$(mktemp)
  gh api "repos/${REPO}/actions/runs/${run_id}/logs" > "${tmp}" 2>/dev/null \
    && unzip -p "${tmp}" 2>/dev/null
  rm -f "${tmp}"
}

# Per-job plain-text log. More reliable than the run-level zip when one
# job's log isn't packaged. Used for per-test-run summary extraction.
job_log() {
  local job_id="$1"
  gh api "repos/${REPO}/actions/jobs/${job_id}/logs" 2>/dev/null
}

# --- argument parsing -------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)         VERSION_MAJOR="$2";    shift 2 ;;
    -d|--date-time-stamp) DATE_TIME_STAMP="$2";  shift 2 ;;
    -y|--yes)             ASSUME_YES=1;          shift ;;
    -h|--help)            usage; exit 0 ;;
    *)                    die "Unknown argument: $1" ;;
  esac
done

# Validate the date+time stamp format up-front so a typo fails before we
# dispatch anything. The workflow only sanity-checks for empty/non-empty.
if [[ -n "${DATE_TIME_STAMP}" ]]; then
  [[ "${DATE_TIME_STAMP}" =~ ^[0-9]{14}$ ]] \
    || die "--date-time-stamp must be 14 digits (YYYYMMDDhhmmss), got: ${DATE_TIME_STAMP}"
fi

# --- preconditions ----------------------------------------------------------

command -v gh    >/dev/null 2>&1 || die "gh CLI not installed."
command -v jq    >/dev/null 2>&1 || die "jq not installed."
command -v unzip >/dev/null 2>&1 || die "unzip not installed."

[[ -f variables.pkr.hcl && -f .github/workflows/gencloud-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/gencloud-build.yml required)."

gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"

# Default repo set? `gh workflow run`, `gh run list`, `gh run watch`, ...
# all need a default repo when invoked outside a git checkout pointing at
# the target repo, and they fail with: "No default remote repository has
# been set. To learn more about the default repository, run:
# gh repo set-default --help".
if ! gh repo set-default --view >/dev/null 2>&1; then
  warn "No default gh repo set."
  confirm "Set default to 'AlmaLinux/cloud-images'?" \
    || die "Default repo not set. Run: gh repo set-default AlmaLinux/cloud-images"
  gh repo set-default AlmaLinux/cloud-images \
    || die "Failed to set default repo to AlmaLinux/cloud-images."
fi

# Capture the (now-set) default repo so every gh api call below targets the
# same repo `gh workflow run` / `gh run watch` are using. Lets the script
# work unchanged for forks (e.g. cloud-images-ci-dev) without manual edits.
REPO=$(gh repo set-default --view) \
  || die "Failed to read default gh repo (gh repo set-default --view)."
REPO_URL="https://github.com/${REPO}/actions/runs"
info "Default gh repo: ${REPO}"

# No in-flight GenericCloud pipeline?
IN_FLIGHT=$(gh run list --workflow=gencloud-build.yml --status in_progress --json databaseId --jq 'length' || echo 0)
if [[ "${IN_FLIGHT}" -gt 0 ]]; then
  warn "A gencloud-build.yml run is already in progress:"
  gh run list --workflow=gencloud-build.yml --status in_progress --limit 5
  confirm "Proceed anyway?" || die "Aborted."
fi

# --- version_major ----------------------------------------------------------

if [[ -z "${VERSION_MAJOR}" ]]; then
  if [[ ! -t 0 ]] && [[ "${ASSUME_YES}" -eq 0 ]]; then
    die "version_major not given and stdin is not a tty. Pass --version <MAJOR>."
  fi
  read -r -p "AlmaLinux major version [${DEFAULT_VERSION}]: " VERSION_MAJOR || true
  VERSION_MAJOR="${VERSION_MAJOR:-${DEFAULT_VERSION}}"
fi

case "${VERSION_MAJOR}" in
  10-kitten|10|9|8) ;;
  *) die "version_major must be one of: 10-kitten, 10, 9, 8 (got: ${VERSION_MAJOR})" ;;
esac

# --- Step 1: Build ----------------------------------------------------------

info "Step 1/2: GenericCloud: Build Image for AlmaLinux ${VERSION_MAJOR}"
DTS_DESC="${DATE_TIME_STAMP:-auto}"
confirm "Dispatch gencloud-build.yml (version_major=${VERSION_MAJOR}, date_time_stamp=${DTS_DESC}, defaults for self-hosted/store_as_artifact/upload_to_s3/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
# date_time_stamp passed only when non-empty so the workflow falls back to
# its auto-generated value when the user didn't pin one.
if [[ -n "${DATE_TIME_STAMP}" ]]; then
  gh workflow run gencloud-build.yml \
    -f version_major="${VERSION_MAJOR}" \
    -f date_time_stamp="${DATE_TIME_STAMP}"
else
  gh workflow run gencloud-build.yml \
    -f version_major="${VERSION_MAJOR}"
fi

RUN_ID_BUILD=$(wait_for_new_run gencloud-build.yml "${TS}") \
  || die "Could not find dispatched gencloud-build.yml run."
info "Build run: ${REPO_URL}/${RUN_ID_BUILD}"

gh run watch "${RUN_ID_BUILD}" --exit-status \
  || die "Build run failed. See ${REPO_URL}/${RUN_ID_BUILD}"

# Extract unique .qcow2 S3 URLs (exclude .qcow2.sha256sum and .qcow2.txt).
# The regex matches anything ending in ".qcow2" - .qcow2.sha256sum and
# .qcow2.txt strings contain "....qcow2" as a substring, so they're
# collapsed by `sort -u` back to the canonical .qcow2 URL.
mapfile -t QCOW2_URLS < <(
  run_log_zip "${RUN_ID_BUILD}" \
    | grep -oE "https://[a-z0-9.-]+\.s3-accelerate\.dualstack\.amazonaws\.com/[^\"'[:space:])]+\.qcow2" \
    | sort -u
)

[[ "${#QCOW2_URLS[@]}" -gt 0 ]] \
  || die "Failed to extract any .qcow2 URL. See ${REPO_URL}/${RUN_ID_BUILD}"

info "  ${#QCOW2_URLS[@]} .qcow2 image URL(s):"
printf '    %s\n' "${QCOW2_URLS[@]}"

# --- Step 2: Test (parallel dispatch, serial watch) ----------------------

info "Step 2/2: GenericCloud: Test Image (${#QCOW2_URLS[@]} run(s))"
confirm "Dispatch gencloud-test.yml ${#QCOW2_URLS[@]}x (notify_mattermost default)?" \
  || die "Aborted by user."

TS=$(since_iso)
for url in "${QCOW2_URLS[@]}"; do
  gh workflow run gencloud-test.yml \
    -f image_url="${url}"
done

sleep 10
mapfile -t RUN_IDS_TEST < <(
  gh run list --workflow=gencloud-test.yml --limit 30 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)

[[ "${#RUN_IDS_TEST[@]}" -eq "${#QCOW2_URLS[@]}" ]] \
  || warn "Expected ${#QCOW2_URLS[@]} test runs, found ${#RUN_IDS_TEST[@]}. Continuing."

for rid in "${RUN_IDS_TEST[@]}"; do
  info "  Test run: ${REPO_URL}/${rid}"
done

for rid in "${RUN_IDS_TEST[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Test run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Extract per-run summary block (**Image**, **Subtype** (ext4 only),
# **AlmaLinux release**, **System architecture**, **Test**).
# Pick the Test job that actually ran (conclusion=success, not skipped).
declare -a TEST_BLOCKS=()

for rid in "${RUN_IDS_TEST[@]}"; do
  job_id=$(gh run view "${rid}" --json jobs \
    --jq '.jobs[] | select((.name|startswith("Test GenericCloud")) and (.conclusion=="success")) | .databaseId' \
    | head -1)
  if [[ -z "${job_id}" ]]; then
    block="(could not find successful Test job - see ${REPO_URL}/${rid})"
  else
    block=$(job_log "${job_id}" \
      | grep -E '^\*\*(Image|Subtype|AlmaLinux release|System architecture|Test)\*\*:' \
      | head -10)
    [[ -n "${block}" ]] || block="(could not extract summary - see ${REPO_URL}/${rid})"
  fi
  TEST_BLOCKS+=("${block}")

  echo
  echo "=== Test summary (run ${rid}) ==="
  printf '%s\n' "${block}"
  echo
done

# --- Final report ---------------------------------------------------------

cat <<EOF

==============================================================
GenericCloud build + test for AlmaLinux ${VERSION_MAJOR} complete.

Step 1 - Build:  ${REPO_URL}/${RUN_ID_BUILD}
  .qcow2 image URL(s) (${#QCOW2_URLS[@]}):
EOF
printf '    %s\n' "${QCOW2_URLS[@]}"

echo
echo "Step 2 - Test:   ${#RUN_IDS_TEST[@]} run(s), all passed"
for i in "${!RUN_IDS_TEST[@]}"; do
  echo "    ${REPO_URL}/${RUN_IDS_TEST[$i]}"
  # Indent every line of the multi-line block, not just the first.
  printf '%s\n' "${TEST_BLOCKS[$i]}" | sed 's/^/      /'
done

cat <<EOF

GenericCloud images are public in S3 from step 1; there is no
follow-up marketplace step for this image type.
==============================================================
EOF
