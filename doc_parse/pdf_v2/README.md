# PDF v2 Parser Scaffold

`doc_parse/pdf_v2` is an experimental parser package for the PDF v2
architecture contract in `docs/archive/pdf-v2-architecture.md`.

This package does not replace `doc_parse/pdf` or the current `convert/pdf`
runtime. Dispatcher behavior is unchanged.

Boundaries for this scaffold:

- The parser owns source events, source references, geometry, text facts,
  layout facts, warnings, risks, and classifier-ready features.
- Convert owns product policy, Markdown decisions, and final IR lowering.
- PDF input must be scanned once by the future vendor/raw/parser path.
- Convert must not reopen, rescan, or reinterpret raw PDF bytes.
- No fallback to the old PDF runtime is introduced here.
- No Python runtime, model file, DocLayNet data, `features.tsv`, `model.pkl`,
  or external quality-lab file is read at runtime.
- The vendor/core facade is part of the v2 rewrite scope. Phase 2 now defines
  the first narrow `pdf_core_v2` facade and raw source event bridge contract.

The files in this package intentionally define typed contracts before real PDF
reading is wired. Unsupported or incomplete capabilities should be represented
as warnings and risks rather than hidden fallback behavior.

## Productization Reset Direction

Current work is focused on main-chain parity with the shipped v1 PDF path.
`doc_parse/pdf_v2` should continue to own source events, the normalized model,
layout facts, object facts, feature rows, warnings, and risks while convert
owns product lowering. The diagnostics renderer/goldens/adoption scaffold have
been stopped and removed from the current route. v2 is preparing for controlled
dispatcher registration only after the product-surface bridge is close enough
to compare expected diffs. Model integration stays deferred until text, object,
and layout signals are stable enough to extract training data.

Reset 8A audits the parser fact gap behind the Reset 7 semantic block system.
The next parser-facing batches should add neutral facts such as line text
signals, line layout signals, block boundary signals, page artifact candidates,
and text flow candidates. These are parser/model facts only: convert still owns
final paragraph, heading, list, continuation, plain text, and unknown decisions.

## Phase 14 Convert Consumer Boundary Note

Phase 14 adds a one-way `convert/pdf_v2` fact-only lowering smoke over
`PdfV2DocumentModel` and optional `PdfV2FeatureSet`.

Parser status remains unchanged:

- `doc_parse/pdf_v2` does not import or call `convert/pdf_v2`.
- Parser APIs still produce source documents, normalized models, layout facts,
  and feature sets only.
- Convert is a downstream consumer of parser facts. It must not reopen raw PDF
  input, call mbtpdf, depend on old `doc_parse/pdf`, or fallback to the old PDF
  runtime.
- The Phase 14 lowerer emits plain text and conservative diagnostic fragments
  only; parser facts still do not contain Markdown roles.

## Phase 15 Feature Gate Consumer Boundary Note

Phase 15 adds a `convert/pdf_v2` no-model gate over `PdfV2FeatureSet`.

Parser status remains unchanged:

- `PdfV2FeatureSet` remains parser-owned factual evidence and risk signal data.
- `doc_parse/pdf_v2` still has no dependency on `convert/pdf_v2`.
- The gate is a downstream consumer only; it must not call parser path APIs,
  reopen raw PDF input, call mbtpdf, read external model/data files, or emit
  semantic block labels.

## Phase 13 Classifier Feature Scaffold Status

Phase 13 builds classifier-ready feature scaffolding from existing parser facts:

```text
PdfV2DocumentModel
  + PdfV2LayoutFactSet
  + object capability reports
  -> PdfV2FeatureSet
```

Current status:

- `PdfV2FeatureSet` contains document, page, block, and object feature rows
  plus summaries, warnings, risks, source refs, and one-pass/no-fallback flags.
- Feature rows are parser facts and risk signals. They are not heading, list,
  caption, table, figure, form, link, or Markdown labels.
- Document and page rows expose text/object counts, layout statuses,
  unsupported capability counts, partial fact counts, capped object counts,
  metadata-only counts, warnings, risks, and source refs.
- Block rows expose text length, line/span/char counts, decode confidence,
  geometry confidence, missing-geometry and low-signal flags, object presence
  flags, cap context, reason tags, and source refs.
- Object rows expose object kind, capability status, metadata-only/partial/
  unsupported/capped flags, bbox/source-ref presence, diagnostics, and reason
  tags.
