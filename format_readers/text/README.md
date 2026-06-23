# format_readers/text

Role:
  lower-level plain-text reader foundation

Owns:
  byte and text open helpers
  newline normalization
  line and paragraph grouping
  inspect helpers

Does not own:
  parser registration
  Markdown escaping policy
  IR lowering
  final rendering

Used by:
  `formats/txt`

Key entrypoints:
  `open_text_document`
  `parse_text_document`
  `inspect_text_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
