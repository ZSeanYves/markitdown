# Progress Summary

This document is a current-stage status summary, not a full development log.
It answers three questions:

* what is already landed
* what is currently stable enough to treat as project contract
* what remains as next-stage priority work

For detailed format-by-format behavior, use
[docs/support-and-limits.md](./support-and-limits.md).

## Current Stage

The repository is now in a documented multi-format product-hardening stage:

* MoonBit-native CLI is in place
* unified IR / Markdown emitter / metadata sidecar are in place
* major format families are connected to one dispatcher-driven mainflow
* sample regression and benchmark harnesses are in place
* sample validation temp-dir isolation is in place
* TXT / Markdown now have stable H2-complete support contracts
* CSV / TSV now have stable H2-complete support contracts
* JSON now has a stable H2-complete support contract
* YAML / YML now has a stable H2-complete support contract
* XML now has a stable H2-complete support contract
* HTML / HTM now have stable H2-complete support contracts
* XLSX now has a stable H2-complete support contract
* ZIP now has a stable H2-complete support contract
* EPUB now has a stable H2-complete support contract
* ZIP / EPUB archive entry temp-dir isolation is fixed for repeated asset and
  diff validation runs
* DOCX / PPTX now have stable H2-complete support contracts after deeper
  closure work
* PDF has completed its core-first H2/P4 pass, conservative table/image-caption
  hardening, and final closure re-audit, and now has a stable H2-complete
  support contract
* H3 benchmark discipline audit/plan is documented
* H3.2 batch benchmark mode design is documented
* CLI batch mode v1 is implemented for non-recursive directory conversion
* H3.3 batch profiling harness and first startup/throughput/memory report are
  documented
* H3.4 batch profiling scale extension is documented for `1 / 3 / 8 / 16`
  groups and metadata on/off profiling
* H3.5 manual benchmark regression warning prototype is in place with
  conservative checked-in thresholds
* H1 is not final parity completion; H2 / H3 remain

## Full-format hardening milestone

The repository has completed its first full-format hardening milestone:

* all primary formats now have H2-complete support contracts
* stable support/limits wording, regression coverage, and benchmark framing
  are in place across the main format families
* lower-layer/parser deliverables are now explicit parts of the product story,
  not just converter internals

The next phase is centered on H3 benchmark discipline, larger-corpus
profiling, release/documentation polish, and selective H2.1 quality work
rather than simply wiring more formats.

See [docs/full-format-hardening-milestone.md](./full-format-hardening-milestone.md)
for the full status table, benchmark/comparison framing, non-goals, and the
current next-stage Top 10.

## Supported Format Families

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

## Current Status Summary

* TXT / Markdown: H2 complete
* CSV / TSV: H2 complete
* JSON: H2 complete
* YAML / YML: H2 complete
* XML: H2 complete
* HTML / HTM: H2 complete
* XLSX: H2 complete
* ZIP: H2 complete
* EPUB: H2 complete
* DOCX: H2 complete
* PPTX: H2 complete
* PDF: H2 complete

## Implemented Capability Groups

### Core pipeline

* CLI with `normal / ocr / batch / debug`
* dispatcher-based extension routing
* unified IR
* Markdown emitter
* metadata sidecar
* asset export

### Parsing infrastructure

* shared ZIP reader
* shared OOXML package / relationships / media / docProps helpers
* native PDF substrate via `doc_parse/pdf`

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
* ZIP inspect/inventory surface for deterministic entry planning/debug
* ZIP support for `.txt` and `.xml` entries through normal dispatcher routing
* EPUB `container.xml -> OPF -> manifest/spine` conversion
* EPUB nav/TOC and cover detection with conservative emission policy
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

## Current Validation Status

The repository currently expects the following checks to pass together:

```bash
moon check
moon test
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_samples.sh
./samples/scripts/bench_smoke.sh --kind smoke
```

## Next-stage Priorities

Current recommended next priorities are:

* H3 benchmark discipline: batch mode design follow-through, scale
  normalization, and optional memory probing
* larger real-world corpora for PDF / DOCX / PPTX / XLSX / EPUB
* release/documentation polish and user-facing packaging cleanup
* EPUB future quality work such as NCX / broader anchor semantics
* selective H2.1 quality upgrades where product value is clear, without
  hiding current documented limitations
## 2026-05-04

* tightened PDF page-number candidate scoping after numeric-table preservation:
  numeric table cells now survive into conservative table detection, while true
  edge/trailing page numbers are re-caught by later noise policy
* final PDF H2 closure re-audit completed: simple high-confidence tables and
  image captions are now treated as sufficient H2 coverage, with complex
  tables, multi-column recovery, outlines/internal links, tagged PDF, and OCR
  kept as documented limitations
* test architecture audit completed: `test/` subpackages remain the home for
  black-box/package tests, while root `*_wbtest.mbt` files are now explicitly
  treated as the correct MoonBit white-box mechanism for package-private helper
  coverage
* PDF black-box caption coverage was strengthened so conservative caption
  behavior is guarded at the package seam in addition to white-box helper and
  metadata-chain coverage
* sample validation UX was cleaned up: PPTX warnings removed, validation now
  uses a shared runner-resolution path that prefers a probe-validated native
  CLI and falls back to `moon run` when the local binary is stale, and the
  main regression/metadata/assets scripts now use compact progress plus final
  failure summary output
* vendored PDF backend packaging was normalized: `vendor/mbtpdf` is now used
  as a repository-local package tree, and the root module no longer carries a
  path-only external upstream dependency for the PDF backend
