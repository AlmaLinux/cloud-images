#!/usr/bin/env bash
# AlmaLinux Vagrant box build + HCP publish pipeline driver.
#
# Sequentially dispatches the three workflows that build and publish
# AlmaLinux Vagrant boxes:
#   1. .github/workflows/vagrant-build.yml  - "Vagrant: Build Boxes"  (libvirt + virtualbox + vmware)
#   2. .github/workflows/hyperv-build.yml   - "Vagrant: Build Hyper-V Box"
#   3. .github/workflows/vagrant-publish.yml - "Vagrant: Publish Box to HCP"  (per .box URL)
#
# Steps 1 and 2 are dispatched in parallel. Step 3 waits for both to
# finish, then dispatches one publish per produced .box file. The
# vagrant-build step includes a stuck-virtualbox rescue: if a virtualbox
# matrix job runs > 30 minutes while all non-virtualbox jobs are done,
# the script asks the user before cancelling the run and rerunning only
# the cancelled (failed) subset.
#
# Run from the cloud-images repo root;
# gh must be authenticated and have a default
# repo set (the script derives REPO from `gh repo set-default --view`,
# so it works for AlmaLinux/cloud-images and forks alike).
#
# Usage:
#   tools/vagrant-build-publish.sh [-v <MAJOR>] [-y]
#
# Options:
#   -v, --version <MAJOR>  AlmaLinux major version. One of: 10-kitten, 10, 9, 8.
#                          Prompts (defaulting to 10) if not given.
#   -d, --date-time-stamp <STAMP>
#                          Custom YYYYMMDDhhmmss stamp shared by step 2 +
#                          step 3 so every produced .box lands in the
#                          same S3 path. Defaults to the current UTC time
#                          if omitted.
#   -y, --yes              Skip the per-step confirmation prompts. Does NOT
#                          skip the always-interactive prompts:
#                            * stuck-virtualbox rescue cancel confirm
#                            * HCP Vagrant Cloud publish confirm
#                          Both are destructive / hard-to-reverse so the
#                          user always gets a hard stop on them.
#   -h, --help             Show this help and exit.

set -euo pipefail

DEFAULT_VERSION=10
DEFAULT_TYPE=ALL
VERSION_MAJOR=""
VAGRANT_TYPE=""
DATE_TIME_STAMP=""
ASSUME_YES=0
REPO=""       # captured below from `gh repo set-default --view`
REPO_URL=""   # https://github.com/<REPO>/actions/runs - derived from REPO
STUCK_THRESHOLD=1800  # 30 minutes, in seconds

