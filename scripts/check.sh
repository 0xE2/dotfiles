#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="${MISE_BIN:-${HOME:?}/.local/bin/mise}"

for command_name in shellcheck shfmt; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'error: required validator is missing: %s\n' "$command_name" >&2
    exit 1
  }
done
[[ -x $mise_bin ]] || {
  printf 'error: mise is not executable: %s\n' "$mise_bin" >&2
  exit 1
}

cd "$dotfiles_dir"

# The manifest path is resolved relative to this script at runtime.
# shellcheck disable=SC1091
source "$dotfiles_dir/.mise-bootstrap.env"
[[ $MISE_VERSION =~ ^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$ ]] || {
  printf 'error: invalid version in .mise-bootstrap.env\n' >&2
  exit 1
}
[[ $MISE_SHA256_X64 =~ ^[0-9a-f]{64}$ && $MISE_SHA256_ARM64 =~ ^[0-9a-f]{64}$ ]] || {
  printf 'error: invalid checksum in .mise-bootstrap.env\n' >&2
  exit 1
}

bash -n bootstrap.sh scripts/check.sh scripts/link_shell_dotfiles.sh scripts/update_mise_bootstrap.sh scripts/update_mise_locks.sh
shellcheck bootstrap.sh scripts/check.sh scripts/link_shell_dotfiles.sh scripts/prepare-mitmproxy-env.sh scripts/update_mise_bootstrap.sh scripts/update_mise_locks.sh
shfmt -d -i 2 -ci bootstrap.sh scripts/check.sh scripts/link_shell_dotfiles.sh scripts/prepare-mitmproxy-env.sh scripts/update_mise_bootstrap.sh scripts/update_mise_locks.sh

export MISE_CONFIG_DIR="$dotfiles_dir/.config/mise"
export MISE_TRUSTED_CONFIG_PATHS="$dotfiles_dir"
export MISE_SAFE=1
"$mise_bin" fmt --all --check

for lock_file in "$MISE_CONFIG_DIR"/*.lock; do
  awk '
    function check_tool() {
      if (tool != "" && tool !~ /pipx:/ && (!x64 || !arm64)) {
        printf "error: %s lacks both Linux architecture entries in %s\n", tool, FILENAME > "/dev/stderr"
        failed = 1
      }
    }
    /^\[\[tools\./ {
      check_tool()
      tool = $0
      x64 = 0
      arm64 = 0
    }
    /platforms\.linux-x64/ { x64 = 1 }
    /platforms\.linux-arm64/ { arm64 = 1 }
    END {
      check_tool()
      exit failed
    }
  ' "$lock_file"
done

for profile_file in "$MISE_CONFIG_DIR"/profiles/*.miserc.toml; do
  env_list="$(sed -n 's/^env = \[\(.*\)\]$/\1/p' "$profile_file" | tr -d '" ')"
  [[ -n $env_list ]] || {
    printf 'error: could not read environments from %s\n' "$profile_file" >&2
    exit 1
  }
  if [[ ,$env_list, == *,personal,* && ,$env_list, == *,work,* ]]; then
    printf 'error: profile selects both personal and work: %s\n' "$profile_file" >&2
    exit 1
  fi
  MISE_ENV="$env_list" "$mise_bin" config ls >/dev/null
  MISE_ENV="$env_list" "$mise_bin" install --locked --dry-run >/dev/null
done

tmp_home="$(mktemp -d -t dotfiles-link-check.XXXXXXXXXX)"
[[ -n $tmp_home && -d $tmp_home ]] || {
  printf 'error: failed to create link-check directory\n' >&2
  exit 1
}
trap '[[ -n ${tmp_home:-} && -d ${tmp_home:-} ]] && rm -r -- "$tmp_home"' EXIT
HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" scripts/link_shell_dotfiles.sh >/dev/null
HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" scripts/link_shell_dotfiles.sh >/dev/null

for expected in \
  "$tmp_home/.bashrc" \
  "$tmp_home/.zshenv" \
  "$tmp_home/.config/mise" \
  "$tmp_home/.config/tmux" \
  "$tmp_home/.config/zsh"; do
  [[ -L $expected ]] || {
    printf 'error: linker did not create %s\n' "$expected" >&2
    exit 1
  }
done

printf 'All checks passed.\n'
