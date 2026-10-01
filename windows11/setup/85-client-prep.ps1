# Windows 11 client only: get the image ready for sysprep and make it behave
# like a normal desktop once deployed.
$ErrorActionPreference = 'Continue'

# Sysprep /generalize fails on a client when an app package is installed for a
# user but not provisioned for all users (typically a Store app that updated
# itself for labuser during the build). Remove those per-user copies.
# Match on the app name: a provisioned package is a neutral bundle
# (Name_Version_neutral_~_Publisher) while the installed copy is
# architecture-specific (Name_Version_x64__Publisher), so full names never match
# and comparing them would remove inbox apps such as Calculator and Photos.
$provisioned = (Get-AppxProvisionedPackage -Online).DisplayName
Get-AppxPackage -AllUsers | Where-Object {
    $_.NonRemovable -eq $false -and
    $_.SignatureKind -eq 'Store' -and
    $_.IsFramework -eq $false -and
    ($provisioned -notcontains $_.Name)
} | ForEach-Object {
    Write-Host "Removing per-user package that would block sysprep: $($_.PackageFullName)"
    try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop } catch { Write-Host "  could not remove: $_" }
}

# The build turned UAC off (autounattend offlineServicing) so Packer's WinRM
# session runs elevated. A test desktop must behave like users' desktops, so
# switch it back on; it takes effect on the post-sysprep boot.
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -Value 1 -Type DWord

# Build-only policy: let the Store update apps again on deployed VMs.
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name AutoDownload -ErrorAction SilentlyContinue

Write-Host "Client prep done."
exit 0
