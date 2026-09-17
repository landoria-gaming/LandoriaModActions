# Landoria Mod Actions

Reusable Windows GitHub Actions for standalone Landoria Valheim mods.

## Actions

- `check-snapshot`: compares AssemblyInformationalVersion and manifest version_number; both must be identical X.Y.Z-snapshot.
- `cache-references`: downloads the dedicated server and BepInExPack once; caches only managed DLLs and hash metadata.
- `restore-references`: restores both caches, verifies versions and hashes, exports ValheimGamePath and BepInExPath.
- `build-snapshot`: builds a root-level .NET Framework 4.8 project with its HarmonyValidator and calls its PackageThunderstore MSBuild target.
- `publish-snapshot`: updates the rolling snapshot prerelease, tag and two stable ZIP assets. Only the current main head may publish.

All composite actions require a Windows runner and PowerShell. The publishing action requires gh and contents: write; call it only in a trusted main job. No game, Unity, BepInEx or Harmony DLL is distributed in the mod ZIP.

## Reusable workflows

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
    uses: landoria-gaming/LandoriaModActions/.github/workflows/snapshot.yml@v1
    with:
      project-file: Landoria.FirstPerson.csproj
      mod-name: Landoria.FirstPerson
      package-name: FirstPerson
```

The reusable workflow grants write permission only to the main publishing job; eligibility and builds remain read-only. Fork PR permissions are read-only. Set publish: false to disable releases.

A second manual caller invokes `.github/workflows/cache-references.yml@v1` with contents: read. Run it on main before building, and again after cache eviction.

Caller configuration (default `build/valheim-references.json`):

```json
{"version":"1.0.12","steam_app_id":896660,"steam_beta":"public","bepinex_version":"5.4.2350","cache_revision":1}
```

Caches belong to the calling mod repository, not this repository. GitHub may evict unused caches after 7 days; caches are not permanent storage. Increase cache_revision to create fresh immutable entries. The archive workflow checks the actual downloaded game version and fails rather than caching mismatched DLLs. An old game version cannot be downloaded from a beta that no longer serves it.

The mod retains its local PackageThunderstore target and source version files. No suffix is added automatically. Package files must be at repository root; DLL output must be bin/Release/<mod-name>.dll. Artifacts are retained 30 days. Only main push/manual builds publish.

The v1 tag identifies this API. Workflow and composite actions use the same tag; advance it deliberately for compatible updates.
