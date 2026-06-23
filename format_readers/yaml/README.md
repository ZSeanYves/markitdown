# format_readers/yaml

Role:
  lower-level YAML subset parser and AST foundation

Owns:
  conservative YAML subset parsing
  AST model
  inspect helpers
  fail-closed unsupported-feature handling

Does not own:
  parser registration
  IR lowering
  Markdown rendering
  full YAML feature coverage

Used by:
  `formats/yaml`

Key entrypoints:
  `parse_yaml_document`
  `inspect_yaml_document`
  `classify_yaml_error`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
