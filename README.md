# Dotfiles and config files

This repo has configurations for WSL2, Linux + Exegol and Windows


## Exegol on WSL2 (Windows 11)

``` Bash
sudo apt install x11-xserver-utils
<create Exegol "bin" somewhere in the PATH and chmod +x it>

#!/usr/bin/env bash
.../Exegol-venv/bin/python3 .../Exegol/exegol.py "$@"
```

## Zsh

https://zsh.sourceforge.io/Doc/Release/Files.html#Files

``` Bash
zsh -d -f -i # run in debug mode, don't load any config files, run interactively

chsh -s $(which zsh)

cat .zshenv | sudo tee -a /etc/zsh/zshenv
    OR, as root
source ./scripts/append_custom_config.sh
content=$(cat .zshenv)
update_config /etc/zsh/zshenv $content

# ZDOTDIR env var isn't exported from global zshenv because directory is not yet linked
ln -s "$(pwd)/.config/zsh" ~/.config/zsh
```

### Plugins
`$ZDOTDIR/plugins/` OR `/usr/share/zsh/plugins/` OR `/etc/zsh/plugins`
- https://github.com/romkatv/powerlevel10k
    - https://www.nerdfonts.com/
- https://github.com/zsh-users/zsh-autosuggestions
- https://github.com/zsh-users/zsh-history-substring-search

### Tmux

```
mkdir $XDG_CONFIG_HOME/tmux
ln -s $(pwd)/.config/tmux/tmux.conf $XDG_CONFIG_HOME/tmux/tmux.conf
git clone https://github.com/tmux-plugins/tpm $XDG_CONFIG_HOME/tmux/plugins/tpm
```

### Terminals

xfce4-terminal
```shell
_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/terminal"
terminalrc="$_config_dir/terminalrc"
if [ ! -f "$terminalrc" ]; then
    mkdir -p _config_dir
    echo "[Configuration]" > "$terminalrc"
    echo "FontName=MesloLGS NF 12" >> "$terminalrc"
else
    echo "$terminalrc already exists"
    sed -i 's/^FontName=.*/FontName=MesloLGS NF 12/' "$terminalrc"
fi
```

## Python

_pyenv + pipenv + pipx:_

- https://github.com/pyenv/pyenv#automatic-installer
- in zsh: `PIP_REQUIRE_VIRTUALENV=false pip install pipenv pipx`

## Podman

1. Install Podman on Windows, create machine -> creates another WSL distribution
2. Install Podman on WSL2 from `podman-remote-static-linux_amd64.tar.gz`
3. Copy `%APPDATA%\containers\containers.conf` and SSH key from Windows to WSL2 `$HOME/.config/containers/containers.conf`
    * Use key from Windows in WSL2:

``` Bash
podman system connection add podman-machine-default-root --default --identity /mnt/c/Users/$WIN_USER/.ssh/podman-machine-default ssh://root@127.0.0.1:$PORT/run/podman/podman.sock
```

## Inspired by

- ZSH | https://github.com/radleylewis/dotfiles
