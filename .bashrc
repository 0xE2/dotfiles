export PATH=~/bin:~/.local/bin:$PATH

HISTCONTROL=ignoreboth
HISTIGNORE="&:ls:[bf]g:exit:pwd:history"

# Windows
alias clip=clip.exe
alias shellcheck="shellcheck.exe"
alias sdkmanager="sdkmanager.bat"
alias avdmanager="avdmanager.bat"

alias disable_hist="set +o history"

source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
