# Pre-sysprep hygiene: clear logs, temp, Windows Update download cache, trim
# the C: drive so the template OVF is as lean as possible.

$ErrorActionPreference = 'Continue'

Write-Host "Clearing event logs..."
Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
    Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } |
    ForEach-Object { try { wevtutil.exe cl $_.LogName } catch {} }

Write-Host "Stopping Windows Update service..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue

Write-Host "Removing SoftwareDistribution download cache..."
Remove-Item -Path 'C:\Windows\SoftwareDistribution\Download\*' -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Clearing user + system temp..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path 'C:\Windows\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue -Exclude 'sentania-lab-root-2.crt','unattend.xml'

Write-Host "Running DISM component cleanup..."
Start-Process -FilePath dism.exe -ArgumentList '/online','/Cleanup-Image','/StartComponentCleanup','/ResetBase' -Wait -NoNewWindow

Write-Host "Trimming C: ..."
Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue

Write-Host "Cleanup done."
