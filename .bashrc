# Minimal Bash fallback; Zsh is the primary interactive shell.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

[[ $- == *i* ]] || return

HISTCONTROL=ignoreboth
HISTIGNORE="&:ls:[bf]g:exit:pwd:history"

if [[ -x $HOME/.local/bin/mise ]]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

shell_integration_root="$XDG_CACHE_HOME/dotfiles/shell-integrations/current/bash"
if [[ -d $shell_integration_root ]]; then
  export BASH_COMPLETION_USER_DIR="$shell_integration_root"
fi

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck disable=SC1091
  source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  # shellcheck disable=SC1091
  source /etc/bash_completion
fi

if [[ -d $shell_integration_root/integrations ]]; then
  for integration_file in "$shell_integration_root"/integrations/*.bash; do
    [[ -r $integration_file ]] || continue
    # Generated host-local integration selected by the guarded glob above.
    # shellcheck disable=SC1090
    source "$integration_file"
  done
  unset integration_file
fi
unset shell_integration_root

alias disable_hist='set +o history'
