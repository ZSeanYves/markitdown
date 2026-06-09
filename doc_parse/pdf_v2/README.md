# PDF v2 Parser Scaffold

Status: experimental scaffold.

This package is the parser-side PDF v2 experiment described by
`docs/archive/pdf-v2-architecture.md`.

Current scope:

- vendor/core facade types and placeholder `open_pdf_core_v2`
- explicit `pdf_core_v2` capability matrix for object graph, xref, streams,
  filters, pages, resources, content ops, fonts, glyph decode, images, vectors,
  annotations, forms, outlines, metadata, security metadata, and diagnostics
- structured warning/risk contracts for unsupported, partial, malformed,
  decode, encrypted, permission-restricted, missing-resource, low-signal, and
  boundary-violation states
- default one-pass/no-fallback/runtime-closure policies
- one-pass source document scaffold
- text reconstruction model scaffold
- parser-owned layout recovery scaffold
- normalized `PdfV2DocumentModel`
- model/rule cooperation score records
- feature contract placeholders for future quality-lab export

## Core Boundary

`pdf_core_v2` is the PDF v2 parser-facing substrate. It is not a wrapper around
the old `doc_parse/pdf` runtime, and it is not a full low-level PDF parser
rewrite inside `doc_parse/pdf_v2`. The low-level parsing owner is mbtpdf:
object graph, xref tables/streams, object streams, stream decode, page tree,
resources, content operators, text/font extraction, CMap/ToUnicode experience,
and security metadata come through the mbtpdf-backed adapter.

PDF v2 owns the product-facing contract above that substrate: structured
diagnostics, source refs, object refs, page indices, content order, decode
confidence, source events, normalized parser model, layout facts, feature
export, classifier gate inputs, and fail-closed lowering policy. The v2 adapter
may add diagnostics, reason tags, source attribution, confidence rollups, and
tolerant Unicode/ToUnicode handling. It must not regrow a separate xref,
indirect-object, or content-stream parser.

The stable `open_pdf_core_v2(Bytes)` entry remains scaffold-only and
fail-closed. The `open_pdf_core_v2_perf(Bytes)` entry is the authorized
mbtpdf-backed real reader path. Public v2 parser contracts remain owned by
`doc_parse/pdf_v2`; mbtpdf types are not exposed as the v2 public boundary.

The v2 target is a complete common-PDF substrate: object graph, xref table and
xref stream handling, object streams, compressed streams, filters, page tree,
page boxes, rotation, user units, resource dictionaries, content stream
operators, text state, graphics state, font dictionaries, CMap and ToUnicode,
glyph decode, ligatures, images, vectors, annotations, links, destinations,
outlines, Info/XMP metadata, AcroForm facts, optional-content diagnostics,
encryption metadata, permissions metadata, malformed-object diagnostics, and
low-signal document diagnostics.

Missing or partial capabilities must be emitted as structured `PdfV2Warning`
and/or `PdfV2Risk` records. They must not be hidden by fallback, broad
catch-all flags, silent loss, or convert-side reparsing.

## Runtime Policies

Normal PDF v2 runtime follows these defaults:

- `one_pass_required = true`
- `legacy_fallback_allowed = false`
- `convert_raw_reparse_allowed = false`
- `model_export_raw_reparse_allowed = false`
- `debug_tools_in_runtime_allowed = false`
- `external_model_file_allowed = false`
- `quality_lab_runtime_dependency_allowed = false`

The runtime closure allows reader-facing capabilities only: read, objects, xref,
streams, filters, pages, resources, content ops, text, fonts, images, vectors,
annotations, forms, outlines, metadata, security metadata, and diagnostics.
Writer APIs, debug dumps/examples, vendor-slow tests, quality-lab bridge code,
training export, model training, feature TSV loading, pickle model loading, and
Python runtime dependencies are forbidden from normal runtime closure.

Convert consumes parser/model facts only. It may use risks to abstain or fail
closed, but it cannot mutate parser facts, reopen the PDF, rebuild raw source
events, or use old-parser fallback.

Performance is part of the contract: one pass over input bytes, bounded memory,
bounded feature extraction, and a controlled runtime closure are required before
dispatcher adoption.

## RESET-2 Diagnostics Helpers

This reset adds source/object diagnostics helpers only. It does not implement a
complete PDF reader, stream decoder, security handler, page resource resolver,
dispatcher switch, model hook, or training/export path.

