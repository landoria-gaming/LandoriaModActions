$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$actions = Get-ChildItem -Path "$repository/actions/*/action.yml"
foreach ($action in $actions) {
    $raw = Get-Content -LiteralPath $action.FullName -Raw
    foreach ($block in [regex]::Matches($raw, '(?ms)^      run: \|\r?\n(.*?)(?=^    - |\z)')) {
        $script = ($block.Groups[1].Value -split '\r?\n' | ForEach-Object { $_ -replace '^        ', '' }) -join "`n"
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count) { throw "Invalid PowerShell in $($action.FullName): $($errors | Out-String)" }
    }
    Write-Output "Syntax valid: $($action.Directory.Name)"
}

$check = Get-Content -LiteralPath "$repository/actions/check-snapshot/action.yml" -Raw
$condition = [regex]::Match($check, '(?ms)^\s*\$assemblyVersionMatches = .*?(?=\r?\n\s*} catch)').Value
if (-not $condition) { throw 'Snapshot condition not found.' }
$cases = @(
    @{ Manifest = '1.0.11-snapshot'; Assembly = '1.0.11-snapshot'; Expected = $true },
    @{ Manifest = '1.0.12-snapshot'; Assembly = '1.0.11-snapshot'; Expected = $false },
    @{ Manifest = '1.0.11'; Assembly = '1.0.11'; Expected = $false },
    @{ Manifest = '1.0.11-snapshot'; Assembly = ''; Expected = $false },
    @{ Manifest = '1.0.11-snapshot'; Assembly = '1.0.11-SNAPSHOT'; Expected = $false }
)
foreach ($case in $cases) {
    $manifest = [pscustomobject]@{ version_number = $case.Manifest }
    $assemblyInfo = '[assembly: AssemblyInformationalVersion("' + $case.Assembly + '")]'
    . ([scriptblock]::Create($condition))
    if ($eligible -ne $case.Expected) { throw "Wrong eligibility for $($case.Manifest) / $($case.Assembly)" }
}
Write-Output 'Snapshot eligibility tests passed.'

$restore = Get-Content -LiteralPath "$repository/actions/restore-references/action.yml" -Raw
if ($restore -match 'steamcmd|Invoke-WebRequest|actions/cache/save') {
    throw 'Restore action must never download or save compilation dependencies.'
}
Write-Output 'Restore-only dependency policy passed.'
& "$PSScriptRoot/Test-RequestReferences.ps1"
$workflow = Get-Content -LiteralPath "$repository/.github/workflows/snapshot.yml" -Raw
if ($workflow -notmatch "github.ref == 'refs/heads/main'" -or
    $workflow -match 'pull_request.head.repo') { throw 'Reference builds must be restricted to trusted main events.' }

foreach ($tool in Get-ChildItem -LiteralPath "$repository/tools" -Filter '*.ps1') {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($tool.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}
