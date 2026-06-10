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
