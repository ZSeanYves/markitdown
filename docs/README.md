# Documentation index

The 0.8 documentation is organized by the question a reader is trying to
answer. Product users can start with the root [README](../README.md); this page
is the map for API consumers, contributors, and release reviewers.

## Start here

| Need | Read |
| --- | --- |
| Understand supported formats and boundaries | [Capabilities and limitations](./capabilities-and-limitations.md) |
| Run the command line interface | [CLI usage guide](./cli-usage-guide.md) |
| Call the library from MoonBit | [Stable API 0.8](./api-v0.8.md) |
| Move a pre-0.8 integration | [Migration to 0.8](./migration-0.8.md) |
| Validate a published package through MoonX | [MoonX regression](../tools/regression/README.md) |

## Product and API

- [Environment and runtime dependencies](./environment-dependencies.md) — the
  MoonBit-only build boundary and the Native/Wasm split.
- [Compatibility matrix](./compatibility-matrix.md) — target, mode, and format
  coverage in one table.
- [Performance evidence](./performance.md) — reproducible measurements,
  baselines, and interpretation limits.
- [Release-candidate acceptance](./release-candidate.md) — Linux/macOS,
  Native/Wasm, and post-publication consumer checks.

## Architecture

- [Core-chain architecture](./architecture/mb-markitdown-architecture.md) —
  detection, routing, parsing, IR, pipeline, rendering, and output.
- [MoonX package architecture](./architecture/markitdown-package-architecture.md) —
  the `main.mbt` / `lib` / `internal` package boundary.
- [Benchmark architecture](./architecture/benchmark-architecture.md) — how
  package-consumer measurements are collected without a second execution path.
- [Native FFI inventory](./ffi-inventory.md) — every target-isolated extension,
  ownership rule, and removal condition.
- [Dependency register](./dependency-register.md) — direct and transitive
  dependencies, licenses, target support, and adoption decisions.

## Maintenance and governance

- [Contributing](../CONTRIBUTING.md) — source checks, MoonX validation, fixtures,
  and review expectations.
- [Maintainer responsibilities](./maintainer-responsibilities.md) — ownership
  and evidence requirements.
- [Release checklist](./governance/release-checklist.md) — the final acceptance
  gates.
- [Risk register](./governance/risk-register.md) — open product and release
  risks.
- [Architecture decision records](./adr/README.md) — accepted historical
  decisions and their supersession links.
- [RFC template](./rfcs/0000-template.md) — format for new proposals.

## Migration and research records

The following documents preserve decisions and experiment results that explain
why the current implementation looks the way it does:

- [Native/Wasm upgrade progress](./native-wasm-upgrade.md)
- [Text extraction scope and community package assessment](./rfcs/0001-text-extraction-scope-and-community-packages.md)
- [Phase 2 compatibility lab](./phase-2-compatibility-lab.md)
- [Maintenance and evolution plan](./project-maintenance-plan.md)

These records are evidence, not additional runtime entrypoints. Current
commands are the MoonBit source checks and the MoonX `.mbtx` consumer checks
documented above. Historical ADRs and audit notes may retain the commands that
were used at the time; they do not describe a supported workflow today.

## Document lifecycle

Behavioral documentation must change with the public contract. Generated
interfaces, fixture goldens, showcase results, benchmark data, and CI artifacts
are evidence files rather than narrative documentation. Accepted ADRs remain
immutable historical records; supersede a decision with a new ADR instead of
rewriting the old one.
