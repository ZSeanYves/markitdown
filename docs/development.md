# Development Guide

## CLI

The current CLI uses a subcommand-based interface:

```bash
moon run cli -- normal <input> [output]
moon run cli -- ocr <input> [output]
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
````

To also output a metadata sidecar, use:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
moon run cli -- ocr --with-metadata <input> <output.md>
moon run cli -- debug --with-metadata <all|extract|raw|pipeline> <input> <output.md>
```

Current output rules:

* The Markdown main output follows the `[output]` argument
* If `[output]` behaves like a directory, the main output becomes `<output>/<input_stem>.md`
* The metadata sidecar is always written to:

  * `<markdown_dir>/metadata/<markdown_stem>.metadata.json`
* If no output file is provided (stdout mode), the sidecar is not written to disk

## Debug Modes

The current supported debug scopes are:

* `all`
* `extract`
* `raw`
* `pipeline`

Approximate meanings:

* `debug all`: enables the full PDF debug chain
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF processing pipeline

For the current native PDF path, `debug pipeline` is the most useful
architecture-facing inspect entry. It surfaces `pdf_core`-derived information
such as page geometry, raw refs, image summaries, annotation summaries, and
text block statistics without changing normal conversion output.

## Regression System

The current regression system has been split into three independent validation chains:

* `samples/main_process`: mainflow structural recovery
* `samples/metadata`: origin / image-context / caption / nearby-caption
* `samples/assets`: asset export and Markdown asset-reference validity

In addition, `samples/test` provides a compact five-format demo set for acceptance walkthrough and quick manual inspection.

### Check sample enrollment consistency

```bash
./samples/check_samples.sh
```

### Run full main regression

```bash
./samples/diff.sh
```

### Run metadata regression independently

```bash
./samples/check_metadata.sh
```

### Run assets regression independently

```bash
./samples/check_assets.sh
```

## How to Choose Regression Scope During Development

### When modifying mainflow structural recovery logic

If you modify any of the following, you should at least run:

```bash
./samples/diff.sh
```

Typical cases include:

* `convert/*`
* `core/emitter_markdown.mbt`
* `core/ir.mbt`
* mainflow-related samples and expected outputs

### When modifying metadata / provenance / image-context logic

If you modify any of the following, you should at least run:

```bash
./samples/check_metadata.sh
```

Typical cases include:

* `core/metadata.mbt`
* `core/ir.mbt`
* image caption / nearby-caption / origin related logic
* `samples/metadata/*`

### When modifying asset export / asset reference logic

If you modify any of the following, you should at least run:

```bash
./samples/check_assets.sh
```

Typical cases include:

* image export logic for any format
* asset naming rules
* `samples/assets/*`

### When modifying PDF-related lower-level or recovery logic

If you modify any of the following, it is recommended to run at least:

```bash
./samples/diff.sh
./samples/check_metadata.sh
```

Typical cases include:

* `doc_parse/pdf_core/`
* `convert/pdf/`
* `core/emitter_markdown.mbt`
* PDF-related samples / expected outputs / metadata samples

The reason is that PDF currently affects not only the mainflow, but also image context and lightweight provenance.

## External Dependencies

### OCR plugin path

At the moment, only the OCR path depends on external tooling:

* `ocrmypdf`

Notes:

* OCR remains a dedicated plugin-style path, not the default `normal` mainflow
* The normal PDF path on `main` no longer depends on `pdftotext` or `mutool`
* The current normal PDF mainflow is driven by the repository’s native recovery chain

## How to Understand the Current Engineering Structure

The current project can be roughly understood as the following layers:

* `cli/`: command-line entry and output path coordination
* `convert/*`: upper-level structural recovery and semantic mapping
* `doc_parse/*`: lower-level parsing infrastructure (ZIP / OOXML / PDF)
* `core/*`: unified IR, Markdown emitter, metadata sidecar emitter
* `samples/*`: mainflow / metadata / assets regression and acceptance demo samples

