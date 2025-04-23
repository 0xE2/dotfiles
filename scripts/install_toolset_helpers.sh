#!/usr/bin/env bash
set -e

DEFAULT_BIN_DIR="/usr/local/bin"
BIN_DIR=${1:-"${DEFAULT_BIN_DIR}"}
GITHUB_REPO=""

# Helper functions for logs
info() {
    echo '[INFO] ' "$@"
}

warn() {
    echo '[WARN] ' "$@" >&2
}

fatal() {
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# Set OS, fatal if operating system not supported
setup_verify_os() {
    if [[ -z "${OS}" ]]; then
        OS=$(uname)
    fi
    case ${OS} in
        Darwin)
            OS=darwin
            ;;
        Linux)
            OS=linux
            ;;
        *)
            fatal "Unsupported operating system ${OS}"
    esac
    # info "Operating system: ${OS}"
    export OS
}

# Set arch, fatal if architecture not supported
setup_verify_arch() {
    if [[ -z "${ARCH}" ]]; then
        ARCH=$(uname -m)
    fi
    case ${ARCH} in
        arm|armv6l|armv7l)
            ARCH=arm
            ;;
        arm64|aarch64|armv8l)
            ARCH=arm64
            ;;
        amd64)
            ARCH=amd64
            ;;
        x86_64)
            ARCH=amd64
            ;;
        *)
            fatal "Unsupported architecture ${ARCH}"
    esac
    # info "Architecture: ${ARCH}"
    export ARCH
}

# Verify existence of downloader executable
verify_downloader() {
    # Return failure if it doesn't exist or is no executable
    [[ -x "$(which "$1")" ]] || return 1

    # Set verified executable as our downloader program and return success
    DOWNLOADER=$1
    return 0
}

verify_common_downloaders() {
    verify_downloader curl || verify_downloader wget || fatal 'Can not find curl or wget for downloading files'
}

verify_env() {
    BIN_FILE_TPL
    if [[ -z "${BIN_FILE_TPL}" ]]; then
        fatal "BIN_FILE_TPL is not set, unable to proceed"
    fi
    if [[ -z "${HASH_FILE_TPL}" ]]; then
        warn "HASH_FILE_TPL is not set, skipping hash checks"
        SKIP_HASH_CHECK=1
    fi
}

# envsubst alternative in pure Bash
# Ref: https://gist.github.com/gmolveau/2770f2d05fa5825e1ffdb5a61f0c1283
replace_env_variables() {
    local content="$1"
    local var name value safe_value

    # Extract all occurrences of ${VAR} and filter unique variable names.
    # This regex matches ${VAR} where VAR starts with a letter or underscore and continues with alphanumeric or underscores.
    local vars
    vars=$(echo "$content" | grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' | sort -u)

    # Loop over each extracted variable placeholder
    for var in $vars; do
        # Remove the '${' prefix and '}' suffix to get the variable name.
        name="${var:2:${#var}-3}"

        # Get the environment variable's value
        value=$(printenv "$name")
        if [ -n "$value" ]; then
            # Escape any forward slashes and ampersands for sed replacement.
            safe_value=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')

            # Replace all occurrences of ${VAR} with the actual value
            content=$(echo "$content" | sed "s|\${$name}|$safe_value|g")
        fi
    done

    echo "$content"
}

# Create temporary directory and cleanup when done
setup_tmp() {
    TMP_DIR=$(mktemp -d -t "${TOOL_NAME}-install.XXXXXXXXXX")
    TMP_METADATA="${TMP_DIR}/${TOOL_NAME}.json"
    TMP_HASH="${TMP_DIR}/${TOOL_NAME}.hash"
    TMP_BIN="${TMP_DIR}/${TOOL_NAME}.tar.gz"
    cleanup() {
        info "Cleaning up ${TMP_DIR}"
        local code=$?
        set +e
        trap - EXIT
        rm -rf "${TMP_DIR}"
        exit ${code}
    }
    trap cleanup INT EXIT
}

# Find version from Github metadata
github_get_release_version() {
    local tool_version=${1} raw_tag semver
    if [[ -n "${tool_version}" ]]; then
      SUFFIX_URL="tags/${tool_version}"
    else
      SUFFIX_URL="latest"
    fi

    METADATA_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/${SUFFIX_URL}"

    info "Downloading metadata ${METADATA_URL}"
    github_download "${TMP_METADATA}" "${METADATA_URL}"

    raw_tag=$(grep '"tag_name":' "${TMP_METADATA}" | sed -E 's/.*"([^"]+)".*/\1/')
    RELEASE_VERSION="${raw_tag}"
    export RELEASE_VERSION

    semver=$(echo "${RELEASE_VERSION}" \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
            | head -n1)
    if [[ -z "${semver}" ]]; then
        fatal "Unable to parse semantic version from '${RELEASE_VERSION}'"
    fi
    RELEASE_SEMVER="${semver}"
    export RELEASE_SEMVER

    # BIN_FILE=$(echo "${BIN_FILE_TPL}" | envsubst)
    BIN_FILE=$(replace_env_variables "${BIN_FILE_TPL}")
    if [[ -n "${RELEASE_VERSION}" ]]; then
        info "Using ${RELEASE_VERSION} as release"
        info "Using ${BIN_FILE} as artifact"
    else
        fatal "Unable to determine release version"
    fi
}

# Download from file from URL
github_download() {
    [[ $# -eq 2 ]] || fatal 'download needs exactly 2 arguments'

    case $DOWNLOADER in
        curl)
            curl -u user:$GITHUB_TOKEN -o "$1" -sfL "$2"
            ;;
        wget)
            wget --auth-no-challenge --user=user --password=$GITHUB_TOKEN -qO "$1" "$2"
            ;;
        *)
            fatal "Incorrect executable '${DOWNLOADER}'"
            ;;
    esac

    # Abort if download command failed
    [[ $? -eq 0 ]] || fatal 'GitHub Download failed'
}

