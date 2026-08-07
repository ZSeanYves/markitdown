# markitdown-mb

`markitdown-mb` is a native MoonBit document-to-Markdown converter for document
ingestion, RAG, and automation pipelines. It follows Microsoft MarkItDown's
observable document-extraction behavior where a reviewed compatibility contract
exists, but it is an independent implementation rather than a source port.

The repository is on the unreleased `0.8.0` development line. The stable 0.8
library contract is native-only; local archives and benchmark runs are
development evidence, not published releases.

Start with the [documentation index](./docs/README.md). The most useful entry
points are the [CLI guide](./docs/cli-usage-guide.md), [capability matrix](./docs/capabilities-and-limitations.md),
[stable API](./docs/api-v0.8.md), [optional-runtime setup](./docs/environment-dependencies.md),
and [current performance evidence](./docs/performance.md).

## Install and build

Balanced readers for text, structured data, mail, containers, Office/ODF,
EPUB, and native PDF require no Python or external converter.

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
./_build/native/release/build/cli/cli.exe --help
```

Optional local runtimes are installed through one managed entry point:

```bash
./tools/env/optional_deps.sh install balance  # Tesseract image OCR
./tools/env/optional_deps.sh install audio    # Vosk and FFmpeg
./tools/env/optional_deps.sh install accurate # PaddleOCR and pdftoppm
./tools/env/optional_deps.sh install bench    # MarkItDown 0.1.7 comparison
```

Use a Python version in the supported `>=3.10,<3.14` range when the active
`python3` is newer:

```bash
./tools/env/optional_deps.sh install bench --python /path/to/python3.11
```

## CLI quick start

The default mode is `balance`:

```bash
CLI=./_build/native/release/build/cli/cli.exe
$CLI samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/plain.md
$CLI balance --format html input.html output.md
$CLI balance --rag input.docx output.json
$CLI balance --provenance-out .tmp/manual/provenance.json input.pdf output.md
$CLI batch balance samples/fixtures/contracts .tmp/manual/batch
```

`accurate` and `stream` are explicit routes, not quality flags accepted by every
format. Unsupported requests fail closed. Batch mode always writes
`manifest.json`; `--provenance-out` is single-file only.

## Stable library API

`ZSeanYves/markitdown/api` is the sole compatibility-stable 0.8 package. It
supports Path, Text, Bytes, and caller-owned Reader inputs plus Markdown,
Debug, and RAG outputs.

```mbt
let input = @api.Input::from_path("document.docx")
let options = @api.ConvertOptions::default()
  .with_output_mode(Markdown)
let result = @api.convert(input, options~)
```

Parser, reader, pipeline, renderer, runtime, and provider packages are internal
or extension contracts. See the [API reference](./docs/api-v0.8.md) and
[0.8 migration guide](./docs/migration-0.8.md).

## Capability summary

- Text and delimited: `txt`, `csv`, `tsv`, `srt`, `vtt`.
- Structured and markup: `json`, `jsonl`, `ndjson`, `yaml`, `toml`, `xml`,
  `html`, `markdown`, `ipynb`, `tex`, `rst`, `asciidoc`.
- Mail and containers: `eml`, `zip`, `epub`. `msg` is an RFC822/EML alias,
  not native Outlook binary MSG support.
- Office and ODF: `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`.
- PDF: bounded native balanced extraction; optional full-page OCR in accurate
  mode.
- Images: optional OCR for `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`.
- Audio: optional local transcription for `wav`, `mp3`, and `m4a`.

No core reader performs network access, executes document scripts/macros, or
loads remote includes. See [capabilities and limitations](./docs/capabilities-and-limitations.md)
for the structures and modes supported by each format.

## Current performance evidence

The latest complete formal measurement was recorded on 2026-08-07 using an
Apple M4/16 GiB host, native release binaries, Microsoft MarkItDown 0.1.7 on
Python 3.11.15, and one warmup plus five samples per row.

External run `run-1786101654079-0f0c773a82`:

- 25/25 comparable rows and 75/75 trusted tool cases;
- MoonBit CLI median of row medians: **63.941 ms**;
- MarkItDown median of row medians: **699.717 ms**;
- every row passed the 2x gate and every format passed the 3x geometric-mean
  gate;
- every evaluated MoonBit CLI row passed its configured RSS budget.

Self run `run-1786102949457-9591fe380a` covered 53 ODF, technical-text,
OCR/audio, and other non-external-comparison rows: 106/106 CLI/engine cases were
trusted and all RSS budgets passed. It is a candidate observation, not an
approved regression delta, because the existing self baseline has different
tool and runner fingerprints.

See [performance evidence](./docs/performance.md) for the format table,
methodology, caveats, reproduction commands, and committed runner summaries.

## Repository layout

All 68 MoonBit packages live under `src/`. `source = "src"` in `moon.mod` keeps
logical imports such as `ZSeanYves/markitdown/api` free of a `src` segment.

```text
src/      MoonBit product, CLI, internal implementations, tests, benchmark runner
bench/    benchmark policy and reviewed result summaries
samples/  deterministic fixtures and showcase outputs
tools/    environment, regression, governance, and release tooling
docs/     maintained documentation, architecture, governance, ADRs, and RFCs
```

## Development verification

```bash
moon info && moon fmt
moon fmt --check
moon check --target all --warn-list +73 --deny-warn
moon test --target all
python3 tools/governance/check_documentation.py
./tools/regression/check_coverage.sh --enforce
```

External regression and formal performance runs additionally require the
quality-lab commit pinned in the Phase 0 baseline:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
bash tools/regression/check_balance.sh
bash tools/regression/check_balance_quality.sh
bash tools/regression/check_accurate.sh
```

Contribution rules and risk-specific verification are in
[CONTRIBUTING.md](./CONTRIBUTING.md).
