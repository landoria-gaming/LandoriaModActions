param([Parameter(Mandatory)][string]$Repository, [int]$TimeoutMinutes = 55)
$ErrorActionPreference = 'Stop'
if (-not $env:GH_TOKEN) { throw 'Configure MOD_REFERENCES_TOKEN with Actions: write on LandoriaModReferences only.' }
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid reference repository name.' }
# Current API returns the exact dispatched run, avoiding latest-run races.
$json = gh api --method POST -H 'X-GitHub-Api-Version: 2026-03-10' "repos/$Repository/actions/workflows/update-references.yml/dispatches" -f ref=main
if ($LASTEXITCODE -ne 0) { throw 'Reference dispatch failed; check Actions: write permission.' }
$runId = ($json | ConvertFrom-Json).workflow_run_id
if ("$runId" -notmatch '^\d+$') { throw 'Dispatch did not return a workflow run ID.' }
$deadline = [DateTime]::UtcNow.AddMinutes($TimeoutMinutes)
do {
    $json = gh api "repos/$Repository/actions/runs/$runId"
    if ($LASTEXITCODE -ne 0) { throw 'Reference run lookup failed.' }
    $run = $json | ConvertFrom-Json
    if ($run.head_branch -ne 'main' -or $run.event -ne 'workflow_dispatch') { throw 'Unexpected reference workflow source.' }
    if ($run.status -eq 'completed') {
        if ($run.conclusion -ne 'success') { throw "Reference update failed ($($run.conclusion)): $($run.html_url)" }
        $json = gh api "repos/$Repository/actions/runs/$runId/artifacts"
        if ($LASTEXITCODE -ne 0) { throw 'Reference artifact lookup failed.' }
        $bundles = @(($json | ConvertFrom-Json).artifacts | Where-Object { $_.name -eq 'mod-compilation-references' -and -not $_.expired })
        if ($bundles.Count -ne 1) { throw 'Successful reference update has no unique bundle.' }
        "run-id=$runId" >> $env:GITHUB_OUTPUT
        return
    }
    if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out waiting for references: $($run.html_url)" }
    Start-Sleep -Seconds 15
} while ($true)
