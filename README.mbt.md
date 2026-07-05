# markitdown-mb

`markitdown-mb` is a MoonBit document-to-Markdown tool designed for engineering-grade workloads.

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
- `ipynb`
- `xml`
- `yaml`
- `yml`
- `toml`
- `html`
- `htm`
- `markdown`
- `md`
- `eml`
- `srt`
- `vtt`
- `tex`
- `latex`
- `rst`
- `adoc`
- `asciidoc`
- `zip`
- `epub`
- `docx`
- `xlsx`
- `pptx`
- `pdf`
- `png`
- `jpg`
- `jpeg`
- `bmp`
- `webp`
- `tif`
- `tiff`

Current format policy:

- `pdf` is officially supported for native-text PDFs by default.
- Single-file `pdf --accurate` now defaults to `--pdf-ocr auto-scanned`; scanned-like PDFs enter the Paddle-backed OCR route and fail closed with install guidance when Paddle is unavailable.
- `pdf --ocr` remains supported as a compatibility alias for `pdf --pdf-ocr explicit`.
- Scanned or image-only PDFs should currently use `--ocr` or `--pdf-ocr auto-scanned`.
- Direct image input is officially supported through local Tesseract OCR.
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

Accurate fidelity example:

```bash
./_build/native/debug/build/cli/cli.exe normal --accurate samples/main_process/docx/markdown/docx_heading_levels.docx .tmp/manual/docx-accurate.md
```

Accurate plus RAG output example:

```bash
./_build/native/debug/build/cli/cli.exe normal --accurate --rag samples/main_process/pptx/markdown/pptx_bullet_levels.pptx .tmp/manual/pptx-accurate.rag.json
```

