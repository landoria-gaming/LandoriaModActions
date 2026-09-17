#!/usr/bin/env bash
set -euo pipefail
root=${1:?Reference root required}
for kind in valheim bepinex; do
  directory="$root/$kind-references"
  if [[ "$kind" == valheim ]]; then managed="$directory/valheim_Data/Managed"; else managed="$directory/BepInEx/core"; fi
  metadata="$directory/build-references.json"
  jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$metadata" >/dev/null
  jq -e '.files | length > 0 and (map(.name | ascii_downcase) | unique | length) == length' "$metadata" >/dev/null
  expected=$(jq '.files | length' "$metadata" | tr -d '\r')
  actual=$(find "$managed" -maxdepth 1 -iname '*.dll' -type f | wc -l)
  [[ "$expected" -eq "$actual" ]] || { echo "Unlisted $kind DLLs." >&2; exit 1; }
  while IFS=$'\t' read -r name hash; do
    hash=${hash//$'\r'/}
    [[ "$name" =~ ^[A-Za-z0-9_.-]+\.dll$ && "$hash" =~ ^[A-Fa-f0-9]{64}$ ]] || exit 1
    if [[ "$kind" == bepinex ]]; then [[ "$name" == BepInEx.dll || "$name" == 0Harmony.dll ]] || exit 1; fi
    [[ -s "$managed/$name" ]] || exit 1
    actual_hash=$(sha256sum "$managed/$name"); actual_hash=${actual_hash%% *}
    [[ "${actual_hash,,}" == "${hash,,}" ]] || { echo "Invalid hash: $name" >&2; exit 1; }
  done < <(jq -r '.files[] | [.name,.sha256] | @tsv' "$metadata")
  if [[ "$kind" == valheim ]]; then required=(assembly_valheim.dll netstandard.dll); else required=(BepInEx.dll 0Harmony.dll); fi
  for name in "${required[@]}"; do jq -e --arg name "$name" '.files | any(.name == $name)' "$metadata" >/dev/null; done
done
