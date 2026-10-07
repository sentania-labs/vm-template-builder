# Kickstart: RHEL 8 (rhel8 source, RHEL 8.10 DVD).
#
# The body is the same as el9.ks today: every command used here means the
# same thing on RHEL 8 Anaconda. It is its own file so an EL8-only change
# (RHEL 8 is in maintenance and its Anaconda is older) never forces a retest
# of the three EL9 sources, and the reverse.
#
# Contract (mirrors ubuntu24): labuser with the lab RSA key and passwordless
# sudo, root locked, open-vm-tools, sshd on, DHCP on the first NIC, IPv6 off,
# LVM root, no cloud-init, no subscription registration. Served to Anaconda
# from the packer cd_content CD labelled OEMDRV and booted with
# "inst.text inst.ks=hd:LABEL=OEMDRV:/ks.cfg".

text
cdrom
eula --agreed
firstboot --disable
skipx
reboot

lang en_US.UTF-8
keyboard --xlayouts='us'
timezone Etc/UTC --utc

network --bootproto=dhcp --device=link --onboot=on --activate --noipv6
firewall --enabled --service=ssh
selinux --enforcing
services --enabled=sshd,vmtoolsd

rootpw --lock
# Lab default labuser password (same SHA-512 hash as ubuntu/http/user-data).
user --name=labuser --groups=wheel --iscrypted --password=$6$GcokXb86Rt.azJEj$4zeQGtCXwY8hluxfdkhDARjOy98s4EoGGPRfWadZOXhz2qNkG0g0rKjBbZCuQsrJY/w/zxncMtteD0tHUZSXD0
sshkey --username=labuser "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCebLZZYuVSoAKTyryMC9s7YeMAm7BcwoVFz0DJskIR0oGjPgiPkZI+nCSQbDvtdc8Lm3yeS/CmVtsNv6wWdbHNSxhSmczLzgSfZgO3iBcrI/VhWa/7cs5GSXuZvfX0ww4L5M/INk36HIKmi+9TvdQlFrfmxLnVGtGHBLdPrOOXfdUYBkT3KYI8WQubk6JF+jjYKj9jBKgAxt4t7P3NdcTRl+ILbeh6QllMjsZjUJLLGEgvrCzfBOKtBBmhDG/O3Hv5/kTVef0rqEBlpTlt/K8QbCkG7tCeogaqagLMQJUpJWafIXLk8LHJOgMbORUwPe4KOuarsx/W8bCU/O8CHIaz rsa-key-20250129"

ignoredisk --only-use=sda
zerombr
clearpart --all --initlabel --drives=sda
bootloader --append="ipv6.disable=1"
autopart --type=lvm --nohome

%packages
@^minimal-environment
open-vm-tools
%end

%addon com_redhat_kdump --disable
%end

%post --erroronfail --log=/root/ks-post.log
echo 'labuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/labuser
chmod 0440 /etc/sudoers.d/labuser
%end
