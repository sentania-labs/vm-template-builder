# Windows Build Notes

## 2026-04-23 — RESOLVED 2026-04-23: "Press any key to boot from CD or DVD..." prompt times out, drops to Boot Manager

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

**Status:** RESOLVED. windows2025-bare retargeted to content library item server2025-remastered (remastered ISO with efisys_noprompt.bin, no press-any-key prompt). Commit: b596dc8.

**windows2025-cbinit variant is parked** — not being actively built. Source block retained in windows.pkr.hcl but cbinit is out of scope for the current build sprint.

**CI runs cancelled 2026-04-23:** Three in-progress/queued workflow runs (24835472648, 24836511704, 24836608259) cancelled manually — none would have progressed past this stall.

**Remaster produced 2026-04-23:** `sentania-lab-toolkit/scripts/remaster-windows-iso.ps1` (commit d72d773) ran against the source eval ISO. `efisys_noprompt.bin` was present in the source — no injection needed. Output: `/home/scott/pka/tmp/server2025-remastered.iso` (5.6 GB). Scott will verify and upload to content library. Once he provides the content library item name, Job 2 (retarget Packer to the remastered ISO) will be dispatched.

---

## 2026-04-23 — Win2025: vmxnet3 driver missing from install media

**Symptom:** Win2025 builds fail or hang at Packer's IP-wait step. The VM installs but never acquires an IP address.

**Root cause:** The Windows Server 2025 install media does not include the VMware vmxnet3 driver. The NIC has no driver during (and immediately after) unattended install, so DHCP never fires and Packer's connection step hangs indefinitely.

**Fix pattern:** Make the vmxnet3 driver available to the OS during initial install. Two approaches:
1. Slipstream the driver into boot.wim / install.wim before building the ISO.
2. Attach the driver via a floppy/ISO and add an autounattend DriverPaths entry pointing at it — the installer picks it up during setup.

**Reference:** https://github.com/sentania/windowsServer_ImageBuild — older repo, not in this repo's format, but demonstrates the driver-injection approach.

**Status:** Not yet fixed in this repo. Both windows2025-bare and windows2025-cbinit are affected.

---

## 2026-04-23 — Win2025-bare: WinRM timeout after install (Tools running but WinRM unreachable)

**Symptom:** Run 24848303553 (commit eb5e6b9) reached Windows install successfully on the remastered ISO. Packer received guest IP 172.27.8.233 (so VMware Tools was running enough to report it), then hung 60 minutes on "Waiting for WinRM to become available" before failing with `Timeout waiting for WinRM`. The cbinit build failed separately with `timeout waiting for IP address` because its source was still pointed at the non-remastered ISO (parked variant).

**Root-cause diagnosis:** FirstLogonCommands in the prior autounattend used `winrm quickconfig -q`, which on Windows Server 2025 refuses to create an HTTP listener when the active network profile is Public (the default for a freshly-provisioned unclassified NIC). The three follow-up `winrm set` / firewall commands then have nothing to bind to. The symptom at the Packer orchestrator is that Tools reports an IP (vmxnet3 driver installed, DHCP up) but port 5985 never answers.

**Fix applied (this commit):**

- New `windows/autounattend/bootstrap.ps1` — single first-logon script that:
  - Forces every `Get-NetConnectionProfile` entry to `Private` before any WinRM step.
  - Installs VMware Tools from the attached tools CD (`/S /v/qn` + MSI log at `C:\Windows\Temp\vmtools-msi.log`). Breadcrumbs: `C:\Windows\Temp\bootstrap.log`, `C:\Windows\Temp\vmtools-attempted.txt`, `C:\Windows\Temp\bootstrap-done.txt`.
  - Runs `Enable-PSRemoting -Force -SkipNetworkProfileCheck` (tolerates an interface still classifying).
  - Sets service `AllowUnencrypted=true` + `Basic=true`, adds explicit `profile=any` firewall rule on TCP 5985, and restarts the WinRM service.
- `windows/autounattend/autounattend.xml` — FirstLogonCommands collapsed from six brittle commands to three: relax execution policy, copy `bootstrap.ps1` off the PACKER CD to `C:\Windows\Temp\`, run it.
- `windows/windows.pkr.hcl` — switched `cd_content` → `cd_files` so `bootstrap.ps1` ships on the Packer CD alongside `autounattend.xml`. Dropped `source.vsphere-iso.windows2025-cbinit` from `build.sources` (parked variant was still pointing at the original non-remastered ISO and poisoning CI).
- `windows/setup/10-install-vmtools.ps1` — short-circuits if the `VMTools` service already exists, since bootstrap normally handles it. Kept as a safety net.

**What to watch for in the next run:**

- `==> vsphere-iso.windows2025-bare: IP address: <x>` should appear within ~15 min of VM power-on (same as last run).
- `==> vsphere-iso.windows2025-bare: Waiting for WinRM to become available...` should clear within a minute or two instead of timing out.
- If WinRM still times out, the diagnostic signal is on the VM's C: drive: `C:\Windows\Temp\bootstrap.log`, `vmtools-attempted.txt`, `vmtools-msi.log`, `bootstrap-done.txt`. Mount the VM's disk or console in and pull those before destroying.
- cbinit is now excluded from the build; CI should no longer report the cbinit IP-timeout failure.
