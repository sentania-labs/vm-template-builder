# windows/: Windows Server 2022 and 2025 templates

Packer definitions for Server 2022 and Server 2025 templates published to
the `vcf-lab-mgmt-contentlibrary` on `vcf-lab-vcenter-mgmt.int.sentania.net`.
The two sources share one build block, one provisioner chain and the same
hardware; they differ only where the OS media forces it (see the table
below). Keep them in lockstep.

## Variants

| Source | Published name | First-boot | Purpose |
|---|---|---|---|
| `vsphere-iso.windows2025-bare` | `windows2025-bare` | None | Clean base image. See [bare.md](bare.md). |
| `vsphere-iso.windows2022-bare` | `windows2022-bare` | None | Clean base image. See [bare-2022.md](bare-2022.md). |

## Per-version differences

| | Server 2025 | Server 2022 |
|---|---|---|
| Edition (final) | Standard, Desktop Experience | Standard, Desktop Experience |
| Media | `server2025-remastered` content library item | `server2022-remastered` content library item: Microsoft **evaluation** ISO (`SERVER_EVAL_x64FRE_en-us.iso`) remastered with `efisys_noprompt.bin` |
| Answer file | `autounattend/autounattend.xml` | `autounattend/autounattend-2022.xml` (published on the CD as `autounattend.xml`) |
| Image selected | `/IMAGE/NAME` = `Windows Server 2025 SERVERSTANDARD` | `/IMAGE/NAME` = `Windows Server 2022 SERVERSTANDARD` (installs `ServerStandardEval`) |
| GVLK | `TVRH6-WHNXV-R9WG3-9XRFY-MY832`, baked into the autounattend | `VDYBN-27WPP-V4HQT-9VMD4-VMK7H`, applied after install by `setup/15-set-edition.ps1` (`DISM /Set-Edition:ServerStandard`); no key in the autounattend |
| `guest_os_type` | `windows2019srv_64Guest` | `windows2019srvNext_64Guest` |

## Common properties

- **Edition:** Windows Server **Standard**, Desktop Experience (both versions).
- **Firmware:** UEFI with Secure Boot (`efi-secure`).
- **Disk:** 90 GB thin-provisioned VMDK, `pvscsi` controller.
- **NIC:** `vmxnet3` on `vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt`.
- **Sizing at build time:** 2 vCPU, 4 GB RAM. Resize downstream as needed.
- **ISO:** remastered (no "press any key" prompt) content library item per
  version; see the table above.
- **VMware Tools:** installed during build from the ESXi host-provided
  `[] /vmimages/tools-isoimages/windows.iso`; no separate upload.
- **CA trust:** `files/sentania Lab Root 2.crt` imported into
  `Cert:\LocalMachine\Root`.
- **Windows Updates:** latest cumulative + SSU applied during build via
  `PSWindowsUpdate` (two passes with reboots).
- **Accounts (lab standard, per `CLAUDE.md`):**
  - Local Administrator: password `VMware123!VMware123!`
  - `labuser` (Administrators group): password `VMware123!VMware123!`
- **Activation:** Microsoft-published Standard GVLK per version (table
  above). Both templates are non-eval Standard and expect the lab KMS;
  unactivated without one. Check with `slmgr /dlv`.

## Build flow

1. Packer boots the VM with the OS ISO + Tools ISO mounted.
2. `autounattend/autounattend.xml` drives unattended install, creates the
   accounts, and enables WinRM in the OOBE FirstLogonCommands.
3. Provisioners run (see `windows.pkr.hcl` for the ordered chain): install
   VMware Tools → reboot → (2022 only) convert evaluation to Standard
   with DISM → reboot → verify edition → import CA → apply updates → reboot → apply
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
- `server2025-remastered` and `server2022-remastered` content library
  items exist in `vcf-lab-mgmt-contentlibrary` before the build runs.
- ESXi host exposes the standard VMware Tools ISO at
  `/vmimages/tools-isoimages/windows.iso`.

## CI

Built by the `windows-build` job in
`.github/workflows/packer-build.yml`. The job runs after the Ubuntu job
completes (to avoid content-library OVF-import races). It runs
`packer build .` in `windows/`, so every source in the build block (2025
and 2022) is built one after the other (`-parallel-builds=1`).
