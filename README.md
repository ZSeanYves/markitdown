# markitdown-mb

[![CI](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml/badge.svg)](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-6b7280)
![Formats](https://img.shields.io/badge/formats-14%2B-0ea5e9)
![License](https://img.shields.io/badge/license-Apache--2.0-f59e0b)

`markitdown-mb` is a MoonBit-first document-to-Markdown CLI for local
structure extraction, RAG ingestion, and knowledge-base import. It is inspired
by Microsoft MarkItDown, but the repository is organized around MoonBit-native
runtime code, explicit parser/converter boundaries, conservative output
contracts, and checked sample validation.

Current product pipeline:

```text
input document -> parser/runtime facts -> unified IR -> Markdown / assets / metadata
```

## Repository Architecture

The main repository owns the product implementation:

- MoonBit runtime, parser, converter, IR, and CLI packages
- format-specific conversion code under `convert/*`
- product entry binaries such as `cli`, plus bundled `pdf` and `zip` runtime
  components
- repo-local regression samples under `samples/main_process/`
- public validation entrypoints under `samples/`

The main repository is self-contained for normal development:

```bash
moon check
moon test
bash samples/check.sh
```

Those commands do not require the external lab.

## Supported Formats

The main CLI converts common local document formats into Markdown-first output:

- Office formats: `docx`, `pptx`, `xlsx`
- document, web, and text formats: `pdf`, `epub`, `html`, `csv`, `tsv`,
  `json`, `yaml`, `xml`, `txt`, `md`
- archive/container inputs: `zip`
- image inputs: `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

Markdown is the primary output. Assets and metadata are companion outputs when
requested or when a sample contract covers them.

Use [docs/supported-formats.md](./docs/supported-formats.md) for the detailed
support matrix and explicit limits.

## Quick Start

Development prerequisites:

- MoonBit native toolchain with `moon`
- `bash` plus common POSIX/coreutils shell tools for sample helpers
- Python for selected validation helper scripts
- optional `tesseract` plus language data for image OCR
- optional external lab at `markitdown-quality-lab/` for external quality and
  benchmark signal

Build the product binaries:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Run the product CLI:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/txt_plain.txt .tmp/manual/txt_plain.md
./_build/native/debug/build/cli/cli.exe normal --with-metadata samples/main_process/pdf/text_simple.pdf .tmp/manual/text_simple.md
./_build/native/debug/build/cli/cli.exe batch samples/main_process/txt .tmp/manual/txt_batch
```

Image OCR is available through the main CLI when local `tesseract` and language
data are installed:

```bash
./_build/native/debug/build/cli/cli.exe normal --ocr-lang eng samples/fixtures/ocr/tiny_ocr_sample.png .tmp/manual/tiny_ocr_sample.md
```

## OCR and PDF Boundary

Current OCR support is intentionally narrow:

- image inputs auto-OCR by default
- `--ocr`, `--no-ocr`, and `--ocr-lang LANG` are supported on the main CLI
- `--ocr-lang LANG` applies to image OCR only
- image OCR uses the MoonBit-owned `convert/vision` path and local `tesseract`
- missing OCR runtime support fails clearly

Current PDF behavior is separate:

- PDF support means native text, asset, metadata, annotation, and layout-aware
  extraction
- scanned or image-only PDFs do not run OCR in the normal path
- PDF `--ocr` fails closed in this build
- PDF scan diagnostics are report-only signals and do not change output

## Public Validation Entrypoints

The public sample entrypoints are:

```bash
bash samples/check.sh
bash samples/check_quality.sh
bash samples/bench.sh
```

`samples/check.sh` is the repo-local product regression entrypoint. It reads
`samples/main_process/` only and can run all formats or one focused format:

```bash
bash samples/check.sh
bash samples/check.sh --format pdf
bash samples/check.sh --metadata-only --format txt
```

`samples/check_quality.sh` is the external quality bridge. It consumes the
formal external quality manifest:

```text
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

Example commands:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

If the external lab, `external_quality/`, or `MANIFEST.tsv` is absent, the
script reports the missing path and exits clearly. It does not use repo-local
samples as external quality data.

`samples/bench.sh` is the external benchmark bridge. It consumes the formal
external benchmark manifest:

```text
markitdown-quality-lab/external_bench/MANIFEST.tsv
```

Example commands:

```bash
bash samples/bench.sh --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0
bash samples/bench.sh --help
```

Benchmark results are same-machine, same-corpus, same-parameters feedback. They
are not universal performance claims.

## External Lab

`markitdown-quality-lab/` is an optional external repository used for larger
quality and benchmark corpora. The main repository does not require it for
build, test, repo-local validation, or normal CLI use.

The bridge scripts default to `./markitdown-quality-lab/`. A different location
can be selected with environment variables:

```bash
MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab bash samples/check_quality.sh
MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab bash samples/bench.sh --format pdf
MARKITDOWN_BENCH_LAB=/path/to/markitdown-quality-lab bash samples/bench.sh --layer cli --format pdf
```

External lab areas:

- `external_quality/`: formal external quality corpus consumed by
  `samples/check_quality.sh`
- `external_bench/`: formal benchmark corpus consumed by `samples/bench.sh`
- `pdf_model_training/`: independent PDF/model training and audit assets, not a
  main-repository runtime or public validation gate

Formal corpus inclusion requires `MANIFEST.tsv`, `SOURCE_CATALOG.tsv`, and
recorded provenance and license evidence. Temporary tools, audit scripts,
cleanup reports, local caches, and generated reports are not corpus layers.

## Temporary Output

Validation and benchmark commands write ignored run output under `.tmp`:

```text
.tmp/check/runs/<run-id>/
.tmp/quality/runs/<run-id>/
.tmp/bench/runs/<run-id>/
```

Each run directory may contain:

```text
logs/entrypoint.log
summary.tsv
summary.md
diff/
workspace/
raw/
reports/
```

`.tmp` is disposable. Formal manifests, source catalogs, sample payloads,
license evidence, and expected outputs must not depend on `.tmp` as their only
durable location.

## Native Runner Strategy

Validation helpers use a prebuilt-first, missing-only build strategy:

- explicit overrides such as `MARKITDOWN_CLI`, `MARKITDOWN_PDF_CLI`,
  `MARKITDOWN_ZIP_CLI`, `MARKITDOWN_DEBUG_CLI`, and `MARKITDOWN_BENCH_CLI`
  win when set
- existing native binaries under `_build/` or `target/` are probed before any
  build
- if a required native runner is missing, the helper builds that package once
  with `moon build <package> --target native`
- `moon run` is disabled by default for validation helpers and is used only when
  `MARKITDOWN_ALLOW_MOON_RUN=1` is set
- benchmark layer helpers follow the same principle: use an existing native
  runner first, then build only the missing runner

This keeps public validation close to the native product path while avoiding
unnecessary rebuilds.

## Documentation

Start here for project details:

- [docs/README.md](./docs/README.md): documentation index
- [docs/architecture.md](./docs/architecture.md): package, binary, and
  repository boundaries
- [docs/supported-formats.md](./docs/supported-formats.md): supported formats
  and explicit limits
- [docs/quality-and-release.md](./docs/quality-and-release.md): validation and
  release workflow
- [docs/performance.md](./docs/performance.md): benchmark interpretation and
  measured performance notes
- [samples/README.md](./samples/README.md): sample validation entrypoints and
  temporary output layout

## Non-goals

This repository does not:

- require the external lab for normal build, test, runtime, or repo-local
  validation
- use external corpora through product runtime, parser, converter, IR, or CLI
  imports
- treat repo-local samples as benchmark corpus
- treat external benchmark results as universal performance promises
- provide legal advice about external corpus licenses
- define the `pdf_model_training/` architecture
- keep temporary, generated, or cache directories as public corpus inputs
- expose legacy validation modes as product entrypoints
