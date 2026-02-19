# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf** into structured **Markdown**.

> Current goal: ship a minimal end-to-end pipeline (**docx / pdf → IR → Markdown**) and validate it with sample-based regression tests.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), then apply lightweight paragraphing
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier

> Note: This project intentionally avoids unstable/untrusted third-party PDF parsing libraries. The PDF MVP uses “external text extraction + internal normalization”.

---

## Repository Layout (current)

* `src/cli/`: CLI entry (`demo` / `convert`)
* `src/core/`: core layer (IR + emitter + dispatcher + utilities)

  * `ir.mbt`: IR definitions (`Document` / `Block`, etc.)
  * `emitter_markdown.mbt`: IR → Markdown
  * `errors.mbt` / `tool.mbt`: shared errors & utilities
* `src/docx/`: docx parsing

  * `zip_min.mbt`: a **pure MoonBit** minimal ZIP reader (for reading docx internal entries)
  * `docx_zip.mbt`: docx ZIP wrapper (reads `word/document.xml` / rels / media)
  * `rels.mbt`: parses `document.xml.rels` (rId → Target)
  * `docx_xml.mbt`: scans `document.xml` and produces IR (paragraphs/headings/images/tables)
  * `docx_parser.mbt`: the orchestrated `parse_docx()` pipeline
* `src/pdf/`: PDF parsing

  * `dispatcher.mbt`: dispatches by extension to docx/pdf parsers
  * `pdf_parser.mbt`: PDF text extraction + paragraphing (MVP)
* `samples/`: sample files & regression scripts

  * `pdf/`: PDF samples (e.g., `text_simple.pdf`)
  * `expected/`: golden Markdown outputs
  * `diff.sh`: regression script (writes outputs to `.tmp_pdf_out/` and diffs against `samples/expected/`)

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

* Deflate decompression in `zip_min` is implemented via `mizchi/zlib` (`deflate_decompress`) and verified with real docx files.

### ✅ PDF (text-based) MVP

* Extracts text via external tools (tries multiple candidates) and selects the output that best matches reading order using a scoring function:

  * `pdftotext` (Poppler): default / `-layout` / `-raw`
  * fallback: `mutool draw -F txt` (MuPDF)
* Applies lightweight normalization:

  * normalize line endings
  * split paragraphs by blank lines (and merge hard wraps)
  * use `---` as a page separator for multi-page PDFs (MVP)

> Note: `mutool` may print progress info to stderr (e.g., `page ...`). This project separates stdout/stderr to avoid contaminating extracted text.

---

## External Dependencies (PDF)

The PDF MVP relies on at least one of the following command-line tools installed on your system:

* `pdftotext` (Poppler)
* `mutool` (MuPDF toolset)

If neither is available, the program will show a unified error message:

> “pdftotext (Poppler) or mutool (MuPDF) not found. Please install and try again ...”

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

Prints a demo Markdown document (no docx/pdf input required).

### 2) `convert`: convert docx/pdf → Markdown

```bash
moon run --target native src/cli -- \
  convert samples/golden.docx \
  -o out/golden.md \
  --out-dir out \
  --max-heading 3
```

Options:

* `-o out/golden.md`: output Markdown path (default: stdout)
* `--out-dir out`: asset output directory (docx images go to `out/assets/`)
* `--max-heading 3`: maximum heading level (1–6). **Currently supports up to level 3.**

PDF example:

```bash
moon run --target native src/cli -- \
  convert samples/text_simple.pdf \
  -o out/text_simple.md \
  --out-dir out
```

---

## Regression Tests (samples)

The script writes conversion outputs to **`.tmp_pdf_out/`** and diffs against `samples/expected/`.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_pdf_out
./samples/diff.sh
```

If you update the implementation and confirm the new output is correct, refresh the golden outputs:

```bash
rm -rf samples/expected
mkdir -p samples/expected
cp .tmp_pdf_out/text_simple.md    samples/expected/text_simple.md
cp .tmp_pdf_out/text_hardwrap.md  samples/expected/text_hardwrap.md
cp .tmp_pdf_out/text_multipage.md samples/expected/text_multipage.md
./samples/diff.sh
```

---

## Recommended Test Samples (this repo ships 4 golden test cases)

### Docx (`golden.docx`) should include

* Heading levels 1/2/3
* Mixed Chinese/English paragraphs (with punctuation and line breaks)
* At least 1 image (`word/media/image1.png`)
* At least 1 table (3 columns × 4–5 rows)

### PDF (`text_*.pdf`) should cover

* `text_simple.pdf`: multi-paragraph (CN/EN/mixed)
* `text_hardwrap.pdf`: hard wraps (line breaks every few words)
* `text_multipage.pdf`: multi-page separator handling

---

## Roadmap

### Near-term (Docx)

1. Support more heading styles (e.g., `Title` / `Subtitle` / `Heading4..6`)
2. Images: support multiple images, multiple rIds, and de-duplication for repeated references

### Mid-term (PDF)

1. Improve paragraphing and line-wrap rules (more stable reading order / pagination / lists)
2. Later: scanned PDFs (OCR + basic layout recovery), likely still via external tools first, then progressively MoonBit-ified

---

## Status

* ✅ docx: minimal end-to-end pipeline works
* ✅ pdf (text-based): MVP works (depends on external extractors)
* ✅ samples regression script works (output directory: `.tmp_pdf_out/`)
