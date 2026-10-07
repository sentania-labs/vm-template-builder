# linux/ - RHEL, Rocky, CentOS Stream and Alpine templates

Packer definitions for the lab's non-Ubuntu Linux templates. Each source is
published as an OVF to `vcf-lab-mgmt-contentlibrary` on
`vcf-lab-vcenter-mgmt.int.sentania.net`, under a library item with the source's
name. They give a deployer the same thing `ubuntu24` does: a bare VM that comes
up on DHCP with `labuser` reachable over SSH, ready for a role bootstrap script.

Ubuntu stays in `ubuntu/`. It installs with Subiquity autoinstall and
provisions with apt; these distros install with Anaconda kickstart (or
`setup-alpine`) and share nothing with it but the account contract, so they
are a family of their own rather than more sources in `ubuntu/`.

## Templates

| Source / library item | Distro | Version | ISO library item | Firmware | Controller | Answer file | Status |
|---|---|---|---|---|---|---|---|
| `rhel10` | Red Hat Enterprise Linux | 10.2 | `rhel-10.2-x86_64-dvd` | UEFI | pvscsi | `ks/el10.ks` | validated; ISO upload in progress |
| `rhel9` | Red Hat Enterprise Linux | 9.8 | `rhel-9.8-x86_64-dvd` | UEFI | pvscsi | `ks/el9.ks` | validated; ISO upload in progress |
| `rhel8` | Red Hat Enterprise Linux | 8.10 | `rhel-8.10-x86_64-dvd` | UEFI | pvscsi | `ks/el8.ks` | validated, ISO not staged |
| `rocky9` | Rocky Linux | 9.8 | `Rocky-9.8-x86_64-dvd` | UEFI | pvscsi | `ks/el9.ks` | validated, ISO not staged |
| `centos-stream9` | CentOS Stream | 9 (20261006.0 compose) | `CentOS-Stream-9-20261006.0-x86_64-dvd1` | UEFI | pvscsi | `ks/el9.ks` | validated, ISO not staged |
| `alpine324` | Alpine Linux | 3.24.2 (standard) | `alpine-standard-3.24.2-x86_64` | UEFI | pvscsi | `alpine/answers` + `alpine/bootstrap.sh` | validated, ISO not staged |

"Validated" means `packer validate` and `ksvalidator` (strict, per RHEL
release) pass. No source has been built yet; each row moves to "built" with a
date once a CI build has published the item and a VM deployed from it came up
on DHCP with `labuser` reachable over SSH.

Per-source notes: `rhel.md` (no registration at build time, how to register
after deploy), `alpine.md` (answer flow, what is and is not unattended).
Decisions and open questions: `NOTES.md`.

## What every template contains

Same contract as `ubuntu24` (accounts copied from `ubuntu/http/user-data`):

- `labuser`, lab default password (same SHA-512 hash as Ubuntu), the lab RSA
  public key (`rsa-key-20250129`) in `~/.ssh/authorized_keys`, passwordless
  sudo (`/etc/sudoers.d/labuser`), member of `wheel`.
- root locked (no password), as on Ubuntu.
- open-vm-tools running, so vCenter sees the IP and the guest can be shut
  down cleanly. Alpine also gets the guestinfo, deploypkg, timesync and
  vmbackup plugins (separate packages there).
- sshd enabled, password and key login.
- DHCP on the first NIC at every boot. Hostname is `localhost` (Alpine's
  `/etc/hosts` line is reset to match); the deploy
  script sets the real name and address.
- IPv6 off (kernel `ipv6.disable=1` on EL, sysctl on Alpine), as on Ubuntu.
- The lab Root CA (`files/sentania Lab Root 2.crt`) in the system trust store.
- No cloud-init. Ubuntu carries it without the VMware datasource enabled, so
  nothing downstream uses it, and RHEL's stock cloud-init config turns SSH
  password login off. Add it per role if guestinfo customization is ever
  wanted.
- Generalized before conversion: SSH host keys removed (regenerated at first
  boot), machine-id emptied (EL), package caches and logs cleared.

EL specifics: `@^minimal-environment` plus `open-vm-tools`, LVM root without a
separate `/home`, SELinux enforcing, firewalld on with only SSH open (the
distro default; Ubuntu ships with its firewall off, so a role bootstrap must
open its own ports), kdump off, timezone UTC.

## Hardware

2 vCPU, 2 GB (reserved), 50 GB thin disk, vmxnet3, pvscsi,
`disk.EnableUUID=true`. Hardware version is not pinned, same as `ubuntu/`, so
it follows the cluster default. Resize at deploy.

Firmware is UEFI (no Secure Boot) for every source: all six ISOs boot UEFI and
take their boot parameters unattended. Ubuntu is still BIOS; that is history,
not a requirement.

## How a build runs

