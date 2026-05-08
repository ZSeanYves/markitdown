# Documentation Map

This directory contains the repository's current product, validation, and
design documentation.

Use these pages as the primary current-state entrypoints:

* [Support and Limits](./support-and-limits.md)
  Per-format support contract, boundaries, and non-goals.
* [Validation and Benchmark Summary](./validation-and-benchmark-summary.md)
  Current checked validation counts and representative benchmark facts.
* [Architecture](./architecture.md)
  Repository structure, lower-layer boundaries, and main pipeline design.
* [Development Guide](./development.md)
  Maintainer workflow, validation commands, and format-onboarding practice.
* [Text Normalization Migration Plan](./text-normalization-migration-plan.md)
  Current shared-cleanup rollout and remaining migration boundaries.
* [Text Normalization Conformance Plan](./text-normalization-conformance.md)
  Explicit canonical normalization verification strategy and caveats.

Supporting reference sets:

* [Second-Round Summary](./second-round-summary.md)
  Stable sealed-scope summary for H2++ / H3++ format status.
* [Quality Comparisons](./quality-comparisons/README.md)
  Human-readable comparison records against Microsoft MarkItDown.
* [Benchmark Governance](./benchmark-governance.md)
  Runner, corpus, and comparability rules for benchmark claims.
* [Metadata Sidecar](./metadata-sidecar.md)
  Sidecar schema and field-fill notes.

Historical and process-oriented notes in this directory are kept for audit
traceability, but they should not be treated as the primary source of truth
when a current-state page above already covers the same area.
