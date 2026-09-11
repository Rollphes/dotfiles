param([Parameter(Mandatory)][string] $StateRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$active = Get-Content -LiteralPath (Join-Path $StateRoot 'active.json') -Raw | ConvertFrom-Json
if ($active.status -ne 'stopped') { throw 'Containment audit did not finish.' }
$metadata = Get-Content -LiteralPath (Join-Path $active.sessionDirectory 'metadata.json') -Raw | ConvertFrom-Json
if ($metadata.schemaVersion -ne 4 -or $metadata.status -ne 'stopped') { throw 'Incomplete or obsolete audit.' }
$policy = Get-Content -LiteralPath (Join-Path $active.sessionDirectory 'policy.json') -Raw | ConvertFrom-Json
if ($policy.schemaVersion -ne 1 -or $policy.decision -ne 'pass' -or @($policy.violations).Count) {
    throw "Windows containment failed: $($active.sessionDirectory)\policy.json"
}
Write-Output 'Windows containment policy: PASS (monitored roots only)'
