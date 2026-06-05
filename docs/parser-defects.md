# Parser Defects and Deferred Decisions

This is an internal parser-layer tracking document. It is not a user-facing
support matrix.

It records known limitations, deferred risks, and not-a-bug decisions for the
current parser refactor pass.

Current scope:

* JSON
* YAML
* XML
* CSV / TSV
* Text
* Markdown
* HTML
* ZIP
* OOXML
* DOCX
* PPTX
* XLSX
* EPUB
* PDF

## Parser / Convert Contract Principle

* Parser packages own source facts: syntax, source-native structure, spans,
  relationships, validation signals, and package/part facts.
* Convert packages own product policy: Markdown / IR lowering, rendering choices,
  metadata, origin attachment, asset export, provider gates, and fallbacks.
* Parser / convert integration may use a full model, token / event stream, query
  API, shared scanner / helper primitive, cache / index, or inventory /
  validation signal.
* Full parser model consumption is optional, not mandatory.
* Duplicate source parsing is a defect only when it is unnecessary and
  unjustified.
* Convert-local semantic logic is acceptable when it is product policy and
  benchmark-stable.

## 1. JSON

### Status

* `doc_parse/json` has a healthy parser / AST / inspect separation.
* `convert/json consumes doc_parse/json`.
* No adapter is needed.
* `convert/json` owns Markdown and IR lowering policy.
* The parser layer remains string-based and source-native.

### Fixed in current pass

* Normal `parse_json_document` no longer builds profile-only detail strings such
  as `chars=` and `root=` when profiling is disabled.
* The README `root_kind` example was corrected to match the current String
  field shape.

### Deferred defects / risks

* `profile_json_document` is public even though it is mostly an internal
  attribution surface.
* Recursive JSON parsing has no explicit depth guard.
* The parser is not streaming and currently expects a full String input.

### Not-a-bug decisions

* JSON5, comments, and trailing commas are unsupported.
* JSON numbers remain source-preserving strings in the parser model.

### Future actions

* Decide whether the profile API should remain public.
* Consider a unified depth guard policy.
* Revisit allocation hot spots only when profiling or product-path timings show
  a meaningful need.

## 2. YAML

### Status

* `doc_parse/yaml` is a conservative YAML subset parser.
* `convert/yaml consumes doc_parse/yaml`.
* No adapter is needed.
* `convert/yaml` owns Markdown and IR lowering policy.
* The parser intentionally fails closed for unsupported YAML features.

### Fixed in current pass

* Normal `parse_yaml_document` no longer builds profile-only detail strings such
  as `root=` and `lines=` when profiling is disabled.
* YAML-1 added conservative single-line flow sequence and flow mapping support.
* Parser tests, `convert/yaml` tests, and a main-process YAML sample were synced
  for flow sequence / mapping coverage.

### Deferred defects / risks

* Full YAML 1.2 is unsupported.
* Block scalars remain unsupported.
* Anchors, aliases, tags, merge keys, and complex keys remain unsupported.
* Real multi-document streams remain unsupported.
* Recursive YAML parsing has no explicit depth guard.
* The parser is not streaming and currently expects a full String input.
* `profile_yaml_document` is public even though it is mostly an internal
  attribution surface.

### Not-a-bug decisions

* Malformed flow collections fail closed.
* Numbers retain the current parser model behavior.
* Flow support is limited to a conservative single-line subset.
* `convert/yaml` runtime remains unchanged because it already consumes existing
  `YamlValue::Sequence` and `YamlValue::Mapping` shapes.

### Future actions

* Keep the YAML subset boundary explicit.
* Extend only small, product-driven YAML subsets.

## 3. XML

### Status

* `doc_parse/xml` has a healthy tokenizer / parser / model / inspect / safety
  boundary.
* `convert/xml` now consumes `doc_parse/xml` for safe small XML structured
  lowering after convert-owned bytes decode.
* Unsupported, unsafe, complex, malformed, or large XML still falls back to
  source-preserving fenced XML in the convert layer.

### Deferred defects / risks

* The tokenizer still normalizes source and builds a char array.
* Recursive XML element parsing has no explicit depth guard.
* Entity-heavy inputs can cause extra small allocations during entity decoding.
* `tokenize_xml_document` and `XmlToken` may be wider public surface than the
  long-term parser contract needs.
* Numeric character references are not yet supported.

### Not-a-bug decisions

* The parser stays source-oriented and does not own Markdown / IR lowering.
* Unsupported XML language features and fallback behavior are tracked in
  `docs/format-limits.md` instead of this defect list.

### Future actions

* Consider an explicit recursive depth guard.
* Consider numeric character references as a narrow XML subset upgrade.
* Review whether `tokenize_xml_document` / `XmlToken` should remain public.
* Revisit tokenizer allocation only if XML benchmark data shows a bottleneck.

## 4. CSV / TSV

### Status

* `doc_parse/csv` owns the shared CSV / delimited parser core.
* `doc_parse/tsv` is a thin facade over `doc_parse/csv` with tab delimiter
  options.
* `convert/csv consumes doc_parse/csv`.
* `convert/csv parse_tsv consumes doc_parse/tsv`.
* No adapter is needed.
* `convert/csv` owns header, table, and Markdown policy.

### Current boundary

* Parser packages own source/delimiter parsing and row materialization.
* Header detection, RichTable construction, encoding fallback, and Markdown /
  IR output policy remain convert-owned.
* TSV remains a thin input-format facade over the shared delimited parser.

### Deferred defects / risks

* CSV README examples mention API shapes that may be stale, such as
  `new_csv_parse_options()` and `trim_fields`.
* The CSV parser normalizes source, converts normalized text to a char array,
  and counts physical lines separately; this creates mild multiple-scan
  overhead.
* There is no streaming parser; large delimited files remain full-String parser
  inputs.
* CSV/TSV rows are fully materialized before convert lowering.
* Delimiter support follows explicit parser options; automatic dialect
  detection beyond current parser policy is deferred.
* Parser inputs are decoded Strings; file bytes and encoding fallback remain
  convert-owned where applicable.

### Not-a-bug decisions

* Do not introduce `doc_parse/delimited` yet; the current shared parser in
  `doc_parse/csv` is enough.
