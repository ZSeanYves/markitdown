# Documentation Map

This directory contains the repository's current product, benchmark, and design
documentation.

## Current Source Of Truth

Use these pages first:

* [README](../README.md)
  Concise repository positioning, validation entrypoints, and non-goals.
* [Acceptance Checklist](./acceptance-checklist.md)
  Release-facing acceptance checklist.
* [Architecture](./architecture.md)
  Repository structure, lower-layer boundaries, and main pipeline design.
* [Support and Limits](./support-and-limits.md)
  Per-format support contract, boundaries, and non-goals.
* [doc_parse Foundation Contract](./doc-parse-foundation.md)
  Architecture-facing status matrix, package boundaries, and candidate-line
  strategy for the current `doc_parse/*` foundation line.
* [Performance](./performance.md)
  Current performance layers, measured baseline, attribution coverage, and
  remaining follow-up work.
* [Roadmap](./roadmap.md)
  Current release work, later work, and non-goals.
* [Benchmarking](./benchmarking.md)
  Recommended benchmark commands, helper status, and output directories.
* [Metadata Sidecar](./metadata-sidecar.md)
  Sidecar schema and field-fill notes.
* [Text Normalization Conformance](./text-normalization-conformance.md)
  Explicit canonical normalization verification strategy and caveats for the
  non-default facade APIs.
* [doc_parse Package Strategy](./package-publishing-strategy.md)
  Current in-tree subpackage delivery strategy and future module-split
  criteria.
* [Development Guide](./development.md)
  Maintainer workflow, validation commands, and format-onboarding practice.

## Supporting References

* [Quality Comparisons](./quality-comparisons/README.md)
  Human-readable comparison records against Microsoft MarkItDown.

## Historical Records

Historical planning, audit, benchmark, normalization, and milestone documents
now live under [docs/archive/](./archive/README.md).
