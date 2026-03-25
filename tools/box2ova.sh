#!/bin/bash
#
# box2ova.sh - Convert a Vagrant VMware Desktop .box to a vSphere/ESXi .ova
#
# This script extracts a Vagrant .box archive, re-enables cloud-init
# networking inside the disk image (disabled for Vagrant environments),
# and converts the result to an OVA template using VMware's ovftool.
#
# Usage: box2ova.sh <path-to-box-file>
#
# Requirements: qemu-img, libguestfs (virt-customize), ovftool, tar, unzip
# Supported on: AlmaLinux 9, AlmaLinux 10 (and compatible EL distros)
#

set -euo pipefail

PROG=$(basename "$0")

# Default hardware version: 20 = ESXi 8.0 U1+
# Override with HW_VERSION environment variable if needed.
HW_VERSION="${HW_VERSION:-20}"

usage() {
    echo "Usage: ${PROG} <path-to-box-file>"
    echo ""
    echo "Convert a Vagrant VMware Desktop .box file to a vSphere/ESXi .ova template."
    echo ""
    echo "Environment variables:"
    echo "  HW_VERSION  VMware hardware version (default: 20, ESXi 8.0 U1+)"
    exit 1
}

log() {
    echo "[${PROG}] $*"
}

die() {
    echo "[${PROG}] ERROR: $*" >&2
    exit 1
}

if [ $# -lt 1 ] || [ -z "$1" ]; then
    usage
fi

BOX_FILE="$1"

if [ ! -f "${BOX_FILE}" ]; then
    die "File not found: ${BOX_FILE}"
fi

# --- Step 1: Install required system packages ---

log "Step 1: Installing required system packages..."

EXTRA_PKGS=""
if [ -f /etc/os-release ]; then
    VERSION_ID=$(rpm -E %rhel)
    # EL10 needs libxcrypt-compat for ovftool
    if [[ "${VERSION_ID}" == "10" ]]; then
        log "EL10 detected, adding 'libxcrypt-compat' for ovftool compatibility."
        EXTRA_PKGS="libxcrypt-compat"
    fi
fi

# shellcheck disable=SC2086
sudo dnf install -y libguestfs guestfs-tools libnsl qemu-img unzip ${EXTRA_PKGS}

# --- Step 2: Check / install ovftool ---

log "Step 2: Checking ovftool installation..."

OVFTOOL=""
if command -v ovftool &> /dev/null; then
    OVFTOOL=$(command -v ovftool)
    log "ovftool found in PATH: ${OVFTOOL}"
elif [ -x /opt/ovftool/ovftool ]; then
    OVFTOOL=/opt/ovftool/ovftool
    log "ovftool found at ${OVFTOOL}"
else
    log "ovftool not found. Attempting auto-install from local .zip..."
    ZIP_FILE=$(find . -maxdepth 1 -name 'VMware-ovftool-*-lin.x86_64.zip' -print -quit 2>/dev/null || true)

    if [ -z "${ZIP_FILE}" ]; then
        die "OVF Tool is not installed and no VMware-ovftool-*-lin.x86_64.zip was found in the current directory.
Please download the 'OVF Tool for Linux Zip' from Broadcom and place it here."
    fi

    log "Unpacking ${ZIP_FILE} to /opt/..."
    sudo unzip -q "${ZIP_FILE}" -d /opt/

    OVFTOOL=/opt/ovftool/ovftool
    log "ovftool unpacked to ${OVFTOOL}"
fi

# --- Step 3: Extract the .box archive ---

TMP_DIR=$(mktemp -d)
trap 'log "Cleaning up temporary directory..."; rm -rf "${TMP_DIR}"' EXIT

log "Step 3: Extracting '${BOX_FILE}'..."
tar -xf "${BOX_FILE}" -C "${TMP_DIR}"

VMX_FILE=$(find "${TMP_DIR}" -name "*.vmx" ! -name "._*" -print -quit)
VMDK_FILE=$(find "${TMP_DIR}" -name "*.vmdk" ! -name "*-s[0-9]*.vmdk" ! -name "*-flat.vmdk" ! -name "._*" -print -quit)

if [ -z "${VMDK_FILE}" ] || [ -z "${VMX_FILE}" ]; then
    die "Could not find the main .vmdk or .vmx file inside the .box archive."
fi

log "Found VMX: ${VMX_FILE}"
log "Found VMDK: ${VMDK_FILE}"

# --- Step 4: Derive the OVA template name ---

log "Step 4: Determining template name from VMX metadata..."

# Extract displayname from VMX, stripping carriage returns
RAW_NAME=$(grep -i '^displayname[[:space:]]*=' "${VMX_FILE}" | cut -d '"' -f 2 | tr -d '\r' || true)

# Fallback to box filename without extension
if [ -z "${RAW_NAME}" ]; then
    RAW_NAME=$(basename "${BOX_FILE}" .box)
fi

# Strip "Vagrant" from the name to produce a clean enterprise template name
CLEAN_NAME=$(echo "${RAW_NAME}" | sed -e 's/-[Vv]agrant//g' -e 's/[Vv]agrant-//g' -e 's/[Vv]agrant//g')
OUTPUT_OVA="${CLEAN_NAME}.ova"

log "Target OVA: ${OUTPUT_OVA}"

# --- Step 5: Convert VMDK to RAW for safe editing ---

log "Step 5: Converting VMDK to RAW format..."
qemu-img convert -O raw "${VMDK_FILE}" "${VMDK_FILE}.raw"

# --- Step 6: Re-enable cloud-init networking inside the disk ---

log "Step 6: Re-enabling cloud-init networking inside disk image..."

# Running as root via sudo to avoid strict kernel read permissions on newer OSs (EL10).
# LIBGUESTFS_MEMSIZE=768 prevents OOM kills on smaller build servers.
sudo env LIBGUESTFS_BACKEND=direct LIBGUESTFS_MEMSIZE=768 \
    virt-customize --format raw -a "${VMDK_FILE}.raw" --run-command '
        CFG="/etc/cloud/cloud.cfg.d/99_vagrant.cfg"
        if [ -f "$CFG" ]; then
            sed -i "/network: {config: disabled}/d" "$CFG"
            echo "cloud-init network config restriction removed from $CFG"
        else
            echo "WARNING: $CFG not found, skipping."
        fi
    '

# Reclaim ownership before packing
sudo chown "$(id -u):$(id -g)" "${VMDK_FILE}.raw"

# --- Step 7: Re-pack RAW back to VMDK ---

log "Step 7: Converting RAW back to VMDK..."
qemu-img convert -f raw -O vmdk -o subformat=monolithicSparse "${VMDK_FILE}.raw" "${VMDK_FILE}"
rm -f "${VMDK_FILE}.raw"

# --- Step 8: Convert to OVA ---

log "Step 8: Converting to OVA (hardware version ${HW_VERSION})..."
${OVFTOOL} --maxVirtualHardwareVersion="${HW_VERSION}" \
        --name="${CLEAN_NAME}" \
        --annotation="AlmaLinux OS Enterprise Template" \
        "${VMX_FILE}" "${OUTPUT_OVA}"

log "Done. Enterprise template saved as: ${OUTPUT_OVA}"
