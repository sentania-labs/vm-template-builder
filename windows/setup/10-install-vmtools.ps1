# Install VMware Tools from the secondary CD that Packer attached
# ([] /vmimages/tools-isoimages/windows.iso on the ESXi host).
# Normally bootstrap.ps1 (first logon) has already installed Tools;
# this provisioner is a safety net for images where that didn't happen.

$ErrorActionPreference = 'Stop'

if (Get-Service -Name VMTools -ErrorAction SilentlyContinue) {
    Write-Host "VMware Tools already installed (service VMTools present) — skipping."
    return
}

$setup = Get-CimInstance -ClassName Win32_LogicalDisk |
    Where-Object { $_.DriveType -eq 5 } |
    ForEach-Object {
        $candidate = Join-Path $_.DeviceID 'setup64.exe'
        if (Test-Path $candidate) { $candidate }
    } | Select-Object -First 1

if (-not $setup) {
    # Fall back to setup.exe on 32-bit media or older ISOs.
    $setup = Get-CimInstance -ClassName Win32_LogicalDisk |
        Where-Object { $_.DriveType -eq 5 } |
        ForEach-Object {
            $candidate = Join-Path $_.DeviceID 'setup.exe'
            if (Test-Path $candidate) { $candidate }
        } | Select-Object -First 1
}

if (-not $setup) {
    throw "VMware Tools setup executable not found on any attached CD. Confirm the tools ISO is mounted."
}

Write-Host "Installing VMware Tools from $setup"
$proc = Start-Process -FilePath $setup -ArgumentList '/S','/v','/qn REBOOT=ReallySuppress' -Wait -PassThru
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "VMware Tools install exited with code $($proc.ExitCode)"
}
Write-Host "VMware Tools install exit code: $($proc.ExitCode)"
