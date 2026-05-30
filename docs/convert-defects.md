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

### Package Map Summary

- `convert/convert`: dispatcher + tests.
- `convert/txt`, `convert/markdown`, `convert/json`, `convert/yaml`,
  `convert/xml`, `convert/csv`, `convert/html`: lightweight/medium format
  runtimes.
- `convert/zip`, `convert/zip_core`, `convert/zip_worker`: archive runtime and
  nested dispatch/asset remap.
- `convert/epub`: EPUB conversion and asset/link/origin policy.
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
- `convert/markdown` is a conservative Markdown passthrough converter. It does
  not currently consume `doc_parse/markdown`.
- `convert/json` consumes `doc_parse/json` and lowers `JsonValue` to
  table/list/paragraph/code fallback IR.
- `convert/yaml` consumes `doc_parse/yaml` and lowers `YamlValue` to
  table/list/paragraph/code fallback IR.
- `convert/xml` consumes `doc_parse/xml` for safe structured XML lowering while
  keeping bytes decode / encoding sniff in convert.
- `convert/csv` consumes `doc_parse/csv` and `doc_parse/tsv`, owns CSV/TSV
  table output policy and text encoding fallback.

### Confirmed Boundary Findings

- `json`, `yaml`, `txt`, `xml`, and `csv` mostly avoid reimplementing parser
  logic and rely on `doc_parse`.
- `markdown` performs conservative passthrough/block/footnote scanning in
  convert; this is currently convert policy, not a full Markdown parser.
- `xml` performs encoding sniff/decode in convert, parses safe small XML once
  through `doc_parse/xml`, and lowers only conservative element trees.
- Unsafe, unsupported, complex, malformed, or large XML falls back to
  source-preserving fenced XML.
- Metadata/origin handling across these packages belongs to convert.
- JSON/YAML/CSV RichTable/table lowering belongs to convert, not parser.
- No runtime quality-lab, external_quality, benchmark, manifest TSV, or JSONL
  pollution was found.
- samples/main_process references are test-only.

### Deferred Defects / Risks

- `convert/markdown` not consuming `doc_parse/markdown` is a deferred
  architecture decision.
- `txt`, `json`, `yaml`, and `csv` normal paths may still construct
  profile-only detail strings such as `bytes=`, `chars=`, `blocks=`, or
  `rows=`.
- Large JSON/YAML nested fallback can stringify large ASTs and allocate
  heavily.
- JSON/YAML uniform table detection can become hot for large arrays of objects.
- CSV/TSV table conversion is full-document/full-table memory behavior.
- Markdown passthrough keeps source while scanning lines/blocks/footnotes; large
  Markdown can incur multiple scans.
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

- Markdown conservative passthrough is acceptable until a separate design
  connects `doc_parse/markdown`.
- XML conservative fallback is acceptable for unsupported, unsafe, complex, or
  large inputs.
- CSV/JSON/YAML table/list/stringify decisions are convert output policy.
- Encoding fallback for CSV belongs in convert because file bytes enter the
  product conversion layer.
- XML bytes decode / encoding sniff remains convert-owned because file bytes
  enter the product conversion layer there.

### Future Actions

- Consider narrow profile-detail hot-path fixes for `txt`, `json`, `yaml`, and
  `csv`.
- Decide separately whether `convert/markdown` should consume
  `doc_parse/markdown`.
- Mature XML structured lowering only with explicit samples and real-corpus
  coverage.
- Close the Microsoft RSS license review before treating it as strict XML-real
  accepted.
- Keep samples/check and quality-lab concerns outside convert runtime.
- Continue Convert-2B with HTML and TSV boundary clarification.

## Convert-2B HTML / TSV Boundary

### HTML Status

- `convert/html` is a full HTML product conversion runtime.
- It reads HTML files, performs a private lightweight DOM / semantic scan,
  extracts body scope, skips script/style/head/noscript/noise, lowers content to
  core IR, and owns link/image/assets/origin/note/table/heading/list policy.
- It is not a simple `doc_parse/html` model-to-IR adapter.
- Public API is narrow; most internal surfaces are private.

### HTML Boundary Findings

- `convert/html` does not currently consume `doc_parse/html`.
- It maintains private `HtmlNode`, tag scanning, inline parsing, entity decode,
  table/list/note lowering.
- This duplicates some parser foundation responsibilities already present in
  `doc_parse/html`, but the private scanner is tightly coupled to output
  policy.
- Link/href handling, unsafe scheme filtering, redirect unwrap, image asset
  export, note definitions, block origin, and asset origin are convert policy.
