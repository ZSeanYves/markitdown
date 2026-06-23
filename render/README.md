# render

Role:
  renderer implementations

Owns:
  `Renderer`
  Markdown rendering
  debug JSON rendering
  renderer-level escaping and formatting rules

Does not own:
  format detection
  parsing
  IR pass execution
  CLI argument parsing

Depends on:
  `core`

Used by:
  `convert` and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
