# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

> Current status: the project has moved well beyond the initial MVP stage and now provides a stable multi-format **document → IR → Markdown** pipeline with sample-based regression coverage across **docx / pdf / xlsx / pptx / html**. A major recent milestone is the completion of a first substantial **OOXML infrastructure refactor**: the project now owns its ZIP container and OOXML package layer directly, and **DOCX / XLSX / PPTX have all been migrated** onto the new shared foundation.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references, style/numbering-driven list structure recovery, paragraph line-break preservation, and code-like paragraph recovery under the current heuristic rules
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), select the best candidate output heuristically, then apply page-noise cleanup, repeated header/footer removal, heading/paragraph boundary recovery, cross-page paragraph merging, and basic list-item recovery
* ✅ **PDF (scanned, experimental OCR fallback)**: when the PDF has no usable text layer, the pipeline can attempt OCR-based fallback through external tools (`OCRmyPDF` + `Tesseract`) under `--pdf-mode experimental`; this path is currently functional but still lower-confidence than the text-PDF path and accuracy depends strongly on scan quality / document noise
* ✅ **XLSX → Markdown**: extract workbook sheets as Markdown tables, with multi-sheet output, sparse-table trimming, minimal non-empty bounding-box cropping, empty-sheet handling, basic cell-type support, and lightweight date/time formatting for style-marked numeric cells
* ✅ **PPTX → Markdown**: extract slide text by shape, preserve real slide order via `presentation.xml`, recover title/body structure, restore bullet lists with nesting levels, restore ordered lists from numbering-aware bullet properties, merge multi-paragraph title shapes, clean up empty / duplicate paragraph noise, apply shape-layout reading-order recovery, keep note-like / caption-like text regions more stable in output order, and stabilize local table-like / grid-like text regions before Markdown emission
* ✅ **HTML → Markdown**: extract headings / paragraphs / list items / block quotes / code blocks / tables, preserve common `<br>` variants, preserve ordered / unordered / nested list structure, avoid swallowing nested list text in parent items, add lightweight inline modeling for HTML text spans and explicit break semantics, and recover multi-block structure inside block quotes and list items
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier
* ✅ **Shared OOXML foundation**: the Office-family path now runs through a shared in-project chain of **`bytes -> ZipArchive -> OoxmlPackage -> format parser`**

> Note: this project intentionally avoids unstable or opaque parsing dependencies where practical, keeps format handling in small MoonBit packages with explicit heuristics, and uses external system tools when that is the most reliable current engineering trade-off.

---

## Project Status

The project is no longer just a minimal proof of concept.

Current state:

* ✅ **Unified multi-format pipeline**: **docx / pdf / xlsx / pptx / html → IR → Markdown** is implemented and regression-tested
* ✅ **Sample-based regression suite** is in place and used as the primary behavior guardrail
* ✅ **OOXML infrastructure refactor (phase-1)** is complete at the shared foundation level
* ✅ **Self-managed ZIP container phase-1** is complete
* ✅ **Self-managed OOXML package phase-1** is complete
* ✅ **DOCX / XLSX / PPTX have all been migrated** to the new shared OOXML foundation
* ✅ **Old zipmin / external-path helper dependencies have been removed** from the Office-family path
* ✅ **DOCX** is at high completeness for the current project scope and now runs on the new OOXML layer
* ✅ **XLSX** is at high completeness for the current project scope and now runs on the new OOXML layer
* ✅ **PPTX** is at high completeness and still under active heuristic enhancement, now also running on the new OOXML layer
* ✅ **HTML** is at relatively high completeness for the current project scope
* ⚠️ **PDF** remains the largest current technical-debt area because text extraction still depends on external tools
* ⚠️ **Experimental scanned-PDF support** exists through external OCR tools, but quality remains best-effort and below the text-PDF path

A major architecture change in the current stage is that the OOXML path is now much cleaner and more internally controlled:

* previous Office-family helper logic that depended on older `zipmin` / external-path flows has been removed
* ZIP container logic is now managed directly inside the project
* OOXML package logic is now managed directly inside the project
* Office-family parsers now share the same lower-level package chain instead of format-by-format ad hoc access paths

---

## OOXML Foundation (current)

The shared Office-family stack now looks like this:

```text
bytes -> ZipArchive -> OoxmlPackage -> format parser
```

This is now the common base for:

* `docx`
* `xlsx`
* `pptx`

