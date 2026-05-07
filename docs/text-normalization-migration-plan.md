# Text Normalization Migration Plan

This document records the P2 audit for scattered PDF text cleanup logic.

Scope of this round:

* audit only
* no converter/parser/emitter output changes
* no migration of PDF layout heuristics into shared cleanup yet
* no default enablement of NFC/NFKC

Current implementation status after P2 and P3.1:

* low-risk PDF character cleanup has been moved into
  `core/text_normalization`
* `doc_parse/pdf/text/normalize_texts.mbt` now calls
  `normalize_pdf_text_cleanup` before PDF-specific post-processing
* canonical normalization facade APIs exist, but remain explicit-only
* default converter behavior still does not enable NFC/NFKC

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
* other formats such as DOCX, HTML, TXT, and Markdown should adopt shared
  cleanup through `core/text_normalization`, not by inventing format-local
  Unicode cleanup stacks

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

Cross-format adoption rule:

* DOCX, HTML, TXT, and Markdown may gradually adopt
  `normalize_document_text_cleanup` when they want conservative shared cleanup
* PDF should continue using `normalize_pdf_text_cleanup` before its own
  format-specific post-processing
* no converter or parser package should directly import
  `tonyfettes/unicode`; canonical normalization must stay behind the
  `core/text_normalization` facade

## Non-PDF Format Audit

This section audits non-PDF formats for scattered text cleanup logic and
classifies which parts may eventually adopt
`normalize_document_text_cleanup`.

### Summary by format

#### DOCX

Relevant files:

* [`convert/docx/docx_document.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_document.mbt:1)
* [`convert/docx/docx_table.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_table.mbt:364)

Current cleanup:

* ad hoc CRLF normalization inside `text_is_code_like`
* frequent `trim_ascii_spaces` / `trim_string`
* paragraph, run, list, and table assembly is structure-driven

Recommendation:

* do not attach `normalize_document_text_cleanup` at raw run or paragraph
  boundaries yet
* document cleanup may be useful later for carefully chosen plain-text payloads,
  but DOCX run/paragraph/tab semantics must stay local

Risk:

* DOCX tabs, run boundaries, list spacing, code-like detection, and table cell
  newlines are format semantics rather than generic cleanup

#### PPTX

Relevant files:

* [`convert/pptx/pptx_bytes.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_bytes.mbt:108)
* [`convert/pptx/pptx_text.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_text.mbt:1)
* [`convert/pptx/pptx_slide.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_slide.mbt:85)
* [`convert/pptx/pptx_noise.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_noise.mbt:173)
* [`convert/pptx/pptx_reading_order.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_reading_order.mbt:24)

Current cleanup:

* `normalize_slide_text` trims and collapses spaces/tabs/newlines to one space
* shape text and title text are normalized before reading-order and noise
  decisions

Recommendation:

* do not replace `normalize_slide_text` with shared cleanup wholesale
* only the lowest-risk character cleanup might be reusable later, but current
  space collapsing is tightly coupled to slide shape semantics

Risk:

* shape reading order, title merging, bullet handling, and noise detection are
  PPTX-specific semantics

#### XLSX

Relevant files:

* [`convert/xlsx/xlsx_sheet.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/xlsx/xlsx_sheet.mbt:400)
* [`convert/xlsx/xlsx_datetime.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/xlsx/xlsx_datetime.mbt:85)

Current cleanup:

* heavy use of `trim_string` and `trim()` for cell value classification
* blank-row trimming, table-width normalization, boolean/error display shaping

Recommendation:

* do not apply `normalize_document_text_cleanup` to raw cell contents by
  default
* XLSX is mostly field-literal and table-structural; any future adoption should
  be narrow and opt-in

Risk:

* trimming and blank-cell detection affect table shape, semantic typing, and
  formula cache handling

#### HTML

Relevant files:

* [`convert/html/html_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/html/html_parser.mbt:20)
* [`convert/html/html_bytes.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/html/html_bytes.mbt:1)
* [`convert/html/html_dom.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/html/html_dom.mbt:1)

Current cleanup:

* input bytes strip UTF-8 BOM and normalize CRLF/CR
* `html_unescape` maps `&nbsp;` to space and decodes entities
* inline trimming is DOM-aware

Recommendation:

* HTML is a promising future adopter for some shared document cleanup, but only
  after DOM-level whitespace behavior is preserved carefully
* raw byte normalization should likely stay local

Risk:

* HTML whitespace collapse is DOM semantics, not generic text cleanup
* inline trimming around tags, paragraphs, `<pre>`, `<code>`, and figures must
  remain format-aware

#### TXT

Relevant files:

* [`convert/txt/txt_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/txt/txt_parser.mbt:47)

Current cleanup:

* strips UTF-8 BOM
* normalizes CRLF/CR to LF
* later trims lines and joins paragraphs

Recommendation:

* TXT is the strongest non-PDF candidate for future adoption of
  `normalize_document_text_cleanup`
* even here, paragraph joining and list/thematic-break heuristics must remain
  local

Risk:

* line-based paragraph grouping is TXT semantics and should not move into core

#### Markdown

Relevant files:

* [`convert/markdown/markdown_passthrough.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/markdown/markdown_passthrough.mbt:19)

Current cleanup:

* CRLF/CR normalized to LF
* block/fence scanning uses trimmed lines conservatively

Recommendation:

* do not route Markdown passthrough through `normalize_document_text_cleanup`
  by default
