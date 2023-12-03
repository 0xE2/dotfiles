#!/usr/bin/env bash

# Update Exegol my-resources directory with the latest copy of dotfiles
# https://exegol.readthedocs.io/en/latest/exegol-image/my-resources.html
# Usage: ./exegol_update_my-resources.sh [dotfiles_dir] [exegol_dir]

# Function to check if directories exist
check_dirs() {
    for dir in "$@"; do
        if [[ ! -d "$dir" ]]; then
            echo "Directory $dir does not exist. Please check the path and try again."
            exit 1
        fi
    done
}

copy_files() {
    local src_dir=$1
    local dst_dir=$2

    # Use rsync for idempotent file copying, it only copies files that are different
    # -a to preserve timestamps, ownership, and permissions
    # -R to use relative path
    # --copy-links to transform symlink into referent file/dir
    # The trailing / on the source directory tells rsync to copy the content of the source directory, not the directory itself
    rsync -vaR --checksum --copy-links "$src_dir"/ "$dst_dir"
}

main() {
    local src_dir=${1:-"$HOME/projects/dotfiles/exegol-setup/."}
    local dst_dir=${2:-"$HOME/.exegol/my-resources/setup"}

    check_dirs "$src_dir" "$dst_dir"
    copy_files "$src_dir" "$dst_dir"
}

main "$@"
