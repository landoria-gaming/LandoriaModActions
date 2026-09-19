#!/usr/bin/env bash
# Publishes one existing package ZIP through the official Thunderstore CLI.
set -euo pipefail

if [[ -z "${TCLI_AUTH_TOKEN:-}" ]]; then
  echo 'THUNDERSTORE_TOKEN is required when promotion is enabled.' >&2
  exit 1
fi
if [[ ! "$PACKAGE_NAMESPACE" =~ ^[A-Za-z0-9_]+$ || ! "$THUNDERSTORE_COMMUNITY" =~ ^[a-z0-9-]+$ ]]; then
  echo 'Invalid Thunderstore namespace or community.' >&2
  exit 1
fi
mapfile -t packages < <(compgen -G "$PACKAGE_FILE" || true)
if [[ ${#packages[@]} -ne 1 ]]; then
  echo "Expected exactly one package matching $PACKAGE_FILE, found ${#packages[@]}." >&2
  exit 1
fi

package=$(realpath "${packages[0]}")
workspace=$(pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
unzip -p "$package" manifest.json > "$temp_dir/manifest.json"
name=$(jq -er '.name' "$temp_dir/manifest.json")
version=$(jq -er '.version_number' "$temp_dir/manifest.json")
categories=$(jq -c '.categories // []' "$temp_dir/manifest.json")

cat > "$temp_dir/thunderstore.toml" <<EOF
[config]
schemaVersion = "0.0.1"
[package]
namespace = "$PACKAGE_NAMESPACE"
name = "$name"
versionNumber = "$version"
[build]
outdir = "$temp_dir/build"
[publish]
repository = "https://thunderstore.io"
communities = ["$THUNDERSTORE_COMMUNITY"]
[publish.categories]
$THUNDERSTORE_COMMUNITY = $categories
EOF

dotnet run --project "$workspace/$TCLI_PROJECT" --property EnableInstallers=false -- \
  publish --config-path "$temp_dir/thunderstore.toml" --file "$package"
