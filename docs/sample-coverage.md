# Sample Coverage

## Regression sets vs. demo set

The repository has two different sample roles:

1. **Full regression sets** (for engineering stability)
   - `samples/main_process`
   - `samples/metadata`
   - `samples/assets`
2. **Acceptance demo set** (for quick showcase)
   - `samples/test`

`samples/test` is a compact five-format demonstration set. It is **not** a replacement for full regression coverage.

## Why regression is split into 3 independent chains

- `main_process`: validate structure recovery and Markdown main output quality.
- `metadata`: validate origin / image-context / caption / nearby-caption semantics.
- `assets`: validate extracted assets and Markdown asset reference validity.

This split improves explainability:

- failures are easier to localize,
- acceptance evidence maps clearly to completion/quality/explainability/UX,
- regression noise is reduced.

## Scripts

- `samples/check_samples.sh`: enrollment integrity check for main_process set.
- `samples/diff.sh`: main process regression entry (and invokes assets checks).
- `samples/check_metadata.sh`: metadata-focused regression.
- `samples/check_assets.sh`: assets extraction/reference regression.

## Acceptance demo coverage (`samples/test`)

Current demo files cover five formats:

- DOCX: `samples/test/golden.md`
- HTML: `samples/test/html_figure_figcaption_basic.md`
- PDF: `samples/test/pdf_image_single_caption_like.md`
- PPTX: `samples/test/pptx_image_single_caption_like.md`
- XLSX: `samples/test/xlsx_builtin_datetime_22.md`

And include metadata/assets examples for acceptance walkthrough.
