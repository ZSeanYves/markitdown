# PDF H2++ Readiness Audit

This document is the repository's PDF H2++ readiness audit.

It is intentionally not a format-closure claim.

Current intended result:

* clarify the real native PDF path
* separate native text-PDF support from OCR and other optional paths
* record what is already evidenced today
* identify the blockers that must be closed before a real PDF H2++ sprint

Non-goal of this audit:

* no broad PDF converter rewrite
* no status inflation from `H2 partial` to `H2++`
* no OCR/cloud/vision story mixed into native local-performance claims

## 1. Current Architecture

The current default local PDF path is:

```text
normal/debug PDF CLI
-> convert/pdf.parse_pdf
-> doc_parse/pdf/api
-> doc_parse/pdf/raw + text + model
-> convert/pdf line/block/classify/noise/merge/link/table/caption stages
-> unified IR
-> Markdown / assets / metadata sidecar
```

Important path boundaries:

* the default `normal` path is native and local
* the native lower layer is `doc_parse/pdf` with vendored `vendor/mbtpdf`
* OCR is a separate explicit path through `ocr` or PDF mode forcing
* `ocr-auto` exists, but only as a conservative fallback when the native model
  is effectively empty
* OCR is not part of the default PDF support or H3++ performance story

Current routing facts:

* dispatcher sends `.pdf` to `convert/pdf.parse_pdf`
* `parse_pdf` only uses OCR when:
  * `pdf_mode == "ocr"` -> force OCR
  * `pdf_mode == "ocr-auto"` and native extraction is effectively empty
* there is no default `pdftotext`, `poppler`, or `mutool` text backend in the
  normal local path
* debug entrypoints are mostly PDF-specific and include extract/raw/pipeline
  style inspection

## 2. Current Capability Matrix

### 2.1 Native lower-layer capability

The current native lower layer already exposes more signal than the top-level
status labels imply.

Current `doc_parse/pdf` model includes:

* document version
* page count
* page boxes:
  * media box
  * crop box
  * rotation
* text chars / spans / lines / blocks
* source refs:
  * page index
  * source stream index
  * source op index
  * text object id
  * content-order index
  * source object ref
* text style hints:
  * font name
  * font family
  * font size
  * bold / italic / monospace hints
  * fill/stroke color
  * decode confidence
  * writing direction
* image objects:
  * bbox
  * image size
  * filter
  * colorspace
  * object ref
  * inline-image flag
  * payload when exportable
  * source refs
* annotation objects:
  * subtype
  * bbox
  * URI
  * internal destination raw string
  * object ref
  * contents / subject / color
* raw content-stream refs per page
* document flags:
  * encrypted
  * xref-stream
  * object-stream

Current lower-layer gaps:

* outlines/bookmarks are modeled but remain empty in the current path
* forms are modeled but not populated in the current path
* document metadata from raw extraction is still sparse:
  * `metadata_title`, `metadata_author`, etc. are currently not populated by
    the vendored adapter
* `has_xref_stream` and `has_object_stream` currently exist in the model, but
  the current `mbtpdf` adapter path still hardcodes them to `false`
* internal destination links are extracted as raw annotation `dest`, but not
  promoted to emitted Markdown links

### 2.2 Native convert-layer capability

The current convert pipeline is explicit and stage-oriented:

* line staging
* block staging
* heading classification
* noise filtering
* cross-page merge
* URI-link attachment
* table-like detection
* image-caption pairing
* final IR lowering

Current supported text-PDF behaviors:

* paragraphs
* heading promotion for high-confidence heading-like blocks
* false-positive heading guards
* hardwrap recovery
* shared Text Normalization v2 substrate for ligature / NBSP / unicode-space /
  zero-width / soft-hyphen / PDF compatibility-glyph cleanup on the native PDF
  path
