# format_readers/tsv

Role:
  TSV facade over the shared delimited reader foundation

Owns:
  tab-delimited parser entrypoints
  TSV inspect and validation entrypoints

Does not own:
  a separate parsing engine
  parser registration
  IR lowering
  Markdown rendering

Used by:
  `formats/tsv`

Key entrypoints:
  `parse_tsv_document`
  `inspect_tsv_document`
  `validate_tsv_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
