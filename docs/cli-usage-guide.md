# CLI Usage Guide

This document covers the day-to-day usage of the main CLI. Read
[environment-dependencies.md](./environment-dependencies.md) first.

> Notes:
> - The current CLI uses a unified `mode + options + input/output` shape.
> - If you omit the mode, it defaults to `balance`.
> - The removed legacy forms are `convert`, `normal`, `--accurate`, and `--stream`.
> - OCR-related options `--ocr`, `--no-ocr`, and `--ocr-lang` are still supported.
> - The current build supports the capability groups `Core`, `Office`, `Containers`, `Media`, and `PdfOcr`; formats outside the current support surface fail closed explicitly.

## 1. Build And Help

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
./_build/native/release/build/cli/cli.exe --help
./_build/native/release/build/cli/cli.exe --version
```

## 2. Basic Syntax

Single file:

```bash
./_build/native/release/build/cli/cli.exe [balance|accurate|stream] [--format <format>] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]
```

Batch:

```bash
./_build/native/release/build/cli/cli.exe batch [balance|accurate|stream] [--format <format>] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] <input> <output_dir>
```

If `output` is omitted in single-file mode, the result is written to stdout.
Because stdout has no asset directory, local asset references are replaced by
readable placeholders and reported on stderr instead of producing broken links.

For file output in Markdown mode, the CLI uses an atomic unbuffered sink only
for TXT, CSV/TSV, SRT/VTT, JSON/JSONL/NDJSON, XML, YAML, and TOML. It writes to
a temporary sibling, commits by rename only after conversion and sink finish,
and removes the temporary file on write, asset, or empty-failure paths.
Fail-closed XML raw fences are valid output and are committed even when their
diagnostics record the parse error that caused the fallback.

## 3. Common Single-File Examples

Regular conversion:

```bash
./_build/native/release/build/cli/cli.exe balance samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

Explicit format:

```bash
./_build/native/release/build/cli/cli.exe balance --format pdf samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Write provenance:

```bash
./_build/native/release/build/cli/cli.exe balance --provenance-out .tmp/manual/result.provenance.json samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

## 4. Batch Mode

Process a directory:

```bash
./_build/native/release/build/cli/cli.exe batch balance samples/fixtures/contracts .tmp/batch-out
```

Notes:

- Batch mode writes results into the output directory.
- Markdown output ends with `.md`, `--debug` output ends with `.debug.json`, and `--rag` output ends with `.rag.json`.
- Batch mode does not support `--provenance-out`; it always writes `manifest.json` in the output directory.
- Batch mode writes every task outcome to the manifest and returns non-zero if any task fails.
- Single-file conversion returns non-zero when conversion produces no output
  and has errors, when sink/commit fails, or when asset persistence fails.

## 5. Output Views

The default output is Markdown.

Debug JSON:

```bash
./_build/native/release/build/cli/cli.exe balance --debug samples/fixtures/contracts/html/html_simple.html
```

RAG JSON:

```bash
./_build/native/release/build/cli/cli.exe balance --rag samples/fixtures/contracts/html/html_simple.html
```

`--debug` and `--rag` cannot be used together.

## 6. `balance`, `accurate`, And `stream`

- `balance`: the default mode.
- `accurate`: requests a higher-fidelity route.
- `stream`: requests a productized streaming or block-streaming route when one exists for the active format.

Examples:

```bash
./_build/native/release/build/cli/cli.exe accurate samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-accurate.md
./_build/native/release/build/cli/cli.exe stream samples/fixtures/contracts/html/html_semantic_sectioning.html .tmp/manual/html-stream.md
```

Current behavior:

- If a format does not productize `accurate`, the CLI rejects the request with a non-zero exit status.
- If a format does not productize `stream`, the CLI rejects the request with a non-zero exit status.
- Provenance keeps both the requested mode and the effective execution route.

## 7. PDF And Image OCR

Regular PDF conversion:

```bash
./_build/native/release/build/cli/cli.exe balance samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Request the Accurate PDF route:

```bash
./_build/native/release/build/cli/cli.exe accurate samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-accurate.md
```

Direct image OCR:

```bash
./_build/native/release/build/cli/cli.exe balance samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr.md
```

Disable image OCR:

```bash
./_build/native/release/build/cli/cli.exe balance --no-ocr samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr-disabled.md
```

Set the OCR language:

```bash
./_build/native/release/build/cli/cli.exe balance --ocr-lang chi_sim samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr-chi.md
```

Notes:

- Direct image input enables local OCR by default, so you usually do not need to write `--ocr` explicitly.
- `--no-ocr` is still available to disable OCR for direct image input.
- `--ocr-lang` is still available for direct image input, and it also works on the `accurate` PDF OCR route.
- `--ocr` still exists, but it is mainly useful when you want to state OCR intent explicitly; for direct image input it is usually not required.
- PDF no longer exposes a public balanced OCR route; PDF OCR is only enabled through the `accurate` PdfOcr layout/OCR route.
- If you explicitly use `--ocr` on a non-`accurate` PDF path, the CLI reports an error.
- If Accurate image OCR is missing Paddle runtime dependencies, it falls back to balanced image OCR.
- If Accurate PDF OCR is missing Paddle runtime dependencies, it reports the missing dependency directly.

## 8. Audio

Audio input currently supports `wav`, `mp3`, and `m4a`:

```bash
./_build/native/release/build/cli/cli.exe balance samples/fixtures/contracts/audio/contract.wav .tmp/manual/audio.md
./_build/native/release/build/cli/cli.exe balance --audio-lang zh samples/fixtures/contracts/audio/contract.mp3 .tmp/manual/audio-zh.md
```

Notes:

- `audio` remains part of the main CLI, but it depends on an optional local transcription backend.
- When you run from the repo root, the runtime prefers the repo-managed environment under `./env/` together with the checked-in wrapper.
- Compressed audio preprocessing may use local `ffmpeg`.
- `audio` does not currently support `accurate`; requesting it returns a non-zero unsupported-mode error.
- In batch mode, if you use `--audio-lang`, it is recommended to set `--format wav|mp3|m4a` explicitly.

## 9. Troubleshooting

- First run `./tools/env/optional_deps.sh check <profile>` and follow
  [environment-dependencies.md](./environment-dependencies.md) if the profile is incomplete.
- Then check CLI stderr.
- If you need to confirm the real execution route, use `--provenance-out` in single-file mode.
- If you are not running from the repo root, or if you are using a custom runtime, verify that the relevant environment variables are configured correctly.
