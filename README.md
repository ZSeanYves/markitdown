# markitdown-mb

`markitdown-mb` is a MoonBit-first document-to-Markdown tool designed for engineering-grade workloads.

The project was originally inspired by Microsoft's MarkItDown: convert common document formats into stable, consumable Markdown. The current implementation follows that goal, but places stronger emphasis on a unified product path, verifiable benchmarking, and fail-closed product boundaries.

The overall architecture has now fully migrated to the unified `v2` pipeline. In practice, this means the product does more than simply "convert supported formats": it also preserves richer semantics, diagnostics, source refs, and provenance along the same execution path.

The canonical product path is:

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

For the architectural reference, see [docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md). For capability boundaries and known limitations, see [docs/capabilities-and-limitations.md](./docs/capabilities-and-limitations.md).

## Why This Project

The focus of the current release is not unconstrained format expansion. It is to make the officially supported paths trustworthy, measurable, and reproducible.

- Performance: official benchmarking uses `bench v2`, which measures only release binaries and real product paths. For formats that better represent the complex document pipeline, reproduced official compare results currently show:

  | Format | CLI speedup vs markitdown |
  | --- | --- |
  | `docx` | `88.09x` |
  | `xlsx` | `30.75x` |
  | `epub` | `18.07x` |
  | `pdf` | `30.60x` |

  For `txt`, `csv`, `tsv`, and `json`, the implementation is not trading away semantics or diagnostics just to widen benchmark gaps. It still keeps the full product-path information and output constraints, so the margin is often less dramatic, while remaining faster under the formal benchmark definition.
- Medium-to-large files and stress cases: the unified `v2` path is more stable on larger inputs. On some stress samples where the external baseline cannot form a complete comparable set, the MoonBit path can still complete conversion successfully. These claims can be reproduced directly with `bench v2` compare runs on specific rows.
- Memory profile: in the current tracked benchmark samples, the median peak RSS for `moonbit-cli` is approximately `48,328 KB`, compared with `176,640 KB` for `markitdown`. Public-facing summaries still prioritize performance and trust guarantees; for full memory details, inspect the run artifacts directly.
- Stability: benchmarking includes provenance, route coverage, and fidelity gates. Missing provenance, route mismatches, or `route_fidelity_status != matched` immediately invalidate trust for the MoonBit case.
- Clear boundaries: unsupported formats fail closed. The product does not rely on hidden fallback paths to present a false success surface.

All of the statements above can be regenerated from the benchmark commands below and do not depend on any fixed run id.

## Support Matrix

The main CLI currently supports:

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

- `pdf` is officially supported only for native-text PDFs.
- Scanned or image-only PDFs still fail closed.
- `pdf --ocr` is not supported.
- Default image input is not part of the formal support matrix, but explicit image `--ocr` can use local Tesseract.
- Unsupported formats fail closed.

For more detailed capability coverage, limitations, OCR boundaries, and container semantics, see [docs/capabilities-and-limitations.md](./docs/capabilities-and-limitations.md).

## Quick Start

Build the CLI:

```bash
moon build cli --target native
```

Show help:

```bash
./_build/native/debug/build/cli/cli.exe --help
```

Minimal conversion example:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/markdown/txt_plain.txt .tmp/manual/out.md
```

Native-text PDF example:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/markdown/root_native_text_baseline.pdf .tmp/manual/pdf.md
```

## OCR

Current OCR support is based on local `Tesseract` and does not depend on a cloud model.

macOS / Homebrew:

```bash
brew install tesseract
brew install tesseract-lang
```

Current boundaries:

- `--ocr` is available only for the explicit image OCR boundary.
- `--ocr-lang <LANG>` can be used to specify language.
- `pdf --ocr` is not currently enabled.
- Scanned/image-only PDFs remain fail-closed.

## Reproducibility Guide

Daily regression validation:

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

External quality validation:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

Formal benchmark reproduction:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe doctor
_build/native/release/build/bench/runner/runner.exe run --preset official-internal
_build/native/release/build/bench/runner/runner.exe run --preset official-compare --markitdown-path /path/to/markitdown
_build/native/release/build/bench/runner/runner.exe run --scenario compare.official_compare --bench-id docx_medium_golden_v1 --markitdown-path /path/to/markitdown
_build/native/release/build/bench/runner/runner.exe run --scenario compare.official_compare --bench-id xlsx_medium_regional_1971_2020_v1 --markitdown-path /path/to/markitdown
_build/native/release/build/bench/runner/runner.exe run --scenario compare.official_compare --bench-id epub_medium_alice_v1,pdf_medium_nist_800_207_v1 --markitdown-path /path/to/markitdown
_build/native/release/build/bench/runner/runner.exe run --scenario compare.official_compare --bench-id json_medium_spdx_licenses_v1 --markitdown-path /path/to/markitdown
```

For sample-regression usage, see [samples/README.md](./samples/README.md). For benchmark usage, see [bench/README.md](./bench/README.md).

## Project Structure

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

Architectural constraints:

- `ParserRegistry` selects parsers; it does not own final rendering.
- Every parser returns `ParseResult`.
- `IRInput` and `RenderInput` are the stable cross-layer product shapes.
- `Renderer` owns final Markdown output.
- `format_readers` must not depend on `runtime`, `pipeline`, `render`, or `convert`.

## Samples And Quality Lab

- `samples/main_process/` contains repo-local regression samples and expected outputs.
- `samples/check.sh` is the primary sample regression entrypoint.
- `samples/helpers/contracts/check_root_contracts.sh` is the aggregated contract entrypoint.
- `markitdown-quality-lab/` is an optional external quality corpus repository used only by `samples/check_quality.sh`.

The following implementation notes remain stable user-facing facts:

- EPUB support is implemented through `format_readers/epub` on top of `format_readers/zip`.
- ZIP archive reading continues to rely on `bikallem/compress/flate` inside `format_readers/zip`.

The repository is self-contained for normal build, test, and repo-local regression validation. `markitdown-quality-lab/` is only required for additional external quality validation.
