# Convert Defects and Deferred Decisions

This is an internal convert-layer tracking document. It is not a user-facing
support matrix.

It records known convert-layer boundary issues, performance risks, and deferred
architecture decisions. Current scope: Convert-0 global map.

## Convert-0 Global Map

### Status

- The convert layer owns parser-model-to-core-IR conversion, Markdown/IR output
  policy, assets, metadata/origin policy, OCR/provider gates, and format-level
  warnings/fallbacks.
- The normal entry is `convert/convert.parse_to_ir(input_path, opts)`.
- The dispatcher currently statically imports default format packages.
- Debug/tool/layout packages should stay out of normal runtime.

### Parser / Convert Contract Principle

- Convert does not have to consume a full parser model.
- Convert must not duplicate source parsing without reason.
- Product policy may remain convert-local.
- Contract choices include full model, token / event stream, query API, shared
  scanner / helper primitive, cache / index, and inventory / validation signal.
- Parser packages provide source facts; convert packages keep Markdown / IR /
  assets / origin policy.

### Package Map Summary

- `convert/convert`: dispatcher + tests.
- `convert/txt`, `convert/markdown`, `convert/json`, `convert/yaml`,
  `convert/xml`, `convert/csv`, `convert/html`: lightweight/medium format
  runtimes.
- `convert/zip`, `convert/zip_core`, `convert/zip_worker`: archive runtime and
  nested dispatch/asset remap.
- `convert/epub`: EPUB conversion, per-run part cache, and
  asset/link/origin policy.
- `convert/docx`, `convert/pptx`, `convert/xlsx`: Office format runtimes.
- `convert/pdf`: heavy PDF product conversion policy.
- `convert/pdf_debug`: debug-only bridge.
- `convert/pdf_layout`: layout model/export/infer bridge, not normal dispatcher
  runtime.
- `convert/vision`: OCR/provider/vision surface, not default dispatcher runtime.
- `convert/vision/tsv_preview_tool`: debug/tool surface.

### Confirmed Boundary Findings

- The dispatcher statically imports all default format runtime packages.
- `image-ocr` / `future-provider` registry entries are disabled by default and
  fail closed.
- `convert/pdf_debug`, `convert/pdf_layout`, and the vision TSV preview tool are
  not imported by normal dispatcher runtime.
- `convert/zip` imports `convert/pdf` for archive entry support, which can bring
  PDF compile closure into ZIP conversion paths.
- Normal `convert/pdf` does not import raw/vendor PDF internals directly.
- `samples/main_process` and quality-lab references are mainly tests/comments,
  not normal runtime dependencies.
- TSV/JSON/model surfaces are concentrated in `convert/pdf_layout` and vision
  OCR tooling.

### Performance / Compile-Size Hotspot Candidates

- `convert/pdf`: largest policy-heavy runtime package.
- `convert/pptx` and `convert/docx`: large Office conversion runtimes.
- `convert/html`: medium DOM lowering/runtime policy.
- `convert/vision`: large provider/OCR surface, not default dispatcher runtime.
- `convert/pdf_layout` and `convert/pdf_debug`: heavy but isolated tools/debug.
- `convert/convert` tests: heavy all-format origin metadata tests.

### Public API Risks

- `convert/vision` public surface is likely too broad.
- `convert/pdf` exposes many pipeline builders and decision helpers.
- `convert/pdf_layout` exposes model JSON, feature TSV, inference, and export
  surfaces together.
- `convert/zip_core` exposes archive traversal/remap/dispatch internals.
- `convert/xlsx` has compatibility model surface that may be wider than needed.

### Deferred Decisions

- Whether the dispatcher should remain all-format static or move toward
  slimmer/lazy/feature-specific package paths.
- Whether `convert/zip` should directly import `convert/pdf` or route through a
  dispatcher/capability boundary.
- How to keep debug/provider/layout tools out of normal runtime while
  preserving tests.
- How to narrow public pipeline APIs without breaking debug/layout/tests.

### Future Audit Plan

- Convert-1 dispatcher / registry / format boundary.
- Convert-2 lightweight formats: txt/markdown/json/yaml/xml/csv/tsv/html.
- Convert-3 archive/container formats: zip/zip_core/zip_worker/epub.
- Convert-4 Office formats: docx/pptx/xlsx.
- Convert-5 PDF runtime policy.
- Convert-6 OCR/vision/provider/debug/layout tools.
- Convert-7 metadata/assets/origin policy and samples/check alignment.

## Convert-1 Dispatcher / Registry / Format Boundary

### Status

- `convert/convert` is the unified conversion dispatcher.
- `parse_to_ir(input_path, opts)` detects a format from extension/registry and
  statically dispatches to format runtime packages.
- The dispatcher does not implement deep format conversion policy, but it does
  expose global `ConvertOptions`.
- `ConvertOptions` currently contains PDF-specific debug/profile/layout/OCR
  options, so the dispatcher/options surface is not fully format-neutral.

### Registry Model

- The registry is a static entry list.
- Default enabled entries include `docx`, `pdf`, `xlsx`, `pptx`, `html`,
  `csv`, `tsv`, `txt`, `xml`, `json`, `yaml`, `markdown`, `zip`, and `epub`.
- Disabled entries include `image-ocr` and `future-provider`.
- Extension matching is lower/trim plus linear scan over extensions.
- Unknown extensions and disabled entries fail closed as unsupported file type.
- Disabled provider/OCR entries do not import `convert/vision`.

### Confirmed Boundary Findings

- The dispatcher statically imports all default format runtime packages.
- Registry scan cost is small; the compile/link closure is the real risk.
- `convert/zip_core` acts as a nested archive dispatcher and statically imports
  multiple format converters.
- `convert/zip` directly imports `convert/pdf` for archive-entry PDF
  conversion, so ZIP conversion can pull the PDF closure.
- `convert/vision` is not statically imported by the dispatcher.
- `convert/pdf_debug`, `convert/pdf_layout`, and vision preview tools remain
  outside normal dispatcher runtime.
