# Phase 2 Compatibility Lab

Phase 2 turns compatibility from a narrative claim into a reviewed, repeatable
contract. The reference is Microsoft MarkItDown `v0.1.7` at commit
`fd239d5d2be43d9b68329730206b9312c7d5a388`. The reference repository is MIT
licensed; its binary test files are not copied into this repository. Instead,
the project stores deterministic local equivalents where redistribution and
provenance are clear, and records the exact upstream file name for audit.

The machine-readable contract lives in
`tools/compatibility/contract-manifest.json`. Each case specifies a format
tier, local fixture or reference-only status, SHA-256 when local, input kinds,
hint dimensions, modes, structural signals, and one reviewed difference
category.

The only accepted categories are defined in
`tools/compatibility/difference-categories.json`: `bug`,
`upstream_feature_missing`, `expected_enhancement`, `undefined_behavior`, and
`unsupported_by_design`. An unclassified difference cannot update a golden and
fails the manifest gate.

## Current Results

The local executable lab runs 15 representative cases across DOCX,
PPTX, XLSX, PDF, HTML, CSV, JSON, XML, IPYNB, ZIP, and EPUB. The checked cases
cover OMML preservation diagnostics, cached PPTX chart lowering, chart
fallback behavior, SVG asset policy, and non-empty conversion for the remaining
formats. The native run executes 28 local mode cases. A second invocation can
fetch the 17 exact upstream v0.1.7 binary fixtures (15 executable plus two
reference-only web fixtures), compare the same structural fields against the
official CLI, and currently passes 15/15 executable upstream samples.

Three upstream scenarios remain explicit reference-only gaps:

| Scenario | Product status | Stable behavior |
| --- | --- | --- |
| Legacy XLS/BIFF | unsupported | capability status `Unsupported`; no parser alias; follow-up [#155](https://github.com/ZSeanYves/markitdown/issues/155) |
| Binary Outlook MSG | unsupported | `msg` is RFC822/EML-only; binary input is not claimed compatible; follow-up [#156](https://github.com/ZSeanYves/markitdown/issues/156) |
| RSS/Atom and URI/web converters | unsupported in core | no network access; capability status `Unsupported`; follow-up [#157](https://github.com/ZSeanYves/markitdown/issues/157) |

These are intentionally not represented by an EML alias or a network fallback.
They remain in the manifest so an accidental capability expansion is visible.
Reference-only web fixture hashes are retained for provenance, and are never
executed as network converters.

Run the gates from a clean checkout:

```bash
python3 tools/compatibility/check_contract_manifest.py
python3 tools/compatibility/fetch_upstream_corpus.py
moon build --target native --release --package ZSeanYves/markitdown/cli
python3 tools/compatibility/run_contract_lab.py \
  --cli ./_build/native/release/build/cli/cli.exe
python3 tools/compatibility/run_contract_lab.py \
  --cli ./_build/native/release/build/cli/cli.exe \
  --upstream ./env/.venv-markitdown-bench/bin/markitdown \
  --upstream-corpus ./.tmp/compatibility/upstream-v0.1.7
```

The lab is a semantic gate, not a byte-for-byte promise. Markdown structure is
compared by field, while project provenance, diagnostics, source maps, and
asset metadata are checked independently. A changed expected output requires a
classified difference and a written decision in the same PR.
