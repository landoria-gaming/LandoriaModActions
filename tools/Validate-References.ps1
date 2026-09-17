param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
foreach ($kind in 'valheim', 'bepinex') {
    $directory = Join-Path $Root "$kind-references"
    $managed = if ($kind -eq 'valheim') { "$directory/valheim_Data/Managed" } else { "$directory/BepInEx/core" }
    $metadata = Get-Content -LiteralPath "$directory/build-references.json" -Raw | ConvertFrom-Json
    if (-not $metadata.files.Count -or $metadata.version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid $kind metadata." }
    $names = @($metadata.files | ForEach-Object name)
    if (@($names | Sort-Object -Unique).Count -ne $names.Count) { throw "Duplicate $kind reference names." }
    if (@(Get-ChildItem -LiteralPath $managed -Filter '*.dll').Count -ne $names.Count) { throw "Unlisted $kind references." }
    foreach ($file in $metadata.files) {
        if ($file.name -notmatch '^[A-Za-z0-9_.-]+\.dll$') { throw 'Invalid reference filename.' }
        if ($kind -eq 'bepinex' -and $file.name -notin @('BepInEx.dll', '0Harmony.dll')) { throw 'Unexpected BepInEx reference.' }
        $path = Join-Path $managed $file.name
        if ((Get-Item -LiteralPath $path).Length -eq 0 -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) { throw "Invalid hash for $($file.name)." }
    }
    $required = if ($kind -eq 'valheim') { @('assembly_valheim.dll', 'netstandard.dll') } else { @('BepInEx.dll', '0Harmony.dll') }
    foreach ($name in $required) { if ($name -notin $names) { throw "Missing reference $name." } }
}
