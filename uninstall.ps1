# Removes Yeti X LED Studio (program files, settings, shortcuts). LED colours stay as they are.
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
param([string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'YetiX-LED-Tool'))

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like "*$InstallDir*YetiX-LED-Tool.ps1*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$paths = @(
  $InstallDir,
  (Join-Path $env:ProgramData 'YetiX-LED-Studio'),
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Yeti X LED Studio.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Yeti X LED Studio.lnk')
)
foreach ($p in $paths) {
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; Write-Host "Removed $p" }
}
Write-Host 'Yeti X LED Studio has been removed.'
