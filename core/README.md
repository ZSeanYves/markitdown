# core

Role:
  canonical Core IR and shared data model

Owns:
  `DocumentIR`
  `CoreBlock` and `CoreInline`
  `IRInput`
  diagnostics, source refs, assets, and container plan data

Does not own:
  format detection
  parser selection
  IR pass execution
  rendering
  CLI behavior

Depends on:
  no project packages

Used by:
  almost every higher layer

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
