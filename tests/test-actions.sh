#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
for script in "$root"/tools/*.sh "$root"/tests/*.sh; do bash -n "$script"; done
if grep -REn 'shell: pwsh|\.ps1' "$root/actions" "$root/.github"; then echo 'PowerShell is forbidden.' >&2; exit 1; fi
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export MANIFEST_PATH="$fixture/manifest.json" ASSEMBLY_INFO_PATH="$fixture/AssemblyInfo.cs"
export GITHUB_OUTPUT="$fixture/output" GITHUB_STEP_SUMMARY="$fixture/summary"
check() {
  printf '{"version_number":"%s"}\n' "$1" > "$MANIFEST_PATH"
  printf '[assembly: AssemblyInformationalVersion("%s")]\n' "$2" > "$ASSEMBLY_INFO_PATH"
  : > "$GITHUB_OUTPUT"
  bash "$root/tools/check-snapshot.sh"
  [[ $(tr -d '\r' < "$GITHUB_OUTPUT") == "eligible=$3" ]]
}
check 1.0.11-snapshot 1.0.11-snapshot true
check 1.0.12-snapshot 1.0.11-snapshot false
check 1.0.11 1.0.11 false
check 1.0.11-snapshot 1.0.11-SNAPSHOT false
printf '\n[assembly: AssemblyInformationalVersion("1.0.11-snapshot")]\n' >> "$ASSEMBLY_INFO_PATH"
: > "$GITHUB_OUTPUT"
bash "$root/tools/check-snapshot.sh"
grep -q 'eligible=false' "$GITHUB_OUTPUT"
printf '{broken json' > "$MANIFEST_PATH"
bash "$root/tools/check-snapshot.sh"

check_release() {
  printf '{"version_number":"%s"}\n' "$1" > "$MANIFEST_PATH"
  printf '[assembly: AssemblyInformationalVersion("%s")]\n' "$2" > "$ASSEMBLY_INFO_PATH"
  : > "$GITHUB_OUTPUT"
  bash "$root/tools/check-release.sh"
  grep -qx "eligible=$3" "$GITHUB_OUTPUT"
  if [[ "$3" == true ]]; then grep -qx "version=$1" "$GITHUB_OUTPUT"; fi
}
check_release 1.0.11 1.0.11 true
check_release 1.0.12 1.0.11 false
check_release 1.0.11-snapshot 1.0.11-snapshot false
check_release 1.0.11 1.0.11-snapshot false
check_release 1.0.11-draft 1.0.11-draft false
printf '[assembly: AssemblyInformationalVersion("1.0.11")]\n' >> "$ASSEMBLY_INFO_PATH"
: > "$GITHUB_OUTPUT"
bash "$root/tools/check-release.sh"
grep -qx 'eligible=false' "$GITHUB_OUTPUT"
printf '{invalid' > "$MANIFEST_PATH"
bash "$root/tools/check-release.sh"

# MSBuild rejects invalid versions before invoking the mod packaging target.
mkdir -p "$fixture/Properties"
cp "$ASSEMBLY_INFO_PATH" "$fixture/Properties/AssemblyInfo.cs"
printf '%s\n' '<Project><Target Name="PackageThunderstore"><WriteLinesToFile File="$(MSBuildProjectDirectory)/built.txt" Lines="built" /></Target></Project>' > "$fixture/ReleaseTest.proj"
release_project=$(cygpath -m "$root/tools/release.proj")
mod_project=$(cygpath -m "$fixture/ReleaseTest.proj")
printf '{"version_number":"1.0.11"}\n' > "$MANIFEST_PATH"
printf '[assembly: AssemblyInformationalVersion("1.0.11")]\n' > "$fixture/Properties/AssemblyInfo.cs"
dotnet msbuild "$release_project" -t:PackageRelease "-p:ModProject=$mod_project"
[[ -f "$fixture/built.txt" ]]
rm "$fixture/built.txt"
for version in 1.0.12 1.0.11-snapshot; do
  printf '{"version_number":"%s"}\n' "$version" > "$MANIFEST_PATH"
  if dotnet msbuild "$release_project" -t:PackageRelease "-p:ModProject=$mod_project"; then exit 1; fi
  [[ ! -f "$fixture/built.txt" ]]
done

# Mock the API, never make a real dispatch in tests.
gh() {
  if [[ "$*" == *'/dispatches'* ]]; then
    [[ "$SCENARIO" != dispatch-error ]] || return 1
    echo '{"workflow_run_id":123}'
  elif [[ "$*" == *'/artifacts'* ]]; then
    if [[ "$SCENARIO" == missing-artifact ]]; then echo '{"artifacts":[]}'; else
      echo '{"artifacts":[{"name":"mod-compilation-references","expired":false}]}'; fi
  else
    status=completed; conclusion=success; branch=main
    [[ "$SCENARIO" != failure ]] || conclusion=failure
    [[ "$SCENARIO" != wrong-branch ]] || branch=feature
    [[ "$SCENARIO" != timeout ]] || status=in_progress
    printf '{"head_branch":"%s","event":"workflow_dispatch","status":"%s","conclusion":"%s","html_url":"https://example.invalid/run/123"}\n' "$branch" "$status" "$conclusion"
  fi
}
export -f gh
export GH_TOKEN=mock-not-a-real-token SCENARIO=success REFERENCE_TIMEOUT_SECONDS=0
: > "$GITHUB_OUTPUT"
bash "$root/tools/request-references.sh" landoria-gaming/LandoriaModReferences
grep -q 'run-id=123' "$GITHUB_OUTPUT"
for SCENARIO in failure wrong-branch missing-artifact dispatch-error timeout; do
  export SCENARIO
  if bash "$root/tools/request-references.sh" landoria-gaming/LandoriaModReferences; then echo "Expected failure: $SCENARIO" >&2; exit 1; fi
done
if GH_TOKEN='' bash "$root/tools/request-references.sh" landoria-gaming/LandoriaModReferences; then exit 1; fi

for kind in valheim bepinex; do
  if [[ "$kind" == valheim ]]; then dir="$fixture/$kind-references/valheim_Data/Managed"; names=(assembly_valheim.dll netstandard.dll); else
    dir="$fixture/$kind-references/BepInEx/core"; names=(BepInEx.dll 0Harmony.dll); fi
  mkdir -p "$dir"
  files='[]'
  for name in "${names[@]}"; do
    printf 'fixture DLL\n' > "$dir/$name"
    hash=$(sha256sum "$dir/$name"); hash=${hash%% *}
    files=$(jq -c --arg name "$name" --arg hash "$hash" '. + [{name:$name,sha256:$hash}]' <<< "$files")
  done
  jq -n --argjson files "$files" '{version:"1.0.12",files:$files}' > "$fixture/$kind-references/build-references.json"
done
bash "$root/tools/validate-references.sh" "$fixture"
printf 'tampered' >> "$fixture/valheim-references/valheim_Data/Managed/assembly_valheim.dll"
if bash "$root/tools/validate-references.sh" "$fixture"; then echo 'Tampered DLL was accepted.' >&2; exit 1; fi

# Reference versions must reach both the console and saved log before compilation.
dotnet() { return 1; }
export -f dotnet
if (cd "$fixture"; MOD_NAME=Landoria.Test PROJECT_FILE=Test.csproj VALHEIM_VERSION=1.0.12 BEPINEX_VERSION=5.4.2350 REFERENCE_RUN_ID=123 \
  bash "$root/tools/build-snapshot.sh" > console.log); then exit 1; fi
unset -f dotnet
for log in "$fixture/console.log" "$fixture/obj/snapshot-build.log"; do
  grep -q 'Valheim 1.0.12 | BepInEx 5.4.2350 | Reference run 123' "$log"
done

# Packaging belongs to MSBuild; stage only the mod DLL, not other build references.
mkdir -p "$fixture/bin/Release"
printf 'mod DLL' > "$fixture/bin/Release/Landoria.Test.dll"
printf 'must not ship' > "$fixture/bin/Release/UnityEngine.dll"
printf 'icon' > "$fixture/icon.png"
printf 'README' > "$fixture/README.md"
printf 'manifest metadata' > "$fixture/valheim-appmanifest.acf"
dotnet msbuild "$(cygpath -m "$root/tools/archive.proj")" -t:StageSnapshot \
  "-p:ModRoot=$(cygpath -m "$fixture")" -p:ModName=Landoria.Test \
  "-p:ReferenceMetadata=$(cygpath -m "$fixture/valheim-appmanifest.acf")"
[[ -s "$fixture/bin/snapshot/Landoria.Test.dll" && ! -e "$fixture/bin/snapshot/UnityEngine.dll" ]]
dotnet msbuild "$(cygpath -m "$root/tools/archive.proj")" -t:Zip \
  "-p:SourceDirectory=$(cygpath -m "$fixture/bin/snapshot")" "-p:DestinationFile=$(cygpath -m "$fixture/snapshot.zip")"
[[ -s "$fixture/snapshot.zip" ]]
# Publication keeps the version in both asset names and removes old names after upload.
mkdir -p "$fixture/snapshot" "$fixture/thunderstore"
printf '{"version_number":"1.0.11-snapshot"}\n' > "$fixture/snapshot/manifest.json"
cp "$fixture/snapshot.zip" "$fixture/thunderstore/Landoria-Test-1.0.11-snapshot.zip"
gh() {
  case "$*" in
    *'git/ref/heads/main'*) echo abc ;;
    'release view snapshot --json assets') echo '{"assets":[{"name":"Landoria-Test-snapshot.zip"}]}' ;;
    'release upload '*|'release delete-asset '*) printf '%s\n' "$*" >> "$ASSET_TRACE" ;;
    *) return 0 ;;
  esac
}
export -f gh
export ASSET_TRACE="$fixture/asset-trace" MOD_NAME=Landoria.Test PACKAGE_NAME=Test GH_REPO=org/Test
export GITHUB_REF=refs/heads/main GITHUB_EVENT_NAME=workflow_dispatch GITHUB_SHA=abc GITHUB_RUN_ID=123 GITHUB_SERVER_URL=https://github.com
(cd "$fixture"; bash "$root/tools/publish-snapshot.sh")
grep -q 'release upload snapshot release/Landoria-Test-1.0.11-snapshot.zip release/Landoria.Test-1.0.11-snapshot.zip' "$ASSET_TRACE"
grep -q 'release delete-asset snapshot Landoria-Test-snapshot.zip' "$ASSET_TRACE"
echo 'Bash action tests passed.'
