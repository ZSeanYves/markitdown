# Sample Fixtures

`samples/` now contains only repo-tracked sample payloads and lightweight
fixtures used by tests, smoke checks, and manual CLI experiments.

Main directories:

- `samples/fixtures/contracts/`
  stable happy-path fixtures used by MoonBit tests and shell smoke checks
- `samples/fixtures/boundaries/`
  malformed or fail-closed fixtures that exercise safety boundaries

This directory no longer contains managed environment installers or formal
regression entrypoints.

For repo-level tooling, use:

- [tools/env/README.md](../tools/env/README.md)
- [tools/regression/README.md](../tools/regression/README.md)

Formal corpora and benchmark payloads still live in the external
`markitdown-quality-lab` repository at the repo root.
