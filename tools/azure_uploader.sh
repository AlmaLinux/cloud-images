#!/bin/bash
# authors:
#   Eugene Zamriy <ezamriy@almalinux.org>
#   Yuriy Kohut <ykohut@almalinux.org>
# created: 2022-10-20
# modified: 2025-08-22
# description: Converts a raw image to a fixed VHD and uploads it to an Azure
#              storage container and a compute gallery.
#
# dependencies:
#   - azure-cli
#   - qemu-img
#   - jq

set -eo pipefail

SIMULATE=1
DISTRO_VER=''
INPUT_IMAGE=''
IMAGE_TYPE=''
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
  echo '  -t        product type. Possible values are: default, arm64 and arm64-64k.'
  echo '  -d        distribution version (e.g. "8.10", "9.6", "10.0" and "10" if Kitten)'
  echo "  -g        Azure compute gallery name. Default is ${GALLERY_NAME}"
  echo "  -r        Azure resource group name. Default is ${RESOURCE_GROUP}"
  echo "  -s        Azure storage account name. Default is ${STORAGE_ACCOUNT}"
  echo '  -u        image blob URI in case if it is already uploaded'
  echo '  -f        perform all operations (by default script runs in dry-run mode)'
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

# Executes a command or prints it in dry-run mode.
# It checks the $SIMULATE variable and either prints or executes the command.
#
# $@ - a command and its arguments
#
execute() {
  if [[ "$SIMULATE" -eq 1 ]]; then
    echo "[DRY RUN] Would execute:"
    printf "  %q" "$@" # "$@" refers to all arguments passed to the function
    echo
  else
    echo "[EXEC] Running: $1..."
    "$@" # Execute the command and its arguments
  fi
}

# Checks if an image type is supported.
#
# $1 - image type.
#
# Terminates the program if the image type is not supported.
assert_image_type() {
  local -r image_type="${1}"
  case "${image_type}" in
    arm64-64k | arm64 | default ) return 0 ;;
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
    error 'required arguments -d and/or -t are not defined'
    exit 1
  fi
  if [[ -z "${INPUT_IMAGE}" && -z "${IMAGE_URI}" ]]; then
    error 'either image path (-i argument) or blob URI (-u argument) is required'
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

# Guesses an OS architecture by an Azure image type.
#
# $1 - Azure image type.
# $2 - distribution major version (e.g. 8, 9, 10).
#
# Prints an OS architecture to stdout.
get_image_arch() {
  local -r image_type="${1}"
  local -r major_ver="${2}"
  assert_image_type "${image_type}"
  case "${image_type}" in
    arm64)
      case "${major_ver}" in
        10) echo 'aarch64' ;;
        *) echo 'arm64' ;;
      esac
      ;;
    arm64-64k) echo 'aarch64' ;;
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
# $4 - distribution major version (e.g. 8, 9, 10).
#
# Prints a unique image index to stdout.
get_next_image_idx() {
    local -r account="${1}"
    local -r container_name="${2}"
    local -r image_name="${3}"
    local -r major_ver="${4}"
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
                    | grep -oP "${image_name//./\\.}" | wc -l)"
    local rslt
    [ -z "${idx}" ] && rslt=1 || rslt=$((idx + 1))
    if [[ "${major_ver}" == '10' || ( "${major_ver}" == '9' && "${IMAGE_TYPE}" == 'arm64-64k' ) ]]; then
      rslt=$((rslt - 1))
      printf "%d" ${rslt}
    else
      printf "%02d" ${rslt}
    fi
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
  if [[ $SIMULATE -eq 0  ]]; then
    az storage blob url "${args[@]}"
  else
    echo "https://${account}.blob.core.windows.net/${container}/${blob_name}"
  fi
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
execute az storage blob upload "${args[@]}"

}

