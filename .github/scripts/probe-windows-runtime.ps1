# Run as a native child of the managed MSYS2 Fish environment, within the audit.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Native-Path([string] $Path) {
    if ($Path -match '^[A-Za-z]:[\\/]') { return [IO.Path]::GetFullPath($Path).TrimEnd('\') }
    $converted = & C:\msys64\usr\bin\cygpath.exe -w $Path
    if ($LASTEXITCODE) { throw "Path conversion failed: $Path" }
    return [IO.Path]::GetFullPath($converted).TrimEnd('\')
}
function Invoke-Probe([string] $Tool, [string[]] $Arguments) {
    $output = & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool probe failed ($LASTEXITCODE)" }
    return $output
}
$developmentHome = Native-Path $env:HOME
$hostProfileHint = [string]::Concat($env:HOMEDRIVE, $env:HOMEPATH)
if (
    $hostProfileHint -notmatch '^[A-Za-z]:[\\/]' -or
    (Native-Path $hostProfileHint) -ieq $developmentHome
) {
    throw "HOMEDRIVE/HOMEPATH do not identify the Windows host profile: $hostProfileHint"
}
Write-Output "windows.hostProfileHint=$hostProfileHint"
function Assert-Contained([string] $Name, [string] $Path) {
    if (-not $Path -or $Path -notmatch '^[A-Za-z]:[\\/]') { throw "$Name is not a native absolute path: $Path" }
    $full = Native-Path $Path
    if ($full -ine $developmentHome -and -not $full.StartsWith("$developmentHome\", [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name escaped canonical home: $full"
    }
    if ($full -match '[/\\]\.winprofile([/\\]|$)') { throw "$Name uses retired profile storage" }
    Write-Output "$Name=$full"
}
if ($env:USERPROFILE -notmatch '^[A-Za-z]:[\\/]' -or (Native-Path $env:USERPROFILE) -ine $developmentHome) {
    throw 'HOME and native USERPROFILE must identify the same development home'
}
foreach ($pair in @(
    @('APPDATA', '.config'),
    @('LOCALAPPDATA', '.local\share'),
    @('GOCACHE', '.cache\go-build'),
    @('NPM_CONFIG_CACHE', '.cache\npm')
)) {
    $value = [Environment]::GetEnvironmentVariable($pair[0])
    if ((Native-Path $value) -ine (Join-Path $developmentHome $pair[1])) { throw "Unexpected $($pair[0]): $value" }
}
if ([IO.Directory]::Exists((Join-Path $developmentHome 'AppData'))) {
    throw 'The canonical development home contains the retired AppData tree'
}

$nativeHome = $developmentHome.Replace('\', '/')
$credentialContract = @(
    "HOME='$nativeHome'",
    "USERPROFILE='$nativeHome'",
    "APPDATA='$nativeHome/.config'",
    "LOCALAPPDATA='$nativeHome/.local/share'",
    "TEMP='C:/msys64/tmp'",
    "TMP='C:/msys64/tmp'",
    "XDG_CONFIG_HOME='$nativeHome/.config'",
    "XDG_DATA_HOME='$nativeHome/.local/share'",
    "XDG_STATE_HOME='$nativeHome/.local/state'",
    "XDG_CACHE_HOME='$nativeHome/.cache'",
    "MISE_CONFIG_DIR='$nativeHome/.config/mise'",
    "MISE_DATA_DIR='$nativeHome/.local/share/mise'",
    "MISE_STATE_DIR='$nativeHome/.local/state/mise'",
    "MISE_CACHE_DIR='$nativeHome/.cache/mise'",
    "MISE_TMP_DIR='$nativeHome/.cache/mise/tmp'"
)
$gitCommand = 'C:\msys64\ucrt64\bin\git.exe'
if (-not (Test-Path -LiteralPath $gitCommand -PathType Leaf)) {
    throw "Managed MSYS2 Git is missing: $gitCommand"
}
$managedCredentialHelpers = @{}
foreach ($credentialHost in 'github.com','api.github.com','gist.github.com') {
    $helpers = @(& $gitCommand config --global --get-all "credential.https://$credentialHost.helper")
    if ($LASTEXITCODE -ne 0 -or $helpers.Count -lt 2 -or $helpers[0] -ne '') {
        throw "Managed credential helper reset is missing for $credentialHost"
    }
    $helper = $helpers[-1]
    foreach ($entry in $credentialContract) {
        if (-not $helper.Contains($entry, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Credential helper for $credentialHost lacks $entry"
        }
    }
    if ($helper -notmatch '/\.local/share/mise/shims/gh\.exe\b') {
        throw "Credential helper for $credentialHost does not use the managed gh shim"
    }
    $managedCredentialHelpers[$credentialHost] = $helper
}

# Exercise Git's helper selection and shell environment without consulting or
# returning any machine credential. Replacing only the final gh command keeps
# the managed helper's actual inline environment contract under test.
$credentialProbeRoot = Join-Path $env:TEMP (
    "credential-helper-probe-{0}" -f [Guid]::NewGuid().ToString('N')
)
$credentialProbeScript = Join-Path $credentialProbeRoot 'capture.sh'
$credentialProbeConfig = Join-Path $credentialProbeRoot 'gitconfig'
$credentialProbeCapture = Join-Path $credentialProbeRoot 'environment.txt'
New-Item -ItemType Directory -Path $credentialProbeRoot | Out-Null
try {
    @'
#!/bin/sh
printf '%s\n' \
    "$HOME" "$USERPROFILE" "$APPDATA" "$LOCALAPPDATA" "$TEMP" "$TMP" \
    "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" \
    "$MISE_CONFIG_DIR" "$MISE_DATA_DIR" "$MISE_STATE_DIR" \
    "$MISE_CACHE_DIR" "$MISE_TMP_DIR" > "$CAPTURE_PATH"
printf 'username=containment-probe\npassword=containment-probe\n'
'@ | Set-Content -LiteralPath $credentialProbeScript -Encoding utf8NoBOM
    $credentialProbeScriptPosix = (& C:\msys64\usr\bin\cygpath.exe -u $credentialProbeScript).Trim()
    $credentialProbeCapturePosix = (& C:\msys64\usr\bin\cygpath.exe -u $credentialProbeCapture).Trim()
    $expectedCredentialEnvironment = @(
        $nativeHome, $nativeHome, "$nativeHome/.config", "$nativeHome/.local/share",
        'C:/msys64/tmp', 'C:/msys64/tmp', "$nativeHome/.config",
        "$nativeHome/.local/share", "$nativeHome/.local/state", "$nativeHome/.cache",
        "$nativeHome/.config/mise", "$nativeHome/.local/share/mise",
        "$nativeHome/.local/state/mise", "$nativeHome/.cache/mise",
        "$nativeHome/.cache/mise/tmp"
    )
    foreach ($credentialHost in 'github.com','api.github.com') {
        $helper = $managedCredentialHelpers[$credentialHost]
        $probeHelper = $helper -replace "'[^']+/\.local/share/mise/shims/gh\.exe' auth git-credential$", "'C:/msys64/usr/bin/sh.exe' '$credentialProbeScriptPosix'"
        if ($probeHelper -eq $helper) {
            throw "Unable to instrument credential helper for $credentialHost"
        }
        if (Test-Path -LiteralPath $credentialProbeConfig) {
            Remove-Item -LiteralPath $credentialProbeConfig -Force
        }
        & $gitCommand config --file $credentialProbeConfig --add "credential.https://$credentialHost.helper" ''
        & $gitCommand config --file $credentialProbeConfig --add "credential.https://$credentialHost.helper" $probeHelper
        if ($LASTEXITCODE -ne 0) { throw "Unable to create credential probe for $credentialHost" }
        "protocol=https`nhost=$credentialHost`n" | & C:\msys64\usr\bin\env.exe `
            'HOME=C:/forbidden-host-fixture' `
            'USERPROFILE=C:/forbidden-host-fixture' `
            'APPDATA=C:/forbidden-host-fixture/AppData/Roaming' `
            'LOCALAPPDATA=C:/forbidden-host-fixture/AppData/Local' `
            'TEMP=C:/forbidden-host-fixture/Temp' `
            'TMP=C:/forbidden-host-fixture/Temp' `
            "CAPTURE_PATH=$credentialProbeCapturePosix" `
            "GIT_CONFIG_GLOBAL=$credentialProbeConfig" `
            'GIT_CONFIG_NOSYSTEM=1' `
            $gitCommand -C $credentialProbeRoot -c credential.interactive=false credential fill | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Credential environment probe failed for $credentialHost" }
        $actualCredentialEnvironment = @(Get-Content -LiteralPath $credentialProbeCapture)
        if (($actualCredentialEnvironment -join "`n") -cne ($expectedCredentialEnvironment -join "`n")) {
            throw "Credential helper environment escaped containment for $credentialHost"
        }
    }
} finally {
    foreach ($path in $credentialProbeCapture,$credentialProbeConfig,$credentialProbeScript) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    if (Test-Path -LiteralPath $credentialProbeRoot) {
        Remove-Item -LiteralPath $credentialProbeRoot -Force
    }
}
foreach ($name in 'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME',
    'MISE_CONFIG_DIR','MISE_DATA_DIR','MISE_STATE_DIR','MISE_CACHE_DIR','MISE_TMP_DIR',
    'AUBE_CACHE_DIR','AUBE_STORE_DIR','CARGO_HOME','RUSTUP_HOME','STARSHIP_CONFIG','STARSHIP_CACHE') {
    Assert-Contained $name ([Environment]::GetEnvironmentVariable($name))
}
foreach ($name in 'TEMP','TMP') {
    if ((Native-Path ([Environment]::GetEnvironmentVariable($name))) -ine 'C:\msys64\tmp') { throw "$name escaped MSYS2 temp" }
}
if ([IO.Path]::GetTempPath().TrimEnd('\') -ine 'C:\msys64\tmp') { throw 'PowerShell native temp fallback escaped' }
Write-Output "powershell.executableHome=$PSHOME"
Write-Output "powershell.version=$($PSVersionTable.PSVersion)"

$ciToolset = $env:GITHUB_ACTIONS -eq 'true'
if ($ciToolset) {
    $miseConfigPath = Join-Path $env:MISE_CONFIG_DIR 'config.toml'
    $miseConfig = Get-Content -LiteralPath $miseConfigPath -Raw
    if ($miseConfig -match '(?m)^\s*go\s*=' -or $miseConfig -match '(?m)^\s*"go:[^"]+"\s*=') {
        throw 'Go or go backend tools must be excluded from the CI mise config'
    }
    if ($miseConfig -notmatch '(?ms)^\[settings\.aqua\]\s+github_attestations\s*=\s*false\b') {
        throw 'Windows CI mise config must disable aqua GitHub attestations'
    }
    Write-Output 'go/gopls=SKIP (excluded from CI toolset)'
} else {
    $go = (Invoke-Probe go @('env','-json','GOPATH','GOCACHE','GOENV','GOMODCACHE','GOTMPDIR','GOROOT')) -join "`n" | ConvertFrom-Json
    $expectedGo = @{
        GOPATH = Join-Path $developmentHome 'go'
        GOCACHE = Join-Path $developmentHome '.cache\go-build'
        GOENV = Join-Path $developmentHome '.config\go\env'
        GOMODCACHE = Join-Path $developmentHome 'go\pkg\mod'
    }
    foreach ($name in $expectedGo.Keys) {
        if ((Native-Path $go.$name) -ine $expectedGo[$name]) { throw "Unexpected go.$($name): $($go.$name)" }
        Write-Output "go.$name=$($go.$name)"
    }
    Assert-Contained 'go.GOROOT' $go.GOROOT
    if ($go.GOTMPDIR -and (Native-Path $go.GOTMPDIR) -ine 'C:\msys64\tmp') { throw 'Go GOTMPDIR escaped' }
}
$npmCache = ((Invoke-Probe npm @('config','get','cache')) -join '').Trim()
if ((Native-Path $npmCache) -ine (Native-Path $env:NPM_CONFIG_CACHE)) { throw "Unexpected npm cache: $npmCache" }
Write-Output "npm.cache=$npmCache"
$pnpmStore = ((Invoke-Probe pnpm @('store','path')) -join '').Trim()
# pnpm may use a project-local store; the current workspace is an allowed target.
$workspace = (Get-Location).Path.TrimEnd('\')
if ((Native-Path $pnpmStore).StartsWith("$workspace\", [StringComparison]::OrdinalIgnoreCase)) {
    Write-Output "pnpm.workspaceStore=$pnpmStore"
} else { Assert-Contained 'pnpm.store' $pnpmStore }
Assert-Contained 'uv.cache' ((Invoke-Probe uv @('cache','dir')) -join '').Trim()
Assert-Contained 'ghq.root' ((Invoke-Probe ghq @('root')) -join '').Trim()
$node = ((Invoke-Probe node @('-e','console.log(JSON.stringify({home:require("os").homedir(),tmp:require("os").tmpdir()}))')) -join '') | ConvertFrom-Json
Assert-Contained 'node.home' $node.home
if ((Native-Path $node.tmp) -ine 'C:\msys64\tmp') { throw 'Node temp escaped' }
$python = ((Invoke-Probe python @('-B','-c','import json,os,tempfile; print(json.dumps(dict(home=os.path.expanduser("~"),tmp=tempfile.gettempdir())))')) -join '') | ConvertFrom-Json
Assert-Contained 'python.home' $python.home
if ((Native-Path $python.tmp) -ine 'C:\msys64\tmp') { throw 'Python temp escaped' }
# These exercise installed executables without downloads, credentials, or user init.
$versionTools = @('chezmoi','mise','node','npm','pnpm','uv','cargo','rustup','rustc','git','gh','ghq','tree-sitter')
if (-not $ciToolset) { $versionTools += 'go' }
foreach ($tool in $versionTools) {
    $arguments = if ($tool -eq 'go') { @('version') } else { @('--version') }
    Invoke-Probe $tool $arguments
}
if (-not $ciToolset) { Invoke-Probe gopls @('version') }
$nvimPaths = ((Invoke-Probe nvim @('--headless','-u','NONE','-i','NONE','-n','-c','lua local p = {}; for _,k in ipairs({"config","data","state","cache"}) do p[k] = vim.fn.stdpath(k) end; io.stdout:write(vim.json.encode(p))','-c','qa')) -join '') | ConvertFrom-Json
foreach ($name in 'config','data','state','cache') { Assert-Contained "nvim.$name" $nvimPaths.$name }

# Minimal offline workloads exercise parser compilation and, outside CI, gopls's
# Go subprocess. Go/gopls are intentionally omitted from the CI toolset.
$fixture = Join-Path $env:TEMP ('containment-runtime-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
$savedGoProxy = $env:GOPROXY
$savedGoToolchain = $env:GOTOOLCHAIN
$savedGoWork = $env:GOWORK
Push-Location $fixture
try {
    if (-not $ciToolset) {
        $env:GOPROXY = 'off'
        $env:GOTOOLCHAIN = 'local'
        $env:GOWORK = 'off'
        "module containment.invalid/probe`n`ngo 1.20`n" | Set-Content go.mod
        'package probe; func Answer() int { return 42 }' | Set-Content probe.go
        Invoke-Probe go @('list','.')
        $goplsCheck = @(& gopls check probe.go 2>&1)
        if ($LASTEXITCODE -ne 0 -or ($goplsCheck -join "`n") -match 'Error:|initial workspace load failed') {
            throw "gopls Go runtime probe failed: $($goplsCheck -join "`n")"
        }
        $goplsCheck
    }
    'module.exports = grammar({name: "containment_probe", rules: {source_file: $ => repeat($.word), word: $ => /[a-z]+/}});' | Set-Content grammar.js
    '{"parser-directories": []}' | Set-Content parser-config.json
    'hello' | Set-Content example.txt
    Invoke-Probe tree-sitter @('generate','grammar.js')
    Invoke-Probe tree-sitter @('parse','--grammar-path','.', '--config-path','parser-config.json','example.txt')
    $parserLibrary = Join-Path $env:LOCALAPPDATA 'tree-sitter\lib\containment_probe.dll'
    if (-not (Test-Path -LiteralPath $parserLibrary -PathType Leaf)) { throw 'Tree-sitter parser data is missing from canonical XDG data' }
    Assert-Contained 'tree-sitter.parserData' $parserLibrary
} finally {
    Pop-Location
    $env:GOPROXY = $savedGoProxy
    $env:GOTOOLCHAIN = $savedGoToolchain
    $env:GOWORK = $savedGoWork
}
Write-Output "Offline runtime fixture: $fixture"
# aube is embedded in mise: first apply's npm backend exercises it, no separate executable required.
Write-Output 'Native runtime resolver probes: PASS'