* TSV as an input format sample is allowed.
* TSV as a main-repo manifest / config / control file remains disallowed.
* Header detection and table policy belong to `convert/csv`, not
  `doc_parse/csv`.

### Future actions

* Fix CSV README API examples.
* Consider hot-path scan reduction only if benchmark data shows a CSV / TSV
  bottleneck.
* Keep the TSV facade thin.

## Text

### Status

* `doc_parse/text` is not a pure passthrough.
* It owns a UTF-8 bytes decode helper, BOM / newline normalization, newline
  style detection, line inventory, blank-line paragraph grouping, inspect, and
  profile surfaces.
* `convert/txt` consumes normalized text / model output and owns cleanup,
  literal Markdown, origin metadata, and IR lowering.

### Fixed in current pass

* None yet.

### Deferred defects / risks

* Normal parse still builds profile-only detail strings such as `style=` and
  `chars=` unless optimized.
* Text parsing does multiple scans / allocations: `to_array`, normalized chars,
  line strings, and paragraph strings.
* `text_chars_equal_string` may do another `to_array` pass.
* `profile_text_document` and profile report structs are public but mostly
  internal attribution surface.

### Not-a-bug decisions

* The text parser does not do file I/O.
* The text parser may expose a bytes decode helper, but actual file reading
  stays in the convert / CLI layer.
* Paragraph grouping is non-Markdown blank-line grouping, not Markdown
  semantics.

### Future actions

* Avoid profile detail construction in normal parse.
* Consider reducing the `text_chars_equal_string` extra scan only if low-risk.
* Decide profile API boundary together with JSON, YAML, and Markdown.

## Markdown

### Status

* `doc_parse/markdown` is a lightweight Markdown source scanner.
* It scans raw block inventory, frontmatter, fences, headings, lists,
  blockquotes, table-like rows, and HTML-candidate signals.
* It is not a renderer, CommonMark parser, or passthrough converter.
* `convert/markdown` consumes the `doc_parse/markdown` scanner for block
  inventory, frontmatter, fence, and HTML-candidate ranges.
* `convert/markdown` still owns source-preserving passthrough output and
  footnote policy.

### Fixed in current pass

* `convert/markdown` now consumes `doc_parse/markdown` scanner output for block
  inventory / frontmatter / fence / HTML-candidate ranges.

### Deferred defects / risks

* Normal scan still builds profile-only detail strings unless optimized.
* `source_length` uses `normalized.to_array().length()`, creating an avoidable
  full char-array pass.
* The scanner performs normalization, line splitting, line views, trim passes,
  and raw block joins.
* `profile_markdown_document` and profile report structs are public but mostly
  internal attribution surface.
* Large Markdown inputs still deserve explicit benchmark-driven review because
  the scanner remains a full-buffer normalization / line-oriented pass.

### Not-a-bug decisions

* Keeping the scanner package is reasonable because it contains real structural
  signal extraction, not an empty wrapper.
* CommonMark completeness, full Markdown AST work, HTML sanitization, remote
  link/image fetch, and other product-facing Markdown behavior belong in
  `docs/format-limits.md`, not this defect list.

### Future actions

* Avoid profile detail construction in normal scan.
* Replace the `source_length` char-array count with a lower-allocation helper if
  low-risk.
* Record profile API boundary with other parser packages.

## HTML

### Status

* `doc_parse/html` is a parser / DOM-lite foundation: tokenizer -> tolerant
  DOM-ish model -> validation / inspect.
* It does not produce Markdown, IR, or assets and performs no I/O, remote fetch,
  CSS, or JS execution.
* It includes parser-layer safety / diagnostic issues such as duplicate
  attributes, unsafe URL scheme, and script / style warnings.
* `convert/html` consumes `doc_parse/html` parser validation / security
  signals.
* HTML-2A shared low-level parser primitives are complete for entity decode,
  raw tag-name extraction, and raw / decoded attribute value helpers.
* HTML-2B selective token / event traversal is complete for source-offset token
  events and depth-aware matching helpers used by `convert/html` scope
  selection.
* HTML-2C token-event skip ranges are complete for closed
  script/style/head/noscript element source ranges.
* HTML-2D inline/link/image primitive convergence is complete for convert-side
  inline tag dispatch through the shared parser raw-tag helper.
* HTML-2D parser-analysis observability is available in the `convert/html`
  profile path for parser analysis, event scope, skip ranges, fallback reason,
  and large-input guard signals.
* HTML-2E table/list/note primitive convergence is complete where applicable:
  structural table/list matching uses parser-backed tag-name verification, table
  span attrs use decoded parser attrs, and note/ref paths keep parser-backed
  attr/entity helpers.
* HTML-2E profile hot-path audit is complete for HTML profile timing and
  enabled-only conversion counters.
* `convert/html` now routes low-level attr / entity / raw-tag helpers through
  `doc_parse/html` primitives.
* `convert/html` uses parser token events for main / article / body scope range
  selection while keeping semantic lowering policy local.
* `convert/html` uses parser token-event ranges to skip closed
  script/style/head/noscript elements in the main block scanner while preserving
  fallback raw scanning.
* `convert/html` may keep semantic body / noise / table / link / image policy.
* Full parser DOM adoption remains non-default and requires benchmark / quality
  proof.

### Deferred defects / risks

* `parse_html_document` and `tokenize_html_document` currently perform double
  normalization plus an extra `source_length` char-array / `to_array`-style
  pass.
* `inspect_html_document` recursively visits children; very deep DOM trees can
  hit recursion depth risk.
* Entity-heavy HTML can allocate through repeated text, attribute, and entity
  decoding.
* The private `convert/html` semantic traversal still uses byte search / matching
  for block, inline, table, list, note, and noise product policy; this is
  separate from the shared attr / entity / raw-tag primitives, scope event
  traversal, and token-event skip ranges completed in HTML-2A / HTML-2B /
  HTML-2C, inline tag dispatch completed in HTML-2D, and table/list/note
  structural primitive convergence completed in HTML-2E.
* Large HTML can hit double-parse risk when parser validation and private
  semantic scanning both run; very large inputs keep the parser-validation guard
  and fall back to byte scope selection.
* `tokenize_html_document`, `HtmlToken`, token event, and token source-range
  helper APIs may be wider public surface than needed.
