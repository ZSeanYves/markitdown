# PDF H2 Core Gap Review

This document records the first planning pass for PDF H2 work.

Status update:

* PDF P1 `doc_parse/pdf` model/debug signal pass is completed
* PDF P1.1 annotation/link signal pass is completed
* PDF P2.2 high-confidence URI link emission is completed
* PDF P3/P4 heading/noise/cross-page passes are completed through benchmark and
  comparison refresh
* PDF conservative table/caption passes and numeric page-number scoping pass
  are completed
* PDF final closure re-audit now treats PDF as H2 complete, with remaining
  deeper layout/semantic gaps kept as documented limitations
* current implementation notes are tracked in
  [docs/pdf-core-model-debug-pass.md](./pdf-core-model-debug-pass.md)
* current heading / noise / cross-page attribution notes are tracked in
  [docs/pdf-p3-heading-noise-cross-page-audit.md](./pdf-p3-heading-noise-cross-page-audit.md)

Scope for this round:

* audit the current `doc_parse/pdf` and `convert/pdf` architecture
* identify which H2 gaps are really core gaps
* identify which H2 improvements can stay in `convert/pdf`
* inventory current samples and benchmark coverage
* define a core-first next-step order

This is intentionally not a converter rewrite plan. It does not change current
PDF semantics by itself.

## Current PDF Architecture Map

### `doc_parse/pdf` / `doc_parse` map

Current PDF lower-layer code is centered under `doc_parse/pdf/`:

* `raw/mbtpdf_text_adapter.mbt`
  Reads PDFs through vendored `mbtpdf`, walks page content streams, and emits
  project-owned raw text-op records.
* `raw/mbtpdf_page_adapter.mbt`
  Extracts page refs, media/crop boxes, rotation, and content stream refs.
* `raw/mbtpdf_image_adapter.mbt`
  Extracts inline/XObject/Form-XObject images, placement bbox, payload bytes,
  and source refs.
* `raw/mbtpdf_annotation_adapter.mbt`
  Extracts raw annotations, including URI/dest data when present.
* `raw/pdf_raw_types.mbt`
  Owns project-side raw structs such as `RawPdfDocumentExtract`,
  `RawPdfPageExtract`, `RawTextOp`, `RawImageInfo`, and `RawAnnotationInfo`.
* `text/pdf_text_chars.mbt`
  Rebuilds chars from raw text ops.
* `text/pdf_text_spans.mbt`
  Groups chars into spans.
* `text/pdf_text_lines.mbt`
  Rebuilds lines and line metrics.
* `text/pdf_text_blocks.mbt`
  Rebuilds text blocks and block-level candidate flags.
* `text/normalize_texts.mbt`, `text/unicode_compat.mbt`, `text/rule.mbt`
  Normalization and recovery heuristics.
* `model/pdf_geom_model.mbt`
  Geometry types such as points, rects, and page boxes.
* `model/pdf_text_model.mbt`
  Chars, spans, lines, and blocks.
* `model/pdf_image_model.mbt`
  Image payload and provenance-facing image structs.
* `model/pdf_page_model.mbt`
  Page/document containers, annotations, outlines, vectors, forms, metadata.
* `api/pdf_api.mbt`
  Public API entry point and debug helpers.
* `api/test/pdf_api_test.mbt`
  Integration-style coverage for model extraction, images, annotations, and
  debug summaries.

There is no separate `pdf debug` package today. Public debug surfaces live
in `api`, and some lower-level helpers remain internal to the adapters.

### `convert/pdf` map

Current converter-side PDF files are under `convert/pdf/`:

* `pdf_parser.mbt`
  Main native-or-OCR orchestration path.
* `pdf_extract.mbt`
  Thin bridge from `convert/pdf` into `pdf/api`.
* `pdf_lines.mbt`
  Converts `doc_parse/pdf` pages/blocks/lines/images/annotations into convert-stage
  line/image/annotation structs.
* `pdf_blocks.mbt`
  Rebuilds initial convert blocks and page object order.
* `pdf_classify.mbt`
  Heading/paragraph/noise reclassification heuristics.
* `pdf_noise.mbt`
  Repeated edge noise and page-number cleanup.
* `pdf_merge.mbt`
  Cross-page paragraph merge heuristics.
* `pdf_to_ir.mbt`
  Converts text blocks/images into unified IR and metadata sidecar origins.