# Generates an Azure compute gallery image definition name based on an image
# type, distribution version and VM generation.
#
# $1 - Image type.
# $2 - Distribution version (e.g. 9.0).
# $3 - VM generation (1 or 2), optional.
#
# Prints an image definition name to stdout, like:
#   almalinux-ci-kitten-10-arm64-gen2
#   almalinux-ci-kitten-10-x64-gen1
#   almalinux-ci-kitten-10-x64-gen2
#   almalinux-ci-10-arm64-gen2
#   almalinux-ci-10-arm64-64k-gen2
#   almalinux-10
#   almalinux-9-arm64
#   almalinux-9-arm64-64k
#   almalinux-9-gen1
#   almalinux-9-gen2
#   almalinux-8-arm64
#   almalinux-8-gen1
#   almalinux-8-gen2
get_image_definition_name() {
    local -r image_type="${1}"
    local -r distro_ver="${2}"
    local -r generation="${3}"
    local -r major_ver=${distro_ver%%.*}
    local prefix='almalinux'
    local postfix=''
    case "${distro_ver}" in
      10)
        prefix='almalinux-ci-kitten'
        if [[ "${image_type}" == 'arm64'* ]]; then
          postfix="-${image_type}-gen${generation}"
        else
          postfix="-x64-gen${generation}"
        fi
        ;;
      10.*)
        if [[ "${image_type}" == 'arm64'* ]]; then
          prefix='almalinux-ci'
          postfix="-${image_type}-gen${generation}"
        fi
        ;;
      *)
        if [[ "${image_type}" == 'arm64'* ]]; then
          postfix="-${image_type}"
        else
          postfix="-gen${generation}"
        fi
        ;;
    esac
    echo "${prefix}-${major_ver}${postfix}"
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
    execute az sig image-version create \
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
  local -r image_def="$(get_image_definition_name "${IMAGE_TYPE}" "${DISTRO_VER}" "2")"
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

# Generates an Azure Storage container name, base on distributive version and image type
#
# $1 - Distribution version (e.g. 9.0).
# $2 - Image type.
#
# Prints a container name to stdout, like:
#   8-arm64, 8-default
#   9-arm64, 9-arm64-64k, 9-default
#   almalinux-10
#   kitten-10
get_container_name() {
  local -r distro_ver="${1}"
  local -r image_type="${2}"
  local -r major_ver=${distro_ver%%.*}

  case "${distro_ver}" in
    10) echo "kitten-${distro_ver}" ;;
    10.*) echo "almalinux-${major_ver}"  ;;
    *)
      if [[ "${image_type}" == 'arm64-64k' && "${major_ver}" == '8' ]]; then
        exit 1
      fi
      echo "${major_ver}-${image_type}"
      ;;
  esac
}

# Generates image file name, excluding extension
#
# $1 - Distribution version (e.g. 9.0).
# $2 - Image type.
# $3 - Date in YYYYMMDD format.
# $4 - the index number
#
# Prints an image name to stdout, like:
#   almalinux-8.10-arm64.20240603-02
#   almalinux-8.10-x86_64.20240603-02
#   almalinux-9.6-arm64.20250522-01
#   AlmaLinux-Azure-9.6-202505220-64k.aarch64
#   almalinux-9.6-x86_64.20250522-01
#   AlmaLinux-10-Azure-10.0-20250529.0-64k.aarch64
#   AlmaLinux-10-Azure-10.0-20250529.0.aarch64
#   AlmaLinux-10-Azure-10.0-20250529.0.x86_64
#   AlmaLinux-Kitten-Azure-10-20250813.0.aarch64
#   AlmaLinux-Kitten-Azure-10-20250813.0.x86_64
get_image_name() {
  local -r distro_ver="${1}"
  local -r image_type="${2}"
  local -r date="${3}"
  local -r idx="${4}"
  local -r major_ver=${distro_ver%%.*}
  local -r arch="$(get_image_arch "${image_type}" "${major_ver}")"

  case "${distro_ver}" in
    10)
      if [[ "${image_type}" == 'arm64-64k' ]]; then
        echo "AlmaLinux-Kitten-Azure-${distro_ver}-${date}.${idx}-64k.${arch}"
        return
      fi
      echo "AlmaLinux-Kitten-Azure-${distro_ver}-${date}.${idx}.${arch}"
      ;;
    10.*)
      if [[ "${image_type}" == 'arm64-64k' ]]; then
        echo "AlmaLinux-${major_ver}-Azure-${distro_ver}-${date}.${idx}-64k.${arch}"
        return
      fi
      echo "AlmaLinux-${major_ver}-Azure-${distro_ver}-${date}.${idx}.${arch}"
      ;;
    *)
      if [[ "${image_type}" == 'arm64-64k' ]]; then
        echo "AlmaLinux-Azure-${distro_ver}-${date}${idx}-64k.${arch}"
        return
      fi
      echo "almalinux-${distro_ver}-${arch}.${date}-${idx}"
      ;;
  esac
}

