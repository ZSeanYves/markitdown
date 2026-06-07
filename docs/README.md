# Documentation

This directory is the current documentation set for `markitdown-mb`.

The top-level pages describe the product state that maintainers should rely on
today. Historical planning notes and long audit fragments were removed from the
main documentation path so they do not read like current runtime contracts.

## Current Docs

* [Architecture](./architecture.md): package boundaries, runtime flow, and
  parser/converter responsibilities.
* [Supported formats](./supported-formats.md): current format support and
  explicit limits.
* [Quality and release](./quality-and-release.md): validation entrypoints,
  optional quality-lab usage, and release-readiness checks.
* [Performance](./performance.md): benchmark entrypoint and interpretation
  rules.
* [Roadmap](./roadmap.md): near-term work after the DOCX v2 runtime switch.

## Working Ledgers

These three files remain top-level because they are active inputs for future
parser/model/converter rewrites:

* [Parser defects](./parser-defects.md)
* [Format limits](./format-limits.md)
* [Convert defects](./convert-defects.md)

They are internal ledgers, not user-facing support claims.

## Archive

[docs/archive/](./archive/) is intentionally small. It is for architecture
contracts and historical contracts that still matter when rewriting a format.

Current archived contract:

* [DOCX architecture contract](./archive/docx-architecture.md)

DOCX v2 is the current runtime path. The archived contract records the source
model and lowering boundary that replaced the old v1 scanner path.

## Quality Comparisons

[docs/quality-comparisons/](./quality-comparisons/README.md) is preserved as
the quality comparison notebook area. It was not cleaned up in this pass and
will be updated separately.