* `pdf_debug.mbt`
  Convert-stage debug printers.
* `pdf_convert_types.mbt`
  Convert-stage structs and helper enums.
* `ocr/*`
  Optional OCR pipeline, not part of the default native fast path.

### Current main pipeline

The normal PDF path is currently:

```text
pdf extract_document_model
-> build_convert_lines
-> build_convert_blocks
-> classify_convert_blocks
-> filter_noise_blocks
-> merge_convert_blocks
-> convert_pdf_blocks_to_ir
```

Important current architecture fact:

* the native PDF path is already core-first in extraction
* the remaining H2 question is whether the missing market-parity behavior is
  caused by weak `doc_parse/pdf` signal, weak convert-stage use of that signal, or
  both

## `doc_parse/pdf` Current Model Audit

### Document-level

| Signal | Current status | Notes |
| --- | --- | --- |
| `PdfDocumentModel` | present | Stable public model returned by `extract_document_model`. |
| `page_count` | present | Populated. |
| document metadata | present | Title/author/subject/keywords/creator/producer/creation/mod dates. |
| `is_encrypted` | present | Populated from current backend state. |
| `has_object_stream` | present in model | Currently hardcoded `false` in the current adapter. |
| `has_xref_stream` | present in model | Currently hardcoded `false` in the current adapter. |
| `pages` | present | Main page surface. |
| `outlines` / bookmarks | model field exists | Currently emitted as empty; not yet populated. |
| fatal/error status | no model field | Extraction returns `Result`; convert path separately decides whether native output is "effectively empty". |
| low-signal status | no explicit model field | Only implicit through convert-stage fallback predicate. |

### Page-level

| Signal | Current status | Notes |
| --- | --- | --- |
| `page_index` | present | Populated. |
| `page_label` | model field exists | Currently `None`. |
| page geometry | present | `media_box`, `crop_box`, `rotation`; `user_unit` exists but is currently `None`. |
| `text_blocks` | present | Main text structure consumed by converter. |
| `images` | present | Includes bbox, payload, source refs, and object refs. |
| `annotations` | present | Includes URI/dest when available. |
| `vectors` | model field exists | Currently empty. |
| `forms` | model field exists | Currently empty. |
| `reading_order_candidates` | model field exists | Currently empty. |
| `artifact_candidates` | model field exists | Currently empty. |
| `raw_content_stream_refs` | present | Good provenance/debug signal; currently not consumed by converter. |
| page stats/debug info | debug only | Available through block-debug summary, not a structured public stats model. |

### Text-level

| Signal | Current status | Notes |
| --- | --- | --- |
| text blocks | present | Includes bbox, dominant font, writing direction, candidate flags, source refs. |
| text lines | present | Includes bbox, baseline, line height, indents, gaps, paragraph-wrap candidates. |
| text spans | present | Includes font family/size, style flags, scaling, spacing, language hints, chars, source refs. |
| chars | present | Includes unicode/raw bytes/decoded text, bbox/origin/quad, glyph widths, font info, ligature and compat-glyph flags, decode confidence. |
| heading candidate | present | Block-level flag from `doc_parse/pdf`. |
| page number candidate | present | Block-level flag from `doc_parse/pdf`. |
| header/footer candidate | present | Block-level flag from `doc_parse/pdf`. |
| table-cell candidate | present | Block-level flag from `doc_parse/pdf`. |
| caption candidate | present | Block-level flag from `doc_parse/pdf`. |
| source refs | present | Chars/spans/lines/blocks all have source refs. |
| source op / stream refs | partial | Char/source refs are rich; page raw content stream refs are present; convert side does not preserve them. |

### Image-level

| Signal | Current status | Notes |
| --- | --- | --- |
| image object/id | present | Stable per-image id in page model. |
| payload bytes | present | JPEG/JP2/JBIG2/raw RGB payloads when extractable. |
| page index | present | Via page container. |
| bbox | present | Populated for inline/XObject/Form-XObject placement. |
| width/height | present | Pixel dimensions available. |
| object ref / provenance | present | Object refs and source refs are available. |
| alt text | present | Available when present in lower-layer extraction. |
| nearby caption candidate | no core field | Current caption pairing is convert-side only. |
| asset export relationship | no core field | Asset export is a convert concern today. |

