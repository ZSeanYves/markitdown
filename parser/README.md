# parser

Role:
  parser contracts and registry

Owns:
  `ParserMode`
  `ParserCapability`
  `ParseContext`
  `ParseResult`
  `ParserRegistry`

Does not own:
  format detection
  concrete product parser implementations
  IR passes
  rendering

Depends on:
  `core` and `input`

Used by:
  `formats`, `runtime`, `convert`, and tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
