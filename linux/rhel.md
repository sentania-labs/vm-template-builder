# RHEL templates (rhel8, rhel9, rhel10)

Built from the full DVD ISOs (`rhel-8.10-x86_64-dvd`, `rhel-9.8-x86_64-dvd`,
`rhel-10.2-x86_64-dvd`). Everything installed comes from the DVD's BaseOS and
AppStream repos; the build never contacts Red Hat.

## No registration at build time

The kickstarts have no `rhsm` command and the build runs no
`subscription-manager`, so the templates are unregistered. The lab has no
Satellite, and a registration baked into a template would be cloned into
every VM (one system identity, many machines). The consequence: a fresh VM has
no package repos enabled until it is registered. `dnf install` fails with
"This system is not registered" until then.

## Registering a VM after deploy

Do it in the role bootstrap, after the hostname is set (the hostname is what
appears in the Red Hat console):

```
sudo subscription-manager register --org=<org id> --activationkey=<key>
# or, interactively: sudo subscription-manager register --username=<rh login>
sudo dnf repolist        # BaseOS and AppStream should now be listed
```

With Simple Content Access (the default on current accounts) no `attach` step
is needed. The activation key and org id are secrets: keep them in
`lab-config.json` on the deploying side and pass them in at run time, never in
this repo. Before deleting a VM, `sudo subscription-manager unregister` frees
its entry.

`rhc connect` (RHEL 9/10) does the same and also enrolls Insights; use it only
if that is wanted.

## Per-release notes

- **RHEL 10** needs an x86-64-v3 CPU (AVX2 and friends). The mgmt hosts have
  it; an EVC baseline below that on the build or target cluster stops the
  kernel at boot. Guest type `rhel10_64Guest` needs a vSphere 9 era vCenter.
- **RHEL 8** is in its maintenance phase. Its kickstart body is the same as
  EL9's today but lives in its own file so changes can diverge safely.
- All three: SELinux enforcing, firewalld with SSH only, kdump off.
