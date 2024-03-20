#!/bin/bash
# author: Eugene Zamriy <ezamriy@almalinux.org>
# created: 2022-10-20
# description: Converts a raw image to a fixed VHD and uploads it to an Azure
#              storage container and a compute gallery.
#
# dependencies:
#   - azure-cli
#   - qemu-img
#   - jq

set -eo pipefail

DISTRO_VER=''
INPUT_IMAGE=''
IMAGE_TYPE='default'
IMAGE_URI=''
# Azure compute gallery name
GALLERY_NAME='almalinux_ci'
# Azure resource group name
RESOURCE_GROUP='rg-alma-images'
# Azure storage account name
STORAGE_ACCOUNT='almalinux'
# list of target Azure regions and replicas count
TARGET_REGIONS=('eastus=1' 'germanywestcentral=1' 'westus2=1' \
                'southeastasia=1' 'southcentralus=1')
# Enable extra debug output if 1
VERBOSE=0


show_usage() {
  echo -e 'Converts a raw image to a fixed VHD and uploads it to Azure\n'
  echo '  -i        raw image path to upload'
  echo '  -t        product type. Possible values are: default, hpc and arm64.'
  echo '            Default value is "default".'
  echo '  -d        distribution version (e.g. "8.6" or "9.0")'
  echo "  -g        Azure compute gallery name. Default is ${GALLERY_NAME}"
  echo "  -r        Azure resource group name. Default is ${RESOURCE_GROUP}"
  echo "  -s        Azure storage account name. Default is ${STORAGE_ACCOUNT}"
  echo '  -u        image blob URI in case if it is already uploaded'
  echo '  -h        display this help message and exit'
  echo '  -v        enable additional debug output'
}

# Prints a debug message to stderr if verbose mode is enabled.
debug() {
  if [[ ${VERBOSE} -eq 1 ]]; then
    echo "DEBUG: $*" >&2
  fi
}

# Prints an error message to stderr.
error() {
  echo "ERROR: $*" >&2
}

# Checks if an image type is supported.
#
# $1 - image type.
#
# Terminates the program if the image type is not supported.
assert_image_type() {
  local -r image_type="${1}"
  case "${image_type}" in
    arm64 | default | hpc) return 0 ;;
    *)
      error "unsupported image type '${image_type}'"
      exit 1
      ;;
  esac
}

# Validates global variables set by command line arguments and terminates
# the program if validation failed.
validate_args() {
  if [[ -z "${DISTRO_VER}" || -z "${IMAGE_TYPE}" ]]; then
    error 'required arguments are not defined'
    exit 1
  fi
  if [[ -z "${INPUT_IMAGE}" && -z "${IMAGE_URI}" ]]; then
    error 'either image path or blob URI is required'
    exit 1
  fi
}

# Calculates a raw image size rounded to 1 MB.
#
# $1 - Raw image path to calculate rounded size for.
#
# Prints rounded size to stdout.
get_rounded_size() {
    local -r img_path="${1}"
    local -r mb=$((1024 * 1024))
    local -r size=$(qemu-img info -f raw --output json "${img_path}" \
                    | jq '."virtual-size"')
    echo $((((size + mb - 1) / mb) * mb))
}

# Generates a product (Azure disk) name for the specified image type.
#
# $1 - image type.
#
# Prints a product name to stdout.
get_product_name() {
  local -r image_type="${1}"
  assert_image_type "${image_type}"
  local product='almalinux'
  if [[ "${image_type}" == 'hpc' ]]; then
    product="${product}-hpc"
  fi
  echo "${product}"
}

# Guesses an OS architecture by an Azure image type.
#
# $1 - Azure image type.
#
# Prints an OS architecture to stdout.
get_image_arch() {
  local -r image_type="${1}"
  assert_image_type "${image_type}"
  case "${image_type}" in
    arm64) echo 'arm64' ;;
    *) echo 'x86_64' ;;
  esac
}