- The feature parser API is `parse_pdf_v2_features_from_path`, which builds the
  model and layout facts once and then derives features from those parser facts.

This is still not model loading, model training, semantic classification,
heading/list/caption/table detection, layout recovery, convert lowering,
dispatcher behavior, external data/model reading, or fallback.

## Phase 12 Object Capability Reporting Status

Phase 12 adds explicit parser-owned object capability diagnostics on top of the
Phase 11 object candidates:

```text
Object candidates
  -> capability statuses
  -> object caps
  -> unsupported capability reports
  -> partial fact reports
```

Current status:

- `PdfV2ObjectCapOptions` bounds image, inline-image, annotation, link, form,
  outline, destination, resource, and metadata candidate arrays.
- Cap hits trim the parser candidate arrays and produce warnings, risks,
  `Capped` capability reports, and `PdfV2ObjectSummary` cap counters.
- `PdfV2UnsupportedCapabilityReport` records metadata-only image decode,
  unsupported/heavy image filters, not-attempted object capabilities, source
  refs, object refs, severities, and reason tags.
- `PdfV2PartialFactReport` records available and missing fields for partial
  annotations, links, forms/widgets, outlines, destinations, and metadata.
- `PdfV2SourceDocument`, `PdfV2DocumentModel`, and `PdfV2LayoutFactSet` expose
  the unsupported and partial reports alongside extended object summaries.
- Image decode remains metadata-only/not-attempted unless a future phase adds a
  reviewed decode pipeline behind explicit caps.

This is still not image decoding, OCR, object-region recovery, caption/table
association, form semantic normalization, link Markdown lowering, semantic
classification, convert lowering, dispatcher behavior, external data/model
reading, or fallback.

## Phase 11 Object Facts Integration Status

Phase 11 maps object-related core/source events into parser-owned candidates and
threads them through the normalized model and layout fact coverage:

```text
CoreEvent object facts
  -> PdfV2SourceDocument object candidates
  -> PdfV2DocumentModel page/document object facts
  -> PdfV2LayoutFactSet object coverage
```

Current status:

- Object facts are represented as parser candidates for image XObjects, inline
  images, annotations, links, forms/widgets, outlines, destinations, resources,
  and metadata.
- Image facts are metadata-first. Width, height, color space, bits per
  component, filters, mask flags, object refs, and source refs are recorded
  when available, but image bytes are not decoded or exported.
- Annotation/link/form/outline/destination/resource/metadata facts are partial,
  source-ref preserving records. Unsupported or incomplete pieces remain
  warnings, risks, reason tags, or capability gaps rather than fallback.
- `PdfV2SourceDocument`, `PdfV2PageModel`, and `PdfV2DocumentModel` now carry
  object candidate arrays plus `PdfV2ObjectSummary`.
- Layout facts consume model object candidates for page-level object coverage
  booleans and scaffold statuses. This does not create true regions, captions,
  tables, Markdown links, Markdown images, or form semantics.

This is still not image decoding, OCR, form semantic extraction, link lowering,
caption/table association, semantic classification, convert lowering,
dispatcher behavior, external data reading, or fallback.

## Phase 10 Layout Facts Scaffold Status

Phase 10 consumes the Phase 9 normalized parser model and assembles bounded
parser-owned layout facts:

```text
PdfV2DocumentModel
  -> PdfV2LayoutFactSet
```

Current status:

- `PdfV2LayoutFactSet` records per-page layout facts, summary counts,
  warnings, risks, source refs, and one-pass/no-fallback flags.
- `PdfV2PageLayoutFacts` records page box facts, text candidate counts/source
  refs, object candidate flags, conservative geometry coverage, and layout
  recovery statuses.
- Geometry coverage is factual only. Missing candidate bboxes/baselines produce
  `Missing`, `Sparse`, or `Unknown` coverage plus warnings/risks; the scaffold
  does not invent page regions, bboxes, baselines, columns, or tables.
- Reading order is represented only as a status. Text-bearing pages are
  `SourceOrderOnly`; pages with no text facts are `NotAttempted`.
- Object facts are flags derived from existing model/source events, such as
  image metadata, annotations, forms, outlines, and destinations. They are not
  region recovery or semantic associations.
- The experimental parser entry point is
  `parse_pdf_v2_layout_facts_from_path`, which calls model assembly and then
  layout fact assembly without rereading the PDF.

