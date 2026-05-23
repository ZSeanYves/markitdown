# Quality And Release

This page is the current release-readiness map for the repository.

It separates:

* repo-local quick checks
* optional quality-lab OCR/Vision checks
* full quality gates
* paths that must stay out of a release candidate commit

## Main Entry Points

The public sample entrypoints are `samples/check.sh`,
`samples/check_quality.sh`, and `samples/bench.sh`.

Recommended copy-paste-safe commands:

* `bash samples/check.sh --manifest-only`
* `bash samples/check_quality.sh --public-only`
* `bash samples/bench.sh --suite smoke --kind smoke`
* `bash samples/bench.sh --help`

Internal helper paths exist for maintainers, but they are not the primary
onboarding surface.

## A. Repo-Local Quick Checks

These commands do not require `markitdown-quality-lab`:

* `bash samples/check.sh --manifest-only` checks repo-tracked sample integrity
  and manifest-level entrypoints
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline from `samples/helpers/quality/manifest.tsv`
* `bash samples/bench.sh --help` checks that the public benchmark entrypoint is
  available and advertises its suites
* `moon check` runs the current MoonBit check/lint gate

Optional product-path attribution smoke stays outside this quick-check gate:

* `moon build cli --target native`
* `bash samples/helpers/bench/check_product_path_attribution_smoke.sh`

That helper is a diagnostic-only benchmark smoke for observing normal-path
cost boundaries before a release candidate. It does not enter
`bash samples/check_quality.sh --public-only`, and it is not a release hard
gate.

Optional PDF scan diagnostics also stay outside this quick-check gate:

* `moon build debug --target native`
* `bash samples/helpers/contracts/check_pdf_scan_diagnostics.sh`
* `bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`
* `MARKITDOWN_DEBUG=_build/native/debug/build/debug/debug.exe bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`

These helpers are report-only PDF diagnostics. They reuse the explicit debug
path, do not run OCR, do not probe providers, do not change normal PDF output,
and do not enter `bash samples/check_quality.sh --public-only`.

Current checked facts:

* `moon check`: pass
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`

## Broader Repo-Local Validation

Run these before a release candidate or after behavior-affecting changes:

* `moon test`
* `bash samples/check.sh`

Current checked fact:

* `moon test`: `1579 passed`

Main-repo OCR fixtures remain policy-only groundwork. The helper
`samples/helpers/validation/check_ocr_fixtures.sh` validates manifest
structure, licensing policy, path safety, and checked-in fixture size limits
for `samples/fixtures/ocr/`. It does not run OCR, does not require
`tesseract`, and is not an OCR accuracy gate.

## B. Optional Quality-Lab OCR/Vision Checks

These checks are internal/dev-only. They do not imply current product OCR
support, and they do not change the normal path, which still never OCRs.

Current quality-lab OCR scaffold shape:

* `markitdown-quality-lab/ocr_samples/manifest.tsv`
* `markitdown-quality-lab/ocr_samples/source_catalog.tsv`
* `markitdown-quality-lab/ocr_samples/images/`
* `markitdown-quality-lab/ocr_samples/expected_text/`
* `markitdown-quality-lab/ocr_samples/expected_markdown/`
* `markitdown-quality-lab/ocr_samples/provider_outputs/tesseract_tsv/`
* `markitdown-quality-lab/ocr_samples/provider_outputs/layout_preview/`
* `markitdown-quality-lab/ocr_samples/provider_outputs/layout_preview_resegmented/`
* `markitdown-quality-lab/ocr_samples/provider_outputs/ir_hints/`
* `markitdown-quality-lab/ocr_samples/provider_outputs/ir_hints_resegmented/`

Current helper map:

| Command | Purpose | Runs OCR / `tesseract` | Needs prebuilt `tsv_preview_tool` |
| --- | --- | --- | --- |
| `bash samples/helpers/validation/check_quality_lab_ocr_scaffold.sh` | validates manifest/source headers, relative paths, and referenced files | no | no |
| `bash samples/helpers/quality/summarize_quality_lab_ocr.sh` | read-only summary of corpus rows, checked-in artifacts, and semantic coverage | no | no |
| `bash samples/helpers/quality/check_quality_lab_ocr_preview.sh` | compares `expected_markdown` against checked-in `layout_preview` artifacts | no | no |
| `bash samples/helpers/quality/check_quality_lab_ocr_resegmented_preview.sh` | regenerates `--resegment-lines` preview from checked-in TSV inputs and compares `layout_preview_resegmented` | no | yes |
| `bash samples/helpers/quality/check_quality_lab_ocr_ir_hints.sh` | regenerates default and resegmented IR hint TSV output and compares `ir_hints` artifacts | no | yes |

Before the last two checks, build the tool explicitly with
`moon build convert/vision/tsv_preview_tool --target native`. Those helpers
intentionally do not build the tool internally, and they do not rely on
per-row `moon run`.

If you want to point at a different prebuilt binary, override the path with
`TSV_PREVIEW_TOOL=/path/to/tsv_preview_tool.exe`.

Current OCR/Vision hint tracking is limited to a semantic side-channel such as
`TableLike`, `KeyValueLike`, `CaptionLike`, `Heading`, and `ListItem`. Those
hints do not change the current conservative Markdown output, and they do not
mean Markdown table, key-value, or caption reconstruction is already supported.

The only helper here that may invoke local `tesseract` is
`bash samples/helpers/contracts/check_vision_tesseract_tsv_signal_optional.sh`.
It is an optional developer-machine smoke, not a public quality gate.

None of the helpers in this section enter
`bash samples/check_quality.sh --public-only`.

## C. Full Quality

The optional full quality gate uses the repo-root quality-lab:

* `git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`

Current checked facts:

* full quality: `330 rows / 1 skipped / 0 expected_fail`
* focused PDF quality: `101 rows / 1 skipped / 0 expected_fail`

`full quality` means the public baseline plus lab-managed rows from
`markitdown-quality-lab/quality_rows/manifest.tsv`.

The quality-lab carries:

* external corpus payloads
* tracked full/local quality rows
* OCR preview and IR hint artifacts
* PDF layout classifier training/eval/model/report assets
* helper and generator scripts that do not belong in runtime

The main repo keeps:

* runtime code
* mandatory test fixtures
* public sample corpus
* public-only quality baseline
* user-facing sample entrypoints

If `markitdown-quality-lab/` is absent:

* `moon test` should still pass
* `bash samples/check.sh` should still pass
* `bash samples/check_quality.sh --public-only` should still pass
* `bash samples/check_quality.sh` should fail clearly with a clone hint

## D. Prohibited Paths

Do not stage or ship these as part of a main-repo release candidate:

* `markitdown-quality-lab/`
* `.external`
* `external_manifest.local.tsv`
* `_build`
* `.tmp`
* `.mooncakes`

## Release Helpers

Release helpers build on the same public entrypoints rather than a separate
release-only workflow:

* `bash samples/helpers/release/check_release_candidate.sh`
* `bash samples/helpers/release/check_release_candidate.sh --skip-bench`
* `bash samples/helpers/release/check_release_candidate.sh --full`
* `bash samples/helpers/release/print_release_summary.sh`

Legacy sibling quality-lab lookup and legacy `.external/...` resolution remain
compatibility-only and are no longer the recommended workflow.