usage() {
  cat <<'EOF'
Usage: tools/vagrant-build-publish.sh [-v <MAJOR>] [-t <TYPE>] [-d <YYYYMMDDhhmmss>] [-y]

Drives the Vagrant build + HCP publish pipeline:
  1. Vagrant: Build Boxes        (vagrant-build.yml)   \
  2. Vagrant: Build Hyper-V Box  (hyperv-build.yml)    / parallel (with -t ALL)
  3. Vagrant: Publish Box to HCP (vagrant-publish.yml) per .box URL

Options:
  -v, --version <MAJOR>          AlmaLinux major version: 10-kitten, 10, 9, 8.
                                 Prompted (defaulting to 10) if not given.
  -d, --date-time-stamp <STAMP>  Custom YYYYMMDDhhmmss stamp shared by both
                                 build dispatches so every produced .box
                                 lands in the same S3 path. Defaults to
                                 the current UTC time if omitted.
  -t, --type <TYPE>              Which Vagrant provider(s) to build. One of:
                                   ALL                 - both build workflows
                                                         (libvirt + virtualbox
                                                         + vmware via vagrant-
                                                         build.yml, AND hyperv
                                                         via hyperv-build.yml)
                                   vagrant_libvirt     - only vagrant-build.yml,
                                                         vagrant_type=
                                                         vagrant_libvirt
                                   vagrant_virtualbox  - only vagrant-build.yml,
                                                         vagrant_type=
                                                         vagrant_virtualbox
                                   vagrant_vmware      - only vagrant-build.yml,
                                                         vagrant_type=
                                                         vagrant_vmware
                                   vagrant_hyperv      - only hyperv-build.yml
                                                         (no vagrant-build.yml)
                                 Defaults to 'ALL' if not given.
  -y, --yes                      Skip confirmation prompts (except the
                                 stuck-virtualbox rescue and HCP publish
                                 confirms - those are always asked).
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

# Always-interactive confirm: asked even under -y/--yes. Use for actions
# that are destructive or hard to reverse - cancelling a run, publishing
# to a public registry - where an auto-yes would be reckless.
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

# Timestamp 60 seconds in the past. The backdate absorbs clock skew between
# this host and GitHub's run-creation timestamps so the JQ filter
# `[.[]|select(.createdAt > since)]` doesn't reject our dispatched run.
since_iso() {
  date -u -d '60 seconds ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -v-60S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Poll for a dispatched run to materialise in the run list. No `--user @me`
# filter - that's unreliable on forks/older gh versions.
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

# Per-job plain-text log (reliable; `gh run view --log` is empty for some
# past jobs, and the run-level zip omits some matrix-job text files).
job_log() {
  local job_id="$1"
  gh api "repos/${REPO}/actions/jobs/${job_id}/logs" 2>/dev/null
}

# Watch the vagrant-build run with stuck-virtualbox rescue. Polls every
# 60s; if all non-virtualbox jobs are completed and a virtualbox job has
# been in_progress for more than STUCK_THRESHOLD seconds, asks the user
# to cancel the run and rerun only the cancelled (failed) virtualbox
# jobs. Loops the rescue if the next attempt also hangs.
watch_vagrant_build_with_rescue() {
  local run_id="$1"
  # Initialise `last_rescue` to function-entry time so the first rescue
  # can only fire after STUCK_THRESHOLD has elapsed since watching began.
  # If left at 0, the throttle (now - last_rescue < STUCK_THRESHOLD) was
  # trivially false on the first poll and the rescue fired immediately -
  # particularly visible with `-t vagrant_virtualbox`, where the "all
  # non-virtualbox jobs completed" condition is trivially true (no
  # non-virtualbox jobs exist in the matrix).
  local last_rescue
  last_rescue=$(date -u +%s)
  local rescue_attempt=0

  while true; do
    sleep 60
    local snapshot status conclusion
    snapshot=$(gh run view "${run_id}" --json status,conclusion,jobs)
    status=$(printf '%s' "${snapshot}" | jq -r '.status')
    conclusion=$(printf '%s' "${snapshot}" | jq -r '.conclusion // ""')

    if [[ "${status}" == "completed" ]]; then
      [[ "${conclusion}" == "success" ]] && return 0
      warn "vagrant-build finished with conclusion '${conclusion}'."
      return 1
    fi

    # Throttle rescue attempts: only consider after STUCK_THRESHOLD since
    # last try.
    local now
    now=$(date -u +%s)
    (( now - last_rescue < STUCK_THRESHOLD )) && continue

    # Non-virtualbox jobs - any still not completed?
    local non_vbox_pending
    non_vbox_pending=$(printf '%s' "${snapshot}" | jq '[.jobs[]
      | select(.name | test("virtualbox") | not)
      | select(.status != "completed")] | length')
    (( non_vbox_pending > 0 )) && continue

    # Virtualbox jobs - any still in_progress?
    local vbox_stuck
    vbox_stuck=$(printf '%s' "${snapshot}" | jq -r '[.jobs[]
      | select(.name | test("virtualbox"))
      | select(.status == "in_progress")
      | "  \(.databaseId)  \(.name)"] | .[]')
    [[ -z "${vbox_stuck}" ]] && continue

    echo
    warn "virtualbox job(s) stuck > 30min while all non-virtualbox jobs are completed:"
    printf '%s\n' "${vbox_stuck}"
    if ! confirm_always "Cancel the run and rerun only the cancelled virtualbox jobs?"; then
      warn "Aborted rescue; the script will keep waiting for the run to finish on its own."
      last_rescue=$(date -u +%s)
      continue
    fi

    gh run cancel "${run_id}" || warn "gh run cancel exited non-zero; the run may have just moved on."

    # Wait for the cancellation to fully propagate. `gh run rerun --failed`
    # requires the run to be in status=completed; if called while the run
    # is still in `in_progress` / `cancelling`, it fails with the
    # misleading "workflow file may be broken" error. A blanket sleep is
    # not enough - poll until completed (up to 5 minutes).
    info "Waiting for run ${run_id} to reach status=completed before rerun..."
    local cancel_status=""
    for _ in $(seq 1 60); do
      sleep 5
      cancel_status=$(gh run view "${run_id}" --json status --jq '.status' 2>/dev/null || echo "")
      [[ "${cancel_status}" == "completed" ]] && break
    done
    if [[ "${cancel_status}" != "completed" ]]; then
      warn "Run ${run_id} did not reach status=completed within 5 minutes (last seen: '${cancel_status:-unknown}'); cannot rerun automatically."
      return 1
    fi

    local rerun_output=""
    if ! rerun_output=$(gh run rerun "${run_id}" --failed 2>&1); then
      warn "gh run rerun --failed failed: ${rerun_output}"
      return 1
    fi
    rescue_attempt=$((rescue_attempt + 1))
    last_rescue=$(date -u +%s)
    info "vagrant-build rescue attempt ${rescue_attempt}: cancelled stuck virtualbox job(s); reran the cancelled subset. ${REPO_URL}/${run_id}"
  done
}

# Extract .box S3 URLs from a build run by walking its per-job logs (the
# run-level zip is unreliable for the vagrant-build matrix).
extract_box_urls_from_run() {
  local run_id="$1"
  local jid
  for jid in $(gh run view "${run_id}" --json jobs \
                --jq '.jobs[] | select(.conclusion=="success") | .databaseId'); do
    job_log "${jid}"
  done | grep -oE "https://[a-z0-9.-]+\.s3-accelerate\.dualstack\.amazonaws\.com/[^\"'[:space:])]+\.box" \
       | sort -u
}

# --- argument parsing -------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)         VERSION_MAJOR="$2";    shift 2 ;;
    -t|--type)            VAGRANT_TYPE="$2";     shift 2 ;;
    -d|--date-time-stamp) DATE_TIME_STAMP="$2";  shift 2 ;;
    -y|--yes)             ASSUME_YES=1;          shift ;;
    -h|--help)            usage; exit 0 ;;
    *)                    die "Unknown argument: $1" ;;
  esac
