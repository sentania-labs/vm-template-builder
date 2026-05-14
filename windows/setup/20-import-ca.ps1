# Import the Sentania Lab Root 2 CA cert into the LocalMachine Trusted Root store.
# The cert is uploaded to C:\Windows\Temp\sentania-lab-root-2.crt by a preceding
# file provisioner.

$ErrorActionPreference = 'Stop'

$certPath = 'C:\Windows\Temp\sentania-lab-root-2.crt'
if (-not (Test-Path $certPath)) {
    throw "CA cert not found at $certPath"
}

Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

$installed = Get-ChildItem Cert:\LocalMachine\Root |
    Where-Object { $_.Subject -match 'sentania Lab Root 2' }
if (-not $installed) {
    throw "CA cert import failed - not found in Cert:\LocalMachine\Root"
}
Write-Host "Installed CA: $($installed.Subject)"
