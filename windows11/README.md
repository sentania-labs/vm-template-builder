# windows11/ - Windows 11 Pro test-desktop template

Packer definition for `windows11-pro-bare`, published as an OVF to
`vcf-lab-mgmt-contentlibrary` on `vcf-lab-vcenter-mgmt.int.sentania.net`. It is
the base for the lab's Windows test desktop: a domain-joinable Windows 11 Pro VM
for running Windows apps the way a user would.

It runs the same chain as `windows/` (Server 2025) and reuses that folder's
scripts: unattended install, VMware Tools from the host ISO, lab Root CA, two
Windows Update passes, cleanup, sysprep. What differs:

- **Edition:** Windows 11 Pro (the minimum edition that joins a domain; matches the
  lab's laptops). KMS client key `W269N-WFGWX-YVC9B-4J6C9-T83GX`, activates against
  the lab KMS.
- **Media:** library item `win11-pro-26300-remastered`, built from Microsoft's
  multi-edition `Windows11_Client_x64_en-us_26300_9457.iso` (SHA-256
  `bd4307df32bc8af33b39ccecb1174aeb345386630f89a2b86c7a4e36b55ea650`) with
  `efisys_noprompt.bin` as the UEFI boot image (no "press any key" prompt). The ISO
  has no Enterprise edition.
- **TPM:** none at build time. A VM with a vTPM is encrypted and cannot be exported
  to OVF, so the answer file sets setup's LabConfig bypass keys (TPM, Secure Boot,
  RAM, CPU checks). Add a vTPM to each VM deployed from the template (the mgmt
  vCenter has a Native Key Provider).
- **Guest type:** `windows11_64Guest`, EFI with Secure Boot, 100 GB thin disk,
  2 vCPU / 4 GB at build time.
- **Build-only settings undone before sysprep** (`setup/85-client-prep.ps1`): UAC is
  re-enabled, Store auto-updates are allowed again, and per-user app packages that
  are not provisioned for all users are removed (they make client sysprep fail).
- **Sysprep runs from a scheduled task**, not over WinRM. Started directly, sysprep is
  a child of the WinRM shell; generalize deletes the NIC, the shell dies and Windows
  kills sysprep mid-generalize (what failed the first four builds on 2026-10-01). The
  `shutdown_command` creates and runs a SYSTEM task `packer-sysprep`, Packer waits for
  the power-off, and `sysprep/unattend-bare.xml` deletes the task in the specialize pass.
- **Never sleeps:** sleep and hibernate are off from first logon. Client Windows
  otherwise sleeps after 30 idle minutes, which a remote test desktop cannot afford.
- **Time zone:** Central.
- **Accounts:** local Administrator (disabled by default on client editions) and
  `labuser` in Administrators, lab default password.

First boot after deploy: no OOBE, boots to the login screen. Verified 2026-10-01 on a
VM deployed from the library item: setup completes, the `packer-sysprep` task is gone,
UAC is on, sleep is off. Activation needs TCP 1688 to the lab KMS (172.16.6.20) and a
KMS host the client can find (domain GPO, or `slmgr /skms`); there is no `_vlmcs` SRV
record.
