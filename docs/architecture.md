# Architecture Overview

This document describes the current repository architecture. It intentionally
focuses on the active design, not the full historical path used to reach it.

## Pipeline

The current project follows this layered flow:

**CLI -> dispatcher -> format converters / parsers -> unified IR -> Markdown / assets / metadata**

The key idea is to keep parsing, recovery, representation, and output concerns
separate enough that behavior stays explainable and regression-verifiable.

## Main Layers

### CLI

`cli/` is responsible for:

* subcommand parsing
* output path coordination
* `--with-metadata`
* debug/ocr mode selection

It does not implement format-specific parsing or recovery.

### Dispatcher

`convert/convert/dispatcher.mbt` is responsible for extension-based routing.

It currently routes:

* `docx`
* `pptx`
* `xlsx`
* `pdf`
* `html` / `htm`
* `csv` / `tsv`
* `json`
* `yaml` / `yml`
* `md` / `markdown`
* `txt`
* `xml`
* `zip`
* `epub`

It only chooses the converter; it does not own recovery strategy.

### Low-level parsing infrastructure

`doc_parse/*` provides reusable foundations:

* `doc_parse/zip`: ZIP reader and container primitives
* `doc_parse/ooxml`: OOXML package / relationships / media / docProps helpers
* `doc_parse/pdf`: native PDF substrate and inspect/debug-facing raw data
* `doc_parse/epub`: EPUB package parsing for `container.xml`, OPF, manifest, and spine

These packages are infrastructure, not final Markdown semantics.

### Format converters

`convert/*` maps source formats into unified IR and handles conservative
degradation.

Current format families:

* OOXML:
  * `convert/docx`
  * `convert/pptx`
  * `convert/xlsx`
* PDF:
  * `convert/pdf`
* HTML:
  * `convert/html`
* Structured data:
  * `convert/csv` for CSV / TSV
  * `convert/json`
  * `convert/yaml`
  * `convert/xml`
* Text-like:
  * `convert/markdown`
  * `convert/txt`
* Container:
  * `convert/zip`
* Ebook:
  * `convert/epub`

### Unified IR

`core/ir.mbt` provides the shared representation:

* `Document`
* `Block`
* `Inline`
* `ImageData`
* `block_origins`
* `asset_origins`
* optional `passthrough_markdown`

This layer is what makes cross-format Markdown, metadata, and asset behavior
consistent enough to test as one tool rather than a pile of unrelated parsers.

### Output layers

`core/emitter_markdown.mbt` handles Markdown emission.

`core/metadata.mbt` handles sidecar emission.

Asset export is driven by converters plus CLI output-directory coordination.

## Format-family View

### OOXML

DOCX / PPTX / XLSX share:

* ZIP package handling
* relationships
* media indexing
* document properties

This is why OOXML support is not implemented as three fully isolated parsers.

### PDF

PDF has its own native substrate:

* page geometry
* text structures
* raw image extraction
* annotation/link data
* inspect/debug surfaces

The default mainflow uses conservative structural recovery rather than OCR-first
or visual-page reconstruction.

### HTML

HTML is a lightweight semantic converter:

* structural tags map into IR
* inline links and local images are preserved within current limits
* browser/CSS/JS semantics are intentionally out of scope

### Text-like

TXT and Markdown are intentionally different:

* TXT is conservative paragraph conversion
* Markdown is source-preserving passthrough

### Structured data

CSV / TSV / JSON / YAML / XML are not treated as one semantic family, but they
share a “conservative and stable” philosophy:

* CSV / TSV -> tables
* JSON / YAML -> conservative table / list / code-block mapping
* XML -> source-preserving fenced code-block output

### Container

ZIP is not just “unzip and concatenate”.

It adds:

* safe path normalization
* supported-entry dispatch
* archive warning fallback
* archive asset namespace/remap
* safe extracted-tree handling for ZIP HTML local images

### Ebook

EPUB is not treated as generic ZIP traversal.

It adds:

* `container.xml` lookup
* OPF rootfile handling
* manifest/spine parsing
* spine-order aggregation
* safe same-archive local-image handling for XHTML/HTML spine documents

## Metadata And Assets

The repository treats Markdown main output and engineering sidecar output as
different layers:

* Markdown is for reading
* metadata is for provenance / indexing / auditing
* assets are for materialized exported resources

Current provenance is intentionally lightweight:

* block-level origin
* asset-level origin
* additive sparse fields

It is not a full layout trace or DOM/object anchoring model.

## Debug / Regression / Benchmark

The repository includes explicit non-production support layers:

* debug pipeline for PDF
* regression chains under `samples/main_process`, `samples/metadata`,
  `samples/assets`
* compact acceptance demo samples under `samples/test`
* internal smoke benchmark
* overlap-only comparison benchmark

These are part of the architecture in practice because they enforce contract
stability and provide explainability beyond “the converter happened to run”.
