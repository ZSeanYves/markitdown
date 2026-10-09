# Contributing

Keep product code and repository automation in MoonBit. The supported
automation surface is the `.mbtx` regression and benchmark programs under
`tools/regression/`; there is no Python or shell helper layer.

## Development checks

Run the source checks in a serialized order because MoonBit shares its build
lock across targets:

```text
moon info && moon fmt
moon check --target all --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target wasm --no-parallelize
moon build --target native --release --package ZSeanYves/markitdown
moon build --target wasm --release --package ZSeanYves/markitdown
```

These commands validate the checkout and release artifacts. They do not replace
the package-consumer gate.

## MoonX validation

For a behavior change, use the pinned sibling `markitdown-quality-lab` checkout
and an exact published package coordinate:

```text
moonx tools/regression/moonx_smoke.mbtx ZSeanYves/markitdown@<exact-version> --target wasm
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --target wasm --suite all
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@<exact-version> --target wasm
```

Use `--suite quality`, `--suite accurate`, `--format FORMAT`, or `--case ID`
while diagnosing one fixture, then run every affected suite. Evidence is
written under ignored `.tmp/moonx-*` directories. Before publication, a MoonX
download error is expected because the exact registry asset does not exist yet;
do not replace it with a local binary run.

## Format changes

Every format change should answer three questions in the pull request:

1. Which public capability or diagnostic changes?
2. Which deterministic fixture or quality-lab case proves the change?
3. How do Native and Wasm observe the same shared semantic result?

Add or update a small contract fixture for a new boundary. Keep third-party
samples in `markitdown-quality-lab` with their license, hash, provenance, and
manifest entry. Never change a golden only to hide lost text, structure,
assets, diagnostics, or source references.

The stable consumer import is `ZSeanYves/markitdown/lib`. Internal readers,
parser records, `DocumentIR`, pipeline contexts, and runtime adapters can be
refactored without becoming public compatibility promises.

## Scope and target rules

The 0.8 product is text-only. OCR, audio transcription, scanned-page
recognition, and image recognition are retired routes. Document images remain
exportable assets, and PDF work must preserve the bounded text-layer contract
with an explicit diagnostic for pages without recoverable text.

Wasm defines the portable baseline. Native extensions belong behind the small
target-isolated FFI boundary and must be listed in
[`docs/ffi-inventory.md`](docs/ffi-inventory.md). Do not copy the full
conversion pipeline for a target-specific implementation.

## Documentation

Update the nearest maintained document when behavior changes. Start with the
[documentation index](docs/README.md), and keep command examples aligned with
the current MoonX entrypoints. Generated interfaces and evidence files are
updated by their owning check; do not hand-edit them to make a diff disappear.
