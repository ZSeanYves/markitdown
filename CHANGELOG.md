# Changelog

## Unreleased

### Current baseline

* main-repo runtime, `moon test`, and `./samples/check.sh` remain self-contained
* optional external quality runs through `bash ./samples/check_quality.sh`
* repo-root `markitdown-quality-lab/` remains the optional home for:
  * external corpus payloads
  * tracked local/full quality rows
  * PDF layout classifier training/eval/model/report assets
  * generator scripts that do not belong in runtime

### Validation baseline

* `moon test`: `1579 passed`
* `./samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`
* full quality remains external-corpus scoped and depends on the checked-out
  `markitdown-quality-lab` manifest
* focused PDF quality: `79 rows / 0 failed / 1 skipped / 0 expected_fail`

### User-visible updates

* PDF native text recovery improved paragraph soft merge, superscript-style note
  marker attachment, numbered-heading promotion, and two-column negative guards
* PDF annotation links can upgrade a high-confidence URI annotation into
  Markdown link syntax when the visible label is unique within the merged text
  block, while duplicate-label or invisible-only annotations stay conservative
* shared note IR now supports normalized Markdown footnote refs and resolved
  note bodies across Markdown, DOCX, EPUB, and resolved PDF note cases
* `samples/check.sh` remains the main repo-local validation entrypoint, and
  `samples/check_quality.sh` remains the optional external-quality entrypoint
* active package docs and test guards now describe the stable
  `format_readers -> formats -> runtime/pipeline/render` architecture without
  transitional cleanup bookkeeping

### Architecture notes

* normal runtime does not read quality-lab assets or model JSON
* OCR remains explicit-only
* retired `doc_parse` and `office` roots in favor of `format_readers`
* repo-tracked PDF fixtures required by `moon test` stay in the main repo

### Current caution notes

* `0 expected_fail` is not a blanket format-completeness claim
* OCR/scanned behavior remains explicit-only
* PDF footnote body association is still future work; PDF note output remains
  marker-only unless a resolved body exists
* broader HTML conservative noteref inference remains future work beyond the
  explicit same-document noteref/body pairs already recognized
* runtime model/gate loading and OCR provider expansion remain out of the
  normal product path
* benchmark and compare numbers remain local and sample-scoped
* quality-lab is not a release artifact
