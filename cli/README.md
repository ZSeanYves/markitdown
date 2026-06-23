# cli

Role:
  product command-line entrypoint

Owns:
  argument parsing
  supported-format surface for the main CLI
  fail-closed user-facing error messages
  handoff into `convert`

Does not own:
  format detection internals
  parser implementations
  IR passes
  Markdown rendering rules

Depends on:
  `convert`, `input`, selected format guard helpers

Used by:
  end users and shell validation gates

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
