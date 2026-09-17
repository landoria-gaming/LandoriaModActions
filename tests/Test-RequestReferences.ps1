$ErrorActionPreference = 'Stop'
$originalToken = $env:GH_TOKEN
$originalOutput = $env:GITHUB_OUTPUT
$originalExitCode = $global:LASTEXITCODE
$testOutput = [System.IO.Path]::GetTempFileName()
try {
    $env:GH_TOKEN = 'mock-not-a-real-token'
    $env:GITHUB_OUTPUT = $testOutput
    function gh {
        $global:LASTEXITCODE = 0
        $arguments = $args -join ' '
        if ($arguments -match '/dispatches') {
            if ($global:referenceTestScenario -eq 'dispatch-error') { $global:LASTEXITCODE = 1; return }
            return '{"workflow_run_id":123}'
        }
        if ($arguments -match '/artifacts') {
            if ($global:referenceTestScenario -eq 'missing-artifact') { return '{"artifacts":[]}' }
            return '{"artifacts":[{"name":"mod-compilation-references","expired":false}]}'
        }
        $conclusion = if ($global:referenceTestScenario -eq 'failure') { 'failure' } else { 'success' }
        $branch = if ($global:referenceTestScenario -eq 'wrong-branch') { 'feature' } else { 'main' }
        return "{`"head_branch`":`"$branch`",`"event`":`"workflow_dispatch`",`"status`":`"completed`",`"conclusion`":`"$conclusion`",`"html_url`":`"https://example.invalid/run/123`"}"
    }
    $request = "$PSScriptRoot/../tools/Request-References.ps1"
    $global:referenceTestScenario = 'success'
    & $request -Repository 'landoria-gaming/LandoriaModReferences'
    if ((Get-Content -LiteralPath $testOutput -Raw).Trim() -ne 'run-id=123') { throw 'Incorrect dispatched bundle selection.' }
    foreach ($global:referenceTestScenario in 'failure', 'wrong-branch', 'missing-artifact', 'dispatch-error') {
        $failed = $false
        try { & $request -Repository 'landoria-gaming/LandoriaModReferences' } catch { $failed = $true }
        if (-not $failed) { throw "Expected failure: $global:referenceTestScenario" }
    }
    $env:GH_TOKEN = ''
    $failed = $false
    try { & $request -Repository 'landoria-gaming/LandoriaModReferences' } catch { $failed = $true }
    if (-not $failed) { throw 'Missing token must fail before dispatch.' }
    Write-Output 'On-demand reference request tests passed.'
} finally {
    $env:GH_TOKEN = $originalToken
    $env:GITHUB_OUTPUT = $originalOutput
    Remove-Item -LiteralPath $testOutput
    Remove-Variable -Name referenceTestScenario -Scope Global
    $global:LASTEXITCODE = $originalExitCode
}
