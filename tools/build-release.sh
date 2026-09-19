#!/usr/bin/env bash
set -euo pipefail
tools=$(cd "$(dirname "$0")" && pwd)
actions_root=$(cd "$tools/.." && pwd)
thunderstore_targets=$(cygpath -m "$actions_root/build/Thunderstore.targets")
mod_project=$(cygpath -m "$PWD/$PROJECT_FILE")
mkdir -p obj
printf 'Compilation references: Valheim %s | BepInEx %s | Reference run %s\n' \
  "$VALHEIM_VERSION" "$BEPINEX_VERSION" "$REFERENCE_RUN_ID" | tee obj/release-build.log
dotnet restore "$PROJECT_FILE" -p:Configuration=Release
dotnet msbuild "$(cygpath -m "$tools/release.proj")" -t:PackageRelease \
  "-p:ModProject=$mod_project" "-p:ThunderstoreProject=$mod_project" \
  "-p:CustomAfterMicrosoftCommonTargets=$thunderstore_targets" \
  -v:minimal -fl '-flp:logfile=obj/release-build.log;verbosity=normal;append'
shopt -s nullglob
archives=(bin/thunderstore/*.zip)
[[ ${#archives[@]} -eq 1 ]]