Native-text PDF example:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/markdown/root_native_text_baseline.pdf .tmp/manual/pdf.md
```

## OCR

Current OCR support is based on local `Tesseract` and does not depend on a cloud model.

macOS / Homebrew:

```bash
brew install poppler
brew install tesseract
brew install tesseract-lang
```

Ubuntu:

```bash
sudo apt install poppler-utils tesseract-ocr
sudo apt install tesseract-ocr-eng
# install extra language packs as needed, for example:
# sudo apt install tesseract-ocr-chi-sim tesseract-ocr-jpn
```

Current boundaries:

- Direct image input uses OCR by default.
- `--no-ocr` disables direct-image OCR explicitly.
- `--ocr-lang <LANG>` can be used to specify language for direct image input and PDF OCR routes triggered by `--ocr` / `--pdf-ocr`.
- Balanced PDF OCR is entered through `--ocr` or `--pdf-ocr explicit|auto-scanned`.
- Accurate PDF OCR is entered through `pdf --accurate`, which defaults to `auto-scanned` instead of whole-document OCR.
- `--pdf-ocr auto-scanned` keeps native-text pages on the native route and only OCRs scanned-like pages.
- Balanced OCR and Balanced PDF OCR require local `tesseract`.
- Accurate OCR and Accurate PDF OCR are still experimental and currently require a Paddle-backed wrapper configured through `MARKITDOWN_PADDLE_OCR_CMD`.
- PDF OCR in both modes also requires local `pdftoppm`.
- Missing dependencies fail closed with install guidance; the product does not silently fall back across OCR providers.
- This project does not bundle or redistribute `pdftoppm`, `tesseract`, or the Paddle Python runtime.

### MARKITDOWN_PADDLE_OCR_CMD

`MARKITDOWN_PADDLE_OCR_CMD` is the fixed runtime hook for the official Paddle OCR wrapper.

Current status:

- Accurate OCR and Accurate PDF OCR are still experimental.
- They can run locally, but stability and result quality are not yet treated as the same-level contract as the balanced OCR paths.

- The command is invoked as `<adapter_cmd> <image_path> [--lang <LANG>]`.
- `markitdown-mb` expects the adapter to print a single JSON object to stdout.
- Non-zero exit codes are treated as provider execution failures.
- Zero exit plus malformed JSON is treated as an `output_parse_failed` provider error.

Current payload contract:

```json
{
  "provider_name": "paddle_ocr",
  "provider_version": "3.0.0",
  "diagnostics": ["adapter=samples/helpers/paddle_ocr_wrapper.py"],
  "pages": [
    {
      "page_index": 0,
      "width": 1000,
      "height": 2000,
      "language": "eng",
      "diagnostics": ["page=0"],
      "blocks": [
        {
          "block_index": 0,
          "bbox": { "x0": 10, "y0": 20, "x1": 300, "y1": 120 },
          "confidence": 0.97,
          "lines": [
            {
              "line_index": 0,
              "text": "MoonBit OCR",
              "bbox": { "x0": 10, "y0": 20, "x1": 280, "y1": 60 },
              "confidence": 0.98,
              "words": [
                { "word_index": 0, "text": "MoonBit" },
                { "word_index": 1, "text": "OCR" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Official wrapper:

```bash
chmod +x samples/helpers/paddle_ocr_wrapper.py
export MARKITDOWN_PADDLE_OCR_CMD="$PWD/samples/helpers/paddle_ocr_wrapper.py"
```

The sample bridge expects a Python runtime with `paddleocr` installed. If Pillow is available, it also fills `width` and `height`.

## Audio Native CLI

Audio transcription for root local `wav`, `mp3`, and `m4a` inputs now uses local `whisper.cpp` directly.

- Balanced and Accurate both stay on the same P0 native audio route.
- `--audio-lang <LANG>` is the dedicated audio language hint; audio no longer reuses `--ocr-lang`.
- `wav` and `mp3` go directly into `whisper.cpp`.
- `m4a` is normalized through local `ffmpeg` into temporary `wav` before transcription.
- Non-zero exit codes, missing backend/model, malformed JSON output, empty transcript segments, malformed timestamps, or all-empty transcript text all fail closed.

Runtime requirements:

```bash
# install whisper.cpp locally and make whisper-cli available on PATH
# `main` is also accepted as a compatibility fallback binary name

# download the multilingual ggml-base model locally
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp"
# place model at:
# ${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp/ggml-base.bin

# optional override
export MARKITDOWN_AUDIO_MODEL_PATH="/absolute/path/to/ggml-base.bin"

# install ffmpeg if you need m4a support
```

Current backend facts:

- backend transport: `native_cli`
- backend name: `whisper_cpp`
- default model: multilingual `ggml-base`
- command discovery order: `whisper-cli`, then `main`
- Markdown output keeps `[start - end]` transcript lines
- RAG output keeps one chunk per audio segment with time boundaries

The sample bridge expects a Python runtime with `paddleocr` installed. If Pillow is available, it also fills `width` and `height`.

## Fidelity And Output Modes

The main CLI now exposes fidelity and output as separate product dimensions:

- default: balanced fidelity + Markdown output
- `--accurate`: accurate fidelity + Markdown output
- `--debug`: debug JSON output
- `--rag`: RAG JSON output
- supported combinations include `--accurate --debug` and `--accurate --rag`

The current Office product routes stay architecture-stable:

- `docx`, `pptx`, `xlsx` remain package-single-pass parsers
- `--accurate` enables higher-fidelity behavior inside those existing Office routes
- `pdf` remains native-text by default and only enters OCR through `--ocr` / `--pdf-ocr explicit|auto-scanned`

## Reproducibility Guide

Daily regression validation:

Note:
Before running sample validation, make sure the local environment already has the OCR runtime dependencies, PDF raster backend, and the official external regression corpus checked out at `./markitdown-quality-lab/`. In practice, `samples/check.sh` expects local `tesseract`, `pdftoppm`, and `markitdown-quality-lab/external_main_process/`; otherwise OCR, PDF OCR, and enrolled main-regression lanes will fail.

```bash
moon fmt
moon info
moon check
moon build
moon test
moon test tests
bash samples/check.sh
bash samples/check.sh --check-inventory
bash samples/helpers/contracts/check_root_contracts.sh
```

External quality validation:

Note:
`samples/check_quality.sh` is also defined against the official external corpus repo at `./markitdown-quality-lab/`.

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

- `samples/fixtures/contracts/` contains the minimal offline fixtures used by repo-local tests and retained shell contracts.
- `samples/check.sh` runs the external main regression corpus from `markitdown-quality-lab/external_main_process/`.
- `samples/check.sh` is the primary sample regression entrypoint.
- `samples/check_quality.sh` runs the external quality corpus from `markitdown-quality-lab/external_quality/`.
- `samples/helpers/contracts/check_root_contracts.sh` is the aggregated contract entrypoint.
- `./markitdown-quality-lab/` is the official external corpus repository location for quality and benchmark validation.

The following implementation notes remain stable user-facing facts:

- EPUB support is implemented through `format_readers/epub` on top of `format_readers/zip`.
- ZIP archive reading continues to rely on `bikallem/compress/flate` inside `format_readers/zip`.

The repository is self-contained for build, unit tests, and a small set of repo-local fixtures used by contract coverage.
Formal main regression, quality regression, and benchmark validation all intentionally depend on `./markitdown-quality-lab/` under the main repo root.
Formal `bench v2` reads `./markitdown-quality-lab/external_bench/` by default; `MARKITDOWN_BENCH_ROOT` is an explicit override.
