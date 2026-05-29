# Quality And Release

This page is the current release-readiness map for the repository.

It separates:

* repo-local main validation
* optional quality-lab OCR/Vision checks
* full quality gates
* paths that must stay out of a release candidate commit

## Main Entry Points

The public sample entrypoints are `samples/check.sh`,
`samples/check_quality.sh`, and `samples/bench.sh`.

Recommended copy-paste-safe commands:

* `moon check`
* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`
* `bash samples/bench.sh`
* `bash samples/bench.sh --help`

Internal helper paths exist for maintainers, but they are not the primary
onboarding surface.

Generated validation artifacts stay under `.tmp/` and are not checked in.
Current layout is:

* `.tmp/check/` for repo-local sample validation scratch space
* `.tmp/quality/runs/<run_id>/` for isolated external quality runs
* `.tmp/bench/<suite>/` for benchmark output
* `.tmp/validation/` for report-only validation helpers

Entry-point scripts also bind converter-local scratch space into nested
`workspace/` subtrees so clean rebuilds do not depend on stray root-level
`.tmp/zip`, `.tmp/epub`, or similar leftovers.

## A. Repo-Local Main Validation

These commands do not require `markitdown-quality-lab`:

* `bash samples/check.sh` runs full repo-local sample validation
* `moon check` runs the current MoonBit check/lint gate
* `bash samples/bench.sh` runs the default benchmark suite
* `bash samples/bench.sh --help` shows additional benchmark suites

Optional product-path attribution smoke stays outside this quick-check gate:

* `moon build cli --target native`
* `bash samples/helpers/bench/check_product_path_attribution_smoke.sh`

That helper is a diagnostic-only benchmark smoke for observing normal-path
cost boundaries before a release candidate. It stays outside the main
validation entrypoints and is not a release hard gate.

Optional image OCR attribution smoke also stays outside this quick-check gate:

* `moon build cli --target native`
* `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`

That helper is a separate diagnostic-only benchmark smoke for observing the
main-CLI image OCR path. It requires local `tesseract` plus installed `eng`
tessdata, skips cleanly when those prerequisites are unavailable, stays
outside the main validation entrypoints, and is not a release hard gate.

## OCR Release Readiness

Current release-readiness meaning for shipped image OCR:

* required public checks must stay independent from local `tesseract`
* `bash samples/check.sh`, `bash samples/check_quality.sh`, and `moon check` do
  not require OCR runtime prerequisites beyond the external corpus itself when
  `check_quality.sh` is intentionally invoked
* `bash samples/helpers/contracts/check_ocr_contract.sh` is
  `tesseract`-aware:
  it validates the shipped image OCR policy layer and accepts clear OCR
  failure when local OCR prerequisites are absent
* `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh` is the
  optional performance-observation entrypoint for the real image OCR path; it
  requires local `tesseract` plus installed `eng` tessdata
* OCR quality-lab helpers remain optional external validation against
  `markitdown-quality-lab/`; they do not enter the main validation entrypoints
* release snapshot helpers do not auto-build OCR tools, do not install
  `tesseract`, and do not download tessdata
* image OCR remains releaseable as an explicit local-runtime-dependent feature,
  while PDF OCR remains unshipped

Optional PDF scan diagnostics also stay outside this quick-check gate:

* `moon build debug --target native`
* `bash samples/helpers/contracts/check_pdf_scan_diagnostics.sh`
* `bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`
* `MARKITDOWN_DEBUG=_build/native/debug/build/debug/debug.exe bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`

These helpers are report-only PDF diagnostics. They reuse the explicit debug
path, do not run OCR, do not probe providers, do not change normal PDF output,
and do not enter the main validation entrypoints.

Future PDF OCR quality boundary:

* any future PDF OCR implementation should use a separate optional quality-lab
  corpus rather than reinterpreting the native PDF baseline
* main validation entrypoints must continue to avoid requiring OCR providers, OCR
  models, or tessdata
* future PDF OCR contracts should be provider-aware and should skip or fail
  clearly according to the chosen product policy
* current release checks only validate report-only PDF diagnostics; they do
  not execute PDF OCR

Current checked facts:

* `moon check`: pass
* `bash samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* `bash samples/check_quality.sh --format pdf`: `79` rows / `0` failed / `1`
  skipped / `0` expected_fail on the current repo-local quality-lab checkout
* `bash samples/check_quality.sh`: `315` rows / `0` failed / `1` skipped /
  `0` expected_fail on the current repo-local quality-lab checkout

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

These checks are optional advanced validation. They do not imply scanned-PDF OCR support
or broader OCR quality guarantees, and they do not change the normal document
path, which still never OCRs.

Current OCR product-policy boundary:

* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported
* image inputs now auto-OCR through `convert/vision`
* product image OCR depends on local `tesseract` and language data
* `--ocr-lang <LANG>` only affects image OCR and requires installed tessdata;
  there is no language auto-detection
* if local OCR runtime support is missing, image OCR fails clearly
* main validation entrypoints must not require `tesseract` or
  tessdata
* PDF OCR remains future explicit provider work and is not wired now

Current validation entrypoints for this product stage:

* required baseline:
  `moon check`
* required repo-local samples:
  `bash samples/check.sh`
* required external quality:
  `bash samples/check_quality.sh`
* OCR product contract:
  `bash samples/helpers/contracts/check_ocr_contract.sh`
* optional image OCR timing smoke:
  `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`
* optional external OCR artifact validation:
  `bash samples/helpers/quality/summarize_quality_lab_ocr.sh`,
  `bash samples/helpers/quality/check_quality_lab_ocr_preview.sh`,
  `bash samples/helpers/quality/check_quality_lab_ocr_resegmented_preview.sh`,
  and `bash samples/helpers/quality/check_quality_lab_ocr_ir_hints.sh`

Current quality-lab OCR corpus shape:

* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/manifest.tsv`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/source_catalog.tsv`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/images/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/expected_text/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/expected_markdown/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/tesseract_tsv/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/layout_preview/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/layout_preview_resegmented/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/ir_hints/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/ir_hints_resegmented/`

Current optional advanced-validation helper map:

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

None of the quality-lab helpers in this section invoke local `tesseract`.
Current optional local-runtime-dependent OCR diagnostics live on the product side:
`bash samples/helpers/contracts/check_ocr_contract.sh` and
`bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`.

None of the helpers in this section enter
the main `bash samples/check_quality.sh` entrypoint by default.

If a future explicit PDF OCR path is added, it should stay in its own
quality/contract lane rather than being folded into the current image OCR or
native PDF lanes.

The no-implicit-OCR contract helper
`bash samples/helpers/contracts/check_ocr_contract.sh` now also locks the
current image-OCR product layer:

* image default auto-OCR executes when local `tesseract` is available
* image `--ocr` executes when local `tesseract` is available
* image `--ocr-lang <LANG>` passes a Tesseract language value when local
  runtime support and tessdata are available
* image OCR fails clearly when local `tesseract` or requested tessdata are
  unavailable
* image `--no-ocr` fails clearly because no native image-to-Markdown path
  exists
* PDF `--ocr` still fails closed
* normal text/PDF paths still stay no-OCR

Public-only environments must not require `tesseract` or tessdata. When local
OCR runtime support or the requested language data is missing, the contract
expects a clear OCR failure rather than a fallback to native image conversion.

## C. Full Quality

The optional full quality gate uses the repo-root quality-lab:

* `git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`

Current checked facts:

* `bash samples/check_quality.sh` runs only lab-managed rows from
  `markitdown-quality-lab/external_quality/_quality_rows_staging/manifest.tsv`
* `bash samples/check_quality.sh --format pdf` runs the focused PDF slice of
  that same external corpus; current local snapshot is `79` rows / `0` failed /
  `1` skipped / `0` expected_fail
* `bash samples/check_quality.sh` currently passes on `315` approved rows with
  `0` failed / `1` skipped / `0` expected_fail in the repo-local quality-lab
  checkout

The current external corpus includes focused signal-level rows for
Python-Markdown footnote fixtures, official IRS/NIOSH PDF form/manual samples,
and DOCX note-definition behavior after footnotes/endnotes moved out of normal
body appendix sections. License-clear external EPUB/HTML strong-noteref samples
remain a future expansion target; current strong-noteref behavior is still
covered by repo-local synthetic samples.

Each `bash samples/check_quality.sh` invocation now creates an isolated
`.tmp/quality/runs/<run_id>/` workspace. Full and filtered runs can therefore
execute concurrently without sharing one `outputs/` or `summary.tsv` tree.

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
* external quality entrypoint
* user-facing sample entrypoints

If `markitdown-quality-lab/` is absent:

* `moon test` should still pass
* `bash samples/check.sh` should still pass
* `bash samples/check_quality.sh` should fail clearly with a clone hint
* `bash samples/check_quality.sh` should not fall back to repo-local quality rows

## D. Prohibited Paths

Do not stage or ship these as part of a main-repo release candidate:

* `markitdown-quality-lab/`
* `.external`
* legacy local manifests such as `external_manifest.local.tsv`
* `_build`
* `.tmp`
* `.mooncakes`

## Release Helpers

Release helpers build on the same public entrypoints rather than a separate
release-only workflow:

* `bash samples/helpers/release/summarize_release_readiness.sh`
* `bash samples/helpers/release/summarize_release_readiness.sh --strict`
* `bash samples/helpers/release/check_release_candidate.sh`
* `bash samples/helpers/release/check_release_candidate.sh --skip-bench`
* `bash samples/helpers/release/check_release_candidate.sh --full`
* `bash samples/helpers/release/print_release_summary.sh`

Current release dry-run helper contract:

* `summarize_release_readiness.sh` prints a sectioned local snapshot for
  required validation entrypoints plus optional diagnostics
* it does not redefine the main validation entrypoints
* it does not make optional diagnostics a release hard gate by default
* missing prebuilt tools for optional diagnostics are reported as `SKIP`
  unless `--strict` is set
* `--strict` upgrades missing optional-tool prerequisites into failures
* it does not run full quality by default
* it does not run OCR, `tesseract`, or provider probing by default
* optional OCR attribution smoke remains a manual helper rather than a release
  hard gate
* it does not build the main CLI automatically for OCR timing helpers
* it does not install `tesseract` or download tessdata for OCR checks

## Release Candidate Dry-Run Report

This report is a maintainer-facing recording template for one local release
candidate dry-run. It is not a new gate.

Current meaning:

* the default snapshot expects required quick checks to pass
* the default snapshot still allows optional diagnostics to `SKIP` when a
  prebuilt tool is missing
* the strict snapshot is intended for machines where local prerequisites have
  already been built explicitly
* the strict snapshot upgrades missing optional-tool prerequisites into
  failures
* optional diagnostics still do not replace the main validation entrypoints
* full quality remains a separate entrypoint and is not run by the snapshot by
  default
* the helper does not build tools automatically
* the helper does not run OCR, `tesseract`, or provider probing by default
* the strict snapshot still does not install `tesseract` or download tessdata

Paste-safe command order:

```bash
bash samples/helpers/release/summarize_release_readiness.sh
```

Optional strict preparation:

```bash
moon build debug --target native
moon build cli --target native
moon build convert/vision/tsv_preview_tool --target native
bash samples/helpers/release/summarize_release_readiness.sh --strict
```

Current dry-run report template:

```markdown
## Release readiness snapshot

