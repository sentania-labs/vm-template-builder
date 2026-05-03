---
title: vm-template-builder build_vm_template capability contract
schema_version: 1
contract_owner: vm-template-builder
capability: build_vm_template
---

# `build_vm_template` — build or refresh a VM template in the lab content library

**Owner:** `vm-template-builder` workspace.
**Audience:** any peer workspace requesting a new VM template variant or a
refresh of an existing one. Today the only allowed caller is `lab-admin`.
**Status:** Bootstrap. Approval-gated. Every accepted request publishes
to the prod vSphere content library on
`vcf-lab-vcenter-mgmt.int.sentania.net`, so each one goes through Scott
before the build runs.

This contract covers what a caller sends to `vm-template-builder` to
produce a Packer-built VM template (Ubuntu LTS or Windows Server 2025
variants today) and publish it as an OVF to the lab content library.
The workspace's charter is image creation only — provisioning,
deployment, and post-template orchestration are out of scope and
belong to the caller.

---

## 1. Lane discipline

| Owner | Owns |
|---|---|
| `vm-template-builder` | Packer source authoring, autounattend / cloud-init / cloudbase-init configuration, build execution (CI or local), publishing the resulting OVF to the configured vSphere content library, build-status reporting back through the orchestrator. |
| Caller (e.g. `lab-admin`) | Deciding which OS / variant is needed and why, providing the template name and any non-default customizations as request fields, consuming the published content-library item once the build is reported `accepted`. |
| `lab-admin` (downstream consumer of the artifact) | All VM provisioning, host configuration, and deployment of VMs cloned from the template. `vm-template-builder` does not provision, does not deploy, does not touch lab hosts. |

`vm-template-builder` does not modify host configuration, does not run
provisioners outside the Packer build, does not deploy templates as
VMs, and does not manage the content library beyond publishing built
images to it. The workspace's `Charter` section in `CLAUDE.md` is the
authoritative lane definition.

---

## 2. Request interface

A request is dispatched through the Scott² orchestrator queue
(`~/scott.2/tasks/pending/`) targeting `vm-template-builder`.

### 2.1 Required fields

| Field | Type | Notes |
|---|---|---|
| `template_name` | string | Kebab-case, lowercase, ≤40 chars, regex `^[a-z0-9][a-z0-9-]{0,39}$`. Becomes the content-library item name. Must not collide with an existing item unless `replace_existing: true` is set. |
| `os` | enum | `ubuntu` / `windows`. Selects the source family in the repo. |
| `version` | string | OS version. For `ubuntu`: `22.04` or `24.04`. For `windows`: `2025`. New versions require a Packer source addition before they are accepted. |
| `variant` | enum | OS-family-specific: ubuntu has `default` (cloud-init); windows has `cloudbase-init` or `bare`. Variant determines first-boot behavior and which Packer source is used. |
| `tenant_workspace` | string | Workspace slug submitting the request. Must be in `capabilities.yml`'s `allowed_callers`. |
| `rationale` | string | One sentence: why this template is needed (new template, refresh for security patches, schema bump, etc.). |

### 2.2 Optional fields

| Field | Type | Notes |
|---|---|---|
| `replace_existing` | bool | Default `false`. If `true`, an existing content-library item with the same name is replaced (old item archived per content-library policy). If `false` and a collision exists, the request is `rejected`. |
| `customizations` | object | Variant-specific overrides. See §2.3. Anything not listed there requires a Packer source change first and is `rejected` at validation. |
| `target_content_library` | string | Override the default content library. Defaults to the lab's standard library on `vcf-lab-vcenter-mgmt.int.sentania.net`. Non-default targets require Scott approval beyond the standard request approval gate. |

### 2.3 Allowed `customizations`

Customizations are limited to fields the existing Packer sources
already parameterize. New customization fields require a Packer
template change and are out of scope for a single request.