* repeated header/footer and page-number cleanup
* cross-page paragraph merge
* cross-page merge negatives
* conservative two-column negative protection
* narrow high-confidence URI-link emission
* simple grid-like table recovery
* headerless numeric table recovery on a checked-in subset
* image asset export
* conservative caption-like pairing

Current convert-layer gaps:

* no outline/bookmark emission
* no internal-destination / GoTo link emission
* no multiline or ambiguous link emission
* no general table engine
* no full multi-column reading-order engine
* no complex-layout recovery contract
* no tagged-PDF semantic interpretation contract

### 2.3 Debug / inspect surface

Current debug/inspect support is strong enough to be treated as part of the
PDF product-readiness story.

Available lower-layer debug surfaces:

* `extract_document_summary`
* `extract_document_block_debug`
* `extract_document_inspect_dump`

Available convert-stage debug surfaces:

* line summaries
* image provenance
* annotation passthrough
* block summaries
* heading decisions
* noise decisions
* merge decisions
* table matches
* image-caption matches

This is one of the format's strongest current assets:

* many PDF heuristics are explainable today rather than hidden inside final
  Markdown output only
* text normalization is now centralized enough to document as a deterministic
  staged preprocessing subsystem rather than scattered one-off character fixes
* output text and comparison text now use distinct normalization profiles:
  `PdfText` for emitted text cleanup and `PdfCompareText` for heading/noise/
  table/caption/merge comparisons

Text Normalization v2 notes for the PDF path:

* character normalization is centralized in `core/text_normalization.mbt`
  rather than duplicated across `convert/pdf` heuristics
* `doc_parse/pdf/text/unicode_compat.mbt` is now a compatibility adapter into
  the shared substrate instead of a separate parallel character-normalization
  implementation
* canonical `NFC` / `NFKC` are not claimed as fully implemented PDF behavior
  today; the current MoonBit stdlib path does not expose a full Unicode
  normalization API for this repository, so the project currently ships a
  high-value subset with explicit warning hooks
* text normalization remains separate from OCR, reading-order recovery,
  paragraph merge policy, and table/layout classification

## 3. Existing Evidence

### 3.1 Main regression samples already present

Checked-in main-output PDF samples already cover:

* `text_simple.pdf`
* `text_multipage.pdf`
* `text_hardwrap.pdf`
* `hardwrap_en.pdf`
* `hardwrap_zh.pdf`
* `heading_basic.pdf`
* `not_heading_sentence.pdf`
* `pdf_heading_vs_short_sentence.pdf`
* `pdf_heading_false_positive_phase15.pdf`
* `pdf_page_noise_cleanup.pdf`
* `pdf_repeated_header_footer.pdf`
* `pdf_repeated_header_footer_variants.pdf`
* `pdf_header_footer_variants_phase15.pdf`
* `pdf_cross_page_paragraph.pdf`
* `pdf_cross_page_should_merge_phase15.pdf`
* `pdf_cross_page_should_not_merge_phase15.pdf`
* `pdf_two_column_negative_phase15.pdf`

This is already a meaningful text-PDF structure matrix:

* simple text
* multipage
* heading
* heading false-positive guards
* repeated header/footer cleanup
* cross-page merge and no-merge
* hardwrap
* two-column negative

### 3.2 Metadata / assets evidence already present

Current checked-in metadata/assets coverage is much thinner than the main
output corpus, but not empty.

Present today:

* `samples/main_process/pdf/metadata/pdf_image_single_caption_like.pdf`
* `samples/main_process/pdf/metadata/pdf_image_no_caption_negative.pdf`
* `samples/main_process/pdf/expected/metadata/pdf_image_single_caption_like.metadata.json`
* `samples/main_process/pdf/expected/metadata/pdf_image_single_caption_like.md`

Currently evidenced via fixtures:

* image asset export
* image `object_ref`
* nearby caption
* caption/no-caption boundary

### 3.3 Unit and whitebox evidence already present

The test surface is stronger than the status label suggests.

