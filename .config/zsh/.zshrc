# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Check if we're on QubesOS. We're most likely in AppVM, so let's indicate to
# our scripts to use non-volatile directories
[[ -f "/usr/share/qubes/marker-vm" ]] && export LIMIT_TO_USER_DIRS=true

[ -f "${ZDOTDIR}/aliasrc.zsh" ] && source "${ZDOTDIR}/aliasrc.zsh"
[ -f "${ZDOTDIR}/optionrc.zsh" ] && source "${ZDOTDIR}/optionrc.zsh"
[ -f "${ZDOTDIR}/pluginrc.zsh" ] && source "${ZDOTDIR}/pluginrc.zsh"

# History
HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=4000


# Don't consider certain characters ('/') part of the word
# Useful for path navigation
WORDCHARS=${WORDCHARS//\/}

# hide EOL sign ('%')
PROMPT_EOL_MARK=""

export PATH=~/.local/bin:~/bin:~/go/bin:/usr/local/go/bin:$PATH

# Prefer [[ in zsh/bash scripts for robustness and readability
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Krew is the package manager for kubectl plugins
KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
[[ -d "$KREW_ROOT/bin" ]] && export PATH="$KREW_ROOT/bin:$PATH"

fpath=("$ZDOTDIR/functions" "${fpath[@]}")


####################################################################################################
# Configure key bindings
####################################################################################################

# bindkey -l will give you a list of existing keymap names
# bindkey -M <keymap> will list all the bindings in a given keymap
# bindkey with no arguments will print all keybindings for main (emacs or viins) keymap
# zle -al will list all the widgets (functions) you can bind to keys
# man zshzle (https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html) -> STANDARD WIDGETS section
# sed -n l will show you the characters that are being typed
# zmodload zsh/terminfo
# https://github.com/romkatv/zsh4humans/blob/bb139177bced8338e99e78380b2932b1a9c32209/fn/-z4h-init#L319 | some of default bindings
bindkey -e                                        # emacs key bindings
# bindkey ' ' magic-space                           # do history expansion on space
bindkey '^U' backward-kill-line                   # ctrl + U
# bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[3~' delete-char                       # delete
bindkey '^[[1;5C' forward-word                    # ctrl + right arrow
bindkey '^[[1;5D' backward-word                   # ctrl + left arrow
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[H' beginning-of-line                  # home
bindkey '^[[F' end-of-line                        # end
bindkey '^[[Z' undo                               # shift + tab undo last action

# Just '^[[A' / '^[[B' doesn't work for me
# https://invisible-island.net/ncurses/man/user_caps.5.html#h3-Extended-key-definitions
bindkey "$terminfo[kcuu1]" history-substring-search-up   # up arrow
bindkey "$terminfo[kcud1]" history-substring-search-down # down arrow
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

####################################################################################################
# Set up colors
####################################################################################################

# autoload -U colors && colors

# Enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    # test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:" # fix ls color for folders with 777 permissions

    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    # Color man 
    # https://unix.stackexchange.com/questions/108699/documentation-on-less-termcap-variables
    # https://www.gnu.org/software/termutils/manual/termcap-1.3/html_mono/termcap.html#SEC33 -> search `mb' etc
    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
    export LESS_TERMCAP_so=$'\E[01;43;34m' # begin highlight
    export LESS_TERMCAP_se=$'\E[0m'        # reset highlight
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline
    export LESS=-R # allows raw control characters only for colors to be displayed

    # Take advantage of $LS_COLORS for completion as well
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

####################################################################################################
# Enable completion features
####################################################################################################

# https://thevaluable.dev/zsh-completion-guide-examples/
# run-help autoload / man zshmisc -> AUTOLOADING FUNCTIONS
# man zshbuiltins -> search autoload
# https://www.reddit.com/r/zsh/comments/13sy6z6/understanding_autoload_x/
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select  # navigate completions using the arrow keys
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # allows case-insensitive matching
zstyle ':completion:*' rehash true  # automatically find new executables in path
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# Setup completion scripts in interactive shells


####################################################################################################
# Set up config for plugins
####################################################################################################

# zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'

# The command-not-found will look-up command in the database and suggest
# installation of packages available from the repository
if [ -f /etc/zsh_command_not_found ]; then
    . /etc/zsh_command_not_found
fi

# To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh


####################################################################################################
# Other
####################################################################################################

# Continue Python init
if [[ -d $PYENV_ROOT/bin ]]; then
  eval "$(pyenv init -)"
  export PIP_REQUIRE_VIRTUALENV=true
  # PIPX_DEFAULT_PYTHON
fi

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

autoload -Uz get_tunnel_ipv4

export DOCKER_HOST=unix://mnt/wsl/podman-sockets/podman-machine-default/podman-root.sock
