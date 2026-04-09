# markitdown-mb (MoonBit)

`markitdown-mb` is a MoonBit document-to-Markdown converter.

It currently supports:
- `docx`
- `pdf`
- `xlsx`
- `pptx`
- `html`

The project is now in a **stable mainline + tech-debt cleanup + lower-layer convergence** stage.

---

## Current Status

The main conversion chain is stable across formats:

`document -> parser -> IR -> Markdown`

Sample-based regression is the primary safety net and is designed to be continuously runnable during iteration.

This is no longer an MVP branch. The focus has shifted from “make it work once” to “keep behavior stable while cleaning internals and reducing duplicated infrastructure”.

---

## Features

- Multi-format parsing entry with shared dispatch.
- Shared IR (`Document` / `Block`) for all formats.
- Markdown emitter with stable block-level output behavior.
- Format-specific parsers with pragmatic structure recovery heuristics.
- Sample-based regression assets under `samples/` and `samples/expected/`.

---

## Architecture

### High-level pipeline

`document bytes/path -> format parser -> IR -> Markdown`

- Each format parser maps source structure into shared IR.
- The Markdown emitter is format-agnostic.
- This keeps parser complexity local while preserving a unified output contract.

### OOXML pipeline (current)

For OOXML formats (`docx`, `xlsx`, `pptx`), the shared lower chain is now:

`bytes -> ZipArchive -> OoxmlPackage -> format parser`

This is the current baseline for package/container access.

---

## OOXML Foundation

A full first round of lower-layer refactoring has been completed:

- **Self-managed ZIP container phase-1**
- **Self-managed OOXML package phase-1**

### What this means

- `docx / xlsx / pptx` now use the same shared OOXML lower layer.
- Active OOXML paths no longer depend on the previous external-path-based ZIP helper flow.
- ZIP/package behavior is controlled inside this repository, with cleaner dependency direction and less repeated container logic in each format parser.

### ZIP container phase-1 capabilities

- EOCD discovery
- central directory parsing
- entry indexing
- local header validation
- reading entry bytes by path
- current supported ZIP methods:
  - `Store`
  - `DeflateRaw`

### OOXML package phase-1 capabilities

- part existence check
- part bytes reading
- `[Content_Types].xml` lookup
- package relationships reading
- part relationships reading
- relationship target resolution

---

## Format Status

### DOCX

- High completion level for current scope.
- Built on the new shared OOXML lower layer.
- Strong coverage for document structure extraction in current regression set.

### XLSX

- High completion level for current scope.
- Built on the new shared OOXML lower layer.
- Stable table-oriented output behavior in current regression set.

### PPTX

- High completion level with ongoing enhancement.
- Built on the new shared OOXML lower layer.
- Structure recovery remains heuristic-driven and is being incrementally hardened by samples.

### PDF

- Functional and actively used, but still the largest technical-debt area.
- Continues to rely on external text extraction/OCR tooling.

### HTML

- High completion level for current scope.
- Stable parser + IR mapping behavior in current regression set.

---

## Limitations

The project intentionally documents current boundaries instead of claiming full coverage.

- PDF still depends on external extraction tools.
- ZIP phase currently targets common OOXML samples and does **not** fully cover:
  - ZIP64
  - encrypted ZIP
  - multi-disk ZIP
  - full data-descriptor support
- OOXML package layer is requirement-driven for this project, not a full general-purpose OOXML SDK.
- Complex PDF/PPTX structure recovery still relies on heuristics.

---

## Development Status

Current engineering priorities are:

1. Keep mainline behavior stable under sample-based regression.
2. Continue technical debt cleanup, especially around PDF and parser edge cases.
3. Converge shared lower layers to reduce duplicated container/package logic.
4. Improve maintainability through clearer module boundaries and dependency direction.

---

## Suggested Next Directions / Roadmap

- Expand ZIP/container compatibility where needed (selectively, based on real samples).
- Continue OOXML package hardening for edge relationships/content-type cases.
- Keep improving PPTX/PDF structural recovery with targeted regression additions.
- Reduce parser-local duplication by extracting reusable lower-level helpers when behavior is proven stable.
- Maintain conservative output stability: behavior changes should be sample-backed and intentional.
