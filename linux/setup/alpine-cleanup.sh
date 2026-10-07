#!/bin/sh
# Generalize the Alpine build before it becomes a template. Same intent as
# ubuntu/setup/setup.sh: no host identity, no logs.
set -u

echo '> Cleaning apk cache ...'
rm -rf /var/cache/apk/*

echo '> Cleaning logs ...'
[ -f /var/log/wtmp ] && cat /dev/null > /var/log/wtmp
[ -f /var/log/lastlog ] && cat /dev/null > /var/log/lastlog
[ -f /var/log/messages ] && cat /dev/null > /var/log/messages

# The sshd init script regenerates missing host keys at the next start.
echo '> Cleaning SSH host keys ...'
rm -f /etc/ssh/ssh_host_*

echo '> Setting hostname to localhost ...'
echo localhost > /etc/hostname

exit 0
