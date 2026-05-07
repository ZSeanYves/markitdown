# Text Normalization Migration Plan

This document records the P2 audit for scattered PDF text cleanup logic.

Scope of this round:

* audit only
* no converter/parser/emitter output changes
* no migration of PDF layout heuristics into shared cleanup yet
* no default enablement of NFC/NFKC

## Goal

The repository already has a project-level text normalization facade in
[`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1).

The next migration step is not to add more ad hoc PDF cleanup. It is to move
reusable character-level cleanup toward that shared facade while preserving a
clean layering split:

* PDF decode stays in `vendor/mbtpdf` and the PDF raw adapter
* cross-format text cleanup stays in `core/text_normalization`
* PDF layout and structure heuristics stay in PDF-specific layers

## Current Scatter Points

### 1. PDF decode layer

These files are correctly PDF-specific and should remain outside the shared
cleanup facade:

* [`vendor/mbtpdf/font/pdfcmap/pdfcmap.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdfcmap/pdfcmap.mbt:1)
* [`vendor/mbtpdf/font/pdffont/encoding.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdffont/encoding.mbt:1)
* [`vendor/mbtpdf/font/pdfglyphlist/pdfglyphlist.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdfglyphlist/pdfglyphlist.mbt:1)
* [`vendor/mbtpdf/text/pdftext/read.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/text/pdftext/read.mbt:1)
* [`vendor/mbtpdf/text/pdftext/extract.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/text/pdftext/extract.mbt:1)
* [`doc_parse/pdf/raw/mbtpdf_text_adapter.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/raw/mbtpdf_text_adapter.mbt:1)

Responsibilities:

* `ToUnicode`
* CMap parsing
* font encoding
* glyph-name mapping
* PDFDocEncoding and raw string decode
* backend extraction and source tracking

These are decode responsibilities, not document cleanup responsibilities.

### 2. Shared cleanup already routed through core facade

These files already use the shared text layer and are the strongest evidence
that migration should continue toward `core/text_normalization` rather than
back into PDF internals:

* [`doc_parse/pdf/text/unicode_compat.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/unicode_compat.mbt:15)
* [`convert/pdf/pdf_text_compare.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_text_compare.mbt:2)
* [`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1)

Current shared cleanup that is already centralized:

* line ending normalization
* NBSP cleanup
* Unicode space cleanup
* zero-width cleanup
* soft hyphen cleanup
* ligature expansion
* PDF compare whitespace cleanup
* optional fullwidth and canonical normalization support through the facade

### 3. PDF lower-layer text normalization and recovery

The main scatter point is here:

* [`doc_parse/pdf/text/normalize_texts.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/normalize_texts.mbt:419)

Important functions:

* `normalize_text`
* `normalize_basic_spaces`
* `normalize_post_text`
* `strip_trailing_slash_page_artifact`
* `fix_hyphenated_english_wrap`
* `fix_common_split_english_words`
* `remove_spaces_between_cjk`
* `normalize_ascii_punct_spacing`
* `normalize_bullet_marker_spacing`
* `normalize_numbered_marker_spacing`

This file currently mixes two kinds of work:

* character-level cleanup that could be shared later
* PDF-specific line/span recovery heuristics that should remain PDF-local

### 4. PDF layout glue and line merge heuristics

These files are strongly layout-aware:

* [`doc_parse/pdf/model/pdf_text_model.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/model/pdf_text_model.mbt:157)
* [`doc_parse/pdf/text/rule.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/rule.mbt:47)
* [`doc_parse/pdf/text/pdf_text_lines.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/pdf_text_lines.mbt:1)
* [`doc_parse/pdf/text/pdf_text_blocks.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/pdf_text_blocks.mbt:1)

Important functions:

* `glue_between_spans`
* `should_merge_hyphenated_word_piece`
* `should_insert_space_after_bullet_marker`
* `should_insert_space_after_numbered_marker`
* `should_glue_english_word_piece`
* `should_join_same_line`
* `should_merge_lines`
* `looks_like_broken_english_word_pair`
* `looks_like_cjk_continuation_pair`
* `should_merge_short_fragment_pair`
* `looks_like_heading_line`
* `looks_like_body_line`
* `is_page_number_candidate`

These rules depend on span boundaries, source op proximity, line geometry,
paragraph continuity, or heading/body classification. They are not generic
cleanup.

### 5. PDF convert-stage comparison and semantic heuristics

These files mostly consume normalized compare text, but their decisions remain
PDF-specific:

* [`convert/pdf/pdf_noise.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_noise.mbt:170)
* [`convert/pdf/pdf_noise_decision.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_noise_decision.mbt:1)
* [`convert/pdf/pdf_merge.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_merge.mbt:1)
* [`convert/pdf/pdf_merge_decision.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_merge_decision.mbt:46)
* [`convert/pdf/pdf_heading_decision.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_heading_decision.mbt:52)
* [`convert/pdf/pdf_image_caption.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_image_caption.mbt:61)
* [`convert/pdf/pdf_table_detect.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_table_detect.mbt:22)

