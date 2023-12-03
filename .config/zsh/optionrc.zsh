# https://zsh.sourceforge.io/Doc/Release/Options.html


# History
setopt append_history         # Immediately append history instead of overwriting
setopt inc_append_history     # save commands are added to the history immediately, otherwise only when shell exits
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt hist_ignore_all_dups   # If a new command is a duplicate, remove the older one
#setopt share_history         # share command history data