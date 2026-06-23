# format_readers/html

Role:
  lower-level HTML tokenizer and safe DOM-like reader

Owns:
  HTML tokenization
  tolerant parse model
  inspect and validation helpers
  no-fetch HTML safety boundary

Does not own:
  parser registration
  readability-style product policy
  IR lowering
  Markdown rendering

Used by:
  `formats/html`
  container-style HTML consumers such as EPUB parsing

Key entrypoints:
  `parse_html_document`
  `inspect_html_document`
  `validate_html_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
