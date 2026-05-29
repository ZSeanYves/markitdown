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
* `./samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`
* full quality: external-corpus scoped; row counts depend on the checked-out
  `markitdown-quality-lab` manifest
* focused PDF quality: `79 rows / 0 failed / 1 skipped / 0 expected_fail`

### Product/runtime boundary

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* current PDF layout behavior in the normal path remains distilled into narrow MoonBit rules/gates
* OCR remains explicit-only
* `cli mbtpdf count = 0`
* `zip mbtpdf count = 0`
* `pdf mbtpdf count = 23339`

### Recent structural changes

* PDF native text-flow recovery has been tightened for:
  * paragraph soft merge across nearby fragments
  * superscript-style note marker attachment through shared note refs
  * numbered heading split/promotion when the text signal is strong
  * two-column negative guards that prevent cross-column paragraph merge
* PDF annotation-link handling now upgrades a high-confidence URI annotation to
  Markdown link syntax when the visible label is a unique substring inside a
  merged text block, while duplicate-label or invisible-only annotations stay
  conservative
* shared note IR support now covers:
  * `Inline::NoteRef` for inline references
  * document-level `Document.note_definitions` for resolved note bodies
  * metadata sidecar `note_definitions` plus `summary.note_definition_count`
    for resolved note bodies
  * DOCX structured footnotes and endnotes as full Markdown footnotes
  * Markdown native footnote passthrough and normalization as full Markdown
    footnotes when bodies exist
  * EPUB explicit strong noterefs as full Markdown footnotes
  * PDF marker-only fallback when the marker is known but body association is
    not reliable
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
* PDF footnote body association is still future work; PDF note output remains
  marker-only unless a resolved body exists
* broader HTML conservative noteref inference remains future work beyond the
  explicit same-document noteref/body pairs already recognized
* runtime model/gate loading and OCR provider expansion remain out of the
  normal product path
* benchmark and compare numbers remain local and sample-scoped
* quality-lab is not a release artifact

### Architecture consolidation audit

* added a current-state architecture/package/rule-system consolidation audit
  covering package boundaries, PDF rule layers, metadata sidecar status, OCR
  boundary requirements, and the next safe refactor sequence
* fixed current-doc navigation for the doc-parse package notes
* expanded metadata sidecars to include document-level note definitions only
  when resolved note bodies are present
* no package move, runtime model hook, OCR provider implementation, or default
  converter Markdown semantic change is included in this pass
