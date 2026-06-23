# input

Role:
  source loading and format detection

Owns:
  `InputSource`
  `DetectedFormat`
  `FormatDetector`
  path, text, and bytes input helpers

Does not own:
  parser registration
  parsing
  IR passes
  rendering

Depends on:
  filesystem and UTF-8 helpers

Used by:
  `cli`, `convert`, parsers, and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
