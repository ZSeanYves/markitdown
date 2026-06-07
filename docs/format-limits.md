# Format Limits and Fallback Policy

This is the working ledger for format capability limits and fallback policy.
It is not a bug list.

The document records unsupported-by-design behavior, deferred advanced
features, and expected fallback behavior. It can later feed the supported
formats matrix or user-facing documentation.

## Parser / Convert Contract Policy

* Parser / convert adoption is contract-based, not full-model mandatory.
* Duplicate source parsing should be removed or justified.
* Parser packages provide source facts; convert packages keep Markdown / IR /
  assets / origin and rendering policy.
* Contracts may use full models, token / event streams, query APIs, shared
  scanner primitives, cache / index layers, or inventory / validation signals.

## XML

### Supported baseline

* Safe element trees.
* Attributes.
* Text.
* CDATA as text.
* Namespace prefixes preserved as raw names.
* Predefined entities when supported by the parser.
* Structured lowering for small and simple XML.
* Source-preserving fenced fallback for unsupported, complex, malformed, or
  large XML.

### Unsupported by design

* DTD expansion.
* External entity resolution / XXE.
* External resource fetch.

### Reason

These features carry security and performance risks. XML conversion must not
fetch network resources or read local files from XML entity / system
identifiers.

### Deferred advanced features

* XML schema validation.
* XPath / query language support.
* Namespace semantic resolution.
* Numeric character references, if not yet implemented by the parser.
* Richer mixed-content rendering.
* Repeated-child table inference.

### Default behavior

* Fail closed or use source-preserving fenced fallback.
* No network access.
* No local file reads from XML entity / system identifiers.
* No DTD / entity expansion.

### Quality / real sample status

* Main repo XML tests and samples pass.
* External XML quality rows pass.
* CPython XML and IDPF PLS fixtures are strict metadata-closed.
* Microsoft RSS is runtime guard only pending license review.

## JSON

### Supported baseline

* JSON parsing through `doc_parse/json`.
* `convert/json` consumes `doc_parse/json`.
* Object/list/table/code fallback output remains convert-owned.
* Lightweight-1 profile-disabled timing guard complete.

### Unsupported / deferred

* Streaming JSON parser.
* Explicit deep-recursion guard.
* JSONPath/query execution.
* Full schema validation.

### Quality

* External JSON quality row passes 1/1.
* Source/license/hash strict metadata closure should be audited separately.

## YAML

### Supported baseline

* YAML parsing through `doc_parse/yaml`.
* `convert/yaml` consumes `doc_parse/yaml`.
* Conservative flow subset support where implemented.
* Table/list/code fallback output remains convert-owned.
* Lightweight-1 profile-disabled timing guard complete.

### Unsupported / deferred

* Full YAML 1.2.
* Anchors/aliases/merge keys if unsupported.
* Multi-document streams if unsupported.
* Streaming YAML parser.
* Explicit deep-recursion guard.

### Quality

* External YAML quality row passes 1/1.
* Source/license/hash strict metadata closure should be audited separately.

## Markdown

### Supported baseline

* Source-preserving Markdown passthrough.
* Scanner-backed block inventory.
* Frontmatter / fenced code / heading / list / blockquote / table-like /
  HTML-candidate signals.
* Convert-owned footnote handling.
* Footnote exclusion from frontmatter, fenced code, and HTML-candidate ranges.
* Origin metadata based on scanner ranges.

### Unsupported / deferred

* Full CommonMark renderer.
* Full Markdown AST.
* Semantic list tree rendering.
* Table-to-RichTable lowering.
* Raw HTML sanitization or execution.
* Link / image fetching.
* Markdown extension execution.
* Frontmatter metadata object extraction unless separately designed.

### Default behavior

* Preserve original Markdown as much as possible.
* No network fetch.
* No HTML execution.
* No link / image download.
* Keep renderer policy in convert and scanner / source model policy in
  `doc_parse`.

### Quality / real sample status

* Main repo Markdown tests and samples pass.
* External quality has Python-Markdown footnotes docs.
* License: BSD-3-Clause.
* sha256: `cb52027428746e19dd82f01f84911fa2f89e5e5107011e116e073f17482e4c33`.

## HTML

### Supported baseline

* HTML product conversion with source extraction and conservative lowering.
* Parser validation / security signals from `doc_parse/html`.
* Heading / list / table / link / image / note conversion policy in
  `convert/html`.
* Local image asset export where supported.
* Unsafe URL handling according to current convert policy.
* Script / style / head / noscript / noise skipping according to current
  convert policy.
* External HTML quality rows passing.

### Phased adoption status

* HTML-1: `convert/html` consumes `doc_parse/html` validation / security
  signals.
* HTML-1 still keeps private semantic lowering for body scope, inline/text,
  table/list/heading, note, link, image, asset, and origin policy.