* Parser model / validation issue public shapes such as `HtmlDocument`,
  `HtmlNode`, `HtmlValidationIssueKind`, and validation reports now cross a real
  package boundary and should remain source-oriented and compatibility-aware.
* `HtmlValidationIssueKind` includes safety diagnostics such as `UnsafeUrl`,
  `ScriptElement`, and `StyleElement`; these must not quietly evolve into
  convert output policy without explicit design.

### Not-a-bug decisions

* Parser-layer safety diagnostics are acceptable.
* `doc_parse/html` does not decide Markdown, IR, table, list, heading, image, or
  link output policy.
* `doc_parse/html` does not copy assets or render links.
* Unknown named entities may remain literal.
* JS / CSS execution, sanitizer mode, browser-grade tree building, and remote
  asset fetch belong in `docs/format-limits.md`, not this defect list.

### Future actions

* Reduce double normalization and `source_length` allocation if low-risk.
* HTML-2A shared low-level parser primitive convergence is complete.
* HTML-2B selective token / event stream traversal is complete for content-scope
  range selection.
* HTML-2C token-event skip ranges are complete for closed
  script/style/head/noscript elements.
* HTML-2D inline/link/image primitive convergence and profile observability are
  complete where applicable.
* HTML-2E table/list/note primitive convergence and profile hot-path audit are
  complete where applicable.
* Do not make full parser DOM adoption the default target without benchmark /
  quality proof.
* Keep safety diagnostics separate from convert output policy.
* Evaluate whether token / validation public surface can be narrowed without
  breaking legitimate parser consumers.
* Consider depth guard strategy with other recursive parsers.

## ZIP

### Status

* `doc_parse/zip` is a ZIP parser / codec / container foundation.
* It owns EOCD, central directory, local header parsing, entry inventory, path
  normalization diagnostics, entry bytes reading, and Store / DeflateRaw decode.
* It performs no Markdown / IR conversion, no entry dispatch policy, and no file
  I/O.
* `convert/zip_core` consumes `doc_parse/zip`.
* No parser integration problem remains.
* `convert/zip_core` owns archive conversion policy and entry format dispatch.
* convert-side inspect-plan/profile/cache cleanup completed in ZIP-1.

### Fixed in current pass

* ZIP-1 completed convert-side inspect-plan/profile/cache cleanup; repeated
  inspect plan rebuild, profile-disabled detail/stat traversal, and repeated
  `read_entry` cache gaps are no longer parser unresolved defects.

### Deferred defects / risks

* `open_zip` keeps the whole archive bytes in memory.
* `read_entry` returns full decoded entry bytes.
* Deflate decode currently completes before `max_output_size` is checked,
  creating peak-memory risk for hostile compressed data.
* CRC32 validation scans decoded bytes after decode.
* There is no streaming entry reader.
* ZIP64, encryption / password recovery, multidisk archives, and unsupported
  compression methods remain unsupported.
* Public API surface is broad: archive, entry, inspect, diagnostic, list, and
  read helpers are all exposed.
* Unsafe entry paths are validation diagnostics at the `doc_parse` level;
  `convert/zip_core` decides fail policy.

### Not-a-bug decisions

* Store and DeflateRaw are the supported compression methods.
* Encrypted archives fail closed.
* ZIP64 sentinel values fail closed.
* Nested archive is only a warning candidate; `doc_parse/zip` does not recurse.
* Directory entries remain in inventory and are reported as diagnostics.
* TSV / manifest-style policy is unrelated here; ZIP entry inventory is data,
  not a main-repo control manifest.

### Future actions

* Consider deflate output cap before or during decompression if the backend
  supports it.
* Consider streaming entry read only if real workloads require it.
* Consider narrowing the public API surface after convert/test consumers are
  reviewed.
* Keep convert policy in `convert/zip_core`.

## OOXML

### Status

* `doc_parse/ooxml` is the shared OOXML package foundation for DOCX, PPTX, and
  XLSX.
* It owns ZIP package opening, part index, `[Content_Types].xml` parsing,
  relationship parsing and target resolution, media inventory, lightweight
  docProps, inspect / validation / dump helpers.
* It does not produce Markdown / IR / assets and does not own DOCX / PPTX /
  XLSX format-specific semantics.
* `doc_parse/zip` sits below it; `doc_parse/docx`, `doc_parse/pptx`, and
  `doc_parse/xlsx` sit above it.

### Fixed in current pass

* None in code. Audit only.

### Deferred defects / risks

* Public surface is broad: `OoxmlPackage` archive / part index / content type
  fields and dump helpers are exposed.
* Full-buffer model is inherited from `doc_parse/zip`; package bytes and
  decoded part bytes are held in memory.
* `read_part_text` and `read_part_bytes` may repeatedly read / decode parts
  without caching.
* Relationship / content type / list inspect helpers may rebuild or sort
  repeatedly.
* `list_media_assets` reads media bytes to determine size and scans all parts /
  relationships.
* Strict validation is separate from open compatibility; duplicate relationship
  ids are validation issues, not open hard failures.
* Unsafe ZIP paths are handled by ZIP / validation policy and are not
  automatically escalated by `open_ooxml_package`.

### Not-a-bug decisions

* OOXML package mechanics belong here; DOCX / PPTX / XLSX document semantics do
  not.
* External relationships are preserved but not fetched.
* Absolute-style package targets are normalized as internal package parts, not
  filesystem paths.
* Missing `[Content_Types].xml` is a package-level hard failure; format-specific
  required parts are checked by DOCX / PPTX / XLSX.
* Conventional media directories are package-level inventory signals, not asset
  export policy.
* Lightweight docProps parsing is package-level metadata signal, not Markdown
  conversion policy.

### Future actions

* Consider caching part text / bytes or inspect reports only if repeated reads
  become measurable.
* Decide whether unsafe ZIP path validation should be escalated at OOXML open
  time.
* Keep DOCX / PPTX / XLSX semantics in their own parser packages.
* Audit DOCX, PPTX, and XLSX separately.

## DOCX

### Status

* `doc_parse/docx` is the DOCX parser / model layer built on
  `doc_parse/ooxml`.
