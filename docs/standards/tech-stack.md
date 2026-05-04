# Tech Stack

Technology choices for `vm-template-builder`. Treat these as defaults
— changes need discussion, not a casual commit.

| Component | Choice |
|-----------|--------|
| Build tool | Packer (HashiCorp) |
| vSphere builder | `hashicorp/vsphere` plugin (`vsphere-iso` source) |
| Guest OS | Ubuntu 22.04 / 24.04 LTS; Windows Server 2025 |
| First-boot config | cloud-init (Linux); cloudbase-init (Windows cloudbase-init variant); none (bare Windows) |
| Unattended Windows install | autounattend.xml served via CD or HTTP during boot |
| Windows provisioner transport | WinRM. Must be enabled during OS install via autounattend.xml so Packer can connect post-boot. Firewall rules, service config, and auth mode are template-author's call; the hard requirement is that WinRM is reachable before the first provisioner step runs. Packer does not use SSH on Windows. |
| Credentials | `.pkrvars.hcl` variables files — see [secrets-policy.md](secrets-policy.md) |
| Content library sync | `scripts/sync_content_libraries.py` / `sync-contentlibrary.ps1` |
| CA trust | `files/sentania Lab Root 2.crt` — internal CA root for vSphere TLS |

## Notes

- `insecure_connection = true` is temporary. The internal CA cert is
  in `files/`; the long-term intent is proper TLS verification. Do
  not remove the CA cert file.
- No external configuration management (Ansible, Chef, Salt). Keep
  the build surface small — extending to one of these needs an
  explicit decision.
- No cloud-provider builders (AWS AMI, Azure VHD, GCP image). The
  workspace targets Scott's private vSphere lab only.
