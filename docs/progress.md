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
* the project has entered format-by-format hardening
* recent H1 baselines: TXT, Markdown, CSV / TSV, JSON, YAML, XML
* EPUB H1/H2 ebook review is completed with package/spine baseline coverage and
  smoke benchmark enrollment
* DOCX H2 market-parity review is completed with baseline benchmark,
  assets/metadata coverage, and overlap-only comparison refresh
* PPTX H2 layout-quality review is completed with smoke/comparison refresh and
  current layout/assets coverage audit
* PDF H2 core-gap review is completed; next PDF work is core-first signal and
  debug surface strengthening before more convert-layer heuristics
* PDF P1 `pdf_core` model/debug signal pass is underway with inspect/debug
  surface tightening and reusable signal-helper cleanup
* PDF P1.1 annotation/link signal pass has started with internal-destination
  coverage and outline gap clarification
* PDF P2 annotation/link emission policy review is underway to keep link
  emission conservative and geometry-driven
* PDF P2.2 high-confidence single-line URI link emission is landed without
  changing internal-destination or ambiguous-link behavior
* H1 is not final parity completion; H2 / H3 remain

## Current Hardening Focus

The project has entered full-format H2 / H3 gap review.

H1 baseline is complete for TXT, Markdown, CSV, TSV, JSON, YAML, XML, and
dedicated H1/H2 review docs now exist for HTML, XLSX, ZIP, EPUB, DOCX, and
PPTX. PDF now has a dedicated H2 core-gap audit and planning document.

Next work will prioritize market-parity quality and performance leadership
across all supported formats.

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
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

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
* HTML / HTM H1/H2 review is completed with baseline coverage and smoke corpus
  expansion
* XLSX H1/H2 review is completed with current formula / merged / hidden-sheet
  policy fixed by regression and smoke coverage expansion
* ZIP H1/H2 container review is completed with metadata coverage, safety
  regression, and smoke corpus expansion
* DOCX H2 market-parity review is completed with smoke/comparison refresh and
  metadata/assets coverage tightening
* PPTX H2 layout-quality review is completed with smoke/comparison refresh and
  existing layout/assets coverage reuse
* PDF H2 core-gap review is completed with `pdf_core` vs `convert/pdf`
  responsibility audit, regression inventory, and benchmark/comparison gap
  planning
* PDF P1 `pdf_core` model/debug pass is started with inspect dump, signal
  helpers, and dedicated test-entry groundwork
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
* PDF core-first signal/debug upgrade round
* EPUB nav / TOC semantic reconstruction
* EPUB CSS / semantic refinement
* ZIP HTML dependency refinement beyond safe sibling materialization
* XLSX merged cells / formula policy refinement
* PPTX notes / advanced layout refinement
* PPTX lower-layer table / notes / hidden-slide signal upgrade
* benchmark comparison refresh
* release packaging / versioned baseline
