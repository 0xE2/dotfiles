# mise configuration

This directory contains the mise configuration, tool locks, and profile selection for this repository. Bootstrap links it to `~/.config/mise`, installs the mise version pinned in `.mise-bootstrap.env`, selects a profile or generated environment list, and installs the selected tools from committed locks.

Run repository scripts from the repository root.

## Structure

The mise configuration is split across these files:

- `config.*.toml` files define tools and tasks for each environment.
- `mise.*.lock` files pin resolved tool versions, downloads, and checksums.
- `profiles/*.miserc.toml` files define committed environment selections.
- `miserc.toml` selects the active profile or generated environment list.

## Selecting profiles

Bootstrap selects profiles for you. To select `personal-dev`, run:

```sh
./bootstrap.sh --profile personal-dev
```

To switch profiles manually, relink `~/.config/mise/miserc.toml`:

```sh
ln -sf ~/.config/mise/profiles/personal-dev.miserc.toml ~/.config/mise/miserc.toml
```

For a one-off combination instead of a committed profile, let bootstrap generate `miserc.toml` from an environment list:

```sh
./bootstrap.sh --env shell-base,languages,personal
```

`personal` and `work` cannot be selected together because both configure Java.

## Using the Android lab profile

The `android-lab` profile keeps Android command-line and reverse-engineering tools in the persistent user home of a Qubes AppVM.

After you bootstrap this profile, accept the Android SDK licenses and install the emulator components:

```sh
mise run android-sdk:licenses
mise run android-sdk:components
```

The component task installs these files below mise's persistent Android SDK installation:

- Android 14 ARM64 system image
- Android emulator
- Android platform tools
- API 35 platform files
- Android build tools

## Managing Python CLI tools

Mise manages persistent Python command-line tools with the `pipx:` backend. When `uv` is available, mise uses `uv tool install` for those tools.

Use `pipxu` and the `pipxu-shell` helper for ad hoc Python tools that should not be pinned in this repository.

## Updating lock files

Lock files are in `~/.config/mise/`, not the current project directory. Use `--global` when you run `mise lock` directly.

If you run plain `mise lock`, mise targets the current directory's config root and reports `No tools configured to lock`.

```sh
# Refresh checksums/URLs for currently pinned versions (no version changes)
mise lock --global

# Bump "latest"/fuzzy selectors to newest matching versions, then relock
mise lock --global --bump

# Preview what --bump would change without writing
mise lock --global --bump --dry-run

# Update a single tool
mise lock --global kubectl
```

The `minimum_release_age = "7d"` setting in `config.toml` prevents locks from using releases that are less than seven days old.

To refresh committed locks for Linux x86-64 and ARM64 with the pinned mise version, run:

```sh
./scripts/update_mise_locks.sh
```

To refresh selected environment locks only, pass a comma-separated environment list:

```sh
./scripts/update_mise_locks.sh devsecops
./scripts/update_mise_locks.sh --env languages,devops
```

## Updating the mise bootstrap version

Mise itself is a bootstrap dependency, not a tool lock. `.mise-bootstrap.env` pins the mise version and the Linux x86-64 and ARM64 checksums.

To update the manifest to the latest stable immutable GitHub release, run:

```sh
./scripts/update_mise_bootstrap.sh
```

The updater reads the latest version from `mise version --json`, gets both asset digests from the GitHub Releases API, and changes only `.mise-bootstrap.env`. It does not install the new binary or create a Git commit. The seven-day tool release delay does not apply to mise itself.

## Adding a new tool

Add a new tool as follows:

1. Add the tool to the appropriate `config.*.toml` file under `[tools]`:

   ```toml
   mytool = "latest"
   ```

2. Lock it (resolves the version and writes the lock entry):

   ```sh
   mise lock --global --bump mytool
   ```

3. Install it:

   ```sh
   mise install mytool
   ```

If the tool should be available in all profiles, add it to `config.shell-base.toml`.
If it's profile-specific, add it to the relevant config and make sure the target profile's `miserc.toml` includes that env.

## Reinstalling pipx tools after option changes

Mise does not always rebuild an already-installed `pipx:` tool when install options change. For example, after you add `uvx_args = "--with aiohttp"` to `pipx:mitmproxy`, force reinstall the existing tool:

```sh
mise install --force --verbose pipx:mitmproxy@12.2.3
```

This command makes mise recreate the uv tool environment with the injected dependency.

To check the injected package inside mitmproxy's own virtual environment, run:

```sh
~/.local/share/mise/installs/pipx-mitmproxy/12.2.3/mitmproxy/bin/python -c 'import aiohttp; print(aiohttp.__version__)'
```