Diagnostics are the foundation for PDF v2's no-fallback and no-silent-loss
contract. Malformed objects, missing objects, invalid object refs, malformed
xref tables/streams, partial object streams, filter/codec failures, encrypted
or permission-restricted documents, missing page resources, missing font/image
resources, unknown font encodings, malformed ToUnicode maps, skipped image or
vector decode, unsupported annotations/forms/optional content groups, low-signal
documents, one-pass boundary violations, runtime closure violations, and
forbidden fallback attempts must be represented as structured `PdfV2Warning`
and/or `PdfV2Risk` records.

The helpers in `pdf_v2_diagnostics.mbt` are pure MoonBit constructors with no
IO, no old `doc_parse/pdf` dependency, no `convert/pdf` dependency, no Python,
and no external repository dependency. They preserve capability, source ref,
object ref, page index, stable reason tags, severity, and recoverability so the
future reader/source-event/text-reconstruction layers can report partial
support explicitly.

Convert may later consume parser/model warnings and risks to abstain or fail
closed, but it cannot rescan raw PDF bytes, repair parser facts, or hide missing
core capabilities with product-policy fallback. Old vendor/mbtpdf code remains
reference or temporary private-backend material only, not a permanent v2 public
API. The next reset can start wiring these diagnostics into source events and
object/page reader scaffolds.

## RESET-3 Source Events

This reset adds the `doc_parse/pdf_v2/source_event` scaffold. It is a
parser-side source-event package that consumes `pdf_core_v2` scaffold records
and RESET-2 diagnostics helpers, then wraps them into typed source events,
source pages, and a source document summary.

The source-event scaffold preserves page indices, source refs, object refs,
resource refs, capability kinds, severity, recoverability, and stable reason
tags on every event. Malformed objects, missing objects, malformed xref
structures, filter diagnostics, encryption/permission diagnostics, missing
page resources, and no-fallback/one-pass violations can now be embedded in
events and summarized as warning/risk counts plus capability coverage.

This is still not a reader or decoder. It does not parse PDF operators, decode
streams, load models, lower to convert, or repair source facts. Diagnostics are
produced from the single `pdf_core_v2` scan scaffold and remain parser-owned.
Convert must consume the resulting parser/model facts later; it must not rescan
PDF bytes, call old `doc_parse/pdf`, or use product policy to fill parser holes.

## RESET-4 Text Reconstruction

This reset adds `doc_parse/pdf_v2/text_reconstruction`, a parser-side scaffold
that consumes `source_event.PdfV2SourceDocument` and builds glyph, char, span,
line, block, page, and text-model placeholders. It does not read PDF files,
call old `doc_parse/pdf`, call vendor/mbtpdf directly, call convert, load
models, or perform training.

Text reconstruction preserves source refs, object refs, page indices, content
order, geometry, font/style fields, writing direction, decode confidence,
warnings, risks, recoverability, and reason tags. When source events do not
contain text payloads, the builder returns an empty text model with summary
warnings/risks rather than silently dropping text. Low-confidence and failed
decode facts remain in the model and are surfaced through structured
diagnostics.

The layer may emit parser-owned candidate facts such as list marker shape,
caption prefix shape, heading shape, wrapped line, same-paragraph, table-cell,
page-number, and header/footer position candidates. These are not final
semantic labels. Final heading/list/caption/table/Markdown/IR decisions remain
convert-owned and must be made from parser facts later.

The next reset can aggregate this text model into the normalized parser model
or begin layout-recovery scaffolding over glyph/span/line/block facts.

## RESET-12A/12B Historical Reader Spikes

RESET-12A and RESET-12B previously carried a small self-written reader spike for
simple text PDFs: object scanning, uncompressed and `/FlateDecode` content
streams, text operators, and a minimal ToUnicode/CMap subset. That code proved
the source-event, text-reconstruction, normalized-model, layout, feature,
classifier, lowering, and core-document scaffolds could propagate real parser
facts and diagnostics.

The spike is no longer part of the current runtime base. It was intentionally
removed rather than expanded, because a long-lived PDF v2 substrate should be
based on the existing mbtpdf reader packages and then adapted to the v2
diagnostics/source-event contract. The synthetic fixtures and placeholder tests
remain to preserve interface shape, one-pass/no-fallback policies, and
fail-closed diagnostics until the mbtpdf-backed base lands.

## RESET-13 Core Cleanup And mbtpdf Plan

