() {
  if [[ "$LIMIT_TO_USER_DIRS" == "true" ]]; then
    ZPLUGINDIR="$HOME/.local/share/zsh-plugins"
  else
    ZPLUGINDIR="/etc/zsh/plugins"
  fi

  # Check if the plugin directory exists
  if [ ! -d "${ZPLUGINDIR}" ]; then
    echo "Plugin directory ${ZPLUGINDIR} does not exist."
    mkdir "$ZPLUGINDIR" || {echo "Please create it manually with 'sudo mkdir -p ${ZPLUGINDIR}; sudo chown -R $(whoami):$(whoami) ${ZPLUGINDIR}'"; return 1}
  fi

  apply() {
    github_org=$1
    plugin_name=$2
    
    if [ ! -d "${ZPLUGINDIR}/${plugin_name}" ]; then
      echo "WARNING: ${plugin_name} not found. Installing..."
      git clone "https://github.com/${github_org}/${plugin_name}" "${ZPLUGINDIR}/${plugin_name}"
      echo "SUCCESS: ${plugin_name} installed!"
    fi
    
    if [ "${plugin_name}" = "powerlevel10k" ]; then
      source "${ZPLUGINDIR}/${plugin_name}/${plugin_name}.zsh-theme"
    else
      source "${ZPLUGINDIR}/${plugin_name}/${plugin_name}.plugin.zsh"
    fi
  }

#   apply zdharma-continuum fast-syntax-highlighting
#   apply zsh-users zsh-syntax-highlighting # load before zsh-history-substring-search
  apply zsh-users zsh-history-substring-search
  apply zsh-users zsh-autosuggestions
#   apply jeffreytse zsh-vi-mode
  apply romkatv powerlevel10k
}
