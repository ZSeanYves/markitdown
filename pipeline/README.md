# pipeline

Role:
  Core IR builder and pass pipeline

Owns:
  `CoreIRBuilder`
  `IRPass`
  `PassPipeline`
  default text, whitespace, asset, and section-tree passes

Does not own:
  source parsing
  parser registration
  final rendering
  CLI behavior

Depends on:
  `core`

Used by:
  `runtime`, `convert`, and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