- `script`, `style`, `head`, `noscript`, and noise skipping are conversion
  safety/output policy.
- HTML table/list/heading/body lowering belongs to convert/html.

### HTML Deferred Defects / Risks

- Whether `convert/html` should consume `doc_parse/html` is a deferred
  architecture decision.
- The HTML pipeline is multi-stage full-buffer behavior: read bytes,
  normalize/scope, note scan, DOM scan, block lowering, asset discovery/export.
- Repeated byte/tag scanning and case-insensitive matching can become hot on
  large HTML.
- Inline rendering may use string accumulation that can become hot for large
  inline spans.
- Entity decoding / unescape occurs across multiple inline/attr/table/pre
  paths.
- Local-heavy HTML can amplify filesystem and asset-map costs.
- `html_parser.mbt` may still construct profile-only detail strings such as
  `bytes=`, `blocks=`, or asset counts on normal paths.

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

- Defer `convert/html` / `doc_parse/html` unification until product output
  behavior is explicitly designed.
- Consider narrow profile-detail hot-path fixes for HTML together with other
  lightweight formats.
- Keep TSV manifest/config/control policy outside convert runtime.
- Continue Convert-3 archive/container audit.

## Convert-3 Archive / Container Formats

### Status

- `convert/zip` is the ZIP public facade. It calls `convert/zip_core` and
  provides a PDF entry callback.
- `convert/zip_core` is the real archive conversion core: ZIP open/read,
  inspect plan, safe path policy, entry filtering, nested dispatch, temp
  staging, asset remap, Markdown aggregation, and origin policy.
- `convert/zip_worker` is an alternate worker/process-oriented ZIP facade. It
  calls `zip_core`, but delegates PDF entries through external CLI/process
  configuration instead of importing `convert/pdf`.
- `convert/epub` is the EPUB product conversion runtime. It consumes
  `doc_parse/epub`, handles spine/nav/toc/cover/content reading order, calls
  `convert/html` for XHTML/HTML body conversion, and owns
  asset/link/origin/warning policy.

### Confirmed Boundary Findings

- `convert/zip_core` acts as a nested archive dispatcher and statically imports
  multiple format converters.
- `convert/zip` directly imports `convert/pdf`, so normal ZIP conversion can
  pull the PDF compile closure.
- `convert/zip_worker` does not import `convert/pdf`; it can route PDF entries
  through `MARKITDOWN_PDF_CLI` / worker CLI behavior, but normal dispatcher does
  not use it.
- `convert/epub` consumes `doc_parse/epub` and keeps package parsing below the
  convert layer.
- `convert/epub` delegates body conversion to `convert/html`, while retaining
  EPUB-specific spine/nav/asset/link/origin policy.
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
  `convert/html`, causing repeated full-buffer reads/writes and HTML lowering
  cost.
- ZIP/EPUB profile detail strings may still be built on normal paths.
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
- Do not remove archive PDF support without replacement coverage.

### Future Actions

- Do not fix `zip -> pdf` until dispatcher and archive entry-handler design is
  clear.
- Consider a future ZIP entry-handler registry or callback architecture.
- Consider making normal `convert/zip` PDF-free or worker-backed if compile
  closure measurements justify it.
- Consider narrowing `zip_core` public helpers after tests/facades are
  reviewed.
- Consider profile-detail hot-path fixes for ZIP/EPUB together with other
  convert formats.
- Continue Convert-4 Office formats next.

## Convert-4 Office Formats

### Status

- `convert/docx` is the DOCX product conversion layer. It consumes
  `doc_parse/ooxml` directly, reads DOCX
  parts/relationships/styles/numbering/document XML, and owns DOCX-to-core-IR
  output policy.
- `convert/pptx` is the PPTX product conversion layer. Its main
  slide/text/image/notes/rendering pipeline is convert-owned OOXML logic, while
  chart semantic paths partially consume `doc_parse/pptx`.
- `convert/xlsx` is the XLSX product conversion layer. It already consumes
  `doc_parse/xlsx` as its primary workbook semantic source, then owns
  sheet/table/RichTable/output policy.

### Model Integration Findings

- DOCX does not currently consume `doc_parse/docx.DocxDocument`.
- PPTX partially consumes `doc_parse/pptx` for chart semantic data, but the
  main presentation pipeline remains convert-owned.
- XLSX consumes `doc_parse/xlsx.XlsxWorkbook` as the primary parser model.
- This means Office integration maturity differs by format: DOCX is deferred,
  PPTX is partial, XLSX is accepted.

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

