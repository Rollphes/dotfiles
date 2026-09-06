<#
.SYNOPSIS
Captures a temporary Windows/MSYS2 runtime leakage audit session.

.DESCRIPTION
Use start before normal CLI work, stop afterward, and report to regenerate the
human-readable summary. ProcMon attribution is enabled only when ProcMon is
available, its EULA was already accepted, no existing session is running, and
-ProcMonConfig names an audit-specific PMC with destructive path/write filters.

.PARAMETER ProcMonConfig
An exported ProcMon configuration with Drop Filtered Events enabled. It must
include Path/Begins with rules for the displayed quarantine and host roots and
Operation/Is rules for the write operations validated by this script. Create it
in the ProcMon UI and export it without replacing your normal configuration.

.EXAMPLE
./tools/windows-leakage-audit.ps1 start -ProcMonConfig C:\audit\leakage.pmc

.EXAMPLE
./tools/windows-leakage-audit.ps1 stop

.EXAMPLE
./tools/windows-leakage-audit.ps1 report
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('start', 'stop', 'report')]
    [string] $Command,

    [string] $Session,
    [string] $CanonicalHome,
    [string] $HostProfile,
    [string] $StateRoot,
    [string] $ProcMonPath,
    [string] $ProcMonConfig,
    [switch] $SnapshotOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param([Parameter(Mandatory)][string] $Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        return $root
    }
    return $fullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-CanonicalHome {
    if ($CanonicalHome) {
        return Resolve-FullPath $CanonicalHome
    }

    if ($env:HOME -and [IO.Path]::IsPathFullyQualified($env:HOME)) {
        return Resolve-FullPath $env:HOME
    }

    if (-not $env:USERNAME) {
        throw 'Cannot derive the MSYS2 canonical home: USERNAME is unset.'
    }

    return Resolve-FullPath (Join-Path 'C:\msys64\home' $env:USERNAME)
}

function Resolve-HostProfile {
    if ($HostProfile) {
        return Resolve-FullPath $HostProfile
    }

    $profile = [Environment]::GetFolderPath('UserProfile')
    if (-not $profile) {
        $profile = $env:USERPROFILE
    }
    if (-not $profile) {
        throw 'Cannot derive the Windows host profile.'
    }

    return Resolve-FullPath $profile
}

function Resolve-StateRoot {
    param([Parameter(Mandatory)][string] $HomePath)

    if ($StateRoot) {
        return Resolve-FullPath $StateRoot
    }

    if ($env:XDG_STATE_HOME -and [IO.Path]::IsPathFullyQualified($env:XDG_STATE_HOME)) {
        return Resolve-FullPath (Join-Path $env:XDG_STATE_HOME 'dotfiles-leakage-audit')
    }

    return Resolve-FullPath (Join-Path $HomePath '.local\state\dotfiles-leakage-audit')
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)] $Value,
        [Parameter(Mandatory)][string] $Path
    )

    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string] $Path)

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-LinkTarget {
    param([Parameter(Mandatory)] $Item)

    if (-not ($Item.PSObject.Properties.Name -contains 'Target')) {
        return $null
    }

    $targets = @(@($Item.Target) | Where-Object { $_ })
    if ($targets.Count -eq 0) {
        return $null
    }

    return ($targets -join '; ')
}

function Get-EntryType {
    param([Parameter(Mandatory)] $Item)

    if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if ($Item.LinkType -eq 'SymbolicLink') { return 'symbolicLink' }
        if ($Item.LinkType -eq 'Junction') { return 'junction' }
        return 'reparsePoint'
    }
    if ($Item.PSIsContainer) { return 'directory' }
    return 'file'
}

