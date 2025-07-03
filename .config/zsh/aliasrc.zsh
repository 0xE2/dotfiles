# force zsh to show the complete history
alias history="history 0"

# some more ls aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

alias m='micro'
alias k='kubectl'

alias kubectx="kubectl-ctx"
alias kctx="kubectl-ctx"
alias kubens="kubectl-ns"
alias kns="kubectl-ns"

# https://stackoverflow.com/questions/24947080/implementing-autocompletion-to-zsh-aliases
# https://superuser.com/questions/1549955/how-to-export-hash-d-directories-to-scripts

hash -d w=~/work
# Same as
# w="${HOME}/work"

function lk {
    cd "$(walk --icons --preview --with-border "$@")"
}
