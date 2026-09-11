param(
    [Parameter(Mandatory)]
    [string] $DevelopmentHome
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$nativeHome = [IO.Path]::GetFullPath($DevelopmentHome).TrimEnd('\').Replace('\', '/')
$credentialContract = [ordered]@{
    HOME = $nativeHome
    USERPROFILE = $nativeHome
    APPDATA = "$nativeHome/.config"
    LOCALAPPDATA = "$nativeHome/.local/share"
    TEMP = 'C:/msys64/tmp'
    TMP = 'C:/msys64/tmp'
    XDG_CONFIG_HOME = "$nativeHome/.config"
    XDG_DATA_HOME = "$nativeHome/.local/share"
    XDG_STATE_HOME = "$nativeHome/.local/state"
    XDG_CACHE_HOME = "$nativeHome/.cache"
    MISE_CONFIG_DIR = "$nativeHome/.config/mise"
    MISE_DATA_DIR = "$nativeHome/.local/share/mise"
    MISE_STATE_DIR = "$nativeHome/.local/state/mise"
    MISE_CACHE_DIR = "$nativeHome/.cache/mise"
    MISE_TMP_DIR = "$nativeHome/.cache/mise/tmp"
}

$gitCommand = 'C:\msys64\ucrt64\bin\git.exe'
if (-not (Test-Path -LiteralPath $gitCommand -PathType Leaf)) {
    throw "Managed MSYS2 Git is missing: $gitCommand"
}

$managedHelpers = @{}
foreach ($credentialHost in 'github.com','api.github.com','gist.github.com') {
    $helpers = @(
        & $gitCommand config --global --get-all "credential.https://$credentialHost.helper"
    )
    if ($LASTEXITCODE -ne 0 -or $helpers.Count -lt 2 -or $helpers[0] -ne '') {
        throw "Managed credential helper reset is missing for $credentialHost"
    }

    $helper = $helpers[-1]
    foreach ($entry in $credentialContract.GetEnumerator()) {
        $assignment = "{0}='{1}'" -f $entry.Key, $entry.Value
        if (-not $helper.Contains($assignment, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Credential helper for $credentialHost lacks $assignment"
        }
    }
    if ($helper -notmatch '/\.local/share/mise/shims/gh\.exe\b') {
        throw "Credential helper for $credentialHost does not use the managed gh shim"
    }
    $managedHelpers[$credentialHost] = $helper
}

# Replace only the final gh command; no machine credential is read by this probe.
$probeRoot = Join-Path $env:TEMP (
    "credential-helper-probe-{0}" -f [Guid]::NewGuid().ToString('N')
)
$captureScript = Join-Path $probeRoot 'capture.sh'
$probeConfig = Join-Path $probeRoot 'gitconfig'
$captureFile = Join-Path $probeRoot 'environment.txt'
New-Item -ItemType Directory -Path $probeRoot | Out-Null

try {
    @'
#!/bin/sh
printf '%s\n' \
    "$HOME" "$USERPROFILE" "$APPDATA" "$LOCALAPPDATA" "$TEMP" "$TMP" \
    "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" \
    "$MISE_CONFIG_DIR" "$MISE_DATA_DIR" "$MISE_STATE_DIR" \
    "$MISE_CACHE_DIR" "$MISE_TMP_DIR" > "$CAPTURE_PATH"
printf 'username=containment-probe\npassword=containment-probe\n'
'@ | Set-Content -LiteralPath $captureScript -Encoding utf8NoBOM

    $captureScriptPosix = (& C:\msys64\usr\bin\cygpath.exe -u $captureScript).Trim()
    $captureFilePosix = (& C:\msys64\usr\bin\cygpath.exe -u $captureFile).Trim()
    $expectedEnvironment = @($credentialContract.Values)

    foreach ($credentialHost in 'github.com','api.github.com') {
        $helper = $managedHelpers[$credentialHost]
        $probeHelper = $helper -replace (
            "'[^']+/\.local/share/mise/shims/gh\.exe' auth git-credential$",
            "'C:/msys64/usr/bin/sh.exe' '$captureScriptPosix'"
        )
        if ($probeHelper -eq $helper) {
            throw "Unable to instrument credential helper for $credentialHost"
        }

        if (Test-Path -LiteralPath $probeConfig) {
            Remove-Item -LiteralPath $probeConfig -Force
        }
        & $gitCommand config --file $probeConfig --add `
            "credential.https://$credentialHost.helper" ''
        & $gitCommand config --file $probeConfig --add `
            "credential.https://$credentialHost.helper" $probeHelper
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to create credential probe for $credentialHost"
        }

        "protocol=https`nhost=$credentialHost`n" | & C:\msys64\usr\bin\env.exe `
            'HOME=C:/forbidden-host-fixture' `
            'USERPROFILE=C:/forbidden-host-fixture' `
            'APPDATA=C:/forbidden-host-fixture/AppData/Roaming' `
            'LOCALAPPDATA=C:/forbidden-host-fixture/AppData/Local' `
            'TEMP=C:/forbidden-host-fixture/Temp' `
            'TMP=C:/forbidden-host-fixture/Temp' `
            "CAPTURE_PATH=$captureFilePosix" `
            "GIT_CONFIG_GLOBAL=$probeConfig" `
            'GIT_CONFIG_NOSYSTEM=1' `
            $gitCommand -C $probeRoot -c credential.interactive=false credential fill |
            Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Credential environment probe failed for $credentialHost"
        }

        $actualEnvironment = @(Get-Content -LiteralPath $captureFile)
        if (($actualEnvironment -join "`n") -cne ($expectedEnvironment -join "`n")) {
            throw "Credential helper environment escaped containment for $credentialHost"
        }
    }
} finally {
    foreach ($path in $captureFile,$probeConfig,$captureScript) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    if (Test-Path -LiteralPath $probeRoot) {
        Remove-Item -LiteralPath $probeRoot -Force
    }
}