function New-Snapshot {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $OutputPath
    )

    $rootPath = Resolve-FullPath $Root
    $entries = [Collections.Generic.List[object]]::new()

    if (Test-Path -LiteralPath $rootPath) {
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($rootPath)
        while ($pending.Count -gt 0) {
            $directory = $pending.Pop()
            foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
                $fullPath = [IO.Path]::GetFullPath($item.FullName)
                $relativePath = $fullPath.Substring($rootPath.Length).TrimStart('\', '/') -replace '\\', '/'
                $type = Get-EntryType $item
                $entry = [ordered]@{
                    path = $relativePath
                    type = $type
                    size = if ($type -eq 'file') { $item.Length } else { $null }
                    lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
                    sha256 = if ($type -eq 'file') {
                        (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
                    } else { $null }
                    target = Get-LinkTarget $item
                }
                $entries.Add([pscustomobject]$entry)

                if ($item.PSIsContainer -and $type -eq 'directory') {
                    $pending.Push($fullPath)
                }
            }
        }
    }

    $snapshot = [ordered]@{
        root = $rootPath
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        entries = @($entries | Sort-Object path)
    }
    Write-JsonFile $snapshot $OutputPath
    return [pscustomobject]$snapshot
}

function Compare-Snapshots {
    param(
        [Parameter(Mandatory)] $Before,
        [Parameter(Mandatory)] $After
    )

    $beforeByPath = @{}
    $afterByPath = @{}
    foreach ($entry in @($Before.entries)) { $beforeByPath[$entry.path] = $entry }
    foreach ($entry in @($After.entries)) { $afterByPath[$entry.path] = $entry }

    $new = [Collections.Generic.List[object]]::new()
    $modified = [Collections.Generic.List[object]]::new()
    $deleted = [Collections.Generic.List[object]]::new()
    $metadataOnly = [Collections.Generic.List[object]]::new()

    foreach ($path in $afterByPath.Keys) {
        if (-not $beforeByPath.ContainsKey($path)) {
            $new.Add($afterByPath[$path])
            continue
        }

        $old = $beforeByPath[$path]
        $current = $afterByPath[$path]
        $reason = if ($old.type -ne $current.type) {
            'type'
        } elseif ($current.type -eq 'file' -and $old.sha256 -ne $current.sha256) {
            'content'
        } elseif ($old.target -ne $current.target) {
            'linkTarget'
        } else {
            $null
        }

        if ($reason) {
            $modified.Add([pscustomobject]@{ path = $path; reason = $reason; before = $old; after = $current })
        } elseif ($old.lastWriteTimeUtc -ne $current.lastWriteTimeUtc) {
            $metadataOnly.Add([pscustomobject]@{ path = $path; before = $old.lastWriteTimeUtc; after = $current.lastWriteTimeUtc })
        }
    }

    foreach ($path in $beforeByPath.Keys) {
        if (-not $afterByPath.ContainsKey($path)) {
            $deleted.Add($beforeByPath[$path])
        }
    }

    return [pscustomobject][ordered]@{
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        new = @($new | Sort-Object path)
        modified = @($modified | Sort-Object path)
        deleted = @($deleted | Sort-Object path)
        metadataOnly = @($metadataOnly | Sort-Object path)
    }
}

function Find-ProcMon {
    if ($ProcMonPath) {
        if (-not (Test-Path -LiteralPath $ProcMonPath -PathType Leaf)) {
            throw "ProcMon executable not found: $ProcMonPath"
        }
        return Resolve-FullPath $ProcMonPath
    }

    foreach ($name in 'procmon64.exe', 'procmon.exe', 'procmon64a.exe') {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }

    $locations = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\Procmon64.exe'),
        (Join-Path $env:ProgramFiles 'Sysinternals\Procmon64.exe'),
        (Join-Path $env:ProgramFiles 'Sysinternals Suite\Procmon64.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
    return $locations | Select-Object -First 1
}

function Get-ProcMonProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @('Procmon', 'Procmon64', 'Procmon64a')
    })
}

function Test-ProcMonEulaAccepted {
    $key = 'HKCU:\Software\Sysinternals\Process Monitor'
    try {
        return (Get-ItemPropertyValue -LiteralPath $key -Name EulaAccepted -ErrorAction Stop) -eq 1
    } catch {
        return $false
    }
}