* It parses DOCX package parts into a `DocxDocument` model: body blocks,
  paragraphs, runs, tables, styles, numbering, relationships, footnotes /
  endnotes, comments, headers / footers, text boxes, drawings, shapes, media,
  fields, math, tracked changes, content controls, smart tags, and
  content-bearing unknowns.
* It does not produce Markdown / IR, copy or export assets, or own metadata
  sidecar policy.
* `doc_parse/ooxml` sits below it; `convert/docx` sits above it.
* The old `doc_parse/docx` parser/runtime directory was removed in commit
  `8ed4a3b`; normal DOCX conversion no longer has a v1 parser fallback.
* The parser/model preserves source order, owner part, stable source keys,
  part graph relationships, table merge/nesting facts, media references, and
  structured warnings for unsupported source constructs.
* `convert/docx` retains Markdown / assets / origin / rendering policy.

### Fixed in current pass

* DOCX source/model/lowering replaced the old DOCX parser/runtime path and
  removed normal runtime fallback/oracle behavior.
* Package part reads, relationship lookup, styles, numbering, media inventory,
  source order, table facts, note/comment/header/footer/textbox bodies,
  drawing/shape anchors, and content-bearing unknowns are represented in v2
  source/model records.
* Parser-owned facts remain source-oriented: Markdown, IR, asset paths,
  appendix placement, origin policy, field evaluation, OMML conversion, and
  full tracked-change rendering stay out of the parser.

### Deferred defects / risks

* `open_docx_document(path)` performs file I/O inside the parser package; this
  is a convenience facade but not a pure parser boundary.
* Keep future DOCX inventory/debug helpers out of profile-disabled normal
  conversion paths.
* Word layout fidelity, field evaluation, OMML conversion, arbitrary-depth
  table rendering, object/chart/smart-art/audio/video rendering, and full
  tracked-change display policy remain explicit product limits.
* Large public model structs make future schema evolution harder.

### Not-a-bug decisions

* Heading / list / table information belongs in `doc_parse/docx` as
  source-model signals, not as Markdown rendering policy.
* Media references belong in the parser model; asset extraction / copy policy
  belongs to `convert/docx`.
* Footnotes, endnotes, comments, headers, and footers parsing belongs in DOCX
  parser scope.
* Document properties mostly remain package-level OOXML signals unless
  DOCX-specific behavior is needed.

### Future actions

* Keep Markdown / IR / asset policy in `convert/docx`.

## PPTX

### Status

* `doc_parse/pptx` is the PPTX parser / model layer built on
  `doc_parse/ooxml`.
* It parses PresentationML package parts into a source-native
  `PptxPresentation` model: slide order, hidden slide signal, shape tree, text
  paragraphs / runs, tables, cached chart data, notes, comments, media
  references, and hyperlinks.
* It does not produce Markdown / IR, copy or export assets, or own metadata
  sidecar policy.
* `doc_parse/ooxml` sits below it; `convert/pptx` sits above it.

### Current adapter boundary

* `convert/pptx` consumes `doc_parse/pptx` through a PPTX-1 parser inventory
  adapter.
* `convert/pptx` reuses the same `OoxmlPackage` and avoids path double-open.
* Chart conversion reuses the parsed `PptxPresentation` instead of reparsing
  the whole deck.
* Legacy slide / text / table / image / output lowering remains in
  `convert/pptx`.

### Deferred defects / risks

* `open_pptx_presentation(path)` performs file I/O inside the parser package;
  this is a convenience facade but not a pure parser boundary.
* Parser and legacy convert paths can still read some of the same package parts
  during the normal PPTX conversion path.
* Repeated part reads may occur across slides, slide relationships, notes,
  comments, and charts.
* XML string scanning in `pptx_xml.mbt` and per-feature parsers can involve
  multiple scans / slices.
* Relationship lookup can be linear in places such as
  `find_pptx_relationship_by_id`.
* Group shape traversal and inspect recurse through shape trees and can hit
  depth risk on extreme documents.
* Chart, table, and media models still preserve source-native signals rather
  than full PowerPoint rendering semantics.
* `inspect_pptx_presentation`, validation reports, and public model structs are
  mostly internal attribution / adapter surface and should remain
  compatibility-aware.
* Large public model structs make future schema evolution harder.

### Not-a-bug decisions

* Slide / title / placeholder / text / table / chart / media / note / comment
  information belongs in `doc_parse/pptx` as source-model signals, not as
  Markdown rendering policy.
* Media references belong in the parser model; asset extraction / copy policy
  belongs to `convert/pptx`.
* Speaker notes are parser model data; final notes rendering belongs to
  `convert/pptx`.
* Cached chart data extraction is parser-model signal, not final chart
  rendering policy.
* Full PowerPoint layout, animation / timing rendering, external link
  execution, and exact theme rendering belong in `docs/format-limits.md`, not
  this defect list.

### Future actions

* Keep the parser inventory adapter narrow while PPTX-2 gradually replaces
  legacy output paths with `PptxPresentation` consumption.
* Consider relationship lookup indexing if slide / shape-heavy decks show
  bottlenecks.
* Keep Markdown / IR / asset / notes rendering policy in `convert/pptx`.
* Audit XLSX separately.

## XLSX

### Status

* `doc_parse/xlsx` is the XLSX parser / model layer built on
  `doc_parse/ooxml`.
* It parses SpreadsheetML package parts into an `XlsxWorkbook` model: workbook
  sheets, worksheet cells, shared strings, inline strings, styles / number
  formats, merged ranges, comments, hidden rows / sheets, formulas, cached
  values, and conservative formula trace signals.
* It does not produce Markdown / IR / RichTable output, copy or export assets,
  or own metadata sidecar policy.
* `doc_parse/ooxml` sits below it; `convert/xlsx` sits above it.
* `convert/xlsx` already consumes `doc_parse/xlsx` as the source model.
* No hybrid adapter is needed; unlike DOCX / PPTX, the normal XLSX convert path
  already uses `XlsxWorkbook`, `XlsxSheet`, and `XlsxCell` through a convert
  compatibility model.

### Fixed in current pass

* No parser architecture change was needed: `convert/xlsx` already consumes
  `doc_parse/xlsx` as the source model.
* XLSX-1C fixed the convert-side huge sparse output risk with a dense-range
  guard; that is no longer an unresolved parser defect.

### Deferred defects / risks

