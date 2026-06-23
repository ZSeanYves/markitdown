# formats

Role:
  registry-facing product parser layer

Owns:
  per-format parser packages under `formats/*`
  builtin parser registration
  format-level contract helpers that stay outside the runtime registry

Does not own:
  low-level reader foundations
  IR pass logic
  Markdown rendering
  CLI wiring

Depends on:
  `parser`, `input`, `core`, and `format_readers`

Used by:
  `convert`, tests, and the builtin registry path

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
