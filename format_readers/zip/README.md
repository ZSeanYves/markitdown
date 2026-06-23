# format_readers/zip

Role:
  lower-level ZIP archive reader foundation

Owns:
  archive open, list, and read helpers
  normalized entry-path handling
  structured inventory and validation helpers
  external `bikallem/compress/flate` decoder boundary

Does not own:
  nested archive conversion policy
  OOXML or EPUB semantics
  parser registration
  Markdown rendering

Used by:
  `formats/zip`
  `format_readers/epub`
  `format_readers/ooxml/package`

Key entrypoints:
  `open_zip`
  `inspect_zip_archive`
  `validate_zip_archive`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
