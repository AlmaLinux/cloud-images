#!/usr/bin/env bash
# AlmaLinux AWS AMI release pipeline driver.
#
# Sequentially dispatches the three workflows that together build, distribute,
# and release AlmaLinux AWS AMIs:
#   1. .github/workflows/ami-build.yml          - "AWS: Build AMI"
#   2. .github/workflows/ami-copy.yml           - "AWS: Copy AMI to Regions and make Public"
#   3. .github/workflows/ami-to-marketplace.yml - "AWS: Release AMI to Marketplace" (run twice)
#
# Run from the cloud-images repo root;
# gh must be authenticated against the AlmaLinux/cloud-images repository.
#
# Usage:
#   tools/aws-ami-build-release.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: kitten_10, 10, 9, 8.
#                          Prompts (defaulting to 10) if not given.
#   -y, --yes              Skip the per-step confirmation prompts. Does NOT
#                          skip the always-interactive prompts:
#                            * "Copy AMIs to ALL regions and make PUBLIC"
#                            * "Release <ami> to AWS Marketplace"
#                          Both are destructive / hard-to-reverse so the
#                          user always gets a hard stop on them.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
VERSION_MAJOR=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO

usage() {
  cat <<'EOF'
Usage: tools/aws-ami-build-release.sh [-v <MAJOR>] [-y]

Drives the three-step AlmaLinux AWS AMI release pipeline:
  1. AWS: Build AMI                       (ami-build.yml)
  2. AWS: Copy AMI to Regions, make Public (ami-copy.yml)
  3. AWS: Release AMI to Marketplace      (ami-to-marketplace.yml, x86_64 + aarch64)

Options:
  -v, --version <MAJOR>  AlmaLinux major version: kitten_10, 10, 9, 8.
                         Prompted (defaulting to 10) if not given.
  -y, --yes              Skip confirmation prompts (except the
                         make-AMIs-public and AWS Marketplace publish
                         confirms - those are always asked).
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
# that are destructive or hard to reverse - making AMIs public across all
# regions, publishing to AWS Marketplace - where an auto-yes would be
# reckless.
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

# Fetch a single job's full log via the API. `gh run view --log [--job <id>]`
# is unreliable for some older job logs (returns empty even when the job
# succeeded); the jobs/<id>/logs endpoint returns plain text reliably.
job_log() {
  local job_id="$1"
  gh api "repos/${REPO}/actions/jobs/${job_id}/logs" 2>/dev/null
}

# Poll for the run we just dispatched. `gh workflow run` is fire-and-forget;
# the run id needs to be looked up from the list, filtered to the current
# user and a timestamp captured before dispatch.
wait_for_new_run() {
  local workflow="$1"
  local since="$2"
  local run_id=""
  for _ in $(seq 1 24); do
    sleep 5
    run_id=$(gh run list --workflow="${workflow}" --limit 5 \
              --json databaseId,createdAt \
              --jq "[.[] | select(.createdAt > \"${since}\")] | sort_by(.createdAt) | last | .databaseId // empty")
    [[ -n "${run_id}" ]] && { echo "${run_id}"; return 0; }
  done
  return 1
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

command -v gh >/dev/null 2>&1 || die "gh CLI not installed."
command -v jq >/dev/null 2>&1 || die "jq not installed."

[[ -f variables.pkr.hcl && -f .github/workflows/ami-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/ami-build.yml required)."

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

# No in-flight build?
IN_FLIGHT=$(gh run list --workflow=ami-build.yml --status in_progress --json databaseId --jq 'length' || echo 0)
if [[ "${IN_FLIGHT}" -gt 0 ]]; then
  warn "An ami-build.yml run is already in progress:"
  gh run list --workflow=ami-build.yml --status in_progress --limit 5
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
  kitten_10|10|9|8) ;;
  *) die "version_major must be one of: kitten_10, 10, 9, 8 (got: ${VERSION_MAJOR})" ;;
esac

# --- Step 1: Build ----------------------------------------------------------

info "Step 1/3: AWS: Build AMI for AlmaLinux ${VERSION_MAJOR}"
confirm "Dispatch ami-build.yml (version_major=${VERSION_MAJOR}, test_ami=true)?" \
  || die "Aborted by user."

TS=$(since_iso)
# notify_mattermost left unset so the workflow's own default takes
# effect - matches what the other tools/* scripts in this repo do.
gh workflow run ami-build.yml \
  -f version_major="${VERSION_MAJOR}" \
  -f test_ami=true

RUN_ID_BUILD=$(wait_for_new_run ami-build.yml "${TS}") \
  || die "Could not find dispatched ami-build.yml run."
info "Build run: ${REPO_URL}/${RUN_ID_BUILD}"

gh run watch "${RUN_ID_BUILD}" --exit-status \
  || die "Build run failed. See ${REPO_URL}/${RUN_ID_BUILD}"

extract_ami() {
  local run_id="$1"
  local arch="$2"
  local job_id
  job_id=$(gh run view "${run_id}" --json jobs \
    --jq ".jobs[] | select((.name|startswith(\"Build\")) and (.name|contains(\"${arch}\"))) | .databaseId" \
    | head -1)
  [[ -n "${job_id}" ]] || die "Could not find Build ${arch} job in run ${run_id}."
  job_log "${job_id}" \
    | grep -oE "AMI ID found in the build log: 'ami-[0-9a-f]+'" \
    | grep -oE 'ami-[0-9a-f]+' | head -1
}

AMI_X86=$(extract_ami "${RUN_ID_BUILD}" "x86_64")
AMI_AARCH=$(extract_ami "${RUN_ID_BUILD}" "aarch64")

[[ -n "${AMI_X86}"   ]] || die "Failed to extract x86_64 AMI ID. See ${REPO_URL}/${RUN_ID_BUILD}"
[[ -n "${AMI_AARCH}" ]] || die "Failed to extract aarch64 AMI ID. See ${REPO_URL}/${RUN_ID_BUILD}"

info "  x86_64  AMI: ${AMI_X86}"
info "  aarch64 AMI: ${AMI_AARCH}"

# --- Step 2: Copy + make public --------------------------------------------

info "Step 2/3: AWS: Copy AMI to Regions and make Public"
# Always-interactive: ami-copy with make_public=true exposes the AMIs in
# every AWS region. The user gets a hard stop even when running -y/--yes.
confirm_always "Copy AMIs to ALL AWS regions and make PUBLIC (x86_64=${AMI_X86}, aarch64=${AMI_AARCH})?" \
  || die "Aborted by user. Build run preserved at ${REPO_URL}/${RUN_ID_BUILD}."

TS=$(since_iso)
# notify_mattermost left unset so the workflow's own default takes
# effect - matches what the other tools/* scripts in this repo do.
gh workflow run ami-copy.yml \
  -f x86_64_ami_id="${AMI_X86}" \
  -f aarch64_ami_id="${AMI_AARCH}" \
  -f make_public=true \
  -f draft=false

RUN_ID_COPY=$(wait_for_new_run ami-copy.yml "${TS}") \
  || die "Could not find dispatched ami-copy.yml run."
info "Copy run: ${REPO_URL}/${RUN_ID_COPY}"

gh run watch "${RUN_ID_COPY}" --exit-status \
  || die "Copy run failed. See ${REPO_URL}/${RUN_ID_COPY}"

JOB_WIKI=$(gh run view "${RUN_ID_COPY}" --json jobs \
  --jq '.jobs[] | select(.name | contains("Prepare MD and CSV data for Wiki")) | .databaseId' \
  | head -1)

WIKI_PR=""
if [[ -n "${JOB_WIKI}" ]]; then
  # Case-insensitive: the wiki repo URL renders as 'AlmaLinux/wiki' in logs
  # even though env.wiki_repo is set as 'almalinux/wiki'.
  WIKI_PR=$(job_log "${JOB_WIKI}" \
    | grep -oiE 'https://github\.com/almalinux/wiki/pull/[0-9]+' | head -1)
fi

if [[ -n "${WIKI_PR}" ]]; then
  info "  Wiki PR: ${WIKI_PR}"
else
  warn "Could not extract wiki PR URL. Check ${REPO_URL}/${RUN_ID_COPY}"
fi

# --- Step 3: Release to Marketplace (twice) --------------------------------

release_to_marketplace() {
  local ami_id="$1"
  local label="$2"

  info "Step 3/3 (${label}): AWS: Release ${ami_id} to Marketplace"
  # Always-interactive: ami-to-marketplace publishes to the AWS Marketplace
  # (public_product=true). The user gets a hard stop even when running -y/--yes.
  confirm_always "Release ${ami_id} (${label}) to AWS Marketplace (public_product=true)?" \
    || die "Aborted by user. Earlier run results preserved."

  local ts run_id job_id
  ts=$(since_iso)
  # notify_mattermost left unset so the workflow's own default takes
  # effect - matches what the other tools/* scripts in this repo do.
  gh workflow run ami-to-marketplace.yml \
    -f ami_id="${ami_id}" \
    -f release_to_marketplace=true \
    -f public_product=true

  run_id=$(wait_for_new_run ami-to-marketplace.yml "${ts}") \
    || die "Could not find dispatched ami-to-marketplace.yml run."
  info "Marketplace (${label}) run: ${REPO_URL}/${run_id}"

  gh run watch "${run_id}" --exit-status \
    || die "Marketplace run failed for ${label}. See ${REPO_URL}/${run_id}"

  job_id=$(gh run view "${run_id}" --json jobs --jq '.jobs[0].databaseId')
  echo
  echo "=== ${label} marketplace release summary ==="
  # The `Print job summary` step echoes "- Field: \`value\`" lines to
  # $GITHUB_STEP_SUMMARY (file redirect; not in stdout). Extract from the
  # echo SOURCE lines that DO appear in the runner log: strip ANSI escapes,
  # drop the timestamp prefix and any leading `&& `, unwrap the quoted echo
  # body, unescape backticks.
  job_log "${job_id}" \
    | sed -E $'s/\x1b\\[[0-9;]*m//g' \
    | grep -E 'echo "- (AMI Name|AMI ID|Product Name|Product ID|Released to Marketplace|ChangeSet ID):' \
    | sed -E 's/^[0-9T:.Z-]+[[:space:]]+//; s/^[[:space:]]*(\&\&[[:space:]]+)?//' \
    | sed -E 's/^echo "(- [^"]+)"( \|\| true)?$/\1/' \
    | sed -E "s/\\\\\`/\`/g" \
    || echo "(could not extract summary lines - see run URL)"
  echo

  RUN_ID_MP_LAST="${run_id}"
}

# x86_64 first (serialise to avoid AWS Marketplace ChangeSet conflicts on
# the same product).
release_to_marketplace "${AMI_X86}"   "x86_64"
RUN_ID_MP_X86="${RUN_ID_MP_LAST}"

release_to_marketplace "${AMI_AARCH}" "aarch64"
RUN_ID_MP_AARCH="${RUN_ID_MP_LAST}"

# --- Final report ----------------------------------------------------------

cat <<EOF

==============================================================
AWS AMI release for AlmaLinux ${VERSION_MAJOR} complete.

Step 1 - Build:         ${REPO_URL}/${RUN_ID_BUILD}
  x86_64  AMI: ${AMI_X86}
  aarch64 AMI: ${AMI_AARCH}

Step 2 - Copy + public: ${REPO_URL}/${RUN_ID_COPY}
  Wiki PR: ${WIKI_PR:-(not extracted - see run URL)}

Step 3 - Marketplace:
  x86_64:  ${REPO_URL}/${RUN_ID_MP_X86}
  aarch64: ${REPO_URL}/${RUN_ID_MP_AARCH}

Pending manual steps:
  - Review and merge the wiki PR.
  - Approve the AWS Marketplace ChangeSets in the seller portal.
==============================================================
EOF
