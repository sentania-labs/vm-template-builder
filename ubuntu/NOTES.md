# Ubuntu build notes

## 2026-10-07: ISOs from vSAN, because esx05 does not mount the library's NFS datastore

Asked for by Scott ("But fix the Packer job."). The Ubuntu job had failed on
every run since the 2026-10-01 schedule run.

What failed: `error mounting an image '<library>/<item>/<item>.iso': Invalid
configuration for device '0'`, about 3 seconds after "Mounting ISO images".
It hit ubuntu24 on 2026-10-01 (both runs) and ubuntu22 on the 2026-10-07 main
run, so it is not tied to one ISO.

Cause: placement. The content library is backed by the NFS datastore
`vcf-lab-mgmt01-nfs`, and cluster host `vcf-lab-mgmt-esx05` does not mount it
(`esxcli storage nfs list` is empty there; the other four cluster hosts list it
accessible). vCenter lists five hosts on the datastore, but the fifth is
standalone esx06, not esx05. When DRS places the build VM on esx05 the CD-ROM
cannot be backed by a library ISO. vCenter events for the 2026-10-07 main run:
ubuntu22-template created on esx05 at 4:19:32 PM, removed at 4:19:37 PM.

Ruled out: the ISOs themselves. Both library files are present at full size,
and the vSAN copies (copied from those files) hash to the published SHA-256
(24.04.3 `c3514bf0...d8274b`, 22.04.5 `9bc60288...aa98b0`).

Fix: per-source `iso_datastore_paths` override, the same escape hatch as
`linux/` and `windows11/`, pointing at copies in
`[vcf-lab-mgmt-cl01-vsan] iso/`, which every cluster host sees. Set in
`variables.auto.pkrvars.hcl`; remove the map to return to the library items
once esx05 mounts the NFS datastore (lab-admin's side, not this repo).

Proof: manual run 37694972818 (`only=ubuntu`, branch
`ubuntu24-iso-mount-fix`) built and published both. ubuntu24-template was
created on esx05, the host that used to fail, and mounted the vSAN ISO.

Open: the two 2026-10-07 runs before the fix also had ubuntu24 time out
waiting for SSH (installer got an IP, SSH never answered in 30 minutes). In
the fixed run the installer spent most of its time in "downloading and
installing security updates" and SSH came up after about 10 minutes. Cause of
the earlier timeouts is not established; if it recurs, capture the VM console
during the wait before changing `ssh_timeout`.

Also added: an `ubuntu` choice for the manual run's `only` input, which runs
the Ubuntu job alone (no Windows, no linux/).
