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

alias disable_hist='set +o history'
