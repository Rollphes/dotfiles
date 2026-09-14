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
    $report = @(Get-Content (Join-Path $active.sessionDirectory 'report.txt'))
    if ($report -notcontains 'POLICY VIOLATIONS:') { throw "Missing policy violation section: $Name" }
    foreach ($violation in @($policy.violations)) {
        $expected = "  $($violation.status.ToUpperInvariant()) [$($violation.root)]: $($violation.path)"
        if ($report -notcontains $expected) { throw "Missing policy violation entry: $Name ($expected)" }
    }
    if (-not $ShouldFail -and $report -notcontains '  None') { throw "Missing empty policy result: $Name" }
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
$startupCache = Join-Path $hostRoot 'AppData\Local\Microsoft\PowerShell\StartupProfileData-NonInteractive'
Run-Case 'managed-host-powershell-startup-cache' { New-Item -ItemType Directory (Split-Path $startupCache) -Force | Out-Null; Set-Content $startupCache 'x' } $false
Run-Case 'host-powershell-cache-sibling' { Set-Content (Join-Path (Split-Path $startupCache) 'unknown.state') 'x' } $true
$windowsStartupCache = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\PowerShell\StartupProfileData-NonInteractive'
Run-Case 'windows-powershell-startup-cache' { New-Item -ItemType Directory (Split-Path $windowsStartupCache) -Force | Out-Null; Set-Content $windowsStartupCache 'x' } $false
Run-Case 'windows-powershell-cache-sibling' { Set-Content (Join-Path (Split-Path $windowsStartupCache) 'unknown.state') 'x' } $true
$usrClassLog = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\UsrClass.dat.LOG1'
Run-Case 'host-registry-log' { New-Item -ItemType Directory (Split-Path $usrClassLog) -Force | Out-Null; Set-Content $usrClassLog 'x' } $false
Run-Case 'host-registry-log2' { Set-Content (Join-Path (Split-Path $usrClassLog) 'UsrClass.dat.LOG2') 'x' } $false
Run-Case 'host-registry-log-sibling' { Set-Content (Join-Path (Split-Path $usrClassLog) 'unknown.LOG1') 'x' } $true
Run-Case 'canonical-write' { Set-Content (Join-Path $canonical 'allowed-state') 'x' } $false
Run-Case 'canonical-appdata-container' { New-Item -ItemType Directory (Join-Path $canonical 'AppData') | Out-Null } $false
Run-Case 'canonical-appdata-unknown' { Set-Content (Join-Path $canonical 'AppData\unknown.state') 'x' } $true
$savedGithubActions = $env:GITHUB_ACTIONS
$savedRunnerEnvironment = $env:RUNNER_ENVIRONMENT
try {
    $webCache = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\WebCache'
    $env:GITHUB_ACTIONS = 'true'
    $env:RUNNER_ENVIRONMENT = 'self-hosted'
    Run-Case 'runner-exclusion-disabled' { New-Item -ItemType Directory $webCache -Force | Out-Null; Set-Content (Join-Path $webCache 'state-1') 'x' } $true
    $notifications = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\Notifications'
    New-Item -ItemType Directory $notifications -Force | Out-Null
    $notificationJournal = Join-Path $notifications 'wpndatabase.db-wal'
    Run-Case 'runner-state-rule-disabled' { Set-Content $notificationJournal 'self-hosted' } $true

    $env:RUNNER_ENVIRONMENT = 'github-hosted'
    Run-Case 'runner-webcache' { Set-Content (Join-Path $webCache 'state-2') 'x' } $false
    $inetCache = Join-Path $hostRoot 'AppData\Local\Microsoft\Windows\INetCache\IE'
    Run-Case 'runner-inetcache' { New-Item -ItemType Directory $inetCache -Force | Out-Null; Set-Content (Join-Path $inetCache 'container.dat') 'x' } $false
    Run-Case 'runner-inetcache-sibling' { Set-Content (Join-Path (Split-Path $inetCache) 'unknown.state') 'x' } $true
    $tokenBroker = Join-Path $hostRoot 'AppData\Local\Microsoft\TokenBroker\Cache'
    Run-Case 'runner-token-broker' { New-Item -ItemType Directory $tokenBroker -Force | Out-Null; Set-Content (Join-Path $tokenBroker 'fixture.tbres') 'x' } $false
    Run-Case 'runner-token-broker-sibling' { Set-Content (Join-Path (Split-Path $tokenBroker) 'unknown.state') 'x' } $true
    $localFirefox = Join-Path $hostRoot 'AppData\Local\Mozilla\Firefox'
    Run-Case 'runner-local-firefox' { New-Item -ItemType Directory $localFirefox -Force | Out-Null; Set-Content (Join-Path $localFirefox 'fixture') 'x' } $false
    Run-Case 'runner-local-firefox-sibling' { Set-Content (Join-Path (Split-Path $localFirefox) 'unknown.state') 'x' } $true
    $roamingFirefox = Join-Path $hostRoot 'AppData\Roaming\Mozilla\Firefox'
    Run-Case 'runner-roaming-firefox' { New-Item -ItemType Directory $roamingFirefox -Force | Out-Null; Set-Content (Join-Path $roamingFirefox 'fixture') 'x' } $false
    Run-Case 'runner-roaming-firefox-sibling' { Set-Content (Join-Path (Split-Path $roamingFirefox) 'unknown.state') 'x' } $true
    $cryptnet = Join-Path $hostRoot 'AppData\LocalLow\Microsoft\CryptnetUrlCache\Content'
    Run-Case 'runner-cryptnet-cache' { New-Item -ItemType Directory $cryptnet -Force | Out-Null; Set-Content (Join-Path $cryptnet 'state') 'x' } $false
    $canonicalWindows = Join-Path $canonical 'AppData\Local\Microsoft\Windows'
    Run-Case 'runner-canonical-history' { New-Item -ItemType Directory (Join-Path $canonicalWindows 'History') -Force | Out-Null } $false
    Run-Case 'runner-canonical-inetcache' { New-Item -ItemType Directory (Join-Path $canonicalWindows 'INetCache\IE') -Force | Out-Null; Set-Content (Join-Path $canonicalWindows 'INetCache\IE\container.dat') 'x' } $false
    Run-Case 'runner-canonical-inetcookies' { New-Item -ItemType Directory (Join-Path $canonicalWindows 'INetCookies') -Force | Out-Null } $false
    Run-Case 'runner-canonical-feeds-cache' { New-Item -ItemType Directory (Join-Path $canonical 'AppData\Local\Microsoft\Feeds Cache') -Force | Out-Null } $false
    Run-Case 'runner-canonical-windows-sibling' { Set-Content (Join-Path $canonicalWindows 'unknown.state') 'x' } $true
    $canonicalRoaming = Join-Path $canonical 'AppData\Roaming'
    Run-Case 'runner-canonical-roaming-entry' { New-Item -ItemType Directory $canonicalRoaming | Out-Null } $false
    Run-Case 'runner-canonical-roaming-child' { Set-Content (Join-Path $canonicalRoaming 'unknown.state') 'x' } $true
    Run-Case 'runner-exclusion-sibling' { Set-Content (Join-Path $hostRoot 'AppData\LocalLow\Microsoft\unknown.state') 'x' } $true
    Run-Case 'runner-notification-journal' { Set-Content $notificationJournal 'github-hosted' } $false
    Run-Case 'runner-notification-sibling' { Set-Content (Join-Path $notifications 'unknown.db-wal') 'x' } $true

    $packages = Join-Path $hostRoot 'AppData\Local\Packages'
    New-Item -ItemType Directory $packages -Force | Out-Null
    $securitySettings = Join-Path $packages 'Microsoft.SecHealthUI_8wekyb3d8bbwe\Settings'
    Run-Case 'runner-security-package-state' { New-Item -ItemType Directory $securitySettings -Force | Out-Null; Set-Content (Join-Path $securitySettings 'settings.dat') 'x' } $false
    Run-Case 'runner-security-package-sibling' { Set-Content (Join-Path $securitySettings 'unknown.state') 'x' } $true
    Run-Case 'runner-package-sibling' { New-Item -ItemType Directory (Join-Path $packages 'Contoso.Tool_1234567890abc\LocalState') -Force | Out-Null } $true
    $vclibsCache = Join-Path $packages 'Microsoft.VCLibs.140.00_8wekyb3d8bbwe\AC\INetCache'
    Run-Case 'runner-vclibs-package-state' { New-Item -ItemType Directory $vclibsCache -Force | Out-Null } $false
    Run-Case 'runner-vclibs-sibling' { New-Item -ItemType Directory (Join-Path $packages 'Microsoft.VCLibs.140.00_8wekyb3d8bbwe\LocalState') -Force | Out-Null } $true

    $startMenuState = Join-Path $packages 'Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState'
    New-Item -ItemType Directory $startMenuState -Force | Out-Null
    $startMenuCache = Join-Path $startMenuState 'StartUnifiedTileModelCache.dat'
    Set-Content $startMenuCache 'before'
    Run-Case 'runner-start-menu-cache' { Set-Content $startMenuCache 'after' } $false
    Run-Case 'runner-start-menu-sibling' { Set-Content (Join-Path $startMenuState 'unknown.dat') 'x' } $true

    $searchState = Join-Path $packages 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy\TempState'
    New-Item -ItemType Directory $searchState -Force | Out-Null
    $searchCache = Join-Path $searchState 'SearchUnifiedTileModelCache.dat'
    Set-Content $searchCache 'before'
    Run-Case 'runner-search-cache' { Set-Content $searchCache 'after' } $false
    Run-Case 'runner-search-sibling' { Set-Content (Join-Path $searchState 'unknown.dat') 'x' } $true
} finally {
    if ($null -eq $savedGithubActions) { Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue } else { $env:GITHUB_ACTIONS = $savedGithubActions }
    if ($null -eq $savedRunnerEnvironment) { Remove-Item Env:RUNNER_ENVIRONMENT -ErrorAction SilentlyContinue } else { $env:RUNNER_ENVIRONMENT = $savedRunnerEnvironment }
}
$canonicalCacheSymlink = Join-Path $canonical 'AppData\Local\Microsoft\PowerShell\StartupProfileData-NonInteractive'
Run-Case 'canonical-cache-symlink-endpoint' { New-Item -ItemType Directory (Split-Path $canonicalCacheSymlink) -Force | Out-Null; Set-Content $canonicalCacheSymlink 'x' } $false
$canonicalTelemetrySymlink = Join-Path $canonical 'AppData\Local\Microsoft\PowerShell\telemetry.uuid'
Run-Case 'canonical-telemetry-symlink-endpoint' { Set-Content $canonicalTelemetrySymlink 'x' } $false
Run-Case 'canonical-symlink-sibling' { Set-Content (Join-Path (Split-Path $canonicalCacheSymlink) 'unknown.state') 'x' } $true
$hostTelemetryTarget = Join-Path $hostRoot 'AppData\Local\Microsoft\PowerShell\telemetry.uuid'
Run-Case 'host-telemetry-target-endpoint' { Set-Content $hostTelemetryTarget 'x' } $false
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
Write-Output "PASS: containment audit policy; fixtures retained at $fixture"
