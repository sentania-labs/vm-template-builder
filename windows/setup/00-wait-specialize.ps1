# Barrier script. By the time Packer is running provisioners WinRM is up,
# but specialize/oobe service work may still be settling. Wait briefly for
# the Windows Installer service and DCOM to be available so subsequent
# msiexec calls don't race.

$ErrorActionPreference = 'Stop'

$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
    $msi = Get-Service -Name msiserver -ErrorAction SilentlyContinue
    $wu  = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($msi -and $wu) {
        try { Start-Service msiserver -ErrorAction SilentlyContinue } catch {}
        try { Start-Service wuauserv -ErrorAction SilentlyContinue } catch {}
        break
    }
    Start-Sleep -Seconds 5
}

Write-Host "Specialize barrier cleared."
