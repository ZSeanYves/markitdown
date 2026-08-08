# Documentation Index

This directory contains the maintained product, architecture, operations, and
historical decision documentation for the unreleased 0.8 line. Start here
instead of browsing files by name.

## Product documentation

- [CLI usage](./cli-usage-guide.md): supported command shapes, modes, batch
  behavior, and troubleshooting.
- [Capabilities and limitations](./capabilities-and-limitations.md): current
  format and mode boundaries.
- [Stable API 0.8](./api-v0.8.md): the sole compatibility-stable library
  surface.
- [Migration to 0.8](./migration-0.8.md): changes required for pre-0.8 callers.
- [Environment and optional dependencies](./environment-dependencies.md):
  managed OCR, audio, accurate-PDF, and benchmark runtimes.
- [Current performance evidence](./performance.md): reproducible measurements,
  scope, environment, and interpretation limits.

## Architecture and maintenance

- [Core-chain architecture](./architecture/mb-markitdown-architecture.md)
- [Optional-enhancement architecture](./architecture/optional-enhancement-architecture.md)
- [Benchmark architecture](./architecture/benchmark-architecture.md)
- [Compatibility matrix](./compatibility-matrix.md)
- [Phase 2 compatibility lab](./phase-2-compatibility-lab.md): pinned upstream
  corpus, structural comparator, and executable semantic gates.
- [Dependency register](./dependency-register.md)
- [Maintenance and evolution plan](./project-maintenance-plan.md)

## Governance and release operations

- [Maintainer responsibilities](./maintainer-responsibilities.md)
- [Branch protection](./governance/branch-protection.md)
- [Risk register](./governance/risk-register.md)
- [Release checklist](./governance/release-checklist.md)
- [Architecture decision records](./adr/README.md)
- [RFC template](./rfcs/0000-template.md)

## Document lifecycle

Documents in the lists above are current and must change with the behavior they
describe. Accepted ADRs are historical records: supersede them with another ADR
instead of rewriting the original decision. Fixture `*.expected.md`, showcase
`result.md`, benchmark JSON, and generated interfaces are evidence artifacts,
not narrative documentation.

Obsolete development-line guides are removed rather than left beside current
instructions. Git history remains the archive. `tools/governance/check_documentation.py`
checks local links, the root README mirror, retired paths, and stale benchmark
claims in CI.
