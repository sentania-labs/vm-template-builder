# CLAUDE.md — packer-image-build

Packer-based VM image builds for Scott's homelab. Builds Ubuntu guest OS templates and publishes them to vSphere content libraries. That's the whole scope.

## What This Is

This repo produces VM templates for Scott's private lab infrastructure. Built images land in a vSphere content library on `vcf-lab-vcenter-mgmt.int.sentania.net`. The templates feed other lab workflows (VCF deployments, dev/test VMs) but this repo stops at image creation — provisioning, deployment, and orchestration live elsewhere.

Current templates:
- **Ubuntu 22.04** (`ubuntu/`) — `vsphere-iso` builder, cloud-init first-boot config, converts to template, publishes as OVF to content library
- **Ubuntu 24.04** (`ubuntu/`) — same pattern, in progress

## Tech Stack

| Component | Choice |
|-----------|--------|
| Build tool | Packer (HashiCorp) |
| vSphere builder | `hashicorp/vsphere` plugin (`vsphere-iso` source) |
| Guest OS | Ubuntu 22.04 / 24.04 LTS |
| First-boot config | cloud-init (meta-data + user-data passed as CD content) |
| Credentials | Variables files (`.pkrvars.hcl`) — never committed |
| Content library sync | `scripts/sync_content_libraries.py` / `sync-contentlibrary.ps1` |
| CA trust | `files/sentania Lab Root 2.crt` — internal CA root for vSphere TLS |

## Repo Layout

```
packer-image-build/
├── ubuntu/
│   ├── ubuntu.pkr.hcl          # Build definition (ubuntu22 + ubuntu24 sources)
│   ├── variables.pkr.hcl       # Variable declarations
│   ├── variables.auto.pkrvars.hcl  # Non-sensitive defaults (committed)
│   ├── ubuntu.pkrvars.hcl      # Sensitive overrides (gitignored)
│   ├── build.ps1               # PowerShell build wrapper
│   └── http/                   # Served over HTTP during boot (preseed/autoinstall)
│       └── setup/              # cloud-init user-data / meta-data
├── files/
│   └── sentania Lab Root 2.crt # Internal CA root (for vSphere TLS trust)
└── scripts/
    ├── inputs/                 # Input data for sync scripts
    ├── sync-contentlibrary.ps1 # PowerShell content library sync
    └── sync_content_libraries.py  # Python content library sync
```

## Design Decisions — Do Not Change Without Discussion

1. **Packer is the build tool.** No switching to other image-build systems (cloud-init-only, Ansible, etc.).
2. **Target is Scott's private vSphere lab.** No cloud provider paths (AWS AMI, Azure VHD, GCP image). Not the goal.
3. **Single responsibility.** This repo builds images. It does not provision VMs, deploy applications, or manage host configuration. That work belongs in `sentania-lab-toolkit` (Navani's domain).
4. **Credentials never in code.** Sensitive values (`vsphere_password`, `ssh_password`, API tokens) go in `.pkrvars.hcl` files that are gitignored. Never commit secrets.
5. **`insecure_connection = true` is temporary.** The internal CA cert is in `files/` — the long-term intent is proper TLS verification. Don't remove the CA cert file.

## Development Guidelines

- Terse commits. Describe what changed in the build, not philosophy.
- Fragments in comments are fine. No over-explaining.
- When adding a new OS template: follow the ubuntu source pattern — declare variables in `variables.pkr.hcl`, keep sensitive vars out of `variables.auto.pkrvars.hcl`, use `vsphere-iso` + cloud-init.
- Test builds against the dev vSphere environment before touching prod content libraries.
- Don't add external provisioners (Ansible, Chef, Salt) without discussion — keep the build surface small.

## What Claude Should NOT Do

- **Modify lab hosts directly.** SSH access, host config, service management — that's `sentania-lab-toolkit` / Navani territory.
- **Deploy built images.** Building is this repo's job. Deploying the resulting templates is downstream.
- **Push changes to other workspaces.** Stay in lane.
- **Commit credential files.** If a `.pkrvars.hcl` or `.env` file contains real values, it must stay gitignored.
- **Run `packer build` against production targets** without Scott's explicit instruction for that session.

## Reference Documents

_Add as the repo matures. Candidates: vSphere content library target reference, cloud-init template docs, internal CA issuance procedure (tracked as a gap in manalog's CLAUDE.md — Navani should document this in sentania-lab-toolkit)._

## Code Review Protocol

Self-review before considering any non-trivial change done:
- Does the Packer HCL validate (`packer validate`)?
- Are credentials referenced by variable, not hardcoded?
- Does the cloud-init config produce a usable VM (or is there a known test result)?

Doc-only changes (README, comments): skip formal review.