`convert/pdf/test/pdf_parse_test.mbt` already covers:

* URI-link emission
* internal-destination non-emission
* caption-positive and caption-negative image pairing
* simple aligned table lowering
* headerless numeric table lowering
* inspect-dump visibility for table signal

`doc_parse/pdf/api/test/pdf_api_test.mbt` already covers:

* raw/model annotation extraction for URI links
* raw/model extraction for internal destinations
* debug dump contains page refs, geometry, image info, annotation info
* inspect dump contains block/line/span/image/annotation source refs
* outlines currently remain empty as an explicit gap

`convert/pdf/*_wbtest.mbt` already covers:

* heading decision heuristics
* noise decision heuristics
* merge decision heuristics
* table/caption/link matching logic

### 3.4 Quality-comparison evidence already present

Current checked-in PDF quality record:

* `docs/quality-comparisons/pdf-heading-structure.md`

This record is useful but narrow:

* it supports a text-PDF heading/noise quality story
* it does not yet close table/link/caption/image/noise/merge quality evidence

### 3.5 Benchmark evidence already present

Current checked-in PDF benchmark rows already include:

Smoke:

* `pdf_text_simple`
* `pdf_text_multipage`
* `pdf_heading_basic`
* `pdf_heading_false_positive_guard`
* `pdf_repeated_header_footer`
* `pdf_repeated_header_footer_variants`
* `pdf_cross_page_merge`
* `pdf_cross_page_no_merge`
* `pdf_two_column_negative`

Image-tier smoke:

* `pdf_image_single_caption_like_img`

Compare rows:

* `text_simple_compare`
* `heading_basic_compare`
* `pdf_repeated_header_footer_compare`
* `pdf_cross_page_should_merge_compare`
* `pdf_cross_page_should_not_merge_compare`

Batch profile:

* PDF participates in batch profile defaults today

This is enough to say:

* native text-PDF benchmarking exists
* overlap compare exists for selected text-PDF rows

It is not enough to say:

* PDF H3++ is already evidenced end to end

## 4. Missing Evidence

The biggest PDF issue today is not "no capability at all".

It is:

* capability exists in code/tests
* but the checked-in evidence is uneven across main/metadata/quality/benchmark
* and the current status docs still compress too many different PDF stories
  into one partial label

Key missing evidence areas:

* metadata-on benchmark rows for PDF
* checked-in metadata fixtures beyond the image-caption slice
* checked-in quality records for:
  * repeated header/footer cleanup
  * cross-page merge
  * URI-link emission boundary
  * simple table-like recovery
  * caption-like image recovery
* explicit negative samples around:
  * ambiguous annotation links
  * two-column negative/noise interaction
  * table-like false positives
* explicit text-PDF vs OCR/scanned boundary docs in a single sprint artifact

## 5. H2++ Boundary Proposal

### 5.1 What should count toward PDF H2++

PDF H2++ should be defined narrowly and realistically around the native
text-PDF path.

Suggested in-scope contract:

* text-oriented PDF on the default local native path
* page model with source refs and geometry
* heading / paragraph structure on the checked-in subset
* repeated header/footer and page-number cleanup
* cross-page paragraph merge on high-confidence boundaries
* cross-page no-merge guards
* conservative two-column negative behavior
* narrow high-confidence URI-link emission
* simple high-confidence table-like recovery
* image asset export with provenance
* conservative caption-like pairing
* page/source/image/object provenance in metadata/debug
* rich debug/inspect explainability
* conservative omission for ambiguous structure

### 5.2 What should not block PDF H2++

These should stay outside the default H2++ blocker set:

* scanned-PDF OCR by default
* OCR-first support claims
* complete layout engine behavior
* perfect multi-column reading order
* general complex table extraction
* visual reconstruction
* cloud/LLM/vision understanding
* forms/XFA/signatures/javascript
* full PDF-spec coverage

### 5.3 H3++ boundary

