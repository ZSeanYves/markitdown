# ADR 0005: Official Compatibility Laboratory and Capability Tiers

- Status: accepted
- Date: 2026-08-08
- Owners: @ZSeanYves
- Related: Phase 2 of `docs/project-maintenance-plan.md`

## Context

Phase 0-1 froze the MarkItDown `v0.1.7` reference and created a stable API,
but compatibility evidence was split between local fixtures and the external
quality lab. There was no repository-owned manifest that required input-kind,
hint, mode, structural fields, and an explicit difference decision for each
case. In particular, the upstream fixes for DOCX equations, PPTX charts and
SVG-only pictures could not be audited as one contract.

## Decision

Create `tools/compatibility/` as the Phase 2 compatibility laboratory.

- Pin the upstream tag and commit in `contract-manifest.json`.
- Use deterministic project-owned equivalents for local executable cases and
  record the upstream test filename, source kind, license and fixture hash.
- Keep XLS/BIFF, binary Outlook MSG and RSS/URI converters reference-only and
  explicitly unsupported in the core capability manifest.
- Compare headings, paragraphs, tables, links, assets, math and diagnostics as
  separate fields. A structural difference must have one of the five reviewed
  categories in `difference-categories.json`; no automatic golden updates.
- Run local cases in every declared mode, and run the upstream `0.1.7` CLI when
  its managed benchmark environment is installed. The local native integration
  tests cover Path/Bytes/Reader and MIME/extension/no-hint detection.

## Consequences

The Phase 2 lab can report semantic compatibility without requiring byte-for-
byte Markdown identity. Existing project enhancements such as provenance and
diagnostic sections remain independently testable. Some local equivalents are
classified `undefined_behavior` until a direct upstream fixture or explicit
contract decision is available; they cannot be silently promoted to stable
goldens.

## Verification and rollback

```bash
python3 tools/compatibility/check_contract_manifest.py
python3 -m unittest discover -s tools/compatibility/tests -p 'test_*.py'
moon check --target all --warn-list +73 --deny-warn
moon test --target native --package ZSeanYves/markitdown/internal/integration_tests --filter 'phase2*'
python3 tools/compatibility/run_contract_lab.py --cli ./_build/native/release/build/cli/cli.exe
```

Rollback removes the Phase 2 CI steps and compatibility directory while
preserving the Phase 0-1 API and architecture gates. No product package imports
the laboratory.