| Field | Applies to | Notes |
|---|---|---|
| `extra_packages` | ubuntu | List of apt package names appended to the cloud-init `packages:` block. Must be in the standard Ubuntu archive — no PPAs from the request. |
| `disk_size_gb` | all | Integer. Overrides the default OS disk size. Must be ≥ the variant's documented minimum. |
| `cpu_count` | all | Integer. Build-time vCPU count for the Packer VM (does not pin the template's deployment-time sizing). |
| `memory_mb` | all | Integer. Build-time RAM. |

---

## 3. Response

`vm-template-builder` responds through the orchestrator queue with one of:

| Status | Meaning |
|---|---|
| `accepted` | Build completed and the OVF is published to the target content library. Response includes the content-library item name, item ID, OVF URL, and the source git SHA the build was produced from. |
| `accepted_pending_publish` | Build completed locally; content-library publish is in flight. Caller should wait for a follow-up `accepted` or `failed` before consuming. |
| `countered` | Request is acceptable in principle but a field needs adjustment (e.g. `disk_size_gb` below the variant minimum, `replace_existing` not set when the item already exists). Response includes the counter-proposal. |
| `rejected` | Request fails a hard rule (see §4). Response cites the rule. |
| `failed` | Build attempted but failed. Response includes the failing Packer step (provisioner name or builder phase), CI run URL if applicable, and whether any partial publish occurred (publishes only happen on a clean build, so the answer is normally "no"). |

Success-path artifacts:

- A new (or replaced) item in the target vSphere content library,
  reachable to `lab-admin` for cloning.
- A git commit on `main` if the build was triggered by a source
  change. Refresh-only builds (no source change) do not produce a
  commit.
- A CI run in `vm-template-builder` recording the build, if executed
  through the GitHub Actions workflow.

The deploy-time secrets baked into every template (the lab default
accounts in `CLAUDE.md` § Secrets Policy) are policy, not response
content. They are not communicated per-request.

---

## 4. Validation rules (hard refusals)

`vm-template-builder` refuses the request — without building — if any
of the following hold:

- `template_name` does not match `^[a-z0-9][a-z0-9-]{0,39}$`.
- `template_name` collides with an existing content-library item AND
  `replace_existing` is not `true`.
- `os` / `version` / `variant` combination is not represented by an
  existing Packer source in the repo. New combinations require a
  source addition and a separate change before they can be requested.
- `customizations` contains a field not listed in §2.3.
- `tenant_workspace` is not in `capabilities.yml`'s `allowed_callers`.
  The dispatcher's gate refuses these before the request reaches
  `vm-template-builder`; restated for clarity.
- `target_content_library` overrides the default and Scott has not
  separately approved that target for this request.
- The request would publish to a content library outside the lab
  vSphere on `vcf-lab-vcenter-mgmt.int.sentania.net`. Cross-vCenter
  publishing is not in charter.

---

## 5. Onboarding flow

There is no per-caller onboarding for this capability beyond being
added to `allowed_callers`. First-time use:

1. Caller workspace adds a `capability-deps.yml` entry for
   `vm-template-builder.build_vm_template` with a `purpose` line.
2. `vm-template-builder` adds the caller to `allowed_callers` in
   `capabilities.yml` (re-survey required).
3. Caller dispatches a request through the orchestrator. First request
   per caller sits in the approval queue per the
   `requires_approval: true` setting.

Each request is independent. There is no per-caller persistent state
to set up.

---

## 6. Steady-state operations

Day-to-day, callers submit one request per template-build event:

- **New template:** caller sends a request; once `accepted`, the
  content-library item is available for cloning.
- **Refresh:** same shape as new, with `replace_existing: true` to
  replace the prior item. Refresh cadence is the caller's call —
  `vm-template-builder` does not auto-refresh on a schedule.
- **Source change without a request:** if the Packer source changes
  on `main`, the GitHub Actions workflow runs the build as part of
  CI. Those builds are CI-driven, not Scott²-routed, and do not
  generate orchestrator responses.

---

## 7. Offboarding / decommission

A caller stops consuming this capability by removing the entry from
its `capability-deps.yml`. `vm-template-builder` then removes the
caller from `allowed_callers` on the next re-survey. No cleanup of
previously-built templates happens automatically — content-library
item lifecycle is the caller's (and downstream consumer's)
responsibility.

---

## 8. Schema versioning

This contract is `schema_version: 1`. Field additions that do not
break existing requests are additive (still v1). Renames, removals,
or semantic changes to existing fields require a v2 bump.
`vm-template-builder` will announce v2 cutovers through an
orchestrator notification with a stated deprecation window.

---

## 9. Open requirements

- **Allowed-callers list contains only `lab-admin` at registration.**
  Per the authorization-maturity stance, the capability starts narrow.
  Additional callers require an explicit `capabilities.yml` change
  and a re-survey.
- **Per-build approval gate (`requires_approval: true`).** Every
  request goes to Scott before dispatch until a steady-state pattern
  emerges that justifies relaxing the gate (e.g. a documented
  refresh cadence with bounded blast radius).
- **No declared schema for the response body.** This contract
  describes status semantics in §3 but does not yet pin a JSON
  schema for the response payload. First real consumer integration
  will surface the right shape; `lab-admin` is the most likely first
  caller and should drive the schema.
- **CI-driven builds bypass the orchestrator.** Builds triggered by
  a source push to `main` (the workspace's normal velocity workflow)
  do not flow through Scott². That is intentional — the orchestrator
  request path is for cross-workspace asks, not for the workspace's
  own iteration. The two paths can produce the same artifact; the
  caller is expected to coordinate timing if it matters.
- **Cross-vCenter publishing is not supported.** Listed as a hard
  refusal in §4 today; revisit if and when a second vCenter enters
  the lab.
- **Windows variants are still in progress.** Per `CLAUDE.md`, both
  Windows Server 2025 variants are under active development. Requests
  for `os: windows` may be `rejected` or `failed` until the
  corresponding source is stable.
