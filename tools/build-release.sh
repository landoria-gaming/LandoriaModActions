#!/usr/bin/env bash
set -euo pipefail
tools=$(cd "$(dirname "$0")" && pwd)
mkdir -p obj
printf 'Compilation references: Valheim %s | BepInEx %s | Reference run %s\n' \
  "$VALHEIM_VERSION" "$BEPINEX_VERSION" "$REFERENCE_RUN_ID" | tee obj/release-build.log
dotnet restore "$PROJECT_FILE" -p:Configuration=Release
dotnet msbuild "$(cygpath -m "$tools/release.proj")" -t:PackageRelease \
  "-p:ModProject=$(cygpath -m "$PWD/$PROJECT_FILE")" \
  -v:minimal -fl '-flp:logfile=obj/release-build.log;verbosity=normal;append'
shopt -s nullglob
archives=(bin/thunderstore/*.zip)
[[ ${#archives[@]} -eq 1 ]]
