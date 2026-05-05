# vm-template-builder

Packer-based VM image builds for Scott's homelab. Produces Ubuntu LTS
and Windows Server 2025 templates and publishes them as OVFs to a
vSphere content library on `vcf-lab-vcenter-mgmt.int.sentania.net`.

## Scope

This repo builds images. Provisioning, deployment, and host
configuration live elsewhere (see `lab-admin`).

## Layout

- `ubuntu/` — Ubuntu 22.04 / 24.04 LTS sources.
- `windows/` — Windows Server 2025 sources (`bare`; `cloudbase-init`
  variant currently parked).
- `files/` — shared assets (internal CA cert).
- `scripts/` — content library sync utilities.
- `contracts/build_vm_template.md` — Scott² capability contract.
- `docs/standards/` — tech stack, secrets policy.

## Builds

GitHub Actions runs `packer build` for every source on push to `main`.
Local builds use the per-OS `*.pkr.hcl` and `*.pkrvars.hcl` files —
real credentials live only in GitHub Actions secrets or local
gitignored vars files (see `docs/standards/secrets-policy.md`).

## More

See `CLAUDE.md` for working conventions and `windows/README.md` /
per-variant docs for image-specific details.
