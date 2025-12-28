#!/usr/bin/env zsh

# Generates zsh for present CLI tools

# source .zshrc to get $fpath
source "$ZDOTDIR/.zshrc"

if (( $+commands[tailscale] )); then
  tailscale completion zsh > "${fpath[1]}/_tailscale"
fi
