# markitdown-mb (MoonBit)

A document conversion tool implemented in **MoonBit**, inspired by Microsoft **markitdown**, for converting **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

---

## Project Overview

The current main pipeline of the repository can be summarized as:

**docx / pdf / xlsx / pptx / html -> IR -> Markdown**

Where:

* `convert/convert/dispatcher.mbt` dispatches files by extension to the corresponding format parser
* `core/ir.mbt` defines the unified Intermediate Representation (IR)
* `core/emitter_markdown.mbt` emits Markdown from the IR

---

## Current Status

### Overall Summary

* A unified multi-format conversion pipeline has been implemented: **DOCX / PDF / XLSX / PPTX / HTML -> IR -> Markdown**
* A sample-based regression suite is in place as the primary behavior guardrail
* **DOCX / XLSX / HTML** are already relatively stable within the current project scope
* **PDF / PPTX** have clearly moved beyond plain text extraction and now include structure recovery and layout-oriented heuristics
* **PPTX** is currently one of the most actively enhanced pipelines, with the richest layout-recovery capabilities and the strongest sample coverage
* The CLI has been switched to subcommands: `normal / ocr / debug`

### Important Current Facts

* **PDF on `main` is still an external text-first pipeline**, not the `pdf_core` pipeline
* OCR is currently positioned as a **dedicated OCR path / experimental enhancement path**, not the default PDF flow
* The current main regression directories are `samples/<format>/` and `samples/expected/<format>/`

---

## Repository Layout (Current)

### `cli/`

Command-line entry layer.

* `main.mbt`: main CLI entry, parses subcommands, validates arguments, and prints usage
* `cli_app.mbt`: command orchestration, builds `ConvertOptions`, calls the unified conversion entry, and outputs Markdown
* `cli_args.mbt`: argument normalization helpers
* `moon.pkg`: CLI package definition; the executable entry is declared here

### `convert/convert/`

Format dispatch layer.

* `dispatcher.mbt`: dispatches by file extension to the `docx / pdf / xlsx / pptx / html` parsers; this is the unified cross-format entry

### `core/`

Shared core infrastructure.

* `ir.mbt`: unified IR definitions (such as `Document` / `Block`)
* `emitter_markdown.mbt`: IR -> Markdown emission
* `tool.mbt`: common text, path, entity-decoding, and helper utilities
* `errors.mbt`: shared error definitions

### `convert/docx/`

DOCX parsing pipeline.

* `docx_parser.mbt`: top-level `parse_docx()` entry
* `docx_document.mbt`: document-body scanning and document assembly
* `docx_table.mbt`: key rule layer for paragraph classification and table parsing
* `docx_styles.mbt`: style parsing for heading / quote / code-like detection
* `docx_numbering.mbt`: numbering parsing for ordered / unordered / nested list recovery
* `docx_package.mbt` / `docx_rels.mbt` / `docx_xml.mbt` / `docx_types.mbt`: OOXML access and lower-level DOCX helpers

### `convert/pdf/`

PDF parsing pipeline.

* `pdf_parser.mbt`: top-level `parse_pdf()` entry
* `pdf_backend.mbt`: external extraction backend calls (such as `pdftotext` / `mutool`)
* `pdf_extract.mbt`: extraction-stage orchestration
* `pdf_select.mbt`: candidate quality scoring and selection
* `pdf_ocr.mbt`: OCR path and sidecar handling
* `pdf_enhance.mbt`: PDF enhancement hook
* `pdf_to_ir.mbt`: main post-processing path for page handling, noise cleanup, cross-page merging, and block recovery into IR
* Other PDF-related modules provide helpers for heading / list / noise / page / text logic

### `convert/xlsx/`

XLSX parsing pipeline.

