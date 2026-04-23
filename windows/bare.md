# windows2025-bare

## Purpose
Clean Windows Server 2025 template for lab workloads that don't need
first-boot automation. Deploy-and-login base.

## OS + version
Windows Server 2025, Standard edition, Desktop Experience.
Activation key: Microsoft-published GVLK
`TVRH6-WHNXV-R9WG3-9XRFY-MY832`.

## Pre-installed software
- VMware Tools (installed from ESXi host ISO during build)
- All Windows Updates current as of build time (PSWindowsUpdate, two
  passes)
- Sentania Lab Root 2 CA in `Cert:\LocalMachine\Root`

## First-boot behavior
None. Sysprep completes with `unattend-bare.xml`, which re-seals the
local accounts and skips OOBE. The VM boots to the login screen.

## Lab assumptions
- Target cluster: `vcf-lab-mgmt-cl01`
- Target content library: `vcf-lab-mgmt-contentlibrary`
- vCenter: `vcf-lab-vcenter-mgmt.int.sentania.net`
- Requires `server2025-iso` content library item uploaded
- Requires VMware Tools ISO at
  `[] /vmimages/tools-isoimages/windows.iso` on the ESXi host
