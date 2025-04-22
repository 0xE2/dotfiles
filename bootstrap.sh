#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

## Paths
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"$HOME/.config"}"
# Set XDG_CONFIG_HOME and ZDOTDIR if not set
source "$DOTFILES_DIR/.zshenv"

## Helpers
log()    { echo "➤ $*"; }
is_nixos(){ [[ -f /etc/NIXOS ]]; }
link() {
  local src=$1 dest=$2
  mkdir --parents "$(dirname "$dest")"
  if [[ -L $dest ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log "Skip: $dest already → $src"
      return
    else
      rm "$dest"
    fi
  elif [[ -e $dest ]]; then
    mv "$dest" "$dest".backup."$(date +%s)"
    log "Backed up existing $dest"
  fi
  ln --symbolic "$src" "$dest"
  log "Linked $dest → $src"
}

append_global_zsh() {
  # Read the helper script
  raw_script=$(<"$DOTFILES_DIR/scripts/append_custom_config.sh")
  # Escape every " → \" using parameter expansion so it can be safely inlined into sudo bash -c "…"
  escaped_script="${raw_script//\"/\\\"}"
  sudo bash -c "DOT=\$(cat \"$DOTFILES_DIR/.zshenv\"); $escaped_script /etc/zsh/zshenv \"\$DOT\" \"CUSTOM ZDOTDIR\""
}

## Installers
install_zsh() {
  log "Installing Zsh configs..."
  link "$DOTFILES_DIR/.config/zsh" "$XDG_CONFIG_HOME/zsh"
  if ! is_nixos; then
    log "Not a NixOS: updating /etc/zsh/zshenv"
    append_global_zsh
  else
    log "NixOS detected: updating ~/.zshenv instead of global one"
    link "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
  fi
}

install_tmux() {
  log "Installing Tmux configs..."
  link "$DOTFILES_DIR/.config/tmux" "$XDG_CONFIG_HOME/tmux"
  local tpm="$XDG_CONFIG_HOME/tmux/plugins/tpm"
  if [[ ! -d $tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm "$tpm"
    log "Cloned TPM to $tpm"
  else
    log "TPM already installed"
  fi
}

install_git() {
  log "Installing Git configs..."
  link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
}


## Argument parsing
declare -A MODULES=(
  [zsh]=install_zsh
  [tmux]=install_tmux
  [git]=install_git
)

selected=()

while getopts "aztgh" opt; do
  case $opt in
    a) selected=( "${!MODULES[@]}" ) ;;  # all
    z) selected+=(zsh) ;;
    t) selected+=(tmux) ;;
    g) selected+=(git) ;;
    h|*) echo "Usage: $0 [-a] [-z] [-t] [-g]" && exit 1 ;;
  esac
done

shift $((OPTIND-1))

## Interactive if nothing chosen
if [[ ${#selected[@]} -eq 0 ]]; then
  for mod in "${!MODULES[@]}"; do
    read -rp "Install $mod configs? [Y/n] " ans
    [[ $ans =~ ^([yY]|$) ]] && selected+=("$mod")
  done
fi

## Run them (dedupe)
for mod in $(printf "%s\n" "${selected[@]}" | sort -u); do
  "${MODULES[$mod]}"
  # Print a separator for half of the cols length
  printf '%*s\n' "$((${COLUMNS:-$(tput cols)} / 2))" '' | tr ' ' -
done

log "Done."