Within `doc_parse/*`, the current lower-level package split is:

* `doc_parse/zip`: ZIP container handling used by OOXML readers
* `doc_parse/ooxml`: shared OOXML package/relationship/media/docProps/debug-dump infrastructure
* `doc_parse/pdf_core`: native PDF parsing substrate including page geometry, source refs, raw images/annotations, and inspect helpers

When developing, you should try to determine clearly which layer your change belongs to:

* raw format parsing problems: check `doc_parse/*` first
* structural recovery problems: check `convert/*` first
* output form and sidecar problems: check `core/*` first
* acceptance or regression issues: check `samples/*` first

## Completed Stabilization Phase

This phase consolidated the OOXML infrastructure, native PDF parsing
substrate, and PDF conversion pipeline without changing the public metadata
sidecar schema or the expected Markdown sample outputs.

### OOXML infrastructure

The shared OOXML layer now provides:

* package query helpers for opening packages, listing parts, checking part
  existence, reading part bytes, and querying content types
* typed relationship parsing with internal/external target handling and
  relationship lookup helpers
* media asset indexing for `word/media`, `ppt/media`, and `xl/media`
* lightweight `docProps/core.xml` and `docProps/app.xml` extraction
* read-only package dump APIs for inspection
* document-property propagation into the metadata sidecar `document` section
* README and package-level responsibility documentation that separates ZIP,
  OOXML shared infrastructure, and format-specific recovery code

### PDF Core infrastructure

The native PDF substrate now provides:

* vendored `mbtpdf` backend integration behind `doc_parse/pdf_core/api`
* source-aware operator parsing and source reference propagation
* page geometry exposure including media box, inherited crop box, rotation,
  raw page refs, and raw content stream refs
* raw image extraction with payload, placement bbox, object refs, filters, and
  source refs
* raw annotation/link extraction with URI, destination, bbox, object ref, and
  source refs
* raw adapter decomposition so text, images, and annotations remain inspectable
  without forcing final Markdown semantics in the parsing layer
* debug inspect output for document, page, text, image, annotation, and geometry
  diagnostics

### PDF Convert pipeline

The default PDF conversion path now has explicit stage boundaries:

* heading recovery is finalized in `classify`, so `to_ir` no longer re-opens
  the heading/noise/paragraph classification decision
* cross-page paragraph merge is layered through hard blockers, positive text
  continuation, layout compatibility, and core-derived continuation support
* repeated edge noise cleanup uses repeated head/tail detection with page box
  top/bottom zones
* `PdfConvertBlock` retains source core block provenance and block-level flags
  for debug and future enhancement work while preserving the default line-seed
  one-line-one-block strategy
* image provenance is available in PDF pipeline debug, including image filter,
  object ref, inline-image marker, dimensions, placement bbox, and source-ref
  count
* annotation/link records are visible in PDF pipeline debug, but are not emitted
  as Markdown links by default
* single-image caption pairing is bbox-gated and remains conservative; ambiguous
  cases are intentionally left unmatched

## Current Boundaries

The following remain unsupported or intentionally disabled by default:

* PDF multi-image caption pairing
* PDF annotation/link Markdown emission
* PDF outline/bookmark extraction into Markdown or metadata output
* PDF complex table recovery
* OCR as a formally closed default path
* broad new-format expansion beyond the current docx/pdf/xlsx/pptx/html/csv/tsv set

## Next Candidate Routes

Recommended order for the next expansion phase:

1. JSON / YAML
2. Markdown passthrough + metadata
3. EPUB
4. RTF
5. ODT / ODS / ODP

Rationale:

* JSON / YAML can establish structured-data passthrough and summarization
  patterns now that CSV / TSV cover the first small-surface table-text route.
* Markdown passthrough can validate metadata/origin behavior without introducing
  a heavy parser.
* EPUB is valuable but requires package/navigation/content stitching.
* RTF and OpenDocument formats are broader parser investments and should follow
  after the lighter routes.

```
