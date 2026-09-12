param(
    [string] $DevelopmentHome = $env:DOTFILES_CI_DEVELOPMENT_HOME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $DevelopmentHome -or $DevelopmentHome -notmatch '^[A-Za-z]:[\\/]') {
    throw "Invalid Windows development home: $DevelopmentHome"
}

$developmentHomePath = [IO.Path]::GetFullPath($DevelopmentHome).TrimEnd('\\')
$xdgConfigHome = Join-Path $developmentHomePath '.config'
$xdgDataHome = Join-Path $developmentHomePath '.local\share'
$xdgStateHome = Join-Path $developmentHomePath '.local\state'
$xdgCacheHome = Join-Path $developmentHomePath '.cache'

$env:HOME = $developmentHomePath
$env:USERPROFILE = $developmentHomePath
$env:APPDATA = $xdgConfigHome
$env:LOCALAPPDATA = $xdgDataHome
$env:XDG_CONFIG_HOME = $xdgConfigHome
$env:XDG_DATA_HOME = $xdgDataHome
$env:XDG_STATE_HOME = $xdgStateHome
$env:XDG_CACHE_HOME = $xdgCacheHome
$env:TEMP = 'C:\msys64\tmp'
$env:TMP = $env:TEMP
$env:CARGO_HOME = Join-Path $developmentHomePath '.cargo'
$env:RUSTUP_HOME = Join-Path $developmentHomePath '.rustup'
$env:GHQ_ROOT = Join-Path $developmentHomePath 'ghq'
$env:GOCACHE = Join-Path $xdgCacheHome 'go-build'
$env:NPM_CONFIG_CACHE = Join-Path $xdgCacheHome 'npm'
$env:PNPM_CONFIG_STORE_DIR = Join-Path $xdgDataHome 'pnpm\store'
$env:MISE_CONFIG_DIR = Join-Path $xdgConfigHome 'mise'
$env:MISE_DATA_DIR = Join-Path $xdgDataHome 'mise'
$env:MISE_STATE_DIR = Join-Path $xdgStateHome 'mise'
$env:MISE_CACHE_DIR = Join-Path $xdgCacheHome 'mise'
$env:MISE_TMP_DIR = Join-Path $xdgCacheHome 'mise\tmp'
$env:AUBE_CACHE_DIR = Join-Path $xdgCacheHome 'aube'
$env:AUBE_STORE_DIR = Join-Path $xdgDataHome 'aube\store'
$env:UV_CACHE_DIR = Join-Path $xdgCacheHome 'uv'
$env:UV_TOOL_DIR = Join-Path $xdgDataHome 'uv\tools'
$env:UV_PYTHON_INSTALL_DIR = Join-Path $xdgDataHome 'uv\python'
$env:_ZO_DATA_DIR = Join-Path $xdgDataHome 'zoxide'
$env:STARSHIP_CONFIG = Join-Path $xdgConfigHome 'starship.toml'
$env:STARSHIP_CACHE = Join-Path $xdgCacheHome 'starship'
$env:MSYSTEM = 'UCRT64'
$env:PATH = @(
    (Join-Path $developmentHomePath '.local\bin'),
    (Join-Path $xdgDataHome 'mise\shims'),
    (Join-Path $env:CARGO_HOME 'bin'),
    $env:PATH
) -join ';'
