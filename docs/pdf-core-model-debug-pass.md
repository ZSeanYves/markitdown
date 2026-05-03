# PDF Core Model/Debug Pass

This document records the PDF P1 `pdf_core` model/debug signal pass.

Scope for this round:

* tighten `pdf_core` model-field responsibility
* improve inspect/debug visibility for page/text/image/annotation/source refs
* expose conservative P1 signals that later `convert/pdf` work can consume
* keep PDF Markdown output unchanged

Non-goals for this round:

* no heading/noise/cross-page rule rewrite in `convert/pdf`
* no Markdown expected changes
* no OCR default-path changes
* no full table extraction
* no full multi-column reading-order engine

## Current `pdf_core` Model Map

### Layers

| Layer | File(s) | Current responsibility | Public/Private | Notes |
| --- | --- | --- | --- | --- |
| geometry model | `doc_parse/pdf_core/model/pdf_geom_model.mbt` | points, rects, quads, colors, page boxes, geometry helpers | public | shared by text/image/page model |
| text model | `doc_parse/pdf_core/model/pdf_text_model.mbt` | source refs, chars, spans, lines, blocks, text helpers | public | now also exposes source-ref and count helpers |
| page/document model | `doc_parse/pdf_core/model/pdf_page_model.mbt` | page/image/annotation/vector/form/document containers | public | now also exposes page stats and edge-region helpers |
| image/annotation model | `doc_parse/pdf_core/model/pdf_image_model.mbt` | payload/image/annotation/vector/form structs | public | core only exposes object/provenance, not final caption semantics |
| raw parser types | `doc_parse/pdf_core/raw/pdf_raw_types.mbt` | backend-owned raw extract structs | mixed | adapter-facing layer |
| raw adapters | `doc_parse/pdf_core/raw/mbtpdf_*.mbt` | vendored `mbtpdf` -> project raw structs | private boundary | only raw layer should know backend details |
| text reconstruction | `doc_parse/pdf_core/text/pdf_text_*.mbt`, `normalize_texts.mbt`, `rule.mbt`, `unicode_compat.mbt` | chars -> spans -> lines -> blocks | public package, internal heuristic role | still heuristic-heavy but model-facing |
| API/builder | `doc_parse/pdf_core/api/pdf_core_api.mbt` | raw -> model, summaries, debug/inspect | public | main consumer entry for `convert/pdf` |
| tests | `doc_parse/pdf_core/api/test/pdf_core_test.mbt`, `doc_parse/pdf_core/model/test/pdf_text_model_test.mbt`, `doc_parse/pdf_core/test/*` | integration/model smoke | test-only | new aggregate test package added |

### Key model responsibilities

* `PdfDocumentModel`
  Owns document-level metadata and capability flags, plus page list.
* `PdfPageModel`
  Owns page geometry, text blocks, images, annotations, and raw content stream
  refs.
* `PdfTextBlock`
  Owns block bbox, dominant font signal, candidate flags, and block-level
  source refs.
* `PdfTextLine`
  Owns baseline/line-height/indent/gap metrics and line-level source refs.
* `PdfTextSpan`
  Owns run-like text, font/style hints, chars, and span-level source refs.
* `PdfChar`
  Owns decoded glyph text, geometry, decode confidence, ligature/compat flags,
  and char-level source ref.
* `PdfImageObject`
  Owns image bbox, pixel size, payload, object ref, and image source refs.
* `PdfAnnotationObject`
  Owns subtype, bbox, URI/dest-facing link signal, object ref, and source refs.
* `PdfSourceRef`
  Owns stream/op/text-object/content-order/object-ref provenance for later
  debug and convert use.

## Debug / Inspect Surface

Current public debug/inspect API after this pass:

* `extract_document_summary`
  Compact document-level summary.
* `extract_document_block_debug`
  Page/block/line/image/annotation dump with geometry, totals, and source-ref
  counts.
* `extract_document_inspect_dump`
  New deeper inspect surface with:
  * page geometry and stats
  * page edge thresholds and candidate totals
  * block flags and source refs
  * line metrics and source refs
  * span font/style/source refs
  * image bbox/object-ref/source refs
  * annotation bbox/URI/dest/source refs

This is still debug output, not a stable IR or Markdown contract.

## P1 Signal Status

| Signal | Current status after this pass | Notes |
| --- | --- | --- |
| page geometry | exposed and inspectable | media/crop/rotation visible in debug/inspect |
| page block/line/span/char stats | exposed | page/block/line count helpers added |
| page edge thresholds | exposed as helper + inspect dump | enables later repeated-edge cleanup to consume the same notion of edge zone |
| edge-region candidate | exposed as helper | conservative derived helper, not a final removal decision |
| artifact/header-footer/page-number candidate totals | exposed | counts visible per page |
| line gap / indent / baseline / line height | exposed in inspect dump | ready for later heading/hardwrap/cross-page tuning |
| block/line/span source refs | exposed in inspect dump | first source ref preview now visible |
| image bbox / provenance | exposed in inspect dump | id, bbox, object ref, source refs |
| annotation/link raw model | exposed in inspect dump | subtype, URI/dest, bbox, object ref, source refs |
| outlines/bookmarks | still gap/placeholder | document model field remains present but unpopulated |
| fatal/low-signal structured status | still gap | current API still uses `Result` + converter-side low-signal predicate |

## Annotation/Link Signal Status

`pdf_core` now exposes a conservative but usable annotation/link raw surface:

* `/Link` subtype
* URI action
* internal destination / `Dest`
* annotation bbox
* page-local ownership
* object ref
* model-level source refs

Current explicit gaps remain:

* raw annotation source refs are still empty
* quadpoints are not exposed
* outlines/bookmarks are still a placeholder gap
* there is no generalized action-system model beyond URI/internal-dest basics

This is enough for later `convert/pdf` work to distinguish core extraction gaps
from convert-side link emission policy.

## What `convert/pdf` Can Consume Next

Without changing Markdown semantics yet, later `convert/pdf` work can now rely
on clearer lower-layer signal for:

* repeated header/footer and page-edge noise work
* heading decisions using line/block metrics
* cross-page merge attribution
* image-caption pairing attribution
* annotation/link emission planning
* source-ref-aware debugging when a conversion heuristic looks wrong

## Remaining Core Gaps

Still not solved by this pass:

* outlines/bookmarks are still empty
* capability flags like `has_xref_stream` / `has_object_stream` still need
  honest backend audit
* no structured fatal/low-signal status model yet
* no public raw-op dump API yet
* no richer reading-order candidate population yet
* no table-region model yet

## Next Implementation Sequence

1. Audit adapter-populated vs placeholder capability fields.
2. Decide whether raw-op/source-object inspect should become a public API.
3. Add sample guards for annotation/link and table-like negatives.
4. Use the new signal/debug surface to classify current heading/noise/cross-page
   misses into core-gap vs convert-gap buckets.
5. Start the next `pdf_core` P1 signal pass only where signal is still missing.
