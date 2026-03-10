# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

> Current goal: ship a minimal end-to-end pipeline (**docx / pdf / xlsx / pptx / html → IR → Markdown**) and validate it with sample-based regression tests.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references, style/numbering-driven list structure recovery, paragraph line-break preservation, and code-like paragraph recovery under the current heuristic rules
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), select the best candidate output heuristically, then apply page-noise cleanup, repeated header/footer removal, heading/paragraph boundary recovery, cross-page paragraph merging, and basic list-item recovery
* ✅ **XLSX → Markdown**: extract workbook sheets as Markdown tables, with multi-sheet output, sparse-table trimming, minimal non-empty bounding-box cropping, empty-sheet handling, basic cell-type support, and lightweight date/time formatting for style-marked numeric cells
* ✅ **PPTX → Markdown**: extract slide text by shape, preserve real slide order via `presentation.xml`, recover title/body structure, restore bullet lists with nesting levels, restore ordered lists from numbering-aware bullet properties, merge multi-paragraph title shapes, and clean up empty / duplicate paragraph noise
* ✅ **HTML → Markdown**: extract headings / paragraphs / list items / block quotes / code blocks / tables, normalize common `<br>` variants, preserve ordered / unordered / nested list structure, avoid swallowing nested list text in parent items, and decode entities
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier

> Note: This project intentionally avoids unstable or untrusted third-party parsing libraries where possible, and keeps format handling in small MoonBit packages with explicit heuristics.

---

## Repository Layout (current)

The source tree is organized into small MoonBit packages, with conversion logic split by format and shared infrastructure kept in `core`.

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
  * `zip_min.mbt`: minimal ZIP reader used by Office-family formats
  * `moon.pkg`: package definition
* `src/docx/`: DOCX parsing package

  * `docx_package.mbt`: DOCX package/ZIP access helpers
  * `docx_parser.mbt`: orchestrated `parse_docx()` entry
  * `docx_document.mbt`: document-level scan / assembly into IR
  * `docx_xml.mbt`: lower-level XML scanning helpers
  * `docx_table.mbt`: table extraction logic
  * `docx_rels.mbt`: relationship parsing (`rId → Target`)
  * `docx_styles.mbt`: `word/styles.xml` parsing for heading-level resolution and paragraph-style name lookup
  * `docx_numbering.mbt`: `word/numbering.xml` parsing for ordered / unordered / nested lists
  * `moon.pkg`: package definition
* `src/html/`: HTML parsing package

  * `html_parser.mbt`: top-level HTML parse entry
  * `html_bytes.mbt`: byte-level HTML traversal helpers
  * `html_dom.mbt`: lightweight DOM-style intermediate structure
  * `html_to_ir.mbt`: HTML structure → shared IR
  * `moon.pkg`: package definition
* `src/pdf/`: PDF parsing package

  * `pdf_parser.mbt`: top-level PDF parse entry
  * `pdf_extract.mbt`: external-tool text extraction orchestration
  * `pdf_extract_score.mbt`: extractor candidate scoring and best-output selection
  * `pdf_page.mbt`: page splitting / page-break marker / cleaned-page merging helpers
  * `pdf_noise.mbt`: page-number detection, repeated header/footer detection, and page-noise stripping
  * `pdf_block.mbt`: block splitting and block-level recovery flow
  * `pdf_heading.mbt`: heading heuristics and heading-level inference
  * `pdf_list.mbt`: PDF list-item detection and list-item parsing helpers
  * `pdf_text.mbt`: shared PDF text utilities and normalization helpers
  * `pdf_to_ir.mbt`: PDF pipeline orchestration and shared IR mapping
  * `moon.pkg`: package definition
* `src/pptx/`: PPTX parsing package

  * `pptx_parser.mbt`: top-level PPTX parse entry
  * `pptx_package.mbt`: PPTX package/ZIP access helpers
  * `pptx_bytes.mbt`: byte / XML scanning helpers
  * `pptx_slide.mbt`: slide-level extraction
  * `pptx_text.mbt`: text-run extraction helpers
  * `moon.pkg`: package definition
* `src/xlsx/`: XLSX parsing package

  * `xlsx_parser.mbt`: top-level XLSX parse entry
  * `xlsx_package.mbt`: XLSX package/ZIP access helpers
  * `xlsx_shared_strings.mbt`: shared strings parsing
  * `xlsx_sheet.mbt`: sheet-level extraction
  * `xlsx_styles.mbt`: `xl/styles.xml` parsing for `numFmtId` / `formatCode`-driven lightweight date/time interpretation
  * `xlsx_xml.mbt`: XML scanning helpers
  * `moon.pkg`: package definition
