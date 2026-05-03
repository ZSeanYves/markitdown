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
* TXT / Markdown / CSV / TSV / JSON / YAML / XML have H1 baselines in place
* HTML / XLSX / ZIP / EPUB have completed review passes and stronger baselines
* DOCX / PPTX have completed H2 review passes
* PDF has completed a core-first H2/P4 pass through benchmark/comparison
  refresh
* H1 is not final parity completion; H2 / H3 remain

## Full-format hardening milestone

The repository has completed its first full-format hardening milestone:

* text/structured formats have H1 baselines in place
* HTML / XLSX / ZIP / EPUB have documented H1/H2 review outcomes and stronger
  baselines
* DOCX / PPTX H2 review passes are completed
* PDF has completed a core-first H2/P4 pass through benchmark/comparison
  refresh

The next phase is centered on H2/H3 product-quality gaps, lower-layer upgrades,
and tighter benchmark discipline rather than simply wiring more formats.

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

* TXT / Markdown / CSV / TSV / JSON / YAML / XML: H1 complete
* HTML / XLSX / ZIP / EPUB: reviewed and baseline-strengthened
* DOCX / PPTX: H2 review completed
* PDF: core-first H2/P4 pass completed through benchmark/comparison refresh

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

## Next-stage Priorities

Current recommended next priorities are:

* temp-dir isolation for sample/benchmark scripts
* H3 benchmark discipline: batch / large / memory profiling
* HTML lower-layer upgrades
* XLSX lower-layer upgrades
* ZIP lower-layer upgrades
* EPUB nav / TOC / cover / anchors
* DOCX advanced OOXML semantics
* PPTX explicit table / notes / group-shape work
* PDF tables / image captions / outlines / internal links
* release/documentation polish
