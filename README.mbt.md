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

## Performance Snapshot

Official performance claims come from `bench` only.
To reproduce the current formal benchmark:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
./tools/env/install_bench_baseline_deps.sh
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" doctor
"$RUNNER" run --preset official-compare
```

Current `official-compare` summary:

- `selected_rows = 75`
- `comparable_rows = 66`
- `gate_status = partial`
- `moonbit-cli`: `75/75`, median wall `140,382 us`
- `moonbit-engine`: `75/75`, median wall `83,973 us`
- repo-local `markitdown` baseline: `67/75`, median wall `547,600 us`

Benchmark numbers vary with CPU, memory, disk, operating system,
Python environment, and OCR dependency state. Treat them as a trend snapshot
rather than a cross-machine constant.

Representative CLI speedups versus `markitdown`:

| Format | CLI speedup vs `markitdown` |
| --- | --- |
| `docx` | `123.62x` |
| `zip` | `53.22x` |
| `pptx` | `38.05x` |
| `eml` | `32.87x` |

Interpretation:

- These ratios mainly reflect advantages on container, Office,
  and structurally complex formats
- Text-oriented formats carry richer semantics, structure, and provenance,
  so the speedup may be less dramatic than the table suggests
- On large `xlsx`, `json`, and other high-pressure inputs,
  complete success rate, timeout control, and stability matter more than
  a single speedup number

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
moon build cli --target native
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe balance samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

If you need provenance output:

```bash
./_build/native/debug/build/cli/cli.exe balance --provenance-out .tmp/manual/out.provenance.json samples/fixtures/contracts/html/html_simple.html .tmp/manual/out.md
```

For more CLI options, batch usage, and OCR / PDF / audio examples, see
[docs/cli-usage-guide.md](./docs/cli-usage-guide.md).

## Modes and Boundaries

- The default mode is `balance`
- `ocr`, `accurate` PDF / image paths, and `audio` are optional capabilities.
  They are unavailable in a bare environment and require runtime dependencies
- `accurate` currently has three cases:
  `pdf` and direct image OCR use a high-fidelity path;
  `docx/xlsx/pptx/odt/ods/odp` use a semantic enhancement path;
  most other formats emit a warning and fall back to `balance`
- `stream` currently supports:
  `txt/csv/tsv/srt/vtt/json/jsonl/ndjson/ipynb/xml/yaml/html/markdown/eml/zip/epub/xlsx/odt/ods/odp`
- `docx/pptx/pdf/audio/direct image OCR` do not expose a standalone `stream`
  path
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
moon check
moon build
moon test
```

Refresh interfaces and formatting:

```bash
moon info
moon fmt
```

The external corpus repository is only required for `tools/regression/check*.sh`
and formal benchmarks. If it is not present locally:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Common regression commands:

```bash
moon build cli --target native
bash tools/regression/check_balance.sh
bash tools/regression/check_balance_quality.sh
```

The formal benchmark reproduction commands are shown above.
When run from the repo root, the runner prefers
`./env/.venv-markitdown-bench/bin/markitdown`.

To point to a specific baseline:

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" run --preset official-compare --markitdown-path /absolute/path/to/markitdown
```