- No runtime samples/main_process, quality-lab, external_quality, benchmark,
  manifest TSV, or JSONL dependency was found in dispatcher/zip_core.

### Deferred Defects / Risks

- All-format static dispatcher can make light-format conversion compile/link
  with heavy PDF/Office/archive closures.
- ZIP nested dispatch currently increases closure size and format coupling.
- `convert/zip -> convert/pdf` is the strongest cross-format dependency smell.
- Global `ConvertOptions` carries PDF-specific options, making the common API
  less neutral.
- Public registry types expose `default_enabled`, notes, capabilities, and
  extension metadata; later registry shape changes become API-sensitive.

### Not-a-bug Decisions

- Dispatcher owning format selection is appropriate.
- Disabled provider/OCR entries failing closed is correct.
- The registry can remain static until format package boundaries are fully
  audited.
- Format-specific Markdown/IR/assets policy should remain in format packages,
  not dispatcher.

### Future Actions

- Defer dispatcher architecture changes until Convert-2 through Convert-6
  complete.
- Consider slimmer/lazy/feature-specific dispatcher packages only after
  measuring package closure cost.
- Revisit `convert/zip -> convert/pdf`; possible future designs include
  callback dispatch, entry-handler registry, or PDF-free archive runtime.
- Consider separating format-neutral `ConvertOptions` from format-specific
  option structs.
- Keep vision/provider/debug/layout tooling out of normal dispatcher runtime.

## Convert-2A Lightweight Format Runtimes

### Status

- `convert/txt` consumes `doc_parse/text`, owns plain-text-to-IR lowering,
  literal Markdown passthrough, origin policy, and profile reporting.
- `convert/markdown` consumes `doc_parse/markdown` scanner output for block
  inventory, frontmatter, fence, and HTML-candidate ranges.
- `convert/markdown` retains source-preserving passthrough output and
  convert-owned footnote policy.
- `convert/json` consumes `doc_parse/json` and lowers `JsonValue` to
  table/list/paragraph/code fallback IR.
- `convert/yaml` consumes `doc_parse/yaml` and lowers `YamlValue` to
  table/list/paragraph/code fallback IR.
- `convert/xml` consumes `doc_parse/xml` for safe structured XML lowering while
  keeping bytes decode / encoding sniff in convert.
- `convert/csv` consumes `doc_parse/csv` and `doc_parse/tsv`, owns CSV/TSV
  table output policy and text encoding fallback.
- Lightweight-1 profile timing guard complete for JSON/YAML/CSV/TSV.
- JSON/YAML/CSV/TSV consume parser models; no adapter is needed.
- JSON/YAML/CSV/TSV profile-disabled paths avoid `@env.now()`, detail
  construction, and profile-only timing.

### Confirmed Boundary Findings

- `json`, `yaml`, `txt`, `xml`, and `csv` mostly avoid reimplementing parser
  logic and rely on `doc_parse`.
- `convert/json` consumes `doc_parse/json`.
- `convert/yaml` consumes `doc_parse/yaml`.
- `convert/csv` consumes `doc_parse/csv`.
- The `convert/csv` TSV path consumes `doc_parse/tsv`.
- JSON/YAML/CSV/TSV profile-enabled behavior and detail strings are preserved,
  while profile-disabled paths skip timing-only work.
- `markdown` now relies on `doc_parse/markdown` scanner output for
  block/frontmatter/fence/HTML-candidate ranges while keeping convert-owned
  passthrough and footnote handling.
- `xml` performs encoding sniff/decode in convert, parses safe small XML once
  through `doc_parse/xml`, and lowers only conservative element trees.
- Unsafe, unsupported, complex, malformed, or large XML falls back to
  source-preserving fenced XML.
- Metadata/origin handling across these packages belongs to convert.
- JSON/YAML/CSV RichTable/table lowering belongs to convert, not parser.
- No runtime quality-lab, external_quality, benchmark, manifest TSV, or JSONL
  pollution was found.
- samples/main_process references are test-only.

### Quality Status

- JSON external quality rows pass: 1 row, failed 0.
- YAML external quality rows pass: 1 row, failed 0.
- CSV external quality rows pass: 15 rows, failed 0.
- TSV external quality rows: 0 rows, failed 0.

### Deferred Defects / Risks

- `txt` normal paths may still construct profile-only detail strings such as
  `bytes=`, `chars=`, or `blocks=`.
- Large JSON/YAML nested fallback can stringify large ASTs and allocate
  heavily.
- JSON/YAML uniform table detection can become hot for large arrays of objects.
- CSV/TSV table conversion is full-document/full-table memory behavior.
- CSV/TSV RichTable construction remains full-memory.
- CSV/TSV ragged or dense rows can expand output to the maximum observed column
  count.
- TSV external quality sample coverage is still missing.
- Source/license/hash strict quality metadata closure should be audited
  separately where not already closed.
- Markdown can still incur more than one scan when footnote-normalized output
  changes the text.
- Markdown still keeps convert-side normalize/split helpers around footnote and
  passthrough policy, so large files remain worth watching for repeated
  full-buffer work.
- XML still decodes the full byte buffer before parse/fallback.
- Large XML currently uses a conservative fallback threshold before parser-model
  lowering.
- XML structured lowering policy is intentionally narrow and may fall back for
  real XML with default namespaces, long attributes/text, markdown-fence text,
  or mixed content.
- XML-real status is `PARTIAL_ACCEPT_WITH_LICENSE_REVIEW`: CPython XML and IDPF
  PLS fixtures are strict accepted, while Microsoft RSS remains a runtime guard
  pending license review.

### Not-a-bug Decisions

- Markdown source-preserving passthrough is product policy, not a defect.
- XML conservative fallback is acceptable for unsupported, unsafe, complex, or
  large inputs.
- CSV/JSON/YAML table/list/stringify decisions are convert output policy.
- Encoding fallback for CSV belongs in convert because file bytes enter the
  product conversion layer.
