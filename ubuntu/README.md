# Ubuntu templates

Ubuntu Server LTS templates built with Packer `vsphere-iso` and published to
the content library `vcf-lab-mgmt-contentlibrary` as OVF items `ubuntu22` and
`ubuntu24`.

| Source | OS | Install media |
|---|---|---|
| `ubuntu22` | Ubuntu 22.04.5 LTS | `ubuntu-22.04.5-live-server-amd64.iso` |
| `ubuntu24` | Ubuntu 24.04.3 LTS | `ubuntu-24.04.3-live-server-amd64.iso` |

- **Install:** Subiquity autoinstall from a `cidata` CD (`http/user-data`,
  `http/meta-data`), not Packer's HTTP server: CI runs in the ARC runner pool
  and the build VM cannot reach a runner pod's port. Security updates are
  applied during the install.
- **Pre-installed:** openssh-server, open-vm-tools, cloud-init,
  ca-certificates, the lab root CA. IPv6 disabled. LVM layout.
- **Account:** `labuser` (lab default password and key, passwordless sudo).
- **First boot:** cloud-init with `datasource_list: [ VMware, NoCloud,
  ConfigDrive ]`; machine-id, SSH host keys and logs are cleaned at build.
- **Lab assumptions:** cluster `vcf-lab-mgmt-cl01`, VM network
  `vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt` with DHCP, build disk on
  `vcf-lab-mgmt-cl01-vsan`.
- **Media location:** the library items normally, but `iso_datastore_paths`
  in `variables.auto.pkrvars.hcl` currently points both sources at copies in
  `[vcf-lab-mgmt-cl01-vsan] iso/`, because esx05 does not mount the library's
  NFS datastore. See `NOTES.md` (2026-10-07).
- **CI:** job `packer-build` in `.github/workflows/packer-build.yml`, on push
  to main, pull requests, the monthly schedule and manual runs (`only` =
  `everything` or `ubuntu`).
