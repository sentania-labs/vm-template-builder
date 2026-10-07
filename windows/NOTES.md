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

**Remaster produced 2026-04-23:** A remaster utility (run out of band, not in this repo) produced a 5.6 GB ISO with `efisys_noprompt.bin` already present in the source — no injection needed. Output was uploaded to the content library as `server2025-remastered`, which is now the source for `windows2025-bare`.

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

---

## 2026-10-07: windows2022-bare added; evaluation media converted to Standard at build time

**Context:** Server 2022 Standard retail/volume media is not on hand, so `windows2022-bare` installs from the Microsoft evaluation ISO (`SERVER_EVAL_x64FRE_en-us.iso`), remastered with `efisys_noprompt.bin` the same way as the 2025 media (see the 2026-04-23 entry) and staged as content library item `server2022-remastered`.

**Why the 2022 autounattend carries no product key:** evaluation media installs the `ServerStandardEval` edition, and its setup rejects a Standard GVLK in `UserData/ProductKey`. The 2025 answer file keeps its GVLK; the 2022 answer file (`autounattend/autounattend-2022.xml`) is otherwise a copy with only the image name changed to `Windows Server 2022 SERVERSTANDARD` (Desktop Experience).

**Why the DISM step:** an eval install expires and will not activate against the lab KMS. `setup/15-set-edition.ps1` converts it in place with `DISM /online /Set-Edition:ServerStandard /ProductKey:VDYBN-27WPP-V4HQT-9VMD4-VMK7H /AcceptEula /NoRestart` (Microsoft's published KMS client key for Server 2022 Standard). Exit code 3010 (reboot required) is treated as success.

**Sequencing (windows.pkr.hcl, `only = ["vsphere-iso.windows2022-bare"]`):** after `10-install-vmtools.ps1` and its reboot, so no reboot is pending when DISM runs; then a `windows-restart` with a 60 minute timeout (the edition change finishes during boot and can take several restarts); then the same script with `EDITION_VERIFY_ONLY=1`, which fails the build if DISM does not report `ServerStandard`. All of this happens before the Windows Update passes, so updates land on the final edition. The script runs as an elevated scheduled task (`elevated_user`, like the update step) to avoid remote-session restrictions on DISM servicing. It is idempotent: if the edition is already `ServerStandard` it does nothing.

**vmxnet3 / pvscsi:** Server 2022 media lacks both drivers, same as 2025. The same mechanism applies unchanged: pvscsi from the Tools ISO via WindowsPE `DriverPaths` (`E:\Program Files\VMware\VMware Tools\Drivers\pvscsi\Win8\amd64`), vmxnet3 via the VMware Tools install at first logon.

**Not yet proven:** no build has run. Watch the DISM step duration and the post-change reboot in the first CI run.

## 2026-10-07 (later) - windows2025-bare was Evaluation edition too

A deployed windows2025-bare VM (mssqldemo3, lab-admin check 2:50 PM) reads
`ServerStandardEval`, "Windows Server 2025 Standard Evaluation", no KMS, about 40
days of evaluation left. The 2025 media is the evaluation ISO as well; the
Standard GVLK in autounattend.xml installs on it without complaint but leaves the
edition as Eval. The three edition steps added for 2022 (15-set-edition.ps1,
restart, verify) now run for both sources, with the key chosen per source
(`source.name`). Scott 2026-10-07: "yes rebuild the iso and trigger an updated
image build." Deployed 2025 VMs were converted in place by lab-admin with the same
DISM command.