function Read-ProcMonConfig {
    param([Parameter(Mandatory)][string] $Path)

    # PMC is undocumented. Reject the config when its expected layout changes.
    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0
    $configuration = @{}
    while ($offset -lt $bytes.Length) {
        if ($bytes.Length - $offset -lt 16) { throw 'Invalid PMC record header.' }
        $recordSize = [BitConverter]::ToUInt32($bytes, $offset)
        $headerSize = [BitConverter]::ToUInt32($bytes, $offset + 4)
        $headerAndNameSize = [BitConverter]::ToUInt32($bytes, $offset + 8)
        $dataSize = [BitConverter]::ToUInt32($bytes, $offset + 12)
        if ($headerSize -ne 16 -or $recordSize -ne $headerAndNameSize + $dataSize -or
            $recordSize -eq 0 -or $offset + $recordSize -gt $bytes.Length) {
            throw 'Invalid PMC record size.'
        }

        $nameSize = $headerAndNameSize - $headerSize
        $name = [Text.Encoding]::Unicode.GetString($bytes, $offset + $headerSize, $nameSize).TrimEnd([char]0)
        $dataOffset = $offset + $headerAndNameSize
        $configuration[$name] = [pscustomobject]@{
            bytes = $bytes
            offset = $dataOffset
            size = $dataSize
        }
        $offset += $recordSize
    }
    return $configuration
}

function Read-ProcMonFilterRules {
    param([Parameter(Mandatory)] $Record)

    if ($Record.size -lt 5 -or $Record.bytes[$Record.offset] -ne 1) {
        throw 'Invalid PMC FilterRules record.'
    }
    $count = [BitConverter]::ToUInt32($Record.bytes, $Record.offset + 1)
    $offset = $Record.offset + 5
    $end = $Record.offset + $Record.size
    $rules = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $count; $index++) {
        if ($end - $offset -lt 21) { throw 'Invalid PMC filter rule.' }
        $column = [BitConverter]::ToUInt32($Record.bytes, $offset)
        $relation = [BitConverter]::ToUInt32($Record.bytes, $offset + 4)
        $action = $Record.bytes[$offset + 8]
        $valueLength = [BitConverter]::ToUInt32($Record.bytes, $offset + 9)
        if ($valueLength % 2 -ne 0 -or $offset + 21 + $valueLength -gt $end) {
            throw 'Invalid PMC filter value.'
        }
        $value = [Text.Encoding]::Unicode.GetString($Record.bytes, $offset + 13, $valueLength).TrimEnd([char]0)
        $rules.Add([pscustomobject]@{
            column = $column
            relation = $relation
            action = $action
            value = $value
        })
        $offset += 21 + $valueLength
    }
    return @($rules)
}

