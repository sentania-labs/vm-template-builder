# CLAUDE.md — packer-image-build

Packer-based VM image builds for Scott's homelab. Builds Ubuntu and Windows guest OS templates and publishes them to vSphere content libraries. That's the whole scope.

## What This Is

This repo produces VM templates for Scott's private lab infrastructure. Built images land in a vSphere content library on `vcf-lab-vcenter-mgmt.int.sentania.net`. The templates feed other lab workflows (VCF deployments, dev/test VMs) but this repo stops at image creation — provisioning, deployment, and orchestration live elsewhere.

Current templates:
- **Ubuntu 22.04** (`ubuntu/`) — `vsphere-iso` builder, cloud-init first-boot config, converts to template, publishes as OVF to content library
- **Ubuntu 24.04** (`ubuntu/`) — same pattern, in progress

Planned:
- **Windows Server 2025 (cloudbase-init)** (`windows/`) — `vsphere-iso` builder, autounattend.xml for unattended install, cloudbase-init MSI + config for first-boot automation
- **Windows Server 2025 (bare)** (`windows/`) — same builder, autounattend.xml, no cloudbase-init; clean base image for workloads that don't need it

## Image Catalog and Documentation

Every image source gets a documentation file alongside it. When adding or modifying a build, the doc is a first-class deliverable — not optional, not deferred.

Each image doc covers:
- **Purpose** — what this template is for in the lab
- **OS + version** — exact edition, build number where relevant
- **Pre-installed software** — anything baked in beyond the base OS
- **First-boot behavior** — cloud-init (Linux), cloudbase-init (Windows), or none (bare images)
- **Lab assumptions** — target vSphere cluster, content library destination, any network or storage prereqs

Convention: `<os-dir>/README.md` for the OS family overview; `<os-dir>/<variant>.md` for per-source detail if a family has multiple variants with meaningfully different behavior.

## Tech Stack

| Component | Choice |
|-----------|--------|
| Build tool | Packer (HashiCorp) |
| vSphere builder | `hashicorp/vsphere` plugin (`vsphere-iso` source) |
| Guest OS | Ubuntu 22.04 / 24.04 LTS; Windows Server 2025 |
| First-boot config | cloud-init (Linux); cloudbase-init (Windows cloudbase-init variant); none (bare Windows) |
| Unattended Windows install | autounattend.xml served via CD or HTTP during boot |
| Credentials | Variables files (`.pkrvars.hcl`) — see Secrets Policy below |
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
4. **Credentials never in code.** Sensitive values (`vsphere_password`, API tokens) go in `.pkrvars.hcl` files that are gitignored, or are injected at build time via GitHub Actions secrets. Never commit real operational credentials. See Secrets Policy below for the one exception.
5. **`insecure_connection = true` is temporary.** The internal CA cert is in `files/` — the long-term intent is proper TLS verification. Don't remove the CA cert file.

## Workflow

Push direct to `main`. No PR flow, no feature branches.

Build failure is the validation gate — if a build fails, fix the template, commit, and rebuild. Don't stage changes behind branches waiting for a clean run. Iteration is the process.

Same pattern as vcf-content-factory's rapid-build phase: the repo is a personal tool, not a shared codebase. Velocity over ceremony.

### CI

A GitHub Actions workflow triggers `packer build` for image sources on push to `main`. The workflow is the feedback loop — a failed build surfaces immediately rather than silently rotting in the repo. Real secrets (vSphere credentials, etc.) are injected at build time via GitHub Actions secrets; see Secrets Policy below.

When adding a new image source, update the CI workflow to include it. A build that never runs in CI is untested.

## Secrets Policy

All real secrets are provided via GitHub Actions secrets — never committed to the repo. This covers:
- vSphere credentials (`vsphere_password`, `vsphere_user`, vCenter hostname if considered sensitive)
- SSH private keys
- Content library tokens or API keys
- Anything that grants access to production or lab infrastructure

**One committed exception: default image user passwords.**

The lab-standard default credentials for built templates are committed in `*.auto.pkrvars.hcl` files because they're lab policy, not operational secrets:

- Default image user: `labuser` / `VMware123!VMware123!`
- Default Windows local Administrator password during build: `VMware123!VMware123!`

These are baked into every template by design. They are the same across all images. Committing them is intentional — they belong to the image, not the environment.

**Rules:**
- If you see a vSphere password, SSH key, or API token and feel tempted to commit it, don't. Pass it through GitHub Actions.
- If the default user password needs to change, that's a policy discussion — not a routine commit.
- Committed credential files must only ever contain the default user password and username. Nothing else.

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
