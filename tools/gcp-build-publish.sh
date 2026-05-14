#!/usr/bin/env bash
# AlmaLinux GCP image build + publish pipeline driver.
#
# Sequentially dispatches the two GCP workflows:
#   1. .github/workflows/gcp-build.yml   - "GCP: Build Image"
#   2. .github/workflows/gcp-publish.yml - "GCP: Publish Image" (run twice
#                                          in parallel: aarch64 + x86_64)
#
# Step 1 produces a build timestamp "YYYYMMDDhhmmss" inside its Mattermost
# notification text; the first 8 chars (YYYYMMDD) are the `image_datetag`
# step 2 needs to identify the artifact to publish.
#
# Run from the cloud-images repo root; gh must be authenticated and have
# a default repo set (the script derives REPO from `gh repo set-default
# --view`, so it works for AlmaLinux/cloud-images and forks alike).
#
# Usage:
#   tools/gcp-build-publish.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: 10-kitten, 10, 9, 8.
#                          Prompts (defaulting to 10) if not given.
#   -y, --yes              Skip the per-step confirmation prompts. Does NOT
#                          skip the always-interactive prompt:
#                            * GCP publish-to-prod confirm
#                          The publish writes to the public almalinux-cloud
#                          GCP project, so the user always gets a hard
#                          stop on it.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/gcp-build-publish.sh [-v <MAJOR>] [-y]

Drives the two-step AlmaLinux GCP build + publish pipeline:
  1. GCP: Build Image   (gcp-build.yml)
  2. GCP: Publish Image (gcp-publish.yml, run twice in parallel:
                         aarch64 + x86_64)

Options:
  -v, --version <MAJOR>  AlmaLinux major version: 10-kitten, 10, 9, 8.
                         Prompted (defaulting to 10) if not given.
  -y, --yes              Skip confirmation prompts (except the
                         GCP publish-to-prod confirm - that one is
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
# that are destructive or hard to reverse - publishing to the public
# almalinux-cloud GCP project - where an auto-yes would be reckless.
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

[[ -f variables.pkr.hcl && -f .github/workflows/gcp-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/gcp-build.yml required)."

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

for wf in gcp-build.yml gcp-publish.yml; do
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
  10-kitten|10|9|8) ;;
  *) die "version_major must be one of: 10-kitten, 10, 9, 8 (got: ${VERSION_MAJOR})" ;;
esac

# --- Step 1: Build ----------------------------------------------------------

info "Step 1/2: GCP: Build Image for AlmaLinux ${VERSION_MAJOR}"
confirm "Dispatch gcp-build.yml (version_major=${VERSION_MAJOR}, defaults for self-hosted/store_as_artifact/upload_to_s3/notify_mattermost)?" \
  || die "Aborted by user."

TS=$(since_iso)
gh workflow run gcp-build.yml -f version_major="${VERSION_MAJOR}"

RUN_ID_BUILD=$(wait_for_new_run gcp-build.yml "${TS}") \
  || die "Could not find dispatched gcp-build.yml run."
info "Build run: ${REPO_URL}/${RUN_ID_BUILD}"

gh run watch "${RUN_ID_BUILD}" --exit-status \
  || die "Build run failed. See ${REPO_URL}/${RUN_ID_BUILD}"

# Extract the 14-char "Gcp Image build `YYYYMMDDhhmmss`" timestamp from
# any per-arch matrix job. Both arch legs share the same timestamp (it
# comes from the init-data job's date_time_stamp output). Walk per-job
# logs because the run-level zip can drop matrix-job logs.
# shellcheck disable=SC2016
BUILD_TS=$(
  for jid in $(gh run view "${RUN_ID_BUILD}" --json jobs \
                --jq '.jobs[] | select(.conclusion=="success") | .databaseId'); do
    job_log "${jid}"
  done \
  | grep -oE 'Gcp Image build `[0-9]{14}`' \
  | head -1 \
  | grep -oE '[0-9]{14}'
)
[[ -n "${BUILD_TS}" ]] \
  || die "Could not extract 'Gcp Image build <TS>' from ${REPO_URL}/${RUN_ID_BUILD}"