### ZIP container phase-1

Current ZIP container support includes:

* EOCD discovery
* central directory parsing
* entry indexing
* local header validation
* reading entry bytes by path

Current ZIP method support:

* `Store`
* `DeflateRaw`

### OOXML package phase-1

Current OOXML package support includes:

* part existence check
* part bytes reading
* `[Content_Types].xml` lookup
* package relationships reading
* part relationships reading
* relationship target resolution

> Note: this layer is intentionally project-driven. It is designed to support the current document-conversion pipeline well, rather than to act as a fully general OOXML SDK.

---

## Repository Layout (current)

The source tree is organized into small MoonBit packages, with conversion logic split by format and shared infrastructure kept in `core` and OOXML support packages.

* `src/cli/`: command-line entry package

  * `cli_app.mbt`: top-level CLI app flow
  * `cli_args.mbt`: argument parsing / option decoding
  * `main.mbt`: executable entry
  * `moon.pkg`: package definition
* `src/convert/`: conversion dispatch package

  * `dispatcher.mbt`: routes input files to the correct parser by format / extension
  * `moon.pkg`: package definition
* `src/core/`: shared core infrastructure

  * `ir.mbt`: shared IR definitions (`Document` / `Block`)
  * `emitter_markdown.mbt`: IR → Markdown emission
  * `errors.mbt`: shared error definitions
  * `tool.mbt`: shared utilities
  * `moon.pkg`: package definition
* `src/ooxml/`: shared OOXML infrastructure

  * ZIP container handling
  * OOXML package handling
  * shared relationship / package resolution helpers
* `src/docx/`: DOCX parsing package

  * DOCX parser / document assembly
  * styles / numbering / tables / relationships / XML helpers
  * built on the shared OOXML foundation
* `src/html/`: HTML parsing package

  * HTML parser / bytes traversal / local DOM-like recovery / HTML → IR
* `src/pdf/`: PDF parsing package

  * external-tool extraction orchestration
  * extractor scoring
  * page cleanup / noise removal / heading/list/block recovery / PDF → IR
* `src/pptx/`: PPTX parsing package

  * PPTX parser / relationships / shape collection / layout recovery / grouping / reading order / paragraph metadata
  * built on the shared OOXML foundation
* `src/xlsx/`: XLSX parsing package

  * XLSX parser / shared strings / sheet extraction / styles / datetime helpers / XML helpers
  * built on the shared OOXML foundation
* `samples/`: sample files & regression scripts

  * `docx/` / `pdf/` / `xlsx/` / `pptx/` / `html/`: format-specific samples
  * `expected/<format>/`: golden Markdown outputs
  * `diff.sh`: regression script (writes outputs to `.tmp_test_out/<format>/` and diffs against `samples/expected/<format>/`)

---

## What Works (current)

### ✅ Core

* IR definitions and push flow work as expected
* Markdown emitter supports:

  * headings
  * paragraphs
  * ordered / unordered list items
  * nested list indentation
  * block quotes
  * code blocks
  * tables
  * image references
* Markdown output tail is normalized consistently across formats (non-empty output ends with a single trailing newline)

### ✅ Shared ZIP / OOXML package handling

The project now owns the Office-family package foundation directly.

Current shared behavior includes:

* ZIP archive opening from bytes
* central directory indexing and entry lookup
* path-based entry reading
* OOXML part lookup through package paths
* package-level relationship loading
* part-level relationship loading
* relationship-target resolution for Office-family parsing

Current architectural status:

* **DOCX / XLSX / PPTX all use the shared OOXML path**
* older helper logic depending on previous `zipmin` / external-path behavior has been removed
* the dependency graph for Office-family parsing is now cleaner and more self-contained

### ✅ Docx Pipeline

* Reads from `.docx` package parts such as:

  * document XML
  * relationships
  * styles
  * numbering
  * media assets
* Exports images to `out/assets/` and references them in Markdown like `![image](assets/xxx.png)`
* Resolves heading levels through style mapping instead of only hard-coded style names
* Recovers list structure using numbering metadata:

  * unordered lists
  * ordered lists
  * nested lists
  * mixed list structures
* Preserves paragraph-level manual line breaks into Markdown-friendly output
* Preserves table-cell internal manual line breaks into Markdown-friendly `<br>` output
* Recovers code-like paragraphs under the current conservative rules
* Now runs entirely on the shared OOXML foundation