* `samples/`: sample files & regression scripts

  * `docx/` / `pdf/` / `xlsx/` / `pptx/` / `html/`: format-specific samples
  * `expected/<format>/`: golden Markdown outputs
  * `diff.sh`: regression script (writes outputs to `.tmp_test_out/<format>/` and diffs against `samples/expected/<format>/`)

---

## What Works (current)

### ✅ Core

* IR definitions and `push` work as expected
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

### ✅ Docx Pipeline

* Reads from `.docx`:

  * `word/document.xml`
  * `word/_rels/document.xml.rels`
  * `word/styles.xml`
  * `word/numbering.xml`
  * `word/media/*` (images)
* Exports images to `out/assets/` and references them in Markdown like `![image](assets/xxx.png)`
* Resolves heading levels through style mapping instead of only hard-coded style names
* Recovers list structure using numbering metadata:

  * unordered lists
  * ordered lists
  * nested lists
  * mixed list structures (current Markdown emission preserves level + ordered/unordered shape)
* Preserves paragraph-level manual line breaks into Markdown-friendly output
* Preserves table-cell internal manual line breaks into Markdown-friendly `<br>` output
* Recovers code-like paragraphs under the current conservative rules:

  * paragraph-style name match when available
  * fallback: multi-line text plus explicit code-like token patterns
* Keeps a style-driven blockquote recovery entry point in the parser

> Note: DOCX blockquote recovery is wired into the parsing pipeline, but **real DOCX blockquote-style samples have not been validated yet**. Current list / heading / table / code-like paragraph coverage is backed by regression samples; blockquote-style recovery is not yet backed by a true source-document sample.

### ✅ ZIP/Deflate Decompression

* ZIP reading is implemented in `zip_min`
* Deflate decompression is implemented via `mizchi/zlib` (`deflate_decompress`)
* For some Office-produced ZIP entries, deflate fallback may be needed (platform tools) depending on environment

### ✅ PDF (text-based) MVP+

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
* Current regression coverage includes:

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

> Note: `mutool` may print progress info to stderr (for example `page ...`). This project separates stdout/stderr to avoid contaminating extracted text.

### ✅ XLSX

* Parses workbook + sheet XML and emits one Markdown table per sheet
* Supports shared strings, inline strings, numeric/default cells, booleans (`t="b"`), string results (`t="str"`), and error cells (`t="e"`)
* Supports multi-sheet output
* Emits `(empty sheet)` for empty worksheets
* Trims sparse trailing empty rows / columns in current regression samples
* Crops sparse sheets to the minimal non-empty bounding box before Markdown emission
* Decodes XML entities (including numeric entities)
* Interprets style-marked numeric date/time-like cells through `xl/styles.xml`:

  * built-in date/time-like `numFmtId` handling
  * custom `formatCode`-driven lightweight date/time-like detection
  * stable output formatting for date / time / datetime cells under the current regression samples

> Note: XLSX date/time support is currently validated against **custom `formatCode`-based samples**. Built-in Excel `numFmtId` cases such as **14 / 20 / 22** are implemented in the lightweight formatter, but **have not yet been validated with real workbook samples**.

### ✅ PPTX

* Extracts slide text by shape (`<p:sp>`) and emits one section per slide
* Resolves real slide order through `ppt/presentation.xml` + `presentation.xml.rels`, instead of relying only on slide file name order
* Prefers title placeholders for slide headings, with text heuristic fallback when needed
* Uses paragraph bullet properties before text-prefix heuristics for list detection
* Restores unordered and ordered list semantics from bullet properties / numbering-aware bullet metadata
* Restores list nesting from `<a:pPr lvl="N">`
* Merges multi-paragraph title-shape text into one heading under the current heuristic rules
* Removes empty paragraphs, bullet-only shells, and adjacent duplicate text
* Decodes XML entities; non-BMP characters are normalized consistently via the shared entity decode path

### ✅ HTML

* Bytes-based parsing to avoid UTF-8 indexing issues
* Extracts headings / paragraphs / list items
* Supports block quotes and preformatted/code blocks
* Supports basic HTML table extraction (`<table>` → IR `Table` → Markdown table)
* Normalizes common `<br>` variants before text extraction
* Preserves ordered / unordered / nested list structure under current regression coverage
* Prevents parent `<li>` text from swallowing nested list text in current regression cases
* Normalizes ragged table rows to stable Markdown table widths
* Decodes entities (including numeric entities)