DATETAG="${BUILD_TS:0:8}"   # first 8 chars: YYYYMMDD
info "  Build timestamp: ${BUILD_TS}"
info "  Image datetag:   ${DATETAG}"

# Resolved image names (deterministic from version_major + datetag + arch).
IMAGE_NAME_X86="almalinux-${VERSION_MAJOR}-v${DATETAG}"
IMAGE_NAME_ARM="almalinux-${VERSION_MAJOR}-arm64-v${DATETAG}"

# --- Step 2: Publish (parallel dispatch, serial watch) ----------------------

info "Step 2/2: GCP: Publish Image (2 run(s) - x86_64 + aarch64)"
info "  Will publish:"
info "    x86_64:  ${IMAGE_NAME_X86}"
info "    aarch64: ${IMAGE_NAME_ARM}"

# Always-interactive: publishes to the public almalinux-cloud GCP project.
# Cannot be silenced by -y/--yes.
confirm_always "Publish AlmaLinux ${VERSION_MAJOR} x86_64 + aarch64 images (datetag ${DATETAG}) to the public almalinux-cloud GCP project?" \
  || die "Aborted by user. Build run preserved at ${REPO_URL}/${RUN_ID_BUILD}; rerun publish manually with version_major=${VERSION_MAJOR}, image_datetag=${DATETAG} when ready."

TS=$(since_iso)
for arch in x86_64 aarch64; do
  gh workflow run gcp-publish.yml \
    -f version_major="${VERSION_MAJOR}" \
    -f arch="${arch}" \
    -f image_datetag="${DATETAG}"
done

sleep 10
mapfile -t RUN_IDS_PUB < <(
  gh run list --workflow=gcp-publish.yml --limit 10 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt > \"${TS}\")] | sort_by(.createdAt) | .[].databaseId"
)
[[ "${#RUN_IDS_PUB[@]}" -eq 2 ]] \
  || warn "Expected 2 publish runs, found ${#RUN_IDS_PUB[@]}. Continuing."

for rid in "${RUN_IDS_PUB[@]}"; do
  info "  Publish run: ${REPO_URL}/${rid}"
done
for rid in "${RUN_IDS_PUB[@]}"; do
  gh run watch "${rid}" --exit-status \
    || die "Publish run ${rid} failed. See ${REPO_URL}/${rid}"
done

# Map each run id to its arch. The publish workflow's display_title
# doesn't include arch directly, but the workflow `name` is the same;
# inputs aren't exposed via gh run view. We dispatched in order
# (x86_64, aarch64), and gh run list --jq sort_by(.createdAt) returns
# them in dispatch order - so index 0 is x86_64, index 1 is aarch64.
RUN_ID_PUB_X86="${RUN_IDS_PUB[0]:-}"
RUN_ID_PUB_ARM="${RUN_IDS_PUB[1]:-}"

# --- Final report ----------------------------------------------------------

cat <<EOF

==============================================================
GCP build + publish for AlmaLinux ${VERSION_MAJOR} complete.

Step 1 - Build:    ${REPO_URL}/${RUN_ID_BUILD}
  build timestamp: ${BUILD_TS}
  image datetag:   ${DATETAG}

Step 2 - Publish:  ${#RUN_IDS_PUB[@]} run(s), all succeeded
  x86_64:  ${REPO_URL}/${RUN_ID_PUB_X86}
    image: ${IMAGE_NAME_X86}
  aarch64: ${REPO_URL}/${RUN_ID_PUB_ARM}
    image: ${IMAGE_NAME_ARM}

Both images are now public in the almalinux-cloud GCP project.
List them with:
    gcloud compute images list --project=almalinux-cloud --filter="name~'^almalinux-${VERSION_MAJOR}.*v${DATETAG}\$'"
==============================================================
EOF
