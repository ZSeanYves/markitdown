# Changelog

## Unreleased

### Current baseline

* main-repo runtime and `moon test` remain self-contained
* formal main regression runs through `bash ./samples/check_balance.sh` and explicitly depends on the checked-out external corpus repo
* formal quality runs through `bash ./samples/check_balance_quality.sh` and explicitly depend on the same external corpus repo
* repo-root `./markitdown-quality-lab/` is the official home for:
  * external corpus payloads
  * benchmark payloads and `bench` sample manifests
  * tracked local/full quality rows
  * PDF layout classifier training/eval/model/report assets
  * generator scripts that do not belong in runtime
* `samples/bench/` no longer serves as an in-repo benchmark fallback; formal
  benchmark inputs now live in the external lab repo

### Validation baseline

* `moon test`: `591 passed`
* `./samples/check_balance.sh`: formal main regression remains external-corpus scoped and depends on the checked-out `markitdown-quality-lab` manifest
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`
* full quality remains external-corpus scoped and depends on the checked-out
  `markitdown-quality-lab` manifest
* focused PDF quality: `80 rows / 72 checked / 8 skipped / 0 failed`

### User-visible updates

* package metadata in `moon.mod` was refreshed for the current release
  surface; published `keywords` now reflect the actual MoonBit-native
  document-to-Markdown, OCR, CLI, and RAG / content-ingestion positioning
  instead of the older extension-heavy format list
* `.msg` is now accepted as a formal mail-input alias for the stable `eml`
  path, so extension-based CLI detection, `--format`, help text, and quality
  examples no longer need a manual `eml` override for RFC822-style `.msg`
  fixtures
* the retired checked-in `samples/quality_examples/` showcase is no longer part
  of the main repo workflow; formal quality coverage remains external-corpus
  scoped under `markitdown-quality-lab/external_quality/` through
  `samples/check_balance_quality.sh`
* direct image OCR is now a formal main-CLI product path for
  `png/jpg/jpeg/bmp/webp/tif/tiff`; image input uses local Tesseract OCR by
  default, `--no-ocr` explicitly disables it, and `--ocr-lang` is accepted for
  direct image input without requiring explicit `--ocr`
* PDF OCR is now formally promoted through the main product surface:
  `pdf --accurate` automatically enters the current OCR-only PDF route, while
  explicit `pdf --ocr` remains supported through local `pdftoppm` +
  `tesseract`; default native-text PDF behavior remains unchanged
* the CLI mode system now exposes fidelity and output as separate dimensions:
  default balanced Markdown, `--accurate`, `--debug`, `--rag`, and supported
  combinations such as `--accurate --debug` and `--accurate --rag`
* DOCX / PPTX / XLSX accurate-fidelity behavior was strengthened without
  changing package ownership or route contracts; current repo-local baselines
  were updated to match the improved Office output and RAG behavior
* OCR and PDF OCR runtime diagnostics, route facts, and dependency-backed
  product messages were tightened so missing `tesseract` / `pdftoppm` now fail
  clearly at runtime instead of silently falling back to unsupported-format
  behavior
* sample fixtures and contract checks were expanded and refreshed across OCR,
  PDF OCR, ZIP / EPUB / PPTX boundary cases, and release-facing CLI docs so the
  published command surface is now executable and regression-guarded end to end
* `samples/check_balance.sh` remains the formal main-regression entrypoint on the external corpus, and
  `samples/check_balance_quality.sh` remains the formal quality-regression entrypoint on the external corpus
* benchmark sample payloads moved out of the main repo into
  `markitdown-quality-lab`, keeping runtime validation lightweight while leaving
  formal bench runs on the external corpus path
* XML structure scan and OOXML/XLSX preflight probing now use the shared
  pure-MoonBit XML path instead of the retired `format_readers/xml_native` FFI
  layer, fixing cross-system environment compatibility issues in native CI
* active package docs and test guards now describe the stable
  `format_readers -> formats -> runtime/pipeline/render` architecture without
  transitional cleanup bookkeeping

### Architecture notes

* normal runtime does not read quality-lab assets or model JSON
* direct image OCR is now part of the formal main CLI surface; PDF OCR remains
  dependency-backed and OCR-only in this release
* retired `doc_parse` and `office` roots in favor of `format_readers`
* repo-tracked PDF fixtures required by `moon test` stay in the main repo

### Current caution notes

* `0 expected_fail` is not a blanket format-completeness claim
* PDF OCR in this release is still OCR-only and does not yet promise future
  model/layout recovery
* PDF footnote body association is still future work; PDF note output remains
  marker-only unless a resolved body exists
* broader HTML conservative noteref inference remains future work beyond the
  explicit same-document noteref/body pairs already recognized
* runtime model/gate loading and OCR provider expansion remain out of the
  normal product path
* benchmark and compare numbers remain local and sample-scoped
* quality-lab is not a release artifact
