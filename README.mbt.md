# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

> Current goal: ship a minimal end-to-end pipeline (**docx / pdf / xlsx / pptx / html → IR → Markdown**) and validate it with sample-based regression tests.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references, and list structure recovery
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), then apply lightweight paragraphing
* ✅ **XLSX → Markdown** (MVP): extract sheet text and emit one table per sheet
* ✅ **PPTX → Markdown** (MVP): extract slide text and emit one section per slide
* ✅ **HTML → Markdown** (MVP): extract headings / paragraphs / list items and decode entities
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier

> Note: This project intentionally avoids unstable/untrusted third-party PDF parsing libraries. The PDF MVP uses “external text extraction + internal normalization”.

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
  * `docx_styles.mbt`: `word/styles.xml` parsing for heading-level resolution
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
  * `pdf_normalize.mbt`: normalization / paragraphing / lightweight structure recovery
  * `pdf_to_ir.mbt`: normalized PDF text → shared IR
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
  * `xlsx_xml.mbt`: XML scanning helpers
  * `moon.pkg`: package definition

Each subpackage also contains generated interface artifacts such as `pkg.generated.mbti`.

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

### ✅ ZIP/Deflate Decompression

* ZIP reading is implemented in `zip_min`
* Deflate decompression is implemented via `mizchi/zlib` (`deflate_decompress`)
* For some Office-produced ZIP entries, deflate fallback may be needed (platform tools) depending on environment

### ✅ PDF (text-based) MVP

* Extracts text via external tools and selects the output that best matches reading order using a scoring function:

  * `pdftotext` (Poppler): default / `-layout` / `-raw`
  * fallback: `mutool draw -F txt` (MuPDF)
* Applies lightweight normalization:

  * normalize line endings
  * split paragraphs by blank lines (and merge hard wraps)
  * recover basic headings under current heuristic rules
  * use `---` as a page separator for multi-page PDFs (MVP)

> Note: `mutool` may print progress info to stderr (for example `page ...`). This project separates stdout/stderr to avoid contaminating extracted text.

### ✅ XLSX (MVP)

* Parses workbook + sheet XML and emits one Markdown table per sheet
* Supports numeric cells and inline strings
* Trims sparse trailing empty rows / columns in current MVP samples
* Decodes XML entities (including numeric entities)

### ✅ PPTX (MVP)

* Extracts slide text runs and emits one section per slide
* Supports simple title / bullet recovery under the current heuristic MVP
* Decodes XML entities; non-BMP characters are normalized consistently via the shared entity decode path

### ✅ HTML (MVP)

* Bytes-based parsing to avoid UTF-8 indexing issues
* Extracts headings / paragraphs / list items
* Supports block quotes and preformatted/code blocks in the current MVP
* Decodes entities (including numeric entities)

---

## External Dependencies (PDF)

The PDF MVP relies on at least one of the following command-line tools installed on your system:

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

Recent DOCX regression coverage includes:

* heading levels
* basic lists
* ordered lists
* nested lists
* mixed lists
* images / tables / general golden sample

If you update the implementation and confirm the new output is correct, refresh the golden outputs for the corresponding format.

Example: refresh DOCX list golden outputs:

```bash
cp .tmp_test_out/docx/docx_list_ordered.md samples/expected/docx/docx_list_ordered.md
cp .tmp_test_out/docx/docx_list_nested.md  samples/expected/docx/docx_list_nested.md
cp .tmp_test_out/docx/docx_list_mixed.md   samples/expected/docx/docx_list_mixed.md
```

Example: refresh PDF golden outputs:

```bash
cp .tmp_test_out/pdf/text_simple.md     samples/expected/pdf/text_simple.md
cp .tmp_test_out/pdf/text_hardwrap.md   samples/expected/pdf/text_hardwrap.md
cp .tmp_test_out/pdf/text_multipage.md  samples/expected/pdf/text_multipage.md
```

Then re-run:

```bash
./samples/diff.sh
```

---

## Roadmap

### Near-term

1. Improve PPTX ordering by `ppt/presentation.xml` + rels (match real slide order)
2. HTML: add minimal table extraction (`<table>` → IR Table)
3. XLSX: support more cell types (for example booleans / richer shared strings)
4. Continue tightening DOCX list fidelity (future emitter / parser refinements if needed)

### Mid-term

1. PDF: improve paragraphing and line-wrap rules (more stable reading order / lists)
2. Expand DOCX style-driven block recovery beyond headings (for example quote / code-like paragraph styles)
3. Later: scanned PDFs (OCR + basic layout recovery), likely still via external tools first

---

## Status

* ✅ docx: upgraded minimal pipeline works, including style-driven headings and numbering-driven lists
* ✅ pdf (text-based): MVP works (depends on external extractors)
* ✅ xlsx: MVP works
* ✅ pptx: MVP works
* ✅ html: MVP works
* ✅ IR + Markdown emitter support structured lists better than the initial MVP
* ✅ samples regression script works (output directory: `.tmp_test_out/`)
