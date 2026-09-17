# Landoria Mod Actions

Reusable Windows GitHub Actions for standalone Landoria Valheim mods.

## Shared organization references (v2)

All mods use the same private reference bundle in
`landoria-gaming/LandoriaModReferences`, containing Valheim/Unity managed DLLs
and BepInEx/Harmony compilation references. No per-mod cache or dependency
update job is used. Only the private central repository checks Steam daily,
downloads new builds and removes previous bundles after successful replacement.

## Actions

- `check-snapshot`: both AssemblyInformationalVersion and version_number must equal X.Y.Z-snapshot.
- `restore-references`: selects the latest successful central reference bundle, downloads it with a read-only token, verifies all DLL hashes and exports build paths.
- `build-snapshot`: builds with the mod's HarmonyValidator and calls its PackageThunderstore target. Reference versions and source run are recorded in build metadata.
- `publish-snapshot`: updates the snapshot prerelease and its stable ZIP assets, only for the current main head.

Composite actions require Windows and PowerShell. The publishing action requires
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
    uses: landoria-gaming/LandoriaModActions/.github/workflows/snapshot.yml@v2
    with:
      project-file: Landoria.FirstPerson.csproj
      mod-name: Landoria.FirstPerson
      package-name: FirstPerson
    secrets:
      references-token: ${{ secrets.MOD_REFERENCES_TOKEN }}
```

Create organization secret `MOD_REFERENCES_TOKEN`, available only to the mod
repositories. Use a fine-grained PAT with Actions: read and Metadata: read
restricted to the private LandoriaModReferences repository, or an equivalent
GitHub App installation token. Ordinary mod GITHUB_TOKEN cannot access it.
Do not reuse an administrator token or expose reference files in public artifacts.

Fork pull requests skip builds because private reference secrets are unavailable;
never use pull_request_target to execute untrusted source with this token.
Same-repository PRs can build using the read-only token. Missing credentials on
trusted runs fail explicitly. The workflow keeps build and eligibility jobs
read-only and grants write access only to the main release job. Set publish: false
to disable rolling releases.

The caller retains PackageThunderstore and version metadata. Files are at repository
root, DLL output is bin/Release/<mod-name>.dll. No suffix is added automatically.
Snapshot artifacts are retained 30 days. Only main push/manual builds publish.
All opted-in mods select the same central source; a central update does not
rebuild the mods automatically or change their own versions.

Version v2 introduces the private global store; v1 is retained for compatibility
and used repository-local caches. Advance API tags deliberately for compatible updates.
