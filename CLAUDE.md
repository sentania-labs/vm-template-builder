# CLAUDE.md — vm-template-builder

Packer-based VM image builds for Scott's homelab. Builds Ubuntu and
Windows guest OS templates and publishes them as OVFs to a vSphere
content library on `vcf-lab-vcenter-mgmt.int.sentania.net`. Templates
feed downstream lab workflows; this repo stops at image creation.
**Not** a provisioner, deployer, host-config tool, or orchestrator.

## Charter

Software workspace. The paragraph above is the charter. Software
authors don't touch infrastructure outside their charter — even with
credentials available. For out-of-charter work, use a sanctioned
cross-system channel.

## Scott² integration

Registered as the `vm-template-builder` provider. Workspace path:
`~/providers/vm-template-builder/`.

- `capabilities.yml` — declares `build_vm_template` (allowed_callers:
  `lab-admin`, requires_approval: true).
- `capability-deps.yml` — empty; produces artifacts, consumes nothing.
- Contract — `contracts/build_vm_template.md`.
- Cross-workspace requests arrive via the orchestrator queue. Do not
  invoke peers directly.

## Layout

- `ubuntu/` — Ubuntu LTS sources (Packer HCL, cloud-init http data).
- `windows/` — Windows Server 2025 sources, autounattend, drivers.
- `files/` — shared assets (internal CA cert).
- `scripts/` — content-library sync utilities.
- `contracts/` — capability contracts.
- `docs/standards/` — tech stack, secrets policy.

## Image catalog conventions

Every image source ships with documentation alongside it. Adding or
modifying a build means updating the doc — not optional, not deferred.
Convention: `<os-dir>/README.md` for the OS family overview;
`<os-dir>/<variant>.md` for per-source detail when a family has
multiple meaningfully-different variants. Each doc covers purpose,
OS + version, pre-installed software, first-boot behavior, and lab
assumptions (target cluster, content library, network/storage
prereqs).

## Hard rules

- **Stay in charter.** Build images. Do not provision VMs, deploy
  applications, modify lab hosts, or reach into other workspaces.
  Lab-host work belongs to `lab-admin`.
- **Real secrets never in code.** vSphere passwords, SSH keys, API
  tokens go through GitHub Actions — never committed. Default lab
  account credentials are the documented exception
  (`docs/standards/secrets-policy.md`).
- **No production builds without explicit approval.** Do not run
  `packer build` against production targets without Scott's
  instruction for that session.
- **Don't change pinned design decisions silently.** Packer is the
  build tool; the target is Scott's private vSphere lab; the CA cert
  in `files/` stays. Changes here are decisions, not edits.

## Workflow

Push direct to `main` — no PR flow, no feature branches. Build failure
is the validation gate: fix, commit, rebuild. GitHub Actions runs
`packer build` for every image source on push to `main`; when adding
a new source, update the workflow.

## Pointers

- `docs/standards/tech-stack.md` — stack details.
- `docs/standards/secrets-policy.md` — secrets policy and lab default
  accounts.
- `contracts/build_vm_template.md` — capability contract.
- `windows/README.md` — Windows family overview.
- `ubuntu/` — Ubuntu family (README pending).

## Self-review (non-trivial changes)

Before considering a change done: `packer validate` passes; credentials
are referenced by variable, not hardcoded; the cloud-init / autounattend
produces a usable VM (or a test result is recorded). Doc-only changes
skip formal review.