The current `open_pdf_core_v2` implementation is scaffold-only. It performs a
bounded PDF header probe, emits structured `self_written_core_removed` and
`mbtpdf_backend_planned` warnings/risks, preserves the core document type,
capability matrix, source summary, one-pass boundary, runtime closure policy,
and no-fallback policy, and then fails closed with no pages, streams, or text
events. Convert continues to consume parser facts only and emits its diagnostic
document rather than calling old `doc_parse/pdf`, `convert/pdf`, OCR, Python, or
external model/data paths.

The planned enhanced base should be a private v2 adapter over mbtpdf, not a new
public dependency boundary. Candidate mbtpdf packages and roles:

- `io/pdfread` or `io/pdfreadcore`: byte input, xref table/stream handling,
  object streams, malformed-object paths, lazy stream loading
- `core/pdf` and `core/pdfio`: object graph, direct/indirect lookup, stream
  bytes, geometry helpers, mutable byte buffers
- `document/pdfpage` and `document/pdftree`: page tree traversal, page object
  numbers, page boxes/resources/content refs
- `graphics/pdfopsread`: content stream lexer/parser and operator sequence
  reading
- `text/pdftextread`: text state and glyph/text extraction experience
- `font/pdfcmap`, `font/pdffont`, `font/pdfglyphlist`: ToUnicode, CMap,
  font encodings, glyph names, composite/simple font mapping

The v2 adapter should preserve the existing upward contract:
`PdfV2CoreDocument` -> source events -> text reconstruction -> normalized model
-> layout recovery -> feature export -> classifier gate -> lowering -> core
Document. Future implementation can use `open_pdf_core_v2_perf` as the
mbtpdf-backed entry while keeping `open_pdf_core_v2` stable.

Performance targets for the mbtpdf-backed base:

- lazy stream decode and bounded decoded-stream lifetime
- batch glyph decode per font/CMap instead of per-token repeated lookup
- reusable buffers for content stream and CMap decoding
- page iteration that avoids full convert-side reparsing
- diagnostics adapters that map mbtpdf parse/decode/font/security failures into
  `PdfV2Warning` and `PdfV2Risk` with source refs, object refs, page indices,
  decode confidence, and reason tags

The contract does not change: one input scan owned by parser, fail-closed
diagnostics for malformed/unsupported/partial capability, low-confidence text
retained when present, no silent loss, no legacy fallback, no convert raw
reparse, no quality-lab/model/TSV/Python runtime dependency.

## RESET-14 mbtpdf-backed Perf Base

`open_pdf_core_v2_perf(Bytes)` now provides the first mbtpdf-backed performance
base inside the PDF v2 scaffold. The stable default `open_pdf_core_v2` remains
scaffold-only, so existing dispatcher/convert behavior does not change in this
reset.

The perf entry is a private v2 adapter over mbtpdf packages:

- `io/pdfread` opens bytes with `pdf_of_input_lazy`
- `core/pdf` and `core/pdfio` provide object graph, direct lookup, streams, and
  buffer conversion
- `document/pdfpage` provides page tree traversal, boxes, rotation, resources,
  and page content references
- `graphics/pdfopsread` parses content streams with source-preserving
  `LocatedOp` records
- `text/pdftextread` performs font, encoding, glyph, and ToUnicode/CMap decode

The adapter emits `PdfV2CoreDocument` facts only: pages, object refs, content
stream refs, text events, source refs, content order, font facts, text matrices,
decode confidence, warnings, and risks. It does not expose mbtpdf types as a v2
public boundary and does not call old `doc_parse/pdf`, `convert/pdf`, OCR,
Python, model artifacts, feature TSVs, or external data.

Current supported path: simple text PDFs with uncompressed or `/FlateDecode`
content streams, `BT/ET`, `Tf`, `Td`, `TD`, `Tm`, `T*`, `Tj`, `TJ`, `'`, and
`"` text-showing operators, plus basic simple-font ToUnicode/CMap decoding as
provided by mbtpdf. Low-confidence or missing font/ToUnicode cases retain text
when possible and emit structured diagnostics instead of silent loss.

Perf notes:

- stream bytes are opened lazily through mbtpdf and decoded only when page
  content operators are parsed
- glyph decode is batched per text-showing operator through the mbtpdf text
  extractor and cached per font name
- source attribution preserves page index, stream index, op index, object ref,
  text object id, and content order
- malformed content streams fail closed with `DecodeFailure` warnings/risks and
  no legacy fallback

## RESET-15 ToUnicode Bad-CMap Handling

`open_pdf_core_v2_perf(Bytes)` now has a v2-owned tolerant ToUnicode adapter for
simple text PDFs. The adapter still uses mbtpdf for lazy object access and stream
decode, including compressed ToUnicode streams, but it no longer requires
mbtpdf's strict CMap parser before producing v2 source text events.

