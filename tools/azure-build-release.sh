#!/usr/bin/env bash
# AlmaLinux Azure image release pipeline driver.
#
# Sequentially dispatches the four workflows that together build, release-to-
# gallery, test, and release-to-marketplace AlmaLinux Azure images:
#   1. .github/workflows/azure-build.yml          - "Azure: Build Image"
#   2. .github/workflows/azure-to-gallery.yml     - "Azure: Release Image to Gallery"      (per .raw URL)
#   3. .github/workflows/azure-test.yml           - "Azure: Test Image"                    (per Created path)
#   4. .github/workflows/azure-to-marketplace.yml - "Azure: Release Image to Marketplace"  (per .vhd Image URI)
#
# Mirrors the almalinux-azure-image-release skill. Run from the cloud-images
# repo root; gh must be authenticated against the AlmaLinux/cloud-images
# repository.
#
# Usage:
#   tools/azure-build-release.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: 10-kitten, 10, 9, 8.
#                          Prompts (defaulting to 10) if not given.
#   -y, --yes              Skip the per-step confirmation prompts. Does NOT
#                          skip the always-interactive prompt:
#                            * Azure Marketplace publish confirm
#                          Destructive / hard-to-reverse so the user
#                          always gets a hard stop on it.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/azure-build-release.sh [-v <MAJOR>] [-y]

Drives the four-step AlmaLinux Azure image release pipeline:
  1. Azure: Build Image                  (azure-build.yml)
  2. Azure: Release Image to Gallery     (azure-to-gallery.yml,     per .raw URL)
  3. Azure: Test Image                   (azure-test.yml,           per Created path)
  4. Azure: Release Image to Marketplace (azure-to-marketplace.yml, per Image URI)

Options:
  -v, --version <MAJOR>  AlmaLinux major version: 10-kitten, 10, 9, 8.
                         Prompted (defaulting to 10) if not given.
  -y, --yes              Skip confirmation prompts (except the Azure
                         Marketplace publish confirm - that one is
                         always asked).
  -h, --help             Show this help.
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

# Always-interactive confirm: asked even under -y/--yes. Use for actions
# that are destructive or hard to reverse - publishing to Azure
# Marketplace - where an auto-yes would be reckless.
confirm_always() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then
    warn "\"${prompt}\" requires a tty; cannot proceed under -y for this step."
    return 1
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

# Download a run's full log ZIP via the API and extract the per-job text logs
# to stdout. `gh run view --log` is unreliable for older runs; this endpoint
# works as long as the run hasn't been GC'd.
run_log() {
  local run_id="$1" tmp
  tmp=$(mktemp)
  gh api "repos/${REPO}/actions/runs/${run_id}/logs" > "${tmp}" 2>/dev/null \
    && unzip -p "${tmp}" 2>/dev/null
  rm -f "${tmp}"
}

# --- argument parsing -------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version) VERSION_MAJOR="$2"; shift 2 ;;
    -y|--yes)     ASSUME_YES=1;       shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown argument: $1" ;;
  esac
done

# --- preconditions ----------------------------------------------------------

command -v gh    >/dev/null 2>&1 || die "gh CLI not installed."
command -v jq    >/dev/null 2>&1 || die "jq not installed."
command -v unzip >/dev/null 2>&1 || die "unzip not installed."

