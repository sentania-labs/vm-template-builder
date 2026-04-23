# windows2025-cbinit

## Purpose
Windows Server 2025 template for VKS guest customization via VCF
Automation 9 All-apps. Cloudbase-Init applies hostname, networking,
user password, and SSH keys from the VMware guestinfo datasource on
first boot.

## OS + version
Windows Server 2025, Standard edition, Desktop Experience.
Activation key: Microsoft-published GVLK
`TVRH6-WHNXV-R9WG3-9XRFY-MY832`.

## Pre-installed software
- VMware Tools (installed from ESXi host ISO during build)
- All Windows Updates current as of build time (PSWindowsUpdate, two
  passes)
- Sentania Lab Root 2 CA in `Cert:\LocalMachine\Root`
- Cloudbase-Init (latest stable x64 MSI from `cloudbase.it`, installed
  during build), configured with the `VMwareGuestInfoService` metadata
  source

## First-boot behavior
Sysprep runs with `unattend-cbinit.xml`. During the specialize pass,
`cloudbase-init-unattend.exe` runs against
`cloudbase-init-unattend.conf` and applies VCF-supplied guest
customization data. The `cloudbase-init` service is set to `Manual`;
it fires once via sysprep and does not persist on subsequent reboots.

## Lab assumptions
- Target cluster: `vcf-lab-mgmt-cl01`
- Target content library: `vcf-lab-mgmt-contentlibrary`
- vCenter: `vcf-lab-vcenter-mgmt.int.sentania.net`
- VCF Automation 9 (or equivalent consumer) delivers guest
  customization data via the VMware guestinfo interface
- Requires `server2025-iso` content library item uploaded
- Requires VMware Tools ISO at
  `[] /vmimages/tools-isoimages/windows.iso` on the ESXi host
- Requires the self-hosted Packer runner to reach
  `https://cloudbase.it/downloads/` at build time
