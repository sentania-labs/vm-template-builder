---
self_audit:
  workspace: vm-template-builder
  tier: provider
  date: 2026-05-04
  claude_md_lines: 165
  skills_count: 0
  findings:
    blockers: 0
    majors: 3
    minors: 3
    nits: 1
  grade: B
---

### Summary

Architecture and capability wiring are clean: a single capability is
declared, contracted in depth, and gated to a single allowed caller;
no peer-to-peer filesystem reads; lane discipline is reinforced by an
explicit Charter section and restated in the contract. The biggest
issue is CLAUDE.md bloat — 165 lines (rubric limit 100), with a
16-line ASCII directory tree and effectively 10 hard rules split
across two sections. The strongest asset is `contracts/build_vm_template.md`,
which is unusually thorough for a bootstrap-status capability and
already documents validation rules, response statuses, and open
requirements.

### CLAUDE.md findings

- `[major]` Total length is 165 lines vs. provider limit of 100 (target <80).
- `[major]` "Repo Layout" (CLAUDE.md:66–84) contains a 16-line inline
  code block; rubric flags any inline code block over 3 lines.
- `[major]` Effective hard-rule count is ~10 (5 in "Design Decisions"
  86–92 and 5 in "What Claude Should NOT Do" 146–152). Rubric target
  is 3–5, limit >7.
- `[minor]` "Secrets Policy" section (108–136) is 29 lines — at the
  per-section ceiling and contains policy detail (account names,
  passwords, rules) better lifted to `docs/standards/secrets-policy.md`
  with a one-line pointer.
- `[minor]` "Tech Stack" table (52–64) duplicates information that is
  also in the contract and in per-OS READMEs; could be replaced with a
  pointer to `windows/README.md` and a future `ubuntu/README.md`.
- `[nit]` Section ordering is fine but "Reference Documents" (154–156)
  is a placeholder (`_Add as the repo matures._`) — either populate or
  remove.
- `[nit]` Repo `README.md` is a 4-line stub from before the rename
  ("packer-image-build", "Add windows support" TODO). Not required by
  rubric for providers, but it is the GitHub landing page and now
  contradicts CLAUDE.md.

### Skill findings

No skills. Workspace has no `.claude/skills/` directory. N/A.

### Architecture alignment

- `[pass]` 3.1 No peer-to-peer communication — only one `~/providers/`
  reference (CLAUDE.md:28) and it is the workspace's own path. No
  reads/writes into other workspaces' filesystems in code.
- `[pass]` 3.2 Capabilities explicit and contracted — `capabilities.yml`
  declares `build_vm_template` with a contract path that resolves to a
  216-line file containing header, request interface (§2), response
  semantics (§3), validation rules (§4), and lifecycle (§5–7).
  `capability-deps.yml` is `consumes: []`, matching the routing-config.
- `[pass]` 3.3 Authorization structural — `allowed_callers: [lab-admin]`
  is explicit, single-tenant, with `requires_approval: true`. No
  wildcard.
- `[pass]` 3.4 Composability — contract is OS-/variant-keyed, not
  caller-keyed. `lab-admin` is mentioned as today's only caller but
  not hardwired into the request shape.
- `[fail]` 3.5 No PKA-era references — one match:
  `windows/NOTES.md:40` references `/home/scott/pka/tmp/server2025-remastered.iso`
  and `lab-admin/scripts/remaster-windows-iso.ps1` (commit d72d773).
  Historical note from 2026-04-23 incident; the path no longer reflects
  current architecture. Treat as transitional — should be relocated
  to a frozen incident log or rewritten to drop the `~/pka/` path.
  Severity: minor (documentation, not active code).
- `[pass]` 3.6 Lane discipline — provider does not consume capabilities;
  Charter section + contract §1 reinforce that image creation is the
  only owned scope.

### Capability file findings

- `[pass]` `capabilities.yml` valid, has `name`, `contract`,
  `authorization.allowed_callers`, `authorization.requires_approval`.
- `[pass]` `contracts/build_vm_template.md` resolves and is non-stub
  (216 lines, structured).
- `[pass]` `capability-deps.yml` valid (`consumes: []`) and matches
  routing-config (`capabilities_consumed: []`).
- `[pass]` Provided capabilities match routing-config
  (`build_vm_template` in both).

### Extraction candidates

- **Repo Layout** (CLAUDE.md:66–84, 19 lines incl. code block) →
  delete entirely. Tree structure is derivable from `ls`. Replace with:
  `Per-OS sources live under \`ubuntu/\` and \`windows/\`; shared assets
  in \`files/\`, sync utilities in \`scripts/\`.`
- **Secrets Policy** (CLAUDE.md:108–136, 29 lines) → `docs/standards/secrets-policy.md`.
  Replace with: `Secrets policy: real secrets via GitHub Actions only;
  baked-in default accounts (`labuser`, root, Administrator) documented
  in \`docs/standards/secrets-policy.md\`.`
- **Tech Stack table** (CLAUDE.md:52–64, 13 lines) → `docs/standards/tech-stack.md`
  or fold into `windows/README.md` + a new `ubuntu/README.md`. Replace
  with: `Stack: Packer + \`hashicorp/vsphere\` plugin; Linux uses
  cloud-init, Windows uses autounattend + optional cloudbase-init.`
- **Code Review Protocol** (CLAUDE.md:158–165) → consider folding into
  Development Guidelines or removing; the three checks are obvious from
  the rest of the file.

### Recommended actions (ordered by impact)

1. Trim CLAUDE.md to <100 lines by extracting the four sections above
   into `docs/standards/` files. (medium)
2. Consolidate the two "rules" sections (Design Decisions + What Claude
   Should NOT Do) into one 3–5 item list of true non-negotiables. The
   rest become guidance, not hard rules. (small)
3. Rewrite or relocate `windows/NOTES.md:40` to remove the `~/pka/` path
   reference. If the note is still operationally useful, keep it but
   replace the path with a description; if it is purely historical,
   move it to an `incidents/` directory or delete it. (small)
4. Refresh the repo `README.md` so the GitHub landing page matches the
   current charter and renamed repo. (small)
5. Optionally add a `docs/sops/` entry for the cloudbase-init build
   sequence — currently scattered across `windows/setup/*.ps1` script
   numbering and `windows/NOTES.md`. (medium)

### PKA-era references

- `windows/NOTES.md:40` — `/home/scott/pka/tmp/server2025-remastered.iso`
  and `lab-admin/scripts/remaster-windows-iso.ps1`. Historical
  incident note; path no longer current.
