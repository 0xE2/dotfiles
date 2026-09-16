# Linux dotfiles and user toolchain

This repository configures a user-wide Linux shell environment and installs versioned tools with [mise](https://mise.jdx.dev/). It targets x86-64 and ARM64 hosts running WSL2, Ubuntu, or Qubes OS.

## Quick start

The bootstrap requires `curl` and `sha256sum`. It downloads the repository's exact mise release to `~/.local/bin/mise`, verifies its published SHA-256 checksum, links the dotfiles, selects a host profile, installs pinned plugins, and installs tools from committed locks.

```bash
./bootstrap.sh --profile personal-dev
./bootstrap.sh --profile work --system
./bootstrap.sh --profile android-lab
```

`--system` is deliberately separate because it may invoke `sudo` through apt. Without it, bootstrap changes only user-owned state.

For a one-off combination instead of a committed profile:

```bash
./bootstrap.sh --env shell-base,languages,personal
```

Run `./bootstrap.sh --help` for the complete interface. Re-running bootstrap is safe. It refuses unmanaged dotfile conflicts, dirty plugin repositories, and invalid or contradictory environment selections.

## Mise toolchain

Mise profiles, environment categories, lock updates, bootstrap version updates, and Python CLI tool details live in [`.config/mise/README.md`](./.config/mise/README.md).

## Dotfile linking

The linker is an atomic, network-free operation:

```bash
./scripts/link_shell_dotfiles.sh
```

It preflights every destination before creating any link, and owns:

- `~/.bashrc`
- `~/.zshenv`
- `~/.config/mise`
- `~/.config/zsh`
- `~/.config/tmux`

It refuses a destination that is a real file or points somewhere else. Resolve the conflict yourself and rerun it; the script never backs up or overwrites files. Zsh is the primary shell. The linked Bash configuration is intentionally minimal and acts as a fallback.

## Plugin ownership

Mise bootstrap clones Zsh plugins, TPM, and tmux plugins at exact commits. Shell startup only loads existing checkouts and never accesses the network. TPM is a loader, not the update mechanism; do not use its install/update shortcuts to change plugin revisions.

## Shell completion and integrations

Completion generators never run during shell startup. Bootstrap synchronizes an explicit registry after installing the selected tools, and stores an atomic, host-specific snapshot under `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/shell-integrations`.

Run synchronization manually after installing or removing an external tool:

```bash
./scripts/sync_shell_integrations.sh
```

Inspect installed tools and cache drift without modifying the active snapshot:

```bash
./scripts/sync_shell_integrations.sh --check
```

Zsh loads generated functions lazily through `fpath` before distro completions, then sources broader integrations before applying tracked keybindings. Bash loads canonical-command completions when the optional `bash-completion` system package is available. Add new tools to the reviewed registry in [`scripts/sync_shell_integrations.sh`](./scripts/sync_shell_integrations.sh);.

## Validation

After an update, run:

```bash
./scripts/check.sh
```

The check covers Bash syntax, ShellCheck, shfmt, mise formatting, every profile, locked dry-run installation, and two-pass linker idempotence. GitHub Actions runs the same checks without applying system packages.

## Situational helpers

- `mitmproxy-env` prepares proxy and CA environment variables for the current
  Zsh session.
- `kpx` integrates KeePassXC where its CLI is available.
- `scripts/Add-Route-to-Tailnet-via-WSL.ps1` is a standalone Windows utility.