### Annotation / link-level

| Signal | Current status | Notes |
| --- | --- | --- |
| raw annotation extraction | present | Page annotations are extracted from raw layer. |
| link URI | present | URI exposed on annotation model. |
| link dest / target page | present | Dest and target-page related data are exposed when available. |
| bbox | present | Required for page model inclusion. |
| page index | present | Via page container. |
| source refs | present | Included on annotation objects. |
| Markdown link emission | present, narrow | High-confidence single-line URI annotations only; internal/ambiguous/image-area cases remain conservative. |
| convert debug passthrough | present | Annotations appear in convert debug. |

### Debug / dump surfaces

Current debug/audit surfaces:

* `extract_document_summary`
  Compact document-level summary.
* `extract_document_block_debug`
  Detailed page/block/line/image/annotation dump with geometry and raw refs.
* `convert/pdf/pdf_debug.mbt`
  Convert-stage line/image/annotation/block dumps and repeated-edge inspection.

Current gaps:

* no dedicated standalone `pdf_check` command
* no public structured raw-op dump API
* no public page-inspect API beyond block-debug text
* CLI `pdf_extract_debug` / `pdf_dump_selected_raw` flags are wired through
  dispatcher/CLI but currently not consumed by `convert/pdf/pdf_parser.mbt`

## `convert/pdf` Consumption Audit

| Stage | Input from `doc_parse/pdf` | Current behavior | Missing consumed signals | Notes |
| --- | --- | --- | --- | --- |
| extract | full `PdfDocumentModel` | Thin bridge; maps core errors into app errors. | document flags, metadata, outlines are not acted on | Good boundary discipline; almost no heuristic work here. |
| lines | pages, blocks, lines, images, annotations, page boxes | Converts core text blocks into convert lines; exports page images; carries annotations into convert page state. | spans/chars/source refs/decode confidence/raw content stream refs are dropped; doc metadata unused | This stage already consumes more than just strings. |
| blocks | convert lines + convert images | Builds one-line starter blocks, initial page objects, and geometry anchors. | page-level reading-order/artifact candidates, annotation alignment, richer block grouping from core | Initial block kinds rely mostly on heading/page-number flags. |
| classify | block text, font, bbox, neighbor context, core candidate flags | Reclassifies heading/paragraph/noise. | char/span style detail, decode confidence, stronger page-region candidates | Heading logic is still mostly converter-local heuristic work. |
| noise | block text, bbox, page boxes, repeated edge patterns | Drops repeated header/footer/page-number-like content. | dedicated artifact/page-edge candidates from core, richer repeated-object provenance | Currently recomputes page-edge repetition at convert time. |
| merge | block text, bbox, font sizes, indent, gap, wrapped candidates | Only merges previous-page-last paragraph with current-page-first paragraph. | richer paragraph continuity signals, source refs, multi-block merge plans | Cross-page merge is conservative and narrow by design. |
| image/caption | page-local images + text blocks + bbox | Emits image blocks; nearby caption only when page has exactly one image. | multi-image caption pairing, caption candidates from core, image-text linkage beyond bbox | Current policy is intentionally narrow and page-local. |
| annotation/link | page annotations | Narrow URI-link emission is landed; debug/inspect still carries the broader raw model. | richer block/link anchoring, internal-link handling, broader provenance | High-value surface, still intentionally conservative. |
| to_ir | blocks + page object order + images | Emits headings, paragraphs, and images in page object order. | annotations, outlines, vectors, forms, table candidates, page labels | IR emission is still text-and-image focused. |
| metadata sidecar | source name, page number, block index, image object ref | Preserves lightweight page/block/image provenance. | line/run/source-op refs, annotation origins, raw content stream refs, richer page geometry origin | Provenance exists, but it is intentionally shallow. |
| debug | convert lines/images/annotations/blocks | Good human-readable inspection output. | raw-op view, structured machine-readable diagnostics, dedicated extract/raw scopes | `pipeline_debug` is the only effective public debug switch today. |

## PDF H2 Gap Matrix

