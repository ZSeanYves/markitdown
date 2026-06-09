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

Non-goals for this scaffold:

- no old PDF runtime changes
- no dispatcher switch
- no external model files
- no DocLayNet or quality-lab reads
- no feature TSV generation
- no fallback to `doc_parse/pdf`
