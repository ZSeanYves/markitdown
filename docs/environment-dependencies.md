# Environment and benchmark dependencies

The 0.8 conversion path is pure MoonBit and does not install Python, OCR or
audio models, Tesseract, FFmpeg, Poppler, or another external recognizer. Image
and audio inputs are detected and return `UnsupportedCapability`; PDFs without
a recoverable text layer return a diagnostic.

Python is accepted only as a reproducible build and benchmark dependency for
the external MarkItDown comparison. It is never imported or launched by the
conversion library.

## Benchmark setup

Install the pinned benchmark environment with the single maintained installer:

```bash
./tools/env/installers/install_bench_baseline_deps.sh
./tools/env/installers/install_bench_baseline_deps.sh --python /path/to/python3.11
```

The supported interpreter range is `>=3.10,<3.14`. The lock file is
`tools/env/config/python/bench.lock`, and its MarkItDown oracle is pinned to
`0.1.7`. The installer is optional and is not needed to build or run the
MoonBit product.

## Native and Wasm boundaries

Native and Wasm share detection, routing, readers, the document IR, rendering,
RAG, assets and source tracking. Native-only code is limited to process and
atomic filesystem extensions used by tooling. The Wasm build fails closed when
one of those extensions is requested; it does not buffer unbounded input or
silently invoke a host process.

See [capabilities and limitations](./capabilities-and-limitations.md) for the
format contract and [native/Wasm upgrade](./native-wasm-upgrade.md) for the
evidence and remaining release gates.
