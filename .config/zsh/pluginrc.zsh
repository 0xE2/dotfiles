() {
  local plugin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh-plugins"
  local plugin_file
  local missing=0

  for plugin_file in \
    "$plugin_dir/zsh-history-substring-search/zsh-history-substring-search.zsh" \
    "$plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "$plugin_dir/powerlevel10k/powerlevel10k.zsh-theme"
  do
    if [[ -r $plugin_file ]]; then
      source "$plugin_file"
    else
      print -u2 "zsh: plugin is not installed: $plugin_file"
      missing=1
    fi
  done

  if (( missing )); then
    print -u2 "zsh: run the dotfiles bootstrap to install pinned plugins"
  fi
}
