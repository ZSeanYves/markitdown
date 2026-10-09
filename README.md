# markitdown

MoonBit-native document-to-Markdown conversion for text extraction, content
ingestion, and RAG preparation. The 0.8 line uses one execution chain for
Native and Wasm: Wasm is the portable baseline, while Native can add only
declared low-level extensions.

The product boundary is text-only. It preserves text, structure, metadata,
source locations, and document image assets. OCR, scanned-page recognition,
audio transcription, and image recognition are outside this package.

> **0.8 status:** the package is still unreleased. The MoonX commands below
> use the final coordinate as a contract and will start working after the
> matching registry asset is published.

## Install

After publication, add the stable façade to a MoonBit project:

```text
moon add ZSeanYves/markitdown@0.8.0
```

Import `ZSeanYves/markitdown/lib`. Internal readers, parser records, the IR,
and runtime adapters are implementation details and are not part of the
consumer API.

## Quick start

Build the CLI from a checkout:

```text
moon build --target native --release --package ZSeanYves/markitdown
./_build/native/release/build/markitdown.exe balance input.docx output.md
```

The stable library entrypoint is asynchronous on both targets:

```mbt
import {
  "ZSeanYves/markitdown/lib",
}

async fn convert_example() -> Result[@lib.Output, @lib.ConvertError] {
  let input = @lib.Input::from_path("document.docx")
  @lib.convert(input, @lib.ConvertOptions::default())
}
```

The façade accepts paths, text, bytes, and caller-owned readers. It returns
facade-owned output, diagnostics, provenance, source maps, assets, and RAG
chunks; community ASTs and FFI handles do not cross the boundary.

## Packages

- `lib`: the stable consumer façade and shared product models.
- `lib/formats`: format parsers and lowering into the shared document IR.
- `lib/render`: Markdown, Debug, and RAG output views.
- `internal/readers`: bounded ZIP, XML, Office, ODF, EPUB, PDF, and text
  preparation.
- `internal/parser`, `internal/pipeline`, `internal/runtime`: the registry,
  semantic passes, resource coordination, and target-isolated host boundary.
- `tools/regression`: the MoonX `.mbtx` consumer and benchmark entrypoints.

## Capabilities

The shared route is:

```text
Input → detect → capability check → reader/parser → ParseResult
      → shared IR/pipeline → Markdown, Debug, RAG, or controlled Sink
```

| Area | Wasm | Native |
| --- | --- | --- |
| Plain and structured text | Shared support | Shared support |
| Markdown, HTML, XML, TeX, RST, AsciiDoc | Shared support | Shared support |
| JSON/JSONL, YAML, TOML, CSV/TSV | Shared support | Shared support, with declared encoding extensions where available |
| MIME, EML, ZIP, EPUB | Shared support | Shared support |
| DOCX, XLSX, PPTX, ODT, ODS, ODP | Shared support | Shared support |
| Text-layer PDF | Bounded shared contract | Same contract plus declared Native extensions |
| Document image assets | Exported when safely recoverable | Exported when safely recoverable |
| OCR, scanned-page recognition, audio transcription | Unsupported | Unsupported |

The complete format matrix, mode boundaries, resource limits, and failure
diagnostics are in [Capabilities and limitations](docs/capabilities-and-limitations.md).
In particular, a PDF without a recoverable text layer reports a diagnostic;
the converter never silently invokes OCR. `accurate` keeps its Office/ODF
semantic meaning and selects the bounded text route for PDF. `stream` is
available only for formats that declare a controlled streaming route.

The main product features are:

- [x] **[portable] Unified asynchronous conversion** — one detector, registry,
  parser protocol, IR, pipeline, renderer, and output boundary.
- [x] **[portable] Text and document formats** — structured text, markup,
  MIME/EML, ZIP/EPUB, Office, ODF, and bounded text-layer PDF.
- [x] **[portable] Ingestion views** — Markdown, Debug, RAG, provenance,
  source maps, and bounded document assets.
- [x] **[native] Declared host extensions** — isolated FFI for capabilities that
  have no equivalent portable implementation.
- [x] **[portable] Fail-closed limits** — malformed input, unsafe archives,
  invalid encodings, missing text layers, and resource exhaustion produce
  diagnostics instead of an implicit fallback.

## Outputs and modes

- `balance` is the default conversion mode.
- `accurate` enables additional Office/ODF semantic recovery and the declared
  PDF text policies.
- `stream` selects a bounded streaming or pull route where the format supports
  it; it does not change the promised Markdown meaning.
- Markdown is the default view. `--debug`, `--rag`, provenance, source maps,
  and materialized assets are available at the output boundary.

Unsupported formats and modes fail closed with typed domain errors. Image and
audio inputs are detected for stable diagnostics and never start an external
recognizer.

## Examples

- [CLI usage guide](docs/cli-usage-guide.md) — single-file, batch, output
  views, modes, and diagnostics.
- [Core conversion showcase](samples/showcase/README.md) — reviewed examples
  across the supported input families.
- [Stable API example](docs/api-v0.8.md) — a checked MoonBit consumer shape for
  the `lib` façade.

## MoonX consumer validation

The repository-owned product validation path runs the published package through
MoonX. It does not substitute a local binary, a worktree, or an unpinned
coordinate:

```text
moonx tools/regression/moonx_smoke.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@0.8.0 --target wasm --suite all
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
```

The regression runner reads the pinned `markitdown-quality-lab` checkout and
records per-case logs and summaries under ignored `.tmp/moonx-*` directories.
See [MoonX regression](tools/regression/README.md) for suite selection and
failure evidence.

Before publication, a package download failure is an expected missing-registry
asset. It is not evidence that a local compatibility runner should be added.

## Repository layout

```text
main.mbt       thin executable composition root
lib/           stable façade and shared product packages
internal/      CLI, readers, parser registry, pipeline, runtime, and tests
tools/         MoonX regression and benchmark entrypoints (.mbtx only)
samples/       deterministic fixtures and reviewed showcase inputs
docs/          API, capability, architecture, migration, and release docs
```

Start with the [documentation index](docs/README.md). Contributors should read
[CONTRIBUTING.md](CONTRIBUTING.md) before changing parser behavior or fixtures.

## Contributor checks

These commands validate the checkout and build artifacts; package-consumer
behavior is accepted through the MoonX commands above:

```text
moon info && moon fmt
moon check --target all --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target wasm --no-parallelize
```

All repository automation is MoonBit. There is no Python or shell helper layer,
runtime installer, model download, or external converter requirement.

## License

Apache-2.0. See [LICENSE](LICENSE).
