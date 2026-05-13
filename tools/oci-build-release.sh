#!/usr/bin/env bash
# AlmaLinux OCI image build + test + marketplace publish pipeline driver.
#
# Sequentially dispatches the three OCI workflows:
#   1. .github/workflows/oci-build.yml               - "OCI: Build Image"
#   2. .github/workflows/oci-marketplace-publish.yml - "OCI: Release Image to Marketplace" (phase 1: import)
#   3. .github/workflows/oci-test.yml                - "OCI: Test Image"
#   4. .github/workflows/oci-marketplace-publish.yml - "OCI: Release Image to Marketplace" (phase 2: draft revision)
#
# Steps 2 and 4 are the SAME workflow with different inputs:
#   - phase 1 (release_to_marketplace=false) imports the .qcow2 to OCI as
#     a Compute Custom Image and prints its OCID.
#   - phase 2 (release_to_marketplace=true) creates the marketplace draft
#     revision, adds the package, and submits for review.
# Phase 1 must run before the test step (the tests need a Compute Image
# OCID), and phase 2 must run after the test step (no untested image
# should reach marketplace).
#
# Run from the cloud-images repo root;
# gh must be authenticated and have a default repo set.
#
# Usage:
#   tools/oci-build-release.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: 10, 9, 8.
#                          (OCI build does NOT support 10-kitten.)
#                          Prompts (defaulting to 10) if not given.
#   -y, --yes              Skip the per-step confirmation prompts. Does NOT
#                          skip the always-interactive prompt:
#                            * Phase-2 OCI Marketplace publish confirm
#                          The phase-2 publish writes to a public
#                          marketplace listing, so the user always gets
#                          a hard stop on it.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/oci-build-release.sh [-v <MAJOR>] [-y]

Drives the four-step AlmaLinux OCI release pipeline:
  1. OCI: Build Image                          (oci-build.yml)
  2. OCI: Release Image to Marketplace phase 1 (oci-marketplace-publish.yml,
       per .qcow2 URL, release_to_marketplace=false; produces OCIDs)
  3. OCI: Test Image                           (oci-test.yml, per OCID)
  4. OCI: Release Image to Marketplace phase 2 (oci-marketplace-publish.yml,
       per OCID, release_to_marketplace=true; submits draft revisions)

Options:
  -v, --version <MAJOR>  AlmaLinux major version: 10, 9, 8.
                         OCI build does NOT support 10-kitten.
                         Prompted (defaulting to 10) if not given.
  -y, --yes              Skip confirmation prompts (except the
                         phase-2 OCI Marketplace publish confirm -
                         that one is always asked).
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
# that are destructive or hard to reverse - publishing to OCI Marketplace -
# where an auto-yes would be reckless.
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

since_iso() {
  date -u -d '60 seconds ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -v-60S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

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

job_log() {
  local job_id="$1"
  gh api "repos/${REPO}/actions/jobs/${job_id}/logs" 2>/dev/null
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

[[ -f variables.pkr.hcl && -f .github/workflows/oci-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/oci-build.yml required)."

gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"

if ! gh repo set-default --view >/dev/null 2>&1; then
  warn "No default gh repo set."
  confirm "Set default to 'AlmaLinux/cloud-images'?" \
    || die "Default repo not set. Run: gh repo set-default AlmaLinux/cloud-images"
  gh repo set-default AlmaLinux/cloud-images \
    || die "Failed to set default repo to AlmaLinux/cloud-images."
fi

REPO=$(gh repo set-default --view) \
  || die "Failed to read default gh repo (gh repo set-default --view)."
REPO_URL="https://github.com/${REPO}/actions/runs"
info "Default gh repo: ${REPO}"

for wf in oci-build.yml oci-marketplace-publish.yml oci-test.yml; do
  in_flight=$(gh run list --workflow="${wf}" --status in_progress --json databaseId --jq 'length' || echo 0)
  if [[ "${in_flight}" -gt 0 ]]; then
    warn "A ${wf} run is already in progress:"
    gh run list --workflow="${wf}" --status in_progress --limit 5
    confirm "Proceed anyway?" || die "Aborted."
  fi
done

# --- version_major ----------------------------------------------------------

if [[ -z "${VERSION_MAJOR}" ]]; then
  if [[ ! -t 0 ]] && [[ "${ASSUME_YES}" -eq 0 ]]; then
    die "version_major not given and stdin is not a tty. Pass --version <MAJOR>."
  fi
  read -r -p "AlmaLinux major version [${DEFAULT_VERSION}]: " VERSION_MAJOR || true
  VERSION_MAJOR="${VERSION_MAJOR:-${DEFAULT_VERSION}}"
fi

case "${VERSION_MAJOR}" in
  10|9|8) ;;
  10-kitten) die "OCI build does not support 10-kitten." ;;
  *) die "version_major must be one of: 10, 9, 8 (got: ${VERSION_MAJOR})" ;;
esac

# --- Step 1: Build ----------------------------------------------------------

