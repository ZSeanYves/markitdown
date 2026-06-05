# markitdown-mb

[![CI](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml/badge.svg)](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-6b7280)
![Formats](https://img.shields.io/badge/formats-14%2B-0ea5e9)
![Validation](https://img.shields.io/badge/validation-passing-16a34a)
![License](https://img.shields.io/badge/license-Apache--2.0-f59e0b)

`markitdown-mb` is a MoonBit-first, lightweight multi-format
document-to-Markdown CLI for local structure extraction, RAG ingestion, and
knowledge-base import.

It is inspired by Microsoft MarkItDown, but the repository is intentionally
organized around:

* native execution
* conservative output contracts
* explicit component boundaries
* checked sample validation
* optional external quality-lab assets instead of checked-in large corpora

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Start Here

| If you are here for | Start here | Then go to |
| --- | --- | --- |
| User / Using the tool | [Five-Minute Tour](#five-minute-tour) | [Quick Start](#quick-start) |
| Developer / Developing converters | [Five-Minute Tour](#five-minute-tour) | [docs/README.md](./docs/README.md) |
| OCR / Image OCR | [What OCR Supports Today](#2-what-ocr-supports-today) | [docs/quality-and-release.md](./docs/quality-and-release.md) |
| PDF / PDF behavior | [What PDF OCR Does Not Support](#3-what-pdf-ocr-does-not-support) | [docs/pdf.md](./docs/pdf.md) |

## Five-Minute Tour

If you only read one section, read this one first.

### 1. What This Tool Converts

Today the main CLI converts common local document formats into Markdown-first
output:

* Office formats: `docx`, `pptx`, `xlsx`
* document/web/text formats: `pdf`, `epub`, `html`, `csv`, `tsv`, `json`,
  `yaml`, `xml`, `txt`, `md`
* archive/container inputs: `zip`
* image inputs: `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

The product contract is conservative:

* Markdown is the primary reading output
* assets and metadata are optional companion outputs
* the runtime favors explicit boundaries over silent fallback behavior

### 2. What OCR Supports Today

Current shipped OCR support is intentionally narrow:

* image OCR is supported on the main CLI
* image inputs auto-OCR by default
* `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are supported
* `--ocr-lang <LANG>` only affects image OCR
* image OCR runs through the MoonBit-owned `convert/vision` path
* image OCR depends on local `tesseract` plus installed language data

Practical reading:

* `image.png` will try OCR
* `image.png --ocr` also tries OCR explicitly
* `image.png --no-ocr` fails clearly because there is no native
  image-to-Markdown path
* normal document conversion still stays no-OCR

Paste-safe image OCR example:

```bash
moon build cli --target native
./_build/native/debug/build/cli/cli.exe samples/fixtures/ocr/tiny_ocr_sample.png --ocr-lang eng
```

That example requires local `tesseract` plus matching language data such as
`eng` tessdata.

### 3. What PDF OCR Does Not Support

Current PDF behavior is easy to misread, so here is the short version:

* PDF support today means native text/assets/metadata extraction
* scanned or image-only PDFs do not enter OCR in the default path
* `pdf --ocr` is not wired and fails closed in this build
* image OCR support does not imply scanned-PDF OCR support
* PDF scan diagnostics may say OCR would be worth trying, but they do not run
  OCR and they do not change PDF output

If you need the detailed boundary, start with [docs/pdf.md](./docs/pdf.md).

### 4. How To Run Validation

Recommended validation entrypoints:

* `moon check`
* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`
* `bash samples/bench.sh`
* `bash samples/bench.sh --help`

Broader local validation:

* `moon test`

Optional extra validation when `markitdown-quality-lab/` is cloned locally:

* `bash samples/helpers/release/summarize_release_readiness.sh`

If you are touching OCR behavior, also read
[docs/quality-and-release.md](./docs/quality-and-release.md).

### 5. How To Extend The Project

The shortest safe mental model:

* add or adjust format policy under `convert/*`
* lower into the shared IR instead of inventing format-specific Markdown
  emitters
* keep product behavior conservative and explicit
* add MoonBit tests plus repo-local sample validation for shipped behavior
* put large corpora, offline analysis, and heavier diagnostics in
  `markitdown-quality-lab/`, not in the main repo
* if the work is OCR-related, route it through `convert/vision` and keep it
  separate from the normal PDF path unless the product contract explicitly
  changes

Start with [docs/README.md](./docs/README.md), then
[docs/architecture.md](./docs/architecture.md) and
[docs/supported-formats.md](./docs/supported-formats.md).

### 6. What Is Product Entry Point Vs Debug Tool

Current product entrypoints:

* `cli` is the user-facing product CLI
* `pdf` and `zip` are bundled runtime components behind the product path

Current developer-only tools and diagnostics:

* `debug` is an inspect/report surface, not the normal product entrypoint
* `bench` is a benchmark surface, not a converter entrypoint
* PDF scan diagnostics are report-only helpers, not PDF OCR
* `doc_parse/pdf/layout_model_tool` is a dev export/infer tool
* quality-lab OCR helpers and preview tools are optional advanced validation,
  not the shipped product surface

## Quick Start

Minimum environment for development and validation:

* MoonBit native toolchain with `moon`
* `bash` plus common POSIX/coreutils shell tools for sample helpers
* Python for selected validation/quality helper scripts, not for normal runtime
* optional `tesseract` plus installed tessdata for image OCR
* optional repo-root `markitdown-quality-lab/` for external quality checks

Build the product binaries:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Optional developer binaries:

```bash
moon build debug --target native
moon build bench --target native
```

Use the product CLI:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe <input> [output]
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
```

Current OCR boundary:

* normal conversion never OCRs and never probes OCR providers.
* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported.
* image inputs such as `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, and
  `tiff` now auto-OCR through `convert/vision`.
* product image OCR depends on a local `tesseract` executable and language
  data; if they are missing, image OCR fails clearly.
* `--ocr-lang <LANG>` passes a Tesseract language value such as `eng` or
  `eng+chi_sim` to image OCR only; there is no language auto-detection.
* forcing OCR on PDF also fails closed; PDF OCR is not wired in this build.
* normal document conversion still stays no-OCR outside explicit image inputs.
* debug/report helpers do not change product behavior and are not product
  entrypoints.
* repo-root `markitdown-quality-lab/` is an optional external corpus/artifact
  repo, not a runtime dependency.
* see [docs/roadmap.md](./docs/roadmap.md) and
  [docs/quality-and-release.md](./docs/quality-and-release.md) for the
  current OCR policy and optional diagnostics.

Recommended validation entrypoints:

The public sample entrypoints are `samples/check.sh`,
`samples/check_quality.sh`, and `samples/bench.sh`.

Recommended copy-paste-safe commands:

* `moon check`
* `bash samples/check.sh` runs the full repo-local sample validation entrypoint.
* `bash samples/check_quality.sh` runs only the external quality corpus from
  `markitdown-quality-lab/external_quality/` and fails clearly if that repo is
  missing or incomplete.
* `bash samples/check_quality.sh --format pdf` runs the focused PDF slice from
  that same external corpus.
* `bash samples/bench.sh` runs the default smoke benchmark suite and writes
  results under `.tmp/bench/`.
* `bash samples/bench.sh --help` shows additional suites and targeted options.

Other public entrypoints:

* `bash samples/helpers/release/summarize_release_readiness.sh` is a
  maintainer snapshot helper; it is not the main validation entrypoint.

## Current Support

| Format | Current scope |
| --- | --- |
| DOCX | conservative document structure, links, structured footnotes/endnotes, images, tables, and text boxes |
| PPTX | conservative presentation structure, notes, links, tables, grouped content, and images |
| XLSX | workbook/sheet/cell extraction with conservative formula and merged-cell policy |
| PDF | native text-PDF path with explicit OCR boundary, high-confidence annotation links, marker-only note fallback, and narrow text-flow/layout cleanup |
| ZIP | archive/container conversion with nested dispatch and delegated PDF handling |
| EPUB | ZIP + OPF + spine + nav/NCX + XHTML chapter lowering, explicit strong noteref footnotes |
| HTML / HTM | lightweight safe parser with explicit noteref/body support; no browser engine, JS execution, or generic `<sup>` footnote inference |
| CSV / TSV | structured table lowering with conservative encoding/dialect handling |
| JSON / YAML / XML / TXT / Markdown | source-preserving or conservative structured/text paths |

Use [docs/supported-formats.md](./docs/supported-formats.md) for the detailed
support matrix and explicit limits.

## Validation Snapshot

Main-repo validation is currently green:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* `bash samples/check_quality.sh --format pdf`: `79` rows / `0` failed / `1`
  skipped / `0` expected_fail on the current repo-local
  `markitdown-quality-lab` checkout
* `bash samples/check_quality.sh`: `315` rows / `0` failed / `1` skipped /
  `0` expected_fail on the current repo-local `markitdown-quality-lab`
  checkout

Interpretation:

* these are checked local validation snapshots, not repository-wide quality percentages
* `0 expected_fail` does not mean every format boundary is universally covered
* OCR and scanned-document behavior remain explicit-only
* benchmark and compare numbers are sample-scoped, not universal performance guarantees

## Quality-Lab Boundary

The main repository is self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh`

The external quality gate is intentionally separate:

* `bash samples/check_quality.sh` expects
  `markitdown-quality-lab/external_quality/`
* missing or incomplete external corpus should fail clearly
* it does not fall back to repo-local quality rows

Optional external assets live in a separate repo cloned into the project root:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

That repo carries:

* `markitdown-quality-lab/external_quality/`
* `markitdown-quality-lab/external_quality/_quality_rows_staging/manifest.tsv`
* `markitdown-quality-lab/pdf_model_training/`
* `markitdown-quality-lab/external_quality/_tools/legacy_encoding/generate_cp936_blob.py`

It is an independent Git repository, not a submodule, and it is not part of
the release artifact set.

If the external corpus is absent or incomplete, `bash samples/check_quality.sh`
fails clearly and points back to `bash samples/check.sh` for repo-local
validation. It does not fall back to repo-local quality rows.

## Product And Tool Boundary

Current user-facing binaries:

* `cli`: normal product entrypoint
* `pdf`: bundled PDF runtime component
* `zip`: bundled ZIP runtime component

Current developer binaries:

* `debug`: inspect/report surface
* `bench`: benchmark surface
* `doc_parse/pdf/layout_model_tool`: PDF layout export/infer tool
* `convert/vision`: provider-independent OCRPageModel scaffold and future OCR
  implementation path

Important limits:

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* PDF layout behavior in the normal path is distilled into MoonBit rules/gates
* normal conversion never OCRs and never probes OCR providers
* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported in this build
* image inputs now auto-OCR through `convert/vision`
* image OCR requires local `tesseract`; missing runtime support fails clearly
* normal document conversion still stays no-OCR outside explicit image inputs
* debug/report helpers are diagnostics, not product entrypoints
* PDF OCR is not wired in this build
* main-repo OCR fixtures are tiny fixture-policy groundwork, not a current OCR
  accuracy gate
* PDF and ZIP stay on the product surface without pulling the full PDF closure into lightweight `cli`

## Performance Snapshot

Current local clean native build snapshot:

* `cli build`: `64.06s`
* `pdf build`: `69.07s`
* `zip build`: `63.48s`
* `cli.exe`: `3,790,168`
* `pdf.exe`: `4,354,040`
* `zip.exe`: `3,601,656`
* `cli.c`: `401,407`
* `pdf.c`: `450,869`
* `zip.c`: `378,571`
* `cli mbtpdf count`: `0`
* `zip mbtpdf count`: `0`
* `pdf mbtpdf count`: `23339`

Current overlap-only compare timing against Microsoft MarkItDown `0.1.5`:

* total runs: `282`
* overlap rows per runner: `47`
* `markitdown-mb`: `11.009 ms`
* `markitdown-python`: `421.715 ms`

Do not treat that compare run as a universal speed claim. It is a local,
sample-scoped timing snapshot on a named overlap corpus.

Use [docs/performance.md](./docs/performance.md) for measured build and
benchmark facts plus interpretation notes.

## Where To Go Next

* [docs/architecture.md](./docs/architecture.md): package, binary, and repository boundaries
* [docs/supported-formats.md](./docs/supported-formats.md): supported formats and explicit limits
* [docs/quality-and-release.md](./docs/quality-and-release.md): validation layers, quality-lab boundary, and release workflow
* [docs/pdf.md](./docs/pdf.md): PDF text/layout/OCR boundary
* [docs/performance.md](./docs/performance.md): measured build, benchmark, and interpretation notes
* [docs/roadmap.md](./docs/roadmap.md): current direction and legacy fallback removal plan
