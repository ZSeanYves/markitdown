# ADR 0007: MoonX consumer verification and text mode boundary

## Status

Accepted for the unreleased 0.8 text-only line.

## Decision

There is one external validation path: pure MoonBit `.mbtx` entrypoints run the
published package through MoonX. `moonx_smoke.mbtx` checks the consumer surface,
`run_moonx_regression.mbtx` runs the main, quality, and accurate manifests, and
`moonx_benchmark.mbtx` records a fixed consumer timing sample. None of these
entrypoints invokes a local binary, shell adapter, Python process, or registry
compatibility shim.

The exact coordinate is mandatory. An unpublished package is expected to fail
before case execution because MoonX cannot download its artifact. That failure
is retained as a release prerequisite; it must not be masked by falling back to
the checkout.

The text conversion modes remain separate from output views:

- `balance` is the safe default semantic route.
- `accurate` requests declared higher-fidelity Office/ODF/PDF text recovery.
- `stream` controls bounded pull/backpressure behavior with the same text
  meaning.
- Markdown, Debug, RAG, and provenance are output views.

Removing OCR and audio removes multimodal routes, model setup, and their test
corpora. It does not remove the text modes or the output views needed by
document ingestion and RAG. Unsupported combinations continue to fail closed.

Wasm is the common capability baseline. Native may add explicitly declared FFI
extensions, but the parser, IR, semantic pipeline, renderer, assets, and source
tracking remain one implementation.
