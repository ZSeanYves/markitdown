# Samples

The `samples/` tree contains the repo-tracked validation corpus and developer
entrypoints.

Repository docs entrypoints:

* [docs/architecture.md](../docs/architecture.md)
* [docs/supported-formats.md](../docs/supported-formats.md)
* [docs/quality-and-release.md](../docs/quality-and-release.md)
* [docs/pdf.md](../docs/pdf.md)
* [docs/performance.md](../docs/performance.md)
* [docs/roadmap.md](../docs/roadmap.md)

Current primary commands:

* `bash samples/check.sh --manifest-only` runs the lightweight repo-local
  quick check.
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline.
* `bash samples/bench.sh --suite smoke --kind smoke` runs the benchmark smoke
  suite.

## Public Quick Checks

These entrypoints are the normal onboarding surface:

* `bash samples/check.sh --manifest-only` for a lightweight repo-local quick
  check
* `bash samples/check_quality.sh --public-only` for the checked-in public
  quality baseline
* `bash samples/bench.sh --suite smoke --kind smoke` for the benchmark smoke
  suite
* `bash samples/bench.sh --help` to list available benchmark suites

`markitdown-quality-lab/` is not required for this section.

## Broader Validation And Full Quality

Use these after the quick checks are green:

* `bash samples/check.sh` runs the full repo-local validation suite
* `bash samples/check_quality.sh` runs the optional full quality gate
* `bash samples/check_quality.sh --format pdf` runs the focused PDF quality
  slice

The optional full quality gate expects the repo-root quality-lab:

* `git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab`

If the quality-lab is absent, `bash samples/check_quality.sh --public-only`
should still pass, while `bash samples/check_quality.sh` should fail clearly
with a clone hint.

## Directory Roles

| Path | Role |
| --- | --- |
| `samples/main_process/` | repo-tracked user-visible sample corpus and expected outputs |
| `samples/fixtures/` | lower-layer and fail-closed fixtures |
| `samples/benchmark/` | checked benchmark corpus and manifests |
| `samples/helpers/bench/` | internal benchmark suite implementations and warning helpers |
| `samples/helpers/contracts/` | internal CLI, PDF, ZIP, batch, debug, and OCR contract checks |
| `samples/helpers/release/` | internal release-candidate and release-summary helpers |
| `samples/helpers/shared/` | shared shell helper libraries for temp dirs and runner resolution |
| `samples/helpers/validation/` | internal sample enrollment, manifest, and inventory helpers |
| `samples/helpers/quality/` | internal quality runner implementation and schema/helpers |
| `samples/fixtures/ocr/` | tiny license-clean OCR fixtures, manifest, and expected text for OCR policy/docs/optional smoke |

## Benchmark Helpers

Current public benchmark entrypoint:

* `bash samples/bench.sh --help`
* `bash samples/bench.sh --suite smoke --kind smoke`

Current lightweight product-path diagnostic helper:

* `moon build cli --target native`
* `bash samples/helpers/bench/check_product_path_attribution_smoke.sh`

That helper:

* uses the public native `cli.exe`
* supports `MARKITDOWN_CLI=/path/to/cli.exe`
* does not build internally
* does not run OCR or `tesseract`
* prints grep-friendly TSV to stdout
* writes transient output under `.tmp/` only
* is a smoke/diagnostic tool, not a release gate or performance promise

## Current Facts

Current checked sample validation:

* markdown: `444`
* metadata: `85`
* assets: `90`
* failures: `0`

Current quality validation:

* public-only: `24 / 0 / 0`
* full quality: `330 / 1 / 0`
* focused PDF quality: `101 / 1 / 0`

## OCR/Vision Quality-Lab Helpers

These helpers are internal/dev scaffolding only. They do not imply current
product OCR support, and they do not change the normal path, which still never
OCRs.

* `samples/fixtures/ocr/` stays limited to tiny, self-generated,
  project-license fixtures; real OCR corpus growth belongs in
  `markitdown-quality-lab`
* `samples/helpers/validation/check_ocr_fixtures.sh` validates OCR fixture
  manifest/licensing, path safety, and fixture-size policy without running OCR
  or requiring `tesseract`
* `bash samples/helpers/validation/check_quality_lab_ocr_scaffold.sh`
  validates the optional `markitdown-quality-lab/ocr_samples/` scaffold only;
  it is read-only and does not run OCR or require `tesseract`
* `bash samples/helpers/quality/summarize_quality_lab_ocr.sh` is the read-only
  OCR quality-lab dashboard helper; it summarizes checked-in corpus rows,
  artifact counts, and semantic hint coverage without running OCR,
  `tesseract`, or `tsv_preview_tool`
* `bash samples/helpers/quality/check_quality_lab_ocr_preview.sh` compares
  checked-in `layout_preview` artifacts against `expected_markdown`; it does
  not run OCR, does not require `tesseract`, and does not need a prebuilt tool
* `moon build convert/vision/tsv_preview_tool --target native` is the explicit
  prebuild step for the next two helpers
* `bash samples/helpers/quality/check_quality_lab_ocr_resegmented_preview.sh`
  regenerates resegmented preview markdown from checked-in `tesseract_tsv`
  artifacts with a prebuilt native `tsv_preview_tool.exe`; it does not run OCR,
  does not require `tesseract`, and intentionally does not build the tool
  internally
* `bash samples/helpers/quality/check_quality_lab_ocr_ir_hints.sh`
  regenerates default and resegmented OCR layout -> IR hint TSV output from
  checked-in `tesseract_tsv` artifacts with a prebuilt native
  `tsv_preview_tool.exe`; it does not run OCR, does not require `tesseract`,
  and intentionally does not build the tool internally
* `TSV_PREVIEW_TOOL=/path/to/tsv_preview_tool.exe` can be used to override the
  tool path for the previous two helpers
* current OCR/Vision semantic hints track side-channel labels such as
  `TableLike`, `KeyValueLike`, and `CaptionLike`; they do not mean Markdown
  table, key-value, or caption reconstruction is already supported
* `bash samples/helpers/contracts/check_vision_tesseract_tsv_signal_optional.sh`
  is the only helper here that may invoke local `tesseract`; it is an optional
  developer-machine smoke, not a public quality gate

## Release Helpers

Release helpers build on the same public entrypoints:

* `bash samples/helpers/release/check_release_candidate.sh`
* `bash samples/helpers/release/check_release_candidate.sh --skip-bench`
* `bash samples/helpers/release/check_release_candidate.sh --full`
* `bash samples/helpers/release/print_release_summary.sh`

## Notes

* `samples/helpers/*` are internal focused rerun helpers, not the main user
  entrypoints
* `samples/helpers/quality/check.sh` remains available for compatibility, but
  it is an internal runner implementation rather than the preferred top-level
  entry
* the rest of `samples/helpers/` is organized by role instead of a flat script
  list
* `samples/quality_corpus/` has been removed from the user-visible samples tree
* `samples/pdf_layout_classifier/` no longer exists in the main repo
* training/eval/model/report assets live in the repo-root quality-lab, not in
  `samples/`
