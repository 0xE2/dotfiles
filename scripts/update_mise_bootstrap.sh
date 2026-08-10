#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$dotfiles_dir/.mise-bootstrap.env"
mise_bin="${MISE_BIN:-${HOME:?}/.local/bin/mise}"
api_url="https://api.github.com/repos/jdx/mise/releases"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for command_name in curl jq; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is missing: $command_name"
done
[[ -x $mise_bin ]] || die "mise is not executable: $mise_bin"

version_json="$(MISE_NO_CONFIG=1 "$mise_bin" version --json)"
installed="$(jq -er '.version | strings' <<<"$version_json")"
latest="$(jq -er '.latest | strings' <<<"$version_json")"
latest="${latest#v}"
[[ $latest =~ ^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$ ]] || die "mise returned an invalid latest version: $latest"

printf 'Installed mise: %s\n' "$installed"
printf 'Latest mise:    %s\n' "$latest"

release_json="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28' \
    "$api_url/tags/v$latest"
)"

[[ "$(jq -er '.tag_name' <<<"$release_json")" == "v$latest" ]] ||
  die "GitHub returned a release with an unexpected tag"
[[ "$(jq -er '.draft' <<<"$release_json")" == false ]] || die "latest release is a draft"
[[ "$(jq -er '.prerelease' <<<"$release_json")" == false ]] || die "latest release is a prerelease"
[[ "$(jq -er '.immutable' <<<"$release_json")" == true ]] || die "latest release is not immutable"

asset_digest() {
  local asset_name=$1
  local digest=""

  digest="$(
    jq -er --arg asset_name "$asset_name" '
      [.assets[] | select(.name == $asset_name and .state == "uploaded")] |
      if length == 1 then .[0].digest else error("release asset is missing or duplicated") end
    ' <<<"$release_json"
  )"
  [[ $digest == sha256:* ]] || die "unsupported digest algorithm for $asset_name"
  digest="${digest#sha256:}"
  [[ $digest =~ ^[0-9a-f]{64}$ ]] || die "invalid SHA-256 digest for $asset_name"
  printf '%s\n' "$digest"
}

x64_digest="$(asset_digest "mise-v${latest}-linux-x64")"
arm64_digest="$(asset_digest "mise-v${latest}-linux-arm64")"

tmp_manifest="$(mktemp "$dotfiles_dir/.mise-bootstrap.env.XXXXXXXXXX")"
[[ -n $tmp_manifest && -f $tmp_manifest ]] || die "failed to create a temporary manifest"
trap '[[ -n ${tmp_manifest:-} && -f ${tmp_manifest:-} ]] && rm -- "$tmp_manifest"' EXIT

{
  printf '# Managed by scripts/update_mise_bootstrap.sh.\n'
  printf 'MISE_VERSION=%s\n' "$latest"
  printf 'MISE_SHA256_X64=%s\n' "$x64_digest"
  printf 'MISE_SHA256_ARM64=%s\n' "$arm64_digest"
} >"$tmp_manifest"
chmod 0644 "$tmp_manifest"

if cmp --silent "$manifest" "$tmp_manifest"; then
  printf 'Bootstrap manifest is already current.\n'
  exit 0
fi

mv -- "$tmp_manifest" "$manifest"
trap - EXIT
printf 'Updated %s to mise %s.\n' "$manifest" "$latest"
printf 'Review the diff and commit the manifest when ready.\n'
