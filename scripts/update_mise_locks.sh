#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="${MISE_BIN:-${HOME:?}/.local/bin/mise}"
env_list=""

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./scripts/update_mise_locks.sh [--env LIST | LIST]

Options:
  --env LIST  Use this comma-separated mise environment list instead of the default lock passes.
  -h, --help  Show this help.

With no LIST, all standard environments are locked in two passes because personal and work select mutually exclusive Java distributions.
EOF
}

while (($#)); do
  case "$1" in
    --env)
      (($# >= 2)) || die "--env requires a value"
      [[ -z $env_list ]] || die "environment list specified more than once"
      env_list=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      die "unknown argument: $1"
      ;;
    *)
      [[ -z $env_list ]] || die "environment list specified more than once"
      env_list=$1
      shift
      ;;
  esac
done

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

lock_envs() {
  local envs=$1

  MISE_ENV="$envs" "$mise_bin" lock --global --bump --platform linux-x64,linux-arm64
}

if [[ -n $env_list ]]; then
  IFS=',' read -r -a environments <<<"$env_list"
  ((${#environments[@]} > 0)) || die "environment list must not be empty"

  saw_personal=false
  saw_work=false
  for environment in "${environments[@]}"; do
    [[ $environment =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid environment: $environment"
    [[ -f "$MISE_CONFIG_DIR/config.$environment.toml" ]] || die "unknown environment: $environment"
    [[ $environment == personal ]] && saw_personal=true
    [[ $environment == work ]] && saw_work=true
  done
  [[ $saw_personal == false || $saw_work == false ]] ||
    die "personal and work environments are mutually exclusive"

  lock_envs "$env_list"
  exit 0
fi

# Personal and work contain mutually exclusive Java distributions, so lock
# them in separate configuration passes.
lock_envs "shell-base,shell-extended,languages,personal,devops,devsecops,android-lab,agentic"
lock_envs "work"
