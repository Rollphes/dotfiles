param([Parameter(Mandatory)][string] $AuditScript)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Synthetic roots only. No host profile, user data, SSH fixture, or symlink access.
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('containment-test-' + [Guid]::NewGuid().ToString('N'))
$canonical = Join-Path $fixture 'development'
$hostRoot = Join-Path $fixture 'host'
$hostTemp = Join-Path $fixture 'host-temp'
$fixtureWorkspace = Join-Path $hostRoot 'project'
New-Item -ItemType Directory -Path $canonical,$hostRoot,$hostTemp | Out-Null
function Run-Case([string] $Name, [scriptblock] $Mutation, [bool] $ShouldFail) {
    $state = Join-Path $canonical $Name
    & $AuditScript start -CanonicalHome $canonical -HostProfile $hostRoot -HostTemp $hostTemp -WorkspaceRoots $fixtureWorkspace -StateRoot $state -HashFiles
    & $Mutation
    $failed = $false
    try { & $AuditScript stop -CanonicalHome $canonical -StateRoot $state } catch { $failed = $true }
    if ($failed -ne $ShouldFail) { throw "Unexpected audit decision: $Name" }
    $verificationFailed = $false
    try { & "$PSScriptRoot/verify-windows-containment.ps1" -StateRoot $state } catch { $verificationFailed = $true }
    if ($verificationFailed -ne $ShouldFail) { throw "Unexpected CI decision: $Name" }
    $active = Get-Content (Join-Path $state 'active.json') -Raw | ConvertFrom-Json
    $policy = Get-Content (Join-Path $active.sessionDirectory 'policy.json') -Raw | ConvertFrom-Json
    if (($policy.decision -eq 'fail') -ne $ShouldFail) { throw "Unexpected policy: $Name" }
    Write-Output "PASS: $Name"
}
$nested = Join-Path $hostRoot 'arbitrary-tool\nested'
New-Item -ItemType Directory -Path $nested -Force | Out-Null
$file = Join-Path $nested 'state'
Set-Content $file 'aaaa' -NoNewline
Run-Case 'unchanged' {} $false
Run-Case 'same-size-content' { $time=(Get-Item $file).LastWriteTimeUtc; Set-Content $file 'bbbb' -NoNewline; (Get-Item $file).LastWriteTimeUtc=$time } $true
Run-Case 'metadata' { (Get-Item $file).LastWriteTimeUtc=[DateTime]::UtcNow.AddMinutes(1) } $true
Run-Case 'new-unknown-tool' { New-Item -ItemType Directory (Join-Path $hostRoot 'another-tool') | Out-Null } $true
Run-Case 'host-temp' { Set-Content (Join-Path $hostTemp 'arbitrary-state') 'x' } $true
Run-Case 'host-roaming' { $dir=Join-Path $hostRoot 'AppData\Roaming\unknown-tool'; New-Item -ItemType Directory $dir -Force | Out-Null; Set-Content (Join-Path $dir 'state') 'x' } $true
Run-Case 'host-locallow' { $dir=Join-Path $hostRoot 'AppData\LocalLow\unknown-tool'; New-Item -ItemType Directory $dir -Force | Out-Null; Set-Content (Join-Path $dir 'state') 'x' } $true
Run-Case 'canonical-write' { Set-Content (Join-Path $canonical 'allowed-state') 'x' } $false
Run-Case 'explicit-workspace' { New-Item -ItemType Directory $fixtureWorkspace -Force | Out-Null; Set-Content (Join-Path $fixtureWorkspace 'source') 'x' } $false
Run-Case 'workspace-sibling' { New-Item -ItemType Directory (Join-Path $hostRoot 'project-other') | Out-Null } $true
$fontDir = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\Fonts'
Run-Case 'managed-font' { New-Item -ItemType Directory $fontDir -Force | Out-Null; Set-Content (Join-Path $fontDir '0xProtoNerdFont-Regular.ttf') 'fixture' } $false
Run-Case 'unmanaged-font-neighbor' { Set-Content (Join-Path $fontDir 'unknown-tool.state') 'fixture' } $true
$bridge = Join-Path $hostRoot '.config\wezterm'
Run-Case 'managed-bridge-exclusion' { New-Item -ItemType Directory $bridge -Force | Out-Null; Set-Content (Join-Path $bridge 'fixture') 'fixture' } $false
Run-Case 'bridge-sibling' { Set-Content (Join-Path $hostRoot '.config\unmanaged.state') 'fixture' } $true
# Directory timestamp changes caused by removal remain writes under strict policy;
# preserve it here to test the deleted-only semantics specifically.
Run-Case 'deleted-only' { $time=(Get-Item $nested).LastWriteTimeUtc; Remove-Item -LiteralPath $file; (Get-Item $nested).LastWriteTimeUtc=$time } $false
try {
    & $AuditScript start -CanonicalHome $canonical -HostProfile $hostRoot -HostTemp $hostTemp -WorkspaceRoots $hostRoot -StateRoot (Join-Path $canonical 'invalid-workspace')
    throw 'Broad workspace exclusion was accepted'
} catch {
    if ($_.Exception.Message -notmatch 'must not hide an entire monitored root') { throw }
}
Write-Output 'PASS: broad workspace exclusion rejected'
try {
    [AuditSnapshotWriter]::WriteRecursive((Join-Path $fixture '.ssh'), (Join-Path $fixture 'excluded.csv'), $true, @())
    throw 'SSH root guard failed'
} catch {
    if ($_.Exception.ToString() -notmatch 'Snapshot root is excluded') { throw }
}
Write-Output "PASS: SSH lexical guard (no existence check); fixtures retained at $fixture"
