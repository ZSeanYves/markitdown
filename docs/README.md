# Documentation Map

This directory contains the repository's current product, validation, and
design documentation.

Use these pages as the primary current-state entrypoints:

* [README](../README.md)
  Concise repository positioning, sealed scope, validation surface, and
  non-goals.
* [Support and Limits](./support-and-limits.md)
  Per-format support contract, boundaries, and non-goals.
* [Validation and Benchmark Summary](./validation-and-benchmark-summary.md)
  Current checked validation counts and representative benchmark facts.
* [Architecture](./architecture.md)
  Repository structure, lower-layer boundaries, and main pipeline design.
* [Second-Round Summary](./second-round-summary.md)
  Concise sealed-scope project summary plus post-seal hardening notes.
* [doc_parse Foundation Contract](./doc-parse-foundation.md)
  Reusable lower-layer package contract for the current container, document,
  simple-format, and XML parser foundation lines under `doc_parse/*`.
* [doc_parse Package Strategy](./package-publishing-strategy.md)
  Current subpackage delivery strategy, future module-split criteria, and
  nested-module warning.
* [Development Guide](./development.md)
  Maintainer workflow, validation commands, and format-onboarding practice.

Supporting reference sets:

* [Quality Comparisons](./quality-comparisons/README.md)
  Human-readable comparison records against Microsoft MarkItDown.
* [Benchmark Governance](./benchmark-governance.md)
  Runner, corpus, and comparability rules for benchmark claims.
* [Metadata Sidecar](./metadata-sidecar.md)
  Sidecar schema and field-fill notes.
* [Text Normalization Conformance Plan](./text-normalization-conformance.md)
  Explicit canonical normalization verification strategy and caveats for the
  non-default facade APIs.

Historical and planning records:

* [Text Normalization Migration Plan](./text-normalization-migration-plan.md)
  Migration history and current boundary notes after the rule-driven rollout.
* [Format Excellence Roadmap](./format-excellence-roadmap.md)
  Historical second-round framework and sealed-scope vocabulary.
* [Progress Summary](./progress.md)
  Historical project-state snapshot retained for traceability.
* [Benchmark H3 Plan](./benchmark-h3-plan.md)
  Historical phase-planning note; current benchmark facts live elsewhere.
* [PDF H2++ Readiness Audit](./pdf-h2pp-readiness-audit.md)
  Historical pre-closure audit for the native text-PDF scope.

Historical and process-oriented notes in this directory are kept for audit
traceability, but they should not be treated as the primary source of truth
when a current-state page above already covers the same area.
