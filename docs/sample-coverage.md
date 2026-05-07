# Sample Coverage

## Regression sets vs. lower-layer fixtures

The repository has two different sample roles:

1. **Unified regression corpus** (for engineering stability)
   - `samples/main_process`
   - `samples/main_process/<format>/expected`
2. **Lower-layer fixture sets** (for parser/core and boundary coverage)
   - `samples/fixtures`

`samples/fixtures` is for parser/core/unit-test-only fixtures, fail-closed
boundaries, and unsafe inputs. It is **not** a replacement for full regression
coverage and is not the repository's user-facing example gallery.

## Why the corpus is now unified

- `main_process` is the single checked-in input tree.
- metadata-heavy and asset-heavy cases remain visible, but live under the same
  format roots rather than separate top-level corpora.
- expectations now live inside each format package under
  `samples/main_process/<format>/expected/`.

## Scripts

- `samples/check.sh --manifest-only`: enrollment and manifest integrity check.
- `samples/check.sh`: full validation entry.
- `samples/check.sh --markdown-only`: unified regression entry.
- `samples/check.sh --metadata-only`: metadata-focused regression.
- `samples/check.sh --assets-only`: assets extraction/reference regression.
- `samples/check.sh --contracts-only`: contract-focused regression.
- `samples/check.sh --manifest-only`: manifest-focused validation.

Validation UX notes:

* validation prefers a probe-validated native CLI when one is available
* if the discovered native binary is stale, validation falls back to `moon run`
* set `MARKITDOWN_CLI=/abs/path/to/cli` to override runner discovery with a
  known-fresh native binary
* `moon run` includes wrapper overhead, so explicit native override is still
  useful for faster local runs
* `SAMPLES_VERBOSE=1` restores per-sample logs
* `check.sh --markdown-only` validates the unified sample tree; run
  `./samples/check.sh` for the full integrity + contract chain

## Lower-layer fixture coverage (`samples/fixtures`)

Current checked-in fixture families are:

- CLI-facing metadata sidecar snapshots:
  `samples/main_process/<format>/expected/*.metadata.json`
- lower-layer metadata snapshots: `samples/fixtures/metadata`
- EPUB package and boundary fixtures: `samples/fixtures/epub`
- ZIP path-safety and nested-archive fixtures: `samples/fixtures/zip`

The previous root-level demo Markdown set under `samples/test` has been
removed so richer user-facing examples can be introduced separately without
mixing them with lower-layer test fixtures.
