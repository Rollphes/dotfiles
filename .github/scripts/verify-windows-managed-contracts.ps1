$env:PATH = @(
    "$env:HOME\.local\bin",
    "$env:HOME\.local\share\mise\shims",
    "$env:CARGO_HOME\bin",
    $env:PATH
) -join ';'

$targetPath = [IO.Path]::GetFullPath(
    (chezmoi --source $env:GITHUB_WORKSPACE target-path)
)
if ($targetPath -ne [IO.Path]::GetFullPath($env:HOME)) {
    throw "Unexpected chezmoi destination: $targetPath"
}

git lfs version
mise --version
rustup show active-toolchain
& C:\msys64\usr\bin\env.exe `
    "HOME=$env:DOTFILES_CI_HOST_PROFILE" `
    "USERPROFILE=$env:DOTFILES_CI_HOST_PROFILE" `
    "APPDATA=$env:DOTFILES_CI_HOST_APPDATA" `
    "LOCALAPPDATA=$env:DOTFILES_CI_HOST_LOCALAPPDATA" `
    pwsh.exe `
        -NoProfile `
        -File .github/scripts/verify-fonts.ps1 `
        -DevelopmentHome $env:HOME
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$rustupCommand = Get-Command rustup -CommandType Application |
    Select-Object -First 1
$expectedRustup = [IO.Path]::GetFullPath("$env:CARGO_HOME\bin\rustup.exe")
if ([IO.Path]::GetFullPath($rustupCommand.Source) -ne $expectedRustup) {
    throw "Unexpected rustup executable: $($rustupCommand.Source)"
}

$rustupHome = rustup show home
if (
    [IO.Path]::GetFullPath($rustupHome) -ne
    [IO.Path]::GetFullPath($env:RUSTUP_HOME)
) {
    throw "Rust escaped the MSYS2 home: $rustupHome"
}

$fishConfigHome = (
    & 'C:\msys64\usr\bin\cygpath.exe' -u $env:XDG_CONFIG_HOME
).Trim()
$fishEnvironment = @(
    & 'C:\msys64\usr\bin\env.exe' `
        'PATH=' `
        "XDG_CONFIG_HOME=$fishConfigHome" `
        'C:\msys64\usr\bin\fish.exe' `
        -c @'
printf '%s\n' \
    "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" \
    "$APPDATA" "$LOCALAPPDATA" "$TEMP" "$TMP" "$GHQ_ROOT" "$GOCACHE" \
    "$NPM_CONFIG_CACHE" "$MISE_CONFIG_DIR" "$MISE_DATA_DIR" \
    "$MISE_STATE_DIR" "$MISE_CACHE_DIR" "$MISE_TMP_DIR" \
    "$AUBE_CACHE_DIR" "$AUBE_STORE_DIR" "$UV_CACHE_DIR" "$UV_TOOL_DIR" \
    "$UV_PYTHON_INSTALL_DIR" "$_ZO_DATA_DIR" "$STARSHIP_CONFIG" \
    "$STARSHIP_CACHE" "$HOME" "$USERPROFILE"
command -s cygpath
'@
)
$emptyEnvironment = @(
    $fishEnvironment | Where-Object { [string]::IsNullOrWhiteSpace($_) }
)
if ($fishEnvironment.Count -ne 27 -or $emptyEnvironment.Count -ne 0) {
    throw "Unexpected Fish environment output: $($fishEnvironment.Count) values"
}
$expectedEnvironment = @(
    "$env:HOME\.config",
    "$env:HOME\.local\share",
    "$env:HOME\.local\state",
    "$env:HOME\.cache",
    "$env:HOME\.config",
    "$env:HOME\.local\share",
    'C:\msys64\tmp',
    'C:\msys64\tmp',
    "$env:HOME\ghq",
    "$env:HOME\.cache\go-build",
    "$env:HOME\.cache\npm",
    "$env:HOME\.config\mise",
    "$env:HOME\.local\share\mise",
    "$env:HOME\.local\state\mise",
    "$env:HOME\.cache\mise",
    "$env:HOME\.cache\mise\tmp",
    "$env:HOME\.cache\aube",
    "$env:HOME\.local\share\aube\store",
    "$env:HOME\.cache\uv",
    "$env:HOME\.local\share\uv\tools",
    "$env:HOME\.local\share\uv\python",
    "$env:HOME\.local\share\zoxide",
    "$env:HOME\.config\starship.toml",
    "$env:HOME\.cache\starship",
    $env:HOME,
    $env:HOME,
    'C:\msys64\usr\bin\cygpath.exe'
) | ForEach-Object { [IO.Path]::GetFullPath($_) }
$actualEnvironment = $fishEnvironment | ForEach-Object {
    [IO.Path]::GetFullPath(
        (& 'C:\msys64\usr\bin\cygpath.exe' -w $_)
    )
}
if (($expectedEnvironment -join "`n") -ine ($actualEnvironment -join "`n")) {
    throw 'Fish environment escaped the MSYS2 home containment'
}