info "Step 1/4: OCI: Build Image for AlmaLinux ${VERSION_MAJOR}"
confirm "Dispatch oci-build.yml (version_major=${VERSION_MAJOR}, defaults for self-hosted/store_as_artifact/upload_to_s3/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
gh workflow run oci-build.yml -f version_major="${VERSION_MAJOR}"

RUN_ID_BUILD=$(wait_for_new_run oci-build.yml "${TS}") \
  || die "Could not find dispatched oci-build.yml run."
info "Build run: ${REPO_URL}/${RUN_ID_BUILD}"

gh run watch "${RUN_ID_BUILD}" --exit-status \
  || die "Build run failed. See ${REPO_URL}/${RUN_ID_BUILD}"

mapfile -t QCOW2_URLS < <(
  for jid in $(gh run view "${RUN_ID_BUILD}" --json jobs \
                --jq '.jobs[] | select(.conclusion=="success") | .databaseId'); do
    job_log "${jid}"
  done \
  | grep -oE "https://[a-z0-9.-]+\.s3-accelerate\.dualstack\.amazonaws\.com/[^\"'[:space:])]+\.qcow2" \
  | sort -u
)
[[ "${#QCOW2_URLS[@]}" -gt 0 ]] \
  || die "Failed to extract any .qcow2 URL. See ${REPO_URL}/${RUN_ID_BUILD}"

info "  ${#QCOW2_URLS[@]} .qcow2 image URL(s):"
printf '    %s\n' "${QCOW2_URLS[@]}"

# --- Step 2: Phase-1 import (parallel dispatch, serial watch) ---------------

info "Step 2/4: OCI: Release Image to Marketplace (phase 1: import) (${#QCOW2_URLS[@]} run(s))"
confirm "Dispatch oci-marketplace-publish.yml ${#QCOW2_URLS[@]}x with release_to_marketplace=false (phase 1, image import only)?" \
  || die "Aborted by user. Build run preserved at ${REPO_URL}/${RUN_ID_BUILD}."

TS=$(since_iso)
for url in "${QCOW2_URLS[@]}"; do
  gh workflow run oci-marketplace-publish.yml \
    -f image_source_type="QCOW2 file URL" \
    -f image_source_data="${url}" \
    -f release_to_marketplace=false
done

sleep 10
mapfile -t RUN_IDS_IMPORT < <(
  gh run list --workflow=oci-marketplace-publish.yml --limit 30 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)
[[ "${#RUN_IDS_IMPORT[@]}" -eq "${#QCOW2_URLS[@]}" ]] \
  || warn "Expected ${#QCOW2_URLS[@]} phase-1 runs, found ${#RUN_IDS_IMPORT[@]}. Continuing."

for rid in "${RUN_IDS_IMPORT[@]}"; do
  info "  Phase-1 run: ${REPO_URL}/${rid}"
done
for rid in "${RUN_IDS_IMPORT[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Phase-1 import run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Extract Compute Image OCID per phase-1 run.
# Source: the workflow's "Import as OCI Compute Image" step prints
#   [Debug] Image OCID: ocid1.image.oc1.<region>.<unique>
# to stdout right after the import (oci-marketplace-publish.yml:438).
# The Print-job-summary step writes the same value to $GITHUB_STEP_SUMMARY,
# but summary content is NOT included in the job log returned by
# `gh api .../jobs/<id>/logs` — so we cannot grep the summary here.
declare -a OCIDS=()
for rid in "${RUN_IDS_IMPORT[@]}"; do
  job_id=$(gh run view "${rid}" --json jobs --jq '.jobs[0].databaseId')
  ocid=$(job_log "${job_id}" \
    | grep -oE '\[Debug\] Image OCID: ocid1\.image\.oc1\.[a-z0-9._-]+' \
    | head -1 \
    | sed -E 's/^\[Debug\] Image OCID: //') || true
  [[ -n "${ocid}" ]] || die "Failed to extract Compute Image OCID from ${REPO_URL}/${rid}"
  OCIDS+=("${ocid}")
done

info "  ${#OCIDS[@]} Compute Image OCID(s):"
printf '    %s\n' "${OCIDS[@]}"

# --- Step 3: Test (parallel dispatch, serial watch) ------------------------

info "Step 3/4: OCI: Test Image (${#OCIDS[@]} run(s))"
confirm "Dispatch oci-test.yml ${#OCIDS[@]}x (notify_mattermost default)?" \
  || die "Aborted by user. Earlier results preserved."

TS=$(since_iso)
for ocid in "${OCIDS[@]}"; do
  gh workflow run oci-test.yml -f image_ocid="${ocid}"
done

sleep 10
mapfile -t RUN_IDS_TEST < <(
  gh run list --workflow=oci-test.yml --limit 30 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)
[[ "${#RUN_IDS_TEST[@]}" -eq "${#OCIDS[@]}" ]] \
  || warn "Expected ${#OCIDS[@]} test runs, found ${#RUN_IDS_TEST[@]}. Continuing."

for rid in "${RUN_IDS_TEST[@]}"; do
  info "  Test run: ${REPO_URL}/${rid}"
