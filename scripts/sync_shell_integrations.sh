#!/usr/bin/env bash
set -euo pipefail

umask 077

check_only=false
cache_root="${XDG_CACHE_HOME:-${HOME:?}/.cache}/dotfiles/shell-integrations"
generations_dir="$cache_root/generations"
current_link="$cache_root/current"
stage_dir=""
link_tmp=""

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

print_usage() {
  cat <<'EOF'
Usage: sync_shell_integrations.sh [--check]

Synchronize completion functions and shell integrations for commands currently
available on PATH. --check generates a temporary snapshot and reports drift
without changing the active cache.
EOF
}

while (($#)); do
  case "$1" in
    --check)
      check_only=true
      shift
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

for command_name in awk diff find sha256sum sort xargs; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is missing: $command_name"
done

mkdir -p -- "$generations_dir"
[[ -d $cache_root && ! -L $cache_root ]] || die "cache root must be a real directory: $cache_root"
[[ -d $generations_dir && ! -L $generations_dir ]] ||
  die "generations path must be a real directory: $generations_dir"
chmod 0700 -- "$cache_root" "$generations_dir"

cleanup() {
  if [[ -n ${link_tmp:-} && -L ${link_tmp:-} ]]; then
    case "$link_tmp" in
      "$cache_root"/.current.*) rm -- "$link_tmp" ;;
    esac
  fi
  if [[ -n ${stage_dir:-} && -d ${stage_dir:-} && ! -L ${stage_dir:-} ]]; then
    case "$stage_dir" in
      "$generations_dir"/.tmp.*) rm -r -- "$stage_dir" ;;
    esac
  fi
}
trap cleanup EXIT

stage_dir="$(mktemp -d "$generations_dir/.tmp.XXXXXXXXXX")"
[[ -n $stage_dir && -d $stage_dir && ! -L $stage_dir ]] || die "failed to create staging directory"
mkdir -p -- \
  "$stage_dir/zsh/completions" \
  "$stage_dir/zsh/integrations" \
  "$stage_dir/bash/completions" \
  "$stage_dir/bash/integrations"

completion_tools=(mise uv uvx kubectl helm sops tailscale podman)
integration_tools=(fzf)
generated=()
skipped=()

generate_completion() {
  local tool=$1
  local shell_name=$2

  case "$tool:$shell_name" in
    mise:zsh | mise:bash) mise completion "$shell_name" ;;
    uv:zsh | uv:bash) uv generate-shell-completion "$shell_name" ;;
    uvx:zsh | uvx:bash) uvx --generate-shell-completion "$shell_name" ;;
    kubectl:zsh | kubectl:bash) kubectl completion "$shell_name" ;;
    helm:zsh | helm:bash) helm completion "$shell_name" ;;
    sops:zsh | sops:bash) sops completion "$shell_name" ;;
    tailscale:zsh | tailscale:bash) tailscale completion "$shell_name" ;;
    podman:zsh | podman:bash) podman completion "$shell_name" ;;
    *) return 2 ;;
  esac
}

generate_integration() {
  local tool=$1
  local shell_name=$2

  case "$tool:$shell_name" in
    fzf:zsh) fzf --zsh ;;
    fzf:bash) fzf --bash ;;
    *) return 2 ;;
  esac
}

completion_dependencies_available() {
  local tool=$1

  case "$tool" in
    mise) type -P usage >/dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

write_completion() {
  local tool=$1
  local shell_name=$2
  local output=""

  if [[ $shell_name == zsh ]]; then
    output="$stage_dir/zsh/completions/_$tool"
  else
    output="$stage_dir/bash/completions/$tool"
  fi

  if ! generate_completion "$tool" "$shell_name" >"$output"; then
    die "$tool failed to generate $shell_name completion"
  fi
  [[ -s $output ]] || die "$tool generated empty $shell_name completion"
  if [[ $shell_name == zsh ]]; then
    IFS= read -r first_line <"$output"
    [[ $first_line == '#compdef '* ]] || die "$tool generated invalid Zsh completion"
  fi
}

write_integration() {
  local tool=$1
  local shell_name=$2
  local output="$stage_dir/$shell_name/integrations/$tool.$shell_name"

  if ! generate_integration "$tool" "$shell_name" >"$output"; then
    die "$tool failed to generate $shell_name integration"
  fi
  [[ -s $output ]] || die "$tool generated empty $shell_name integration"
}

for tool in "${completion_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    skipped+=("$tool")
    continue
  fi
  if ! completion_dependencies_available "$tool"; then
    skipped+=("$tool(missing:usage)")
    continue
  fi
  write_completion "$tool" zsh
  write_completion "$tool" bash
  generated+=("$tool")
done

for tool in "${integration_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    skipped+=("$tool")
    continue
  fi
  write_integration "$tool" zsh
  write_integration "$tool" bash
  generated+=("$tool")
done

current_dir=""
if [[ -e $current_link && ! -L $current_link ]]; then
  die "active cache pointer is not a symlink: $current_link"
fi
if [[ -L $current_link ]]; then
  current_target="$(readlink -- "$current_link")"
  [[ $current_target =~ ^generations/[0-9a-f]{64}$ ]] ||
    die "active cache pointer has an invalid target: $current_target"
  current_dir="$cache_root/$current_target"
fi

matches_current=false
if [[ -n $current_dir && -d $current_dir && ! -L $current_dir ]] &&
  diff --brief --recursive "$stage_dir" "$current_dir" >/dev/null; then
  matches_current=true
fi

printf 'Generated: %s\n' "${generated[*]:-none}"
printf 'Skipped:   %s\n' "${skipped[*]:-none}"

if [[ $check_only == true ]]; then
  if [[ $matches_current == true ]]; then
    printf 'Shell integration cache is current.\n'
    exit 0
  fi
  printf 'Shell integration cache is stale.\n' >&2
  exit 1
fi

if [[ $matches_current == true ]]; then
  printf 'Shell integration cache is already current.\n'
  exit 0
fi

fingerprint="$(
  cd "$stage_dir"
  find . -type f -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum |
    sha256sum |
    awk '{print $1}'
)"
[[ $fingerprint =~ ^[0-9a-f]{64}$ ]] || die "failed to fingerprint generated snapshot"
generation_dir="$generations_dir/$fingerprint"

if [[ -e $generation_dir || -L $generation_dir ]]; then
  [[ -d $generation_dir && ! -L $generation_dir ]] || die "generation path is not a real directory"
  diff --brief --recursive "$stage_dir" "$generation_dir" >/dev/null ||
    die "generated snapshot conflicts with its content fingerprint"
else
  mv -T -- "$stage_dir" "$generation_dir"
  stage_dir=""
fi

link_tmp="$cache_root/.current.$$"
[[ ! -e $link_tmp && ! -L $link_tmp ]] || die "temporary cache pointer already exists"
ln -s -- "generations/$fingerprint" "$link_tmp"
mv -Tf -- "$link_tmp" "$current_link"
link_tmp=""

printf 'Activated shell integration generation %s.\n' "$fingerprint"