# Calculates a next unique index for an Azure image.
#
# That index will be added to the end of a new image file name so that we
# can ensure its uniqueness.
#
# $1 - Azure storage account name.
# $2 - Azure storage container name.
# $3 - image file name.
#
# Prints a unique image index to stdout.
get_next_image_idx() {
    local -r account="${1}"
    local -r container_name="${2}"
    local -r image_name="${3}"
    # find all blobs which name starts with a given image name using the
    # Azure JMESPath query language.
    # TODO: check last image definition version index as well to handle cases
    #       when a version has been created manually or by URL
    declare -a args=(--container-name "${container_name}" \
                     --account-name "${account}" \
                     --query "[?starts_with(name, '${image_name}')].name")
    if [[ ${VERBOSE} -ne 1 ]]; then
      args+=(--only-show-errors)
    fi
    local -r blobs="$(az storage blob list "${args[@]}")"
    local -r idx="$(echo "${blobs}" | jq -r 'join("\n")' \
                    | grep -oP "${image_name//./\\.}-\K\d+" \
                    | sort -n | tail -n 1)"
    local rslt
    [ -z "${idx}" ] && rslt=1 || rslt=$(((idx + 1)))
    printf "%02d" ${rslt}
}

# Returns an Azure storage container blob URI.
#
# $1 - Azure storage account name.
# $2 - Azure storage container name.
# $3 - blob name
#
# Prints a blob URI to stdout.
get_blob_uri() {
  local -r account="${1}"
  local -r container="${2}"
  local -r blob_name="${3}"
  declare -a args=(--account-name "${account}" \
                   --container-name "${container}" \
                   --name "${blob_name}" --output tsv)
  if [[ $VERBOSE -ne 1 ]]; then
    args+=(--only-show-errors)
  fi
  az storage blob url "${args[@]}"
}

# Uploads an image to an Azure storage container.
#
# $1 - Azure storage account name.
# $2 - Azure storage container name.
# $3 - Image and a local file name.
# $4 - Image MD5 checksum.
upload_image_blob() {
  local -r account="${1}"
  local -r container="${2}"
  local -r blob_name="${3}"
  local -r blob_md5="${4}"
  declare -a args=(--account-name "${account}" \
                   --container-name "${container}" \
                   --file "${blob_name}" --name "${blob_name}" \
                   --content-md5 "${blob_md5}" --validate-content)
  if [[ $VERBOSE -ne 1 ]]; then
    args+=(--only-show-errors --no-progress)
  fi
  debug "uploading blob \"${blob_name}\" (MD5: ${blob_md5}) to "\
        "${account}.${container} storage container"
  az storage blob upload "${args[@]}"
}

# Generates an Azure compute gallery image definition name based on an image
# type, distribution version and VM generation.
#
# $1 - Image type.
# $2 - Distribution version (e.g. 9.0).
# $3 - VM generation (1 or 2), optional.
#
# Prints an image definition name to stdout.
get_image_definition_name() {
    local -r image_type="${1}"
    local -r distro_ver="${2}"
    local -r generation="${3}"
    local -r major_ver=$(echo "${distro_ver}" | cut -c 1-1)
    local -r product=$(get_product_name "${image_type}")
    local postfix=''
    if [[ "${image_type}" == 'arm64' ]]; then
        postfix='arm64'
    else
        postfix="gen${generation}"
    fi
    echo "${product}-${major_ver}-${postfix}"
}

# Creates a new image definition version in an Azure compute gallery.
#
# $1 - Image definition name.
# $2 - Image version.
# $3 - Image URI.
upload_image_version() {
    local -r image_def="${1}"
    local -r image_ver="${2}"
    local -r image_uri="${3}"
    debug "uploading image ${image_uri} as \"${image_ver}\" image version "\
          "of ${GALLERY_NAME}.${image_def} image definition"
    az sig image-version create \
        --resource-group "${RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${image_def}" \
        --gallery-image-version "${image_ver}" \
        --os-vhd-uri "${image_uri}" \
        --os-vhd-storage-account "${STORAGE_ACCOUNT}" \
        --target-regions "${TARGET_REGIONS[@]}"
}

# Creates a new ARM image definition version in an Azure compute gallery.
#
# $1 - Image version.
# $2 - Image URI.
#
# Prints a created version and a definition name to stdout.
upload_arm_image_version() {
  local -r image_ver="${1}"
  local -r image_uri="${2}"
  local -r image_def="$(get_image_definition_name 'arm64' "${DISTRO_VER}")"
  upload_image_version "${image_def}" "${image_ver}" "${image_uri}"
  echo "Created ${GALLERY_NAME}.${image_def} image definition version: "\
       "${image_ver}"
}

