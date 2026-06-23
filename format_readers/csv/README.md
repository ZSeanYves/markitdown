# format_readers/csv

Role:
  lower-level CSV reader foundation

Owns:
  CSV parsing
  parse options
  structured inspect and validation helpers

Does not own:
  parser registration
  IR lowering
  Markdown table rendering

Used by:
  `formats/csv`
  shared delimited parser code

Key entrypoints:
  `parse_csv_document`
  `parse_csv_with_options`
  `inspect_csv_document`
  `validate_csv_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
