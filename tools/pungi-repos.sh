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
#                                         for 9/10, the s390x_kernel_url_* /
#                                         s390x_initrd_url_* locals of the
#                                         s390x TCG build, and the os_ver_9 /
#                                         os_ver_10 defaults - see below)
#   - http/*.ks                          ('url --url' and 'repo --baseurl')
#   - almalinux*gencloud*.xml.tmpl       (the <url> element of the Jenkins
#                                         s390x oz build)
#
# The kickstarts preinstall the packages the post-reboot Ansible
# provisioning used to install with dnf (see the note in their %packages
# sections). For the installs that DO stay in Ansible (cloud-init where a
# kickstart cannot carry it, provider guest agents, VirtualBox Guest
# Additions build dependencies, GCP's google-* packages from Google's
# own repository, ...) the script appends a %post section
# to the same kickstarts that writes /etc/yum.repos.d/pungi.repo,
# pointing dnf at the PUNGI compose BaseOS/AppStream with priority=1 so
# they shadow the released-version repositories at provisioning time.
# On GCP only the AlmaLinux dependencies of the google-* packages are
# affected - the Google repository itself is untouched.
# Without it those installs mix released-version packages into the
# pre-release system - fatal where versions must match the running
# kernel (the VirtualBox Guest Additions build installs kernel-devel /
# kernel-headers, which otherwise cannot match the compose kernel). A
# task removing the override is injected into the cleanup_vm role (the
# last role of every playbook), so shipped images keep only the standard
# repositories.
#
# The AWS AMIs (ansible/roles/ami_<major>_<arch>) are built differently:
# a surrogate EBS volume is chroot-bootstrapped from a running source
# instance, and the almalinux-repos package seeds the chroot with the
# released-version repositories. The script injects a task into the
# roles' os.yaml that writes the same pungi.repo into both the source
# instance (host) and the /rootfs chroot right after that - the chroot
# dnf steps then install from the compose. The host copy matters for the
# 9 roles, whose 'Update the system' task uses the ansible dnf module
# and reads the host repository configuration. A removal task injected
# into cleanup.yaml drops the override from both places before the
# volume is snapshotted.
#
# AlmaLinux version: variables.pkr.hcl pins the released minor in
# os_ver_9 / os_ver_10 (e.g. 10.2), and every image name is derived from
# it. A PUNGI compose carries the NEXT minor (its almalinux-release is e.g.
# 10.3), so the script reads that version from the compose BaseOS repodata
# and sets it as the os_ver_<major> default. The images then get the
# pre-release version in their names, matching /etc/almalinux-release
# inside them and the release string the tests grep for, while the
# scheduled (non-PUNGI) builds keep producing the released version from
# the committed defaults - no bump commit is needed to build an upcoming
# release from PUNGI.
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
# AlmaLinux version from the compose -> os_ver_<major> in variables.pkr.hcl
# ---------------------------------------------------------------------------

# Prints the almalinux-release version (e.g. 10.3) of a major's PUNGI
# compose, read from the BaseOS repodata. The composes of one major carry
# the same version on every arch; the arches are tried in order in case a
# host is down.
compose_release_version() {
    local -r major="${1}"
    local arch ad base primary ver
    for arch in x86_64 aarch64 ppc64le s390x; do
        ad=$(arch_dash "${arch}")
        base="https://${ad}-pungi-${major}.almalinux.dev/almalinux/${major}/${arch}/latest_result_almalinux/compose/BaseOS/${arch}/os"
        primary=$(curl -sf "${base}/repodata/repomd.xml" | grep -oE 'repodata/[^"]*-primary\.xml\.gz' | head -n 1) || true
        [ -n "${primary}" ] || continue
        ver=$(curl -sf "${base}/${primary}" | gunzip -c 2>/dev/null \
            | python3 -c 'import re,sys; m=re.search(r"<name>almalinux-release</name>.*?ver=\"([^\"]+)\"", sys.stdin.read(), re.S); print(m.group(1) if m else "")') || true
        if [ -n "${ver}" ]; then
            echo "${ver}"
            return 0
        fi
    done
    return 1
}

for major in "${MAJORS[@]}"; do
    if ! version=$(compose_release_version "${major}"); then
        echo "[Error] Could not read the almalinux-release version from the AlmaLinux ${major} PUNGI compose"
        exit 1
    fi
    if ! [[ "${version}" =~ ^${major}\.[0-9]+$ ]]; then
        echo "[Error] Unexpected almalinux-release version '${version}' in the AlmaLinux ${major} PUNGI compose"
        exit 1
    fi
    current=$(sed -nE "/^variable \"os_ver_${major}\"/,/^}/ s/^  default = \"([^\"]+)\"/\1/p" variables.pkr.hcl)
    if [ -z "${current}" ]; then
        echo "[Error] No os_ver_${major} default found in variables.pkr.hcl"
        exit 1
    fi
    if [ "${current}" != "${version}" ]; then
        sed -E "/^variable \"os_ver_${major}\"/,/^}/ s/^  default = \"[^\"]+\"/  default = \"${version}\"/" variables.pkr.hcl > variables.pkr.hcl.pungi.tmp \
            && mv variables.pkr.hcl.pungi.tmp variables.pkr.hcl
        echo "[Info]   os_ver_${major}: ${current} -> ${version} (almalinux-release in the PUNGI compose)"
    else
        echo "[Info]   os_ver_${major}: already ${version}"
    fi
