# Maintainer Responsibilities

## Ownership map

The repository owner is currently `@ZSeanYves`. Until a backup maintainer is
assigned, areas marked “backup needed” are experimental for new behavior and
cannot receive a new 1.0 stability promise.

| Area | Primary | Backup | Required duties |
| --- | --- | --- | --- |
| Project/release | @ZSeanYves | backup needed | roadmap, version, release, rollback and support window |
| API/core/input/product | @ZSeanYves | backup needed | façade, typed errors, resource policy and compatibility |
| Formats/readers | @ZSeanYves | backup needed | format contracts, fixtures, semantic review and limitations |
| Runtime/FFI/security | @ZSeanYves | backup needed | C stubs, external commands, sanitizer, threat response |
| Quality/performance | @ZSeanYves | backup needed | differential corpus, coverage, benchmark and drift reports |
| Dependencies/licenses | @ZSeanYves | backup needed | registry review, SBOM, NOTICE and upgrade/rollback |

## Review rules

- R0/R1 changes need one owner review.
- R2 changes need the affected format owner and quality owner.
- R3 changes need two approvals, including API, security, runtime or release
  ownership as appropriate.
- A reviewer may not approve a change that modifies a golden output without a
  structured semantic explanation.
- A maintainer must be able to reproduce the relevant check from a clean
  checkout before merging.

## Bus-factor action

Before 1.0, nominate at least one backup for core/API and one for
runtime/security. Each backup must perform a release dry run and a native
sanitizer run independently. The project must not move from 0.9 to 1.0 until
every R3 area has a primary and backup.
