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

echo "[Info] PUNGI rewrite complete"
