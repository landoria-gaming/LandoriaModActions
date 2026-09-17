#!/usr/bin/env bash
set -euo pipefail
mode=${1:?snapshot or release required}
manifest=${MANIFEST_PATH:-manifest.json}
assembly=${ASSEMBLY_INFO_PATH:-Properties/AssemblyInfo.cs}
eligible=false
version='' informational='' assembly_version='' file_version='' plugin_version=''
if [[ -n "${PLUGIN_SOURCE_PATH:-}" ]]; then plugins=("$PLUGIN_SOURCE_PATH"); else
  shopt -s nullglob
  plugins=("$(dirname "$manifest")"/*Plugin.cs)
fi
if [[ -f "$manifest" && -f "$assembly" && ${#plugins[@]} -eq 1 && -f "${plugins[0]}" ]]; then
  version=$(jq -er '.version_number | strings' "$manifest" 2>/dev/null | tr -d '\r') || version=''
  attribute() {
    sed -nE "s/^[[:space:]]*\\[assembly:[[:space:]]*$1\\(\"([^\"]+)\"\\)\\].*/\\1/p" "$assembly" | tr -d '\r'
  }
  informational=$(attribute AssemblyInformationalVersion)
  assembly_version=$(attribute AssemblyVersion)
  file_version=$(attribute AssemblyFileVersion)
  plugin_version=$(sed -nE 's/^[[:space:]]*((public|private|internal|protected|static)[[:space:]]+)*const[[:space:]]+string[[:space:]]+PluginVersion[[:space:]]*=[[:space:]]*"([^"]+)"[[:space:]]*;.*/\3/p' "${plugins[0]}" | tr -d '\r')
  base=${version%-snapshot}
  format=false
  if [[ "$mode" == snapshot && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-snapshot$ ]]; then format=true; fi
  if [[ "$mode" == release && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then format=true; fi
  if [[ "$format" == true && "$informational" == "$version" && "${assembly_version%.\*}" == "$base" && "$file_version" == "$base" && "$plugin_version" == "$base" ]]; then eligible=true; fi
fi
printf 'Versions: manifest=%s | informational=%s | assembly=%s | file=%s | plugin=%s\n' \
  "$version" "$informational" "$assembly_version" "$file_version" "$plugin_version"
printf 'eligible=%s\n' "$eligible" >> "$GITHUB_OUTPUT"
if [[ "$eligible" == true ]]; then printf 'version=%s\n' "$version" >> "$GITHUB_OUTPUT"; else
  printf '%s package skipped: all five versions must match; only manifest and informational version use -snapshot in snapshot builds.\n' "$mode" >> "$GITHUB_STEP_SUMMARY"
fi
