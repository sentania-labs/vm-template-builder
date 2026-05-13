# windows/ — Windows Server 2025 templates

Packer definition for a Server 2025 template published to the
`vcf-lab-mgmt-contentlibrary` on `vcf-lab-vcenter-mgmt.int.sentania.net`.

## Variant

| Source | Published name | First-boot | Purpose |
|---|---|---|---|
| `vsphere-iso.windows2025-bare` | `windows2025-bare` | None | Clean base image. See [bare.md](bare.md). |

## Common properties

- **Edition:** Windows Server 2025 **Standard**, Desktop Experience.
- **Firmware:** UEFI with Secure Boot (`efi-secure`).
- **Disk:** 90 GB thin-provisioned VMDK, `pvscsi` controller.
- **NIC:** `vmxnet3` on `vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt`.
- **Sizing at build time:** 2 vCPU, 4 GB RAM. Resize downstream as needed.
- **ISO:** `server2025-iso` content library item (Standard ISO).
- **VMware Tools:** installed during build from the ESXi host-provided
  `[] /vmimages/tools-isoimages/windows.iso` — no separate upload.
- **CA trust:** `files/sentania Lab Root 2.crt` imported into
  `Cert:\LocalMachine\Root`.
- **Windows Updates:** latest cumulative + SSU applied during build via
  `PSWindowsUpdate` (two passes with reboots).
- **Accounts (lab standard, per `CLAUDE.md`):**
  - Local Administrator — password `VMware123!VMware123!`
  - `labuser` (Administrators group) — password `VMware123!VMware123!`
- **Activation:** GVLK baked in (Standard
  `TVRH6-WHNXV-R9WG3-9XRFY-MY832`). Expects a KMS; unactivated without one.
  Check with `slmgr /dlv`.

## Build flow

1. Packer boots the VM with the OS ISO + Tools ISO mounted.
2. `autounattend/autounattend.xml` drives unattended install, creates the
   accounts, and enables WinRM in the OOBE FirstLogonCommands.
3. Provisioners run (see `windows.pkr.hcl` for the ordered chain): install
   VMware Tools → reboot → import CA → apply updates → reboot → apply
   updates → reboot → (cbinit only) install + configure Cloudbase-Init →
   upload variant sysprep unattend → cleanup → sysprep `/generalize /oobe
   /shutdown`.
4. Packer converts the powered-off VM to a template and publishes an OVF
   to the content library.

## Lab assumptions

- vCenter: `vcf-lab-vcenter-mgmt.int.sentania.net`
- Datacenter / cluster / datastore / network defaults match Ubuntu builds
  (`vcf-lab-mgmt-dc01` / `vcf-lab-mgmt-cl01` / `vcf-lab-mgmt-cl01-vsan` /
  `vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt`).
- `server2025-iso` content library item exists in
  `vcf-lab-mgmt-contentlibrary` before the build runs.
- ESXi host exposes the standard VMware Tools ISO at
  `/vmimages/tools-isoimages/windows.iso`.

## CI

Built by the `windows-build` job in
`.github/workflows/packer-build.yml`. The job runs after the Ubuntu job
completes (to avoid content-library OVF-import races).