* Markdown is intentionally close to source-preserving behavior

Risk:

* extra cleanup could alter fenced blocks, blank-line structure, or passthrough
  expectations

#### CSV / TSV

Relevant files:

* [`convert/csv/csv_to_ir.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/csv/csv_to_ir.mbt:38)
* [`convert/csv/csv_to_ir.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/csv/csv_to_ir.mbt:185)

Current cleanup:

* shared `parse_delimited_file_with_profile_impl` handles both CSV and TSV
* strips UTF-8 BOM
* normalizes CRLF/CR to LF before parsing records

Recommendation:

* keep current normalization local for now
* do not apply general document cleanup to delimited field content by default

Risk:

* CSV/TSV fields are often literal data; Unicode-space cleanup, ligature
  expansion, or zero-width removal could change field values unexpectedly

#### JSON

Relevant files:

* [`convert/json/json_profile.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/json/json_profile.mbt:1)

Current cleanup:

* no meaningful document text cleanup found in converter path
* `trim()` use is mostly profile/log formatting

Recommendation:

* do not introduce shared document cleanup into JSON source rendering by
  default

Risk:

* JSON output is effectively source-structured data; literal preservation
  matters more than cleanup

#### YAML

Relevant files:

* [`convert/yaml/yaml_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/yaml/yaml_parser.mbt:374)

Current cleanup:

* strips UTF-8 BOM on first line
* normalizes CRLF/CR to LF
* rejects tabs for indentation
* trims and strips inline comments as part of YAML parsing

Recommendation:

* keep this logic local
* do not apply shared document cleanup to YAML source before parsing

Risk:

* indentation, comments, and scalar parsing are YAML semantics

#### XML

Relevant files:

* [`convert/xml/xml_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/xml/xml_parser.mbt:19)

Current cleanup:

* strips UTF-8 BOM
* normalizes CRLF/CR to LF
* otherwise keeps source for fenced code output

Recommendation:

* do not attach `normalize_document_text_cleanup` by default

Risk:

* XML is emitted as fenced source-like content; literal preservation matters

#### EPUB

Relevant files:

* [`convert/epub/epub_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/epub/epub_parser.mbt:533)
* [`convert/epub/epub_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/epub/epub_parser.mbt:1177)

Current cleanup:

* mostly archive/path normalization and trailing-newline trimming between merged
  entry markdown blocks
* text cleanup mainly inherited from inner format parsers such as HTML

Recommendation:

* EPUB itself should not add another cleanup layer at archive-merge time
* future adoption should happen in inner content formats, not in EPUB wrapper

Risk:

* EPUB path normalization and stitched-entry formatting are container semantics

#### ZIP

Relevant files:

* [`convert/zip/zip_to_ir.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/zip/zip_to_ir.mbt:771)
* [`convert/zip/zip_to_ir.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/zip/zip_to_ir.mbt:1316)
* [`convert/zip/zip_to_ir.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/zip/zip_to_ir.mbt:1653)

Current cleanup:

* mostly path normalization, HTML asset-src normalization, and trailing-newline
  trimming between stitched subdocuments

Recommendation:

* ZIP wrapper should not apply shared text cleanup at container level
* inner formats should own their own eventual adoption

Risk:

* archive path safety and subdocument stitching are not text-normalization
  concerns

### Classification

#### A. Low-risk candidates for future `normalize_document_text_cleanup`

Best candidates:

* TXT: current BOM + CRLF/CR handling suggests a natural future adoption point
* HTML: only after careful DOM-preserving integration, likely at text-node
  boundaries rather than raw bytes
* possibly selected DOCX/PPTX plain-text payloads later, but not at run/shape
  boundaries by default

Candidate low-risk transforms:

* CRLF/CR normalization
* NBSP / Unicode spaces
* zero-width cleanup
* soft hyphen cleanup
* common ligature cleanup

#### B. Format semantics that should not migrate

Do not migrate:

* DOCX paragraph/run/list/table spacing and code-like detection
* PPTX shape reading order, title/body merge, noise heuristics, and bullet
  behavior
* HTML DOM-aware whitespace trimming and entity/inline handling
* Markdown passthrough fence and blank-line behavior
* CSV/TSV field-literal parsing
* XLSX cell typing, blank-cell detection, and table-width normalization
* YAML indentation, inline comments, and scalar parsing
* XML fenced-source preservation
* EPUB/ZIP path normalization and stitched-entry formatting

#### C. Deferred migration items

Defer for now:

* generic `trim()` replacement across formats
* collapse-space behavior in PPTX and Markdown
* inline-run spacing in DOCX/PPTX/HTML
* table cell whitespace in DOCX/XLSX/CSV/TSV
* trailing-newline trimming in EPUB/ZIP stitched output

Reason:

* all of these can change expected markdown or metadata even when they look
  superficially like harmless cleanup

### Recommended P4 adoption order

1. TXT: easiest future pilot for `normalize_document_text_cleanup`
2. HTML: next best candidate, but only with DOM-aware regression coverage
3. selective DOCX/PPTX plain-text entry points if a truly text-only seam is
   found
4. leave Markdown, CSV/TSV, JSON, YAML, XML, EPUB wrapper, ZIP wrapper, and
   most XLSX paths unchanged by default

This gives the project a safer path to unify cleanup across PDF, DOCX, PPTX,
HTML, TXT, and Markdown without smuggling PDF layout semantics into a shared
normalization layer.
