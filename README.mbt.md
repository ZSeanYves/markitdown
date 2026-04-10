# markitdown-mb (MoonBit)

`markitdown-mb` is a MoonBit document-to-Markdown converter.

Supported input formats:

- `.docx`
- `.pdf`
- `.xlsx`
- `.pptx`
- `.html`

The project is no longer in MVP stage. The main pipeline is stable and runs as:

```text
document -> parser -> IR -> Markdown
```

Regression behavior is maintained with sample-based golden outputs.

---

## Current Architecture

The codebase is organized around a shared core plus format-specific parsers.

### Core

- IR model
- Markdown emitter

### Format parsers

- DOCX parser
- PDF parser
- XLSX parser
- PPTX parser
- HTML parser

### Shared OOXML lower layer (in use)

- ZIP reader
- OOXML package reader

Shared execution chain:

```text
bytes -> ZipArchive -> OoxmlPackage -> format parser
```

### PDF native lower layer (early, in use)

- PDF document/container and object access
- page references and page count
- content stream access
- minimal native text extraction path

The PDF path is currently hybrid:

- external text-extraction backend remains the primary production path
- native backend foundation is integrated and being expanded incrementally

---

## Project Status

### Mainline status

- Multi-format mainline is stable: `document -> parser -> IR -> Markdown`.
- Sample-based regression is continuously runnable.
- OOXML shared lower layer is completed at phase-1 and in production use.
- PDF moved from “external-only” toward a hybrid model (external + early native).

### OOXML status (phase-1 complete)

- Self-managed ZIP container phase-1: completed.
- Self-managed OOXML package phase-1: completed.
- `docx / xlsx / pptx` are fully migrated to the shared OOXML lower layer.
- Old `zipmin` / external path-helper dependencies have been removed from the Office-family pipeline.
- Dependency direction is cleaner: container/package logic is now controlled inside this repository.

### PDF status (hybrid)

Primary path (current):

- External PDF text extraction backend is still the main flow.

Native backend foundation (current):

- PDF container/object access
- page refs/page count
- content stream access
- minimal content-stream text extraction
- `/Length` indirect-reference support
- inherited page resources lookup
- basic ToUnicode CMap parsing
- fallback behavior when ToUnicode is missing

Scope note:

- Native backend is already wired into part of mainline, but still in gradual coverage expansion.
- It is not yet a full replacement for external backends.

---

## Format Coverage Snapshot

### DOCX

- High completion for current project scope.
- Fully migrated to shared OOXML lower layer.
- Stable behavior includes headings, paragraphs, lists, tables, images, manual line breaks, and code-like paragraph recovery.

### XLSX

- High completion for current project scope.
- Fully migrated to shared OOXML lower layer.
- Stable behavior includes multi-sheet output, sparse trimming, basic cell types, and basic date/time/datetime formatting.

### PPTX

- High completion with ongoing heuristic refinement.
- Fully migrated to shared OOXML lower layer.
- Current capabilities include title/body split, reading-order recovery, and note-like/caption-like/table-like/grouping behavior.

### PDF

- Hybrid status.
- External backend remains primary.
- Native backend provides early parser foundation with page/content-stream-level minimal text extraction.
- PDF remains one of the highest-complexity, highest-limitation areas in the project.

### HTML

- High completion for current project scope.
- Covered behavior includes headings, paragraphs, lists, block quotes, code blocks, tables, `<br>` handling, nested lists, and ragged-row table normalization.

---

## Limitations

This project intentionally stays project-oriented and does not claim full-spec parser coverage.

### OOXML limitations

Current ZIP/OOXML package layer is targeted to project needs and does not fully cover:

- ZIP64
- encrypted ZIP
- multi-disk ZIP
- full data-descriptor support

### PDF limitations

Native PDF backend is early-stage and project-oriented. It should not be described as a complete PDF parser.

Not fully covered at this stage:

- encryption
- full xref-stream/object-stream coverage
- full font system coverage
- full ToUnicode/CMap ecosystem coverage
- complete multi-column reading-order reconstruction
- image-only/OCR replacement for external pipeline

Known difficult cases remain, including pseudo two-column and interleaved text-order PDFs.

---

## Repository Layout

- `src/cli/`: CLI entry and option handling
- `src/convert/`: format dispatch
- `src/core/`: shared IR and Markdown emitter
- `src/ooxml/`: shared ZIP + OOXML package lower layer
- `src/docx/`: DOCX parser (on shared OOXML)
- `src/xlsx/`: XLSX parser (on shared OOXML)
- `src/pptx/`: PPTX parser (on shared OOXML)
- `src/pdf/`: PDF parser (hybrid external/native)
- `src/html/`: HTML parser
- `samples/`: input samples + expected markdown outputs

---

## External Dependencies

### PDF text extraction (primary path)

At least one backend should be available:

- `pdftotext` (Poppler)
- `mutool` (MuPDF)

Install examples:

- macOS (Homebrew): `brew install poppler mupdf`
- Ubuntu/Debian: `sudo apt-get install poppler-utils mupdf-tools`
- Arch: `sudo pacman -S poppler mupdf-tools`

---

## Usage

### Demo

```bash
moon run src/cli -- demo
```

### Convert

```bash
moon run --target native src/cli -- \
  convert <input-file> \
  -o out/output.md \
  --out-dir out
```

Examples:

```bash
# DOCX
moon run --target native src/cli -- convert samples/docx/golden.docx -o out/golden.md --out-dir out

# PDF
moon run --target native src/cli -- convert samples/pdf/text_simple.pdf -o out/text_simple.md --out-dir out

# XLSX
moon run --target native src/cli -- convert samples/xlsx/sheet_simple.xlsx -o out/sheet_simple.md --out-dir out

# PPTX
moon run --target native src/cli -- convert samples/pptx/pptx_simple.pptx -o out/pptx_simple.md --out-dir out

# HTML
moon run --target native src/cli -- convert samples/html/html_simple.html -o out/html_simple.md --out-dir out
```

Useful options:

- `-o <path>`: output Markdown file (default: stdout)
- `--out-dir <dir>`: asset output directory (DOCX images go to `assets/` under this directory)
- `--max-heading <1..6>`: heading clamp in Markdown output
- `--pdf-extract-debug [1|true|on|yes]`: show PDF extraction backend scoring logs

### Native PDF backend (incremental)

Use explicit native backend switch:

```bash
moon run --target native src/cli -- \
  convert samples/pdf/text_simple.pdf \
  -o out/text_simple.native.md \
  --pdf-backend pdf-native
```

Recommended current use cases:

- real-world **simple text PDFs** (single-page / multi-page)
- quick native-path regression checks for `Tf + Tj/TJ` and basic ToUnicode cases

The native backend is still in incremental expansion and is **not** a full-spec parser.  
See `docs/pdf_native_supported_subset.md` for the current supported/unsupported/degraded scope.

---

## Regression Workflow

Run sample regression:

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

The script writes outputs to `.tmp_test_out/` and diffs against `samples/expected/<format>/`.

---

## Development Status and Roadmap

Current development phase:

- main pipeline stable
- shared lower layers in place
- robustness hardening (phase-1.5 style)
- native PDF backend incremental expansion

Roadmap priorities:

1. Expand native PDF backend coverage on real-world simple text PDFs.
2. Continue robustness hardening with negative/boundary samples.
3. Deliver small lower-layer refinements without reopening architecture.
4. Keep the hybrid PDF strategy while native support matures.
