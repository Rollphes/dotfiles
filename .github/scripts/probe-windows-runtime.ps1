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
foreach ($pair in @(@('APPDATA', 'AppData\Roaming'), @('LOCALAPPDATA', 'AppData\Local'))) {
    $value = [Environment]::GetEnvironmentVariable($pair[0])
    if ((Native-Path $value) -ine (Join-Path $developmentHome $pair[1])) { throw "Unexpected $($pair[0]): $value" }
}
foreach ($name in 'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME',
    'MISE_CONFIG_DIR','MISE_DATA_DIR','MISE_STATE_DIR','MISE_CACHE_DIR','MISE_TMP_DIR',
    'AUBE_CACHE_DIR','AUBE_STORE_DIR','CARGO_HOME','RUSTUP_HOME') {
    Assert-Contained $name ([Environment]::GetEnvironmentVariable($name))
}
foreach ($name in 'TEMP','TMP') {
    if ((Native-Path ([Environment]::GetEnvironmentVariable($name))) -ine 'C:\msys64\tmp') { throw "$name escaped MSYS2 temp" }
}
if ([IO.Path]::GetTempPath().TrimEnd('\') -ine 'C:\msys64\tmp') { throw 'PowerShell native temp fallback escaped' }
Assert-Contained 'powershell.home' $PSHOME
Write-Output "powershell.version=$($PSVersionTable.PSVersion)"

$go = (Invoke-Probe go @('env','-json','GOPATH','GOCACHE','GOENV','GOMODCACHE','GOTMPDIR','GOROOT')) -join "`n" | ConvertFrom-Json
foreach ($name in 'GOPATH','GOCACHE','GOENV','GOMODCACHE','GOROOT') { Assert-Contained "go.$name" $go.$name }
if ($go.GOTMPDIR -and (Native-Path $go.GOTMPDIR) -ine 'C:\msys64\tmp') { throw 'Go GOTMPDIR escaped' }
Assert-Contained 'npm.cache' ((Invoke-Probe npm @('config','get','cache')) -join '').Trim()
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
foreach ($tool in 'chezmoi','mise','go','node','npm','pnpm','uv','cargo','rustup','rustc','git','gh','ghq','tree-sitter') {
    $arguments = if ($tool -eq 'go') { @('version') } else { @('--version') }
    Invoke-Probe $tool $arguments
}
Invoke-Probe gopls @('version')
$nvimPaths = ((Invoke-Probe nvim @('--headless','-u','NONE','-i','NONE','-n','-c','lua local p = {}; for _,k in ipairs({"config","data","state","cache"}) do p[k] = vim.fn.stdpath(k) end; io.stdout:write(vim.json.encode(p))','-c','qa')) -join '') | ConvertFrom-Json
foreach ($name in 'config','data','state','cache') { Assert-Contained "nvim.$name" $nvimPaths.$name }

# Minimal offline workloads exercise gopls's Go subprocess and parser compilation.
$fixture = Join-Path $env:TEMP ('containment-runtime-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
$savedGoProxy = $env:GOPROXY
$savedGoToolchain = $env:GOTOOLCHAIN
$savedGoWork = $env:GOWORK
Push-Location $fixture
try {
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
    'module.exports = grammar({name: "containment_probe", rules: {source_file: $ => repeat($.word), word: $ => /[a-z]+/}});' | Set-Content grammar.js
    '{"parser-directories": []}' | Set-Content parser-config.json
    'hello' | Set-Content example.txt
    Invoke-Probe tree-sitter @('generate','grammar.js')
    Invoke-Probe tree-sitter @('parse','--grammar-path','.', '--config-path','parser-config.json','example.txt')
    $parserLibrary = Join-Path $env:LOCALAPPDATA 'tree-sitter\lib\containment_probe.dll'
    if (-not (Test-Path -LiteralPath $parserLibrary -PathType Leaf)) { throw 'Tree-sitter parser cache is missing from canonical Local AppData' }
    Assert-Contained 'tree-sitter.parserCache' $parserLibrary
} finally {
    Pop-Location
    $env:GOPROXY = $savedGoProxy
    $env:GOTOOLCHAIN = $savedGoToolchain
    $env:GOWORK = $savedGoWork
}
Write-Output "Offline runtime fixture: $fixture"
# aube is embedded in mise: first apply's npm backend exercises it, no separate executable required.
Write-Output 'Native runtime resolver probes: PASS'