Important text helpers here:

* `normalize_pdf_comparison_text`
* `lowercase_pdf_comparison_text`
* `normalize_noise_key`
* `count_words`
* `ends_like_sentence`
* `is_probable_page_number_like`
* `looks_like_page_start_continuation`
* `looks_like_image_caption_prefix`

These are mainly consumers of normalized text, not the right place for new
shared cleanup logic.

## Three-Layer Responsibility Split

### A. PDF decode layer

Owner:

* `vendor/mbtpdf`
* `doc_parse/pdf/raw`

Responsibility:

* `ToUnicode`
* CMap
* font encoding
* glyph mapping
* PDFDocEncoding
* raw byte-to-text decode

Migration rule:

* do not move cross-format cleanup into this layer

### B. Project text cleanup layer

Owner:

* [`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1)

Responsibility:

* NBSP
* Unicode spaces
* CRLF normalization
* zero-width removal
* soft hyphen removal
* ligature expansion
* optional fullwidth cleanup
* optional canonical normalization via explicit facade API
* compare-profile whitespace cleanup where the rule is format-agnostic

Migration rule:

* only move text-only cleanup that does not need PDF geometry or reading-order
  context

### C. PDF convert/layout layer

Owner:

* `doc_parse/pdf/text`
* `doc_parse/pdf/model`
* `convert/pdf`

Responsibility:

* span glue
* line merge
* paragraph merge
* hyphen line break repair when it depends on adjacent spans or lines
* heading cleanup
* noise filtering
* image caption heuristics
* table detection
* page-number and repeated header/footer decisions
* CJK-Latin spacing decisions when tied to PDF span adjacency or layout

Migration rule:

* do not move layout or structure semantics into shared cleanup

## Migration Candidates

These are the best candidates for later migration into the shared text facade
or for refactoring to call it more directly.

### P3 candidate set A: low-risk character cleanup

Candidate rules:

* `normalize_basic_spaces` in
  [`doc_parse/pdf/text/normalize_texts.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/normalize_texts.mbt:426)
* duplicate space-like collapsing that is purely character-based
* compare-profile whitespace collapse that is not geometry-aware

Reason:

* these rules are text-only
* the same cleanup is potentially useful for HTML, OOXML, TXT, and Markdown
* some of this functionality already exists in `core/text_normalization`

Migration caution:

* do not silently replace PDF-local spacing behavior without regression tests,
  because trimming and collapsing order can still affect heuristics

### P3 candidate set B: reusable PDF-text cleanup profile behavior

Candidate rules:

* `remove_spaces_between_cjk`
* portions of `normalize_ascii_punct_spacing`
* portions of `normalize_noise_key`

Reason:

* these are text-level transforms or compare-key helpers
* they may be useful outside PDF if exposed as opt-in profile behavior

Migration caution:

* `remove_spaces_between_cjk` should not become a default global rule
* it belongs behind an explicit profile or option because it can change output

### P3 candidate set C: slash and artifact micro-cleanup

Candidate rules:

* `strip_trailing_slash_page_artifact`

Reason:

* it is text-only in implementation

Migration caution:

* despite being text-only, it is semantically PDF-specific and looks closer to
  artifact filtering than generic cleanup
* likely better to keep as a PDF profile hook or PDF-specific post-step rather
  than a general shared default

