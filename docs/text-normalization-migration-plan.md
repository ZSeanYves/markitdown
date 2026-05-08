# Text Normalization Migration Plan

This document records the staged migration plan for shared text normalization
and cleanup.

Scope of this document:

* record completed migration phases and remaining gaps
* keep converter/parser/emitter behavior changes out of planning-only rounds
* keep PDF layout heuristics out of shared cleanup
* keep canonical normalization explicit-only by default

Current implementation status after P13:

* low-risk PDF character cleanup has been moved into
  `core/text_normalization`
* `doc_parse/pdf/text/normalize_texts.mbt` now calls
  `normalize_pdf_text_cleanup` before PDF-specific post-processing
* TXT now routes its shared low-risk character cleanup through
  `normalize_document_text_cleanup`
* HTML now routes normal text nodes through
  `normalize_document_text_cleanup` at the text-inline seam
* DOCX now routes only `scan_docx_inline_text` `w:t` plain-text payloads
  through `normalize_document_text_cleanup`
* PPTX now routes only `extract_text_runs` `<a:t>` plain-text payloads
  through `normalize_document_text_cleanup`
* canonical normalization facade APIs exist, but remain explicit-only
* `tonyfettes/unicode` is wired behind the facade for explicit
  `NFD/NFC/NFKD/NFKC` calls
* default converter behavior still does not enable `NFD/NFC/NFKD/NFKC`

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
* possibly selected non-OOXML literal-safe seams later, but not at
  structure-sensitive boundaries by default

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

### Current format status

Already using shared text cleanup:

* PDF: `normalize_pdf_text_cleanup` for low-risk character cleanup before
  PDF-specific post-processing
* TXT: `normalize_document_text_cleanup` at the text-file normalization entry
* HTML: `normalize_document_text_cleanup` only for normal text nodes after
  unescape and before IR text inlines
* DOCX: `normalize_document_text_cleanup` only for `scan_docx_inline_text`
  `w:t` plain-text payloads
* PPTX: `normalize_document_text_cleanup` only for `extract_text_runs`
  `<a:t>` plain-text payloads on the normal inline path

Not yet migrated:

* XLSX
* Markdown
* CSV
* TSV
* JSON
* YAML
* XML
* EPUB
* ZIP

### Why remaining formats stay deferred

DOCX is only partially adopted because:

* only the `w:t` plain-text seam is shared today
* run boundaries, paragraph assembly, tabs, lists, hyperlink assembly,
  code-like detection, and table/header-footer/textbox policy still remain
  DOCX-local semantics

PPTX is only partially adopted because:

* only the `<a:t>` plain-text seam in `extract_text_runs` is shared today
* fallback accumulation, `<a:br>`, hyperlink assembly, shape-level link
  fallback, `normalize_slide_text`, title/body merge, reading order, bullets,
  noise/grouping, explicit table policy, notes, hidden slides, and image
  metadata all remain PPTX-local semantics

### Recommended next candidates

1. canonical normalization conformance follow-up
2. only after a new clean seam is proven, a narrow follow-up on another
   format-specific text-only boundary
3. widen OOXML adoption only after fixture-stable coverage proves the seam

The current staged result is a safer shared-cleanup path across PDF, TXT,
HTML, DOCX, and PPTX without smuggling PDF layout semantics or OOXML document
semantics into the core normalization layer.

## DOCX Text-Only Seam Audit

This section records the P8 audit and P9 narrow pilot for DOCX adoption of
shared document-text cleanup.

Audit scope:

* audit only
* no DOCX converter/parser/emitter output changes
* no direct `tonyfettes/unicode` dependency from DOCX packages
* no default canonical normalization enablement

### Audited files and functions

Primary files:

* [`convert/docx/docx_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_parser.mbt:1)
* [`convert/docx/docx_document.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_document.mbt:1)
* [`convert/docx/docx_table.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_table.mbt:1)
* [`convert/docx/docx_xml.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_xml.mbt:342)
* [`convert/docx/docx_package.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_package.mbt:1)
* [`convert/docx/docx_rels.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_rels.mbt:1)

Key functions and flows:

* `parse_docx_impl`
* `scan_document`
* `scan_paragraph`
* `scan_docx_inline_text`
* `collect_tc_text_with_relationships`
* `collect_tc_paragraph_text`
* `render_docx_inline_markdown`
* `collect_wt_text`
* `collect_docx_paragraph_texts`
* `render_docx_part_text_for_header_footer`
* `render_docx_header_footer_paragraph_text`
* `paragraph_is_codeblock`
* `text_is_code_like`
* `read_docx_image_context`
* `normalize_optional_docx_image_attr`
* `collect_docx_text_boxes_from_xml`

### Current DOCX text assembly shape

