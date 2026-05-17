# markitdown-mb

[![CI](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml/badge.svg)](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-6b7280)
![Formats](https://img.shields.io/badge/formats-14%2B-0ea5e9)
![Validation](https://img.shields.io/badge/validation-passing-16a34a)
![License](https://img.shields.io/badge/license-Apache--2.0-f59e0b)

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown CLI for
local structure extraction, RAG ingestion, and knowledge-base import.

It is inspired by Microsoft MarkItDown, but optimized for lightweight native
execution, explicit component boundaries, and conservative normal-path
contracts.

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

The product entrypoint is `cli`.

* `cli <input> [output]` and `cli normal <input> [output]` are the normal
  conversion path
* PDF and ZIP are available directly through `cli`
* `cli ocr ...` is explicit-only and stays out of the normal path
* `debug` and `bench` are separate developer tools
* `core` stays CLI-free

PDF and ZIP are integrated into the user experience without pulling the heavy
native PDF closure back into the lightweight main binary. The current launcher
keeps `cli` as the unified product surface and routes PDF/ZIP through bundled
`pdf` / `zip` components so the main build stays small and predictable.

OCR remains explicit-only.

## Current Quality Snapshot

Current local external corpus status:

* rows: `142`
* result: pass
* skipped: `1`
* expected_fail: `0`
* unexpected_pass: `5`

Interpretation:

* the current quality gate is green
* the `unexpected_pass` rows are older local manifest boundaries that the
  current implementation already exceeds
* they are not validation failures

Local-only quality assets:

* `.external/quality_corpus`
* `samples/quality_corpus/external_manifest.local.tsv`

These remain local-only and should not be committed.

## Mainstream Comparison Policy

This README does not claim a blanket “mainstream quality percentage” unless a
local reproducible compare run defines the tool version, corpus, and metric.

Current measured quality is tracked by the `142`-row local external corpus plus
the repository validation suites.

If you want a competitor percentage, run a pinned compare workflow first and
record:

* competitor tool name and version
* corpus and row count
* metric definition
* date and machine
* whether OCR/scanned/boundary cases are excluded

The repository already provides an overlap-only compare harness for Microsoft
MarkItDown timing, but it is not a blanket Markdown-quality percentage.

## Quick Start

Build the product entrypoint and the bundled PDF/ZIP components:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Optional component and developer-tool builds:

```bash
moon build ocr --target native
moon build debug --target native
moon build bench --target native
```

Recommended product-path usage:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe --version
./_build/native/debug/build/cli/cli.exe <input> [output]
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/debug/build/cli/cli.exe ocr [--provider <name>] [--lang <code>] <input> [output]
```

`moon run cli -- ...` is still a development fallback, but native binaries are
the recommended runner for validation and benchmark work.

## Commands

Current product commands:

* `cli <input> [output]`
* `cli normal <input> [output]`
* `cli normal --with-metadata <input> <output.md>`
* `cli batch <input_dir> <output_dir>`
* `cli ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]`
* `cli help`
* `cli --help`
* `cli -h`
* `cli version`
* `cli --version`

Developer tools stay separate:

* `debug`: inspect/report surface
* `bench`: benchmark-only surface

## Supported Formats

| Format | Current scope |
| --- | --- |
| XLSX | native workbook/sheet/cell conversion with conservative formula/merged-cell policy |
| DOCX | document structure recovery, not a Word layout engine |
| PPTX | presentation structure recovery, not a PowerPoint layout engine |
| PDF | native text-PDF scope only; no default OCR; encrypted PDFs fail closed |
| ZIP | archive/container conversion with nested dispatch and PDF routing |
| EPUB | ZIP + OPF + spine + nav/NCX + XHTML chapters |
| HTML / HTM | lightweight safe parser; no browser engine, JS, or CSS layout |
| CSV / TSV / JSON / YAML / TXT / XML / Markdown | conservative structured/text paths |

For detailed format behavior and limits, use
[docs/support-and-limits.md](./docs/support-and-limits.md).

## Product Architecture Summary

Current package responsibilities:

* `cli`: unified user-facing product entrypoint
* `cli_common`: lightweight CLI/component runtime and component discovery
* `cli_support`: parser/help/version glue plus product-path dispatch/routing
* `pdf`: bundled PDF product component
* `zip`: bundled ZIP product component
* `ocr`: explicit OCR component surfaced by `cli ocr`
* `debug`: developer inspect tool
* `bench`: developer benchmark tool
* `core`: CLI-free document model, metadata model, emitters, and pure helpers
* `convert/*`: format conversion layer
* `doc_parse/*`: lower-layer parser/model/inspect foundations

Build guardrail:

* main `cli` intentionally stays out of the vendored PDF closure and should
  remain `mbtpdf=0`
* a direct in-process PDF reintegration experiment pushed `cli` to about
  `30M / 653k` generated-C lines, so it was rejected
* the current bundled-component design keeps the user surface unified while
  bounding build cost

Current clean native build snapshot on the checked local machine:

* `cli build`: `62.73s`
* `pdf build`: `67.42s`
* `zip build`: `61.88s`
* `ocr build`: `53.14s`
* `cli.exe`: `3649640` bytes
* `pdf.exe`: `4278680` bytes
* `zip.exe`: `3442056` bytes
* `ocr.exe`: `1644328` bytes
* `cli.c`: `394425` lines
* `pdf.c`: `442901` lines
* `zip.c`: `370607` lines
* `ocr.c`: `154425` lines
* `cli mbtpdf count`: `0`

These are local clean-build measurements, not cross-machine guarantees.

## PDF Layout Gate

The first gated-normal PDF layout gate is intentionally narrow.

Current normal-path scope:

* weak heading demotion
* separator / false-bullet suppression

Current normal-path non-goals:

* table promotion/demotion
* link/caption rewrite
* annotation/link-target changes
* text-decoding changes
* OCR/provider probing
* external/model runtime loading

Current implementation:

* pure MoonBit compact distilled logic
* default on
* disable with `MARKITDOWN_PDF_LAYOUT_GATE=0`
* no Python runtime
* no external/model JSON
* no committed weights
* no `.external/layout_model` runtime dependency

Hard constraints still outrank the gate, including:

* text decoding correctness
* explicit annotation/link payload
* table/caption geometry
* OCR / scan-only boundaries

## Validation

Recommended serial verification:

```bash
moon info
moon fmt
moon check
moon test
./samples/check.sh
bash samples/quality_corpus/check.sh
./samples/bench.sh --suite smoke --kind smoke
bash samples/helpers/check_cli_contract.sh
bash samples/helpers/check_pdf_contract.sh
bash samples/helpers/check_zip_contract.sh
bash samples/helpers/check_batch_contract.sh
bash samples/helpers/check_debug_contract.sh
bash samples/helpers/check_ocr_contract.sh
```

Optional local OCR smoke:

```bash
bash samples/helpers/check_ocr_tesseract_smoke_optional.sh
```

Run Moon commands serially. Avoid parallel `moon` processes and avoid habitual
`moon clean` during normal iteration.

Quality corpus refresh and validation:

```bash
bash samples/quality_corpus/tools/fetch_external_samples.sh --prepare-cache
bash samples/quality_corpus/check.sh
```

## Benchmarks

Public benchmark entrypoint:

```bash
./samples/bench.sh
```

Useful suites:

```bash
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
./samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
./samples/bench.sh --suite product-path --smoke
./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

Use [docs/benchmarking.md](./docs/benchmarking.md) for commands and artifact
layout, and [docs/performance.md](./docs/performance.md) for measured baselines
and caveats.

Measured speed claims are generated from `samples/bench.sh`.
Do not mix clean build time, cold-start CLI time, same-process product-path
time, and competitor overlap timing into one headline number.

Current measured overlap-only compare timing:

* date: `2026-05-17`
* machine: `macOS 15.3`, `arm64`
* competitor: `Microsoft MarkItDown 0.1.5`
* corpus: `samples/benchmark/compare_corpus.tsv`
* rows: `47` overlap samples per runner
* average sample time:
  * `markitdown-mb`: `11.064 ms`
  * `markitdown-python`: `435.660 ms`
* observed ratio on this checked overlap corpus:
  * Python runner about `39.4x` slower than the native runner

This is an overlap-only local timing result, not a universal speed guarantee.
It does not measure OCR, scanned-PDF paths, metadata semantics, assets
semantics, or full Markdown-quality equivalence.

## External Quality Corpus

`samples/quality_corpus/` is the signal-level external/private intake path.

Keep these files local-only:

* `.external/`
* `samples/quality_corpus/external_manifest.local.tsv`
* private local quality samples
* benchmark outputs and OCR/model artifacts
* macOS AppleDouble `._*` files

Do not commit local manifests, local caches, or quality-corpus outputs.

## Development Docs

Current authoritative docs:

* [Documentation Map](./docs/README.md)
* [Architecture](./docs/architecture.md)
* [Development](./docs/development.md)
* [Support and Limits](./docs/support-and-limits.md)
* [Benchmarking](./docs/benchmarking.md)
* [Performance](./docs/performance.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Roadmap](./docs/roadmap.md)
* [Quality Corpus](./samples/quality_corpus/README.md)
* [doc_parse Overview](./doc_parse/README.md)

## Non-goals

`markitdown-mb` does not aim to be:

* a full PDF, Word, PowerPoint, or browser layout engine
* an OCR-first default converter
* a bundled OCR/model runtime distribution
* a remote-fetch or JS/CSS execution pipeline
* a benchmark claim beyond the named checked corpora and runner paths