done

# Validate the date+time stamp format up-front so a typo fails before we
# dispatch anything.
if [[ -n "${DATE_TIME_STAMP}" ]]; then
  [[ "${DATE_TIME_STAMP}" =~ ^[0-9]{14}$ ]] \
    || die "--date-time-stamp must be 14 digits (YYYYMMDDhhmmss), got: ${DATE_TIME_STAMP}"
fi

VAGRANT_TYPE="${VAGRANT_TYPE:-${DEFAULT_TYPE}}"
case "${VAGRANT_TYPE}" in
  ALL|vagrant_libvirt|vagrant_virtualbox|vagrant_vmware|vagrant_hyperv) ;;
  *) die "type must be one of: ALL, vagrant_libvirt, vagrant_virtualbox, vagrant_vmware, vagrant_hyperv (got: ${VAGRANT_TYPE})" ;;
esac

# Which build workflow(s) does the type select?
#   ALL                            -> both vagrant-build.yml AND hyperv-build.yml
#   vagrant_libvirt / _virtualbox /
#   _vmware                        -> only vagrant-build.yml (with that vagrant_type)
#   vagrant_hyperv                 -> only hyperv-build.yml
DO_VAGRANT=0  # dispatch vagrant-build.yml ?
DO_HYPERV=0   # dispatch hyperv-build.yml  ?
case "${VAGRANT_TYPE}" in
  ALL)             DO_VAGRANT=1; DO_HYPERV=1 ;;
  vagrant_hyperv)  DO_VAGRANT=0; DO_HYPERV=1 ;;
  *)               DO_VAGRANT=1; DO_HYPERV=0 ;;
esac

# --- preconditions ----------------------------------------------------------

command -v gh    >/dev/null 2>&1 || die "gh CLI not installed."
command -v jq    >/dev/null 2>&1 || die "jq not installed."
command -v unzip >/dev/null 2>&1 || die "unzip not installed."

[[ -f variables.pkr.hcl && -f .github/workflows/vagrant-build.yml ]] \
  || die "Run from the cloud-images repo root (variables.pkr.hcl + .github/workflows/vagrant-build.yml required)."

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

# No in-flight Vagrant pipeline?
for wf in vagrant-build.yml hyperv-build.yml vagrant-publish.yml; do
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

# --- Step 1: shared date_time_stamp ----------------------------------------

# If the user passed --date-time-stamp, use it verbatim; otherwise mint
# one from the current UTC time. Either way, the same stamp is fed to
# both build dispatches in steps 2 + 3 so every produced .box ends up in
# the same per-build S3 path.
if [[ -z "${DATE_TIME_STAMP}" ]]; then
  DATE_TIME_STAMP=$(date -u +"%Y%m%d%H%M%S")
  info "Step 1/4: shared date_time_stamp = ${DATE_TIME_STAMP} (auto-generated)"
else
  info "Step 1/4: shared date_time_stamp = ${DATE_TIME_STAMP} (user-supplied)"
