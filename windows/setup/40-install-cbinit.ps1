# Download and install the latest stable Cloudbase-Init.
# Only runs on the cloudbase-init variant (gated via `only` in windows.pkr.hcl).

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url = 'https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi'
$dst = 'C:\Windows\Temp\CloudbaseInitSetup.msi'

Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing

$hash = (Get-FileHash -Algorithm SHA256 $dst).Hash
Write-Host "Downloaded MSI SHA256: $hash"

# Install quietly. LOGGINGSERIALPORTNAME= disables the serial-port logging default
# which spams COM1 on headless VMs.
Write-Host "Installing Cloudbase-Init..."
$proc = Start-Process -FilePath msiexec.exe `
    -ArgumentList @('/i', $dst, '/qn', '/norestart', 'LOGGINGSERIALPORTNAME=""') `
    -Wait -PassThru
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "Cloudbase-Init install exited with code $($proc.ExitCode)"
}
Write-Host "Cloudbase-Init install exit code: $($proc.ExitCode)"

# Disable the service so cloudbase-init only runs when sysprep re-arms it on
# first boot from the template (via the provided Unattend.xml). Leaving it on
# means it fires during build and burns its one-shot config.
Stop-Service -Name cloudbase-init -ErrorAction SilentlyContinue
Set-Service -Name cloudbase-init -StartupType Manual