> Note: DOCX blockquote recovery is wired into the parsing pipeline. Current list / heading / table / code-like paragraph coverage is backed by regression samples; blockquote-style recovery is not yet backed by a true source-document sample.

### ✅ PDF (text-based)

* Extracts text via external tools and selects the output that best matches reading order / text integrity using a scoring function:

  * `pdftotext` (Poppler): default / `-layout` / `-raw`
  * fallback: `mutool draw -F txt` (MuPDF)
* Applies lightweight normalization and structure recovery:

  * normalize line endings
  * split pages by form-feed and keep page boundaries internal to normalization
  * split paragraphs by blank lines and merge hard wraps
  * recover basic headings under current heuristic rules
  * reduce short-line false positives in heading detection
  * avoid merging obvious new blocks into the previous paragraph
  * recover basic bullet-list items into shared IR list blocks
  * filter page-number noise and repeated page-header/page-footer noise under the current sample set
  * merge cross-page paragraph continuations when the next page starts with continuation text rather than a new block

> Note: PDF remains one of the main technical-debt areas because text extraction still depends on external tools and difficult layouts still require heuristics.

### ⚠️ PDF (scanned, experimental OCR fallback)

* When the PDF text layer is empty, the pipeline can attempt an OCR-based fallback under `--pdf-mode experimental`
* The current scanned-PDF path is designed as a pragmatic external-tool integration rather than an in-project OCR engine
* Intended toolchain:

  * `OCRmyPDF`
  * `Tesseract`
* Current scope expectation:

  * useful as an experimental fallback path
  * not yet treated as a high-accuracy or regression-hardened primary PDF mode

### ✅ XLSX

* Parses workbook + sheet XML and emits one Markdown table per sheet
* Supports shared strings, inline strings, numeric/default cells, booleans, string results, and error cells
* Supports multi-sheet output
* Emits `(empty sheet)` for empty worksheets
* Trims sparse trailing empty rows / columns in current regression samples
* Crops sparse sheets to the minimal non-empty bounding box before Markdown emission
* Interprets style-marked numeric date/time-like cells through workbook styles
* Now runs entirely on the shared OOXML foundation

### ✅ PPTX

* Extracts slide text by shape and emits one section per slide
* Resolves real slide order through presentation relationships instead of only relying on slide file name order
* Prefers title placeholders for slide headings, with conservative fallback when needed
* Uses paragraph bullet properties before text-prefix heuristics for list detection
* Restores unordered and ordered list semantics from bullet properties / numbering-aware bullet metadata
* Restores list nesting from paragraph level metadata
* Merges multi-paragraph title-shape text into one heading under the current heuristic rules
* Removes empty paragraphs, bullet-only shells, and adjacent duplicate text
* Recovers shape-level reading order using layout heuristics
* Applies conservative PPTX-specific noise filtering
* Groups local note-like / caption-like small text shapes to keep them from being fragmented by the main body flow
* Detects simple table-like / grid-like text regions and keeps them stable as one body region during output ordering
* Now runs entirely on the shared OOXML foundation

> Note: PPTX support is already at high completeness for the current scope, but complex slide layouts still depend on heuristics rather than exact semantic recovery.

### ✅ HTML

* Bytes-based parsing to avoid UTF-8 indexing issues
* Extracts headings / paragraphs / list items
* Supports block quotes and preformatted/code blocks
* Supports basic HTML table extraction (`<table>` → IR `Table` → Markdown table)
* Preserves common `<br>` variants as explicit inline break semantics in the HTML-local model and renders them back to stable Markdown/HTML output
* Preserves ordered / unordered / nested list structure under current regression coverage
* Prevents parent `<li>` text from swallowing nested list text in current regression cases
* Uses a lightweight HTML-local inline model so text spans and explicit breaks are no longer carried only as flat strings
* Recovers block-quote containers as local child-block structures instead of flattening them immediately into one text blob
* Recovers list-item containers as local child-block structures so multi-paragraph items, mixed text, and nested lists are handled more conservatively
* Normalizes ragged table rows
* Decodes entities (including numeric entities)

---

## External Dependencies

### PDF (text-based)

The PDF pipeline relies on at least one of the following command-line tools installed on your system:

* `pdftotext` (Poppler)
* `mutool` (MuPDF toolset)

If neither is available, the program will show a unified error message.

Install examples:

* macOS (Homebrew): `brew install poppler mupdf`
* Ubuntu/Debian: `sudo apt-get install poppler-utils mupdf-tools`
* Arch: `sudo pacman -S poppler mupdf-tools`

### PDF (scanned / OCR fallback, experimental)

If you want to use OCR fallback for scanned PDFs, install:

* `ocrmypdf`
* `tesseract`

Optional but commonly needed for non-English scans:

* extra Tesseract language data (for example Chinese language packs)

Install examples on macOS (Homebrew):

```bash
brew install ocrmypdf
brew install tesseract
# optional, depending on your environment / language needs
brew install tesseract-lang
```

> Note: the scanned-PDF path is only intended for `--pdf-mode experimental` right now. If these OCR dependencies are missing and the PDF has no usable text layer, conversion will fail with an OCR-fallback-related error.

---

## Usage

### 1) `demo`: sanity-check the core pipeline

```bash
moon run src/cli -- demo
```

Prints a demo Markdown document (no input required).

### 2) `convert`: convert documents → Markdown

Docx example:

```bash
moon run --target native src/cli -- \
  convert samples/docx/golden.docx \
  -o out/golden.md \
  --out-dir out
```

PDF example:

```bash
moon run --target native src/cli -- \
  convert samples/pdf/text_simple.pdf \
  -o out/text_simple.md \
  --out-dir out
```

PDF scanned / OCR example (experimental):

```bash
moon run --target native src/cli -- \
  convert samples/pdf/82092117.pdf \
  -o out/82092117.md \
  --out-dir out \
  --pdf-mode experimental
```

XLSX example:

```bash
moon run --target native src/cli -- \
  convert samples/xlsx/sheet_simple.xlsx \
  -o out/sheet_simple.md \
  --out-dir out
```

PPTX example:

```bash
moon run --target native src/cli -- \
  convert samples/pptx/pptx_simple.pptx \
  -o out/pptx_simple.md \
  --out-dir out
```

HTML example:

```bash
moon run --target native src/cli -- \
  convert samples/html/html_simple.html \
  -o out/html_simple.md \
  --out-dir out
```

Options:

* `-o out/xxx.md`: output Markdown path (default: stdout)
* `--out-dir out`: asset output directory (docx images go to `out/assets/`)
* `--max-heading N`: maximum heading level (`1–6`)
* `--pdf-mode experimental`: enable experimental PDF handling paths, including scanned-PDF OCR fallback when available
* `--pdf-extract-debug [1|true|on|yes]`: print concise PDF extractor scoring/selection logs (default: off)

---

## Regression Tests (samples)

The script writes conversion outputs to **`.tmp_test_out/`** (grouped by format) and diffs against `samples/expected/<format>/`.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

Current regression coverage includes:

* **DOCX**

  * heading levels
  * basic lists
  * ordered lists
  * nested lists
  * mixed lists
  * paragraph manual line breaks
  * table-cell manual line breaks
  * code-like paragraph positive / negative cases
  * images / tables / general golden sample
* **PDF**

  * simple text
  * hard-wrap recovery (English / Chinese)
  * heading recovery
  * short-sentence non-heading cases
  * multi-page text
  * repeated header/footer cleanup
  * page-noise cleanup
  * cross-page paragraph merging
  * heading-vs-short-sentence boundary recovery
  * repeated header/footer variants
  * initial manual validation for one scanned/fax-style OCR fallback sample in experimental mode
* **PPTX**

  * basic slides
  * title + bullets
  * presentation-order slide sequence sample
  * shape-aware title/body handling
  * bullet-property list detection
  * ordered-list recovery from numbering-aware bullet properties
  * bullet levels / cleanup behavior
  * multi-paragraph title-shape merge behavior
  * top-title + multi-box layout behavior
  * note-like grouping behavior
  * table-like/grid-like text-region stabilization
  * local table-like region behavior with surrounding body text
  * stronger positive and negative layout samples for table-like boundary control
* **HTML**

  * simple content
  * mixed block content
  * block quotes
  * block-quote multi-paragraph / nested / mixed-text container cases
  * pre/code blocks
  * basic tables
  * `<br>` variants
  * ordered lists
  * nested lists
  * mixed nested ordered/unordered lists
  * list-item multi-paragraph / mixed-text / nested-list / quote-in-item cases
  * ragged table rows
* **XLSX**

  * simple sheet
  * sparse trimming
  * cell types
  * multi-sheet mixed workbook
  * empty sheet behavior
  * sparse-edge / bounding-box trimming
  * custom-format date / time / datetime cells
  * built-in date/time-like style handling under current sample coverage