[[ -f variables.pkr.hcl && -f .github/workflows/azure-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/azure-build.yml required)."

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

# No in-flight Azure pipeline?
IN_FLIGHT=$(gh run list --workflow=azure-build.yml --status in_progress --json databaseId --jq 'length' || echo 0)
if [[ "${IN_FLIGHT}" -gt 0 ]]; then
  warn "An azure-build.yml run is already in progress:"
  gh run list --workflow=azure-build.yml --status in_progress --limit 5
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

info "Step 1/4: Azure: Build Image for AlmaLinux ${VERSION_MAJOR}"
confirm "Dispatch azure-build.yml (version_major=${VERSION_MAJOR}, defaults for self-hosted/store_as_artifact/upload_to_s3/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
gh workflow run azure-build.yml \
  -f version_major="${VERSION_MAJOR}"

RUN_ID_BUILD=$(wait_for_new_run azure-build.yml "${TS}") \
  || die "Could not find dispatched azure-build.yml run."
info "Build run: ${REPO_URL}/${RUN_ID_BUILD}"

gh run watch "${RUN_ID_BUILD}" --exit-status \
  || die "Build run failed. See ${REPO_URL}/${RUN_ID_BUILD}"

# Extract unique .raw S3 URLs (exclude .raw.sha256sum and .raw.txt).
# The regex matches anything ending in ".raw" - .raw.sha256sum and .raw.txt
# strings contain "...x86_64.raw" as a substring, so they're collapsed by
# `sort -u` back to the canonical .raw URL.
mapfile -t RAW_URLS < <(
  run_log "${RUN_ID_BUILD}" \
    | grep -oE "https://[a-z0-9.-]+\.s3-accelerate\.dualstack\.amazonaws\.com/[^\"'[:space:])]+\.raw" \
    | sort -u
)

[[ "${#RAW_URLS[@]}" -gt 0 ]] \
  || die "Failed to extract any .raw URL. See ${REPO_URL}/${RUN_ID_BUILD}"

info "  ${#RAW_URLS[@]} .raw image URL(s):"
printf '    %s\n' "${RAW_URLS[@]}"

# --- Step 2: Release to Gallery (parallel dispatch, serial watch) ---------

info "Step 2/4: Azure: Release Image to Gallery (${#RAW_URLS[@]} run(s))"
confirm "Dispatch azure-to-gallery.yml ${#RAW_URLS[@]}x (defaults for url_type/dry-run-mode/community_gallery/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
for url in "${RAW_URLS[@]}"; do
  gh workflow run azure-to-gallery.yml \
    -f url_type="RAW at AWS S3" \
    -f image_url="${url}"
done

# Give GitHub a moment to list the runs.
sleep 10
mapfile -t RUN_IDS_GAL < <(
  gh run list --workflow=azure-to-gallery.yml --limit 20 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)

[[ "${#RUN_IDS_GAL[@]}" -eq "${#RAW_URLS[@]}" ]] \
  || warn "Expected ${#RAW_URLS[@]} gallery runs, found ${#RUN_IDS_GAL[@]}. Continuing with what's there."

for rid in "${RUN_IDS_GAL[@]}"; do
  info "  Gallery run: ${REPO_URL}/${rid}"
done

for rid in "${RUN_IDS_GAL[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Gallery run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Extract Image URI + Created paths per gallery run.
declare -a IMAGE_URIS=()     # one .vhd URI per gallery run (parallel with RUN_IDS_GAL)
declare -a CREATED_PATHS=()  # all gallery/definition/version paths (deduped globally below)

for rid in "${RUN_IDS_GAL[@]}"; do
  log=$(run_log "${rid}")

  uri=$(printf '%s\n' "${log}" \
          | grep -oE 'Image URI: https://[^[:space:]]+\.vhd' \
          | head -1 | sed -E 's/^Image URI: //')
  [[ -n "${uri}" ]] || die "No 'Image URI:' in ${REPO_URL}/${rid}"
  IMAGE_URIS+=("${uri}")

  mapfile -t paths < <(
    printf '%s\n' "${log}" \
      | grep -oE "Created: '[^']+'" \
      | sed -E "s/^Created: '(.+)'$/\1/" \
      | sort -u
  )
  [[ "${#paths[@]}" -gt 0 ]] || die "No 'Created:' paths in ${REPO_URL}/${rid}"
  CREATED_PATHS+=("${paths[@]}")
done

# Dedupe globally - AL10 x86_64 emits two identical Created lines per run.
mapfile -t CREATED_PATHS < <(printf '%s\n' "${CREATED_PATHS[@]}" | sort -u)

info "  ${#IMAGE_URIS[@]} Image URI(s):"
printf '    %s\n' "${IMAGE_URIS[@]}"
info "  ${#CREATED_PATHS[@]} unique gallery path(s):"
printf '    %s\n' "${CREATED_PATHS[@]}"

# --- Step 3: Test Image (parallel dispatch, serial watch) -----------------

info "Step 3/4: Azure: Test Image (${#CREATED_PATHS[@]} run(s))"
confirm "Dispatch azure-test.yml ${#CREATED_PATHS[@]}x (notify_mattermost default)?" \
  || die "Aborted by user."

TS=$(since_iso)
for path in "${CREATED_PATHS[@]}"; do
  gh workflow run azure-test.yml \
    -f compute_gallery_path="${path}"
done

sleep 10
mapfile -t RUN_IDS_TEST < <(
  gh run list --workflow=azure-test.yml --limit 20 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)

[[ "${#RUN_IDS_TEST[@]}" -eq "${#CREATED_PATHS[@]}" ]] \
  || warn "Expected ${#CREATED_PATHS[@]} test runs, found ${#RUN_IDS_TEST[@]}. Continuing."

for rid in "${RUN_IDS_TEST[@]}"; do
  info "  Test run: ${REPO_URL}/${rid}"
done

for rid in "${RUN_IDS_TEST[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Test run ${rid} failed. See ${REPO_URL}/${rid}"
done

# --- Step 4: Release to Marketplace (serial - per-offer conflict risk) ----

# Filter out variants that are NOT published to Azure Marketplace. For
# AlmaLinux Kitten, the aarch64-64k VHD has no Marketplace plan and must
# be skipped. The regular Kitten aarch64 VHD AND the Kitten x86_64 VHD
# still go to Marketplace.
# Filename distinguisher: the 64k variant ends in `-64k.aarch64.vhd`
# (e.g. `AlmaLinux-Kitten-Azure-10-<date>-64k.aarch64.vhd`); the regular
# aarch64 ends in plain `.aarch64.vhd` with no `-64k.` immediately before.
# Preserve the full Image URI list (all gallery uploads) for step 2's
# section in the final report - the step-4 filter below may shrink the
# working IMAGE_URIS array.
declare -a IMAGE_URIS_ALL=("${IMAGE_URIS[@]}")
declare -a SKIPPED_URIS=()
if [[ "${VERSION_MAJOR}" == "10-kitten" ]]; then
  declare -a IMAGE_URIS_KEPT=()
  for uri in "${IMAGE_URIS[@]}"; do
    if [[ "${uri}" == *-64k.aarch64.vhd ]]; then
      SKIPPED_URIS+=("${uri}")
    else
      IMAGE_URIS_KEPT+=("${uri}")
    fi
  done
  IMAGE_URIS=("${IMAGE_URIS_KEPT[@]}")
  if [[ "${#SKIPPED_URIS[@]}" -gt 0 ]]; then
    warn "Skipping marketplace publish for ${#SKIPPED_URIS[@]} Kitten aarch64-64k VHD(s) (no Marketplace plan):"
    printf '    %s\n' "${SKIPPED_URIS[@]}"
  fi
fi

declare -a RUN_IDS_MP=()
declare -a MP_BLOCKS=()

if [[ "${#IMAGE_URIS[@]}" -eq 0 ]]; then
  warn "No VHDs left to publish to Marketplace after filtering. Skipping step 4."
else
  info "Step 4/4: Azure: Release Image to Marketplace (${#IMAGE_URIS[@]} run(s), serialised)"
  # Always-interactive: azure-to-marketplace configures Marketplace draft
  # offers via the Partner Center Product Ingestion API. The user gets a
  # hard stop even when running -y/--yes.
  confirm_always "Publish ${#IMAGE_URIS[@]} VHD(s) as draft offer(s) to Azure Marketplace (release_to_marketplace=true, submit_to_preview=false)?" \
    || die "Aborted by user. Earlier step results preserved."

  for uri in "${IMAGE_URIS[@]}"; do
    ts=$(since_iso)
    gh workflow run azure-to-marketplace.yml \
      -f image_blob_url="${uri}" \
      -f release_to_marketplace=true \
      -f submit_to_preview=false

    rid=$(wait_for_new_run azure-to-marketplace.yml "${ts}") \
      || die "Could not find dispatched azure-to-marketplace.yml run."
    RUN_IDS_MP+=("${rid}")
    info "  Marketplace run: ${REPO_URL}/${rid}"

    gh run watch "${rid}" --exit-status \
      || die "Marketplace run ${rid} failed. See ${REPO_URL}/${rid}"

    block=$(run_log "${rid}" \
      | grep -E "^(- Offer:|- Plan:|- Package version:|- Released to|✅|❌)" \
      | head -10)
    if [[ -z "${block}" ]]; then
      block="(could not extract summary - see run URL)"
    fi
    MP_BLOCKS+=("${block}")

    echo
    echo "=== Marketplace summary (${uri##*/}) ==="
    printf '%s\n' "${block}"
    echo
  done
fi

# --- Final report ---------------------------------------------------------

cat <<EOF

==============================================================
Azure image release for AlmaLinux ${VERSION_MAJOR} complete.

Step 1 - Build:       ${REPO_URL}/${RUN_ID_BUILD}
  .raw image URL(s):
EOF
printf '    %s\n' "${RAW_URLS[@]}"

echo
echo "Step 2 - Gallery:     ${#RUN_IDS_GAL[@]} run(s)"
for rid in "${RUN_IDS_GAL[@]}"; do
  echo "    ${REPO_URL}/${rid}"
done
echo "  Image URI(s):"
printf '    %s\n' "${IMAGE_URIS_ALL[@]}"
echo "  Gallery path(s):"
printf '    %s\n' "${CREATED_PATHS[@]}"

echo
echo "Step 3 - Test:        ${#RUN_IDS_TEST[@]} run(s), all passed"
for rid in "${RUN_IDS_TEST[@]}"; do
  echo "    ${REPO_URL}/${rid}"
done

echo
echo "Step 4 - Marketplace: ${#RUN_IDS_MP[@]} run(s)"
for i in "${!RUN_IDS_MP[@]}"; do
  echo "    ${REPO_URL}/${RUN_IDS_MP[$i]}"
  echo "      Image: ${IMAGE_URIS[$i]}"
  printf '      %s\n' "${MP_BLOCKS[$i]}"
done
if [[ "${#SKIPPED_URIS[@]}" -gt 0 ]]; then
  echo "  Skipped (no Marketplace plan for Kitten aarch64-64k):"
  printf '    %s\n' "${SKIPPED_URIS[@]}"
fi

cat <<EOF

Pending manual steps:
  - Review each Marketplace offer's draft in Partner Center.
  - Submit each offer for preview + certification when ready.
==============================================================
EOF
