# markitdown-mb

`markitdown-mb` is a MoonBit-first document-to-Markdown project with one
stable product pipeline:

```text
InputSource
  -> FormatDetector
  -> ParserRegistry
  -> ParseResult
  -> runtime / IRInput lowering
  -> pipeline passes
  -> RenderInput
  -> Renderer
  -> Markdown / debug JSON
```

The canonical architecture reference is
[docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md).

## Supported Formats

The main CLI supports:

- `txt`
- `csv`
- `tsv`
- `json`
- `jsonl`
- `ndjson`
- `xml`
- `yaml`
- `yml`
- `html`
- `htm`
- `markdown`
- `md`
- `zip`
- `epub`
- `docx`
- `xlsx`
- `pptx`
- `pdf`

Current format policy:

- `pdf` is product-exposed only for native-text PDFs.
- Scanned or image-only PDFs still fail closed.
- `pdf --ocr` is not supported.
- Image input is not part of the supported format list, but explicit image
  `--ocr` can use local Tesseract when requested.
- Unsupported formats fail closed. The main CLI does not route them through an
  alternate product path.

## Quick Start

Build the product CLI:

```bash
moon build cli --target native
```

Run the CLI:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/markdown/txt_plain.txt .tmp/manual/out.md
```

Native-text PDF example:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/markdown/root_native_text_baseline.pdf .tmp/manual/pdf.md
```

## Package Layout

| Package | Role |
| --- | --- |
| `cli` | main product command-line entrypoint |
| `input` | input loading plus format detection |
| `parser` | `ParserMode`, `ParseContext`, `ParserRegistry`, `ParseResult` |
| `format_readers` | low-level reader foundations that do not render Markdown |
| `formats` | registry-facing parser layer for product formats |
| `container` | shared container policy strings and path-safety helpers |
| `runtime` | parse-result lowering and child-dispatch helpers |
| `pipeline` | `CoreIRBuilder` and IR pass pipeline |
| `render` | `Renderer` implementations such as Markdown and debug JSON |
| `convert` | top-level conversion orchestration |
| `core` | canonical Core IR, diagnostics, source refs, and assets |

Architecture rules:

- `ParserRegistry` selects parsers; it does not render output.
- Every parser returns `ParseResult`.
- `IRInput` and `RenderInput` are the stable cross-layer product shapes.
- `Renderer` owns final Markdown formatting.
- `format_readers` must not depend on `runtime`, `pipeline`, `render`, or
  `convert`.

## Validation

Repo-local validation:

```bash
moon fmt
moon info
moon check
moon build
moon test
bash samples/check.sh
bash samples/check.sh --check-inventory
bash samples/helpers/contracts/check_root_contracts.sh
```

Benchmark validation now uses the binary-only `bench v2` runner:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe doctor
_build/native/release/build/bench/runner/runner.exe run --preset official-internal --limit 3
```

External quality validation:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

## Samples And Quality Lab

- `samples/main_process/` holds repo-local regression samples and expected
  outputs.
- `samples/check.sh` is the main repo-local sample gate.
- `samples/helpers/contracts/check_root_contracts.sh` is the one-shot contract
  aggregator for focused shell guards.
- `markitdown-quality-lab/` is an optional external repository used only for
  quality smoke runs through `samples/check_quality.sh`.

Implementation notes kept as stable user-facing facts:

- EPUB support is implemented through `format_readers/epub` on top of `format_readers/zip`.
- ZIP archive reading continues to rely on `bikallem/compress/flate` inside
  `format_readers/zip`.

The main repository is self-contained for normal build, test, and repo-local
sample validation. The external quality lab is not a runtime dependency.
