#!/usr/bin/env bash

source install_toolset_helpers.sh

install_traefik() {
    TOOL_NAME="traefik"
    GITHUB_REPO="traefik/traefik"
    HASH_FILE_TPL='traefik_v${RELEASE_VERSION}_checksums.txt'
    BIN_FILE_TPL='traefik_v${RELEASE_VERSION}_${OS}_${ARCH}.tar.gz'
    setup_verify_os
    setup_verify_arch
    verify_common_downloaders
    setup_tmp
    github_get_release_version
    github_download_hash
    github_download_binary
    verify_binary
    setup_binary
}

{
    install_traefik
}