# Creates a new Intel image definition version in an Azure compute gallery.
#
# $1 - Image version.
# $2 - Image URI.
#
# Prints a created version and a definition name to stdout.
upload_intel_image_version() {
  local -r image_ver="${1}"
  local -r image_uri="${2}"
  local image_def
  for gen in 1 2; do
    image_def="$(get_image_definition_name "${IMAGE_TYPE}" "${DISTRO_VER}" \
                                           "${gen}")"
    upload_image_version "${image_def}" "${image_ver}" "${image_uri}"
    echo "Created ${GALLERY_NAME}.${image_def} image definition version: "\
         "${image_ver}"
  done
}


main() {
  local -r today="$(date '+%Y%m%d')"
  local -r major_ver=$(echo "${DISTRO_VER}" | cut -c 1-1)
  local -r arch="$(get_image_arch "${IMAGE_TYPE}")"
  local -r product="$(get_product_name "${IMAGE_TYPE}")"
  # calculate Azure storage account container name
  local -r container_name="${major_ver}-${IMAGE_TYPE}"
  # converted image output file name. Don't change the pattern or you will
  # break the get_next_image_idx function logic.
  local -r image_name="${product}-${DISTRO_VER}-${arch}.${today}"
  local -r idx="$(get_next_image_idx "${STORAGE_ACCOUNT}" "${container_name}" \
                                     "${image_name}")"
  local -r image_ver="${DISTRO_VER}.${today}${idx}"
  # create a new image definition version and exit if an image has been
  # previously uploaded
  if [[ -n "${IMAGE_URI}" ]]; then
    if [[ "${IMAGE_TYPE}" == 'arm64' ]]; then
      upload_arm_image_version "${image_ver}" "${IMAGE_URI}"
    else
      upload_intel_image_version "${image_ver}" "${IMAGE_URI}"
    fi
    exit 0
  fi
  #
  # upload a new image to a storage container and create a new image definition
  # version from it
  #
  local -r blob_name="${image_name}-${idx}.vhd"
  # convert input image to fixed VHD blob with size rounded to 1 MB
  local -r blob_size="$(get_rounded_size "${INPUT_IMAGE}")"
  qemu-img resize -q -f raw "${INPUT_IMAGE}" "${blob_size}"
  qemu-img convert -f raw -o subformat=fixed,force_size -O vpc \
    "${INPUT_IMAGE}" "${blob_name}"
  local -r blob_md5=$(md5sum "${blob_name}" | cut -d' ' -f1)
  upload_image_blob "${STORAGE_ACCOUNT}" "${container_name}" "${blob_name}" \
                    "${blob_md5}"
  local -r blob_uri="$(get_blob_uri "${STORAGE_ACCOUNT}" "${container_name}" \
                                    "${blob_name}")"
  echo "Image URI: ${blob_uri}"
  if [[ "${IMAGE_TYPE}" == 'arm64' ]]; then
    upload_arm_image_version "${image_ver}" "${blob_uri}"
  else
    upload_intel_image_version "${image_ver}" "${blob_uri}"
  fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  while getopts "hd:i:o:t:g:r:s:u:v" opt; do
    case "${opt}" in
      h)
        show_usage
        exit 0
        ;;
      i)
        INPUT_IMAGE="${OPTARG}"
        readonly INPUT_IMAGE
        ;;
      d)
        DISTRO_VER="${OPTARG}"
        readonly DISTRO_VER
        ;;
      g)
        GALLERY_NAME="${OPTARG}"
        readonly GALLERY_NAME
        ;;
      r)
        RESOURCE_GROUP="${OPTARG}"
        readonly RESOURCE_GROUP
        ;;
      s)
        STORAGE_ACCOUNT="${OPTARG}"
        readonly STORAGE_ACCOUNT
        ;;
      t)
        assert_image_type "${OPTARG}"
        IMAGE_TYPE="${OPTARG}"
        readonly IMAGE_TYPE
        ;;
      u)
        IMAGE_URI="${OPTARG}"
        readonly IMAGE_URI
        ;;
      v)
        VERBOSE=1
        readonly VERBOSE
        ;;
      *) exit 1 ;;
    esac
  done

  validate_args
  main
fi
