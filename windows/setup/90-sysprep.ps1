# Final step. Run sysprep /generalize /oobe /shutdown with the variant-specific
# unattend file (uploaded to C:\Windows\Temp\unattend.xml by a preceding file
# provisioner). Sysprep powers the VM off; Packer detects shutdown and proceeds
# to template conversion + content library import.

$ErrorActionPreference = 'Stop'

$unattend = 'C:\Windows\Temp\unattend.xml'
if (-not (Test-Path $unattend)) {
    throw "Sysprep unattend not found at $unattend"
}

$sysprep = Join-Path $env:SystemRoot 'System32\Sysprep\sysprep.exe'
$args = @('/generalize', '/oobe', '/shutdown', "/unattend:$unattend")

Write-Host "Invoking: $sysprep $($args -join ' ')"
Start-Process -FilePath $sysprep -ArgumentList $args -NoNewWindow

# Block until the host powers off. Packer's winrm session will drop when the
# VM shuts down and Packer will take over.
Start-Sleep -Seconds 900