This is still not true layout recovery, semantic classification, Markdown,
convert lowering, dispatcher behavior, model inference, external data reading,
or fallback.

## Phase 9 Normalized Parser Model Status

Phase 9 consumes the Phase 8 source document and candidate facts and assembles
an experimental parser-owned document model:

```text
PdfV2SourceDocument
  -> PdfV2DocumentModel
```

Current status:

- `PdfV2DocumentModel` now records document/page counts, page models, source
  events, source summary, reconstruction summary, capabilities, warnings,
  risks, one-pass/no-fallback flags, and a model version.
- `PdfV2PageModel` groups block, line, span, and char candidates by page while
  preserving page facts, source refs, page warnings, and page risks.
- Model assembly validates candidate page indices. Invalid candidate/page facts
  fail closed with `invalid_candidate_page_index` warnings and risks rather
  than silent success.
- Source refs, warnings, risks, low-confidence decode facts, and unavailable
  geometry facts are preserved from the source document.
- The experimental parser entry points are `parse_pdf_v2_source_from_path` and
  `parse_pdf_v2_model_from_path`. They call the mbtpdf-backed source path and
  model assembly only.

This is still not layout recovery, semantic classification, Markdown, convert
lowering, dispatcher behavior, model inference, or fallback. Page `text_blocks`
and layout regions remain empty scaffold fields for compatibility with the
current convert experiment.

## Phase 8 Block Candidate Status

Phase 8 consumes Phase 7 line candidates and adds bounded parser-owned block
candidates:

```text
PdfV2LineCandidate[]
  -> PdfV2BlockCandidate[]
```

Current status:

- `PdfV2BlockCandidate` records grouped line candidates, text, source refs,
  decode confidence, geometry confidence, warnings, merge reason tags, break
  reason tags, optional bbox, writing direction, rotation, and a weak
  parser-level block kind hint.
- Block candidates are source-order parser facts. They are not Markdown
  paragraphs, final text blocks, layout regions, headings, lists, captions,
  tables, or convert decisions.
- `PdfV2BlockKindHint` is deliberately narrow: `TextLike`, `Unknown`, or
  `LowSignal`. It does not encode Heading/List/Caption/Table semantics.
- Grouping is conservative. Adjacent lines may merge only when page/source
  order stays compatible, no text-object or explicit block boundary is visible,
  decode confidence does not fail, geometry does not contradict, and the
  configured block caps are not exceeded.
- Geometry remains conservative. Blocks do not invent bounding boxes;
  unavailable geometry is reported with `block_geometry_unavailable` and
  unknown geometry confidence.
- `max_blocks` and `max_lines_per_block` are explicit reconstruction caps and
  report warnings/risks when reached.
- `PdfV2SourceDocument` carries block candidates as experimental parser facts
  alongside char, span, and line candidates. Page `text_blocks`, layout
  regions, convert output, dispatcher behavior, model features, and fallback
  remain untouched.

This is still not normalized model assembly or layout recovery. Phase 8 does
not build Markdown paragraphs, headings, lists, captions, tables, layout
regions, convert output, dispatcher behavior, model features, or fallback.

## Phase 7 Line Candidate Status

Phase 7 consumes Phase 6 span candidates and adds bounded parser-owned line
candidates:

```text
PdfV2SpanCandidate[]
  -> PdfV2LineCandidate[]
```

Current status:

- `PdfV2LineCandidate` records grouped span candidates, text, source refs,
  decode confidence, geometry confidence, warnings, merge reason tags, break
  reason tags, optional bbox, optional baseline, writing direction, and
  rotation.
- Line candidates are source-order parser facts. They are not final layout
  lines, Markdown spans, blocks, paragraphs, headings, lists, captions, or
  convert decisions.
- Grouping is conservative. Adjacent spans may merge only when page/source
  order stays compatible, no text-object or explicit line-move boundary is
  visible, decode confidence does not fail, geometry does not contradict, and
  the configured line caps are not exceeded.
- Geometry remains conservative. Lines do not invent bboxes or baselines;
  unavailable geometry is reported with `line_geometry_unavailable` and unknown
  geometry confidence.
- `max_lines` and `max_spans_per_line` are explicit reconstruction caps and
  report warnings/risks when reached.
- `PdfV2SourceDocument` carries line candidates as experimental parser facts
  alongside char and span candidates. Page `text_blocks`, layout regions,
  convert output, dispatcher behavior, model features, and fallback remain
  untouched.