# Version comparison
# Returns 0 on '=', 1 on '>', and 2 on '<'.
# Ref: https://stackoverflow.com/a/4025065
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Download hash from Github URL
github_download_hash() {
    if [[ "${SKIP_HASH_CHECK}" -eq 1 ]]; then
        return
    fi
    HASH_URL_TPL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_VERSION}/${HASH_FILE_TPL}"
    # HASH_URL=$(echo "$HASH_URL_TPL" | envsubst)
    HASH_URL=$(replace_env_variables "${HASH_URL_TPL}")

    info "Downloading hash ${HASH_URL}"
    github_download "${TMP_HASH}" "${HASH_URL}"
    HASH_EXPECTED=$(grep " ${BIN_FILE}$" "${TMP_HASH}")
    HASH_EXPECTED=${HASH_EXPECTED%%[[:blank:]]*}
}

# Download binary from Github URL
github_download_binary() {
    BIN_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_VERSION}/${BIN_FILE}"
    info "Downloading binary ${BIN_URL}"
    github_download "${TMP_BIN}" "${BIN_URL}"
}

extract_files() {
    local dest=${1:-"${TMP_DIR}"}
    case "${TMP_BIN}" in
        *.tar.gz)
            tar -xzf "${TMP_BIN}" -C "$dest"
            ;;
        *.zip)
            unzip -q "${TMP_BIN}" -d "$dest"
            ;;
        *)
            fatal "Unknown file format ${TMP_BIN}"
            ;;
    esac
}

compute_sha256sum() {
  cmd=$(which sha256sum shasum | head -n 1)
  case $(basename "$cmd") in
    sha256sum)
      sha256sum "$1" | cut -f 1 -d ' '
      ;;
    shasum)
      shasum -a 256 "$1" | cut -f 1 -d ' '
      ;;
    *)
      fatal "Can not find sha256sum or shasum to compute checksum"
      ;;
  esac
}

# Verify downloaded binary hash
verify_binary() {
    HASH_BIN=$(compute_sha256sum "${TMP_BIN}")
    HASH_BIN=${HASH_BIN%%[[:blank:]]*}
    if [[ "${HASH_EXPECTED}" != "${HASH_BIN}" ]]; then
        fatal "Download sha256 does not match ${HASH_EXPECTED}, got ${HASH_BIN}"
    else
        info "Download hash matched ${HASH_EXPECTED}"
    fi
}

# Setup permissions and move binary
setup_binary() {
    mv_or_sudo() {
        local src=$1 dst=$2
        if [[ -w $(dirname "$dst") ]]; then
            mv -f "$src" "$dst"
        else
            warn "Need sudo to write to ${dst}"
            sudo mv -f "$src" "$dst"
        fi
    }

    # local dest=${1:-"${BIN_DIR}/${TOOL_NAME}"}
    local dest=${1:-"${BIN_DIR}"}
    chmod 755 "${TMP_BIN}"
    info "Installing ${TOOL_NAME} to ${dest}"
    tar -xzof "${TMP_BIN}" -C "${TMP_DIR}"

    # list unique top‑level entries in the archive
    mapfile -t entries < <(
      tar -tzf "${TMP_BIN}" |
      awk -F/ '{print $1}' |
      sort -u
    )

    [[ -e "${dest}" ]] || mkdir -p "${dest}"

    if [[ ${#entries[@]} -eq 1 ]]; then
        local name="${entries[0]}"
        # a) single directory case
        if [[ -d "${TMP_DIR}/${name}" ]]; then
            mv_or_sudo "${TMP_DIR}/${name}" "${dest}/${name}"
            info "Installed directory ${name}"
            return
        fi
        # b) single file case
        if [[ -f "${TMP_DIR}/${name}" ]]; then
            # if it’s not named exactly $TOOL_NAME, rename it
            local target_name="${name##*/}"
            [[ "${target_name}" != "${TOOL_NAME}" ]] && target_name="${TOOL_NAME}"
            mv_or_sudo "${TMP_DIR}/${name}" "${dest}/${target_name}"
            info "Installed binary ${target_name}"
            return
        fi
    else
        # c) multiple files case
        fatal "Archive contains multiple top-level entries: ${entries[*]}"
    fi

    # local CMD_MOVE="mv -f \"${TMP_DIR}/${TOOL_NAME}\" \"${dest}\""
    # if [[ -w "${dest}" ]]; then
    #     eval "${CMD_MOVE}"
    # else
    #     warn "Target directory not writable, trying with sudo"
    #     eval "sudo ${CMD_MOVE}"
    # fi

    # if [[ -x "$(command -v "${TOOL_NAME}")" ]]; then
    #     info "Installed ${TOOL_NAME} successfully"
    # else
    #     fatal "Unable to locate ${TOOL_NAME}"
    # fi
}

# EXAMPLE: Run the install process
# {
#     setup_verify_os
#     setup_verify_arch
#     verify_common_downloaders
#     setup_tmp
#     get_release_version
#     download_hash
#     download_binary
#     verify_binary
#     setup_binary
# }
