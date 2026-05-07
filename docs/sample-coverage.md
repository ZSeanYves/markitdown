# Sample Coverage

## Regression sets vs. lower-layer fixtures

The repository has two different sample roles:

1. **Full regression sets** (for engineering stability)
   - `samples/main_process`
   - `samples/metadata`
   - `samples/assets`
2. **Lower-layer fixture sets** (for parser/core and boundary coverage)
   - `samples/fixtures`

`samples/fixtures` is for parser/core/unit-test-only fixtures, fail-closed
boundaries, and unsafe inputs. It is **not** a replacement for full regression
coverage and is not the repository's user-facing example gallery.

## Why regression is split into 3 independent chains

- `main_process`: validate structure recovery and Markdown main output quality.
- `metadata`: validate origin / image-context / caption / nearby-caption semantics.
- `assets`: validate extracted assets and Markdown asset reference validity.

This split improves explainability:

- failures are easier to localize,
- acceptance evidence maps clearly to completion/quality/explainability/UX,
- regression noise is reduced.

## Scripts

- `samples/scripts/check_samples.sh`: enrollment integrity check for main_process set.
- `samples/check.sh`: full validation entry.
- `samples/check_main_process.sh`: main process regression entry.
- `samples/check_metadata.sh`: metadata-focused regression.
- `samples/check_assets.sh`: assets extraction/reference regression.

Validation UX notes:

* validation prefers a probe-validated native CLI when one is available
* if the discovered native binary is stale, validation falls back to `moon run`
* set `MARKITDOWN_CLI=/abs/path/to/cli` to override runner discovery with a
  known-fresh native binary
* `moon run` includes wrapper overhead, so explicit native override is still
  useful for faster local runs
* `SAMPLES_VERBOSE=1` restores per-sample logs
* `check_main_process.sh` is intentionally focused on main Markdown regression;
  run `./samples/check.sh` for the full integrity + main_process + metadata +
  assets chain

## Lower-layer fixture coverage (`samples/fixtures`)

Current checked-in fixture families are:

- metadata sidecar snapshots: `samples/fixtures/metadata`
- EPUB package and boundary fixtures: `samples/fixtures/epub`
- ZIP path-safety and nested-archive fixtures: `samples/fixtures/zip`

The previous root-level demo Markdown set under `samples/test` has been
removed so richer user-facing examples can be introduced separately without
mixing them with lower-layer test fixtures.
