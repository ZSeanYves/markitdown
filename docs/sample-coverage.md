# Sample Coverage

## Regression sets vs. demo set

The repository has two different sample roles:

1. **Full regression sets** (for engineering stability)
   - `samples/main_process`
   - `samples/metadata`
   - `samples/assets`
2. **Acceptance demo set** (for quick showcase)
   - `samples/test`

`samples/test` is a compact acceptance demonstration set. It is **not** a replacement for full regression coverage.

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

## Acceptance demo coverage (`samples/test`)

Current demo files cover a compact subset of formats:

- DOCX: `samples/test/golden.md`
- HTML: `samples/test/html_figure_figcaption_basic.md`
- PDF: `samples/test/pdf_image_single_caption_like.md`
- PPTX: `samples/test/pptx_image_single_caption_like.md`
- XLSX: `samples/test/xlsx_builtin_datetime_22.md`

And include metadata/assets examples for acceptance walkthrough.
