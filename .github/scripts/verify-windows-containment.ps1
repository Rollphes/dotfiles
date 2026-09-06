param(
    [Parameter(Mandatory)]
    [string] $StateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$active = Get-Content -LiteralPath (Join-Path $StateRoot 'active.json') -Raw |
    ConvertFrom-Json

$checks = @(
    @{ diff = 'local'; paths = @('mise', 'aube', 'ghq') },
    @{ diff = 'roaming'; paths = @('ghq') },
    @{ diff = 'temp'; paths = @('mise') },
    @{ diff = 'profileDotRoots'; paths = @('.local/state/mise', '.ghq') }
)

foreach ($check in $checks) {
    $diff = Get-Content `
        -LiteralPath (Join-Path $active.sessionDirectory "diff\$($check.diff).json") `
        -Raw | ConvertFrom-Json

    foreach ($status in 'new', 'modified', 'metadataOnly') {
        foreach ($entry in @($diff.$status)) {
            $path = $entry.path -replace '\\', '/'
            foreach ($blocked in $check.paths) {
                if ($path -eq $blocked -or $path.StartsWith("$blocked/", [StringComparison]::OrdinalIgnoreCase)) {
                    throw "Windows containment regression ($status): $path"
                }
            }
        }
    }
}

$hostGhqRoot = Join-Path $env:USERPROFILE 'ghq'
if (Test-Path -LiteralPath $hostGhqRoot) {
    throw "Windows containment regression: $hostGhqRoot"
}