If you update the implementation and confirm the new output is correct, refresh the golden outputs for the corresponding format and re-run the regression script.

---

## Progress Dashboard (snapshot: 2026-04-10)

### Coverage completion interpretation (current)

* **DOCX**: high completion and now fully migrated onto the new shared OOXML foundation.
* **PDF (text-based)**: robust text-PDF path with extractor arbitration + noise cleanup + block recovery, but still externally dependent.
* **PDF (scanned / OCR fallback)**: experimentally validated fallback exists and can run, but current OCR quality is still moderate and should be treated as best-effort.
* **XLSX**: high completion and now fully migrated onto the new shared OOXML foundation.
* **PPTX**: high completion and still the most actively refined layout-heuristic area; now fully migrated onto the new shared OOXML foundation.
* **HTML**: high completion with local container + inline modeling.
* **OOXML foundation**: a major phase-1 milestone is complete; ZIP container and package handling are now internally controlled and shared by Office-family parsers.

---

## Roadmap

### Near-term

1. Continue strengthening the **experimental scanned-PDF OCR path**, especially around evaluation discipline, sample accumulation, and output-quality characterization
2. Continue widening PDF validation coverage for difficult layouts, since PDF remains the most important technical-debt area
3. Continue refining PPTX structure recovery around difficult layouts without regressing the now-stable OOXML migration
4. Extend DOCX style-driven block recovery with true source-document validation for quote-like styles
5. Extend XLSX validation coverage with more real-world workbook samples

### Mid-term

1. Unify more structure-aware behavior across formats through the shared IR
2. Improve PDF handling for more difficult layouts
3. Extend the ZIP / OOXML foundation beyond current phase-1 scope where project needs justify it
4. Potentially strengthen the OOXML package layer further, while keeping it project-oriented rather than trying to become a general-purpose OOXML SDK

---

## Limitations

This project is already stable for its current scope, but several limits remain explicit and important:

* **PDF still depends on external extraction tools**
* **Complex PDF and PPTX structure recovery still depends on heuristics**
* **ZIP container phase-1 currently targets ordinary OOXML samples**, and does **not** yet fully cover:

  * ZIP64
  * encrypted ZIP
  * multi-disk ZIP
  * full data-descriptor support
* **The OOXML package layer is project-oriented**, not a fully general or complete OOXML SDK
* **Experimental scanned-PDF OCR fallback** remains best-effort and is still clearly weaker than the text-PDF pipeline

---

## Status

* ✅ **docx**: stable structured conversion with style-driven headings, numbering-driven lists, paragraph/table-cell line-break preservation, image export, conservative code-like paragraph recovery, and full migration onto the shared OOXML foundation
* ⚠️ **pdf (text-based)**: stable extractor-selection pipeline with heading/paragraph cleanup, list-item recovery, repeated header/footer removal, page-noise filtering, cross-page paragraph merging, and heuristic block-boundary recovery, but still externally dependent
* ⚠️ **pdf (scanned / OCR fallback, experimental)**: functional fallback path for no-text-layer PDFs through external OCR tools, manually validated on a real scanned sample, but current recognition quality is still moderate and not yet at the same stability level as text-based PDFs
* ✅ **xlsx**: stable table-oriented workbook conversion with multiple cell types, multi-sheet support, empty-sheet handling, sparse bounding-box trimming, lightweight style-driven date/time interpretation, and full migration onto the shared OOXML foundation
* ✅ **pptx**: stable shape-oriented conversion with real presentation-order traversal, title/body handling, ordered/unordered list recovery, nested list levels, multi-paragraph title merge, paragraph cleanup, layout-based reading-order recovery, conservative noise filtering, note-like grouping, table-like text-region stabilization, and full migration onto the shared OOXML foundation
* ✅ **html**: stable bytes-based HTML conversion with lists / quotes / code blocks / tables, explicit `<br>` break preservation, lightweight inline modeling, local blockquote/list-item container recovery, ordered/nested-list structure recovery, parent-item protection, and ragged-row table normalization
* ✅ **IR + Markdown emitter**: shared structured output path across formats
* ✅ **shared ZIP / OOXML foundation**: self-managed ZIP container phase-1 and OOXML package phase-1 are complete, with DOCX / XLSX / PPTX already unified on top of them
