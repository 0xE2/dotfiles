# Linux dotfiles and user toolchain

This repository configures a user-wide Linux shell environment and installs versioned tools with [mise](https://mise.jdx.dev/). It targets x86-64 and ARM64 hosts running WSL2, Ubuntu, or Qubes OS. Windows files in the repository are standalone host utilities; Windows itself is not a bootstrap target.

## Quick start

The bootstrap requires `curl` and `sha256sum`. It downloads the repository's exact mise release to `~/.local/bin/mise`, verifies its published SHA-256 checksum, links the dotfiles, selects a host profile, installs pinned plugins, and installs tools from committed locks.

```bash
./bootstrap.sh --profile personal-dev
./bootstrap.sh --profile work --system
```

`--system` is deliberately separate because it may invoke `sudo` through apt. Without it, bootstrap changes only user-owned state.

For a one-off combination instead of a committed profile:

```bash
./bootstrap.sh --env shell-base,languages,personal
```

Run `./bootstrap.sh --help` for the complete interface. Re-running bootstrap is safe. It refuses unmanaged dotfile conflicts, dirty plugin repositories, and invalid or contradictory environment selections.

## Profiles and categories

Profiles live under `.config/mise/profiles/`. Bootstrap selects one by linking it to the ignored `.config/mise/miserc.toml`. An explicit `--env` selection generates that local file instead. `personal` and `work` cannot be selected together because both configure Java.

Mise's `pipx:` backend uses `uv tool install` whenever uv is available. Mise owns persistent Python CLI declarations; `pipxu` remains available for ad hoc tools and the `pipxu-shell` helper.

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

## Updates and validation

Fuzzy tool constraints are held back for seven days. Committed lockfiles record the resolved downloads and checksums for Linux x86-64 and ARM64. Update them deliberately with the repository's pinned mise version:

```bash
./scripts/update_mise_locks.sh
```

Mise itself is a bootstrap dependency rather than a tool lock. Its version and Linux x86-64/ARM64 checksums live in `.mise-bootstrap.env`. Update that manifest to the latest stable immutable GitHub release with:

```bash
./scripts/update_mise_bootstrap.sh
```

The updater reads the latest version from `mise version --json`, obtains both asset digests from the GitHub Releases API, and changes only the manifest. It does not install the new binary or create a Git commit. The seven-day tool release delay does not apply to mise itself.

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
