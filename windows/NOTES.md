# Windows Build Notes

## 2026-04-23 — CURRENT BLOCKER: Win2025 VM drops to EFI Boot Manager, installer never starts

**Symptom:** After Packer boots the VM, the EFI Boot Manager appears with "Boot normally" highlighted and the system stalls. The installer never launches. The boot menu shows entries for EFI Virtual disk, three EFI VMware Virtual IDE CDROM entries, EFI Network, and setup/reset/shutdown options — but nothing auto-boots from the CDROMs.

**Manual repro (2026-04-23):** Scott hand-created a Win2025 VM outside Packer — same EFI Boot Manager stall. Manually selected the CDROM from the boot menu and the ISO booted fine, installation started normally. This rules out the ISO as the problem and confirms the fault is in EFI boot order: firmware picks "EFI Virtual disk (0.0)" first, finds nothing bootable, drops to Boot Manager and waits instead of falling through to the next device.

**Root cause: EFI boot order puts empty virtual disk before CDROMs.**

**~~Ruled out:~~** ~~ISO not EFI-bootable~~ — confirmed bootable when manually selected.

**Remaining suspects / fix candidates:**

1. **Boot order in Packer/VMX config** — put CDROM ahead of the virtual disk. VMX options to try:
   - `bios.bootorder = "cdrom,hdd"` (legacy BIOS setting, may be honoured by EFI firmware in some ESXi versions)
   - `efi.bootorder` or `uefi.bootorder` VMX key — force CDROM first
   - Check what `vsphere-iso` exposes for boot order; may need `configuration_parameters` in the Packer HCL to inject VMX keys directly.
2. **Defer disk attachment until post-boot** — some Packer templates attach the boot disk only after the installer is running, so the EFI firmware sees only the CDROM at first power-on. Worth checking if `vsphere-iso` supports this.
3. **boot_command to navigate Boot Manager** — if boot order can't be forced, send keystrokes in `boot_command` to select the CDROM entry from the EFI Boot Manager menu before the timeout expires.

**Fix direction:**
- Start with boot order: add VMX `efi.bootorder` / `uefi.bootorder` override via Packer `configuration_parameters` to put CDROM first.
- If that doesn't work, investigate deferred disk attachment.
- `boot_command` workaround is a last resort — fragile and timing-dependent.

**Status:** Open. Blocking all Win2025 build progress.

**CI runs cancelled 2026-04-23:** Three in-progress/queued workflow runs (24835472648, 24836511704, 24836608259) cancelled manually — none would have progressed past this EFI boot stall, and the vmxnet3 issue would have caused a hang even if they had.

---

## 2026-04-23 — Win2025: vmxnet3 driver missing from install media

> **Note:** Blocked by EFI boot issue above — this won't be hit until the installer actually runs.

**Symptom:** Win2025 builds fail or hang at Packer's IP-wait step. The VM installs but never acquires an IP address.

**Root cause:** The Windows Server 2025 install media does not include the VMware vmxnet3 driver. The NIC has no driver during (and immediately after) unattended install, so DHCP never fires and Packer's connection step hangs indefinitely.

**Fix pattern:** Make the vmxnet3 driver available to the OS during initial install. Two approaches:
1. Slipstream the driver into boot.wim / install.wim before building the ISO.
2. Attach the driver via a floppy/ISO and add an autounattend DriverPaths entry pointing at it — the installer picks it up during setup.

**Reference:** https://github.com/sentania/windowsServer_ImageBuild — older repo, not in this repo's format, but demonstrates the driver-injection approach.

**Status:** Not yet fixed in this repo. Both windows2025-bare and windows2025-cbinit are affected.