| Area | Current behavior | Market expectation | Core gap? | Convert gap? | Suggested next action | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| Text extraction completeness | Good on text PDFs; model has rich char/span/line data; capability flags are only partly real | Stable text plus clear capability reporting | yes, partial | no | Audit adapter-populated vs placeholder fields and document capability status | P0 |
| Paragraph / hardwrap recovery | Existing hardwrap and cross-page merge guards are regression-backed | More consistent paragraph recovery on real documents | partial | yes | First validate line-gap/indent/font consistency from core, then tune convert merge/classify | P2 |
| Heading precision / levels | Works on current guards but still heuristic-heavy | Better precision with fewer short-sentence false positives | partial | yes | Use font/spacing/source context more systematically after core signal audit | P2 |
| Page noise / repeated header-footer | Current repeated-edge cleanup exists and is useful | More robust header/footer suppression across variants | yes | yes | Add page-edge/artifact candidates in core, then simplify converter heuristics | P1 -> P2 |
| Cross-page merge | Only previous-page-last to current-page-first paragraph merge | More reliable continuation detection without false joins | partial | yes | Add stronger continuity signals from core, keep merge conservative in convert | P2 |
| Multi-column / reading order | Only limited current ordering; negative guard exists | Better reading order on columnar layouts | yes | partial | Audit whether core should expose reading-order candidates before converter tries more reordering | P1 |
| Tables / weak table detection | No table semantics; only table-cell candidates exist | Conservative readable table recovery on simple text PDFs | yes | yes | First expose stronger cell/row/region signals, then try weak table lowering | P2 |
| Images / image provenance | Stronger than many lightweight pipelines already | Stable asset export, bbox, provenance, page linkage | partial | no | Expand image provenance/debug surfaces before caption or layout inference work | P1 |
| Image caption pairing | Single-image page-local bbox heuristic only | Better caption pairing on common figure layouts | partial | yes | Keep narrow policy; only widen after core exposes stronger image/text neighborhood signal | P2 |
| PDF annotations / links | Extracted into core and convert debug, not emitted | URI links should usually surface in output | yes, partly | yes | Strengthen link model and define conservative Markdown emission rules | P1 -> P2 |
| Outlines / bookmarks | Model field exists but is empty | Bookmark/tree access for navigation-aware conversion | yes | no | Keep as explicit core gap until a safe lower-layer outline model exists | P1 |
| Document metadata | Basic metadata exists in core but is lightly used | Stable document metadata with capability visibility | partial | partial | Decide what PDF metadata should consistently surface in sidecar/debug | P1 |
| Page geometry / origin metadata | Page/block/image origin exists; geometry-rich provenance stays internal | Better auditability for page/block/image decisions | yes | yes | Preserve selected source refs and page geometry hints into debug/sidecar | P1 |
| CJK / ligature / unicode normalization | Char model has decode confidence, ligature, compat glyph info; converter largely ignores it | Better auditability and safer normalization choices | yes | partial | Add debug/sample coverage and clarify when converter should trust or preserve raw text | P1 |
| Scanned PDF / OCR fallback | OCR exists only as explicit or auto-fallback path | Optional fallback, not default fast path | no | no | Keep as documented limitation; do not move OCR into default chain | P3 non-goal |
| Encrypted / object stream / xref stream support | `is_encrypted` exists; xref/object-stream flags are currently placeholder-like | Clear capability reporting and graceful unsupported handling | yes | no | Audit actual backend support and report capability honestly before feature claims | P1 |
| Large PDF performance | No dedicated core-vs-convert split benchmark; smoke only covers one easy text case | Profiled small/medium/large text/image/noise cases | yes, for visibility | yes | Add core-only and full-pipeline benchmark tiers after audit cleanup | P2 / H3 |
| Debug / inspect / auditability | Summary and block-debug exist; raw/extract CLI scopes are thin | Easy root-cause debugging for layout mistakes | yes | partial | Add better public dump surfaces before more heuristic tuning | P1 |

## Core-first Priority List

### P0: Must clarify before implementation

These are the minimum audit items that should be settled before new PDF H2
coding starts:

* confirm which `PdfDocumentModel` fields are genuinely populated today and
  which are still placeholders
* confirm which `doc_parse/pdf` signals `convert/pdf` already uses well and which it
  discards
* confirm whether current regression pain is mostly core-signal loss or
  converter-policy weakness
* confirm current sample and benchmark coverage so new work lands against the
  right guards

Why this is first:

* PDF already has more lower-layer signal than a naive text extractor
* without this audit, more heading/noise/merge rules would risk duplicating or
  misusing information that already exists in `doc_parse/pdf`