$uvCache = [IO.Path]::GetFullPath((uv cache dir).Trim())
$expectedUvCache = [IO.Path]::GetFullPath("$env:XDG_CACHE_HOME\uv")
if (-not $uvCache.Equals($expectedUvCache, [StringComparison]::OrdinalIgnoreCase)) {
    throw "uv cache escaped the MSYS2 home: $uvCache"
}

$ghqRoot = [IO.Path]::GetFullPath((ghq root).Trim())
$expectedGhqRoot = [IO.Path]::GetFullPath("$env:HOME\ghq")
if (-not $ghqRoot.Equals($expectedGhqRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ghq escaped the MSYS2 home: $ghqRoot"
}
$ghqRoots = @(ghq root --all)
if (
    $ghqRoots.Count -ne 1 -or
    -not [IO.Path]::GetFullPath($ghqRoots[0].Trim()).Equals(
        $expectedGhqRoot,
        [StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "Unexpected ghq roots: $($ghqRoots -join ', ')"
}

$miseData = [IO.Path]::GetFullPath("$env:HOME\.local\share\mise")
if (-not (Test-Path -LiteralPath $miseData -PathType Container)) {
    throw "mise data is missing from the MSYS2 home: $miseData"
}
$ghqInstall = [IO.Path]::GetFullPath((mise where ghq).Trim())
if (-not $ghqInstall.StartsWith(
    "$miseData$([IO.Path]::DirectorySeparatorChar)",
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "mise install escaped the MSYS2 home: $ghqInstall"
}

function Assert-SymbolicLinkTarget([string] $LinkPath, [string] $ExpectedTarget) {
    $link = Get-Item -LiteralPath $linkPath -Force
    if ($link.LinkType -ne 'SymbolicLink') {
        throw "Bridge is not a symbolic link: $LinkPath"
    }
    $resolvedTarget = $link.ResolveLinkTarget($false)
    if ($null -eq $resolvedTarget) {
        throw "Unable to resolve bridge target: $LinkPath"
    }
    $actual = [IO.Path]::GetFullPath($resolvedTarget.FullName).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $expected = [IO.Path]::GetFullPath($ExpectedTarget).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if (-not [string]::Equals(
        $actual,
        $expected,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unexpected bridge target: $LinkPath -> $actual"
    }
}

function Resolve-BridgeRoot([string] $Name) {
    switch ($Name) {
        'msys2UserProfile' { return $env:HOME }
        'windowsUserProfile' { return $env:DOTFILES_CI_HOST_PROFILE }
        'windowsLocalAppData' { return $env:DOTFILES_CI_HOST_LOCALAPPDATA }
        default { throw "Unknown bridge root: $Name" }
    }
}

$bridges = (chezmoi --source $env:GITHUB_WORKSPACE execute-template '{{ .windows.bridges | toJson }}') | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($bridge in @($bridges)) {
    Assert-SymbolicLinkTarget `
        (Join-Path (Resolve-BridgeRoot $bridge.symlinkRoot) $bridge.symlink) `
        (Join-Path (Resolve-BridgeRoot $bridge.targetRoot) $bridge.target)
}

$secondAuditState = "$env:HOME\.local\state\dotfiles-leakage-ci\second"
$auditScript = Join-Path $env:TEMP 'windows-leakage-audit.ps1'
& $auditScript `
    start `
    -HostProfile $env:DOTFILES_CI_HOST_PROFILE `
    -HostTemp $env:DOTFILES_CI_HOST_TEMP `
    -HostLocalAppData $env:DOTFILES_CI_HOST_LOCALAPPDATA `
    -HostRoamingAppData $env:DOTFILES_CI_HOST_APPDATA `
    -WorkspaceRoots $env:GITHUB_WORKSPACE `
    -StateRoot $secondAuditState

$secondApply = @()
$secondApplyExitCode = 0
$secondApplyError = $null
$auditError = $null
try {
    $secondApply = chezmoi --source $env:GITHUB_WORKSPACE apply --no-tty
    $secondApplyExitCode = $LASTEXITCODE
} catch {
    $secondApplyError = $_
} finally {
    try {
        try {
            & $auditScript stop -StateRoot $secondAuditState
        } finally {
            & $auditScript report -StateRoot $secondAuditState
        }
        & .github/scripts/verify-windows-containment.ps1 `
            -StateRoot $secondAuditState
    } catch {
        $auditError = $_
    }
}

$secondApply
if ($null -ne $secondApplyError) { throw $secondApplyError }
if ($secondApplyExitCode -ne 0) { exit $secondApplyExitCode }
if ($null -ne $auditError) { throw $auditError }

if (@($secondApply | Select-String -SimpleMatch 'already installed').Count -ne 2) {
    throw 'Second apply reinstalled a managed font'
}

$diff = chezmoi `
    --source $env:GITHUB_WORKSPACE `
    diff `
    --no-pager `
    --exclude scripts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($diff) { throw "chezmoi diff is not empty`n$diff" }
if (git status --porcelain) { throw 'Source tree is not clean' }
