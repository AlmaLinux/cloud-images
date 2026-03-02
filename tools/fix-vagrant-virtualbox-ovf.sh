#!/bin/bash
# tools/fix-vagrant-virtualbox-ovf.sh
#
# Strips EFI NVRAM hardware item (resource type 32768) from VirtualBox OVF
# inside a Vagrant .box file. VirtualBox 7.1+ exports NVRAM as a vendor-
# specific OVF resource that older VirtualBox versions cannot import.
#
# Usage: tools/fix-vagrant-virtualbox-ovf.sh <path-to.box>

set -euo pipefail

BOX_FILE="$1"

if [[ ! -f "${BOX_FILE}" ]]; then
    echo "ERROR: Box file not found: ${BOX_FILE}"
    exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

# Extract the box (gzipped tar)
tar -xzf "${BOX_FILE}" -C "${WORK_DIR}"

OVF_FILE=$(find "${WORK_DIR}" -maxdepth 1 -name '*.ovf' -print -quit)

if [[ -z "${OVF_FILE}" ]]; then
    echo "WARNING: No .ovf file found in box, skipping: ${BOX_FILE}"
    exit 0
fi

# Check if the NVRAM item (resource type 32768) exists
if ! grep -q 'ResourceType>32768<' "${OVF_FILE}"; then
    echo "No NVRAM item (resource type 32768) found, nothing to fix: ${BOX_FILE}"
    exit 0
fi

echo "Stripping NVRAM (resource type 32768) from: ${BOX_FILE}"

# Use Python to strip the NVRAM Item and its File reference from the OVF
python3 -c "
import re, sys

ovf_file = sys.argv[1]

with open(ovf_file, 'r') as f:
    content = f.read()

# Find the Item block containing ResourceType 32768
nvram_match = re.search(
    r'\s*<Item>\s*.*?<rasd:ResourceType>32768</rasd:ResourceType>.*?</Item>',
    content, re.DOTALL)

if not nvram_match:
    print('No ResourceType 32768 Item found')
    sys.exit(0)

# Extract the file reference ID (e.g., 'file1' from 'ovf:/file/file1')
file_ref_id = None
href_match = re.search(r'ovf:/file/(\w+)', nvram_match.group())
if href_match:
    file_ref_id = href_match.group(1)

# Remove the NVRAM Item block
content = content[:nvram_match.start()] + '\n' + content[nvram_match.end():]

# Remove the corresponding File reference from References section
if file_ref_id:
    content = re.sub(
        r'\s*<File[^>]*ovf:id=\"' + re.escape(file_ref_id) + r'\"[^>]*/?>\s*',
        '\n', content)

with open(ovf_file, 'w') as f:
    f.write(content)

print('Removed NVRAM Item (ResourceType 32768)' +
      (f' and File reference \"{file_ref_id}\"' if file_ref_id else ''))
" "${OVF_FILE}"

# Remove .nvram files from the extracted box
find "${WORK_DIR}" -maxdepth 1 -name '*.nvram' -print -delete | while read -r f; do
    echo "Removed: $(basename "${f}")"
done

# Repackage the box (gzipped tar, files at root level)
(cd "${WORK_DIR}" && tar -czf box_fixed.tar.gz ./*)
mv "${WORK_DIR}/box_fixed.tar.gz" "${BOX_FILE}"

echo "Fixed: ${BOX_FILE}"
