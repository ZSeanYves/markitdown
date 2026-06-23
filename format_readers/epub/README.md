# format_readers/epub

Role:
  lower-level EPUB package reader built on ZIP foundations

Owns:
  EPUB package open and inventory
  rootfile, manifest, spine, nav, and cover discovery
  safe part access and validation helpers

Does not own:
  XHTML semantic conversion
  Markdown aggregation
  reading-system behavior
  remote fetch

Used by:
  `formats/epub`

Key entrypoints:
  `open_epub_package`
  `inspect_epub_package`
  `validate_epub_package`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