* `open_xlsx_workbook(path)` performs file I/O inside the parser package; this
  is a convenience facade but not a pure parser boundary.
* XLSX parsing inherits full-buffer OOXML / package reads from
  `doc_parse/ooxml`.
* Shared strings, styles, workbook sheets, worksheet cells, hidden-row data,
  comments, and merged ranges are fully materialized.
* Date / time and number-format interpretation are relatively thick
  parser-layer semantics via `display_text` and `semantic_type`; this must
  remain source-model signal, not product rendering policy.
* Parser-side profile helper calls may still construct parser-only detail
  strings such as `bytes=` and `count=` on the non-profile path; this is
  separate from the XLSX-1C convert-side profile-disabled hot-path fix.
* Shared strings are loaded into a full in-memory array.
* Cell `display_text` can copy or spread shared string / formatted value text
  across many cells.
* Worksheet, styles, shared strings, and formula parsing rely on XML string
  scanning / slicing; large worksheets can be hot.
* Formula context can build coordinate maps, duplicating memory with the full
  workbook model.
* Drawings / images / media are not currently represented as parser model
  features.
* Hyperlink target metadata is not currently represented as parser model
  feature beyond visible cell text and relationship-level sheet metadata.
* Large public model structs and compatibility aliases such as `XlsxSheetModel`
  and `XlsxCellModel` make future schema evolution harder.
* Streaming parser support for very large workbooks is deferred.
* Convert/xlsx now bounds huge sparse used-range outputs with a dense-range
  guard, but the parser remains full-materialization and non-streaming.

### Not-a-bug decisions

* Workbook / sheet / cell / style / formula / comment information belongs in
  `doc_parse/xlsx` as source-model signals.
* Markdown table rendering, sheet heading / output policy, row / column
  trimming, metadata sidecar, and origin policy belong in `convert/xlsx`.
* Date / number display hints are acceptable parser-model signals as long as
  convert keeps final output policy.
* Drawings / images / media are intentionally out of current XLSX parser scope.
* Full Excel formula evaluation, macro execution, external link fetching, and
  full Excel layout / rendering fidelity belong in `docs/format-limits.md`, not
  this defect list.

### Future actions

* Avoid parser-side normal-path profile detail construction if low-risk.
* Consider formula / style / date hot-path work only with XLSX samples or
  benchmark evidence.
* Consider shared string / `display_text` memory reductions only if real
  workloads show pressure.
* Keep RichTable / Markdown / sheet output policy in `convert/xlsx`.
* EPUB audit and EPUB-1 convert-side cache cleanup are complete; audit PDF last.

## EPUB

### Status

* `doc_parse/epub` is an EPUB package / parser / model foundation built on
  `doc_parse/zip`.
* It opens EPUB bytes, normalizes archive entries, reads
  `META-INF/container.xml`, OPF package data, manifest, spine, EPUB3 nav, NCX
  toc, guide, metadata, cover candidates, and resource references.
* It does not produce Markdown / IR, export assets, rewrite links, or own
  metadata sidecar policy.
* `doc_parse/zip` sits below it; `convert/epub` sits above it.
* `convert/epub` already consumes `doc_parse/epub` and owns
  reading-order-to-Markdown, asset remap / export, link rewriting, warnings,
  and origin metadata policy.
* No hybrid adapter is needed.
* `convert/epub` has a per-run part cache for repeated conversion part reads.

### Fixed in current pass

* EPUB-1 added a `convert/epub` per-run part cache for repeated conversion
  reads; materialization and cover export now use cached part bytes where
  applicable.

### Deferred defects / risks

* `EpubPackage` exposes archive, `entry_index`, manifest / spine / nav
  internals, and public container-like read / list helpers; this is broad but
  currently useful.
* `doc_parse/epub` inherits full-buffer ZIP behavior and full decoded entry
  reads from `doc_parse/zip`; there is no streaming archive reader.
* Public `read_part_bytes` and `read_part_text` remain a broad package/read-part
  surface, even though `convert/epub` now caches repeated reads within one
  conversion run.
* Full safe archive tree materialization and staged XHTML / HTML conversion
  remain convert-side performance risks tracked in `docs/convert-defects.md`.
* EPUB3 nav and NCX toc traversal can hit depth risk on extreme files.
* Path normalization and external href/resource safety must remain guarded.
* Path resolution uses repeated `split` / `replace` / `to_array` style
  operations; large manifests / resources may accumulate overhead.
* EPUB3 nav hrefs are kept as raw toc signals, while NCX unsafe hrefs are
  skipped; behavior should stay documented.

### Not-a-bug decisions

* Spine reading order belongs in `doc_parse/epub` as source-model order; final
  Markdown structure belongs in `convert/epub`.
* Manifest / resources / cover candidates belong in parser model; asset copy /
  export policy belongs in `convert/epub`.
* External links / resources are preserved but not fetched.
* `doc_parse/epub` does not parse XHTML body content; `convert/epub` delegates
  body conversion to `convert/html`.
* `doc_parse/epub` remains a package/source model layer only; Markdown / IR /
  asset / origin policy stays in `convert/epub`.
* `META-INF/encryption.xml` remains unsupported / fail-closed.

### Future actions

* Consider nav / toc depth guard with other recursive parser decisions.
* Consider streaming ZIP / EPUB package reading only as a separately designed
  parser project.
* Keep link rewrite, asset export, Markdown rendering, and metadata sidecar
  policy in `convert/epub`.
* Audit PDF last.

## PDF

### Status

* `doc_parse/pdf` is a layered PDF stack, not a single parser package.
* The stack includes runtime entry / API, raw adapter, document model, text /
  layout extraction model, inspect / debug surface, `layout_model_tool`, tests /
  testdata, and a large vendored `mbtpdf` tree.
* Normal conversion goes through `convert/pdf` -> `doc_parse/pdf/api` -> raw
  `mbtpdf` extraction -> text / model builders -> `convert/pdf` policy.
* PDF-6 outline second-open fix complete.
* Raw extraction carries outlines / bookmarks from the first opened PDF object.
* `RawPdfDocumentExtract.outlines` feeds `PdfDocumentModel.outlines`.
* Normal extraction path no longer reopens PDF for bookmarks / outlines.
* `doc_parse/pdf` is the largest known compile-size / time risk in the parser
  layer.

