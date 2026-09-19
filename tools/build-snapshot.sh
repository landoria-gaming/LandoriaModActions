#!/usr/bin/env bash
set -euo pipefail
[[ "$MOD_NAME" =~ ^[A-Za-z0-9_.-]+$ ]] || exit 1
tools=$(cd "$(dirname "$0")" && pwd)
actions_root=$(cd "$tools/.." && pwd)
native_path() { cygpath -m "$1"; }
thunderstore_targets=$(native_path "$actions_root/build/Thunderstore.targets")
mod_project=$(native_path "$PWD/$PROJECT_FILE")
mkdir -p obj
printf 'Compilation references: Valheim %s | BepInEx %s | Reference run %s\n' \
  "$VALHEIM_VERSION" "$BEPINEX_VERSION" "$REFERENCE_RUN_ID" | tee obj/snapshot-build.log
dotnet msbuild "$(native_path "$tools/archive.proj")" -t:ValidateModVersions \
  "-p:ModRoot=$(native_path "$PWD")" -p:VersionMode=snapshot
dotnet build "$PROJECT_FILE" -c Release --nologo -p:Platform=AnyCPU \
  "-p:CustomAfterMicrosoftCommonTargets=$thunderstore_targets" \
  "-p:ThunderstoreProject=$mod_project" \
  -v minimal -fl '-flp:logfile=obj/snapshot-build.log;verbosity=normal;append'
temp=$(cygpath -u "$RUNNER_TEMP")
dotnet msbuild "$(native_path "$tools/archive.proj")" -t:StageSnapshot \
  "-p:ModRoot=$(native_path "$PWD")" "-p:ModName=$MOD_NAME" \
  "-p:ReferenceMetadata=$(native_path "$temp/snapshot-dependencies/valheim-appmanifest.acf")"
[[ -s "bin/snapshot/$MOD_NAME.dll" ]] || exit 1
dotnet msbuild "$PROJECT_FILE" -t:StageSnapshotExtras -p:Configuration=Release \
  "-p:CustomAfterMicrosoftCommonTargets=$thunderstore_targets" \
  "-p:ThunderstoreProject=$mod_project"
hash=$(sha256sum "bin/snapshot/$MOD_NAME.dll"); hash=${hash%% *}
jq -n --arg commit "$(git rev-parse HEAD | tr -d '\r')" --arg run "$GITHUB_RUN_ID" \
  --arg attempt "$GITHUB_RUN_ATTEMPT" --arg utc "$(date -u +%FT%TZ)" \
  --arg bepinex "$BEPINEX_VERSION" --arg valheim "$VALHEIM_VERSION" \
  --arg references "$REFERENCE_RUN_ID" --arg hash "$hash" \
  '{kind:"snapshot",commit:$commit,run:$run,attempt:$attempt,builtUtc:$utc,framework:".NET Framework 4.8",platform:"AnyCPU",configuration:"Release",bepinexVersion:$bepinex,valheimVersion:$valheim,referenceRun:$references,dllSha256:$hash}' > bin/snapshot/build-info.json
dotnet build "$PROJECT_FILE" -c Release --no-restore --nologo \
  -t:PackageThunderstore -p:Platform=AnyCPU -p:SnapshotBuild=true \
  "-p:CustomAfterMicrosoftCommonTargets=$thunderstore_targets" \
  "-p:ThunderstoreProject=$mod_project"