If PDF reaches H2++, H3++ must still stay narrow:

* native default local path only
* text-PDF corpus only
* OCR excluded from the default H3++ story
* any external/manual/OCR benchmark path must be reported separately
* overlap comparison must stay limited to selected comparable text-PDF rows

## 6. Blocker List

### 6.1 P0 blockers

These must be clear before a real PDF H2++ sprint can close:

* separate native text-PDF, OCR, and any external/manual path language in one
  audit artifact
* confirm the default normal path remains native and local
* keep main-process text-PDF samples green
* keep metadata/assets contract stable on the existing image path
* preserve debug/inspect explainability as part of the product contract

Current judgement:

* these are mostly satisfied after this audit
* the remaining P0 work is documentation and sprint-scoping clarity, not a
  parser rewrite

### 6.2 P1 blockers

These are the best next sprint targets:

* text-PDF evidence closure across main + metadata + quality + benchmark
* URI annotation-link evidence closure
* image/caption metadata closure
* table-like evidence closure
* heading/noise/merge debug-to-quality traceability
* metadata fixture expansion beyond image-only coverage

### 6.3 P2 blockers

These are valuable, but not required for the first real H2++ closure:

* outline/bookmark support
* richer document metadata from the raw adapter
* `has_xref_stream` / `has_object_stream` population
* richer font/style and block provenance
* advanced table structures
* stronger multi-column/layout handling
* forms

### 6.4 Non-goals

These should remain explicit non-goals for the default PDF H2++ story:

* OCR default mainflow
* full scanned-PDF understanding without OCR
* full PDF layout engine
* cloud/LLM/vision paths
* complete table engine
* perfect reading order on complex multi-column or magazine-like layouts

## 7. Recommended Sprint Plan

### Sprint PDF-1: Text-PDF evidence closure

Goal:

* close the evidence gap for the already-existing native text-PDF path

Recommended scope:

* add regression/metadata/quality records for heading/noise/merge cases
* add metadata-on benchmark rows
* avoid major parser changes

Why first:

* the current code already has a real text-PDF story
* this is the smallest path to an honest H2++ decision

### Sprint PDF-2: Links / images / captions

Goal:

* close link/image/caption evidence for the current native path

Recommended scope:

* URI annotation-link evidence
* image asset provenance
* caption pairing evidence
* image-no-caption negative evidence

Why second:

* these are already partially implemented and test-backed
* they need checked-in closure more than new heuristics

### Sprint PDF-3: Layout heuristics hardening

Goal:

* strengthen the evidence and guardrails around current heuristics

Recommended scope:

* heading/noise/cross-page/two-column/table-like evidence chain
* more explicit debug/decision documentation

Why third:

* current weakness is not only parser signal but also incomplete checked-in
  evidence around the heuristic boundaries

### Sprint PDF-4: H3++ benchmark separation

Goal:

* make the performance story honest and scoped

Recommended scope:

* native text-PDF corpus
* metadata-on rows
* batch profile
* overlap compare for selected text-PDF rows
* OCR kept separate

Why fourth:

* H3++ claims for PDF are risky unless native, OCR, and external/manual paths
  remain clearly separated

## 8. Risks

Main risks for the PDF sprint:

* support inflation from strong text-PDF samples into blanket PDF claims
* accidental mixing of native, OCR, and optional/manual benchmark stories
* overreacting to layout quality gaps with emitter-level string patches
  instead of evidence-first hardening
* treating inspect/debug richness as if it already guarantees product-level H2++
  evidence closure

## 9. Recommended Status Wording Today

Current recommended wording after this audit:

* `PDF H2++ readiness audit complete`
* `next sprint will close text-PDF evidence and selected layout/link/image blockers`

Current wording that should still be avoided:

* `PDF H2++ complete`
* `PDF H3++ evidence-backed`
* any blanket statement about scanned PDFs, OCR, cloud, or vision paths
