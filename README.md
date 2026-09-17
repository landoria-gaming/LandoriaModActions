# Landoria Mod Actions

Reusable Windows GitHub Actions for standalone Landoria Valheim mods.

## Shared organization references (v4.2)

All mods use the same private reference bundle in
`landoria-gaming/LandoriaModReferences`, containing Valheim/Unity managed DLLs
and BepInEx/Harmony compilation references. No per-mod cache or dependency
update job is used. Before each trusted main build, the consumer dispatches the
private central workflow and waits for its exact run. That workflow checks Steam
and Thunderstore on demand, reuses unchanged DLLs, and downloads only changed or
missing dependencies. No scheduled update is used. Old bundles are pruned after
success with a two-hour download grace period. Expired references are regenerated.

## Actions

- `check-snapshot`: both AssemblyInformationalVersion and version_number must equal X.Y.Z-snapshot.
- `restore-references`: dispatches the central check, waits for success, downloads that run's bundle, verifies all DLL hashes and exports build paths.
- `build-snapshot`: builds with the mod's HarmonyValidator and calls its PackageThunderstore target. Reference versions and source run are recorded in build metadata.
- `publish-snapshot`: updates the snapshot prerelease and its stable ZIP assets, only for the current main head.

Composite actions require Windows, Bash and jq. Compilation, staging and ZIP
creation use MSBuild targets. PowerShell scripts are not used. The publishing action requires
GitHub CLI and contents: write. Valheim, Unity, BepInEx and Harmony references
are never included in mod packages or published publicly.

## Consumer workflow

```yaml
name: Snapshot build
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  snapshot:
    permissions:
      contents: write
    uses: landoria-gaming/LandoriaModActions/.github/workflows/snapshot.yml@v4.2
    with:
      project-file: Landoria.FirstPerson.csproj
      mod-name: Landoria.FirstPerson
      package-name: FirstPerson
    secrets:
      references-token: ${{ secrets.MOD_REFERENCES_TOKEN }}
```

Create organization secret `MOD_REFERENCES_TOKEN`, available only to the mod
repositories. Use a dedicated fine-grained PAT with Actions: write and Metadata: read
restricted to the private LandoriaModReferences repository. Actions: write is
needed to dispatch the on-demand check. Ordinary mod GITHUB_TOKEN cannot access it.
Do not reuse an administrator token or expose reference files in public artifacts.

All pull requests and manual runs outside main skip dependency builds;
never use pull_request_target to execute untrusted source with this token.
Only main push/manual builds use the reference token. Missing credentials on
trusted runs fail explicitly. The workflow keeps caller build and eligibility jobs
read-only and grants write access only to the main release job. Set publish: false
to disable rolling releases.

The caller retains PackageThunderstore and version metadata. Files are at repository
root, DLL output is bin/Release/<mod-name>.dll. No suffix is added automatically.
Snapshot artifacts are retained 30 days. Only main push/manual builds publish.
All opted-in mods select the same central source; a central update does not
rebuild the mods automatically or change their own versions.

Version v4 uses Bash orchestration and MSBuild archive tasks. Version v3 adds
on-demand checks and main-only trusted builds. v2 used scheduled
central updates; v1 used repository-local caches. Earlier tags are retained.