done

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

inject_gpg_import() {
    # inject_gpg_import <ks-file> - append a %post importing the AlmaLinux
    # GPG keys into the RPM database. On GA builds dnf imports the keys
    # lazily while installing the google-* packages' AlmaLinux
    # dependencies, but on PUNGI builds those come from the gpgcheck=0
    # override repositories and no import ever happens - the image would
    # ship without the keys. The 9 gcp kickstarts already import
    # /etc/pki/rpm-gpg/* (everything) in their %post; the 10 ones import
    # only Google's key. Idempotent: skipped when an import already
    # covers the AlmaLinux keys.
    local f="$1"
    [ -e "${f}" ] || return 0
    grep -qE 'rpm --import /etc/pki/rpm-gpg/(RPM-GPG-KEY-AlmaLinux|\*)' "${f}" && return 0
    cat >> "${f}" <<'EOF'

# PUNGI: with the AlmaLinux packages coming from the gpgcheck=0 override
# repositories, dnf never imports the AlmaLinux GPG keys during the Ansible
# provisioning - import them explicitly so the image matches its GA
# counterpart (where the first dnf install imports them).
%post
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux*
%end
EOF
    echo "[Info]   GPG key import injected: ${f}"
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

    # gcp: the google-* packages stay in Ansible (Google's own repository),
    # but their AlmaLinux dependencies resolve against BaseOS/AppStream at
    # provisioning time - the override keeps them on the compose.
    for arch in x86_64 aarch64; do
        inject_repo_override "http/almalinux-${major}.gcp-${arch}.ks" "${major}" "${arch}"
        inject_gpg_import "http/almalinux-${major}.gcp-${arch}.ks"
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

# ---------------------------------------------------------------------------
# AWS AMI roles: repository override for the chroot bootstrap (see the
# header). 9/10 only - no PUNGI hosts for 8, Kitten is a rolling stream.

inject_ami_repo_override() {
    # inject_ami_repo_override <major> <arch> - inject the pungi.repo write
    # into the AMI role's os.yaml (before the first dnf step) and its removal
    # into cleanup.yaml. Idempotent: skipped when already present.
    local major="$1" arch="$2" base tmp
    local os_yaml="ansible/roles/ami_${major}_${arch}/tasks/os.yaml"
    local cleanup_yaml="ansible/roles/ami_${major}_${arch}/tasks/cleanup.yaml"
    [ -e "${os_yaml}" ] || return 0
    if ! grep -q 'pungi\.repo' "${os_yaml}"; then
        if ! grep -q '^- name: Update the system' "${os_yaml}"; then
            echo "[Error] ${os_yaml} has no 'Update the system' task, cannot inject the repo override"
            exit 1
        fi
        base="https://$(arch_dash "${arch}")-pungi-${major}.almalinux.dev/almalinux/${major}/${arch}/latest_result_almalinux/compose"
        tmp=$(mktemp)
        cat > "${tmp}" <<EOF
# PUNGI: the almalinux-repos package just seeded the chroot with the
# released-version repositories; give the pre-release compose priority for
# the dnf steps below. Written to the host too: the 9 roles' 'Update the
# system' task uses the ansible dnf module, which reads the host repository
# configuration. Removed again by the cleanup.yaml task
# tools/pungi-repos.sh injects.
- name: PUNGI - point the host and the chroot at the pre-release repositories
  ansible.builtin.copy:
    dest: "{{ item }}"
    mode: "0644"
    content: |
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
  loop:
    - /etc/yum.repos.d/pungi.repo
    - /rootfs/etc/yum.repos.d/pungi.repo

EOF
        awk -v ins="${tmp}" '
            /^- name: Update the system/ && !done {
                while ((getline line < ins) > 0) print line
                close(ins)
                done = 1
            }
            { print }
        ' "${os_yaml}" > "${os_yaml}.pungi.tmp" && mv "${os_yaml}.pungi.tmp" "${os_yaml}"
        rm -f "${tmp}"
        echo "[Info]   AMI repo override injected: ${os_yaml}"
    fi

    if ! grep -q 'pungi\.repo' "${cleanup_yaml}"; then
        if [ "$(head -n 1 "${cleanup_yaml}")" != "---" ]; then
            echo "[Error] ${cleanup_yaml} does not start with '---', cannot inject the override removal"
            exit 1
        fi
        {
            echo "---"
            echo "- name: PUNGI - remove the pre-release repositories override"
            echo "  ansible.builtin.file:"
            echo "    path: \"{{ item }}\""
            echo "    state: absent"
            echo "  loop:"
            echo "    - /etc/yum.repos.d/pungi.repo"
            echo "    - /rootfs/etc/yum.repos.d/pungi.repo"
            echo ""
            tail -n +2 "${cleanup_yaml}"
        } > "${cleanup_yaml}.pungi.tmp" && mv "${cleanup_yaml}.pungi.tmp" "${cleanup_yaml}"
        echo "[Info]   AMI override removal injected: ${cleanup_yaml}"
    fi
}

for major in "${MAJORS[@]}"; do
    for arch in x86_64 aarch64; do
        inject_ami_repo_override "${major}" "${arch}"
    done
done

echo "[Info] PUNGI rewrite complete"