The RESET-15 path supports a minimal CMap subset:

- `begincodespacerange` / `endcodespacerange`
- `beginbfchar` / `endbfchar`
- `beginbfrange` / `endbfrange`
- UTF-16BE ToUnicode targets, including surrogate pairs

Decoded Unicode strings are normalized through
`tonyfettes/unicode/normalization` (`nfc`) before they enter source events. Bad
or partial CMaps produce structured warnings/risks with reason tags such as
`decode_source_tounicode`, `tounicode_bfchar_applied`,
`tounicode_bfrange_applied`, `bad_tounicode_handled`,
`tounicode_unmapped_code`, `glyph_decode_low_confidence`, and `text_retained`.
Low-confidence text is retained rather than silently dropped.

The public scaffold interface and upper pipeline remain unchanged:
`PdfV2CoreDocument` -> source events -> text reconstruction -> normalized model
-> layout recovery -> feature export -> classifier gate -> lowering -> core
Document. There is still no old `doc_parse/pdf` fallback, no `convert/pdf`
fallback, no convert-side raw reparse, no Python/model/TSV/runtime data
dependency, and malformed unsupported input remains fail-closed with diagnostics.

## RESET-16 Reader Contract Guard

RESET-16 locks the corrected ownership boundary:

- mbtpdf owns low-level PDF parsing
- PDF v2 owns diagnostics, source-event contracts, parser model facts, feature
  export, classifier-gate inputs, and lowering policy
- `open_pdf_core_v2(Bytes)` remains scaffold-only/fail-closed
- `open_pdf_core_v2_perf(Bytes)` is the only real PDF reader path
- v2 must not restore the RESET-11/12A/12B self-written reader spike
- convert must not reopen raw PDFs, reparse streams, or re-decode text

The package exposes contract constants:
`pdf_v2_reader_backend_contract = "mbtpdf-backed"`,
`pdf_v2_low_level_parser_owner = "vendor/mbtpdf"`,
`pdf_v2_self_written_core_allowed = false`,
`pdf_v2_default_reader_entry_contract = "scaffold-only"`, and
`pdf_v2_perf_reader_entry_contract = "authorized-mbtpdf-reader"`.

The perf reader also emits stable diagnostics tags such as
`mbtpdf_backend_used` and `v2_adapter_diagnostics_only`. These tags are a guard
against future self-written core regression; they do not add new parsing
capability. The tonyfettes Unicode helper remains scoped to tolerant
Unicode/ToUnicode normalization inside the adapter, not a separate parser path.

## RESET-13 mbtpdf Diagnostics Expansion

`open_pdf_core_v2_perf(Bytes)` now expands the mbtpdf-backed adapter diagnostics
without changing the stable scaffold entry, dispatcher, `convert/pdf_v2`, or the
upper source-event to lowering pipeline.

New diagnostics coverage:

- page/resource diagnostics for missing page resources, missing font/XObject
  /ExtGState/ColorSpace resources, unsupported resource kinds, and page-tree
  resource inheritance
- text-state diagnostics for preserved text matrices, origins, font size,
  baseline tags, line-height estimates, spacing/scaling/rendering/text-rise
  facts, and explicit partial-positioning warnings
- font diagnostics for simple fonts, Type0/CID fonts, subset font names,
  embedded-font presence, ToUnicode/CMap presence, best-effort glyph decode,
  and low-confidence retained text
- xref/object/filter/security diagnostics for xref table use, xref/object
  stream detection when visible in the mbtpdf object graph, FlateDecode,
  filter chains, DecodeParms, stream decode failures, and encrypted PDFs

The adapter records bounded decoded-stream lifetime counters as diagnostics:
decoded stream count, total decoded bytes, maximum decoded stream bytes,
content stream count, page count, text event count, glyph/char count, and decode
failure count. It does not hold decoded stream copies after operator parsing and
does not expose raw or decoded stream bytes to convert.

Encrypted PDFs fail closed with structured warnings/risks. Malformed streams
fail closed with decode diagnostics. No old `doc_parse/pdf` or `convert/pdf`
fallback is introduced, and convert still consumes parser facts only.

## RESET-5 Normalized Parser Model

This reset adds `doc_parse/pdf_v2/normalized_model`, a parser-owned aggregation
scaffold that consumes `source_event.PdfV2SourceDocument` and
`text_reconstruction.PdfV2TextModel`. It builds document, page, text block,
line, span, char, media placeholder, layout placeholder, reading-order
placeholder, cross-page-boundary placeholder, source-summary, diagnostics, and
classifier-ready feature placeholder records.

