# Alpine template (alpine324)

Alpine Linux 3.24.2 from the standard x86_64 ISO (`linux-lts` kernel, OpenRC,
musl). The source is named for the minor release; when 3.25 ships, add an
`alpine325` source rather than silently changing what `alpine324` contains.

## How the install is driven

Alpine has no kickstart equivalent that the ISO reads by itself. The flow:

1. The live ISO boots to a console login. Packer waits 60 s, types `root`
   (no password on the live system), then a one-line loop that mounts the
   Packer CD (`ALPINEKS`) at `/media/ks` and runs `bootstrap.sh`.
2. `bootstrap.sh` runs `setup-alpine -e -f answers` with `DISKOPTS=none`:
   keymap, hostname, DHCP on `eth0`, the CDN mirror with community enabled,
   chrony, openssh. Nothing is written to disk yet.
3. It then adds open-vm-tools (plus guestinfo, deploypkg, timesync, vmbackup,
   openrc plugins), sudo, bash and ca-certificates, creates `labuser` (bash,
   `wheel`, lab password hash, lab RSA key, `NOPASSWD` sudoers drop-in),
   disables IPv6 by sysctl and locks root.
4. `ERASE_DISKS=/dev/sda setup-disk -m sys /dev/sda` installs to disk. It
   installs every package in the live system's world file and copies the
   changed `/etc` plus `lbu add`-ed paths (`/home/labuser`), which is how
   step 3 reaches the installed system.
5. Reboot. open-vm-tools reports the DHCP address; Packer connects as
   `labuser`, installs the CA, cleans up and powers off.

The install needs internet access from the build network (packages come from
`dl-cdn.alpinelinux.org`; the standard ISO only carries the base set).

## Unattended or not

Fully unattended on paper: every `setup-alpine` step has an answer, the root
password prompt is skipped with `-e`, and `ERASE_DISKS` answers the disk
erase prompt. The only typed input is the boot command. Not yet proven by a
build; the likeliest failure points are the boot_command timing (if the
console is not at the login prompt after 60 s the keystrokes are lost and the
build times out waiting for SSH) and a `setup-alpine` prompt this answer file
does not cover on 3.24. Either shows on the VM console. If a gap turns up,
record it in `NOTES.md` and the manual step here.

## Differences from the EL and Ubuntu templates

- OpenRC, not systemd; `sudo poweroff` / `rc-service`, not `systemctl`.
- No machine-id to reset; hostname is reset to `localhost` via
  `/etc/hostname`.
- Disk layout is setup-disk "sys" mode on UEFI: an EFI system partition, swap
  and an ext4 root, no LVM.
- The NIC is `eth0`. No firewall is installed (same as Ubuntu's default).
- cloud-init is not installed. It exists in Alpine's community repo if a role
  ever needs guestinfo customization.
- Controller: pvscsi. `vmw_pvscsi` is a module in `linux-lts` 3.24 and in
  mkinitfs' default `scsi` feature, so both the installer and the installed
  system see the disk. If a build cannot find `/dev/sda`, switch the `alpine`
  source to `lsilogic-sas` (also in that feature).