fi

# --- Steps 2 + 3: dispatch the selected build workflow(s) -------------------

# Build a human-readable summary of what's about to be dispatched (based
# on VAGRANT_TYPE) and an empty pair of run-id slots; either may stay
# empty if the type selects only one of the two workflows.
RUN_ID_VAGRANT=""
RUN_ID_HYPERV=""

if (( DO_VAGRANT )) && (( DO_HYPERV )); then
  info "Step 2/4: Vagrant: Build Boxes for AlmaLinux ${VERSION_MAJOR} (vagrant_type=${VAGRANT_TYPE}, parallel with Hyper-V)"
  info "Step 3/4: Vagrant: Build Hyper-V Box for AlmaLinux ${VERSION_MAJOR} (parallel with Vagrant)"
  confirm "Dispatch BOTH vagrant-build.yml (vagrant_type=${VAGRANT_TYPE}) AND hyperv-build.yml (version_major=${VERSION_MAJOR}, defaults for other flags)?" \
    || die "Aborted by user."
elif (( DO_VAGRANT )); then
  info "Step 2/4: Vagrant: Build Boxes for AlmaLinux ${VERSION_MAJOR} (vagrant_type=${VAGRANT_TYPE} only - no Hyper-V)"
  confirm "Dispatch vagrant-build.yml (version_major=${VERSION_MAJOR}, vagrant_type=${VAGRANT_TYPE}, defaults for other flags)?" \
    || die "Aborted by user."
else
  # DO_HYPERV only
  info "Step 3/4: Vagrant: Build Hyper-V Box for AlmaLinux ${VERSION_MAJOR} (Hyper-V only - no vagrant-build)"
  confirm "Dispatch hyperv-build.yml (version_major=${VERSION_MAJOR}, defaults for other flags)?" \
    || die "Aborted by user."
fi

# Dispatch vagrant-build if selected
if (( DO_VAGRANT )); then
  TS=$(since_iso)
  gh workflow run vagrant-build.yml \
    -f date_time_stamp="${DATE_TIME_STAMP}" \
    -f version_major="${VERSION_MAJOR}" \
    -f vagrant_type="${VAGRANT_TYPE}"
  RUN_ID_VAGRANT=$(wait_for_new_run vagrant-build.yml "${TS}") \
    || die "Could not find dispatched vagrant-build.yml run."
  info "Vagrant-build run: ${REPO_URL}/${RUN_ID_VAGRANT}"
fi

# Dispatch hyperv-build if selected
if (( DO_HYPERV )); then
  TS=$(since_iso)
  gh workflow run hyperv-build.yml \
    -f date_time_stamp="${DATE_TIME_STAMP}" \
    -f version_major="${VERSION_MAJOR}"
  RUN_ID_HYPERV=$(wait_for_new_run hyperv-build.yml "${TS}") \
    || die "Could not find dispatched hyperv-build.yml run."
  info "Hyper-V-build run: ${REPO_URL}/${RUN_ID_HYPERV}"
fi

# Watch each dispatched run. When both are dispatched, watch hyperv in
# background and vagrant-build (with stuck-virtualbox rescue) in foreground.
HV_PID=""
if (( DO_HYPERV )); then
  if (( DO_VAGRANT )); then
    info "Watching hyperv-build in background, vagrant-build (with stuck-virtualbox rescue) in foreground."
    ( gh run watch "${RUN_ID_HYPERV}" --exit-status ) &
    HV_PID=$!
  else
    info "Watching hyperv-build (foreground, only build dispatched)."
    gh run watch "${RUN_ID_HYPERV}" --exit-status \
      || die "hyperv-build failed. See ${REPO_URL}/${RUN_ID_HYPERV}"
    info "hyperv-build succeeded."
  fi
fi

if (( DO_VAGRANT )); then
  watch_vagrant_build_with_rescue "${RUN_ID_VAGRANT}" \
    || die "vagrant-build did not succeed. See ${REPO_URL}/${RUN_ID_VAGRANT}"
  info "vagrant-build succeeded."
fi

if [[ -n "${HV_PID}" ]]; then
  if wait "${HV_PID}"; then
    info "hyperv-build succeeded."
  else
    die "hyperv-build failed. See ${REPO_URL}/${RUN_ID_HYPERV}"
  fi
fi

# --- Aggregate .box URLs ----------------------------------------------------