- `iso_paths` points at `<library>/<item>/<item>.iso` in the content library.
  If the NFS datastore behind the library cannot mount ISOs (the problem
  `windows11/` hit on 2026-10-01), set a per-source override in
  `iso_datastore_paths`, for example
  `iso_datastore_paths = { rhel9 = "[vcf-lab-mgmt-cl01-vsan] iso/rhel-9.8-x86_64-dvd.iso" }`.
- The answer files ride on a second CD built by Packer (`cd_content`), not on
  Packer's HTTP server: CI runs in the ARC runner pool and the build VM cannot
  reach a runner pod's ephemeral port. Ubuntu does the same with its cidata CD.
- EL boot: at the GRUB menu Packer selects "Install ...", appends
  `inst.text inst.ks=hd:LABEL=OEMDRV:/ks.cfg` to the kernel line and boots.
  The CD is labelled `OEMDRV`, which Anaconda also searches on its own: if
  the whole keystroke sequence misses, the default menu entry first runs a
  media check of the DVD (slow) and then still installs unattended from
  `ks.cfg`. A sequence that lands only partly can stop the boot instead;
  that shows on the VM console.
- Alpine boot: Packer logs in as root on the live console and runs
  `bootstrap.sh` from the second CD (see `alpine.md`).
- After the install reboots, Packer waits for VMware Tools to report an IP,
  SSHes in as `labuser`, installs the CA, runs the cleanup script, powers off,
  converts to a template and uploads the OVF, replacing the previous item.

## ISO staging

Upload each ISO to `vcf-lab-mgmt-contentlibrary` as an ISO item named after
the file without `.iso`, keeping the file name inside the item. A build of a
source whose item is missing fails at VM creation; the others are unaffected.

| Source | Library item name | File inside the item | Where to get it |
|---|---|---|---|
| `rhel10` | `rhel-10.2-x86_64-dvd` | `rhel-10.2-x86_64-dvd.iso` | Red Hat customer portal (downloaded 2026-10-07) |
| `rhel9` | `rhel-9.8-x86_64-dvd` | `rhel-9.8-x86_64-dvd.iso` | Red Hat customer portal (downloaded 2026-10-07) |
| `rhel8` | `rhel-8.10-x86_64-dvd` | `rhel-8.10-x86_64-dvd.iso` | Red Hat customer portal (downloaded 2026-10-07) |
| `rocky9` | `Rocky-9.8-x86_64-dvd` | `Rocky-9.8-x86_64-dvd.iso` | https://dl.rockylinux.org/pub/rocky/9/isos/x86_64/ (`CHECKSUM` alongside) |
| `centos-stream9` | `CentOS-Stream-9-20261006.0-x86_64-dvd1` | `CentOS-Stream-9-20261006.0-x86_64-dvd1.iso` | https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/ (`.SHA256SUM` alongside) |
| `alpine324` | `alpine-standard-3.24.2-x86_64` | `alpine-standard-3.24.2-x86_64.iso` | https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/ (`.sha256` alongside) |

Use the DVD images for Rocky and CentOS (the install needs AppStream for
open-vm-tools and runs with no network repos). Take the dated CentOS file, not
`latest`, so the item name says what is in it. When a newer point release or
compose is staged, change its entry in `iso_items` in `variables.pkr.hcl`.

## Building

CI (`.github/workflows/packer-build.yml`, job `linux-build`) builds every
source, one at a time, after the Windows 11 job, on push to `main`, on the
monthly schedule and on manual runs; never on pull requests. Each source is its
own matrix leg, so one failure does not stop the rest. A manual run's `only`
input picks `linux-all` or a single source, and then skips Ubuntu and Windows.

Locally (needs vCenter credentials; this replaces the library item):

```
cd linux
packer init .
packer build -force -only='el.vsphere-iso.rhel9' \
  -var vsphere_server=vcf-lab-vcenter-mgmt.int.sentania.net \
  -var vsphere_username=... -var vsphere_password=... .
```

Always pass `-only` (or `-parallel-builds=1`): a bare `packer build .` starts
all six VMs at once. Source names for `-only`: `el.vsphere-iso.{rocky9,centos-stream9,rhel8,rhel9,rhel10}`
and `alpine.vsphere-iso.alpine324`.

## Files

- `linux.pkr.hcl`: the two base sources (`el`, `alpine`) and the per-distro
  instances in the two build blocks.
- `variables.pkr.hcl`, `variables.auto.pkrvars.hcl`: inputs and lab values
  (only lab default credentials are committed).
- `ks/el8.ks`, `ks/el9.ks`, `ks/el10.ks`: kickstarts per EL major.
- `alpine/answers`, `alpine/bootstrap.sh`, `alpine/authorized_keys`: Alpine
  install.
- `setup/`: CA trust and cleanup scripts per family.