function Test-ProcMonConfig {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $MonitoredRoots
    )

    $configuration = Read-ProcMonConfig $Path
    if (-not $configuration.ContainsKey('DestructiveFilter') -or
        $configuration.DestructiveFilter.size -lt 4 -or
        [BitConverter]::ToUInt32(
            $configuration.DestructiveFilter.bytes,
            $configuration.DestructiveFilter.offset
        ) -ne 1) {
        throw 'ProcMon configuration must enable Drop Filtered Events.'
    }
    if (-not $configuration.ContainsKey('FilterRules')) {
        throw 'ProcMon configuration has no filter rules.'
    }

    $rules = @(Read-ProcMonFilterRules $configuration.FilterRules)
    $pathIncludes = @($rules | Where-Object { $_.column -eq 40071 -and $_.action -eq 1 })
    if ($pathIncludes.Count -ne $MonitoredRoots.Count) {
        throw 'ProcMon configuration contains an unexpected Path include rule.'
    }
    foreach ($root in $MonitoredRoots) {
        $expected = (Resolve-FullPath $root).TrimEnd('\')
        $matching = @($pathIncludes | Where-Object {
            $_.relation -eq 4 -and
            $_.value.TrimEnd('\').Equals($expected, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($matching.Count -eq 0) {
            throw "ProcMon configuration must include Path begins with: $expected"
        }
    }

    $requiredOperations = @(
        'CreateFile',
        'WriteFile',
        'SetEndOfFileInformationFile',
        'SetRenameInformationFile',
        'SetDispositionInformationFile',
        'SetBasicInformationFile'
    )
    if ($rules.Count -ne $MonitoredRoots.Count + $requiredOperations.Count) {
        throw 'ProcMon configuration contains unexpected filter rules.'
    }
    $operationIncludes = @($rules | Where-Object { $_.column -eq 40055 -and $_.action -eq 1 })
    if ($operationIncludes.Count -ne $requiredOperations.Count) {
        throw 'ProcMon configuration contains an unexpected Operation include rule.'
    }
    foreach ($operation in $requiredOperations) {
        $matching = @($operationIncludes | Where-Object {
            $_.relation -eq 0 -and
            $_.value.Equals($operation, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($matching.Count -eq 0) {
            throw "ProcMon configuration must include Operation is: $operation"
        }
    }
}

function Start-ProcMonCapture {
    param(
        [Parameter(Mandatory)][string] $Executable,
        [Parameter(Mandatory)][string] $PmlPath,
        [Parameter(Mandatory)][string] $ConfigPath
    )

    if ((Get-ProcMonProcesses).Count -ne 0) {
        return [pscustomobject]@{ mode = 'snapshot-only'; reason = 'An existing ProcMon session is running.'; owned = $false }
    }
    if (-not (Test-ProcMonEulaAccepted)) {
        return [pscustomobject]@{ mode = 'snapshot-only'; reason = 'ProcMon EULA has not been accepted manually.'; owned = $false }
    }

    Start-Process -FilePath $Executable `
        -ArgumentList @('/Quiet', '/Minimized', '/LoadConfig', $ConfigPath, '/BackingFile', $PmlPath) `
        -WindowStyle Hidden | Out-Null
    $process = $null
    for ($attempt = 0; $attempt -lt 20 -and -not $process; $attempt++) {
        Start-Sleep -Milliseconds 250
        $process = Get-ProcMonProcesses | Select-Object -First 1
    }
    if (-not $process) {
        return [pscustomobject]@{ mode = 'snapshot-only'; reason = 'ProcMon did not remain running.'; owned = $false }
    }

    return [pscustomobject]@{ mode = 'capture'; reason = $null; owned = $true; pid = $process.Id }
}

function Stop-ProcMonCapture {
    param([Parameter(Mandatory)] $Metadata)

    if ($Metadata.procmon.mode -ne 'capture' -or -not $Metadata.procmon.owned) {
        return $null
    }

    $running = Get-ProcMonProcesses
    if ($running.Count -eq 0) { return $null }

    $owned = @($running | Where-Object { $_.Id -eq [int]$Metadata.procmon.pid })
    if ($owned.Count -ne 1 -or $running.Count -ne 1) {
        return 'ProcMon was not stopped because the running session no longer matches the audit-owned process.'
    }

    $stop = Start-Process -FilePath $Metadata.procmon.executable -ArgumentList @('/Terminate', '/Quiet') -WindowStyle Hidden -Wait -PassThru
    if ($stop.ExitCode -ne 0) {
        return "ProcMon terminate returned exit code $($stop.ExitCode)."
    }
    return $null
}

function Export-ProcMonCsv {
    param([Parameter(Mandatory)] $Metadata)

    if (-not $Metadata.procmon.executable -or -not (Test-Path -LiteralPath $Metadata.procmon.pmlPath)) {
        return $null
    }
    if ((Get-ProcMonProcesses).Count -ne 0) {
        return 'ProcMon CSV export skipped while a ProcMon session is running.'
    }

    $export = Start-Process -FilePath $Metadata.procmon.executable `
        -ArgumentList @('/OpenLog', $Metadata.procmon.pmlPath, '/SaveAs', $Metadata.procmon.csvPath, '/Quiet') `
        -WindowStyle Hidden -Wait -PassThru
    if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $Metadata.procmon.csvPath)) {
        return "ProcMon CSV export failed with exit code $($export.ExitCode)."
    }
    return $null
}

function Test-PathWithin {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Root
    )

    $candidate = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $candidate.Equals($rootPath, [StringComparison]::OrdinalIgnoreCase) -or
        $candidate.StartsWith("$rootPath\", [StringComparison]::OrdinalIgnoreCase)
}

function Get-ManagedBridgeRoots {
    param([Parameter(Mandatory)][string] $ProfileRoot)

    $manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.chezmoidata\windows-bridges.toml'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return @() }

    return @(Get-Content -LiteralPath $manifestPath | ForEach-Object {
        if ($_ -match '^\s*path\s*=\s*"(?<path>[^"]+)"\s*$') {
            Resolve-FullPath (Join-Path $ProfileRoot ($Matches.path -replace '/', '\'))
        }
    })
}

function Get-ProcMonDetailField {
    param(
        [Parameter(Mandatory)][string] $Detail,
        [Parameter(Mandatory)][string] $Name
    )

    $escapedName = [Regex]::Escape($Name)
    $match = [Regex]::Match(
        $Detail,
        "(?:^|,\s*)${escapedName}:\s*(?<value>.*?)(?=,\s*[A-Za-z][A-Za-z ]+:\s|$)",
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) { return $null }
    return $match.Groups['value'].Value.Trim()
}

function Test-CreateFileWrite {
    param([Parameter(Mandatory)][string] $Detail)

    $desiredAccess = Get-ProcMonDetailField $Detail 'Desired Access'
    if ($desiredAccess -and $desiredAccess -match '(?i)(Generic Write|Write Data|Append Data|Write EA|Write Attributes|Delete|Change Permissions|Take Ownership)') {
        return $true
    }

    $disposition = Get-ProcMonDetailField $Detail 'Disposition'
    if ($disposition -and $disposition -match '^(?i:Create|OpenIf|Overwrite|OverwriteIf|Supersede)$') {
        return $true
    }

    $options = Get-ProcMonDetailField $Detail 'Options'
    return $options -and $options -match '(?i)Delete On Close'
}

function Get-WriteEvents {
    param([Parameter(Mandatory)] $Metadata)

    if (-not (Test-Path -LiteralPath $Metadata.procmon.csvPath -PathType Leaf)) { return @() }

    $operations = @(
        'CreateFile',
        'WriteFile',
        'SetEndOfFileInformationFile',
        'SetRenameInformationFile',
        'SetDispositionInformationFile',
        'SetBasicInformationFile'
    )

    return @(Import-Csv -LiteralPath $Metadata.procmon.csvPath | Where-Object {
        if ($_.Operation -notin $operations) { return $false }
        if ($_.Operation -ne 'CreateFile') { return $true }
        return Test-CreateFileWrite $_.Detail
    })
}

function Get-Attribution {
    param(
        [Parameter(Mandatory)][string] $FullPath,
        [Parameter(Mandatory)][bool] $IsDirectory,
        [object[]] $Events
    )

    $matching = @($Events | Where-Object {
        $_.Path.Equals($FullPath, [StringComparison]::OrdinalIgnoreCase) -or
            ($IsDirectory -and (Test-PathWithin $_.Path $FullPath))
    })
    return @($matching | ForEach-Object {
        [pscustomobject]@{
            process = $_.'Process Name'
            pid = $_.PID
            operation = $_.Operation
        }
    } | Sort-Object process, pid, operation -Unique)
}

function New-Report {
    param(
        [Parameter(Mandatory)] $Metadata,
        [Parameter(Mandatory)] $Diff
    )

    $events = @(Get-WriteEvents $Metadata)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("Windows leakage audit: $($Metadata.sessionId)")
    $lines.Add("Started: $($Metadata.startedAtUtc)")
    $lines.Add("Stopped: $($Metadata.stoppedAtUtc)")
    $lines.Add("ProcMon: $($Metadata.procmon.mode)")
    if ($Metadata.procmon.reason) { $lines.Add("ProcMon note: $($Metadata.procmon.reason)") }
    foreach ($warning in @($Metadata.warnings)) { $lines.Add("Warning: $warning") }
    $lines.Add('')

    foreach ($group in @(
        @{ Name = 'NEW'; Values = @($Diff.new) },
        @{ Name = 'MODIFIED'; Values = @($Diff.modified) },
        @{ Name = 'DELETED'; Values = @($Diff.deleted) }
    )) {
        $lines.Add("$($group.Name): $($group.Values.Count)")
        foreach ($entry in $group.Values) {
            $lines.Add("  QUARANTINE WRITE  $($entry.path)")
            $fullPath = Join-Path $Metadata.quarantineRoot $entry.path
            $type = if ($group.Name -eq 'MODIFIED') { $entry.after.type } else { $entry.type }
            $attribution = @(Get-Attribution $fullPath ($type -ne 'file') $events)
            if ($attribution.Count -eq 0) {
                $lines.Add('    process: unavailable')
            } else {
                foreach ($writer in $attribution) {
                    $lines.Add("    process: $($writer.process)  pid=$($writer.pid)  operation=$($writer.operation)")
                }
            }
        }
        $lines.Add('')
    }

    $lines.Add("METADATA ONLY: $(@($Diff.metadataOnly).Count)")
    foreach ($entry in @($Diff.metadataOnly)) { $lines.Add("  $($entry.path)") }
    $lines.Add('')

    $managedBridgeRoots = if ($Metadata.PSObject.Properties.Name -contains 'managedBridgeRoots') {
        @($Metadata.managedBridgeRoots)
    } else { @() }
    $managedBridgeEvents = @($events | Where-Object {
        $event = $_
        @($managedBridgeRoots | Where-Object { Test-PathWithin $event.Path $_ }).Count -ne 0
    })
    $lines.Add("MANAGED BRIDGE ACCESS: $($managedBridgeEvents.Count)")
    foreach ($event in $managedBridgeEvents | Sort-Object Path, 'Process Name', PID, Operation -Unique) {
        $lines.Add("  path: $($event.Path)")
        $lines.Add("    process: $($event.'Process Name')  pid=$($event.PID)  operation=$($event.Operation)")
    }
    $lines.Add('')

    $hostEvents = @($events | Where-Object {
        $event = $_
        (Test-PathWithin $event.Path $Metadata.hostProfileRoot) -and
        @($managedBridgeRoots | Where-Object { Test-PathWithin $event.Path $_ }).Count -eq 0
    })
    $lines.Add("HOST LEAKAGE: $($hostEvents.Count)")
    foreach ($event in $hostEvents | Sort-Object Path, 'Process Name', PID, Operation -Unique) {
        $lines.Add("  path: $($event.Path)")
        $lines.Add("    process: $($event.'Process Name')  pid=$($event.PID)  operation=$($event.Operation)")
    }
    $lines.Add('')

    $canonicalEvents = @($events | Where-Object {
        (Test-PathWithin $_.Path $Metadata.canonicalHome) -and
        -not (Test-PathWithin $_.Path $Metadata.quarantineRoot) -and
        -not (Test-PathWithin $_.Path $Metadata.stateRoot)
    })
    $lines.Add("CANONICAL writes observed: $($canonicalEvents.Count)")
    $lines.Add('Raw ProcMon evidence remains in procmon.pml and procmon.csv when capture is available.')

    $reportPath = Join-Path $Metadata.sessionDirectory 'report.txt'
    $lines | Set-Content -LiteralPath $reportPath -Encoding utf8
    return $reportPath
}

function Resolve-SessionDirectory {
    param(
        [Parameter(Mandatory)][string] $AuditStateRoot,
        [switch] $RequireActive
    )

    $sessionDirectory = if ($Session) {
        $candidate = if ([IO.Path]::IsPathFullyQualified($Session)) { $Session } else { Join-Path $AuditStateRoot $Session }
        Resolve-FullPath $candidate
    } else {
        $activePath = Join-Path $AuditStateRoot 'active.json'
        if (Test-Path -LiteralPath $activePath) {
            (Read-JsonFile $activePath).sessionDirectory
        } else {
            if ($RequireActive) { throw 'No active audit session was found.' }
            $latest = Get-ChildItem -LiteralPath $AuditStateRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
            if (-not $latest) { throw 'No audit session was found.' }
            $latest.FullName
        }
    }

    $resolved = Resolve-FullPath $sessionDirectory
    $stateRootPath = Resolve-FullPath $AuditStateRoot
    if ($resolved.Equals($stateRootPath, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-PathWithin $resolved $stateRootPath)) {
        throw "Audit session must remain below the audit state root: $resolved"
    }
    return $resolved
}

$canonicalHomePath = Resolve-CanonicalHome
$hostProfilePath = Resolve-HostProfile
$auditStateRoot = Resolve-StateRoot $canonicalHomePath
$quarantineRoot = Join-Path $canonicalHomePath '.winprofile'

if (-not (Test-PathWithin $auditStateRoot $canonicalHomePath) -or
    (Test-PathWithin $auditStateRoot $quarantineRoot) -or
    (Test-PathWithin $auditStateRoot $hostProfilePath)) {
    throw "Audit state must remain in the canonical home outside .winprofile: $auditStateRoot"
}

switch ($Command) {
    'start' {
        New-Item -ItemType Directory -Path $auditStateRoot -Force | Out-Null
        $activePath = Join-Path $auditStateRoot 'active.json'
        if (Test-Path -LiteralPath $activePath) {
            $active = Read-JsonFile $activePath
            if ($active.status -eq 'running') {
                throw "Audit session is already running: $($active.sessionDirectory)"
            }
        }

        $sessionId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
        $sessionDirectory = Join-Path $auditStateRoot $sessionId
        New-Item -ItemType Directory -Path $sessionDirectory | Out-Null
        New-Snapshot $quarantineRoot (Join-Path $sessionDirectory 'before.json') | Out-Null

        $executable = if ($SnapshotOnly) { $null } else { Find-ProcMon }
        $sessionConfigPath = Join-Path $sessionDirectory 'procmon.pmc'
        $procmon = if (-not $executable) {
            [pscustomobject]@{ mode = 'snapshot-only'; reason = 'ProcMon unavailable.'; owned = $false }
        } elseif (-not $ProcMonConfig) {
            [pscustomobject]@{
                mode = 'snapshot-only'
                reason = 'ProcMon capture requires -ProcMonConfig with destructive audit filters.'
                owned = $false
            }
        } else {
            $sourceConfigPath = Resolve-FullPath $ProcMonConfig
            if (-not (Test-Path -LiteralPath $sourceConfigPath -PathType Leaf)) {
                throw "ProcMon configuration not found: $sourceConfigPath"
            }
            Test-ProcMonConfig $sourceConfigPath @($quarantineRoot, $hostProfilePath)
            Copy-Item -LiteralPath $sourceConfigPath -Destination $sessionConfigPath
            Start-ProcMonCapture `
                $executable `
                (Join-Path $sessionDirectory 'procmon.pml') `
                $sessionConfigPath
        }

        $cleanupMetadata = [pscustomobject]@{
            procmon = [pscustomobject]@{
                mode = $procmon.mode
                executable = $executable
                owned = $procmon.owned
                pid = if ($procmon.PSObject.Properties.Name -contains 'pid') { $procmon.pid } else { $null }
            }
        }
        try {
            $metadata = [ordered]@{
                schemaVersion = 1
                sessionId = $sessionId
                status = 'running'
                startedAtUtc = [DateTime]::UtcNow.ToString('o')
                stoppedAtUtc = $null
                canonicalHome = $canonicalHomePath
                quarantineRoot = $quarantineRoot
                hostProfileRoot = $hostProfilePath
                managedBridgeRoots = @(Get-ManagedBridgeRoots $hostProfilePath)
                stateRoot = $auditStateRoot
                sessionDirectory = $sessionDirectory
                procmon = [ordered]@{
                    mode = $procmon.mode
                    reason = $procmon.reason
                    executable = $executable
                    configPath = if (Test-Path -LiteralPath $sessionConfigPath) { $sessionConfigPath } else { $null }
                    owned = $procmon.owned
                    pid = if ($procmon.PSObject.Properties.Name -contains 'pid') { $procmon.pid } else { $null }
                    pmlPath = Join-Path $sessionDirectory 'procmon.pml'
                    csvPath = Join-Path $sessionDirectory 'procmon.csv'
                }
                warnings = @()
            }
            Write-JsonFile $metadata (Join-Path $sessionDirectory 'metadata.json')
            Write-JsonFile @{ status = 'running'; sessionDirectory = $sessionDirectory } $activePath
        } catch {
            $initializationError = $_
            try {
                $warning = Stop-ProcMonCapture $cleanupMetadata
                if ($warning) { Write-Warning $warning }
            } catch {
                Write-Warning "ProcMon cleanup failed after audit initialization failed: $_"
            }
            throw $initializationError
        }
        Write-Output "Audit started: $sessionDirectory"
        Write-Output "ProcMon mode: $($procmon.mode)"
        if ($procmon.reason) { Write-Warning $procmon.reason }
    }

    'stop' {
        $sessionDirectory = Resolve-SessionDirectory $auditStateRoot -RequireActive
        $metadataPath = Join-Path $sessionDirectory 'metadata.json'
        $metadata = Read-JsonFile $metadataPath
        if ($metadata.status -ne 'running') { throw "Audit session is not running: $sessionDirectory" }

        $warnings = [Collections.Generic.List[string]]::new()
        $snapshotError = $null
        try {
            $after = New-Snapshot $metadata.quarantineRoot (Join-Path $sessionDirectory 'after.json')
        } catch {
            $snapshotError = $_
        } finally {
            try {
                $warning = Stop-ProcMonCapture $metadata
            } catch {
                $warning = "ProcMon cleanup failed while stopping the audit: $_"
            }
        }
        if ($warning) { $warnings.Add($warning) }
        if ($snapshotError) {
            foreach ($message in $warnings) { Write-Warning $message }
            throw $snapshotError
        }

        $warning = Export-ProcMonCsv $metadata
        if ($warning) { $warnings.Add($warning) }

        $before = Read-JsonFile (Join-Path $sessionDirectory 'before.json')
        $diff = Compare-Snapshots $before $after
        Write-JsonFile $diff (Join-Path $sessionDirectory 'diff.json')

        $metadata.status = 'stopped'
        $metadata.stoppedAtUtc = [DateTime]::UtcNow.ToString('o')
        $metadata.warnings = @($warnings)
        Write-JsonFile $metadata $metadataPath
        Write-JsonFile @{ status = 'stopped'; sessionDirectory = $sessionDirectory } (Join-Path $auditStateRoot 'active.json')
        $reportPath = New-Report $metadata $diff
        Write-Output "Audit stopped: $sessionDirectory"
        Write-Output "Report: $reportPath"
    }

    'report' {
        $sessionDirectory = Resolve-SessionDirectory $auditStateRoot
        $metadata = Read-JsonFile (Join-Path $sessionDirectory 'metadata.json')
        if ($metadata.status -ne 'stopped') { throw "Stop the audit before generating a report: $sessionDirectory" }
        $diff = Read-JsonFile (Join-Path $sessionDirectory 'diff.json')
        $reportPath = New-Report $metadata $diff
        Get-Content -LiteralPath $reportPath
    }
}