- XML bytes decode / encoding sniff remains convert-owned because file bytes
  enter the product conversion layer there.

### Future Actions

- Consider narrow profile-detail hot-path fixes for `txt` and other remaining
  formats where profile-disabled paths still build profile-only details.
- Mature XML structured lowering only with explicit samples and real-corpus
  coverage.
- Close the Microsoft RSS license review before treating it as strict XML-real
  accepted.
- Keep samples/check and quality-lab concerns outside convert runtime.
- Continue Convert-2B with HTML and TSV boundary clarification.

## Convert-2B HTML / TSV Boundary

### HTML Status

- `convert/html` is a full HTML product conversion runtime.
- `parse_html` consumes `doc_parse/html` parser validation / security signals on
  the normal-size path and feeds them into the convert profile / report path.
- HTML-1 still reads HTML files, performs a private lightweight DOM / semantic
  scan, extracts body scope, skips script/style/head/noscript/noise, lowers
  content to core IR, and owns link/image/assets/origin/note/table/heading/list
  policy.
- HTML-2A shared primitive convergence is complete for attr / entity / raw-tag
  helpers.
- HTML-2B selective token / event traversal is complete for content-scope range
  selection.
- HTML-2C token-event skip ranges are complete for closed
  script/style/head/noscript elements in the main block scanner.
- HTML-2D inline/link/image primitive convergence is complete for inline tag
  dispatch, with href/src/alt/title attr and entity paths already routed through
  shared parser primitives.
- HTML-2D parser-analysis observability is complete in the HTML profile summary
  for attempted/used analysis, event scope, skip-range count, fallback reason,
  and large-input guard signals.
- HTML-2E table/list/note primitive convergence is complete where applicable:
  table/list structural matching uses parser-backed tag names, table span attrs
  use decoded parser attrs, and note/ref attr/entity paths stay parser-backed.
- HTML-2E profile hot-path audit is complete: disabled profile paths avoid HTML
  timing work, and enabled profiles report table/image/link/note conversion
  counters.
- Full DOM adoption is not the default target.
- Public API is still mostly narrow, though HTML-1 added parser-validation
  helper surface and HTML-2B / HTML-2C added token event / source-range helper
  surface that may be wider than ideal.

### HTML Boundary Findings

- `convert/html` now consumes `doc_parse/html` validation / security signals.
- HTML-1 keeps private `HtmlNode`, semantic byte traversal, inline parsing,
  table/list/note lowering, and body-scope/noise policy.
- This still duplicates some parser foundation responsibilities already present
  in `doc_parse/html`; HTML-2A now routes attr / entity / raw-tag helpers through
  shared low-level parser primitives while keeping output policy in convert.
- HTML-2B routes main / article / body scope tag traversal through parser token
  events and depth-aware matching helpers.
- HTML-2C routes closed script/style/head/noscript skip ranges through parser
  token event source ranges for the main block scanner.
- HTML-2D routes inline link/image tag-name decisions through parser-backed raw
  tag-name extraction while preserving link sanitize, redirect unwrap, image
  export, and table/list/note policy in convert.
- HTML-2E routes table/list structural tag matching through parser-backed
  tag-name extraction and keeps RichTable/list/note lowering policy in convert.
- Link/href handling, unsafe scheme filtering, redirect unwrap, image asset
  export, note definitions, block origin, and asset origin are convert policy.
- `script`, `style`, `head`, `noscript`, and noise skipping are conversion
  safety/output policy.
- HTML table/list/heading/body lowering belongs to convert/html.
- Large HTML currently skips parser validation to avoid parser + private-scan
  double work on very large inputs.

### HTML Deferred Defects / Risks

- HTML-1 small/normal inputs still run a parser-validation path plus private
  semantic scan / lowering path, but the parser analysis now also supplies token
  events for scope selection rather than adding a separate tokenizer pass.
- HTML-2A removed duplicated attr / entity / raw-tag helper logic from the
  unresolved list.
- HTML-2B removed the unresolved raw byte scope-selection traversal from the
  normal-size main path.
- HTML-2C removed normal-path raw close-tag lookup for closed
  script/style/head/noscript elements in the main block scanner; raw lookup
  remains fallback for large, malformed, unclosed, and inner-slice paths.
- HTML-2D removes remaining inline-link/image low-level tag dispatch from the
  unresolved primitive-convergence list and adds profile visibility for parser
  analysis adoption decisions.
- HTML-2E removes table/list/note low-level primitive convergence from the
  unresolved list where localized; broad semantic traversal remains convert
  policy.
- Remaining private semantic traversal byte matching is block / inline / table /
  list / note / noise product-policy traversal, not a reason to force full DOM
  adoption.
- Full parser DOM adoption is non-default and requires benchmark / quality
  proof.
- The HTML pipeline is multi-stage full-buffer behavior: read bytes,
  normalize/scope, note scan, DOM scan, block lowering, asset discovery/export.
- Large HTML intentionally skips parser validation, so parser signal coverage is
  not uniform across all input sizes.
- Repeated byte/tag scanning and case-insensitive matching can become hot on
  large HTML outside the scope-selection and main skip-range paths.
- Inline rendering may use string accumulation that can become hot for large
  inline spans.
- Entity decoding / unescape occurs across multiple inline/attr/table/pre
  paths.
- Local-heavy HTML can amplify filesystem and asset-map costs.
- `HtmlParserIssueSummary`, parser analysis, token event, and token source-range
  helper APIs may be wider public surface than needed for the long term.
- The `html_parser_validation` profile stage currently uses diagnostic
  `elapsed_ms=0` semantics rather than true stage timing.

### TSV Boundary

- TSV as input format is allowed.
- TSV is handled by `convert/csv.parse_tsv` ->
  `doc_parse/tsv.parse_tsv_document` -> shared `doc_parse/csv` delimiter
  parser.
