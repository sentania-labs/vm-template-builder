# Secrets Policy

Authoritative policy for credentials in `vm-template-builder`.

## Real secrets — GitHub Actions only

All real secrets are provided via GitHub Actions secrets and never
committed to the repo. This covers:

- vSphere credentials (`vsphere_password`, `vsphere_user`, vCenter
  hostname if considered sensitive)
- SSH private keys
- Content library tokens or API keys
- Anything that grants access to production or lab infrastructure

Local builds load these values from `*.pkrvars.hcl` files that are
gitignored.

## Committed exception — lab-standard default accounts

These accounts are baked into every template by design and may live in
committed `*.auto.pkrvars.hcl` files or provisioner scripts. They are
lab policy, not operational secrets — they belong to the image, not
the environment.

### Built-in default accounts

Set during unattended OS install; not created by Packer provisioners.

- **Linux root** — `VMware123!VMware123!`. SSH is disabled for root.
  Password exists for local/console recovery only.
- **Windows local Administrator** — `VMware123!VMware123!`.

### Provisioned users

Created during the build by Packer provisioners.

- **`labuser`** — `VMware123!VMware123!`. Passwordless sudo on Linux;
  member of the local Administrators group on Windows.

## Rules

- If you see a vSphere password, SSH key, or API token and feel
  tempted to commit it, don't. Pass it through GitHub Actions.
- If the default account passwords need to change, that is a policy
  discussion — not a routine commit.
- Committed credential files must contain only the default account
  credentials listed above. Nothing else.
