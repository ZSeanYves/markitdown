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

`pdf_core_v2` is the PDF v2 parsing substrate. It is not a wrapper around the
old `doc_parse/pdf` runtime, and it is not a permanent public API for the old
vendored `mbtpdf` package. Old vendor code may be used as reference material,
as a source for carefully ported code, or as a temporary private backend during
implementation, but v2 public parser contracts must remain owned by
`doc_parse/pdf_v2`.

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