- `convert/csv` owns TSV/CSV table output policy and RichTable lowering.
- TSV manifest/config/control files are not part of convert runtime.
- No convert runtime quality-lab, benchmark, manifest, or JSONL pollution was
  found for TSV.
- `samples/main_process/tsv` references are test/sample-only.

### Future Actions

- HTML-2A shared low-level parser primitive convergence is complete.
- HTML-2B selective token / event stream traversal is complete for content-scope
  range selection.
- HTML-2C token-event skip ranges are complete for closed
  script/style/head/noscript elements.
- HTML-2D inline/link/image primitive convergence and parser-analysis
  observability are complete.
- HTML-2E table/list/note primitive convergence and profile hot-path audit are
  complete.
- Consider narrowing or internalizing HTML-1 parser-validation helper surface
  once tests and profile/report hooks no longer need it.
- Continue only explicitly scoped HTML profile work after benchmark evidence.
- Keep TSV manifest/config/control policy outside convert runtime.
- Continue Convert-3 archive/container audit.

## Convert-3 Archive / Container Formats

### Status

- `convert/zip` is the ZIP public facade. It calls `convert/zip_core` and
  provides a PDF entry callback.
- `convert/zip_core` is the real archive conversion core: ZIP open/read,
  inspect plan, safe path policy, entry filtering, nested dispatch, temp
  staging, asset remap, Markdown aggregation, and origin policy.
- ZIP-1 inspect-plan/profile/cache cleanup complete: `ZipConversionPlan` reuses
  inspect + sorted plans, profile-disabled paths avoid profile-only
  details/stat traversal/`env.now`, and `ZipEntryByteCache` reduces repeated
  `read_entry` within one conversion.
- `convert/zip_worker` is an alternate worker/process-oriented ZIP facade. It
  calls `zip_core`, but delegates PDF entries through external CLI/process
  configuration instead of importing `convert/pdf`.
- `convert/epub` is the EPUB product conversion runtime. It consumes
  `doc_parse/epub`, handles spine/nav/toc/cover/content reading order, calls
  `convert/html` for XHTML/HTML body conversion, and owns
  asset/link/origin/warning policy.
- EPUB-1 per-run part cache is complete; materialization and cover reads use
  cached part bytes where applicable.
- External ZIP quality rows pass: 15 rows, failed 0.
- External EPUB quality rows pass: 16 rows, failed 0.

### Confirmed Boundary Findings

- `convert/zip_core` consumes `doc_parse/zip`; no parser integration problem
  remains.
- `ZipConversionPlan` reuses inspect + sorted plans instead of rebuilding /
  filtering / sorting them again in the parse path.
- ZIP profile-disabled paths avoid profile-only details/stat traversal and
  profile-only `env.now`.
- `ZipEntryByteCache` reduces repeated `read_entry` within one conversion,
  including the HTML local asset materialization path.
- `convert/zip_core` acts as a nested archive dispatcher and statically imports
  multiple format converters.
- `convert/zip` directly imports `convert/pdf`, so normal ZIP conversion can
  pull the PDF compile closure.
- `convert/zip_worker` does not import `convert/pdf`; it can route PDF entries
  through `MARKITDOWN_PDF_CLI` / worker CLI behavior, but normal dispatcher does
  not use it.
- `convert/epub` consumes `doc_parse/epub` and keeps package parsing below the
  convert layer.
- EPUB already consumes `doc_parse/epub`; no hybrid adapter is needed.
- `convert/epub` delegates body conversion to `convert/html`, while retaining
  EPUB-specific spine/nav/asset/link/origin policy.
- EPUB-1 per-run part cache is complete; materialization and cover reads use
  cached part bytes where applicable.
- ZIP and EPUB runtime do not reimplement ZIP/EPUB parser core; they use
  `doc_parse/zip` and `doc_parse/epub`.
- OPF manifest hits in EPUB are package semantics, not repo TSV/control
  manifest usage.
- Runtime quality-lab, external_quality, benchmark, TSV/JSONL corpus pollution
  was not found.

### Deferred Defects / Risks

- ZIP nested dispatch increases compile closure and cross-format coupling.
- `convert/zip -> convert/pdf` is the strongest archive-layer compile-size
  smell.
- ZIP conversion writes entries to temp files and calls path-based converters,
  so nested conversion is full-buffer and file-system heavy.
- ZIP HTML local image handling may materialize safe archive trees.
- ZIP/PDF support inside archive conversion needs a clearer capability or
  callback boundary.
- EPUB materializes safe archive trees and then feeds spine XHTML/HTML into
  `convert/html`, causing full-buffer staging and HTML lowering cost.
- EPUB safe tree materialization remains broad/full; selective materialization is
  deferred.
- EPUB asset remap/copy overhead remains a convert-side hotspot, and HTML asset
  path behavior must remain stable.
- ZIP temp staging/materialization and asset remap copies remain convert-side
  hotspots even after the per-run entry byte cache.
- ZIP streaming conversion remains deferred.
- `zip_worker` adoption by the normal dispatcher remains deferred.
- EPUB profile detail strings may still be built on normal paths.
- ZIP source/license/hash strict quality metadata closure should be audited
  separately if not already complete.
- EPUB source/license/hash strict quality metadata closure should be audited
  separately if not already complete.
- `convert/zip_core` public API is broad: inspect structs, profile structs,
  path helpers, staging helpers, asset remap helpers, and aggregation helpers.
- `convert/zip` and `convert/zip_worker` duplicate or convert `zip_core`
  inspect/profile structs.

### Not-a-bug Decisions

- ZIP unsafe path, absolute path, collision, nested archive, entry count, and
  entry size handling belong to archive convert policy.
- EPUB reading-order-to-Markdown, asset remap/export, link rewrite, warnings,
  and origin metadata belong to convert/epub.
- External EPUB resources are preserved or warned about, not fetched.
- EPUB calling `convert/html` for content documents is currently the correct
  product conversion boundary.
- EPUB repeated `read_part` for materialization / cover in the same conversion
  run is no longer tracked as an unresolved defect after EPUB-1 cache work.
