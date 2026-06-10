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