* `xlsx_parser.mbt`: top-level entry
* `xlsx_sheet.mbt`: sheet-level scanning, cell parsing, sparse trimming, and table normalization
* `xlsx_styles.mbt`: style parsing
* `xlsx_datetime.mbt`: date / time / datetime formatting
* `xlsx_package.mbt` / `xlsx_shared_strings.mbt` / `xlsx_xml.mbt`: lower-level XLSX helpers

### `convert/pptx/`

PPTX parsing pipeline.

* `pptx_parser.mbt`: top-level entry
* `pptx_reading_order.mbt`: main reading-order recovery path, handling title/body separation, two-column layouts, grouping, and final order flattening
* `pptx_table_like.mbt`: detection and stabilization of table-like / grid-like regions
* `pptx_grouping.mbt` / `pptx_group_candidates.mbt`: grouping and candidate detection for caption-like / note-like / callout-like regions
* `pptx_noise.mbt`: conservative cleanup for page numbers, corner labels, and similar noise
* `pptx_slide.mbt` / `pptx_text.mbt`: extraction of shape text, bullet properties, and paragraph metadata
* `pptx_types.mbt` / `pptx_geom.mbt` / `pptx_shape_collect.mbt` / `pptx_layout_base.mbt` / `pptx_paragraph_meta.mbt` / `pptx_classify.mbt`: local modules for PPTX layout recovery

### `convert/html/`

HTML parsing pipeline.

* `html_parser.mbt`: top-level entry
* `html_dom.mbt`: lightweight DOM-like scanning and the main path for block / inline / container recovery
* `html_to_ir.mbt`: HTML structure -> IR
* `html_bytes.mbt`: byte-level scanning helpers

### `doc_parse/`

Low-level document parsing support.

* `doc_parse/ooxml/`: OOXML package / relationship / part access
* `doc_parse/zip/`: zip reading and decompression primitives

### `samples/`

Samples and regression tests.

* `samples/docx/` / `pdf/` / `xlsx/` / `pptx/` / `html/`: input samples
* `samples/expected/<format>/`: golden Markdown outputs
* `samples/check_samples.sh`: checks that input/expected pairs are complete
* `samples/diff.sh`: batch conversion and diffing against golden outputs

---

## CLI (Current Real Usage)

The current CLI uses a **subcommand-based interface** with only three top-level entries:

