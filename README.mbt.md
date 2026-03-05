# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

> Current goal: ship a minimal end-to-end pipeline (**docx / pdf / xlsx / pptx / html → IR → Markdown**) and validate it with sample-based regression tests.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), then apply lightweight paragraphing
* ✅ **XLSX → Markdown** (MVP): extract sheet text and emit one table per sheet
* ✅ **PPTX → Markdown** (MVP): extract slide text and emit one section per slide
* ✅ **HTML → Markdown** (MVP): extract headings/paragraphs/list items and decode entities
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier

> Note: This project intentionally avoids unstable/untrusted third-party PDF parsing libraries. The PDF MVP uses “external text extraction + internal normalization”.

---

## Repository Layout (current)

* `src/cli/`: CLI entry (`demo` / `convert`)
* `src/core/`: core layer (IR + emitter + dispatcher + utilities)

  * `ir.mbt`: IR definitions (`Document` / `Block`, etc.)
  * `emitter_markdown.mbt`: IR → Markdown
  * `errors.mbt` / `tool.mbt`: shared errors & utilities
  * `zip_min.mbt`: minimal ZIP reader used by Office formats (docx/xlsx/pptx)
* `src/docx/`: docx parsing

  * `docx_zip.mbt`: docx ZIP wrapper (reads `word/document.xml` / rels / media)
  * `rels.mbt`: parses `document.xml.rels` (rId → Target)
  * `docx_xml.mbt`: scans `document.xml` and produces IR (paragraphs/headings/images/tables)
  * `docx_parser.mbt`: the orchestrated `parse_docx()` pipeline
* `src/pdf/`: PDF parsing

  * `pdf_parser.mbt`: PDF text extraction + paragraphing (MVP)
* `src/xlsx/`: XLSX parsing (MVP)

  * `xlsx_parser.mbt`: reads workbook + sheets and emits tables
* `src/pptx/`: PPTX parsing (MVP)

  * `pptx_parser.mbt`: reads slides and emits slide sections
* `src/html/`: HTML parsing (MVP)

  * `html_parser.mbt`: lightweight HTML extraction (bytes-based to avoid UTF-8 indexing issues)
* `samples/`: sample files & regression scripts

  * `docx/` / `pdf/` / `xlsx/` / `pptx/` / `html/`: format-specific samples
  * `expected/<format>/`: golden Markdown outputs
  * `diff.sh`: regression script (writes outputs to `.tmp_test_out/<format>/` and diffs against `samples/expected/<format>/`)

---

## What Works (current)

### ✅ Core

* IR definitions and `push` work as expected
* Markdown emitter supports: headings / paragraphs / tables / image references

### ✅ Minimal Docx Pipeline

* Reads from `.docx`:

  * `word/document.xml`
  * `word/_rels/document.xml.rels`
  * `word/media/*` (images)
* Exports images to `out/assets/` and references them in Markdown like `![image](assets/xxx.png)`

### ✅ ZIP/Deflate Decompression

* ZIP reading is implemented in `zip_min`.
* Deflate decompression is implemented via `mizchi/zlib` (`deflate_decompress`).
* For some Office-produced ZIP entries, deflate fallback may be needed (platform tools) depending on environment.

### ✅ PDF (text-based) MVP

* Extracts text via external tools (tries multiple candidates) and selects the output that best matches reading order using a scoring function:

  * `pdftotext` (Poppler): default / `-layout` / `-raw`
  * fallback: `mutool draw -F txt` (MuPDF)
* Applies lightweight normalization:

  * normalize line endings
  * split paragraphs by blank lines (and merge hard wraps)
  * use `---` as a page separator for multi-page PDFs (MVP)

> Note: `mutool` may print progress info to stderr (e.g., `page ...`). This project separates stdout/stderr to avoid contaminating extracted text.

### ✅ XLSX (MVP)

* Parses workbook + sheet XML and emits one Markdown table per sheet
* Supports numeric cells and inline strings; decodes XML entities (including numeric entities)

### ✅ PPTX (MVP)

* Extracts slide text runs and emits one section per slide
* Decodes XML entities; non-BMP characters are normalized consistently via the shared entity decode path

### ✅ HTML (MVP)

* Bytes-based parsing to avoid UTF-8 indexing issues
* Extracts headings/paragraphs/list items; decodes entities (including numeric entities)

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
  --out-dir out \
  --max-heading 3
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
* `--max-heading N`: maximum heading level (1–6)

---

## Regression Tests (samples)

The script writes conversion outputs to **`.tmp_test_out/`** (grouped by format) and diffs against `samples/expected/<format>/`.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

If you update the implementation and confirm the new output is correct, refresh the golden outputs for the corresponding format.

Example: refresh PDF golden outputs:

```bash
cp .tmp_test_out/pdf/text_simple.md     samples/expected/pdf/text_simple.md
cp .tmp_test_out/pdf/text_hardwrap.md   samples/expected/pdf/text_hardwrap.md
cp .tmp_test_out/pdf/text_multipage.md  samples/expected/pdf/text_multipage.md
```

Example: refresh one XLSX golden file:

```bash
cp .tmp_test_out/xlsx/sheet_simple.md samples/expected/xlsx/sheet_simple.md
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
3. XLSX: support more cell types (sharedStrings-rich text, booleans)

### Mid-term

1. PDF: improve paragraphing and line-wrap rules (more stable reading order / lists)
2. Later: scanned PDFs (OCR + basic layout recovery), likely still via external tools first

---

## Status

* ✅ docx: minimal end-to-end pipeline works
* ✅ pdf (text-based): MVP works (depends on external extractors)
* ✅ xlsx: MVP works
* ✅ pptx: MVP works
* ✅ html: MVP works
* ✅ samples regression script works (output directory: `.tmp_test_out/`)