### Current package map

* `api`: runtime entry / path-oriented facade.
* `raw`: adapter over vendored `mbtpdf`.
* `model`: parser model.
* `text`: runtime text / layout extraction model; heavy but runtime-relevant.
* `inspect`: debug / inspect surface; should not be normal runtime dependency.
* `layout_model_tool`: dev / model-training / export tool; boundary suspect
  because it depends on `convert/pdf_layout`.
* `vendor/mbtpdf`: vendored raw PDF parser / codec / font / page / object
  implementation; major compile-size hotspot.
* `tests/testdata`: tests and small fixtures only.

### Runtime chain

* Normal conversion path is `convert/pdf.parse_pdf` ->
  `doc_parse/pdf/api.extract_document_model` ->
  `raw.extract_raw_document_with_mbtpdf` -> vendored `mbtpdf` read / page /
  operator / text / image extraction -> text builders -> `PdfDocumentModel` ->
  `convert/pdf` policy.
* Normal runtime requires `doc_parse/pdf/api`, `raw`, `model`, `text`, and a
  vendor read / text / page / operator / image / font / codec subset.
* `doc_parse/pdf/inspect`, `layout_model_tool`, and `convert/pdf_debug` are not
  imported by normal parse.
* `convert/pdf_layout` is not imported by `convert/pdf` and is not part of the
  normal PDF conversion runtime.
* `convert/pdf` internal layout gate logic is normal runtime convert policy,
  but that is separate from importing the `convert/pdf_layout` package.

### Compile-size / time hotspots

* `vendor/mbtpdf/document/pdfpage`
* `vendor/mbtpdf/codec/pdfcodec`
* `vendor/mbtpdf/text/pdftextread`
* `vendor/mbtpdf/graphics/pdfops` and `pdfopsread`
* `vendor/mbtpdf/core/pdf`
* `vendor/mbtpdf/crypto/pdfcrypt`
* `vendor/mbtpdf/font/pdfglyphlist`
* `doc_parse/pdf/text`
* `doc_parse/pdf/inspect`

### PDF-2 vendor compile-size findings

* Normal raw runtime directly imports `core/pdf`, `core/pdfio`,
  `core/pdftransform`, `io/pdfiofs`, `io/pdfreadcore`,
  `document/pdfpage`, `document/pdfdest`, `graphics/pdfopsread`,
  `graphics/pdfimage`, `text/pdftextread`, and `codec/pdfcodec`.
* Text extraction pulls `pdffont`, `pdfcmap`, `pdfglyphlist`, and
  `pdfsyntax`.
* Image extraction pulls `pdfimage`, `pdfspace`, `pdffun`, and `pdfcodec`.
* Page tree / outlines pull `pdfpage`, `pdfmarks`, `pdfdest`, and `pdftree`.
* Full `io/pdfread`, `io/pdfwrite`, `crypto/pdfcrypt`, and
  `crypto/pdfcryptcore` appear mostly isolated from normal runtime.
* `core/pdfcryptprimitives` is still pulled via `core/pdf` and needs later
  proof before split.

### PDF-2 compile-size hotspot ranking

* `document/pdfpage`: page read / edit / write / helpers in one package;
  partial runtime need; split candidate.
* `codec/pdfcodec`: common Flate plus rare / heavy filters such as CCITT /
  LZW / ASCII85 / RunLength and encode helpers; split candidate.
* `text/pdftextread`: runtime important; optimize cautiously.
* `graphics/pdfops`: emit / write / operator surface likely pulled via
  `pdfpage`; split candidate.
* `core/pdf`: central object model plus serialize / copy helpers; hard split
  candidate.
* `font/pdfglyphlist`: large generated glyph table; lazy-init candidate.
* `graphics/pdffun` / `pdfimage`: image path heavy; benchmark before split.
* `core/pdfcryptprimitives`: questionable normal-runtime dependency via
  `core/pdf`.

### PDF-2 writer / crypto / debug / test-only boundary

* `io/pdfwrite` is mostly outside normal runtime.
* `crypto/pdfcrypt` and `pdfcryptcore` are mostly outside normal runtime.
* Writer / emit / build helpers still live inside normal-adjacent packages
  through `pdfpage` / `pdfops`.
* Raw wbtests import heavier writer / operator packages but should remain
  test-only.

### PDF-2 rare filter / font boundary

* Keep ToUnicode / CMap / text extraction correctness intact.
* Do not remove rare filters blindly.
* If reducing compile cost, prefer package split / lazy facade over semantic
  removal.
* `pdfglyphlist` should be considered for lazy decoding / loading if it
  initializes eagerly.

### PDF-3 layout / model / debug / tool boundary

* `doc_parse/pdf/inspect` is an inspect / report / dump package. It imports
  `api`, `model`, and `raw`, does not import `convert`, and does not enter
  normal parse.
* `doc_parse/pdf/layout_model_tool` is a dev / model-training / export tool
  package. It does not enter normal parse, but it depends on
  `convert/pdf_layout`, creating a `doc_parse` -> `convert` reverse dependency
  in a tool-only path.
* `convert/pdf_debug` is a debug bridge. It imports `convert/pdf`,
  `convert/pdf_layout`, `doc_parse/pdf/inspect`, and `doc_parse/pdf/model`, but
  does not enter normal conversion runtime.
* `convert/pdf_layout` is a layout model / export / infer bridge package. It
  imports `convert/pdf` and `doc_parse/pdf` APIs, but `convert/pdf` does not
  import `convert/pdf_layout`.
* Therefore the `convert/pdf_layout` package is not part of normal PDF
  conversion runtime.
* `convert/pdf` internal layout gate logic is normal runtime convert policy,
  but it is not the same as importing `convert/pdf_layout`.

### PDF-3 decisions

* Keep `doc_parse/pdf/inspect` separate and debug-only.
* Keep `convert/pdf_debug` separate and debug-only.
* Defer moving `doc_parse/pdf/layout_model_tool` until layout model / training
  replacement is stable.
* Defer splitting `convert/pdf_layout` into model / infer core versus TSV /
  export / spike / fs helpers.
* Do not let TSV / export / training surfaces enter parser runtime.

### PDF-3 deferred defects / risks

