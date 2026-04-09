# markitdown-mb (MoonBit)

`markitdown-mb` is a MoonBit document-to-Markdown converter.

It currently supports:

- `docx`
- `pdf`
- `xlsx`
- `pptx`
- `html`

The project is beyond MVP. The main conversion chain is stable:

`document -> parser -> IR -> Markdown`

and sample-based regression is used continuously as the primary guardrail.

---

## Current Engineering Status

The project is currently in a **"main pipeline stable + technical debt cleanup + lower-layer convergence"** phase.

Key points:

- Multi-format mainline conversion is stable.
- Regression samples are maintained and runnable.
- Ongoing work focuses on reducing duplicated infrastructure and improving parser internals.

---

## Architecture Overview

### End-to-end flow

For all supported formats:

`input bytes -> format parser -> shared IR -> Markdown emitter`

### OOXML unified lower layer (completed phase-1 refactor)

A major refactor has been completed for OOXML formats (`docx/xlsx/pptx`).

The shared lower-level chain is now:

`bytes -> ZipArchive -> OoxmlPackage -> format parser`

This means:

- ZIP container handling is now self-managed in-project (phase-1).
- OOXML package handling is now self-managed in-project (phase-1).
- `docx`, `xlsx`, and `pptx` all run on the same OOXML foundation.
- Previous `zipmin` / external-path helper dependency direction has been removed.

Result: cleaner dependency direction and less repeated container/package logic across OOXML parsers.

---

## OOXML Foundation Capabilities (phase-1)

### ZIP container phase-1

Current implemented scope includes:

- EOCD discovery
- central directory parsing
- entry indexing
- local header validation
- reading entry bytes by path
- compression methods currently supported:
  - `Store`
  - `DeflateRaw`

### OOXML package phase-1

Current implemented scope includes:

- part existence check
- part bytes reading
- `[Content_Types].xml` lookup
- package relationships reading
- part relationships reading
- relationship target resolution

---

## Format Status

### DOCX

- High completeness for current project scope.
- Runs on the new shared OOXML lower layer.
- Includes structure-oriented recovery (headings, lists, tables, images, etc.).

### XLSX

- High completeness for current project scope.
- Runs on the new shared OOXML lower layer.
- Maintains stable sheet/table extraction behavior.

### PPTX

- High completeness with ongoing enhancement.
- Runs on the new shared OOXML lower layer.
- Continues to improve layout/reading-order and structure heuristics.

### PDF

- Still relies on external text extraction tools.
- Remains one of the main technical debt sources.

### HTML

- High completeness for current project scope.
- Stable conversion path.

---

## Limitations (current, explicit)

This project intentionally keeps limitations explicit:

- PDF conversion still depends on external extractors/tooling.
- ZIP phase-1 is focused on normal OOXML samples and does **not** fully cover:
  - ZIP64
  - encrypted ZIP
  - multi-disk ZIP
  - full data-descriptor support
- OOXML package layer is project-oriented, not a full general-purpose OOXML SDK.
- Complex PDF/PPTX structure recovery is still heuristic-dependent.

---

## Repository Layout

- `src/cli`: CLI entry and argument handling
- `src/convert`: format dispatch layer
- `src/core`: shared IR, Markdown emitter, common utilities/errors
- `src/zip`: self-managed ZIP container implementation (phase-1)
- `src/ooxml`: self-managed OOXML package implementation (phase-1)
- `src/docx`: DOCX parser
- `src/xlsx`: XLSX parser
- `src/pptx`: PPTX parser
- `src/pdf`: PDF pipeline and heuristic recovery
- `src/html`: HTML parser
- `samples`: sample inputs + expected outputs for regression

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
  -o <output.md> \
  --out-dir <output-dir>
```

Example:

```bash
moon run --target native src/cli -- \
  convert samples/docx/golden.docx \
  -o out/golden.md \
  --out-dir out
```

Common options:

- `-o <path>`: output Markdown file (default: stdout)
- `--out-dir <dir>`: output directory (e.g. extracted assets)
- `--max-heading N`: max heading level (`1..6`)
- `--pdf-mode experimental`: enable experimental PDF paths (including OCR fallback when available)

---

## Regression Workflow

Sample-based regression is the default quality gate.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

The script regenerates outputs under `.tmp_test_out/` and diffs against `samples/expected/<format>/`.

---

## External Dependencies

### PDF text extraction

At least one of:

- `pdftotext` (Poppler)
- `mutool` (MuPDF)

### PDF OCR fallback (experimental)

- `ocrmypdf`
- `tesseract`

---

## Project Direction

Current direction is practical and incremental:

1. Keep the multi-format mainline stable.
2. Continue parser quality improvements through regression samples.
3. Continue technical debt cleanup where external dependencies are still required.
4. Further converge shared lower layers when that reduces duplicated logic without over-generalizing.

