# Windows Build Notes

## 2026-04-23 — CURRENT BLOCKER: Win2025 VM drops to EFI Boot Manager, installer never starts

**Symptom:** After Packer boots the VM, the EFI Boot Manager appears with "Boot normally" highlighted and the system stalls. The installer never launches. The boot menu shows entries for EFI Virtual disk, three EFI VMware Virtual IDE CDROM entries, EFI Network, and setup/reset/shutdown options — but nothing auto-boots from the CDROMs.

**Likely causes to investigate:**

1. **ISO not EFI-bootable as attached** — Win2025 ISO must expose `efi/boot/bootx64.efi` to the firmware. If the content library item or the vsphere-iso CD attachment strips the EFI boot partition, the firmware finds no bootable image on the CDROMs and falls back to the Boot Manager.
2. **Boot order: virtual disk before CDROMs** — If the VMX/Packer config puts the (empty) virtual disk first in EFI boot order, firmware tries it, finds nothing, and lands in the Boot Manager rather than falling through to the CDROM.
3. **Packer boot_command / boot_wait mismatch** — The config may assume an auto-boot that isn't happening. May need an explicit keystroke in boot_command to select the CDROM entry from the EFI Boot Manager menu.
4. **"Press any key to boot from CD" prompt** — Win2025 EFI media shows this prompt with a short timeout. If boot_wait is too long or boot_command doesn't send a key during the window, the prompt expires and the system drops to the Boot Manager.

**Fix direction:**
- Confirm `firmware = "efi"` is set and that boot order has CDROMs ahead of the virtual disk in Packer/VMX config.
- Verify the ISO item in the content library is a standard Win2025 ISO with an intact EFI boot partition (check for `efi/boot/bootx64.efi`).
- Revisit `boot_wait` and `boot_command` — Win2025 may need a key sent during the "Press any key" window immediately after BIOS/EFI hands off to the CDROM.

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
