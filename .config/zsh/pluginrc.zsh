() {
  local ZPLUGINDIR=/etc/zsh/plugins

  # Check if the plugin directory exists
  if [ ! -d "${ZPLUGINDIR}" ]; then
    echo "Plugin directory ${ZPLUGINDIR} does not exist."
    echo "Please create it manually with 'sudo mkdir -p ${ZPLUGINDIR}; sudo chown -R $(whoami):$(whoami) ${ZPLUGINDIR}'"
    return 1
  fi

  apply() {
    github=$1
    plugin=$2
    
    if [ ! -d "${ZPLUGINDIR}/${plugin}" ]; then
      echo "WARNING: ${plugin} not found. Installing..."
      git clone "https://www.github.com/${github}/${plugin}" "${ZPLUGINDIR}/${plugin}"
      echo "SUCCESS: ${plugin} installed!"
    fi
    
    if [ "${plugin}" = "powerlevel10k" ]; then
      source "${ZPLUGINDIR}/${plugin}/${plugin}.zsh-theme"
    else
      source "${ZPLUGINDIR}/${plugin}/${plugin}.plugin.zsh"
    fi
  }

#   apply zdharma-continuum fast-syntax-highlighting
#   apply zsh-users zsh-syntax-highlighting # load before zsh-history-substring-search
  apply zsh-users zsh-history-substring-search
  apply zsh-users zsh-autosuggestions
#   apply jeffreytse zsh-vi-mode
  apply romkatv powerlevel10k
}