### P1: Core signal upgrades

These are the highest-value lower-layer upgrades for H2:

* make block/line/span/char surfaces easier to trust and inspect
* improve bbox / baseline / line-gap / indent consistency where needed
* preserve and expose source refs more usefully
* add page-edge / artifact / repeated-region candidates
* strengthen annotation/link, outline, and image provenance surfaces
* improve debug and dump visibility

Why this comes before converter tuning:

* heading, noise, cross-page merge, and links are only as good as the signal
  they consume
* if the model is under-specified, converter rules become fragile and opaque

### P2: Convert quality upgrades

Once P1 signal is trustworthy, convert-side H2 work should focus on:

* heading precision and heading-level assignment
* repeated header/footer cleanup with less local guesswork
* cross-page paragraph merge quality
* conservative image-caption pairing
* annotation/link Markdown emission
* weak table detection on simple text PDFs

Why this is second:

* these are directly user-visible quality wins
* they are best implemented after the lower layer tells the converter more
  clearly what is text structure vs artifact vs annotation vs image context

### P3: Advanced or non-goal for now

These items should stay later or explicitly out of scope for the near term:

* full multi-column reading-order engine
* full table extraction
* OCR in the default fast path
* visual/LLM layout understanding
* full encrypted/object-stream/xref-stream support promise
* full tagged-PDF semantic tree reconstruction

Why these are later:

* they are large projects in their own right
* they should not block the next practical H2 pass for text-oriented PDFs

## PDF Regression / Sample Inventory

### Basic text / hardwrap

| Sample | Exists | Current use | Current status |
| --- | --- | --- | --- |
| `text_simple` | yes | main-process baseline, smoke benchmark, compare baseline | stable simple text guard |
| `text_multipage` | yes | main-process regression | stable multi-page baseline |
| `text_hardwrap` | yes | main-process regression | stable hardwrap guard |
| `hardwrap_en` | yes | main-process regression, `doc_parse/pdf` test coverage | stable H2 guard |
| `hardwrap_zh` | yes | main-process regression, `doc_parse/pdf` test coverage | stable H2 guard |
| `not_heading_sentence` | yes | main-process regression | stable false-positive guard |

### Heading precision

| Sample | Exists | Current use | Current status |
| --- | --- | --- | --- |
| `heading_basic` | yes | main-process regression | stable baseline |
| `pdf_heading_vs_short_sentence` | yes | main-process regression | stable H2 guard |
| `pdf_heading_false_positive_phase15` | yes | main-process regression | stable H2 guard |

### Noise / repeated header-footer

| Sample | Exists | Current use | Current status |
| --- | --- | --- | --- |
| `pdf_page_noise_cleanup` | yes | main-process regression | stable guard |
| `pdf_repeated_header_footer` | yes | main-process regression | stable baseline |
| `pdf_repeated_header_footer_variants` | yes | main-process regression, extended benchmark | high-value H2 guard |
| `pdf_header_footer_variants_phase15` | yes | main-process regression | stable guard |

### Cross-page

| Sample | Exists | Current use | Current status |
| --- | --- | --- | --- |
| `pdf_cross_page_paragraph` | yes | main-process regression | stable baseline |
| `pdf_cross_page_should_merge_phase15` | yes | main-process regression | high-value H2 guard |
| `pdf_cross_page_should_not_merge_phase15` | yes | main-process regression | high-value H2 guard |

### Layout negative

| Sample | Exists | Current use | Current status |
| --- | --- | --- | --- |
| `pdf_two_column_negative_phase15` | yes | main-process regression | useful negative guard; no positive multi-column H2 corpus yet |

### Image / annotation

| Sample group | Exists | Current use | Current status |
| --- | --- | --- | --- |
| PDF image provenance samples | yes | `samples/assets/pdf/*`, metadata/origin tests | stable image-provenance guard |
| PDF image caption samples | yes | `samples/metadata/pdf/*`, metadata/origin tests | stable narrow caption guard |
| PDF annotation/link debug samples | partial | generated in `doc_parse/pdf/api/test/pdf_api_test.mbt` | useful lower-layer test, but no checked-in main-process/compare guard yet |

### Benchmark inventory

