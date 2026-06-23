# format_readers/ooxml/package

Role:
  shared low-level OOXML package reader for DOCX, PPTX, and XLSX

Owns:
  OOXML ZIP package open and part access
  content types
  relationships
  media inventory
  lightweight package properties

Does not own:
  Word, PowerPoint, or Excel semantic recovery
  parser registration
  IR lowering
  Markdown rendering

Used by:
  `formats/docx`
  `formats/pptx`
  `formats/xlsx`
  shared OOXML helpers

Key entrypoints:
  `open_ooxml_package`
  `inspect_ooxml_package`
  `validate_ooxml_package`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../../docs/architecture/mb-markitdown-architecture.md)