- ZIP repeated inspect plan rebuild/sort, profile-disabled detail/stat
  traversal, and repeated `read_entry` for localized asset materialization are
  no longer tracked as unresolved defects after ZIP-1.
- Do not remove archive PDF support without replacement coverage.

### Future Actions

- Do not fix `zip -> pdf` until dispatcher and archive entry-handler design is
  clear.
- Consider a future ZIP entry-handler registry or callback architecture.
- Consider making normal `convert/zip` PDF-free or worker-backed if compile
  closure measurements justify it.
- Consider narrowing `zip_core` public helpers after tests/facades are
  reviewed.
- Consider profile-detail hot-path fixes for EPUB together with other convert
  formats.
- Keep ZIP streaming and `zip_worker` adoption deferred until dispatcher /
  capability design is explicit.
- Keep EPUB selective materialization deferred until asset path behavior and
  quality rows can prove no output drift.
- Continue Convert-4 Office formats next.

## Convert-4 Office Formats

### Status

- `convert/docx` is the DOCX product conversion layer. It opens the DOCX
  package once, consumes `doc_parse/docx` typed source/model output, and
  owns DOCX-to-core-IR output policy without v1 fallback.
- DOCX body paragraph / run / table / media / notes / comments / header /
  footer / textbox lowering is owned by `convert/docx`.
- The old DOCX v1 runtime directories were removed in commit `8ed4a3b`; normal
  DOCX conversion no longer depends on `convert/docx` or `doc_parse/docx`.
- `convert/pptx` is the PPTX product conversion layer. PPTX-1 hybrid adapter is
  complete: it opens the PPTX package once, reuses the same `OoxmlPackage`,
  consumes `doc_parse/pptx` parser inventory summary, and owns PPTX-to-core-IR
  output policy.
- Legacy PPTX slide / text / table / image / asset / notes / comments / output
  lowering remains in `convert/pptx`.
- PPTX chart conversion reuses the parsed `PptxPresentation` instead of
  reparsing the full deck per chart slide.
- `convert/xlsx` is the XLSX product conversion layer. It already consumes
  `doc_parse/xlsx` as its primary workbook semantic source, then owns
  sheet/table/RichTable/output policy.
- No DOCX/PPTX-style hybrid adapter is needed for XLSX.
- XLSX-1C performance guard complete: profile-disabled paths avoid
  profile-only detail/stat traversal, and huge sparse used-range outputs are
  bounded by a dense-area guard.

### Model Integration Findings

- DOCX replacement is complete for the checked normal runtime surface;
  `convert/docx` consumes the full typed `DocxDocument` model.
- The typed model preserves source/model facts for paragraphs, runs, tables,
  merged and nested cells, numbering/list hints, notes, comments, headers,
  footers, textboxes, drawings, VML shapes, media, fields, math, tracked
  changes, content controls, smart tags, and content-bearing unknowns.
- Runtime parity is guarded by v2 parser/lowering tests, main-process samples,
  quality rows, and the post-v1-removal route/dependency guard.
- Remaining DOCX product limits are explicit policy boundaries such as Word
  layout fidelity, field evaluation, OMML conversion, and full tracked-change
  rendering; unsupported constructs should surface through typed warnings or
  placeholders, not fallback to the old scanner.
- PPTX-1 hybrid adapter is complete; `convert/pptx` consumes parser inventory
  summary rather than full `PptxPresentation` lowering.
- PPTX-2 should gradually replace legacy parser-like slide / text / table /
  media / notes / comments output paths with `PptxPresentation` consumption.
- XLSX consumes `doc_parse/xlsx.XlsxWorkbook` as the primary parser model.
- XLSX already consumes `doc_parse/xlsx`; XLSX-1C performance guard work is
  complete, so future XLSX work should focus on remaining memory and metadata
  closure risks rather than architecture wiring.
- This means Office integration maturity differs by format: DOCX and XLSX are
  accepted parser/model-driven runtimes, while PPTX still uses the PPTX-1
  hybrid adapter pending full `PptxPresentation` lowering.

### DOCX Validation Status

- Main repo DOCX parser tests, convert tests, and `samples/check.sh --format
  docx` pass.
- External DOCX quality rows pass: 60 rows, failed 0.
- Full replacement validation at adoption passed `moon check`, `moon test`,
  `samples/check.sh`, and `samples/check_quality.sh` with DOCX routed through
  `convert/docx`.
- Previous stale footnote / endnote appendix expectations were synced to the
  current Markdown note definition policy.

### PPTX Validation Status

- Main repo PPTX parser tests, convert tests, and `samples/check.sh --format
  pptx` pass.
- Main repo PPTX sample coverage passes: markdown 79 rows, metadata 16 rows,
  assets 13 rows, failed 0.
- External PPTX quality rows pass: 55 rows, failed 0.

### XLSX Validation Status

- XLSX-1C validation passed: parser tests, convert tests, and
  `samples/check.sh --format xlsx` pass.
- External XLSX quality rows pass: 51 rows, failed 0.
- Normal XLSX output and quality rows pass after the profile hot-path and dense
  sparse guard changes.

### Convert Policy Boundary

- DOCX heading/list/table/media/comments/notes/header/footer rendering belongs
  in `convert/docx`.
- PPTX slide ordering, text/image/chart/table/notes rendering belongs in
  `convert/pptx`.
- XLSX sheet/table/date/number/formula display/output policy belongs in
  `convert/xlsx`.
- Metadata/origin/assets policy belongs in convert.
- Parser packages should remain source-model providers, not Markdown/IR
  renderers.

### Deferred Defects / Risks

- DOCX still needs periodic performance snapshots on large and media-heavy
  documents, because the old v1 runtime has been removed and parity checks no
  longer compare against a live scanner.
- Keep future DOCX inventory/debug additions out of profile-disabled normal
  conversion paths.