* `layout_model_tool` lives under `doc_parse/pdf` despite depending on
  `convert/pdf_layout`.
* `convert/pdf_layout` mixes model JSON, feature TSV, infer / render, export /
  spike, and fs / tool concerns.
* Inspect path-based dump / report facades may reopen / re-extract PDFs and
  should remain debug-only.
* The layout / model training route has quality-lab comments but no hard-coded
  runtime dependency.

### PDF-4 tests / whitebox / testdata findings

* PDF-related test code is large, roughly 31k+ lines across parser, convert,
  debug, layout, and vendored `mbtpdf` tests.
* Public parser / model tests, whitebox tests, debug tests, vendor tests,
  layout-model tests, product integration tests, and fixtures are all present.
* This affects test / check compile time, even when normal conversion runtime
  does not import the same heavy surfaces.

### PDF-4 test classification

* `doc_parse/pdf/model/test`: public model / parser tests; keep.
* `doc_parse/pdf/text/*_wbtest`: whitebox tests; keep, but not necessarily
  public default lane.
* `doc_parse/pdf/raw/*_wbtest`: whitebox tests; keep, but quality-lab fallback
  cleanup is deferred.
* `doc_parse/pdf/api/test`: public / debug mixed tests; keep, but heavy imports
  are deferred.
* `doc_parse/pdf/test`: debug / integration tests; keep, but sample dependency
  is a boundary smell.
* `doc_parse/pdf/inspect/*_wbtest`: debug tests; keep.
* `convert/pdf/*_wbtest` and `convert/pdf/test`: product / whitebox
  integration tests; keep.
* `convert/pdf_debug` and `convert/pdf_layout` tests: debug / layout-model
  tests; keep but dev-only split is deferred.
* Vendored `mbtpdf` tests: keep for vendor correctness, but a separate slow /
  heavy lane should be considered.

### PDF-4 pollution / dependency findings

* `samples/main_process/pdf` is referenced by parser and convert PDF tests;
  this is test-only but blurs parser-vs-product fixture boundaries.
* `markitdown-quality-lab/external_quality` fallback paths appear in several
  PDF tests and wbtests; these must remain optional and test-only.
* TSV / model / gold terms are mostly `convert/pdf_layout` feature / model
  surfaces, not parser runtime.
* No normal runtime dependency on benchmark / manifest / dashboard / matrix
  corpus was found in PDF tests.
* `doc_parse/pdf/testdata/pdfjs` fixtures are small repo-local parser fixtures
  and should remain.
* Larger fixtures and broad corpora belong in quality-lab, not main parser
  tests.
* Vendor testdata is mostly acceptable small fixtures, but `SFAA_Japanese.pdf`
  around 1.8 MB is a human-decision candidate for external-corpus relocation.

### PDF-4 compile-time test risks

* `convert/pdf/test` imports heavy vendor writer / operator / page / inspect
  packages.
* `doc_parse/pdf/api/test` imports `pdfwrite`, `pdfpage`, `pdfmarks`,
  `pdfdest`, and `inspect`.
* `doc_parse/pdf/raw` whitebox tests import `pdfopswrite` / `pdfwrite`.
* Vendor crypto / write / read tests pull `pdfcrypt`, `pdfwrite`, full
  `pdfread`, and rare codec paths.
* These are test / check cost risks, not normal runtime conversion risks.

### PDF-5 convert/pdf boundary findings

* `convert/pdf` is the PDF product conversion layer.
* It consumes `PdfDocumentModel` from `doc_parse/pdf/api` and owns line / block
  staging, heading / noise / merge / table / caption / link / image / layout
  gate / OCR gate / asset export / origin metadata / IR output policy.
* It does not import `doc_parse/pdf/raw` or vendored `mbtpdf` packages in
  normal runtime.
* Heavy vendor writer / operator / page imports in `convert/pdf` are test-only.
* `convert/pdf` does not import `convert/pdf_layout` or `convert/pdf_debug`.
* `convert/pdf` internal layout gate is normal runtime convert policy and is
  separate from the `convert/pdf_layout` model / export package.
* OCR / vision mode is a convert policy gate; non-disabled OCR modes fail
  closed unless runtime support is wired.

### PDF-5 convert/pdf status / risks

* Profile-only detail string construction is guarded behind profile `Some`;
  profile-disabled `convert/pdf` paths no longer build those details.
* `convert/pdf` public API is broad: many stage builders, decision helpers,
  intermediate structs, layout summaries / features, table / link / noise /
  merge helpers are exposed.
* Some broad API exists because `convert/pdf_debug`, `convert/pdf_layout`, and
  tests consume internal pipeline surfaces.
* `pdf_lines.mbt` combines line construction and image asset export policy; a
  future split may be useful but is not urgent.

### PDF-5 not-a-bug decisions

* Heading / noise / merge / table / caption / link / annotation / image /
  asset / OCR / layout / metadata / origin policy belongs in `convert/pdf`,
  not `doc_parse/pdf`.
* The `convert/pdf_layout` package remaining outside normal runtime is a
  healthy boundary.
* The `convert/pdf_debug` package remaining outside normal runtime is a
  healthy boundary.
* Parser model should stay source-oriented; Markdown / IR output remains
  convert-owned.

### PDF audit summary

* PDF-0 mapped `doc_parse/pdf` as a layered stack with runtime, raw, model,
  text, inspect, `layout_model_tool`, tests, and vendored `mbtpdf`.
* PDF-1 confirmed the normal runtime chain and initially identified outline
  second-open and `convert/pdf` profile detail overhead risks.
* PDF-2 identified vendor compile-size hotspots: `pdfpage`, `pdfcodec`,
  `pdfops`, `pdfglyphlist`, `core/pdf`, and related rare-filter / write
  surfaces.
* PDF-3 clarified debug / layout / tool boundaries: the `convert/pdf_layout`
  package is not normal runtime, but `layout_model_tool` has a tool-only
  `doc_parse` -> `convert` reverse dependency.
* PDF-4 identified heavy PDF test and whitebox closure risks, plus optional
  quality-lab fallback and fixture policy concerns.
* PDF-5 confirmed `convert/pdf` owns product conversion policy and does not
  mix raw / vendor parser responsibilities.
