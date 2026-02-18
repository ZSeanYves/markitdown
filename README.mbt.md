# markitdown-mb (MoonBit)

A MoonBit (markitdown-like) implementation that converts **.docx / .pdf** into structured **Markdown**.

> Current focus: first get the minimal **docx → IR → Markdown** pipeline working end-to-end; PDF parsing will be added later.

---

## Repository Structure (Current)

* `src/cli/`: CLI entrypoint (`demo` / `convert`)
* `src/core/`: core IR + Markdown emitter

  * `ir.mbt`: IR definitions such as `Document` / `Block` / `Inline`
  * `emitter_markdown.mbt`: IR → Markdown
  * `dispatcher.mbt`: dispatch parsers by file extension (currently mainly docx)
  * `errors.mbt` / `tool.mbt`: shared utilities
* `src/docx/`: docx parsing (main track)

  * `zip_min.mbt`: a **pure MoonBit** minimal ZIP reader (used to read entries inside docx)
  * `docx_zip.mbt`: docx ZIP wrapper (reads `word/document.xml` / rels / media)
  * `rels.mbt`: parse `document.xml.rels` (rId → Target)
  * `docx_xml.mbt`: scan `document.xml` and build IR (paragraphs/headings/images/tables)
  * `docx_parser.mbt`: the composed workflow `parse_docx()`
* `src/pdf/`: placeholder (`pdf_parser.mbt`, to be implemented)
* `samples/`: test samples (e.g. `golden.docx`)
* `out/`: output directory (markdown + assets)

---

## Completed / Currently Working

### ✅ Core layer

* IR definitions and `push` work as expected
* Markdown emitter is usable (headings, paragraphs, tables, image references)

### ✅ Docx minimal pipeline is working

* Can read from a `.docx`:

  * `word/document.xml`
  * `word/_rels/document.xml.rels`
  * `word/media/*` (images)
* Can export images to `out/assets/` and reference them in Markdown as `![image](assets/xxx.png)`

### ✅ Deflate decompression works

* In `zip_min`, deflate decompression is currently implemented via `mizchi/zlib` (`deflate_decompress`) and works on real docx files.

  * The earlier `zipc/deflate` path failed to decompress real docx reliably, so it has been switched.

---

## How to Run

### 1) `demo`: validate the core

```bash
moon run src/cli -- demo
```

Prints a demo Markdown document (no docx required).

### 2) `convert`: convert docx → Markdown

Preparation: put a test docx into `samples/` (e.g. `samples/golden.docx`).

```bash
moon run --target native src/cli -- \
  convert samples/golden.docx \
  -o out/golden.md \
  --out-dir out \
  --max-heading 3
```

* `-o out/golden.md`: output Markdown path
* `--out-dir out`: export images and other assets to `out/assets/`
* `--max-heading 3`: maximum heading level (1–6)

> Note: currently `out-dir` must exist or be created by the program (auto-creation for `out/assets` is supported).

---

## Recommended Test Docx

It’s best to prepare a “golden” docx that includes:

* Heading 1/2/3
* Normal paragraphs (mixed Chinese/English, punctuation, line breaks)
* One image (`word/media/image1.png`)
* One table (3 columns × 4–5 rows)

A main test sample has already been prepared containing: headings + paragraphs + image + table.

---

## Roadmap

### Near-term (docx)

1. Support more heading styles (e.g. `Title` / `Subtitle` / `Heading4..6`)
2. Images: support multiple images, different rIds, and a dedup strategy for repeated references

### Mid-term (pdf)

* Start with text-based PDFs: extract text → paragraphs
* Then handle scanned PDFs: OCR + layout (likely integrating external tools first, then gradually porting to MoonBit)

---

## Status Summary

* ✅ **Minimal docx pipeline is working end-to-end**: read docx, export images, generate Markdown
* ✅ ZIP/deflate is stable on real docx using pure MoonBit + `mizchi/zlib`