The normalized model preserves diagnostics, source refs, object refs, page
indices, content order, decode confidence, warnings, risks, recoverability, and
reason tags from source events and text reconstruction. Candidate facts from
text reconstruction stay candidate facts. They are not converted into final
heading, list item, caption, table, Markdown, or IR labels.

This layer does not parse PDF bytes, reopen inputs, call old `doc_parse/pdf`,
call convert, load models, train, or export TSVs. Convert may later consume the
normalized parser facts, warnings, risks, and classifier-ready placeholders, but
it must not mutate parser facts or fill missing parser facts through fallback.

Non-goals for this scaffold:

- no old PDF runtime changes
- no dispatcher switch
- no external model files
- no DocLayNet or quality-lab reads
- no feature TSV generation
- no fallback to `doc_parse/pdf`

## RESET-6 Layout Recovery

This reset adds `doc_parse/pdf_v2/layout_recovery`, a parser-side layout
recovery scaffold that consumes only
`normalized_model.PdfV2DocumentModel`. It produces parser-owned layout facts:
layout regions, reading-order candidates, cross-page boundary candidates,
layout risks, confidence scores, decision traces, source refs, object refs,
member block ids, member line ids, warnings, risks, and reason tags.

The scaffold does not read PDF files, reopen bytes, call old `doc_parse/pdf`,
call vendored PDF packages directly, call convert, train models, read feature
TSVs, read quality-lab artifacts, or load external model files. It keeps
layout recovery on the parser side; future convert code may consume these facts
and fail closed, but it must not redo canonical layout recovery or mutate the
parser model.

Deterministic/model cooperation is represented as a typed boundary only. Layout
decisions carry `deterministic_constraint_score`, `model_confidence`,
`feature_support_score`, `risk_penalty`, `final_confidence`,
`decision_source`, `abstain`, and reason tags. The intended ordering is hard
constraints first, then high-confidence model hints, then weak heuristics, then
abstain. Model hints are in-memory candidate facts for future wiring; they
cannot hard override parser facts, and runtime model artifacts must not be read
from external repository files.

Low-signal, malformed, uncertain, source-order conflict, cross-page ambiguity,
and model-hint conflict states are explicit layout risks and lower confidence
or trigger abstain. OCR recommendation is represented only as a warning/risk
(`ocr_recommended_but_not_fallback`); this layer never performs OCR fallback.

The next stage can either feed these parser-owned layout facts into feature
export or build the convert-side classifier gate scaffold that consumes them.

## RESET-7 Classifier-Ready Feature Export

This reset adds `doc_parse/pdf_v2/feature_export`, a parser-side feature
contract scaffold. It consumes `normalized_model.PdfV2DocumentModel` plus
`layout_recovery.PdfV2LayoutRecoveryResult` and returns typed feature schema,
block feature records, diagnostics, risks, and summary counts. It is not a TSV
writer, model trainer, quality-lab bridge, convert gate, Markdown policy, or IR
lowering layer.

Feature export does not read PDF files, reopen bytes, call old
`doc_parse/pdf`, call vendored PDF packages directly, call convert, read
external repositories, load model artifacts, generate `features.tsv`, or train
models. The output is parser-owned evidence for future `text_block_classifier`,
quality-lab bridge, and convert classifier gate consumers.

The default block feature schema fixes the contract for identity, text shape,
font/style, geometry, page-relative geometry, line spacing, indentation,
neighbor context, visual proximity, layout region, reading order, cross-page,
diagnostics, risk, candidate facts, model-gate input, and training-export
metadata groups. Caption, list, heading, table/layout, risk, and abstain gaps
from earlier classifier iterations are explicit schema fields.

Features available from normalized text and layout recovery are emitted as
available or derived values. Features that still need richer parser facts, such
as visual proximity, font body-density deltas, hanging indent, continuation
counts, and vector-grid/table geometry, are represented as planned or
missing-with-warning diagnostics rather than being silently omitted or left for
convert to reconstruct.

Feature records may contain candidate or evidence fields such as
`heading_shape_candidate`, `list_marker_candidate`, `caption_prefix_candidate`,
`table_cell_candidate`, `layout_region_kind`, and `classifier_input_feature`.
They must not contain final semantic labels such as final heading, paragraph,
list item, caption, table, Markdown block kind, or IR kind. Final semantic
policy remains convert-owned.
