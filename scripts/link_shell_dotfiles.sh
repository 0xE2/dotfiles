#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xdg_config_home="${XDG_CONFIG_HOME:-${HOME:?}/.config}"

sources=(
  "$dotfiles_dir/.zshenv"
  "$dotfiles_dir/.config/zsh"
  "$dotfiles_dir/.config/tmux"
)

destinations=(
  "${HOME:?}/.zshenv"
  "$xdg_config_home/zsh"
  "$xdg_config_home/tmux"
)

for index in "${!sources[@]}"; do
  source_path="${sources[$index]}"
  destination_path="${destinations[$index]}"

  if [[ ! -e "$source_path" ]]; then
    printf 'error: dotfiles source does not exist: %s\n' "$source_path" >&2
    exit 1
  fi

  if [[ -L "$destination_path" ]]; then
    if [[ "$(readlink -f -- "$destination_path")" == "$(readlink -f -- "$source_path")" ]]; then
      continue
    fi
    printf 'error: destination points elsewhere: %s\n' "$destination_path" >&2
    exit 1
  fi

  if [[ -e "$destination_path" ]]; then
    printf 'error: destination already exists and is not a symlink: %s\n' "$destination_path" >&2
    exit 1
  fi
done

for index in "${!sources[@]}"; do
  source_path="${sources[$index]}"
  destination_path="${destinations[$index]}"

  if [[ -L "$destination_path" ]]; then
    printf 'unchanged: %s -> %s\n' "$destination_path" "$source_path"
    continue
  fi

  mkdir -p -- "$(dirname "$destination_path")"
  ln -s -- "$source_path" "$destination_path"
  printf 'linked: %s -> %s\n' "$destination_path" "$source_path"
done