Observed structure:

* `w:t` text is XML-unescaped and converted into `Inline::Text` in
  `scan_docx_inline_text`
* `w:br` becomes `Inline::Break` and contributes `\n` to the fallback text
* `w:tab` becomes literal `\t`
* `w:hyperlink` is assembled together with relationship lookup and trimmed
  link text
* paragraph/list/heading/blockquote/code decisions happen after inline scan
* table cells are assembled paragraph-by-paragraph and then joined with `\n`
* header/footer, footnote, endnote, comment, and text-box text reuse local
  DOCX text extraction helpers

This means DOCX does not have one single text-only path. It has several
related paths that all sit close to OOXML run/paragraph semantics.

### P9 pilot status

P9 status:

* completed as a minimal seam pilot
* shared cleanup is applied only to the plain `w:t` text branch inside
  [`scan_docx_inline_text`](/Users/winter/Documents/Moonbit/markitdown/convert/docx/docx_xml.mbt:1022)

Current adopted seam:

* XML-unescaped `w:t` plain-text payload before it becomes `Inline::Text`

What this pilot intentionally did not touch:

* `w:tab`
* `w:br`
* hyperlink assembly
* fallback plain-text accumulation
* code-like detection
* table policy
* header/footer policy
* notes/comments policy
* textbox policy

### Must stay in DOCX layer

These are DOCX semantics, not shared cleanup:

* `w:tab` handling
* `w:br` handling
* paragraph/run boundary behavior
* heading inference from paragraph styles
* list numbering and list fallback
* blockquote and style inference
* hyperlink assembly with relationship lookup
* table-cell paragraph joining and row/cell structure
* code-like paragraph detection
* text-box extraction and append-only section policy
* header/footer page-number filtering
* note/comment reference markers and append sections

Reason:

* all of these depend on OOXML structure, document assembly rules, or DOCX
  presentation semantics rather than plain character cleanup

### Deferred items

Defer for now:

* generic `trim()` replacement in DOCX
* run-boundary space shaping
* paragraph-end trimming
* table-cell whitespace policy
* hyperlink text trimming policy
* image alt/title normalization policy
* header/footer, note, and comment text cleanup policy

Reason:

* these are the areas most likely to change fixtures even if the underlying
  cleanup seems conservative

### Risk notes

Key risks if DOCX adopts shared cleanup too early:

* code-like detection may change because `text_is_code_like` inspects assembled
  paragraph text
* hyperlink text may change because `scan_docx_inline_text` trims the assembled
  hyperlink body before building `Inline::Link`
* table cell output may change because multiline cell text is built from
  paragraph-level joined strings
* note/header/footer/text-box sections may drift because they reuse local text
  helpers with their own trimming and append conventions

### Recommended current DOCX boundary

Keep the current P9 boundary:

1. only `scan_docx_inline_text` `w:t` plain-text payload uses shared cleanup
2. keep `w:tab`, `w:br`, hyperlink assembly, and fallback accumulation
   unchanged
3. keep code-like, table, header/footer, notes/comments, and textbox behavior
   DOCX-local
4. do not widen DOCX adoption unless fixture-stable coverage proves another
   seam is safe

## PPTX Text-Only Seam Audit

This section records the P11 audit and P12 narrow pilot for PPTX adoption of
shared document-text cleanup.

Audit scope:

* audit first, then P12 narrow seam pilot
* no PPTX converter/parser/emitter behavior changes outside that narrow seam
* no direct `tonyfettes/unicode` dependency from PPTX packages
* no default canonical normalization enablement

### Audited files and functions

Primary files:

* [`convert/pptx/pptx_parser.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_parser.mbt:1)
* [`convert/pptx/pptx_text.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_text.mbt:1)
* [`convert/pptx/pptx_slide.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_slide.mbt:1)
* [`convert/pptx/pptx_bytes.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_bytes.mbt:108)
* [`convert/pptx/pptx_reading_order.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_reading_order.mbt:1)
* [`convert/pptx/pptx_shape_collect.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_shape_collect.mbt:1)
* [`convert/pptx/pptx_noise.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_noise.mbt:1)
* [`convert/pptx/pptx_table_xml.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_table_xml.mbt:1)
* [`convert/pptx/pptx_notes.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_notes.mbt:1)
* [`convert/pptx/pptx_image_assets.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_image_assets.mbt:1)
* [`convert/pptx/pptx_rels.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_rels.mbt:1)

Key functions and flows:

* `parse_pptx`
* `extract_slide_paragraphs`
* `extract_shape_paragraphs`
* `extract_text_runs`
* `extract_text_inlines`
* `render_plain_text_inlines`
* `normalize_slide_text`
* `split_title_shapes`
* `flatten_shapes_in_reading_order`
* `filter_noise_shapes`
* `collect_explicit_table_frames`
* `parse_table_cell_text_body`
* `extract_speaker_notes`
* `export_slide_images`
* `normalize_optional_pptx_image_attr`
* `parse_presentation_slide_entries`

### Current PPTX text assembly shape

Observed structure:

* `<a:t>` run text is UTF-8 decoded and XML-unescaped inside
  `extract_text_runs`
* `extract_text_inlines` turns that run payload into `Inline::Text`, or into
  `Inline::Link` when a run-level hyperlink relationship is present
* `<a:br>` becomes `Inline::Break`
* paragraph text is assembled in `extract_shape_paragraphs`, then trimmed
* title shapes merge multiple paragraphs through `normalize_slide_text`
* slide-level reading order, title/body split, grouping, and noise filtering
  happen after paragraph extraction
* explicit `<a:tbl>` tables parse cell text through the same inline extractor,
  but table row/cell assembly stays local
* speaker notes reuse `extract_shape_paragraphs`
* image alt/title metadata is read separately from picture shape attributes

This means PPTX does not have one single plain-text path. It has a narrow run
payload seam surrounded by strong slide/layout semantics.

### P12 pilot status

P12 status:

* completed as a minimal seam pilot
* shared cleanup is applied only to the plain `<a:t>` text branch inside
  [`extract_text_runs`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_text.mbt:2)

Current adopted seam:

* UTF-8 decoded and XML-unescaped `<a:t>` plain-text payload on the normal
  inline path before it becomes ordinary text output

What this pilot intentionally did not touch:

* fallback accumulation
* `<a:br>`
* hyperlink assembly
* shape-level link fallback
* `normalize_slide_text`
* title/body merge
* reading order
* bullets
* noise/grouping
* explicit table policy
* notes
* hidden-slide handling
* image metadata

### Candidate future seam

Best candidate seam:

* the plain `<a:t>` payload inside
  [`extract_text_runs`](/Users/winter/Documents/Moonbit/markitdown/convert/pptx/pptx_text.mbt:2)
  after UTF-8 decode and XML unescape, before it is wrapped into ordinary text
  inlines

Why this is the lowest-risk seam:

* the payload is already decoded OOXML text rather than raw slide XML
* it is earlier than paragraph/title merge and reading-order heuristics
* it is similar in spirit to the adopted HTML text-node seam and DOCX `w:t`
  seam

Boundary for any future widening:

* only plain `<a:t>` payload should be considered
* do not widen to `extract_text_inlines` wholesale, because that function also
  owns hyperlink assembly, `<a:br>`, and fallback text accumulation

### Must stay in PPTX layer

These are PPTX semantics, not shared cleanup:

* `normalize_slide_text`
* shape reading order
* title/body split and title merge
* bullet/list inference and paragraph level handling
* hyperlink assembly and shape-level link fallback
* single-slide noise filtering
* caption-like, callout-like, and table-like grouping heuristics
* explicit table row/cell assembly policy
* speaker notes placeholder filtering
* hidden-slide labeling
* image caption inference
* image alt/title extraction policy

Reason:

* all of these depend on slide geometry, OOXML presentation structure, or
  output-shaping heuristics rather than plain character cleanup

### Deferred items

Defer for now:

* generic `trim()` replacement in PPTX
* `normalize_slide_text` whitespace collapse behavior
* shape-text normalization used by title/noise/grouping heuristics
* hyperlink text trimming policy
* speaker-notes text cleanup policy
* explicit table cell whitespace policy
* image alt/title cleanup policy

Reason:

* these are the areas most likely to change fixtures even if the underlying
  cleanup appears conservative

### Risk notes

Key risks if PPTX adopts shared cleanup too early:

* title merge may change because `extract_shape_paragraphs` normalizes and
  joins title paragraphs with spaces
* link behavior may drift because run-level and shape-level hyperlink assembly
  happen in the same inline path
* explicit table output may shift because table cells reuse inline extraction
  but have their own row/cell policy
* notes, hidden-slide markers, and noise filtering may move because they
  normalize shape text for slide-specific decisions
* caption-like and callout-like grouping may change because they inspect
  already-normalized shape text

### Recommended current PPTX boundary

Keep the current P12 boundary:

1. only `extract_text_runs` `<a:t>` plain-text payload uses shared cleanup on
   the normal inline path
2. keep fallback accumulation, `<a:br>`, hyperlink assembly, and shape-level
   link fallback unchanged
3. keep `normalize_slide_text`, title merge, reading order, bullets,
   noise/grouping, explicit tables, notes, hidden-slide handling, and image
   metadata PPTX-local
4. do not widen PPTX adoption unless fixture-stable coverage proves another
   seam is safe