mapfile -t BOX_URLS < <(
  {
    [[ -n "${RUN_ID_VAGRANT}" ]] && extract_box_urls_from_run "${RUN_ID_VAGRANT}"
    [[ -n "${RUN_ID_HYPERV}"  ]] && extract_box_urls_from_run "${RUN_ID_HYPERV}"
  } | sort -u
)

[[ "${#BOX_URLS[@]}" -gt 0 ]] \
  || die "Failed to extract any .box URL. See ${REPO_URL}/${RUN_ID_VAGRANT:-(skipped)} and ${REPO_URL}/${RUN_ID_HYPERV:-(skipped)}"

info "  ${#BOX_URLS[@]} .box image URL(s):"
printf '    %s\n' "${BOX_URLS[@]}"

# --- Step 4: HCP publish (SERIAL dispatch+watch) ---------------------------

# Multiple parallel vagrant-publish runs all try to "release" the SAME
# `almalinux/<major>` (or `almalinux/<major>-x86_64_v2`) box version on
# HCP Vagrant Cloud. The first one wins the release; the others fail with
#   Vagrant Cloud request failed - version is already released
# So serialise the dispatches: one at a time, watch each before moving
# on.

info "Step 4/4: Vagrant: Publish Box to HCP (${#BOX_URLS[@]} run(s), serialised)"
# Always-interactive confirm here: vagrant-publish pushes boxes to the
# public HCP Vagrant Cloud, which is hard to reverse. The user gets a
# hard stop even when running with -y/--yes.
confirm_always "Publish ${#BOX_URLS[@]} box(es) to HCP Vagrant Cloud now? (dry-run-mode=false, serialised)" \
  || die "Aborted by user. The build runs are preserved at ${REPO_URL}/${RUN_ID_VAGRANT:-(skipped)} and ${REPO_URL}/${RUN_ID_HYPERV:-(skipped)}."

declare -a RUN_IDS_PUB=()
declare -a PUBLISH_BLOCKS=()

for url in "${BOX_URLS[@]}"; do
  ts=$(since_iso)
  gh workflow run vagrant-publish.yml \
    -f image_url="${url}" \
    -f dry-run-mode=false

  rid=$(wait_for_new_run vagrant-publish.yml "${ts}") \
    || die "Could not find dispatched vagrant-publish.yml run for ${url##*/}."
  RUN_IDS_PUB+=("${rid}")
  info "  Publish run: ${REPO_URL}/${rid}  (${url##*/})"

  gh run watch "${rid}" --exit-status \
    || die "Publish run ${rid} failed. See ${REPO_URL}/${rid}"

  job_id=$(gh run view "${rid}" --json jobs --jq '.jobs[0].databaseId')
  block=$(job_log "${job_id}" \
    | grep -E "^(Vagrant box for|The box name:|Published to the Cloud)" \
    | head -10)
  [[ -n "${block}" ]] || block="(could not extract summary - see ${REPO_URL}/${rid})"
  PUBLISH_BLOCKS+=("${block}")

  echo
  echo "=== Publish summary (run ${rid}) ==="
  printf '%s\n' "${block}"
  echo
done

# --- Final report ----------------------------------------------------------

cat <<EOF

==============================================================
Vagrant build + HCP publish for AlmaLinux ${VERSION_MAJOR} complete.
type:            ${VAGRANT_TYPE}
date_time_stamp: ${DATE_TIME_STAMP}

EOF
if (( DO_VAGRANT )); then
  echo "Step 2 - Vagrant build:    ${REPO_URL}/${RUN_ID_VAGRANT}"
else
  echo "Step 2 - Vagrant build:    (skipped - type=${VAGRANT_TYPE})"
fi
if (( DO_HYPERV )); then
  echo "Step 3 - Hyper-V build:    ${REPO_URL}/${RUN_ID_HYPERV}"
else
  echo "Step 3 - Hyper-V build:    (skipped - type=${VAGRANT_TYPE})"
fi
echo
echo ".box image URL(s) (${#BOX_URLS[@]}):"
printf '    %s\n' "${BOX_URLS[@]}"

echo
echo "Step 4 - HCP publish:      ${#RUN_IDS_PUB[@]} run(s), all succeeded"
for i in "${!RUN_IDS_PUB[@]}"; do
  echo "    ${REPO_URL}/${RUN_IDS_PUB[$i]}"
  # Indent every line of the multi-line block, not just the first.
  printf '%s\n' "${PUBLISH_BLOCKS[$i]}" | sed 's/^/      /'
done

cat <<EOF

Boxes are now discoverable at https://portal.cloud.hashicorp.com/vagrant/discover/almalinux/.
==============================================================
EOF