# Guesses an image date and index from the input image name or URI.
#
# Prints the date in YYYYMMDD format and the index to stdout, separated by a space.
get_date_and_idx() {
  local date_idx
  if [[ -n "${INPUT_IMAGE}" ]]; then
    date_idx="$(basename "${INPUT_IMAGE}" | grep -oP '\d{8}\.?\d')"
    date="${date_idx:0:8}"
    idx="${date_idx: -1}"
  fi
  if [[ -n "${IMAGE_URI}" ]]; then
    if [[ $IMAGE_URI =~ ([0-9]{8})[.-]?([0-9]*) ]]; then
      date="${BASH_REMATCH[1]}"
      idx="${BASH_REMATCH[2]}"
    fi
  fi

  echo "${date} ${idx}"
}

# calculate MD5 checksum of the created blob or use a dummy one in dry-run mode
#
# $1 - blob (image file) name
#
# Prints MD5 checksum (or dummy 32 x's in dry-run mode) to stdout.
get_blob_md5() {
  local -r blob_name="${1}"

  if [[ $SIMULATE -eq 0 ]]; then
    md5sum "${blob_name}" | cut -d' ' -f1
  else
    echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  fi
}

main() {
  local -r major_ver=${DISTRO_VER%%.*}
  local -r arch="$(get_image_arch "${IMAGE_TYPE}" "${major_ver}")"

  # get date and index from the input image name or URI
  read -r image_date image_idx <<< "$(get_date_and_idx)"

  # calculate Azure storage account container name
  container_name="$(get_container_name "${DISTRO_VER}" "${IMAGE_TYPE}")"

  # Image name and version considering current raw image file
  image_name="$(get_image_name "${DISTRO_VER}" "${IMAGE_TYPE}" \
                                    "${image_date}" "${image_idx}")"
  local image_ver="${DISTRO_VER}.${image_date}${image_idx}"
  [[ "${DISTRO_VER}" == 10 ]] && image_ver="${DISTRO_VER}.${image_date}.${image_idx}"

  # create a new image definition version and exit if an image has been
  # previously uploaded
  if [[ -n "${IMAGE_URI}" ]]; then
    if [[ "${IMAGE_TYPE}" == 'arm64'* ]]; then
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
  local -r idx="$(get_next_image_idx "${STORAGE_ACCOUNT}" "${container_name}" \
                                     "${image_name}" "${major_ver}")"
  # Image name and version considering incremented index
  image_name="$(get_image_name "${DISTRO_VER}" "${IMAGE_TYPE}" \
                                    "${image_date}" "${idx}")"
  local image_ver="${DISTRO_VER}.${image_date}${idx}"
  [[ "${DISTRO_VER}" == 10 ]] && image_ver="${DISTRO_VER}.${image_date}.${idx}"
  local -r blob_name="${image_name}.vhd"
  # convert input image to fixed VHD blob with size rounded to 1 MB
  local -r blob_size="$(get_rounded_size "${INPUT_IMAGE}")"
  # Get actual image size in bytes
  local actual_size
  actual_size=$(qemu-img info -f raw --output json "${INPUT_IMAGE}" | jq '.["virtual-size"]')

  # Only resize if needed
  if [ "$actual_size" -ne "$blob_size" ]; then
    execute qemu-img resize -q -f raw "${INPUT_IMAGE}" "${blob_size}"
  else
    echo "Image already aligned to $blob_size, skipping resize."
  fi

  execute qemu-img convert -f raw -o subformat=fixed,force_size -O vpc \
    "${INPUT_IMAGE}" "${blob_name}"
  local -r blob_md5="$(get_blob_md5 "${blob_name}")"
  upload_image_blob "${STORAGE_ACCOUNT}" "${container_name}" "${blob_name}" \
                    "${blob_md5}"
  local -r blob_uri="$(get_blob_uri "${STORAGE_ACCOUNT}" "${container_name}" \
                                    "${blob_name}")"
  echo "Image URI: ${blob_uri}"
  if [[ "${IMAGE_TYPE}" == 'arm64'* ]]; then
    upload_arm_image_version "${image_ver}" "${blob_uri}"
  else
    upload_intel_image_version "${image_ver}" "${blob_uri}"
  fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  while getopts "hfd:i:o:t:g:r:s:u:v" opt; do
    case "${opt}" in
      h)
        show_usage
        exit 0
        ;;
      f)
        SIMULATE=0
        readonly SIMULATE
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
