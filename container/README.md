# container

Role:
  shared container contracts and safety helpers

Owns:
  supported inner-format lists
  asset output path safety checks
  container diagnostics and guardrail helpers

Does not own:
  archive parsing
  parser registration
  child conversion orchestration
  file writes at the CLI boundary

Depends on:
  `core` and `input`

Used by:
  container-style parsers and contract tests

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
