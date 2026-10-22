# Installs Yeti X LED Studio for the current user. No admin rights needed, nothing is downloaded.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
param(
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'YetiX-LED-Tool'),
  [switch]$NoDesktopShortcut
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\shortcut.ps1')

Write-Host "Installing to $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'app\*') -Destination $InstallDir -Force
Get-ChildItem -LiteralPath $InstallDir -File | Unblock-File   # remove "downloaded from the internet" mark

# Small launcher exe, compiled locally from launcher\Launcher.cs with the C# compiler that ships with Windows.
$exe = Join-Path $InstallDir 'YetiX-LED-Studio.exe'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (Test-Path -LiteralPath $csc) {
  & $csc /nologo /target:winexe /optimize+ "/win32icon:$(Join-Path $InstallDir 'logo.ico')" "/out:$exe" (Join-Path $PSScriptRoot 'launcher\Launcher.cs')
  if ($LASTEXITCODE -ne 0) { Write-Warning 'Launcher build failed - shortcuts will start PowerShell directly.'; $exe = $null }
} else { $exe = $null }

$script = Join-Path $InstallDir 'YetiX-LED-Tool.ps1'
if ($exe) { $target = $exe; $arguments = '' }
else {
  $target = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$script`""
}

# Explorer cannot load shortcut icons from paths with non-ASCII characters (e.g. an umlaut in the
# Windows user name). In that case the icon is copied to ProgramData, which has a plain ASCII path.
$icon = Join-Path $InstallDir 'logo.ico'
if ($icon -match '[^\x00-\x7F]') {
  $iconDir = Join-Path $env:ProgramData 'YetiX-LED-Studio'
  New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
  Copy-Item -LiteralPath $icon -Destination (Join-Path $iconDir 'app.ico') -Force
  $icon = Join-Path $iconDir 'app.ico'
}

$links = @(Join-Path ([Environment]::GetFolderPath('Programs')) 'Yeti X LED Studio.lnk')
if (-not $NoDesktopShortcut) { $links += Join-Path ([Environment]::GetFolderPath('Desktop')) 'Yeti X LED Studio.lnk' }
foreach ($l in $links) {
  New-YxShortcut -LinkPath $l -Target $target -Arguments $arguments -WorkingDirectory $InstallDir -Icon $icon -Description 'Yeti X LED Studio - set every Yeti X LED freely'
  Write-Host "Shortcut: $l"
}
Write-Host 'Done. Start "Yeti X LED Studio" from the desktop or the Start menu (G HUB must be running).'
