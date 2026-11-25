[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string]$Source,
    [switch]$Restore,
    [Parameter(DontShow)][switch]$AtSignIn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scheme = 'macOS Tahoe (Custom Cursors)'
$root = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TahoeCursors'
$backupPath = Join-Path $root 'previous-settings.json'
$cursorKey = 'Control Panel\Cursors'
$schemeKey = "$cursorKey\Schemes"
$shortcutName = 'Restore Tahoe cursor scheme.lnk'

# The order of the entries is the order used by Mouse Properties for saved schemes.
$files = [ordered]@{
    Arrow = 'arrow.cur'; Help = 'help.cur'; AppStarting = 'wait.ani'; Wait = 'busy.ani'
    Crosshair = 'cross.cur'; IBeam = 'beam.cur'; NWPen = 'pen.cur'; No = 'no.cur'
    SizeNS = 'vsize.cur'; SizeWE = 'hsize.cur'; SizeNWSE = 'dsize1.cur'; SizeNESW = 'dsize2.cur'
    SizeAll = 'move.cur'; UpArrow = 'up.cur'; Hand = 'link.cur'; Pin = 'location.cur'; Person = 'person.cur'
}

function Initialize-CursorApi {
    if ('TahoeCursorApi' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class TahoeCursorApi {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr LoadCursorFromFile(string file);

    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SystemParametersInfo(uint action, uint param, IntPtr value, uint flags);
}
'@
}

function Update-DesktopCursors {
    Initialize-CursorApi
    # SPI_SETCURSORS reloads the registry settings into the interactive session.
    if (-not [TahoeCursorApi]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Windows rejected the cursor reload (Win32 error $code)."
    }
}

function Get-CursorSettings([string]$directory) {
    $paths = foreach ($role in $files.Keys) {
        $path = Join-Path $directory $files[$role]
        if (-not [IO.File]::Exists($path)) { throw "Cursor file is missing: $path" }
        $path
    }

    $schemePaths = $paths
    if ($directory.Contains(',')) {
        # Keep profile-directory commas out of the saved scheme's delimiter-separated list.
        $schemePaths = foreach ($name in $files.Values) {
            '%LOCALAPPDATA%\TahoeCursors\{0}\{1}' -f (Split-Path -Leaf $directory), $name
        }
    }
    $settings = @([pscustomobject]@{
        Key = $schemeKey; Name = $scheme; Kind = 'String'; Value = $schemePaths -join ','
    })
    $index = 0
    foreach ($role in $files.Keys) {
        $settings += [pscustomobject]@{ Key = $cursorKey; Name = $role; Kind = 'String'; Value = $paths[$index] }
        $index++
    }
    $settings += [pscustomobject]@{ Key = $cursorKey; Name = ''; Kind = 'String'; Value = $scheme }
    $settings += [pscustomobject]@{ Key = $cursorKey; Name = 'Scheme Source'; Kind = 'DWord'; Value = 2 }
    $settings
}

function Read-CursorSettings($settings) {
    foreach ($setting in $settings) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Key)
        try {
            $kind = $null
            $value = $null
            if ($null -ne $key -and $key.GetValueNames() -contains $setting.Name) {
                $kind = $key.GetValueKind($setting.Name).ToString()
                $value = $key.GetValue($setting.Name, $null, 'DoNotExpandEnvironmentNames')
            }
            [pscustomobject]@{ Key = $setting.Key; Name = $setting.Name; Kind = $kind; Value = $value }
        } finally {
            if ($null -ne $key) { $key.Dispose() }
        }
    }
}

function Write-CursorSettings($settings) {
    foreach ($setting in $settings) {
        if ($null -eq $setting.Kind) {
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Key, $true)
            if ($null -eq $key) { continue }
            try { $key.DeleteValue($setting.Name, $false) } finally { $key.Dispose() }
            continue
        }
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($setting.Key)
        try {
            $value = $setting.Value
            switch ($setting.Kind) {
                'Binary'      { $value = [byte[]]$value }
                'MultiString' { $value = [string[]]$value }
                'DWord'       { $value = [int]$value }
                'QWord'       { $value = [long]$value }
            }
            $key.SetValue($setting.Name, $value, [Microsoft.Win32.RegistryValueKind]$setting.Kind)
        } finally { $key.Dispose() }
    }
}

function Set-CursorsWithRollback($desired, $previous) {
    try {
        Write-CursorSettings $desired
        Update-DesktopCursors
    } catch {
        $applyError = $_
        try {
            Write-CursorSettings $previous
            Update-DesktopCursors
        } catch {
            Write-Warning "Restoring the previous cursor settings also failed: $($_.Exception.Message)"
        }
        throw $applyError
    }
}

function Get-SignInArguments([string]$scriptPath) {
    '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -AtSignIn' -f $scriptPath
}

function Save-SignInShortcut([string]$path, [string]$scriptPath) {
    $temporary = Join-Path (Split-Path -Parent $path) ('.Tahoe-' + [guid]::NewGuid() + '.lnk')
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($temporary)
        $link.TargetPath = Join-Path $PSHOME 'powershell.exe'
        $link.Arguments = Get-SignInArguments $scriptPath
        $link.WorkingDirectory = Split-Path -Parent $scriptPath
        $link.Description = 'Reapply the macOS Tahoe Windows cursor scheme at sign-in'
        $link.WindowStyle = 7
        $link.Save()
        if ([IO.File]::Exists($path)) {
            [IO.File]::Replace($temporary, $path, [NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $path)
        }
    } finally {
        [IO.File]::Delete($temporary)
    }
}

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this script with Windows PowerShell (powershell.exe).'
}
if ($Restore -and $AtSignIn) { throw '-Restore and -AtSignIn cannot be used together.' }
if ($Restore -and -not [IO.File]::Exists($backupPath)) {
    throw "No saved cursor settings were found at $backupPath"
}