* HTML-2A complete: shared parser entity, raw tag-name, and raw / decoded attr
  primitives are used by `convert/html` low-level helpers.
* HTML-2B complete: parser token events and depth-aware matching are used by
  `convert/html` for content-scope range selection.
* HTML-2C complete: parser token-event source ranges are used by
  `convert/html` to skip closed script/style/head/noscript elements in the main
  block scanner.
* HTML-2D complete: inline link/image tag dispatch uses parser-backed raw-tag
  primitives, and the HTML profile reports parser analysis, event-scope,
  skip-range, fallback, and large-input guard signals.
* HTML-2E complete: table/list/note structural matching uses parser-backed
  tag-name and attr/entity primitives where localized, disabled profiles avoid
  timing/detail overhead, and enabled profiles include conversion counters.
* Full browser / parser DOM adoption is not guaranteed or default; conversion
  may use shared parser primitives plus convert-owned semantic policy.

### Unsupported by design

* JavaScript execution.
* CSS execution or layout.
* Remote asset fetching.
* Browser-grade rendering.
* Arbitrary sanitizer mode.
* External network access from HTML conversion.

### Deferred advanced features

* Full HTML5 tree builder behavior.
* Complete sanitizer policy.
* Full DOM-to-IR migration from `doc_parse/html`.
* Richer metadata schema for parser validation issues.
* Broader token-event adoption for recursive container and noise lowering.
* Unified asset/link rewrite helper across HTML / EPUB / ZIP.

### Default behavior

* Preserve current product conversion behavior.
* Skip dangerous executable content.
* Do not fetch remote resources.
* Keep asset / link / noise / table policy in convert.
* Use parser validation as signal, not as browser-equivalent rendering.
* Large HTML may skip parser validation to avoid double parse / scan.

### Quality / real sample status

* Main repo HTML tests and samples pass.
* External HTML quality rows pass.
* HTML-real is `PARTIAL_ACCEPT_WITH_LICENSE_REVIEW`.
* MDN `main` / `article` rows are strict accepted.
* MarkItDown / Pandoc rows remain runtime guard rows pending license review.

## ZIP

### Supported baseline

* ZIP archive parsing through `doc_parse/zip`.
* `convert/zip_core` consumes `doc_parse/zip` for archive inventory and entry
  reads.
* Store and DeflateRaw entries are supported.
* Unsafe paths, nested archives, unsupported entries, and child conversion
  failures are handled through convert-owned policy.
* Markdown aggregation, asset remap, and origin metadata remain convert-owned.
* ZIP-1 reuses inspect conversion plans and has a per-run entry byte cache.
* External ZIP quality rows pass.

### Boundary status

* No parser integration problem remains.
* ZIP-1 inspect-plan/profile/cache cleanup is complete.
* ZIP -> PDF compile closure remains deferred.
* Nested dispatcher cleanup remains deferred.
* `zip_worker` adoption remains deferred.

### Unsupported by design / deferred

* Streaming ZIP reader.
* ZIP64 support.
* Encrypted/password-protected ZIP support.
* Multidisk ZIP support.
* Password recovery.
* Full recursive nested archive conversion unless separately designed.
* Dispatcher/capability registry rewrite.

### Default behavior

* Do not extract unsafe paths.
* Do not execute embedded content.
* Do not fetch external resources.
* Keep nested conversion / Markdown aggregation / asset policy in convert.
* Keep ZIP parser source/container-oriented.

### Performance notes

* Archive bytes and decoded entry bytes are still full-buffer.
* ZIP-1 avoids repeated inspect plan rebuild and some repeated entry reads.
* Temp staging/materialization and asset remap copies remain hotspots.
* ZIP -> PDF closure and nested dispatcher are compile-size risks.

### Quality / real sample status

* Main repo ZIP tests and samples pass.
* External ZIP quality rows pass 15/15.
* Source/license/hash strict metadata closure should be audited separately if not
  already complete.

## EPUB

### Supported baseline

* EPUB package parsing through `doc_parse/epub`.
* `convert/epub` consumes `doc_parse/epub` as the source package model.
* Spine / nav / TOC / cover / metadata / warning policy remains in
  `convert/epub`.
* XHTML / HTML spine content is converted through `convert/html`.
* Asset remap and origin metadata remain convert-owned.
* EPUB-1 adds a per-run part cache for repeated reads.
* External EPUB quality rows pass.

### Boundary status

* No hybrid adapter is needed.
* Parser model consumption is already the normal path.
* EPUB-1 part cache is complete.
* Selective archive materialization remains deferred.

### Unsupported by design / deferred

* DRM / encryption support.
* JavaScript execution.
* CSS layout / browser rendering.
* Remote asset fetching.
* Full browser-grade HTML rendering.
* Streaming ZIP / EPUB reader.
* Selective materialization of only required archive entries unless separately
  designed.

