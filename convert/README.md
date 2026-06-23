# convert

Role:
  top-level conversion orchestration

Owns:
  `ConvertMode`
  `ConvertOptions`
  input -> detect -> parse -> runtime -> pipeline -> render orchestration
  end-to-end `ConvertResult`

Does not own:
  format detection implementation
  parser registration details
  low-level reader code
  Markdown rendering internals

Depends on:
  `input`, `parser`, `formats`, `runtime`, `pipeline`, `render`, `core`

Used by:
  `cli` and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
