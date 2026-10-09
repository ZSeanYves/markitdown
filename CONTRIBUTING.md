# Contributing

Keep product code and repository tooling in MoonBit. The repository has no
Python or shell helper layer. MoonBit source checks validate the checkout, while
the external product contract is always exercised by MoonX.

```text
moon fmt --check
moon info && git diff --exit-code
moon check --target all --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target wasm --no-parallelize
moon build --target native --release --package ZSeanYves/markitdown
moon build --target wasm --release --package ZSeanYves/markitdown
```

For behavior changes, check out the pinned
`markitdown-quality-lab` repository and run the exact MoonX package consumer:

```text
moonx tools/regression/moonx_smoke.mbtx ZSeanYves/markitdown@<exact-version> --target wasm
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --target wasm --suite all
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@<exact-version> --target wasm
```

Use `--suite quality`, `--suite accurate`, `--format FORMAT`, or `--case ID`
while diagnosing a fixture, then run the complete affected suite. Evidence is
written under `.tmp/moonx-*`. An unpublished coordinate is expected to fail at
the MoonX download boundary before 0.8 publication and cannot be replaced by a
local binary run.

Changes to format behavior should add or update a deterministic contract
fixture and explain the semantic choice. Third-party samples belong in the
quality-lab checkout with license, hash, provenance, and manifest signals.
Never change a golden merely to hide lost text, structure, assets, diagnostics,
or source references.

OCR, audio transcription, and scanned-page recognition are retired. PDF work
must preserve the bounded text-layer contract and explicit diagnostics for
pages without recoverable text.
