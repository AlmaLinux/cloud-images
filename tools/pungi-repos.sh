#!/bin/bash
# Rewrite the working tree to build from the PUNGI pre-release repositories
# (https://<arch>-pungi-<major>.almalinux.dev) instead of repo.almalinux.org.
# This allows building images before an AlmaLinux version is publicly
# released.
#
# The PUNGI compose mirrors the public repository layout exactly (same
# <Repo>/<arch>/os, BaseOS/<arch>/kickstart/, isos/<arch>/ with identical
# file names), so every rewrite is a per-arch prefix substitution:
#
#   https://repo.almalinux.org/almalinux/<major>
#     -> https://<archdash>-pungi-<major>.almalinux.dev/almalinux/<major>/<arch>/latest_result_almalinux/compose
#
# where <archdash> is the arch with underscores dashed for the host name
# (x86_64 -> x86-64, x86_64_v2 -> x86-64-v2; aarch64/ppc64le/s390x as-is)
# and <arch> is taken from the URL's own path.
#
# Rewritten files:
#   - variables.pkr.hcl                  (iso_url_* / iso_checksum_* locals
#                                         for 9/10)
#   - http/*.ks                          ('url --url' and 'repo --baseurl')
#   - almalinux*gencloud*.xml.tmpl       (the <url> element, s390x)
#
# The kickstarts preinstall the packages the post-reboot Ansible
# provisioning used to install with dnf (see the note in their %packages
# sections). For the installs that DO stay in Ansible (cloud-init where a
# kickstart cannot carry it, provider guest agents, VirtualBox Guest
# Additions build dependencies, ...) the script appends a %post section
# to the same kickstarts that writes /etc/yum.repos.d/pungi.repo,
# pointing dnf at the PUNGI compose BaseOS/AppStream with priority=1 so
# they shadow the released-version repositories at provisioning time.
# Without it those installs mix released-version packages into the
# pre-release system - fatal where versions must match the running
# kernel (the VirtualBox Guest Additions build installs kernel-devel /
# kernel-headers, which otherwise cannot match the compose kernel). A
# task removing the override is injected into the cleanup_vm role (the
# last role of every playbook), so shipped images keep only the standard
# repositories.
#
# Intentionally NOT rewritten:
#   - AlmaLinux 8: no PUNGI hosts exist - 8 keeps building from
#     repo.almalinux.org.
#   - AlmaLinux Kitten: a rolling, stream-based OS with no releases -
#     kitten.repo.almalinux.org already IS the latest compose, so there is
#     no pre-release state to switch to. Kitten keeps its public repos.
#
# The script is idempotent: PUNGI URLs do not match the public-host
# patterns, so a second run is a no-op. No arguments.

set -euo pipefail

cd "$(dirname "$0")/.."

MAJORS=(9 10)
ARCHES=(x86_64 x86_64_v2 aarch64 ppc64le s390x)

arch_dash() {
    # Host names dash the underscores: x86_64 -> x86-64, x86_64_v2 -> x86-64-v2
    echo "${1//_/-}"
}

# Build one sed program covering every (major, arch) combination.
SED_PROG=()
for major in "${MAJORS[@]}"; do
    for arch in "${ARCHES[@]}"; do
        ad=$(arch_dash "${arch}")
        pungi="https://${ad}-pungi-${major}.almalinux.dev/almalinux/${major}/${arch}"

        # Stable, literal major (kickstarts, xml templates):
        #   .../almalinux/<major>/<Repo>/<arch>/...  (Repo = BaseOS, AppStream, isos, ...)
        SED_PROG+=(-e "s#https://repo\.almalinux\.org/almalinux/${major}/([A-Za-z]+)/${arch}/#${pungi}/latest_result_almalinux/compose/\1/${arch}/#g")

        # Stable, os_ver interpolation (variables.pkr.hcl locals):
        #   .../almalinux/${var.os_ver_<major>}/isos/<arch>/...
        SED_PROG+=(-e "s#https://repo\.almalinux\.org/almalinux/\\\$\{var\.os_ver_${major}\}/([A-Za-z]+)/${arch}/#${pungi}/latest_result_almalinux/compose/\1/${arch}/#g")
    done
done