- Complex Word layout fidelity, arbitrary-depth nested table rendering,
  object/chart/smart-art/audio/video rendering, field evaluation, OMML
  conversion, and full tracked-change semantics remain explicit product
  limits.
- DOCX asset export, origin metadata, and output policy remain convert-owned.
- DOCX quality metadata strict source / license closure should be audited
  separately if not already complete.
- PPTX normal conversion currently has parser + legacy dual-read / dual-model
  cost while PPTX-2 remains deferred.
- `pptx_parser_inventory` should remain an inventory / profile helper and not
  grow into a third full PPTX model.
- PPTX slide / text / table / image / asset / notes / comments / output
  lowering remains legacy convert logic.
- PPTX asset export, origin metadata, and output policy remain convert-owned.
- PPTX quality metadata strict source / license closure should be audited
  separately if not already complete.
- PPTX still repeats parser-like OOXML logic for slide relationships,
  shape/text/media/notes/comments/table parsing, plus reading order/grouping
  policy.
- PPTX full `PptxPresentation` output lowering is deferred because output
  behavior must be preserved deliberately.
- DOCX/PPTX may perform repeated part reads and heavy XML string scanning.
- PPTX chart paths may still rebuild renderable chart blocks from parser model
  data, but they no longer reparse the full deck per chart slide.
- XLSX keeps a convert-side compatibility model copied from the semantic
  workbook, which can duplicate memory alongside parser model data.
- XLSX still materializes the full workbook / full cell model before conversion.
- For normal guarded-in ranges, XLSX builds dense `table_rows` and full-memory
  `RichTable` values from parsed cells; large genuinely dense sheets remain
  memory-heavy.
- Huge sparse used-range outputs are now bounded by the XLSX-1C dense-area
  guard instead of expanding into unbounded far-edge dense row arrays.
- XLSX style / date display formatting may have cache opportunities if real
  samples show repeated format work.
- XLSX comments, table output, formula hints, merged-cell hints, metadata, and
  origin policy remain convert-owned.
- XLSX quality metadata strict source / license closure should be audited
  separately if not already complete.
- PPTX may still construct profile-only detail strings on normal paths; DOCX
  and XLSX should keep profile-disabled paths free of profile-only detail/stat
  traversal.
- `convert/xlsx` exposes a broader compatibility model/profile API surface than
  DOCX/PPTX.

### Not-a-bug Decisions

- Do not restore DOCX fallback/oracle paths; future DOCX changes should extend
  v2 typed model coverage and convert-owned lowering directly.
- Do not force PPTX full parser-source lowering without a product-output
  migration plan.
- XLSX consuming `doc_parse/xlsx` is the preferred long-term shape, but it
  should not be used as a reason to rush PPTX migration.
- No PPTX-style hybrid adapter is needed for XLSX.
- DOCX/PPTX/XLSX rendering policy belongs in convert, not doc_parse.
- Existing samples/main_process references are test-only and not runtime
  pollution.

### Future Actions

- DOCX follow-up: keep v2 parser/lowering changes output-stable,
  benchmark-backed, and covered by typed parser tests, convert tests,
  main-process DOCX samples, and DOCX quality rows.
- DOCX follow-up: maintain the deep-table guard and explicit warning /
  placeholder policy for unsupported WordprocessingML instead of restoring
  legacy scanner behavior.
- DOCX follow-up: keep asset export/path policy in `convert/docx` and source
  facts in `doc_parse/docx`.
- PPTX-2: gradually replace legacy parser-like PPTX output paths with
  `PptxPresentation` model consumption while preserving output compatibility.
- Preserve output compatibility before replacing convert-owned OOXML paths.
- XLSX follow-up: focus on remaining full workbook/full cell memory,
  compatibility model surface, style/date cache opportunities, and quality
  metadata closure while preserving current XLSX output.
- Consider narrow profile-detail hot-path fixes later for formats that still
  need them.
- Review repeated part reads / relationship indexes only with Office benchmark
  evidence.
- Continue Convert-5 PDF runtime policy next.

## Convert-5 PDF Runtime Policy

### Status

- `convert/pdf` is the PDF product conversion strategy layer.
- It consumes `PdfDocumentModel` from
  `doc_parse/pdf/api.extract_document_model`.
- It owns line/block staging,
  heading/noise/merge/table/caption/link/annotation/image/assets/OCR/layout
  gate/metadata/origin/IR output policy.
- It does not directly import `doc_parse/pdf/raw` or vendored `mbtpdf` in
  normal runtime.
- `convert/pdf_layout` and `convert/pdf_debug` do not enter normal
  `convert/pdf` runtime.
- PDF-6 outline second-open fix complete.
- PDF-7C profile-disabled timing guard complete.
- `convert/pdf` output unchanged by PDF-6.
- External PDF quality rows pass: 76 rows, failed 0, skipped 1.

### Confirmed Boundary Findings

- `convert/pdf` imports `core`, `doc_parse/pdf/model`, `doc_parse/pdf/api`,
  `doc_parse/pdf/text`, and runtime fs/env/sys dependencies.
- Heavy vendor writer/operator/page dependencies are test-only through
  `convert/pdf/test`.
- `convert/pdf_layout` and `convert/pdf_debug` import `convert/pdf`, not the
  other way around.
- `convert/pdf` internal layout gate is normal runtime convert policy, but it
  is not the same as importing `convert/pdf_layout`.
- OCR/vision mode gate is convert policy; non-disabled modes fail closed unless
  runtime support is wired.
- Heading/noise/merge/table/caption/link/annotation/form/outline/image/assets/metadata/origin
  policy belongs in convert/pdf, not parser/raw/vendor.
- Normal model extraction no longer reopens the PDF for outlines/bookmarks;
  outlines arrive through `PdfDocumentModel.outlines`.

### Profile Hot-Path Status

- PDF-7C profile-disabled timing guard is complete.
- `convert/pdf` profile-disabled paths avoid `@env.now()`, elapsed calculation,
  no-op `pdf_convert_profile_add_stage(..., None)`, and profile-only detail
  construction.
