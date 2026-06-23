# runtime

Role:
  parse-result lowering and child-dispatch helpers

Owns:
  `ParseResult` -> `IRInput` lowering
  diagnostics merge helpers
  child document conversion through the canonical pipeline

Does not own:
  parser registration
  low-level reader logic
  pass definitions
  rendering rules

Depends on:
  `core`, `input`, `parser`, and `pipeline`

Used by:
  container-style parsers, `convert`, and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
