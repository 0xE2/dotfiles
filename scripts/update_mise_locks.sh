#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="${MISE_BIN:-${HOME:?}/.local/bin/mise}"

# The manifest path is resolved relative to this script at runtime.
# shellcheck disable=SC1091
source "$dotfiles_dir/.mise-bootstrap.env"

[[ -x $mise_bin ]] || {
  printf 'error: mise is not executable: %s\n' "$mise_bin" >&2
  exit 1
}
[[ "$(MISE_NO_CONFIG=1 "$mise_bin" --version | awk '{print $1}')" == "$MISE_VERSION" ]] || {
  printf 'error: lock updates require mise %s\n' "$MISE_VERSION" >&2
  exit 1
}

export MISE_CONFIG_DIR="$dotfiles_dir/.config/mise"
export MISE_TRUSTED_CONFIG_PATHS="$dotfiles_dir"
export MISE_SAFE=1

# Personal and work contain mutually exclusive Java distributions, so lock
# them in separate configuration passes.
MISE_ENV="shell-base,shell-extended,languages,personal,devops,devsecops" \
  "$mise_bin" lock --global --bump --platform linux-x64,linux-arm64
MISE_ENV="work" \
  "$mise_bin" lock --global --bump --platform linux-x64,linux-arm64