- DOCX repeats significant parser-like OOXML logic: part reads, relationship
  handling, styles, numbering, XML scanning, notes/comments/header/footer
  parsing.
- PPTX repeats main parser-like OOXML logic: slide relationships,
  shape/text/media/notes/comments/table parsing, plus reading order/grouping
  policy.
- DOCX/PPTX model integration with `doc_parse/docx` and `doc_parse/pptx` is
  deferred because output behavior must be preserved deliberately.
- DOCX/PPTX may perform repeated part reads and heavy XML string scanning.
- PPTX chart paths may reparse or rebuild semantic data.
- XLSX keeps convert-side compatibility/output models, which can duplicate
  memory alongside parser model data.
- All three Office converters may still construct profile-only detail strings
  on normal paths.
- `convert/xlsx` exposes a broader compatibility model/profile API surface than
  DOCX/PPTX.

### Not-a-bug Decisions

- Do not force DOCX/PPTX onto parser models without a product-output migration
  plan.
- XLSX consuming `doc_parse/xlsx` is the preferred long-term shape, but it
  should not be used as a reason to rush DOCX/PPTX migration.
- DOCX/PPTX/XLSX rendering policy belongs in convert, not doc_parse.
- Existing samples/main_process references are test-only and not runtime
  pollution.

### Future Actions

- Decide separately whether and how `convert/docx` should consume
  `DocxDocument`.
- Decide separately whether and how `convert/pptx` should fully consume
  `PptxPresentation`.
- Preserve output compatibility before replacing convert-owned OOXML paths.
- Consider narrow profile-detail hot-path fixes later.
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

### Profile Hot-Path Status

- The profile-only detail hot-path fix has been applied and reviewed.
- Remaining detail strings such as `ocr_mode=`,
  `text_pdf_only=true ocr_excluded=true pages=`, `pages=`, `max_heading=`,
  `enabled=`, `high_confidence_uri_attach=true`, and `blocks=` are only
  constructed inside `profile Some(_)` branches.
- `profile None` branches still call `pdf_convert_profile_add_stage(..., None)`
  and do not construct detail strings.

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
- Outline second open remains a parser/API deferred item, not a convert/pdf
  fix.
- Heavy PDF test lane remains deferred.

### Future Actions

- Keep raw/vendor parsing out of convert/pdf.
- Defer public API narrowing until debug/layout/test dependencies are reviewed.
- Consider splitting `pdf_lines.mbt` only if maintenance or profiling justifies
  it.
- Revisit layout gate/model split only with replacement model design.
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
- `json` / `yaml`: parser model lowering with `$` / key-path and line-based
  origin; RichTable/List/CodeBlock origin belongs to convert.
- `xml`: convert-owned bytes decode, `doc_parse/xml` parser-model consumption
  for safe structured lowering, and source-preserving fenced fallback with
  whole-document line origin for unsupported / complex / large inputs.
- `csv` / `tsv`: RichTable origin with row/column ranges; TSV is input format,
  not manifest/control.
- `html`: private DOM/semantic lowering with block/link/image/table/note origin
  and local image asset policy.
- `zip`: archive entry aggregation, nested origin rewriting, and nested asset
  remap.
- `epub`: spine/nav/toc/cover/content origin; delegates body conversion to
  `convert/html` and remaps origins/assets.
- `docx`: paragraph/run/table/notes/comments/header/footer/media origin from
  OOXML direct logic.
- `pptx`: slide/shape/text/image/table/chart/notes/comments origin; chart path
  partially consumes `doc_parse/pptx`.
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
- Convert-2A audited lightweight formats and recorded the Markdown
  parser-model integration deferral plus profile hot-path candidates; the XML
  parser-model integration deferral is resolved.
- Convert-2B audited HTML/TSV and recorded HTML private scanner vs
  `doc_parse/html` as deferred.
- Convert-3 audited archive/container formats and recorded ZIP nested dispatch
  plus ZIP -> PDF closure as deferred.
- Convert-4 audited Office formats and recorded DOCX deferred model
  integration, PPTX partial integration, XLSX accepted parser-model
  integration.
- Convert-5 audited PDF runtime policy and confirmed raw/vendor parser
  boundaries plus profile hot-path fix.
- Convert-6 audited OCR/vision/debug/layout tools and confirmed they are
  outside normal runtime.
- Convert-7 summarized metadata/assets/origin policy and deferred shared helper
  extraction.
- Overall: convert layer first-pass audit is complete. The next safe code work
  should be small profile hot-path fixes or explicitly scoped architecture
  changes, not broad rewrites.
