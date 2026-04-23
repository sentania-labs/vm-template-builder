
## 2026-04-23 06:18 — windows packer 1.11 pin

**Type:** status
**Needs Scott:** false

### What I did
- Relaxed `required_version` in `windows/windows.pkr.hcl` from `>= 1.11.2` to `>= 1.11.0, < 1.12.0` so the template runs on whatever 1.11.x the self-hosted runners have.

### What I learned
- Nothing else in the Windows template is Packer-1.12-specific (`reattach_cdroms`, `cd_content`, content_library_destination, vsphere plugin 1.4.2 pin are all fine on Packer 1.11.x).

### What's next or blocked
- Asked Scott whether the vsphere plugin pin should also be tightened to a 1.11-compatible range; awaiting answer. No CI change made.