```bash
moon run cli -- normal <input> [output]
moon run cli -- ocr <input> [output]
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

### `normal`

Normal conversion mode.

```bash
moon run cli -- normal input.pdf
moon run cli -- normal input.docx out.md
```

Meaning:

* Runs the current normal conversion pipeline
* Does not proactively enable OCR
* Intended for regular users

### `ocr`

OCR mode.

```bash
moon run cli -- ocr scanned.pdf
moon run cli -- ocr scanned.pdf out.md
```

Meaning:

* Explicitly targets scanned or image-based PDFs
* Enables the OCR route
* Does not expose internal names such as `experimental` to end users

### `debug`

Development-time debugging mode.

```bash
moon run cli -- debug all input.pdf
moon run cli -- debug extract input.pdf
moon run cli -- debug raw input.pdf
moon run cli -- debug pipeline input.pdf
```

Supported debug scopes:

* `all`
* `extract`
* `raw`
* `pipeline`

Approximate meaning:

* `debug all`: enables all PDF debugging capabilities
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF pipeline

---

## Current Capabilities by Format

### DOCX

The DOCX pipeline already provides relatively stable structured conversion, including:

* heading recovery
* ordered / unordered / nested list recovery
* table parsing
* image export and Markdown references
* blockquote detection
* code-like paragraph recovery
* line-break handling in paragraphs and table cells

The current main path is roughly:

`parse_docx -> scan_document -> scan_paragraph / scan_table_block -> IR`

Implementation characteristics:

* heading detection relies mainly on style mapping
* list recovery relies mainly on numbering metadata
* quote-like and code-like detection still uses conservative heuristics

Current boundaries and limitations:

* quote-like / code-like detection for multilingual or non-standard style names is still conservative
* some style generalization still depends mainly on heuristic naming rules

### PDF

The current PDF pipeline on `main` is still:

**external text-first**

That is:

`pdftotext / mutool -> quality scoring and selection -> cleanup -> text-to-IR`

Current capabilities include:

* multi-backend text extraction and selection
* page-noise cleanup
* repeated header/footer cleanup
* heading / short-sentence boundary recovery
* paragraph / block recovery
* basic list-item recovery
* cross-page paragraph merging
* hardwrap recovery (with at least English / Chinese coverage)
* conservative handling of obvious pseudo two-column negative cases

Current OCR positioning:

* not part of the default `normal` path
* treated as a dedicated OCR route / experimental enhancement route
* mainly intended for scanned or image-based PDFs

Current explicit fact:

* `pdf_core` **does not participate in the `main` pipeline at present**; it is being steadily developed in the `pdf-native-mainflow-lab` branch

Current boundaries and limitations:

* the main path is still text-first rather than an event/line/block-native structure-recovery chain
* OCR has not yet been fully integrated into the complete expected-output regression suite
* more complex layouts still depend mainly on heuristic post-processing

### XLSX

The XLSX pipeline is already relatively stable, including:

* multi-sheet output
* handling of shared string / inline string / bool / error / number cells
* sparse table trimming
* sparse-edge bounding-box tightening
* built-in and custom datetime formatting
* table-width normalization

The current main path is roughly:

`parse_xlsx -> parse_sheet_table -> resolve_cell_text -> normalize table -> IR`

Current boundaries and limitations:

* no formula evaluation
* merged cells are not currently treated as a richer structural-recovery target

### PPTX

PPTX remains **one of the most actively enhanced layout-recovery pipelines** in the project.

Current capabilities include:

* real slide-order recovery
* title / body separation
* bullet-property-first list recovery
* ordered / unordered / nested list recovery
* shape-aware reading order
* conservative two-column handling
* note-like / caption-like / callout-like grouping
* table-like / grid-like region detection and stabilization
* conservative page-number / corner-label noise filtering
* modularized local layout-recovery components

The current implementation focus is no longer simply “concatenate text boxes in order”, but increasingly centers on:

* shape geometry
* group candidates
* reading-order recovery
* conservative stabilization of table-like regions

Sample coverage is already strong, including both positive and negative cases, especially for:

* strong table-like cases
* local table-like cases
* note/caption scatter
* callout blocks
* two-column layouts
* negative table-like timeline / negative cards / dense keyword wall cases

Current boundaries and limitations:

* negative cases are still conservatively downgraded to ordered paragraphs rather than upgraded into richer structured-table semantics
* table-like stabilization is currently more about region/order recovery than full table-level IR semantics

### HTML

The HTML pipeline is no longer a simple flattened-text path and now includes local structure recovery.

Current capabilities include:

* headings / paragraphs / list items
* ordered / unordered / nested lists
* block quotes
* pre / code blocks
* tables
* explicit `<br>` preservation
* a lightweight inline model (at least `Text + Break`)
* local structure recovery inside list-item containers
* local structure recovery inside blockquote containers
* local mixed-content cases such as text + paragraph / nested blockquote

The current main path is closer to:

`scan bytes -> build lightweight HTML-local structure -> HtmlNode -> IR`

Current boundaries and limitations:

* it is still a lightweight DOM-like model rather than a browser-grade full HTML semantic model
* more complex containers and deeply nested cases are still handled conservatively

### IR + Markdown Emitter

The unified IR is the structural core of the whole project.

Current block types include:

* `Heading`
* `Paragraph`
* `ListItem`
* `BlockQuote`
* `CodeBlock`
* `Table`
* `Image`
* `BlankLine`

The Markdown emitter is responsible for converging final output behavior across formats, including:

* heading emission
* list-level indentation
* paragraph-internal line breaks emitted as `<br>`
* table-column padding
* unified rendering for quotes, code blocks, images, and more

This is also the shared foundation for future cross-format structural enhancements.

---

## Sample Regression Coverage (Current)

Based on the current repository state, the approximate sample counts are:

* `docx`: 13
* `pdf`: 17
* `xlsx`: 12
* `html`: 32
* `pptx`: 46

The current sample system uses a one-to-one enrollment model between input files and expected outputs, maintained mainly by:

* `samples/check_samples.sh`
* `samples/diff.sh`

### DOCX Coverage

Currently covers:

* heading levels
* ordered / unordered / nested / mixed lists
* multiline table cells
* blockquotes
* code-like paragraphs
* not-code negative cases
* image / table / golden samples

### PDF Coverage

Currently covers:

* simple text
* multipage text
* hardwrap cases, including Chinese and English related samples
* repeated header/footer cleanup
* page-noise cleanup
* cross-page merge positive and negative cases
* heading recovery
* heading false-positive negative cases
* two-column negative cases

### XLSX Coverage

Currently covers:

* cell types
* sparse trimming
* sparse-edge cases
* multi-sheet workbooks
* built-in datetime
* custom datetime / date / time related cases

### PPTX Coverage

This is one of the richest sample groups and currently covers:

* basic slides
* title/body structure
* real presentation order
* list recovery
* ordered / nested lists
* two-column layouts
* note-like grouping
* caption scatter
* callout blocks
* table-like / grid-like positives
* local table-like positives
* multiple table-like negative cases
* timeline negatives
* dense keyword wall negatives
* page-number / corner-label noise cases

### HTML Coverage

Currently covers:

* simple content
* mixed block content
* ordered / unordered / nested lists
* `<br>` variants
* blockquote mixed text / paragraph / nested cases
* list-item multi-paragraph / mixed-text / nested-list cases
* basic tables
* ragged table rows
* pre / code blocks

> Note: OCR-related inputs already exist, but they have not yet been integrated into the expected-output regression suite as fully as the main PDF samples.

---

## Regression and Scripts

### Main Regression Entrypoints

* `samples/check_samples.sh`: checks whether input/expected sample pairs are complete
* `samples/diff.sh`: batch converts samples and diffs them against `samples/expected/<format>/`

---

## External Dependencies

### PDF

The PDF pipeline currently depends on at least one external system tool. Installing both is recommended, since otherwise output quality may be affected:

* `pdftotext` (Poppler)
* `mutool` (MuPDF)

### OCR

The OCR path additionally requires:

* `ocrmypdf`

### OOXML / Package Handling

The repository already includes internal `doc_parse/ooxml/` and `doc_parse/zip/` support as the low-level foundation for Office-family package handling.

---

## Current Engineering Direction

### Near-Term Priorities

1. Continue strengthening PPTX layout-recovery capabilities
2. Continue improving HTML local-container and inline semantic recovery
3. Continue strengthening PDF OCR coverage and the documentation or sample coverage of more complex layout boundaries

### Mid-Term Directions

1. Continue extending cross-format structural capabilities through the unified IR
2. Continue improving support for more complex PDF layouts
3. Continue moving PPTX from stable ordering toward richer structural expression
4. Continue improving consistency in OOXML and lower-level parser infrastructure without sacrificing maintainability

---

## Current Status Summary

* **DOCX**: stable support for headings / lists / tables / images / blockquotes / code-like paragraphs
* **PDF**: `main` still uses an external text-first pipeline, with candidate selection, noise cleanup, cross-page merging, and heading/list recovery
* **XLSX**: stable support for multi-sheet output, sparse trimming, multiple cell types, and style-driven date/time interpretation
* **PPTX**: now has a strong shape/layout-oriented recovery path and is one of the most actively enhanced layout-recovery modules in the project
* **HTML**: now includes a lightweight inline model and local container recovery rather than just flattened text
* **IR + Markdown emitter**: the unified output backbone of the whole project and the foundation for future extensions