### Default behavior

* Do not execute scripts.
* Do not fetch remote resources.
* Keep Markdown / IR / assets / origin policy in convert.
* Keep EPUB parser model source/package-oriented.
* Preserve current asset path behavior.

### Performance notes

* Part reads within one conversion can use the per-run cache.
* Safe archive tree materialization is still broad/full.
* XHTML conversion remains staged-file and full-buffer through `convert/html`.
* Asset remap/copy cost remains a convert-side hotspot.

### Quality / real sample status

* Main repo EPUB tests and samples pass.
* External EPUB quality rows pass 16/16.
* Source/license/hash strict metadata closure should be audited separately if not
  already complete.

## DOCX

### Supported baseline

* DOCX is the current normal DOCX runtime. The architecture is documented in
  `docs/archive/docx-architecture.md`; legacy scanner usage is not part of
  normal conversion.
* DOCX package conversion through OOXML.
* DOCX typed source/model integration via `doc_parse/docx`.
* Paragraph / run / table / media / notes / comments / header / footer /
  textbox output policy is owned by `convert/docx`.
* Footnotes / endnotes follow current Markdown note definition policy.
* Asset export and origin metadata remain convert-owned.
* External DOCX quality rows pass.

### Implementation status

* DOCX replaced the old v1 runtime in commit `8ed4a3b`; `doc_parse/docx`
  and `convert/docx` are no longer present in the normal codebase.
* `doc_parse/docx` preserves source/model facts for paragraphs, runs,
  tables, merged and nested cells, numbering/list hints, notes, comments,
  headers, footers, textboxes, drawings, VML shapes, media, fields, math,
  tracked changes, content controls, smart tags, and content-bearing unknowns.
* `convert/docx` owns Markdown / IR / asset / origin lowering from the
  typed `DocxDocument` model and does not call a v1 fallback or runtime
  oracle.
* Complex Word layout semantics remain intentionally bounded by product policy:
  v2 preserves available typed content and emits warnings/placeholders for
  unsupported constructs instead of falling back to a hidden scanner.

### Unsupported by design / deferred

* Word layout fidelity.
* Field code evaluation.
* OMML-to-MathML/LaTeX conversion.
* Macro execution.
* External link execution or fetching.
* Full tracked-changes rendering unless separately designed.
* Full Word style / layout engine.
* Exact pagination.
* Arbitrary-depth nested table lowering.
* Full object/chart/smart-art/audio/video table media lowering.

### Default behavior

* Do not execute macros.
* Do not fetch external resources.
* Keep Markdown / IR / asset / origin policy in convert.
* Keep parser model source-oriented.
* Preserve current output behavior through v2 parser/lowering tests, main
  samples, and quality rows.
* Keep DOCX package/model state per package / per run; no global conversion
  cache is part of the runtime contract.

### Quality / real sample status

* Main repo DOCX tests and samples pass.
* External DOCX quality rows pass.
* Current quality signal policy expects Markdown note definitions for footnotes
  / endnotes, not appendix headings.
* Source / license strict metadata closure should be audited separately if not
  already complete.

## PPTX

### Supported baseline

* PPTX package conversion through OOXML.
* PPTX-1 parser inventory integration via `doc_parse/pptx`.
* Slide / text / table / chart / image / notes / comments output policy remains
  in `convert/pptx`.
* Chart inventory can reuse the parsed `PptxPresentation` instead of reparsing
  the full deck.
* Asset export and origin metadata remain convert-owned.
* External PPTX quality rows pass.

### Phased adoption status

* PPTX-1: `convert/pptx` consumes `doc_parse/pptx` parser inventory summary
  while preserving legacy output lowering.
* PPTX-1 also removes repeated whole-deck parse from the chart path where
  localized.
* PPTX-2 deferred: gradually replace legacy slide / text / table / media /
  notes / comments lowering with `PptxPresentation` model consumption.
* Full model lowering is not yet complete.

### Unsupported by design / deferred

* Full PowerPoint layout fidelity.
* Animation / timing rendering.
* Slide transition rendering.
* Exact theme rendering.
* Embedded media playback.
* Macro execution.
* External link execution or fetching.
* Exact speaker-notes advanced layout unless separately designed.

### Default behavior

* Do not execute macros.
* Do not fetch external resources.
* Keep Markdown / IR / asset / origin policy in convert.
* Keep parser model source-oriented.
* Preserve current output behavior while parser-model adoption proceeds.

### Quality / real sample status

* Main repo PPTX tests and samples pass.
* External PPTX quality rows pass.
* Source / license strict metadata closure should be audited separately if not
  already complete.

## XLSX

### Supported baseline

