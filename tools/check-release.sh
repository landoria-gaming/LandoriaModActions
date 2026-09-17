#!/usr/bin/env bash
set -euo pipefail
manifest=${MANIFEST_PATH:-manifest.json}
assembly=${ASSEMBLY_INFO_PATH:-Properties/AssemblyInfo.cs}
eligible=false
version=''
if [[ -f "$manifest" && -f "$assembly" ]]; then
  version=$(jq -er '.version_number | strings' "$manifest" 2>/dev/null | tr -d '\r') || version=''
  declarations=$(sed -nE 's/^[[:space:]]*\[assembly:[[:space:]]*AssemblyInformationalVersion\("([^"]+)"\)\].*/\1/p' "$assembly" | tr -d '\r')
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$declarations" == "$version" ]]; then eligible=true; fi
fi
printf 'eligible=%s\n' "$eligible" >> "$GITHUB_OUTPUT"
if [[ "$eligible" == true ]]; then
  printf 'version=%s\n' "$version" >> "$GITHUB_OUTPUT"
else
  echo 'Release package skipped: AssemblyInformationalVersion and version_number must be identical X.Y.Z versions without a suffix.' >> "$GITHUB_STEP_SUMMARY"
fi
