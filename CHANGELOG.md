# Changelog

## Unreleased

### Current baseline

* main-repo runtime, `moon test`, and `./samples/check.sh` remain self-contained
* optional external quality now runs through `bash ./samples/check_quality.sh`
* repo-root `markitdown-quality-lab/` is the primary home for:
  * external corpus payloads
  * tracked local/full quality rows
  * PDF layout classifier training/eval/model/report assets
  * generator scripts that do not belong in runtime

### Validation snapshot

* `moon test`: `1579 passed`
* `./samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0` failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`
* full quality: `330 rows / 1 skipped / 0 expected_fail`
* focused PDF quality: `101 rows / 1 skipped / 0 expected_fail`

### Product/runtime boundary

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* current PDF layout behavior in the normal path remains distilled into narrow MoonBit rules/gates
* OCR remains explicit-only
* `cli mbtpdf count = 0`
* `zip mbtpdf count = 0`
* `pdf mbtpdf count = 23339`

### Recent structural changes

* quality-lab migration completed for:
  * external corpus payloads
  * tracked full/local quality rows
  * PDF layout classifier training/eval scripts and reports
  * encoding generator scripts
* repo-tracked PDF fixtures required by `moon test` were kept in the main repo
* the PDF layout dev/export/infer MoonBit entrypoint now lives under
  `doc_parse/pdf/layout_model_tool`
* `samples/pdf_layout_classifier/` has been removed from the main repo
* `samples/check_quality.sh` is now the preferred optional full-quality entrypoint
* `samples/check.sh` now defaults to full repo-local validation instead of light manifest checks
* `samples/bench.sh` now defaults to the recommended smoke suite and writes summaries under `.tmp/bench/`
* README entry points were cleaned for faster first-read onboarding
* top-level docs navigation and archive/current-doc boundaries were polished
* stale OCR archive notes and legacy TSV-signal helper references were pruned
* current image OCR and PDF OCR boundaries were clarified across docs

### Current caution notes

* `0 expected_fail` is not a blanket format-completeness claim
* OCR/scanned behavior remains explicit-only
* benchmark and compare numbers remain local and sample-scoped
* quality-lab is not a release artifact
