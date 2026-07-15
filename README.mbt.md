# markitdown-mb

`markitdown-mb` is a MoonBit document-to-Markdown tool for document ingestion,
RAG, and automation pipelines.

The project is inspired by Microsoft `MarkItDown`, but it is not a port.
It is designed around stable routing, traceable provenance, explicit failure
boundaries, and reproducible behavior under complex formats and
engineering-scale workloads.

Before first use, read:

- Environment setup and install commands:
  [docs/environment-dependencies.md](./docs/environment-dependencies.md)
- Core architecture overview:
  [docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md)
- Optional enhancement paths for OCR / accurate PDF / audio:
  [docs/architecture/optional-enhancement-architecture.md](./docs/architecture/optional-enhancement-architecture.md)

Prepare runtime dependencies before first run. Otherwise OCR, `accurate` PDF,
`audio`, and benchmark examples will not work as expected.

Core native document readers need no external runtime. Optional profiles use one
managed entrypoint:

```bash
./tools/env/optional_deps.sh install balance  # top-level/ZIP image OCR
./tools/env/optional_deps.sh install audio
./tools/env/optional_deps.sh install accurate # direct image/PDF accurate
./tools/env/optional_deps.sh install bench    # development comparison only
```

## Performance Snapshot

Official performance claims come from `bench` only.
To reproduce the current formal benchmark:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
./tools/env/optional_deps.sh install bench
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" doctor
"$RUNNER" run --preset official-external-compare
```

The runner report is the source of truth for performance numbers. This README
keeps one identified snapshot rather than presenting machine-specific results as
universal constants.

Current audited `official-external-compare` snapshot on macOS arm64, using the
repo-locked Microsoft MarkItDown `0.1.6` baseline:

- 25 selected rows, 25 semantically comparable rows
- 75/75 trusted tool cases; no route, fidelity, provenance, or density failure
- MoonBit CLI aggregate median: `51,295 us`; baseline: `511,348 us`
- performance gate: pass, with every case `>=2x` and every format geometric
  mean `>=3x`

| Format | MoonBit CLI geometric-mean speedup |
| --- | ---: |
| IPYNB | `155.69x` |
| DOCX | `54.92x` |
| XLSX | `53.45x` |
| PPTX | `32.89x` |
| HTML | `11.10x` |
| ZIP | `10.76x` |
| Markdown | `10.03x` |
| PDF | `4.53x` |

ODF and optional dependency-backed balance cases use reviewed self baselines
instead of invalid external comparisons. Dependency versions are locked under
`tools/env/config/`. Approved macOS arm64 and Linux x64 baselines, each covering
106 CLI/engine cases, live under
`markitdown-quality-lab/performance_baselines/`; inspect a generated
`results/summary.json` for the complete measurement evidence.

For full benchmark usage, see [bench/README.md](./bench/README.md).
For benchmark architecture, see
[docs/architecture/benchmark-architecture.md](./docs/architecture/benchmark-architecture.md).

## Input Coverage

A brief input surface:

- Core plain text:
  `txt/csv/tsv/srt/vtt`
- Core structured text:
  `json/jsonl/ndjson/ipynb`
- Core markup and config text:
  `xml/yaml/toml/html/markdown`
- Core technical text:
  `tex/rst/asciidoc`
- Mail:
  `eml`
- Mail alias:
  `msg` is accepted only as a mail parsing alias.
  It does not imply native Outlook `.msg` binary parsing
- Containers:
  `zip/epub`
- Office:
  `docx/xlsx/pptx`
  `odt/ods/odp`
- PDF and direct image OCR:
  `pdf/png/jpg/jpeg/bmp/webp/tif/tiff`
- Audio (optional):
  `wav/mp3/m4a`

For the full capability matrix, see
[docs/capabilities-and-limitations.md](./docs/capabilities-and-limitations.md).

## Quick Start

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
./_build/native/release/build/cli/cli.exe --help
./_build/native/release/build/cli/cli.exe balance samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

If you need provenance output:

```bash
./_build/native/release/build/cli/cli.exe balance --provenance-out .tmp/manual/out.provenance.json samples/fixtures/contracts/html/html_simple.html .tmp/manual/out.md
```

For more CLI options, batch usage, and OCR / PDF / audio examples, see
[docs/cli-usage-guide.md](./docs/cli-usage-guide.md).

## Modes and Boundaries

- The default mode is `balance`
- Core support means the built-in balanced reader path. Direct image OCR,
  audio transcription, and PDF accurate are optional enhancements backed by
  local external runtimes; they are not part of the core reader commitment.
- Formal benchmarks measure balance mode only. ODT/ODS/ODP remain core native
  formats but use reviewed self baselines because the external baseline does
  not support them. OCR and audio also use self baselines.
- `ocr`, `accurate` PDF / image paths, and `audio` are optional capabilities.
  They are unavailable in a bare environment and require runtime dependencies
- `accurate` currently has two supported cases:
  `pdf` and direct image OCR use a high-fidelity path;
  `docx/xlsx/pptx/odt/ods/odp` use a semantic enhancement path.
  Other formats reject the unsupported mode with a non-zero exit status
- `stream` currently supports:
  `txt/csv/tsv/srt/vtt/json/jsonl/ndjson/ipynb/xml/yaml/html/markdown/eml/epub/xlsx/odt/ods/odp`
- `docx/pptx/pdf/audio/direct image OCR` do not expose a standalone `stream`
  path and reject `stream` with a non-zero exit status
- PDF OCR is only entered through the `accurate` `PdfOcr` route
- If `accurate` image OCR is missing Paddle runtime,
  it falls back to balanced image OCR
- If `accurate` PDF OCR is missing Paddle dependencies,
  it reports the missing dependency directly
- `audio` is only available when a local transcription backend is installed
- Requests outside the supported boundary fail closed

## Development and Verification

Daily commands:

```bash
moon check --target all --warn-list +73 --deny-warn
moon build
moon test
```

Refresh interfaces and formatting:

```bash
moon info
moon fmt
```

The quality-lab repository is only required for `tools/regression/check*.sh`
and formal benchmarks, including internal baseline enforcement. If it is not
present locally:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Common regression commands:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
bash tools/regression/check_balance.sh
bash tools/regression/check_balance_quality.sh
bash tools/regression/check_accurate.sh
./tools/regression/check_coverage.sh --enforce
```

The formal benchmark reproduction commands are shown above.
When run from the repo root, the runner prefers
`./env/.venv-markitdown-bench/bin/markitdown`.

To point to a specific baseline:

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" run --preset official-external-compare --markitdown-path /absolute/path/to/markitdown
```
