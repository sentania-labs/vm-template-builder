# Linux family build notes

## 2026-10-07: linux/ family added (rhel8, rhel9, rhel10, rocky9, centos-stream9, alpine324)

Asked for by Scott ("add a workstream to build rockery, centos, alpine, and
the various RHEL builds to the packer pipeline"). Delivered on branch
`linux-family-templates`; validated with Packer 1.11.2 (vsphere plugin 2.5.0)
and pykickstart 3.78, not built.

Decisions:

- **New `linux/` directory, not more sources in `ubuntu/`.** Different
  installers (Anaconda, setup-alpine vs Subiquity), different package
  managers and provisioners. Only the account contract is shared, and that is
  copied (key and hash) from `ubuntu/http/user-data`.
- **Answer files on a CD (`cd_content`), not Packer's HTTP server.** CI runs
  in the ARC runner pool; a build VM on the mgmt VM network cannot reach the
  runner pod's ephemeral HTTP port. Ubuntu already uses a cidata CD for the
  same reason. EL uses the `OEMDRV` label with an explicit
  `inst.ks=hd:LABEL=OEMDRV:/ks.cfg`; Anaconda also auto-loads `ks.cfg` from an
  `OEMDRV` volume, which covers a missed boot keystroke.
- **UEFI everywhere, no Secure Boot.** All six ISOs boot UEFI and accept
  their parameters unattended. Secure Boot would add nothing to a bare
  template and complicates third-party kernel modules later.
- **pvscsi everywhere, including Alpine.** Verified for Alpine 3.24:
  `CONFIG_VMWARE_PVSCSI=m` in `linux-lts` and mkinitfs' default `scsi` feature
  pulls in `kernel/drivers/scsi/*`. LSI SAS is the documented fallback.
- **Hardware version not pinned**, same as `ubuntu/`.
- **Three kickstarts (el8, el9, el10) with identical bodies today.** Every
  command used validates strictly (deprecations fatal) against pykickstart's
  RHEL8, RHEL9 and RHEL10 handlers, so there was no network or package syntax
  difference to encode. Separate files keep an EL8- or EL10-only change from
  forcing a retest of the three EL9 sources. Rocky 9, CentOS Stream 9 and
  RHEL 9 share `el9.ks`.
- **DVD ISOs for Rocky and CentOS Stream**, not boot/minimal: the install is
  offline from the DVD (open-vm-tools is in AppStream), same path as RHEL.
- **No cloud-init.** Ubuntu's is present but its VMware datasource is off, so
  nothing downstream depends on it; RHEL's default config disables SSH
  password login.
- **Root locked, as on Ubuntu.** `docs/standards/secrets-policy.md` says Linux
  root carries the lab default password for console recovery, but `ubuntu24`
  (the contract being mirrored) locks root. Followed Ubuntu; open question
  below.
- **firewalld left on with SSH only** (EL default). Ubuntu ships with ufw off;
  role bootstraps written for Ubuntu need to open ports on EL.
- **No RHEL registration at build time.** See `rhel.md`.
- **CI: one matrix leg per source** (`fail-fast: false`, `max-parallel: 1`)
  after the Windows 11 job; never on pull requests. A missing ISO fails only
  its own leg. The manual-run `only` input selects `linux-all` or one source
  and skips Ubuntu and Windows.
- **ISO item names are variables** (`iso_items`), with the windows11-style
  datastore override (`iso_datastore_paths`) for the NFS mount problem.

Open questions:

- **labuser password.** Copied Ubuntu's hash, which is `VMware123!`. The
  secrets policy lists `VMware123!VMware123!` for labuser (Windows uses that).
  Ubuntu and these templates disagree with the policy; one of them should
  change.
- **Unproven on hardware:** the GRUB keystroke sequence on each EL ISO, the
  Alpine boot timing and `setup-alpine` answer coverage on 3.24, and whether
  `rhel10_64Guest` / `other6xLinux64Guest` / `centos9_64Guest` are accepted by
  the mgmt vCenter (all expected on vSphere 9).
- **RHEL 10 and EVC:** RHEL 10 requires x86-64-v3. Confirm the mgmt cluster's
  EVC mode (if any) exposes AVX2 before the first `rhel10` build.
- **Install RAM:** 2 GB matches Ubuntu and meets the RHEL text-install
  minimum; raise `mem_size` if Anaconda runs out of memory on the DVD install.
