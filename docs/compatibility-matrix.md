# Compatibility matrix

The supported product platforms are Linux x86_64 and macOS arm64 using the
Native backend. There is one conversion implementation. Wasm, Wasm-GC and
JavaScript product targets are retired.

This table defines required compatibility evidence; a row is not a claim
that all platform or release checks have passed.

| Surface | Contract | Validation |
| --- | --- | --- |
| Public library | Async `lib.convert`, versioned façade, Path/Text/Bytes and sync/async Reader constructors | Generated interface and independent Native consumer |
| Plain/structured text and markup | Existing content, ordering, metadata and declared recovery behavior | Main and quality corpus; affected unit tests |
| MIME, ZIP and EPUB | Container order, safe paths, integrity, attachments/assets and sources | Main/quality corpus and resource failures |
| Office/ODF | Balance semantics plus declared accurate/stream behavior, notes, links, cached values and images | Main, quality and accurate corpus |
| Text-layer PDF | Text, geometry, reading order, annotations, links and supported images; explicit text-layer/encryption failure | Per-file PDF contracts, including mandatory hard cases |
| Markdown/Debug/RAG/provenance | Stable body, structure, diagnostics, source and asset references | Separate output-channel assertions and structural RAG checks |
| Collecting/Sink delivery | Equivalent promised semantics and bounded delivery where implemented | Short reads, backpressure, cancellation and write failures |
| CLI | stdin, single file, serial batch, output views and error exit classes | Installed Native artifact and full regression |
| Recognition inputs | OCR, audio transcription and scanned-page recognition remain unsupported | Explicit capability/error contract |

Supported modes are listed in the
[format matrix](capabilities-and-limitations.md). `stream` does not permit
dropping content or weakening resource checks. Existing internal Sink routes
do not establish completion of the planned public `convert_to_sink` or the
single async Reader/Registry/pull protocol.

## Reproducible checks

`run_native_regression.mbtx` checks the pinned independent quality-lab
checkout against a supplied actual Native executable:

```text
moon run --target native tools/regression/run_native_regression.mbtx -- --binary /absolute/path/to/markitdown --lab /absolute/path/to/markitdown-quality-lab --suite all --evidence /absolute/path/to/new-evidence
```

Use `native_install.mbtx` for local, fixed Git and post-publication exact
version installation plus an independent public-library consumer. See
[regression tooling](../tools/regression/README.md) for the CLI and outputs.

Record the source commit and dirty state, exact dependencies/toolchain,
executable hash, platform and corpus hashes. All valid rows execute;
`reference` is not a skip. Expected failures require an explicit error
contract. Missing or malformed manifests and zero executed cases cannot pass.

The [Native plan](architecture/native-performance-plan.md) remains the
acceptance authority. P2–P4 are unfinished implementation/quality gates;
P5 requires both platforms, performance and reliability workloads. P6
requires exact-version installation after publication. Current local tests
or an inventory-only run do not close those gates.