## Non-Migration Items

These should stay out of the shared facade.

### 1. Span and line glue

Do not migrate:

* `glue_between_spans`
* `should_glue_english_word_piece`
* `should_insert_space_after_bullet_marker`
* `should_insert_space_after_numbered_marker`

Reason:

* they depend on adjacent span boundaries and reconstructed PDF runs

### 2. Layout-aware hyphen and fragment repair

Do not migrate:

* `should_merge_hyphenated_word_piece`
* `looks_like_broken_english_word_pair`
* `should_merge_short_fragment_pair`
* `should_join_same_line`
* `should_merge_lines`

Reason:

* these depend on source-op distance, line layout, paragraph continuity, and
  block recovery

### 3. Structural PDF heuristics

Do not migrate:

* heading classification
* repeated edge noise detection
* cross-page merge decisions
* image caption detection
* table detection
* page-number heuristics tied to page position

Reason:

* these are document-structure policies, not text normalization

### 4. Decode internals

Do not migrate:

* `ToUnicode`
* CMap
* font encoding
* glyph mapping
* PDFDocEncoding

Reason:

* these belong to the PDF backend boundary

## Risk Notes

### 1. Cleanup order can change heuristics

Even when two rules look equivalent, moving them earlier or later can alter:

* heading detection
* noise filtering
* table rejection
* line merge confidence

### 2. Shared cleanup can accidentally become output policy

Some PDF-only rules are tempting to centralize because they operate on plain
strings, but they still encode PDF artifact assumptions. A shared facade should
not grow hidden PDF semantics.

### 3. Compare-text and emitted-text must stay separate

`NormalizeProfile::PdfCompareText` is intentionally stronger than the default
text profiles. Migration should preserve that distinction and avoid leaking
compare cleanup into emitted document text.

### 4. Canonical normalization remains opt-in

The facade now has standard Unicode normalization entry points, but they still
must not be enabled by default for existing converters until conformance and
format-specific risks are better understood.

## Recommended P3 Order

### Phase 1

Audit and extract the lowest-risk text-only helpers from
`doc_parse/pdf/text/normalize_texts.mbt` into clearly named shared internal
helpers, without changing profile defaults.

Priority targets:

* basic space collapsing rules that overlap with shared whitespace handling
* reusable compare-key helpers that are not geometry-aware

P3.1 status:

* completed for the lowest-risk character cleanup path
* shared facade now owns CRLF/CR normalization, NBSP and common Unicode-space
  mapping, zero-width cleanup, soft hyphen cleanup, common ligature expansion,
  and space-like run collapsing
* PDF lower-layer `normalize_texts.mbt` now reuses shared char-level cleanup
  before running PDF-specific post-processing
* no CJK spacing migration was done in P3.1
* no ASCII punctuation spacing migration was done in P3.1
* no layout, span, page, or structural heuristic was moved

### Phase 2

Refactor PDF-local callers to use the shared helpers or facade profile options,
while keeping PDF-specific post-processing local.

Priority targets:

* `normalize_basic_spaces`
* compare-key normalization used by noise and merge heuristics

### Phase 3

Re-evaluate whether selected opt-in rules should become profile options in
`core/text_normalization`, rather than local PDF functions.

Possible opt-in rules:

* remove spaces between CJK in compare-oriented profiles
* limited punctuation spacing cleanup

### Phase 4

Only after the shared profile boundary is stable, consider whether any
non-default canonical normalization should be wired into future format-specific
cleanup flows.

Not part of P3:

* no movement of line merge logic
* no movement of paragraph recovery logic
* no movement of heading or table semantics
* no default output change

## Current Recommendation

Recommended direction:

* keep `vendor/mbtpdf` focused on decode
* keep `core/text_normalization` as the only shared text cleanup facade
* migrate only text-only cleanup into shared helpers
* keep all geometry-aware and structure-aware heuristics in PDF-specific code
* continue treating canonical normalization as opt-in until conformance work is
  added

This gives the project a safer path to unify cleanup across PDF, DOCX, PPTX,
HTML, TXT, and Markdown without smuggling PDF layout semantics into a shared
normalization layer.
