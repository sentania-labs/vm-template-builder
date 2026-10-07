#!/bin/sh
# Unattended Alpine install for the Packer alpine324 source.
#
# Run by the boot_command from the live ISO's root shell, off the packer
# cd_content CD (mounted at /media/ks). Steps:
#   1. setup-alpine with the answer file: keymap, hostname, DHCP on eth0,
#      apk repos (main + community), chrony, openssh. Nothing on disk yet.
#   2. In the live system: open-vm-tools, sudo, bash, labuser with the lab
#      key and password hash, passwordless sudo, IPv6 off, root locked.
#   3. setup-disk -m sys /dev/sda. It installs every package in the live
#      /etc/apk/world and copies the changed /etc plus lbu-added paths, so
#      step 2 carries over to the installed system.
#   4. Reboot into the installed system; Packer connects over SSH.
set -eu

KS=/media/ks
DISK=/dev/sda

# 1. Base setup. -e: no root password prompt (root is locked in step 2).
setup-alpine -e -f "$KS/answers"

# 2. Template contract.
apk add --no-progress \
    open-vm-tools open-vm-tools-guestinfo open-vm-tools-deploypkg \
    open-vm-tools-timesync open-vm-tools-vmbackup open-vm-tools-openrc \
    sudo bash ca-certificates
rc-update add open-vm-tools default || true
rc-update add sshd default || true   # setup-sshd may have added it already

adduser -D -s /bin/bash labuser
addgroup labuser wheel
# Lab default labuser password (same SHA-512 hash as ubuntu/http/user-data).
# shellcheck disable=SC2016 # literal hash, must not expand
echo 'labuser:$6$GcokXb86Rt.azJEj$4zeQGtCXwY8hluxfdkhDARjOy98s4EoGGPRfWadZOXhz2qNkG0g0rKjBbZCuQsrJY/w/zxncMtteD0tHUZSXD0' | chpasswd -e
install -d -m 0700 -o labuser -g labuser /home/labuser/.ssh
install -m 0600 -o labuser -g labuser "$KS/authorized_keys" /home/labuser/.ssh/authorized_keys
lbu add /home/labuser

echo 'labuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/labuser
chmod 0440 /etc/sudoers.d/labuser

printf 'net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\n' > /etc/sysctl.d/99-disable-ipv6.conf
rc-update add sysctl boot || true

passwd -l root

# 3. Install to disk. ERASE_DISKS answers the erase prompt.
ERASE_DISKS="$DISK" setup-disk -m sys "$DISK"

# 4. Into the installed system.
reboot
