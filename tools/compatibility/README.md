# Phase 2 Compatibility Lab

This directory is the executable contract surface for Phase 2 of the
maintenance plan. It is deliberately separate from the product packages and
from the external quality-lab repository.

`contract-manifest.json` pins the Microsoft MarkItDown `v0.1.7` tag and commit,
maps each enrolled case to a local or reference-only fixture, and declares the
input kinds, hints, modes, expected signals, tier, and reviewed difference
classification. `difference-categories.json` defines the only classifications
accepted by review. A case without a classification, or a classification not
present in that file, is a hard failure.

The local cases are project-owned equivalents because the upstream repository's
test binaries are MIT-licensed but are not part of this source distribution.
The upstream file name and pinned commit remain recorded so a clean checkout
can retrieve and audit the reference. Reference-only cases intentionally prove
that XLS, binary Outlook MSG, and RSS are unsupported rather than silently
claiming compatibility.

Fetch and verify the exact upstream binaries (they are never committed):

```bash
python3 tools/compatibility/fetch_upstream_corpus.py
```

Run the manifest gate without a MoonBit build:

```bash
python3 tools/compatibility/check_contract_manifest.py
```

Run executable local semantic checks after building the native CLI:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
python3 tools/compatibility/run_contract_lab.py \
  --cli ./_build/native/release/build/cli/cli.exe
```

The runner executes every declared mode and compares structural fields
(headings, paragraphs, tables, links, assets, math markers, and diagnostics)
independently. It never turns an unexplained difference into a new golden
automatically. Path/Bytes/Reader and hint dimensions are exercised by the
native integration contract in `src/internal/integration_tests`.

For the upstream comparison, install the pinned reference environment from
`tools/env/optional_deps.sh install bench`, then pass both `--upstream` and
`--upstream-corpus`. The runner fails on any structural field not recorded in
the case's reviewed classification.