- Profile-enabled stage names, elapsed timing, and detail strings are preserved.

### Deferred Defects / Risks

- The conversion pipeline is multi-stage and full materialization heavy:
  model -> lines -> blocks -> classify -> layout gate -> noise -> merge -> link
  attach -> IR.
- Hotspot candidates include table detection, merge, layout text signals,
  layout gate, line/block construction, classification, and layout features.
- `pdf_lines.mbt` combines line construction with image asset export policy;
  future split may improve maintainability.
- `convert/pdf` public API is broad because stage builders, decision helpers,
  layout features, and intermediate structs are exposed for tests/debug/layout.
- Layout gate / model split remains deferred.
- Vendor compile-size split remains a parser/vendor package-closure track.
- Heavy PDF test lane remains deferred.
- ZIP -> PDF closure remains a separate dispatcher/archive issue.

### Future Actions

- Keep raw/vendor parsing out of convert/pdf.
- Defer public API narrowing until debug/layout/test dependencies are reviewed.
- Consider splitting `pdf_lines.mbt` only if maintenance or profiling justifies
  it.
- Revisit layout gate/model split only with replacement model design.
- Defer vendor package split until a parser/vendor package-closure plan exists.
- Keep ZIP -> PDF closure tracked outside `convert/pdf` runtime policy.
- Continue Convert-6 OCR/vision/provider/debug/layout tools next.

## Convert-6 OCR / Vision / Provider / Debug / Layout Tools

### Status

- `convert/vision` is the OCR / vision foundation package. It includes
  Tesseract TSV parsing/invocation, OCR page/layout models, line
  resegmentation, layout recovery, OCR-to-IR/Markdown helpers, and IR hint TSV
  output.
- `convert/vision/tsv_preview_tool` is an OCR TSV preview CLI tool.
- `convert/pdf_debug` is a PDF debug bridge for inspect/debug/layout assist.
- `convert/pdf_layout` is a PDF layout model / feature export / inference
  bridge with model JSON and feature TSV surfaces.
- `doc_parse/pdf/layout_model_tool` is a dev/model export/infer CLI under
  `doc_parse`, but it depends on `convert/pdf_layout`.

### Normal Runtime Boundary

- The normal dispatcher does not import `convert/vision`, `convert/pdf_debug`,
  or `convert/pdf_layout`.
- `convert/pdf` does not import `convert/pdf_layout` or `convert/pdf_debug`.
- ZIP, EPUB, and Office converters do not import these tool/debug/provider
  packages.
- Disabled registry entries such as `image-ocr` and `future-provider` do not
  pull `convert/vision`.
- These risks are mostly dev/tool/debug compile-lane risks, not normal
  conversion runtime risks.

### Confirmed Boundary Findings

- `doc_parse/pdf/layout_model_tool -> convert/pdf_layout` is a real
  `doc_parse -> convert` reverse dependency, but it is tool-only.
- `convert/vision` public surface is broad: model types, Tesseract TSV parsing,
  process invocation, layout recovery, IR/Markdown rendering, and TSV hint
  export.
- `convert/pdf_layout` mixes model JSON parsing/validation, feature TSV
  rendering/parsing, inference, export/spike logic, and filesystem helpers.
- `convert/pdf_debug` is properly separate but depends on parser inspect and
  convert layout/debug surfaces.
- TSV usage here is model/tool data: Tesseract TSV, OCR hint TSV, and PDF
  layout feature TSV. It is not convert runtime manifest/config pollution.
- `gold_label` and similar fields are layout model/evaluation data, not
  main-repo benchmark/control manifests.

### Deferred Defects / Risks

- `doc_parse/pdf/layout_model_tool` lives under `doc_parse` despite depending
  on convert-side layout model code.
- `convert/vision` needs a future provider/API boundary review before
  cloud/OCR integrations expand.
- `convert/pdf_layout` should eventually split model/infer core from
  TSV/export/spike/fs helpers if runtime model loading becomes real.
- Debug/layout assist public APIs may be wider than needed.
- Tesseract invocation and TSV parsing are full-buffer/tool-style paths.
- `layout_recovery.mbt` may become hot in OCR-heavy workflows.

### Not-a-bug Decisions

- Keeping these packages out of normal dispatcher/runtime is correct.
- Keeping `convert/pdf_debug` debug-only is correct.
- Keeping disabled OCR/provider registry entries fail-closed is correct.
- Do not move layout/model training/export surfaces into parser runtime.
- Do not wire cloud/provider runtime paths without explicit provider boundary
  design.

### Future Actions

- Move `doc_parse/pdf/layout_model_tool` to a tools or convert-side area only
  after layout model/training replacement stabilizes.
- Split `convert/pdf_layout` only when runtime layout model loading or new
  training architecture requires it.
- Keep `convert/pdf_debug` out of normal runtime imports.
- Defer `convert/vision` public API narrowing until provider architecture is
  clearer.
- Continue Convert-7 metadata/assets/origin policy summary next.

## Convert-7 Metadata / Assets / Origin Policy Summary

### Status

- Metadata, asset export, link rewrite, and origin/source mapping are
  convert-layer responsibilities.
- Parser models should remain source-oriented; final Markdown/IR/sidecar output
  policy belongs to convert and core metadata.
- Most formats now follow this boundary, though implementation is distributed
  across format-specific converters.

### Metadata / Origin Policy Map

- `txt`: paragraph/block origin from text line numbers; no assets.
- `markdown`: conservative passthrough with block/footnote origin; no assets.
- `markdown-real` status is `ACCEPT_STRICT`: Python-Markdown footnotes docs,
  BSD-3-Clause, 5126 bytes, sha256
  `cb52027428746e19dd82f01f84911fa2f89e5e5107011e116e073f17482e4c33`.
- `json` / `yaml`: parser model lowering with `$` / key-path and line-based
  origin; RichTable/List/CodeBlock origin belongs to convert.
