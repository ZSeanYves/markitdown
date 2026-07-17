# RAG

`rag/` projects the unified document IR into retrieval-oriented chunk views. It does not parse formats and does not control rendering directly; its job is to own chunking rules, chunk metadata, and stable RAG JSON semantics.

## Responsibilities

- Define RAG chunk options and default policy
- Split `DocumentIR` into stable retrieval units
- Preserve heading paths, source refs, asset refs, and other retrieval-side context

## Key Entry Points

- `types_options.mbt`
  `RagOptions`, `RagChunk`, `ChunkKind`
- `document_chunking.mbt`
  `chunks_from_document`
- `helpers.mbt`
  Helper logic for chunk text, heading paths, and metadata assembly

## Key Types

- `RagOptions`
  Controls chunk size, overlap, table/code splitting, and provenance retention
- `RagChunk`
  Represents one stable public chunk consumable by downstream retrieval systems

## Maintenance Rules

- Keep chunking rules centralized here instead of letting CLI, render, and convert each grow their own logic
- Keep heading-path, source-ref, and asset-reference semantics stable so downstream indexing and regression tests stay reliable
- Add new chunk kinds only when there is a clear retrieval use case, not just local renderer convenience
- RAG JSON remains buffered because its framing and chunk metadata require a
  complete view. Parser-pull and Markdown sink optimizations must not silently
  change RAG chunking, diagnostics, or provenance.

## Validation

```bash
moon test
```
