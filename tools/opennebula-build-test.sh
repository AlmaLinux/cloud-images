#!/usr/bin/env bash
# AlmaLinux OpenNebula build + test pipeline driver.
#
# Sequentially dispatches the two workflows that build and test AlmaLinux
# OpenNebula (.qcow2) images:
#   1. .github/workflows/opennebula-build.yml - "OpenNebula: Build Image"
#   2. .github/workflows/opennebula-test.yml  - "OpenNebula: Test Image"   (per .qcow2 URL)
#
# Mirrors the almalinux-opennebula-build-test skill. Run from the
# cloud-images repo root; gh must be authenticated and have a default repo
# set (the script derives REPO from `gh repo set-default --view`, so it
# works for AlmaLinux/cloud-images and forks alike).
#
# Usage:
#   tools/opennebula-build-test.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: 10-kitten, 10, 9, 8.
#                          Prompts (defaulting to 10) if not given.
#   -y, --yes              Skip the per-step confirmation prompts.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/opennebula-build-test.sh [-v <MAJOR>] [-y]

Drives the two-step AlmaLinux OpenNebula build + test pipeline:
  1. OpenNebula: Build Image (opennebula-build.yml)
  2. OpenNebula: Test Image  (opennebula-test.yml, per .qcow2 URL)

Options:
  -v, --version <MAJOR>  AlmaLinux major version: 10-kitten, 10, 9, 8.
                         Prompted (defaulting to 10) if not given.
  -y, --yes              Skip confirmation prompts.
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

# Timestamp 60 seconds in the past, in ISO-8601 UTC. The backdate absorbs
# clock skew between this host and GitHub's run-creation timestamps so the
# subsequent `[.[]|select(.createdAt > since)]` JQ filter doesn't reject a
# run created at almost the same wall-clock instant as our dispatch.
since_iso() {
  date -u -d '60 seconds ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -v-60S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Poll for a dispatched run to materialise in the run list. Filtered by a
# timestamp captured BEFORE dispatch. NOTE: do NOT add `--user @me` here -
# that filter is unreliable on forks/older gh versions and silently drops
# the run we just dispatched.
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

[[ -f variables.pkr.hcl && -f .github/workflows/opennebula-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/opennebula-build.yml required)."

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

# No in-flight OpenNebula pipeline?
IN_FLIGHT=$(gh run list --workflow=opennebula-build.yml --status in_progress --json databaseId --jq 'length' || echo 0)
if [[ "${IN_FLIGHT}" -gt 0 ]]; then
  warn "An opennebula-build.yml run is already in progress:"
  gh run list --workflow=opennebula-build.yml --status in_progress --limit 5
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

info "Step 1/2: OpenNebula: Build Image for AlmaLinux ${VERSION_MAJOR}"
confirm "Dispatch opennebula-build.yml (version_major=${VERSION_MAJOR}, defaults for self-hosted/store_as_artifact/upload_to_s3/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
gh workflow run opennebula-build.yml \
  -f version_major="${VERSION_MAJOR}"

RUN_ID_BUILD=$(wait_for_new_run opennebula-build.yml "${TS}") \
  || die "Could not find dispatched opennebula-build.yml run."
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

info "Step 2/2: OpenNebula: Test Image (${#QCOW2_URLS[@]} run(s))"
confirm "Dispatch opennebula-test.yml ${#QCOW2_URLS[@]}x (notify_mattermost default)?" \
  || die "Aborted by user."

TS=$(since_iso)
for url in "${QCOW2_URLS[@]}"; do
  gh workflow run opennebula-test.yml \
    -f image_url="${url}"
done

sleep 10
mapfile -t RUN_IDS_TEST < <(
  gh run list --workflow=opennebula-test.yml --limit 30 \
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

# Extract per-run summary block. Note the closing `\*\*` BEFORE the colon -
# the Mattermost notification renders lines as `**Image**: ...`,
# `**Test**: ...` with bold markers on both sides of the field name. The
# `Arch (filename)` field name contains literal parens which must be
# escaped as `\(filename\)` for grep -E.
declare -a TEST_BLOCKS=()

for rid in "${RUN_IDS_TEST[@]}"; do
  job_id=$(gh run view "${rid}" --json jobs \
    --jq '.jobs[] | select((.name|startswith("Test OpenNebula")) and (.conclusion=="success")) | .databaseId' \
    | head -1)
  if [[ -z "${job_id}" ]]; then
    block="(could not find successful Test job - see ${REPO_URL}/${rid})"
  else
    block=$(job_log "${job_id}" \
      | grep -E '^\*\*(Image|Arch \(filename\)|AlmaLinux release|System architecture|Test)\*\*:' \
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
OpenNebula build + test for AlmaLinux ${VERSION_MAJOR} complete.

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

OpenNebula images are public in S3 from step 1; there is no
follow-up marketplace step for this image type.
==============================================================
EOF
