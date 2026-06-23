# format_readers/json

Role:
  lower-level JSON parser and AST foundation

Owns:
  JSON parsing
  AST model
  inspect helpers
  structured parse error classification

Does not own:
  parser registration
  streaming registry policy
  IR lowering
  Markdown rendering

Used by:
  `formats/json`

Key entrypoints:
  `parse_json_document`
  `inspect_json_document`
  `classify_json_error`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
