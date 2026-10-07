# CLI Usage Guide

This document covers the day-to-day usage of the main CLI. Read
[environment-dependencies.md](./environment-dependencies.md) first.

> Notes:
> - The current CLI uses a unified `mode + options + input/output` shape.
> - If you omit the mode, it defaults to `balance`.
> - The removed legacy forms are `convert`, `normal`, `--accurate`, and `--stream`.
> - OCR and audio options were removed in 0.8 and now produce a usage error.
> - The current build supports the capability groups `Core`, `Office`, `Containers`, and `PdfText`; formats outside the current support surface fail closed explicitly.

## 1. Build And Help

```bash
moon build --target native --release --package ZSeanYves/markitdown
./_build/native/release/build/markitdown.exe --help
./_build/native/release/build/markitdown.exe --version
```

## 2. Basic Syntax

Single file:

```bash
./_build/native/release/build/markitdown.exe [balance|accurate|stream] [--format <format>] [--debug|--rag] [--provenance-out <path>] <input> [output]
```

Batch:

```bash
./_build/native/release/build/markitdown.exe batch [balance|accurate|stream] [--format <format>] [--debug|--rag] <input> <output_dir>
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
./_build/native/release/build/markitdown.exe balance samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

Explicit format:

```bash
./_build/native/release/build/markitdown.exe balance --format pdf samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Write provenance:

```bash
./_build/native/release/build/markitdown.exe balance --provenance-out .tmp/manual/result.provenance.json samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

## 4. Batch Mode

Process a directory:

```bash
./_build/native/release/build/markitdown.exe batch balance samples/fixtures/contracts .tmp/batch-out
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
./_build/native/release/build/markitdown.exe balance --debug samples/fixtures/contracts/html/html_simple.html
```

RAG JSON:

```bash
./_build/native/release/build/markitdown.exe balance --rag samples/fixtures/contracts/html/html_simple.html
```

`--debug` and `--rag` cannot be used together.

## 6. `balance`, `accurate`, And `stream`

- `balance`: the default mode.
- `accurate`: requests a higher-fidelity route.
- `stream`: requests a productized streaming or block-streaming route when one exists for the active format.

Examples:

```bash
./_build/native/release/build/markitdown.exe accurate samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf-accurate.md
./_build/native/release/build/markitdown.exe stream samples/fixtures/contracts/html/html_semantic_sectioning.html .tmp/manual/html-stream.md
```

Current behavior:

- If a format does not productize `accurate`, the CLI rejects the request with a non-zero exit status.
- If a format does not productize `stream`, the CLI rejects the request with a non-zero exit status.
- Provenance keeps both the requested mode and the effective execution route.

## 7. PDF text and capability diagnostics

Regular PDF conversion:

```bash
./_build/native/release/build/markitdown.exe balance samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Request accurate PDF text policies:

```bash
./_build/native/release/build/markitdown.exe accurate samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf-accurate.md
```

Notes:

- PDFs without a recoverable text layer report an explicit unsupported text-layer diagnostic.
- `--capabilities` prints the machine-readable capability registry.
- Image and audio inputs return `UnsupportedCapability`; no external recognizer is started.

## 8. Troubleshooting

- For benchmark comparisons, run `./tools/env/installers/install_bench_baseline_deps.sh --check`.
- Then check CLI stderr.
- If you need to confirm the real execution route, use `--provenance-out` in single-file mode.
- The conversion path has no runtime Python, model or system-tool setup.