* PDF-6 outline second-open fix complete: raw extraction carries outlines from
  the first opened PDF object, `RawPdfDocumentExtract.outlines` feeds
  `PdfDocumentModel.outlines`, and normal extraction no longer reopens the PDF
  for bookmarks / outlines.
* Overall, PDF should remain a phased parser refactor target. PDF-6 outline
  second-open removal is complete; remaining parser-side work is around
  path-oriented API shape, full raw / text / model materialization, text / model
  multi-pass behavior, vendor compile-size / package closure, raw / model / text
  API breadth, and bytes / input-handle support.

### Confirmed runtime defects / risks

* Parser-facing PDF API is path-oriented; public `api` / `raw` entries accept
  filesystem paths rather than bytes or input handles.
* No broad bytes / input-handle PDF API exists yet.
* PDF extraction still uses full raw / text / model materialization.
* Raw ops -> chars -> spans -> lines -> blocks remains a staged multi-pass text
  pipeline; this is intentional but memory-heavy.
* `build_page_lines` performs multiple enrich / merge / filter passes and
  contains disabled debug helpers in the same file.
* `raw`, `model`, and `text` expose broad public surfaces; `convert/pdf` needs
  only a subset of this API.
* Vendor compile-size / package closure, including deflate / font / image / text
  extraction costs, remains a parser-side hotspot.

### Deferred defects / risks

* Normal runtime may compile more vendor code than strictly needed, including
  writer / crypto / rare filter / debug-adjacent surfaces.
* `api.extract_document_model` remains path / I/O oriented.
* `doc_parse/pdf/text` is large and may mix runtime extraction, rules, and
  helper / debug-adjacent logic.
* `layout_model_tool` depends on `convert/pdf_layout`, creating a
  `doc_parse` -> `convert` reverse dependency in a tool / model path.
* Inspect / debug surfaces are separate packages but must stay out of normal
  runtime.
* Public API surface across model / raw / text / vendor is broad.
* Test and whitebox paths reference samples / quality-lab fallback paths in
  test-only contexts; this needs PDF-4 review.

### Not-a-bug decisions

* Vendored `mbtpdf` may live under `doc_parse/pdf`, but the runtime-needed
  subset should be distinguished from the full vendor surface.
* Inspect and debug packages do not enter normal parse.
* `layout_model_tool` is separate from normal runtime, though its
  `convert/pdf_layout` dependency remains a tool-boundary issue.
* The `convert/pdf_layout` package does not enter normal PDF conversion
  runtime; only `convert/pdf`'s internal layout gate policy does.
* `convert/pdf` owns Markdown / IR / assets / link / table / heading / noise
  policy.
* Layout / model training and export are not normal parser runtime.
* PDF audit must be phased; do not perform large refactors without package
  dependency evidence.

### Future PDF audit plan

* PDF-1 runtime parser chain: `api`, `raw`, `text`, `model`, path I/O,
  profile / detail, and model-building scans.
* PDF-2 raw / vendor / compile-size: `pdfpage`, `pdfcodec`,
  `pdfops` / `pdfopsread`, `pdfglyphlist`, crypto / write / test-only closure.
* PDF-3 layout / model / debug / tool: `layout_model_tool`,
  `convert/pdf_layout`, `convert/pdf_debug`, and inspect boundary.
* PDF-4 tests / whitebox / testdata: quality-lab fallback, repo-local fixture
  policy, and wbtest dependencies.
* PDF-5 `convert/pdf` boundary: assets / link / table / heading / noise /
  layout gates versus parser model.

### PDF-2 future actions

* Do not refactor vendor without a measured package-closure plan.
* Highest-value future split: `document/pdfpage` read-only page tree versus
  edit / write / page-build helpers.
* Next split: `pdfcodec` common decode versus rare image filters / encode
  helpers.
* Next split: `graphics/pdfops` read / runtime operator types versus emit /
  write helpers if dependency graph confirms it.
* Consider `pdfglyphlist` lazy init.
* Continue PDF-3 layout / model / debug / tool audit before changing package
  graph.

### Future PDF-3 actions

* Move `layout_model_tool` to a tools or convert-side area after model
  replacement / training design stabilizes.
* Split `convert/pdf_layout` only when runtime model loading or a new layout
  model architecture requires it.
* Keep `convert/pdf_debug` out of normal runtime imports.
* Review PDF tests / whitebox / testdata next.

### Future PDF-4 actions

* Consider separating public / narrow PDF tests from heavy whitebox / vendor /
  debug tests if MoonBit package / test routing allows.
* Consider centralizing quality-lab fallback resolution into a test helper.
* Consider moving `SFAA_Japanese.pdf` to external corpus if repository fixture
  size policy requires it.
* Do not delete pdfjs annotation fixtures or `convert/pdf` integration tests
  without replacement coverage.
* Continue PDF-5 `convert/pdf` boundary audit next.

### Future PDF-5 actions

* Defer public API narrowing until debug / layout / test dependencies are
  reviewed.
* Consider splitting `pdf_lines` line model building from asset export only if
  it becomes a maintenance problem.
* Keep raw / vendor parsing out of `convert/pdf`.

### Future PDF-1 actions

* Defer bytes / input-handle PDF API until the vendor integration plan is clear.
* Revisit full raw / text / model materialization only with benchmark evidence.
* Continue PDF-2 vendor compile-size audit before broad refactor.

## 5. Cross-cutting parser issues

### Profile API public/internal boundary

JSON and YAML profile APIs are public today, but they mostly serve internal
parse-hotspot attribution. Their long-term public API status is unresolved.

### Recursion/depth guard

JSON, YAML, and XML all use recursive parsing for nested structures. A unified
depth-guard policy is still needed.

### Hot-path allocation

Some avoidable hot-path work has already been removed. Remaining allocation work
should be benchmark-driven instead of speculative.

### Inspect/profile public API

Inspect APIs are reasonable public debug and report surfaces. Profile APIs are
less clear because they expose internal attribution details.

### Convert layer parser-model consumption

`convert/json`, `convert/yaml`, `convert/xml`, and `convert/csv` consume parser
models. The `convert/csv` TSV path consumes `doc_parse/tsv`. `convert/markdown`
now consumes `doc_parse/markdown` scanner ranges while retaining conservative
passthrough output and convert-owned footnote policy.
