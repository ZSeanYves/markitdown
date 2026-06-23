# format_readers/markdown

Role:
  lower-level Markdown scanner and block inventory reader

Owns:
  lightweight Markdown source scanning
  raw block inventory
  frontmatter and fence validation helpers

Does not own:
  final Markdown formatting
  parser registration
  IR lowering
  output cleanup policy

Used by:
  `formats/markdown`

Key entrypoints:
  `scan_markdown_document`
  `inspect_markdown_document`
  `validate_markdown_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