Date:
Commit:
MoonBit toolchain:
Main repo status:
Quality-lab status:

### Required checks
- moon check:
- samples/check.sh:
- samples/check_quality.sh:
- samples/bench.sh:

### Optional diagnostics
- OCR quality-lab summary:
- OCR preview checks:
- OCR IR hint checks:
- PDF scan diagnostics:
- Product-path attribution smoke:

### Notes
- Optional diagnostics skipped:
- Known non-blocking warnings:
- Prohibited paths checked:
```

Interpretation rules:

* do not commit this report into the repository
* use it as human-facing material for a release note, issue, PR comment, or
  internal checklist
* do not turn benchmark numbers inside the report into a fixed performance
  promise
* product-path attribution numbers remain same-machine directional baselines

## Release Candidate Dry-Run Report

This report is a maintainer-facing recording template for one local release
candidate dry-run. It is not a new gate.

Current meaning:

* the default snapshot expects required quick checks to pass
* the default snapshot still allows optional diagnostics to `SKIP` when a
  prebuilt tool is missing
* the strict snapshot is intended for machines where the local prerequisites
  have already been built explicitly
* the strict snapshot upgrades missing optional-tool prerequisites into
  failures
* optional diagnostics still do not replace the main validation entrypoints
* full quality remains a separate entrypoint and is not run by the snapshot by
  default
* the helper does not build tools automatically
* the helper does not run OCR, `tesseract`, or provider probing

Paste-safe command order:

```bash
bash samples/helpers/release/summarize_release_readiness.sh
```

Optional strict preparation:

```bash
moon build debug --target native
moon build cli --target native
moon build convert/vision/tsv_preview_tool --target native
bash samples/helpers/release/summarize_release_readiness.sh --strict
```

Current dry-run report template:

```markdown
## Release readiness snapshot

Date:
Commit:
MoonBit toolchain:
Main repo status:
Quality-lab status:

### Required checks
- moon check:
- samples/check.sh:
- samples/check_quality.sh:
- samples/bench.sh:

### Optional diagnostics
- OCR quality-lab summary:
- OCR preview checks:
- OCR IR hint checks:
- PDF scan diagnostics:
- Product-path attribution smoke:

### Notes
- Optional diagnostics skipped:
- Known non-blocking warnings:
- Prohibited paths checked:
```

Interpretation rules:

* do not commit this report into the repository
* use it as human-facing material for a release note, issue, PR comment, or
  internal checklist
* do not turn benchmark numbers inside the report into a fixed performance
  promise
* product-path attribution numbers remain same-machine directional baselines

Legacy sibling quality-lab lookup and legacy `.external/...` resolution remain
compatibility-only and are no longer the recommended workflow.
