param(
    [Parameter(Mandatory)]
    [string] $StateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$active = Get-Content -LiteralPath (Join-Path $StateRoot 'active.json') -Raw |
    ConvertFrom-Json

$checks = @(
    @{ diff = 'local'; paths = @('mise', 'aube') },
    @{ diff = 'temp'; paths = @('mise', 'hunk', 'hunk-mcp') },
    @{ diff = 'profileDotRoots'; paths = @('.local/state/mise', '.atuin') }
)

foreach ($check in $checks) {
    $diff = Get-Content `
        -LiteralPath (Join-Path $active.sessionDirectory "diff\$($check.diff).json") `
        -Raw | ConvertFrom-Json

    foreach ($status in 'new', 'modified', 'deleted', 'metadataOnly') {
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
