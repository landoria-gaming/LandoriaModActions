#!/usr/bin/env bash
set -euo pipefail
tools=$(cd "$(dirname "$0")" && pwd)
temp=$(cygpath -u "$RUNNER_TEMP")
root="$temp/shared-references"
bash "$tools/validate-references.sh" "$root"
valheim=$(jq -r '.version' "$root/valheim-references/build-references.json" | tr -d '\r')
bepinex=$(jq -r '.version' "$root/bepinex-references/build-references.json" | tr -d '\r')
jq -e --arg v "$valheim" --arg b "$bepinex" --arg run "$REFERENCE_RUN_ID" \
  '.valheimVersion == $v and .bepinexVersion == $b and (.sourceRun|tostring) == $run' "$root/bundle.json" >/dev/null
{
  printf 'ValheimGamePath=%s\n' "$(cygpath -m "$root/valheim-references")"
  printf 'BepInExPath=%s\n' "$(cygpath -m "$root/bepinex-references/BepInEx")"
  printf 'BEPINEX_VERSION=%s\nVALHEIM_VERSION=%s\nREFERENCE_RUN_ID=%s\n' "$bepinex" "$valheim" "$REFERENCE_RUN_ID"
} >> "$GITHUB_ENV"
mkdir -p "$temp/snapshot-dependencies"
cp "$root/valheim-references/valheim-appmanifest.acf" "$temp/snapshot-dependencies/valheim-appmanifest.acf"