[void][IO.Directory]::CreateDirectory($root)
$lock = [IO.File]::Open((Join-Path $root 'installer.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $startup = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startup $shortcutName

    if ($AtSignIn) {
        # A queued sign-in process can arrive after a restore or package upgrade.
        if (-not [IO.File]::Exists($backupPath) -or -not [IO.File]::Exists($shortcutPath)) { return }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcutPath)
        if ($link.Arguments -ne (Get-SignInArguments $PSCommandPath)) { return }
        $desired = Get-CursorSettings $PSScriptRoot
        $current = Read-CursorSettings $desired
        $changes = @(for ($i = 0; $i -lt $desired.Count; $i++) {
            if ($current[$i].Kind -ne $desired[$i].Kind -or $current[$i].Value -cne $desired[$i].Value) {
                $desired[$i]
            }
        })
        if ($changes.Count -gt 0) { Set-CursorsWithRollback $changes $current }
        [IO.File]::Delete((Join-Path $root 'sign-in-error.txt'))
        return
    }

    if ($Restore) {
        $previous = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
        $current = Read-CursorSettings $previous
        Set-CursorsWithRollback $previous $current
        try {
            [IO.File]::Delete($shortcutPath)
        } catch {
            Set-CursorsWithRollback $current $previous
            throw
        }
        [IO.File]::Delete($backupPath)
        Write-Output 'Restored your previous Windows cursor settings and removed the sign-in shortcut.'
        return
    }

    # Build and validate a fresh copy before touching the active scheme. A new pack
    # gets its own directory so reinstalling cannot overwrite live cursor files.
    Initialize-CursorApi
    # Windows PowerShell 5.1 can evaluate parameter defaults before $PSScriptRoot is available.
    if (-not $PSBoundParameters.ContainsKey('Source')) {
        $Source = Join-Path $PSScriptRoot 'cursors'
    }
    $sourcePath = (Resolve-Path -LiteralPath $Source).ProviderPath
    if (-not [IO.Directory]::Exists($sourcePath)) { throw "Cursor source must be a folder: $sourcePath" }
    $staging = Join-Path $root ('.install-' + [guid]::NewGuid())
    [void][IO.Directory]::CreateDirectory($staging)
    try {
        foreach ($name in $files.Values) {
            $copy = Join-Path $staging $name
            [IO.File]::Copy((Join-Path $sourcePath $name), $copy)
            if ([TahoeCursorApi]::LoadCursorFromFile($copy) -eq [IntPtr]::Zero) {
                throw "Windows could not load $name as a cursor."
            }
        }
        $installerCopy = Join-Path $staging 'Install-TahoeCursors.ps1'
        [IO.File]::Copy($PSCommandPath, $installerCopy)
        $hashes = @(foreach ($name in @($files.Values) + 'Install-TahoeCursors.ps1') {
            (Get-FileHash -LiteralPath (Join-Path $staging $name)).Hash
        })
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes(($hashes -join '')))
        } finally { $sha.Dispose() }
        $version = [BitConverter]::ToString($digest).Replace('-', '').Substring(0, 24)
        $destination = Join-Path $root "pack-$version"
        if ([IO.Directory]::Exists($destination)) {
            $names = @($files.Values) + 'Install-TahoeCursors.ps1'
            for ($i = 0; $i -lt $names.Count; $i++) {
                $target = Join-Path $destination $names[$i]
                if (-not [IO.File]::Exists($target) -or (Get-FileHash -LiteralPath $target).Hash -ne $hashes[$i]) {
                    $destination = Join-Path $root ("pack-$version-" + [guid]::NewGuid().ToString('N'))
                    break
                }
            }
        }
        if (-not [IO.Directory]::Exists($destination)) { [IO.Directory]::Move($staging, $destination) }
    } finally {
        if ([IO.Directory]::Exists($staging)) { [IO.Directory]::Delete($staging, $true) }
    }

    $desired = Get-CursorSettings $destination
    $previous = Read-CursorSettings $desired
    if (-not [IO.File]::Exists($backupPath)) {
        $temporary = Join-Path $root ('backup-' + [guid]::NewGuid() + '.json')
        try {
            $previous | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding UTF8
            [IO.File]::Move($temporary, $backupPath)
        } finally { [IO.File]::Delete($temporary) }
    }
    [void][IO.Directory]::CreateDirectory($startup)
    Set-CursorsWithRollback $desired $previous
    try {
        Save-SignInShortcut $shortcutPath (Join-Path $destination 'Install-TahoeCursors.ps1')
    } catch {
        Set-CursorsWithRollback $previous $desired
        throw
    }
    Write-Output "Installed '$scheme' for this account. Windows will reapply it at sign-in."
    Write-Output "Cursor files: $destination"
} catch {
    if ($AtSignIn) {
        ('{0:o} {1}' -f (Get-Date), $_.Exception.Message) |
            Set-Content -LiteralPath (Join-Path $root 'sign-in-error.txt') -Encoding UTF8
    }
    throw
} finally {
    $lock.Dispose()
}
