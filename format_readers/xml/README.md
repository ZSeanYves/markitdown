# format_readers/xml

Role:
  lower-level safe XML tokenizer and parser foundation

Owns:
  XML parse model
  inspect and validation helpers
  fail-closed entity and doctype handling

Does not own:
  parser registration
  IR lowering
  Markdown rendering
  schema validation

Used by:
  `formats/xml`

Key entrypoints:
  `parse_xml_document`
  `inspect_xml_document`
  `validate_xml_document`

See:
  [docs/architecture/mb-markitdown-architecture.md](../../docs/architecture/mb-markitdown-architecture.md)
