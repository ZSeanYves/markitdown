# Progress Summary

This document is a current-stage status summary, not a full development log.
It answers three questions:

* what is already landed
* what is currently stable enough to treat as project contract
* what remains as next-stage candidate work

For detailed format-by-format behavior, use
[docs/support-and-limits.md](/home/zseanyves/markitdown/docs/support-and-limits.md).

## Current Stage

The repository is now in a documented multi-format baseline stage:

* MoonBit-native CLI is in place
* unified IR / Markdown emitter / metadata sidecar are in place
* major format families are connected to one dispatcher-driven mainflow
* sample regression and benchmark harnesses are in place
* TXT and XML conservative conversion are completed and no longer candidate work

## Implemented Capability Groups

### Core pipeline

* CLI with `normal / ocr / debug`
* dispatcher-based extension routing
* unified IR
* Markdown emitter
* metadata sidecar
* asset export

### Parsing infrastructure

* shared ZIP reader
* shared OOXML package / relationships / media / docProps helpers
* native PDF substrate via `pdf_core`

### Supported format families

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* CSV / TSV
* JSON
* YAML / YML
* Markdown / MD / MARKDOWN
* TXT
* XML
* ZIP
* EPUB

### Current container / ebook scope

* ZIP safe-entry conversion with archive asset namespace/remap
* ZIP support for `.txt` and `.xml` entries through normal dispatcher routing
* EPUB `container.xml -> OPF -> manifest/spine` conversion
* EPUB same-archive local-image handling through a safe extracted tree

### Provenance / metadata / image context

* additive origin population inside existing metadata schema
* block-level and asset-level provenance
* OOXML / PDF / HTML image-context population
* document properties for OOXML and EPUB where available

### Validation and benchmarking

* `samples/main_process`
* `samples/metadata`
* `samples/assets`
* `samples/test` compact acceptance demo
* internal smoke benchmark
* overlap-only MarkItDown comparison benchmark

## Recently Landed

Recent completed additions worth calling out explicitly:

* TXT conservative paragraph conversion
* XML conservative source-preserving conversion
* ZIP asset namespace/remap and same-archive HTML local-image handling
* EPUB spine-based conversion
* repository-local `.venv` dependency removal from comparison benchmark workflow

## Current Validation Status

The repository currently expects the following checks to pass together:

```bash
moon check
moon test
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/check_samples.sh
./samples/bench_smoke.sh --kind smoke
```

## Next-stage Candidates

Current recommended next candidates are:

* OCR regression closure
* PDF core / convert next round
* EPUB nav / TOC semantic reconstruction
* EPUB CSS / semantic refinement
* ZIP HTML dependency refinement beyond safe sibling materialization
* XLSX merged cells / formula policy refinement
* PPTX notes / advanced layout refinement
* benchmark comparison refresh
* release packaging / versioned baseline
