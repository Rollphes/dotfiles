param(
    [Parameter(Mandatory)]
    [string] $DevelopmentHome
)

$ErrorActionPreference = 'Stop'

$manifest = Get-Content '.chezmoidata/fonts.json' -Raw | ConvertFrom-Json
# Match the installer: registered host folder, independent of process LOCALAPPDATA.
$hostLocal = Get-ItemPropertyValue -LiteralPath 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -Name 'Local AppData'
if (-not $hostLocal) { throw 'Cannot resolve host font directory' }
$fontDirectory = Join-Path $hostLocal 'Microsoft\Windows\Fonts'
$stateDirectory = Join-Path $DevelopmentHome '.local\state\dotfiles-fonts'
$registryKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -AssemblyName System.Drawing

foreach ($font in $manifest.fonts) {
    $checksum = Get-Content (Join-Path $stateDirectory "$($font.id).sha256") -Raw
    if ($checksum.Trim() -ne $font.sha256) {
        throw "State checksum mismatch: $($font.id)"
    }

    $names = @(Get-Content (Join-Path $stateDirectory "$($font.id).files"))
    $managed = @(Get-ChildItem -LiteralPath $fontDirectory -Filter $font.managedGlob)
    if (Compare-Object ($names | Sort-Object) ($managed.Name | Sort-Object)) {
        throw "Managed file set mismatch: $($font.id)"
    }

    foreach ($name in $names) {
        $path = Join-Path $fontDirectory $name
        $collection = [Drawing.Text.PrivateFontCollection]::new()
        try {
            $collection.AddFontFile($path)
            $family = $collection.Families[0].Name
        } finally {
            $collection.Dispose()
        }
        if ($family -ne $font.family) {
            throw "Family mismatch: $name"
        }

        $style = [IO.Path]::GetFileNameWithoutExtension($name).Split('-')[-1]
        $registrationName = "$family $style (TrueType)"
        $registeredPath = Get-ItemPropertyValue `
            -LiteralPath $registryKey `
            -Name $registrationName
        if ([IO.Path]::GetFullPath($registeredPath) -ne [IO.Path]::GetFullPath($path)) {
            throw "Registration mismatch: $name"
        }
    }
}