---

## External Dependencies (PDF)

The PDF pipeline relies on at least one of the following command-line tools installed on your system:

* `pdftotext` (Poppler)
* `mutool` (MuPDF toolset)

If neither is available, the program will show a unified error message.

Install examples:

* macOS (Homebrew): `brew install poppler mupdf`
* Ubuntu/Debian: `sudo apt-get install poppler-utils mupdf-tools`
* Arch: `sudo pacman -S poppler mupdf-tools`

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

---

## Regression Tests (samples)

The script writes conversion outputs to **`.tmp_test_out/`** (grouped by format) and diffs against `samples/expected/<format>/`.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

Recent regression coverage includes:

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
* **PPTX**

  * basic slides
  * title + bullets
  * presentation-order slide sequence sample
  * shape-aware title/body handling
  * bullet-property list detection
  * ordered-list recovery from numbering-aware bullet properties
  * bullet levels / cleanup behavior
  * multi-paragraph title-shape merge behavior
* **HTML**

  * simple content
  * mixed block content
  * block quotes
  * pre/code blocks
  * basic tables
  * `<br>` variants
  * ordered lists
  * nested lists
  * mixed nested ordered/unordered lists
  * ragged table rows
* **XLSX**

  * simple sheet
  * sparse trimming
  * cell types
  * multi-sheet mixed workbook
  * empty sheet behavior
  * sparse-edge / bounding-box trimming
  * custom-format date / time / datetime cells

If you update the implementation and confirm the new output is correct, refresh the golden outputs for the corresponding format.

Example: refresh DOCX list golden outputs:

```bash
cp .tmp_test_out/docx/docx_list_ordered.md samples/expected/docx/docx_list_ordered.md
cp .tmp_test_out/docx/docx_list_nested.md  samples/expected/docx/docx_list_nested.md
cp .tmp_test_out/docx/docx_list_mixed.md   samples/expected/docx/docx_list_mixed.md
```

Example: refresh one HTML / XLSX / PPTX / PDF golden file:

```bash
cp .tmp_test_out/html/html_table_basic.md              samples/expected/html/html_table_basic.md
cp .tmp_test_out/xlsx/xlsx_multi_sheet_mixed.md        samples/expected/xlsx/xlsx_multi_sheet_mixed.md
cp .tmp_test_out/pptx/pptx_slide_order.md              samples/expected/pptx/pptx_slide_order.md
cp .tmp_test_out/pdf/pdf_page_noise_cleanup.md         samples/expected/pdf/pdf_page_noise_cleanup.md
```

Then re-run:

```bash
./samples/diff.sh
```

---

## Roadmap

### Near-term

1. Unify output spacing / blank-line style across formats after the current parser work stabilizes
2. Continue improving PPTX fallback behavior for non-standard title/body layouts
3. Expand HTML structure robustness around mixed block content and `<br>` semantics
4. Extend XLSX validation coverage for built-in date/time `numFmtId` cases
5. Extend DOCX style-driven block recovery beyond headings/lists with true source-document validation for quote-like styles

### Mid-term

1. Unify more structure-aware behavior across formats through the shared IR
2. Improve PDF handling for more difficult layouts
3. Later: scanned PDFs (OCR + basic layout recovery), likely still via external tools first

---

## Status

* ✅ docx: upgraded minimal pipeline works, including style-driven headings, numbering-driven lists, paragraph/table-cell line-break preservation, and conservative code-like paragraph recovery
* ✅ pdf (text-based): MVP+ works with extractor selection, heading/paragraph cleanup, list-item recovery, repeated header/footer removal, page-noise filtering, cross-page paragraph merging, and heuristic block-boundary recovery
* ✅ xlsx: MVP+ works for common table-oriented workbooks, including multiple cell types, multi-sheet samples, empty-sheet handling, sparse bounding-box trimming, and lightweight style-driven date/time interpretation
* ✅ pptx: MVP+ works with real presentation-order traversal, shape-aware title recovery, ordered/unordered list recovery, nested list levels, multi-paragraph title merge, and paragraph cleanup
* ✅ html: MVP+ works with lists / quotes / code blocks / tables, plus `<br>` normalization, ordered/nested-list structure recovery, parent-item protection, and ragged-row table normalization
* ✅ IR + Markdown emitter support structured lists and shared block-level output across formats