done
for rid in "${RUN_IDS_TEST[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Test run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Extract test summary per run.
# Same constraint as the phase-1 OCID extraction: the workflow's Job-summary
# step writes to $GITHUB_STEP_SUMMARY, which is NOT in the job log. We grep
# the test workflow's stdout (oci-test.yml emits these labels via plain
# echo: 'Custom Image Name:', 'Instance Name:', 'Instance OCID:',
# 'Public IP:', 'Availability Domain:').
declare -a TEST_BLOCKS=()
for rid in "${RUN_IDS_TEST[@]}"; do
  job_id=$(gh run view "${rid}" --json jobs --jq '.jobs[0].databaseId')
  block=$(job_log "${job_id}" \
    | grep -oE '(Custom Image Name|Availability Domain|Instance Name|Instance OCID|Public IP): .*' \
    | awk '!seen[$0]++' \
    | head -10) || true
  [[ -n "${block}" ]] || block="(could not extract summary - see ${REPO_URL}/${rid})"
  TEST_BLOCKS+=("${block}")

  echo
  echo "=== Test summary (run ${rid}) ==="
  printf '%s\n' "${block}"
  echo
done

# --- Step 4: Phase-2 publish (parallel dispatch, serial watch) -------------

info "Step 4/4: OCI: Release Image to Marketplace (phase 2: draft revision) (${#OCIDS[@]} run(s))"
# Always-interactive: phase 2 submits draft revisions to PUBLIC OCI
# Marketplace listings. The user gets a hard stop even when running -y/--yes.
confirm_always "Publish ${#OCIDS[@]} Compute Image OCID(s) to OCI Marketplace as draft revision(s) (release_to_marketplace=true)?" \
  || die "Aborted by user. Build / import / test results preserved; rerun phase 2 manually when ready."

TS=$(since_iso)
for ocid in "${OCIDS[@]}"; do
  gh workflow run oci-marketplace-publish.yml \
    -f image_source_type="Compute Image OCID" \
    -f image_source_data="${ocid}" \
    -f release_to_marketplace=true
done

sleep 10
mapfile -t RUN_IDS_PUBLISH < <(
  gh run list --workflow=oci-marketplace-publish.yml --limit 30 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)
[[ "${#RUN_IDS_PUBLISH[@]}" -eq "${#OCIDS[@]}" ]] \
  || warn "Expected ${#OCIDS[@]} phase-2 runs, found ${#RUN_IDS_PUBLISH[@]}. Continuing."

for rid in "${RUN_IDS_PUBLISH[@]}"; do
  info "  Phase-2 run: ${REPO_URL}/${rid}"
done
for rid in "${RUN_IDS_PUBLISH[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Phase-2 publish run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Extract publish summary per run.
declare -a PUBLISH_BLOCKS=()
for rid in "${RUN_IDS_PUBLISH[@]}"; do
  job_id=$(gh run view "${rid}" --json jobs --jq '.jobs[0].databaseId')
  block=$(job_log "${job_id}" \
    | grep -E '^(\*\*(Object Storage Path|Compute Custom Image|Compute Image OCID|Marketplace Listing|Marketplace Artifact|Draft Revision|Revision Package)\*\*:|✅ Draft revision|❌ Marketplace release)' \
    | head -15)
  [[ -n "${block}" ]] || block="(could not extract summary - see ${REPO_URL}/${rid})"
  PUBLISH_BLOCKS+=("${block}")

  echo
  echo "=== Phase-2 publish summary (run ${rid}) ==="
  printf '%s\n' "${block}"
  echo
done

# --- Final report ----------------------------------------------------------

cat <<EOF

==============================================================
OCI build + test + publish for AlmaLinux ${VERSION_MAJOR} complete.

Step 1 - Build:                ${REPO_URL}/${RUN_ID_BUILD}
  .qcow2 image URL(s) (${#QCOW2_URLS[@]}):
EOF
printf '    %s\n' "${QCOW2_URLS[@]}"

echo
echo "Step 2 - Marketplace phase 1:  ${#RUN_IDS_IMPORT[@]} run(s), all imported"
for rid in "${RUN_IDS_IMPORT[@]}"; do
  echo "    ${REPO_URL}/${rid}"
done
echo "  Compute Image OCID(s):"
printf '    %s\n' "${OCIDS[@]}"

echo
echo "Step 3 - Test:                 ${#RUN_IDS_TEST[@]} run(s), all passed"
for i in "${!RUN_IDS_TEST[@]}"; do
  echo "    ${REPO_URL}/${RUN_IDS_TEST[$i]}"
  printf '%s\n' "${TEST_BLOCKS[$i]}" | sed 's/^/      /'
done

echo
echo "Step 4 - Marketplace phase 2:  ${#RUN_IDS_PUBLISH[@]} run(s), all submitted for review"
for i in "${!RUN_IDS_PUBLISH[@]}"; do
  echo "    ${REPO_URL}/${RUN_IDS_PUBLISH[$i]}"
  printf '%s\n' "${PUBLISH_BLOCKS[$i]}" | sed 's/^/      /'
done

cat <<EOF

Pending manual steps:
  - Each Draft Revision waits for Oracle's review queue.
  - When approved, publish each revision from the Oracle Cloud Console
    (the workflow does NOT auto-publish - that is intentional).
==============================================================
EOF
