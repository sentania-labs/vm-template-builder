# Windows Build Notes

## 2026-04-23 — CURRENT BLOCKER: "Press any key to boot from CD or DVD..." prompt times out, drops to Boot Manager

**Symptom:** After Packer boots the VM, the EFI firmware tries the CDROM first (boot order is fine) and displays the standard Windows "Press any key to boot from CD or DVD..." prompt. No keypress is sent in time → prompt times out → EFI drops to the Boot Manager with "Boot normally" highlighted. Installer never launches.

When Scott manually selected the CDROM from the Boot Manager the second time around, the prompt didn't appear again — the ISO auto-booted because the EFI boot path was now being invoked directly, skipping the initial `efisys.bin` prompt.

**Root cause: the Win2025 ISO uses `efisys.bin` (prompt version) as its EFI boot image.** Scott's ISO rehash preserved this prompt-version boot image. Packer's `boot_command` isn't firing a keypress during the prompt window, so the timeout expires every time.

**~~Prior theory (ruled out):~~** ~~EFI boot order puts empty virtual disk before CDROMs~~ — CDROM is tried first; boot order is not the issue.

**Fix candidates, in priority order:**

1. **Rebuild the ISO with `efisys_noprompt.bin`** *(recommended — eliminates the race entirely)*
   Windows ADK ships both variants:
   - `efisys.bin` — "Press any key..." prompt (what the current ISO uses)
   - `efisys_noprompt.bin` — auto-boots without prompt

   Rebuild with `oscdimg`:
   ```
   oscdimg -m -o -u2 -udfver102 \
     -bootdata:2#p0,e,b<path>\etfsboot.com#pEF,e,b<path>\efi\microsoft\boot\efisys_noprompt.bin \
     <source-dir> <output.iso>
   ```
   Upload the rebuilt ISO to the content library item `server2025-iso`. No Packer config changes needed.

2. **Fix `boot_command` to send a keypress before the prompt times out** *(fragile — timing-sensitive)*
   Set a short `boot_wait` so Packer connects to the VM console quickly, then open `boot_command` with something like `["<enter>"]` or `["<spacebar>"]` to fire during the prompt window. Prompt timeout is typically 5–10 seconds; `boot_wait` needs to be short enough to beat it. Sensitive to host load.

3. **Shorten VMX boot delay** *(minor assist only)*
   Reduce any VMX-level POST/boot delay so the prompt appears sooner, giving option 2 more headroom. Not a fix on its own.

**Status:** Open. Blocking all Win2025 build progress.

**CI runs cancelled 2026-04-23:** Three in-progress/queued workflow runs (24835472648, 24836511704, 24836608259) cancelled manually — none would have progressed past this stall.

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
