# markitdown-mb

`markitdown-mb` is a text-only MoonBit document-to-Markdown converter for
document ingestion, RAG, and automation. The 0.8 line shares one execution
chain between Native and Wasm; Wasm is the portable baseline and Native may add
declared FFI-backed extensions. OCR, audio transcription, scanned-page
recognition, and image recognition are outside this package boundary.

## Build and use

```text
moon build --target native --release --package ZSeanYves/markitdown
./_build/native/release/build/markitdown.exe balance input.docx output.md
```

The CLI supports `balance`, `accurate`, and `stream` where the capability
declaration allows them. It also supports Markdown, Debug, RAG, provenance,
batch, Path, Text, Bytes, and caller-owned Reader inputs through the public
`ZSeanYves/markitdown/lib` façade. Unsupported modes and formats fail closed
with a domain error.

The public API is asynchronous on both targets:

```mbt
async fn convert_example() -> Result[@lib.Output, @lib.ConvertError] {
  let input = @lib.Input::from_path("document.docx")
  @lib.convert(input, @lib.ConvertOptions::default())
}
```

## Capabilities

The shared text pipeline covers plain and delimited text, JSON/JSONL/NDJSON,
YAML, TOML, XML, HTML, Markdown, notebooks, TeX, RST, AsciiDoc, EML, ZIP,
EPUB, DOCX/XLSX/PPTX, ODT/ODS/ODP, MIME, and bounded text-layer PDF. PDF input
without a recoverable text layer returns an explicit diagnostic; no OCR route is
hidden behind that error. Document images remain exported assets and are never
treated as recognition input.

See [capabilities and limitations](docs/capabilities-and-limitations.md), the
[CLI guide](docs/cli-usage-guide.md), and the [0.8 migration guide](docs/migration-0.8.md).

## MoonX validation

The only repository-owned validation tools are pure MoonBit `.mbtx` programs:

```text
moonx tools/regression/moonx_smoke.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@0.8.0 --target wasm --suite all
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
```

The coordinate must be exact and published. The current unreleased 0.8 package
has no registry asset yet, so a MoonX download failure is an expected external
release prerequisite. Once published, the same commands run the main, quality,
accurate, PDF, asset, and latency checks without a local binary fallback.

The quality-lab checkout is read as data and is pinned by the release workflow.
Case logs and summaries are written to ignored `.tmp/moonx-*` directories.

## Repository layout

```text
main.mbt  thin executable composition root
lib/      public façade and shared product/domain packages
internal/ CLI, readers, parsers, runtime adapters, and tests
samples/  deterministic fixtures and showcase outputs
tools/    MoonX regression and benchmark entrypoints only
docs/     API, capability, architecture, and migration documentation
```

## Local source checks

MoonBit source checks remain necessary before a package can be published:

```text
moon info && moon fmt
moon check --target all --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target wasm --no-parallelize
```

These checks validate the checkout. Product behavior and release acceptance are
validated through the MoonX consumer commands above.
