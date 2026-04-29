# pdf_core

`doc_parse/pdf_core` is the native PDF structural recovery package used by the normal PDF path in `markitdown-mb`.

Its job is to turn rendering-oriented PDF content into a parser-facing document model. It does not emit final Markdown, does not own final IR shaping, and does not implement OCR. Upper layers such as `convert/pdf` decide how the recovered model becomes Markdown.

## Scope

`pdf_core` currently owns:

- opening text-based PDFs through the vendored `mbtpdf` backend
- extracting page text, images, page geometry, and low-level source references
- normalizing raw extracted content into chars, spans, lines, blocks, and pages
- exposing a stable `PdfDocumentModel` to higher converter layers
- providing debug/inspection strings for the recovered model

`pdf_core` does not own:

- final Markdown formatting
- final converter IR decisions
- OCR
- annotation/link/table semantic recovery
- browser-like visual layout reconstruction

## Vendored Backend Boundary

The only backend currently wired into `pdf_core` is vendored `mbtpdf`.

The backend boundary is intentionally narrow:

- `raw/mbtpdf_text_adapter.mbt` imports and consumes `mbtpdf` types.
- `raw/pdf_raw_types.mbt` exposes project-owned raw structs, not `mbtpdf` objects.
- `text`, `model`, and `api` consume project-owned raw/model types.
- `convert/pdf` consumes `pdf_core/api` output and should not depend on `mbtpdf`.

Recent backend work:

- V0: `mbtpdf` was vendored and connected as the PDF backend.
- V1: `LocatedOp` and `parse_operators_with_source` were added so operators can carry source references.
- V2.0: raw/model pages gained media box, crop box, rotation, raw page refs, and raw content stream refs.
- V2.1: vendored `Page.cropbox` now supports inherited `/CropBox`.

The public vendor API changed in V2.1 because `vendor/mbtpdf/document/pdfpage.Page` now includes:

```moonbit
cropbox : PdfObject?
```

This is intentionally contained inside the vendored backend and raw adapter boundary.

## Pipeline

The normal native pipeline is:

```text
mbtpdf
-> raw
-> chars
-> spans
-> lines
-> blocks
-> PdfDocumentModel
-> convert/pdf
```

Layer responsibilities:

- `raw`: factual backend extraction and backend-to-project type conversion.
- `text`: char/span/line/block reconstruction and text recovery heuristics.
- `model`: stable document, page, text, image, geometry, and source-reference structs.
- `api`: package entry points, backend selection, model building, and debug summaries.
- `debug`: there is no separate `debug` package; debug/inspection helpers currently live in `api` and selected pipeline files.

## Raw Layer

`raw` is the only layer that should directly understand `mbtpdf`.

Primary output:

- `RawPdfDocumentExtract`
- `RawPdfPageExtract`
- `RawTextOp`
- `RawImageInfo`

Current page-level raw fields include:

- `page_index`
- `raw_page_ref`
- `media_box`
- `crop_box`
- `rotation`
- `raw_content_stream_refs`
- text ops
- images
- annotations placeholder data

The adapter resolves inherited page geometry through `mbtpdf` page-tree reading. `crop_box` is parsed from `Page.cropbox`; malformed rectangles fall back to `None`.

## Text Layer

`text` turns raw page content into progressively richer textual structure:

- `pdf_text_chars.mbt`: raw text ops to character records.
- `pdf_text_spans.mbt`: character grouping.
- `pdf_text_lines.mbt`: line construction, normalization, merging, and page-line filtering.
- `pdf_text_blocks.mbt`: block construction.
- `normalize_texts.mbt`, `unicode_compat.mbt`, and `rule.mbt`: normalization and recovery heuristics.

This layer is heuristic-heavy by design. Rules should stay conservative, explainable, and regression-backed.

## Model Layer

`model` owns the stable internal representation exposed to the rest of the repository.

Important model groups:

- geometry: `PdfPoint`, `PdfRect`, page boxes
- text: chars, spans, lines, blocks
- image metadata and payloads
- page/document containers
- source references

`PdfPageModel` currently carries page geometry and provenance data:

- `boxes.media_box`
- `boxes.crop_box`
- `rotation`
- `raw_page_ref`
- `raw_content_stream_refs`

These fields are parser-facing metadata. They are not rendered directly to Markdown by `pdf_core`.

## API Layer

`api` is the public entry point for the package.

Main APIs:

- `default_pdf_core_config`
- `extract_document_model`
- `extract_document_summary`
- `extract_document_block_debug`

`extract_document_model` runs the full native pipeline and returns `PdfDocumentModel`.

`extract_document_summary` returns a compact human-readable summary.

`extract_document_block_debug` returns a textual inspection dump of pages, blocks, lines, images, geometry, and selected classification flags. This is for pipeline diagnosis; it is not a stable Markdown or IR format.

## Current Limits

Known limits:

- no full multi-column reading order engine
- no table semantic reconstruction
- no annotation/link semantic model
- no OCR in the native path
- no full vector/graphics semantic recovery
- no browser-like layout engine
- image extraction exists, but image semantics remain limited
- many line/block decisions remain heuristic and sample-regression driven

## Package Audit Notes

Current responsibilities are mostly separated:

- `raw` is the backend adapter boundary.
- `model` is type ownership.
- `text` is reconstruction logic.
- `api` is orchestration and public entry.
- debug output is available through API helpers and gated internal debug functions.

Files that are currently large enough to consider splitting later:

- `raw/mbtpdf_text_adapter.mbt`: backend opening, text ops, image extraction, source refs, and geometry are all in one file.
- `text/rule.mbt`: many unrelated recovery predicates live together.
- `text/normalize_texts.mbt`: normalization and hardwrap behavior could be grouped by concern.
- `api/test/pdf_core_test.mbt`: broad integration coverage in one test file.

Suggested future splits, without changing behavior now:

- `raw/mbtpdf_page_adapter.mbt`
- `raw/mbtpdf_text_ops.mbt`
- `raw/mbtpdf_image_adapter.mbt`
- `text/rules_heading.mbt`
- `text/rules_hardwrap.mbt`
- `text/rules_noise.mbt`

## Tests

Useful verification commands:

```sh
moon check
moon test
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
```

Current sample tests are expected to show no Markdown output changes for C0 documentation/package cleanup.
