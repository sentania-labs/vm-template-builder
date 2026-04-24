# First-logon bootstrap. Runs from the Packer-attached CD (label PACKER)
# before any Packer provisioner. Installs VMware Tools, opens WinRM, and
# leaves breadcrumbs in C:\Windows\Temp so a failed run can be diagnosed
# from vSphere console even if Packer never connects.

" bootstrap-started" | Set-Content -Path C:\Windows\Temp\bootstrap-started.txt
$ErrorActionPreference = 'Continue'
$log = 'C:\Windows\Temp\bootstrap.log'
function Log($msg) {
    "$(Get-Date -Format o) $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

Log 'bootstrap start'

# WS2025 defaults new connections to Public, which blocks the standard
# WinRM firewall rule group. Force every profile to Private.
try {
    Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {
        Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
        Log "profile $($_.InterfaceAlias) -> Private"
    }
} catch {
    Log "network profile set failed: $_"
}

# Install VMware Tools from the attached tools ISO. Done here (not a
# Packer provisioner) so Tools is running before anyone needs WinRM.
$setup = Get-CimInstance -ClassName Win32_LogicalDisk |
    Where-Object { $_.DriveType -eq 5 } |
    ForEach-Object {
        $c = Join-Path $_.DeviceID 'setup64.exe'
        if (Test-Path $c) { $c }
    } | Select-Object -First 1

if (-not $setup) {
    $setup = Get-CimInstance -ClassName Win32_LogicalDisk |
        Where-Object { $_.DriveType -eq 5 } |
        ForEach-Object {
            $c = Join-Path $_.DeviceID 'setup.exe'
            if (Test-Path $c) { $c }
        } | Select-Object -First 1
}

if ($setup) {
    Log "vmtools setup: $setup"
    try {
        $proc = Start-Process -FilePath $setup `
            -ArgumentList '/S','/v','/qn REBOOT=ReallySuppress /l*v C:\Windows\Temp\vmtools-msi.log' `
            -Wait -PassThru
        Log "vmtools exit: $($proc.ExitCode)"
        "$(Get-Date -Format o) exit=$($proc.ExitCode) setup=$setup" |
            Out-File -FilePath 'C:\Windows\Temp\vmtools-attempted.txt' -Append -Encoding utf8
    } catch {
        Log "vmtools install threw: $_"
        "$(Get-Date -Format o) THROW $_" |
            Out-File -FilePath 'C:\Windows\Temp\vmtools-attempted.txt' -Append -Encoding utf8
    }
} else {
    Log 'vmtools setup not found on any CD'
    "$(Get-Date -Format o) NOT_FOUND" |
        Out-File -FilePath 'C:\Windows\Temp\vmtools-attempted.txt' -Append -Encoding utf8
}

# Enable PSRemoting with the network-profile check disabled — the
# interface may still be classifying at first logon.
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
    Log 'Enable-PSRemoting ok'
} catch {
    Log "Enable-PSRemoting failed: $_"
}

# Packer uses HTTP/Basic. Allow both on the service side.
try {
    & winrm set 'winrm/config/service' '@{AllowUnencrypted="true"}' | Out-Null
    & winrm set 'winrm/config/service/auth' '@{Basic="true"}' | Out-Null
    Log 'winrm service config ok'
} catch {
    Log "winrm service config failed: $_"
}

# Explicit firewall rule on 5985 scoped to all profiles, in case the
# built-in group rule stays profile-gated.
try {
    netsh advfirewall firewall delete rule name="Packer WinRM HTTP" 2>$null | Out-Null
    netsh advfirewall firewall add rule name="Packer WinRM HTTP" dir=in action=allow protocol=TCP localport=5985 profile=any | Out-Null
    netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes | Out-Null
    Log 'firewall ok'
} catch {
    Log "firewall failed: $_"
}

try {
    Set-Service -Name WinRM -StartupType Automatic
    Restart-Service -Name WinRM -Force
    Log 'winrm service restarted'
} catch {
    Log "winrm service restart failed: $_"
}

"$(Get-Date -Format o) bootstrap complete" |
    Out-File -FilePath 'C:\Windows\Temp\bootstrap-done.txt' -Append -Encoding utf8
Log 'bootstrap done'