This is still not block reconstruction or layout recovery. Phase 7 does not
build blocks, paragraphs, headings, lists, captions, layout regions, Markdown,
convert output, dispatcher behavior, model features, or fallback.

## Phase 6 Span Candidate Status

Phase 6 consumes Phase 5 character candidates and adds bounded parser-owned
span candidates:

```text
PdfV2CharCandidate[]
  -> PdfV2SpanCandidate[]
```

Current status:

- `PdfV2SpanCandidate` records grouped char candidates, text, source refs, font
  ref/name/size, decode confidence, geometry confidence, warnings, merge reason
  tags, break reason tags, and optional bbox.
- Grouping is conservative. Adjacent chars are merged only when page, text-show
  source ref, font facts, font size, decode confidence, and geometry confidence
  stay compatible and the configured span length cap is not exceeded.
- TJ spacing boundaries break spans by default. Callers may opt into merging
  those chars, but the span keeps `tj_spacing_boundary` reason tags.
- Geometry remains conservative. Spans do not invent bounding boxes; unavailable
  geometry is reported with `span_geometry_unavailable` and unknown geometry
  confidence.
- `max_spans` and `max_chars_per_span` are explicit reconstruction caps and
  report warnings/risks when reached.
- `PdfV2SourceDocument` carries span candidates as experimental parser facts
  alongside char candidates. They are not final normalized `PdfV2Span` records.

This is still not line or block reconstruction. Phase 6 does not build lines,
blocks, paragraphs, headings, lists, captions, layout regions, Markdown,
convert output, dispatcher behavior, model features, or fallback.

## Phase 5 Font Cache And Char Candidate Status

Phase 5 consumes the Phase 4 typed text events and adds a parser-owned font
cache plus bounded character candidates:

```text
TextShow + GlyphCandidate
  -> PdfV2FontCache / PdfV2DecodeProfile
  -> PdfV2CharCandidate[]
```

Current status:

- `PdfV2FontCache` records fonts seen, decode profiles, cache hit/miss counts,
  warnings, and risks without exposing mbtpdf font objects.
- Decode profiles classify the current source facts as ToUnicode, CMap,
  standard encoding, glyph-name, CJK fallback, raw bytes, or unknown with
  conservative confidence and reason tags.
- `PdfV2CharCandidate` records raw code/bytes, optional Unicode/text and glyph
  name, font ref/name/size, source refs, decode confidence, warnings, and
  reason tags.
- Geometry remains conservative. Char candidates do not invent advance widths,
  positions, or bounding boxes when the parser cannot prove them; such cases
  carry `glyph_geometry_unavailable` and unknown geometry confidence.
- `max_chars` is enforced by the reconstruction function and reports explicit
  warnings/risks when capped.
- `PdfV2SourceDocument` carries these experimental parser facts for tests and
  diagnostics, while `text_blocks`, layout regions, and convert output remain
  empty.

This is still not text grouping. Phase 5 does not build spans, lines, blocks,
paragraphs, headings, lists, captions, layout regions, convert output,
dispatcher behavior, model features, or fallback.

## Phase 4 Typed Text Event Status

Phase 4 keeps the Phase 3 mbtpdf reader path and adds typed text-layer events
from the same source-attributed content operators:

```text
located mbtpdf content ops
  -> raw Unknown source event
  -> TextObjectBegin / TextObjectEnd / TextState / FontUse
  -> TextShow / GlyphCandidate
```

Current status:

- Text operators are recognized from the existing `parse_operators_with_source`
  result. The adapter does not re-open or re-parse the PDF.
- `BT`, `ET`, `Tf`, `Tj`, `TJ`, quote operators, and common text state
  operators are mapped to typed source events while preserving stream/op/object
  source refs.
- Text show events carry raw operator kind, raw string/object text, conservative
  decoded text when mbtpdf can decode it, selected font ref/size, text matrix
  snapshot, warnings, confidence, and reason tags.
- Glyph candidates carry raw code/byte candidates, optional Unicode/glyph-name
  candidates, font ref, text-position snapshot, confidence, source refs, and
  reason tags.
- Decode confidence is conservative: ToUnicode-backed decode is high, standard
  or font-encoding decode is medium, missing font resources are unknown, and
  failed decode is failed.
- Missing font resources, missing ToUnicode, unsupported decode, incomplete
  text state geometry, and unavailable glyph geometry are surfaced as
  warnings/reason tags rather than hidden success.

