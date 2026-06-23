# format_readers

Role:
  low-level reader foundations that sit below the product parser layer

Owns:
  bytes and package readers
  tokenizers and safe tree scanners
  shared OOXML and archive foundations
  lower-level PDF, ZIP, EPUB, text, JSON, YAML, XML, HTML, and Markdown reader logic

Does not own:
  product parser registration
  runtime orchestration
  IR passes
  Markdown rendering
  CLI behavior

Depends on:
  lower-level utilities and `core` only when the dependency is format-neutral

Used by:
  `formats`

Rules:
  `format_readers` must not depend on `formats`, `runtime`, `pipeline`, `render`, or `convert`.

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
