# markitdown-mb

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown tool.
It is inspired by Microsoft MarkItDown’s product direction, but it is not a
Python wrapper or Python-port clone. The project focuses on conservative,
auditable conversion, stable degradation, and reusable parsing infrastructure.

All primary repository formats now have **H2-complete** support contracts:
common lightweight-conversion expectations are met, while harder layout and
format-specific edge cases remain explicitly documented as limitations rather
than hidden unresolved gaps.

The current pipeline is:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Current Scope

Supported input families:

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

Core project capabilities:

* MoonBit native CLI
* self-managed OOXML / ZIP / PDF foundations
* unified IR
* Markdown emitter
* asset export
* metadata sidecar
* origin provenance
* PDF debug pipeline
* regression samples
* internal and comparison benchmark harnesses

PDF lower-layer note:

* the native PDF path uses `doc_parse/pdf` plus a repository-local maintained
  vendored backend under `vendor/mbtpdf`
* `vendor/mbtpdf` is maintained in-repo for markitdown-specific PDF parser
  needs; it is not treated as a path-only external dependency during publish

## H2 Milestone

The current H2 milestone is complete across the main format set:

* TXT
* Markdown
* CSV / TSV
* JSON
* YAML / YML
* XML
* HTML / HTM
* XLSX
* ZIP
* EPUB
* DOCX
* PPTX
* PDF

`H2 complete` does **not** mean every complex format feature is implemented.
It means the repository now reaches a stable, auditable, mainstream
lightweight-conversion baseline for these formats while keeping major
limitations explicit in the support contract.

## Format Matrix

| Format | Status | Highlights | Known limitations |
| --- | --- | --- | --- |
| TXT | H2 complete | literal-safe paragraph conversion, metadata | UTF-8-only conservative policy, no semantic Markdown inference |
| Markdown | H2 complete | source-preserving passthrough, metadata | not a Markdown AST rewrite / normalization engine |
| CSV / TSV | H2 complete | stable table lowering, `RichTable` metadata | no streaming or huge-table H3 tuning yet |
| JSON | H2 complete | conservative structured-data lowering, metadata | no streaming/materialization optimization yet |
| YAML / YML | H2 complete | fail-closed supported subset, structured-data lowering | not a full YAML feature-complete parser |
| XML | H2 complete | source-preserving fenced `xml` output, safe tokenizer base | not a semantic XML-family renderer |
| HTML / HTM | H2 complete | semantic text/tables/links/images, `RichTable` metadata | no CSS/JS execution, no rowspan/colspan reconstruction |
| XLSX | H2 complete | workbook/sheet/cell lower layer, datetime handling, metadata | no charts/comments/pivots, no merged-cell visual reconstruction |
| ZIP | H2 complete | safe archive traversal, inspect surface, nested asset remap | no recursive nested archive conversion, no ZIP64/data-descriptor deep work yet |
| EPUB | H2 complete | container/OPF/spine/nav/cover/assets pipeline | richer anchor/NCX semantics remain future work |
| DOCX | H2 complete | lists, tables, notes/comments, headers/footers, text boxes, metadata | no full tracked-change UI, no full run-level style fidelity, no complex visual table reconstruction |
| PPTX | H2 complete | grouped shapes, explicit tables, notes, hidden slides, images | no charts/SmartArt/OLE/action links/animations, no full merged-table visual reconstruction |
| PDF | H2 complete | headings/noise/merge, URI links, simple tables, captions, provenance | no complex table engine, no outlines/internal Dest output, no OCR-default or full multi-column recovery |

## Output Model

The tool can produce:

* Markdown main output
* `assets/` export when the source contains materialized images
* `metadata/*.metadata.json` sidecar when `--with-metadata` is enabled

Typical layout:

```text
out/
  demo.md
  assets/
    image01.png
  metadata/
    demo.metadata.json
```

## Quick Start

Normal conversion:

```bash
moon run cli -- normal <input> [output]
```

With metadata sidecar:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
```

Other entrypoints:

```bash
moon run cli -- ocr <input> [output]
moon run cli -- batch <input_dir> <output_dir>
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

Batch v1 directory conversion:

```bash
moon run cli -- batch --with-metadata <input_dir> <output_dir>
```

Batch v1 writes one isolated document root per top-level input file:

```text
out/
  001-demo/
    demo.md
    assets/
    metadata/demo.metadata.json
```

Notes:

* `ocr` is a separate path, not the default mainflow
* `ocr` should be treated as optional/experimental relative to the native PDF
  path; it is not the repository's default support contract
* `batch` is non-recursive in v1; it scans only the top-level files in
  `<input_dir>`
* stdout mode only prints Markdown; it does not write sidecar files
* if `[output]` looks like a directory, the tool writes `<output>/<input_stem>.md`
* `--with-metadata` writes `<markdown_dir>/metadata/<stem>.metadata.json`
* emitted image assets are written under `assets/` beside the Markdown output;
  archive and nested-document formats may namespace assets conservatively under
  `assets/archive/...`

## Support Summary

Current supported input families:

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

Important boundaries:

* TXT is plain-text paragraph conversion; it does not infer Markdown semantics
* XML is source-preserving fenced `xml` code-block conversion; it is not a
  semantic XHTML / RSS / OPF / SVG converter

For the full per-format support contract and limits, see
[docs/support-and-limits.md](./docs/support-and-limits.md).

## Regression And Benchmark

Regression is split into three chains:

* `samples/main_process`
* `samples/metadata`
* `samples/assets`

Useful commands:

```bash
./samples/check.sh
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
```

Internal smoke benchmark:

```bash
./samples/scripts/bench_smoke.sh --kind smoke
```

Overlap-only comparison benchmark:

```bash
./samples/scripts/bench_compare_markitdown.sh --help
```

The comparison benchmark uses a user-managed external `markitdown` command. It
does not create a repository-local Python virtual environment.

Benchmark interpretation:

* selected overlap cases already show clear same-machine speed wins for the
  native repository runner
* these are **selected** overlaps, not blanket semantic- or performance-parity
  claims for every document shape
* when a benchmark falls back to `moon run`, measured time includes wrapper
  overhead; prebuilt native CLI runs are the stronger performance reference

## Project Positioning

This repository is not aimed at pixel-perfect layout reproduction. The current
engineering priorities are:

* conservative structural recovery
* auditable provenance and debug surfaces
* stable, explainable degradation
* regression-verifiable behavior
* reusable content-processing infrastructure

OCR, cloud services, LLM-style understanding, and complex visual reasoning are
not part of the default `normal` mainflow contract.

## Documentation

* [Support and Limits](./docs/support-and-limits.md)
* [Full-format H2 Completion](./docs/full-format-h2-completion.md)
* [Full-format Hardening Milestone](./docs/full-format-hardening-milestone.md)
* [Architecture](./docs/architecture.md)
* [Development Guide](./docs/development.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Progress Summary](./docs/progress.md)
* [Benchmark Baseline](./docs/benchmark-baseline.md)
* [Benchmark Comparison](./docs/benchmark-comparison.md)
* [Benchmark Comparison Baseline](./docs/benchmark-comparison-baseline.md)
* [Sample Coverage](./docs/sample-coverage.md)
* [Changelog](./CHANGELOG.md)