* XLSX package parsing through `doc_parse/xlsx`.
* `convert/xlsx` consumes `doc_parse/xlsx` as the source model.
* Workbook / sheet order, cells, display text, formulas, shared strings, styles,
  comments, merged-cell metadata, and RichTable output.
* Convert-owned Markdown / IR / origin / RichTable policy.
* Profile disabled hot path is guarded in `convert/xlsx`.
* Huge sparse used ranges have a dense-area guard and bounded fallback.
* External XLSX quality rows pass.

### Boundary status

* No DOCX/PPTX-style hybrid adapter is needed.
* Parser model consumption is already the normal path.
* XLSX-1C performance guard complete.

### Unsupported by design / deferred

* Full Excel formula evaluation.
* Macro execution.
* External link fetching.
* Full Excel layout / rendering fidelity.
* Streaming parser for very large workbooks.
* Drawing / image asset export unless separately designed.
* Full hyperlink target metadata unless parser model expands it.

### Default behavior

* Do not execute macros.
* Do not fetch external resources.
* Keep Markdown / IR / RichTable / origin policy in convert.
* Keep parser model source-oriented.
* Preserve current output behavior for normal ranges.
* Extreme sparse outputs may use a bounded sparse preview instead of a huge
  RichTable.

### Performance notes

* Current path is full-workbook / full-table memory behavior.
* Profile disabled hot path avoids profile-only detail/stat traversal.
* Huge sparse used ranges are bounded by a dense-area guard and deterministic
  sparse fallback.
* Large genuinely dense sheets remain memory-heavy.
* Shared strings and style/date formatting should remain cache-friendly.
* RichTable construction remains full-memory for normal ranges.

### Quality / real sample status

* Main repo XLSX tests and samples should be verified before accepting any code
  change.
* External XLSX quality rows pass 51/51.
* Source/license/hash strict metadata closure should be audited separately if
  not already complete.

## PDF

### Supported baseline

* PDF conversion through `doc_parse/pdf` and `convert/pdf`.
* Raw extraction, text model construction, line/block conversion, links,
  annotations, images, forms, outlines, and origin metadata where supported.
* PDF-6 reads outlines/bookmarks during first raw extraction and no longer
  reopens the PDF only for outlines.
* PDF-7C profile-disabled timing guard is complete.
* Convert-owned Markdown / IR / asset / origin / layout / noise / table / link
  policy.
* External PDF quality rows pass 76 rows, failed 0, skipped 1.

### Boundary status

* `convert/pdf` consumes `doc_parse/pdf/api` model output.
* Raw/vendor parsing remains in `doc_parse/pdf/raw` and vendored `mbtpdf`.
* Convert policy remains in `convert/pdf`.
* Outline second-open fix is complete.
* Vendor package split and bytes-oriented API remain deferred.

### Unsupported by design / deferred

* Full PDF visual layout fidelity.
* Full OCR/vision provider integration unless separately enabled.
* Full tagged-PDF semantic reconstruction.
* Full form calculation / JavaScript execution.
* External resource fetching.
* Streaming PDF parser.
* Vendor package split.
* Full bytes/input API.

### Default behavior

* Do not execute PDF JavaScript.
* Do not fetch external resources.
* Keep Markdown / IR / asset / origin policy in convert.
* Keep raw parser source-oriented.
* Preserve current output behavior while performance work proceeds.

### Performance notes

* PDF still uses full raw/text/model materialization.
* Text processing remains multi-pass: raw ops -> chars -> spans -> lines ->
  blocks.
* Vendor compile-size hotspots remain.
* PDF-6 removes the outline/bookmark second open.
* PDF-7C profile-disabled paths avoid profile-only stage timing overhead.
* Heavy PDF tests and vendor package closure remain separate optimization
  tracks.

### Quality / real sample status

* Main repo PDF tests and samples pass.
* External PDF quality rows pass 76 rows, failed 0, skipped 1.
* Source/license/hash strict metadata closure should be audited separately if
  not already complete.

## CSV / TSV

### Supported baseline

* CSV parsing through `doc_parse/csv`.
* TSV parsing through `doc_parse/tsv` and `convert/csv` TSV path.
* RichTable output remains convert-owned.
* Encoding fallback remains convert-owned where implemented.
* Lightweight-1 profile-disabled timing guard complete.

### Unsupported / deferred

* Streaming CSV/TSV parser.
* Very large table memory optimization.
* Automatic dialect detection beyond current parser policy.
* Full spreadsheet semantics.
* TSV external quality sample still missing.

### Performance notes

* Current path is full-buffer and full-row materialization.
* RichTable construction remains full-memory.
* Ragged rows can expand to max column count.
* Profile-disabled timing/detail overhead has been removed.

### Quality

* CSV external quality rows pass 15/15.
* TSV external quality rows are currently 0/0 and need a real sample later.
* Source/license/hash strict metadata closure should be audited separately.