| Inventory item | Current state | Audit note |
| --- | --- | --- |
| smoke benchmark | `text_simple` only | too narrow for PDF H2/H3 |
| image tier | `pdf_image_single_caption_like_img` | useful image export check, not a speed-profile set |
| extended tier | `pdf_repeated_header_footer_variants_ext` | useful regression guard, not enough for H3 |
| comparison corpus | `text_simple_compare` only | overlap exists, but scope is too narrow |

### Inventory conclusions

Already stable and useful as H2 guards:

* hardwrap samples
* heading false-positive samples
* repeated header/footer samples
* cross-page merge positive/negative samples
* image provenance and single-caption-vs-no-caption samples

Current known gaps in coverage:

* no checked-in annotation-to-Markdown output sample
* no checked-in outlines/bookmarks sample
* no table-like PDF H2 corpus
* no positive multi-column corpus with clearly documented current behavior
* no benchmark split for text vs image-heavy vs noisy vs multi-page PDFs

Samples that should stay high-priority H2 guards:

* `hardwrap_en`
* `hardwrap_zh`
* `not_heading_sentence`
* `pdf_heading_vs_short_sentence`
* `pdf_heading_false_positive_phase15`
* `pdf_repeated_header_footer_variants`
* `pdf_cross_page_should_merge_phase15`
* `pdf_cross_page_should_not_merge_phase15`
* `pdf_two_column_negative_phase15`

## Benchmark / Comparison Audit

### Current benchmark coverage

Current PDF entries in `samples/benchmark/corpus.tsv` are:

* smoke: `text_simple`
* image tier: `pdf_image_single_caption_like_img`
* extended: `pdf_repeated_header_footer_variants_ext`

Current PDF entry in `samples/benchmark/compare_corpus.tsv` is:

* `text_simple_compare`

### Audit answers

1. Current PDF smoke benchmark covers only `text_simple`.
2. The repository has `smoke`, `image`, `metadata`, and `extended` tiers, but
   it does not currently split PDF into native-core-only vs full-convert vs
   external-compare tiers.
3. Yes, there is a PDF MarkItDown comparison, but only for `text_simple`.
4. The comparison is fair in runner setup after the prebuilt-native CLI change,
   but it is not yet fair in semantic scope because it measures only one easy
   text PDF.
5. Yes, PDF benchmark should eventually split at least into:
   * text PDF
   * image-heavy PDF
   * multi-page PDF
   * table-like PDF
   * noisy/repeated-header-footer PDF
6. PDF H3 performance leadership will need:
   * a broader smoke corpus
   * batch cases
   * large-document cases
   * core-only extraction timing
   * full native-pipeline timing
   * overlap-only comparison on several PDF profiles, not just easy text

### H3 benchmark recommendations

Recommended future PDF benchmark structure:

* native-core smoke
  Focus on `doc_parse/pdf` extraction/model cost only.
* full native convert smoke
  Focus on current default path end-to-end cost.
* profile tiers
  Separate text-only, image-heavy, noisy, multi-page, and table-like samples.
* overlap-only comparison
  Keep it narrow and honest, but widen beyond a single easy sample.

## Recommended Next Implementation Sequence

1. `doc_parse/pdf` model audit cleanup: make page/text/image/annotation/source-ref
   field coverage explicit and trustworthy.
2. `doc_parse/pdf` debug dump improvements: expose page blocks/lines/spans/images/
   annotations more directly and make raw/extract debug surfaces usable.
3. Heading/noise/cross-page regression attribution: classify which current
   misses are core-signal problems and which are convert-policy problems.
4. P1 core signal upgrade: page-edge candidate signal, line-gap/bbox
   consistency, source refs, annotation/link/outlines visibility.
5. P2 convert quality upgrade: heading precision, repeated edge noise cleanup,
   cross-page merge.
6. Image/annotation/link pass: caption pairing policy and conservative Markdown
   link emission policy.
7. PDF benchmark/comparison refresh: broaden smoke and overlap profiles only
   after the signal and quality plan above is in place.

## Non-goals for Now

* continue piling heading/noise/cross-page heuristics without first auditing
  `doc_parse/pdf`
* make OCR the default fast path
* add LLM or vision as the default PDF path
* implement a full visual layout engine
* promise full table extraction or full multi-column reading-order recovery in
  the next short pass
* promise full encrypted/object-stream/xref-stream support before backend and
  capability reporting are audited