# Target files
FILES=(variables.pkr.hcl)
for f in http/*.ks almalinux*gencloud*.xml.tmpl; do
    [ -e "${f}" ] && FILES+=("${f}")
done

echo "[Info] Rewriting ${#FILES[@]} file(s) to PUNGI repositories (AlmaLinux 9/10; 8 and Kitten stay on their public repos)"
for f in "${FILES[@]}"; do
    sed -E "${SED_PROG[@]}" "${f}" > "${f}.pungi.tmp"
    if ! cmp -s "${f}" "${f}.pungi.tmp"; then
        mv "${f}.pungi.tmp" "${f}"
        echo "[Info]   rewritten: ${f}"
    else
        rm -f "${f}.pungi.tmp"
    fi
done

# Verify nothing for 9/10 still points at the public repositories.
# (AlmaLinux 8 and Kitten URLs are expected to remain.)
LEFTOVER=$(grep -nE "repo\.almalinux\.org/almalinux/(9|10)/|repo\.almalinux\.org/almalinux/\\\$\{var\.os_ver_(9|10)\}" "${FILES[@]}" || true)
if [ -n "${LEFTOVER}" ]; then
    echo "[Error] Public repository URLs remain after the PUNGI rewrite:"
    echo "${LEFTOVER}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Repository override for the provisioning-time installs (see the header).

inject_repo_override() {
    # inject_repo_override <ks-file> <major> <arch> - append a %post section
    # writing /etc/yum.repos.d/pungi.repo so the packages the post-reboot
    # Ansible provisioning still installs with dnf come from the PUNGI
    # compose instead of the released-version repositories (see the header).
    # priority=1 makes the compose shadow the standard repositories for
    # same-named packages; gpgcheck is off as pre-release compose packages
    # may not be signed yet. Idempotent: skipped when the override is
    # already present.
    local f="$1" major="$2" arch="$3" base
    [ -e "${f}" ] || return 0
    grep -q '^\[pungi-baseos\]' "${f}" && return 0
    base="https://$(arch_dash "${arch}")-pungi-${major}.almalinux.dev/almalinux/${major}/${arch}/latest_result_almalinux/compose"
    cat >> "${f}" <<EOF

# PUNGI: repository override for the Ansible-provisioned installs that are
# deliberately not preinstalled from the kickstart (provider guest agents,
# VirtualBox Guest Additions build dependencies, ...). Removed again by the
# cleanup_vm task tools/pungi-repos.sh injects.
%post
cat > /etc/yum.repos.d/pungi.repo << 'PUNGIREPO'
[pungi-baseos]
name=AlmaLinux \$releasever - PUNGI BaseOS
baseurl=${base}/BaseOS/${arch}/os/
gpgcheck=0
priority=1

[pungi-appstream]
name=AlmaLinux \$releasever - PUNGI AppStream
baseurl=${base}/AppStream/${arch}/os/
gpgcheck=0
priority=1
PUNGIREPO
%end
EOF
    echo "[Info]   runtime repo override injected: ${f}"
}

for major in "${MAJORS[@]}"; do
    for arch in x86_64 x86_64_v2 aarch64 ppc64le; do
        inject_repo_override "http/almalinux-${major}.gencloud-${arch}.ks" "${major}" "${arch}"
    done
    # gencloud s390x: kickstart-only, no Ansible (oz on Jenkins, TCG on
    # GitHub) - nothing installs after the kickstart, skip

    for arch in x86_64 aarch64; do
        inject_repo_override "http/almalinux-${major}.oci-${arch}.ks" "${major}" "${arch}"
    done

    for arch in x86_64 aarch64 64k-aarch64; do
        # the 64k-aarch64 kickstart (64k page-size kernel) still installs
        # from the plain aarch64 compose
        inject_repo_override "http/almalinux-${major}.azure-${arch}.ks" "${major}" "${arch#64k-}"
    done

    for suffix in x86_64 x86_64-bios x86_64_v2 aarch64; do
        # the x86_64-bios kickstart installs from the plain x86_64 compose
        inject_repo_override "http/almalinux-${major}.vagrant-${suffix}.ks" "${major}" "${suffix%-bios}"
    done
done

# Inject the override removal at the top of the cleanup_vm role (the last
# role of every playbook), so shipped images keep only the standard
# repositories. Harmless for playbooks that never saw the override: the
# task just ensures the file is absent.
CLEANUP_TASKS="ansible/roles/cleanup_vm/tasks/main.yml"
if ! grep -q 'pungi\.repo' "${CLEANUP_TASKS}"; then
    if [ "$(head -n 1 "${CLEANUP_TASKS}")" != "---" ]; then
        echo "[Error] ${CLEANUP_TASKS} does not start with '---', cannot inject the override removal"
        exit 1
    fi
    {
        echo "---"
        echo "- name: PUNGI - remove the runtime repository override"
        echo "  ansible.builtin.file:"
        echo "    path: /etc/yum.repos.d/pungi.repo"
        echo "    state: absent"
        echo ""
        tail -n +2 "${CLEANUP_TASKS}"
    } > "${CLEANUP_TASKS}.pungi.tmp" && mv "${CLEANUP_TASKS}.pungi.tmp" "${CLEANUP_TASKS}"
    echo "[Info]   override removal injected: ${CLEANUP_TASKS}"
fi

echo "[Info] PUNGI rewrite complete"
