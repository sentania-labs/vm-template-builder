#!/bin/bash
# Generalize an EL (RHEL / Rocky / CentOS Stream) build before it becomes a
# template. Same intent as ubuntu/setup/setup.sh: no host identity, no logs.
set -uo pipefail

echo '> Cleaning dnf caches ...'
dnf clean all
rm -rf /var/cache/dnf/*

echo '> Cleaning audit logs ...'
[ -f /var/log/audit/audit.log ] && cat /dev/null > /var/log/audit/audit.log
[ -f /var/log/wtmp ] && cat /dev/null > /var/log/wtmp
[ -f /var/log/lastlog ] && cat /dev/null > /var/log/lastlog
journalctl --rotate >/dev/null 2>&1 && journalctl --vacuum-time=1s >/dev/null 2>&1
rm -f /root/anaconda-ks.cfg /root/original-ks.cfg /root/ks-post.log
rm -rf /var/log/anaconda

# sshd-keygen regenerates missing host keys at the next boot.
echo '> Cleaning SSH host keys ...'
rm -f /etc/ssh/ssh_host_*

echo '> Setting hostname to localhost ...'
hostnamectl set-hostname localhost

# An empty machine-id makes systemd generate a fresh one at first boot, so
# every clone gets its own (and its own DHCP client id).
echo '> Cleaning the machine-id ...'
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo '> Cleaning DHCP leases ...'
rm -f /var/lib/NetworkManager/*.lease

exit 0