This is not text reconstruction. Phase 4 still does not build chars, spans,
lines, blocks, paragraphs, headings, lists, captions, layout regions, convert
output, dispatcher behavior, model features, or fallback.

## Phase 3 Minimal Real Reader Adapter Status

Phase 3 wires a narrow read-only mbtpdf adapter behind the v2 facade:

```text
real PDF path
  -> mbtpdf reader/page tree/content op substrate
  -> PdfV2CoreDocument / PdfV2CoreEvent
  -> PdfV2SourceDocument
```

Current status:

- `pdf_v2_open_core_document_from_path` opens real PDF bytes through mbtpdf and
  returns a core document plus capped core events.
- `pdf_v2_open_source_document_from_path` uses the existing raw bridge to build
  a source document without line, block, layout, Markdown, convert, or fallback
  behavior.
- Page facts include media box, crop box, rotate, raw `/UserUnit` when
  available, resources-present, and source refs.
- Events currently include page begin/end, content stream begin/end, and located
  content operators as `Unknown` raw-op-style source events.
- `max_pages` and `max_events` are enforced in the adapter and report
  `PerformanceCap` warnings plus `PerformanceCapReached` risks.
- Malformed, unreadable, encrypted, or page-tree failures fail closed through
  warnings/risks and do not fall back to the old PDF parser.

Known gaps intentionally deferred:

- No text reconstruction, glyph decoding, char/span/line/block grouping, or
  layout recovery.
- No text/font cache, glyph decode confidence, image decode, vector metadata
  caps, rich annotation/form/object events, or convert lowering.

## Phase 2 Facade And Bridge Status

Phase 2 adds the first parser-owned boundary from protected mbtpdf facts into
PDF v2 source facts:

```text
mbtpdf protected facts
  -> PdfV2CoreDocument / PdfV2CoreEvent
  -> PdfV2SourceEvent
  -> PdfV2SourceDocument / PdfV2SourceSummary
```

Current status:

- `PdfV2CoreOpenOptions` carries collection flags and performance caps for
  pages, objects, streams, events, and encrypted documents.
- `PdfV2CoreDocument` carries page count, capabilities, page facts, warnings,
  risks, and source summary.
- `PdfV2CoreEvent` covers page boundaries, content stream boundaries, text,
  glyph, image, inline image, vector, annotation, form, outline, destination,
  metadata, resource, malformed, unsupported, and unknown events.
- `pdf_v2_raw_bridge.mbt` maps core events into source events while preserving
  source refs, object refs, reason tags, warnings, and document risks.
- `PdfV2SourceDocument` stores source events, pages, summary, warnings, and
  risks without constructing lines, blocks, Markdown policy, or convert output.

The real mbtpdf reader adapter is not wired in this phase. The blocker is API
shape, not vendor capability: the next phase needs a small read-only adapter
that opens bytes once, extracts page facts and located content operations, and
translates unsupported, malformed, encrypted, rare, or capped capabilities into
warnings and risks. That adapter must not expose mbtpdf internal object types to
`convert/pdf_v2`.

Source events are parser facts. They are not Markdown policy, not block roles,
and not convert decisions. `convert/pdf_v2` consumes parser/source documents and
must not reopen raw PDF bytes or vendor internals.

## Reset 8B-F Parser Fact Status

Reset 8B-F adds the first parser-owned semantic evidence chain:

```text
PdfV2DocumentModel
  -> PdfV2LineTextSignal
  -> PdfV2BlockBoundarySignal
  -> PdfV2PageArtifactCandidate
  -> PdfV2TextFlowCandidate
```

Current status:

- `PdfV2LineCandidate` embeds `text_signal`.
- `PdfV2BlockCandidate` embeds `boundary_signal`.
- `pdf_v2_build_page_artifact_candidates(model)` aggregates standalone page
  numbers, page labels, caption-like guard facts, and repeated short-line
  artifacts.
- `pdf_v2_build_text_flow_candidates(model)` builds parser-owned flow
  candidates and can split heading/body evidence and inline bullet runs while
  preserving source refs.
- All facts are candidates/scores with reason tags. They are not final
  paragraph, heading, list, caption, table, image, link, or form semantics.

`convert/pdf_v2` owns final semantic decisions and core block mapping. The
parser still does not load models, read external data, run OCR, do full layout
recovery, lower non-text objects, or fall back to the v1 PDF parser.
