# Install all pending Windows updates via PSWindowsUpdate. Safe to re-run;
# the provisioner chain calls this twice (with a windows-restart between)
# to pick up dependency cascades.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ensure NuGet provider + PSGallery are trusted so Install-Module runs unattended.
Get-PackageProvider -Name NuGet -Force -ForceBootstrap | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers
}
Import-Module PSWindowsUpdate -Force

Write-Host "Scanning for Microsoft updates..."
$updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction SilentlyContinue
if (-not $updates) {
    Write-Host "No updates pending."
    exit 0
}

Write-Host ("Installing {0} updates..." -f $updates.Count)
Install-WindowsUpdate -AcceptAll -IgnoreReboot -MicrosoftUpdate -Verbose | Out-Null

# Never fail the provisioner - a reboot loop or transient KB miss is expected
# between passes. The next windows-restart + second run picks up the rest.
exit 0
