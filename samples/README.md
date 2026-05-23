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

* `bash samples/check.sh` runs the full repo-local sample validation entrypoint.
* `bash samples/check_quality.sh` runs only the external quality corpus from
  `markitdown-quality-lab/external_quality/`.
* `bash samples/bench.sh` runs the default smoke benchmark suite.
* `.tmp/` is generated workspace only and must stay uncommitted.

## Primary Entry Points

These entrypoints are the normal onboarding surface:

* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf` runs the focused PDF quality
  slice
* `bash samples/bench.sh`
* `bash samples/bench.sh --help`

The optional full quality gate expects the repo-root quality-lab:

* `git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab`

If the quality-lab is absent, `bash samples/check_quality.sh` should fail
clearly with a clone hint and point back to `bash samples/check.sh` for
repo-local validation. It should not fall back to repo-local quality rows.

## Temporary Output Layout

Generated artifacts should stay under `.tmp/` and are not repository inputs.

Current top-level layout:

* `.tmp/check/` for repo-local sample validation and contract scratch output
* `.tmp/quality/runs/<run_id>/` for isolated external quality runs
* `.tmp/bench/<suite>/` for benchmark summaries and raw timing output
* `.tmp/validation/` for report-only validation helpers
* `.tmp/bench/helpers/` and `.tmp/quality/ocr_helpers/` for focused helper-only
  diagnostics

Each main entrypoint also pins converter-local scratch work under a nested
`workspace/` subtree so ZIP/EPUB/PDF unpack or staging files do not spill back
into ad-hoc `.tmp/*` roots:

* `samples/check.sh` uses `.tmp/check/workspace/`
* `samples/check_quality.sh` uses `.tmp/quality/runs/<run_id>/workspace/`
* `samples/bench.sh` uses `.tmp/bench/<suite>/workspace/`

`bash samples/check_quality.sh` now creates a unique run directory every time,
so full and filtered runs can be executed concurrently without clobbering each
other's `outputs/` or `summary.tsv`.

## Directory Roles

| Path | Role |
| --- | --- |
| `samples/main_process/` | repo-tracked user-visible sample corpus and expected outputs |
| `samples/fixtures/` | lower-layer and fail-closed fixtures |
| `samples/benchmark/` | checked benchmark corpus and manifests |
| `samples/helpers/bench/` | internal benchmark suite implementations and warning helpers |
| `samples/helpers/contracts/` | internal CLI, PDF, ZIP, batch, debug, and no-implicit-OCR contract checks |
| `samples/helpers/release/` | internal release-candidate and release-summary helpers |
| `samples/helpers/shared/` | shared shell helper libraries for temp dirs and runner resolution |
| `samples/helpers/validation/` | internal sample enrollment, manifest, and inventory helpers |
| `samples/helpers/quality/` | internal quality runner implementation and schema/helpers |
| `samples/fixtures/ocr/` | tiny license-clean OCR fixtures, manifest, and expected text for OCR policy/docs/optional smoke |

## Benchmark Helpers

Current public benchmark entrypoint:

* `bash samples/bench.sh`
* `bash samples/bench.sh --help`

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

Current lightweight image OCR attribution diagnostic helper:

* `moon build cli --target native`
* `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`

That helper:

* stays separate from the normal product-path attribution smoke
* uses the public native `cli.exe`
* supports `MARKITDOWN_CLI=/path/to/cli.exe`
* does not build internally
* runs real image OCR through local `tesseract`
* requires installed `eng` tessdata for the explicit `--ocr-lang eng` row
* prints a clear `SKIP` message and exits successfully when `tesseract` or
  `eng` tessdata is unavailable
* prints grep-friendly TSV to stdout
* writes transient output under `.tmp/helpers/image_ocr_bench/` only
  Current location is `.tmp/bench/helpers/image_ocr_bench/`.
* is a smoke/diagnostic tool, not a main validation gate, release hard gate, or
  performance promise

## PDF Diagnostics Helpers

Current report-only PDF scan diagnostics entrypoints:

* `moon build debug --target native`
* `bash samples/helpers/contracts/check_pdf_scan_diagnostics.sh`
* `bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`

That helper:

* uses the explicit debug CLI path rather than the normal product path
* checks that a normal text PDF stays `ocr_recommended=false`
* checks that a low-text, image-heavy PDF surfaces a report-only warning signal
* does not run OCR or `tesseract`
* does not probe OCR providers
* does not change normal Markdown output

The summary helper:

* emits stable TSV for a tiny repo-local PDF sample set
* requires a prebuilt debug binary and does not build internally
* supports a fixed-path override such as
  `MARKITDOWN_DEBUG=_build/native/debug/build/debug/debug.exe bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`
* reuses current `debug --json` output rather than a new PDF analyzer
* is an optional diagnostic, not a release hard gate
* writes helper-only scratch output under `.tmp/validation/`

## Current Facts

Current checked sample validation:

* markdown: `444`
* metadata: `85`
* assets: `90`
* failures: `0`

Current quality validation:

* `bash samples/check_quality.sh` is external-corpus-only; row counts depend on
  the checked-out `markitdown-quality-lab` contents
* `bash samples/check_quality.sh --format pdf` is the focused PDF slice of that
  same external corpus

## OCR/Vision Quality-Lab Helpers

These helpers are optional advanced validation only. They do not imply scanned-PDF
OCR support or broader OCR quality guarantees, and they do not change the
normal document path outside the explicit image OCR surface.

* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported
* image inputs now auto-OCR through `convert/vision`
* product image OCR depends on local `tesseract`; missing runtime support
  fails clearly
* `markitdown-mb samples/fixtures/ocr/tiny_ocr_sample.png --ocr-lang eng`
  exercises image OCR with an explicit Tesseract language value when local
  tessdata is installed
* `samples/fixtures/ocr/` stays limited to tiny, self-generated,
  project-license fixtures; real OCR corpus growth belongs in
  `markitdown-quality-lab`
* `samples/helpers/validation/check_ocr_fixtures.sh` validates OCR fixture
  manifest/licensing, path safety, and fixture-size policy without running OCR
  or requiring `tesseract`
* `bash samples/helpers/validation/check_quality_lab_ocr_scaffold.sh`
  validates the optional
  `markitdown-quality-lab/external_quality/ocr/_legacy_samples/` scaffold only;
  it is read-only and does not run OCR or require `tesseract`
* `bash samples/helpers/quality/summarize_quality_lab_ocr.sh` is the read-only
  OCR quality-lab summary helper; it summarizes checked-in corpus rows,
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
* `bash samples/helpers/contracts/check_ocr_contract.sh` now locks the shipped
  main-CLI OCR policy layer: image default auto-OCR, image `--ocr`, image
  `--ocr-lang`, image `--no-ocr`, and PDF `--ocr` fail-closed behavior; in
  `tesseract`-capable environments it also covers the tiny fixture
  `samples/fixtures/ocr/tiny_ocr_sample.png`
* `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh` is the
  separate same-machine directional timing smoke for the main-CLI image OCR
  path; it uses the tiny repo-local fixture plus local `tesseract`, skips
  cleanly when prerequisites are missing, and does not enter the main
  validation entrypoints

## Release Helpers

Release helpers build on the same public entrypoints:

* `bash samples/helpers/release/summarize_release_readiness.sh`
* `bash samples/helpers/release/summarize_release_readiness.sh --strict`
* `bash samples/helpers/release/check_release_candidate.sh`
* `bash samples/helpers/release/check_release_candidate.sh --skip-bench`
* `bash samples/helpers/release/check_release_candidate.sh --full`
* `bash samples/helpers/release/print_release_summary.sh`

The release-readiness snapshot helper:

* prints a sectioned dry-run snapshot for required validation entrypoints and optional
  diagnostics
* keeps optional diagnostics outside the main validation entrypoints
* skips missing optional prebuilt-tool prerequisites by default
* treats missing optional prebuilt tools as failures only with `--strict`
* does not run full quality by default
* does not run OCR, `tesseract`, or provider probing
* keeps the human report template in
  [docs/quality-and-release.md](../docs/quality-and-release.md)
* leaves the final release dry-run report as a manual record rather than a
  generated artifact
* keeps the human report template in
  [docs/quality-and-release.md](../docs/quality-and-release.md)
* leaves the final release dry-run report as a manual record rather than a
  generated artifact

## Notes

* `samples/helpers/*` are internal focused rerun helpers, not the main user
  entrypoints
* `samples/helpers/quality/check.sh` remains available for compatibility, but
  it is an internal runner implementation rather than the preferred top-level
  entry
* internal/debug-only focused modes such as `--manifest-only` and
  `--public-only` are no longer recommended user entrypoints
* the rest of `samples/helpers/` is organized by role instead of a flat script
  list
* `samples/quality_corpus/` has been removed from the user-visible samples tree
* `samples/pdf_layout_classifier/` no longer exists in the main repo
* training/eval/model/report assets live in the repo-root quality-lab, not in
  `samples/`