- `xml`: convert-owned bytes decode, `doc_parse/xml` parser-model consumption
  for safe structured lowering, and source-preserving fenced fallback with
  whole-document line origin for unsupported / complex / large inputs.
- `csv` / `tsv`: RichTable origin with row/column ranges; TSV is input format,
  not manifest/control.
- `html`: consumes `doc_parse/html` validation / security signals on normal-size
  inputs while keeping private DOM/semantic lowering with
  block/link/image/table/note origin and local image asset policy.
- `html-real` status is `PARTIAL_ACCEPT_WITH_LICENSE_REVIEW`: MDN `main` /
  `article` rows are strict accepted (`CC-BY-SA`), while MarkItDown blog / SERP
  and Pandoc biblio remain runtime-guard rows pending license review.
- `zip`: archive entry aggregation, nested origin rewriting, and nested asset
  remap.
- `epub`: consumes `doc_parse/epub`, uses a per-run part cache for repeated
  conversion part reads, owns spine/nav/toc/cover/content origin, delegates body
  conversion to `convert/html`, and remaps origins/assets.
- `docx`: paragraph/run/table/notes/comments/header/footer/media origin from
  OOXML direct logic.
- `pptx`: consumes `doc_parse/pptx` parser inventory summary while keeping
  slide/shape/text/image/table/chart/notes/comments origin and asset policy in
  convert; chart path reuses the parsed `PptxPresentation`.
- `xlsx`: consumes `doc_parse/xlsx`; sheet/cell/table/formula/merged/style
  metadata belongs to convert output policy.
- `pdf`: page/block/table/link/annotation/form/outline/image origin and asset
  origin with page/object/source image/caption signals.

### Asset Export Policy Map

- Formats without asset export: `txt`, `markdown`, `json`, `yaml`, `xml`,
  `csv`, `tsv`, `xlsx`.
- Formats with asset export: `html`, `zip`, `epub`, `docx`, `pptx`, `pdf`.
- Asset sources include HTML local images, archive/EPUB remapped child assets,
  DOCX/PPTX media relationships, and PDF embedded images.
- HTML/EPUB/ZIP perform the most link/path rewriting and archive-local
  remapping.
- Asset origins are recorded through core document asset-origin APIs and include
  fields such as source name/path, key path, relationship id, page/slide/sheet/
  cell, object ref, and nearby caption where available.

### Duplicated Logic Candidates

- Asset path generation and collision handling.
- Media/asset remap between ZIP and EPUB.
- Link rewrite and href normalization between HTML/EPUB/ZIP.
- Origin and asset-origin construction helpers.
- RichTable/table metadata hint construction.
- Profile stage/detail helper patterns.

### Boundary Risks

- Convert policy is distributed across many format packages; this is acceptable
  but makes consistency harder.
- Core metadata knows some format-level source_kind and table hint details;
  acceptable short-term, but schema policy should be explicit.
- Parser models mostly remain source-oriented; XLSX date/number/formula
  semantics are thick but still source-model signals.
- Future metadata schema changes can affect many samples/main_process metadata
  snapshots.
- TSV/JSONL uses in OCR/layout tooling are model/tool data, not convert runtime
  manifest/control pollution.

### Samples / Expected Impact

- Metadata expected coverage exists across
  CSV/TSV/JSON/YAML/XML/Markdown/HTML/ZIP/EPUB/DOCX/PPTX/XLSX/PDF.
- `txt` sidecar coverage is weaker than Markdown output coverage.
- Changes to `links`, `assets`, `blocks`, RichTable hints, or asset origin can
  affect many snapshots.
- Any metadata schema unification should be planned separately from runtime
  refactors.

### Future Actions

- Defer shared helper extraction until repeated patterns are stable.
- Consider shared origin / asset-origin builders only when they reduce
  duplication without hiding format semantics.
- Consider shared archive asset remap helper for ZIP/EPUB.
- Consider shared profile-stage helper after all profile hot-path fixes are
  complete.
- Keep parser models source-oriented and keep final metadata/asset/origin policy
  in convert/core.

## Convert Audit Summary

- Convert-0 mapped the convert layer and identified static dispatcher, ZIP/PDF
  closure, tool/debug/provider isolation, and public API risks.
- Convert-1 audited dispatcher/registry and deferred all-format static closure
  changes.
- Convert-2A audited lightweight formats, recorded JSON/YAML/CSV/TSV parser
  model consumption plus Lightweight-1 profile timing guard completion, and
  kept deferred depth/stringify/table-memory/quality-closure risks visible.
- Convert-2B audited HTML/TSV and recorded HTML-1 parser-validation
  integration, remaining dual-path/private-lowering risks, and HTML-2A shared
  primitive convergence completion.
- Convert-3 audited archive/container formats and recorded ZIP nested dispatch
  plus ZIP -> PDF closure as deferred; ZIP-1 inspect-plan/profile/cache cleanup
  is complete with external ZIP quality rows passing 15/15; EPUB already
  consumes `doc_parse/epub`, and EPUB-1 per-run part cache is complete with
  external EPUB quality rows passing 16/16.
- Convert-4 audited Office formats and now records DOCX accepted runtime
  adoption, PPTX-1 hybrid adapter completion with PPTX-2 full model lowering
  deferred, and XLSX accepted parser-model integration plus XLSX-1C performance
  guard completion.
- Convert-5 audited PDF runtime policy and confirmed raw/vendor parser
  boundaries, PDF-7C profile-disabled timing guard completion, PDF-6 outline
  second-open fix completion, profile-enabled stage/detail preservation, and
  external PDF quality rows passing 76 rows with failed 0 and skipped 1.
- Convert-6 audited OCR/vision/debug/layout tools and confirmed they are
  outside normal runtime.
- Convert-7 summarized metadata/assets/origin policy and deferred shared helper
  extraction.
- Overall: convert layer first-pass audit is complete. The next safe code work
  should be small remaining profile hot-path fixes or explicitly scoped
  architecture changes, not broad rewrites.
