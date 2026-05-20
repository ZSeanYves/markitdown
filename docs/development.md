# Development Guide

This document explains how to work on the current repository as a developer.
It focuses on workflow, validation, and format-onboarding practice.

## CLI Entry Points

Recommended product-path build:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
moon build ocr --target native
moon build debug --target native
moon build bench --target native
```

Recommended product-path invocation:

```bash
./_build/native/debug/build/cli/cli.exe <input> [output]
```

Normal conversion:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe --version
./_build/native/debug/build/cli/cli.exe <input> [output]
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

Bundled PDF component:

```bash
./_build/native/debug/build/pdf/pdf.exe [normal] [--with-metadata] <input.pdf> [output]
```

Bundled ZIP component:

```bash
./_build/native/debug/build/zip/zip.exe [normal] [--with-metadata] <input.zip> [output]
```

OCR path:

```bash
./_build/native/debug/build/cli/cli.exe ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]
./_build/native/debug/build/ocr/ocr.exe [ocr] <input> [output]
```

Batch path:

```bash
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
```

Debug path:

```bash
moon build debug --target native
./_build/native/debug/build/debug/debug.exe [debug] --json <input>
./_build/native/debug/build/debug/debug.exe [debug] --with-ir --with-metadata-summary --with-normalization <input>
./_build/native/debug/build/debug/debug.exe [debug] <all|extract|raw|pipeline> <input> [output]
```

Benchmark/dev path:

```bash
moon build bench --target native
./_build/native/debug/build/bench/bench.exe _bench-noop
```

Unified debug inspect notes:

* `debug <input>` is the new multi-format inspect entrypoint
* `debug --json` emits a stable JSON report for scripts and regression checks
* `debug --with-ir` adds IR block previews
* `debug --with-metadata-summary` adds origin summary detail
* `debug --with-normalization` adds normalization summary when available
* PDF inspect now uses structured `pdf_backend`, `pdf_pages`,
  `pdf_text_model`, `pdf_images`, `pdf_annotations`, `pdf_links`,
  `pdf_pipeline`, and `normalization` sections
* normalization debug output now includes rule-level summaries in addition to
  change/stage aggregation
* legacy `debug <all|extract|raw|pipeline> ...` is a deprecated PDF alias; it
  prints the unified inspect report and only materializes Markdown when
  `[output]` is provided
* lightweight `cli` still exposes product-path `ocr`, but delegates execution
  to `ocr`
* lightweight `cli` no longer hosts `debug` or hidden benchmark commands;
  those routes now live behind explicit binaries
* lightweight `cli` owns the user-visible PDF/ZIP product surface, but routes
  those inputs through bundled `pdf` / `zip` components so the main
  binary stays under build-size guardrails
* the first gated-normal PDF layout gate is enabled by default in the normal
  PDF path, but it is intentionally narrow and can be disabled with
  `MARKITDOWN_PDF_LAYOUT_GATE=0`

## Convert package API hygiene

The `convert/*` packages are product-path implementation packages, not a wide
plugin surface.

Current policy:

* keep stable `parse_*` entrypoints public
* keep inspect/profile APIs public only when they are consumed by dispatcher,
  CLI, unified debug inspect, or blackbox integration tests
* keep format-internal helpers private whenever practical
* when adding tests for internal behavior, prefer same-package whitebox tests
  over widening the production public API

Metadata sidecar:

```bash
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
```

Development fallback remains:

```bash
moon run cli -- <input> [output]
moon run cli -- normal --with-metadata <input> <output.md>
```

Build-performance policy:

* prefer reusing an existing native CLI binary under `_build/native/*/build/cli/`
* validation and benchmark helpers now try a probe-validated native CLI first
* if no working native CLI is present, helpers build `cli` once with
  `moon build cli --target native`
* if a normal/product-path run needs bundled PDF or ZIP support, helpers also
  resolve `pdf` / `zip` and build each component once only when needed
* `zip` delegates embedded PDF entries to `pdf`, so ZIP validation no
  longer recompiles the vendored PDF native-text closure
* debug helpers build `debug` only when an explicit debug/dev surface is
  requested
* OCR helpers build `ocr` only when an explicit OCR surface is requested
* product-path and cold-start benchmark helpers build `bench` only when
  hidden benchmark commands are requested
* helpers no longer silently fall back to `moon run` unless
  `MARKITDOWN_ALLOW_MOON_RUN=1` is set explicitly
* packaged/product installs should keep `cli`, `pdf`, `zip`, and
  `ocr` in the same directory so the launcher can auto-discover bundled
  product components without environment overrides
* avoid running multiple `moon` commands in parallel; Moon lock contention and
  duplicate native builds can hide the real bottleneck
* avoid routine `moon clean`; a clean native CLI rebuild can be far slower than
  incremental `moon build cli --target native`
* if a lock looks stale, first confirm there is no active `moon`, `clang`,
  `cc`, or `ld` process before removing lock files or cleaning

Output rules:

* Markdown follows `[output]`
* directory-like `[output]` becomes `<output>/<input_stem>.md`
* metadata sidecar is written to `<markdown_dir>/metadata/<stem>.metadata.json`
* stdout mode does not write sidecar files
* batch v1 is a non-recursive directory runner
* batch v1 writes each top-level input file into its own isolated document root
  under `<output_dir>`, using `NNN-<input_stem>/<input_stem>.md`
* batch v1 writes `batch-summary.tsv` at the batch output root

## Temp Directories

The repository standard temp root is:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
```

Reuse this convention for new scripts and tests. Do not invent new root-level
temp layouts when an existing subtree is appropriate.

## Regression Commands

Full validation:

```bash
./samples/check.sh
```

Release-candidate readiness helper:

```bash
bash samples/helpers/check_release_candidate.sh
bash samples/helpers/check_release_candidate.sh --skip-bench
bash samples/helpers/check_release_candidate.sh --full
bash samples/helpers/print_release_summary.sh
```

Quality-corpus root discovery:

* checked-in public rows run directly from the main repository
* external/local rows now resolve payloads from, in order:
  `--corpus-root`, `MARKITDOWN_QUALITY_CORPUS`,
  `MARKITDOWN_QUALITY_LAB/corpus`,
  `markitdown-quality-lab/corpus`,
  optional sibling fallback `../markitdown-quality-lab/corpus`,
  then legacy `.external/quality_corpus`
* the recommended repo-local external-lab layout is:
  `markitdown-quality-lab/corpus`
* the preferred real migration path is now supported and exercised locally:
  `markitdown-quality-lab` can carry both the external quality corpus and
  the PDF layout-classifier lab without changing product/runtime behavior
* the recommended clone command is:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

* the recommended local shell setup, when you want explicit non-default roots, is:

```bash
export MARKITDOWN_QUALITY_LAB="$(pwd)/markitdown-quality-lab"
export MARKITDOWN_QUALITY_CORPUS="$MARKITDOWN_QUALITY_LAB/corpus"
export MARKITDOWN_LAYOUT_LAB="$MARKITDOWN_QUALITY_LAB/pdf_layout_classifier"
```

* runner/tool lookup now auto-discovers `markitdown-quality-lab/` at the repo root
* the environment variables are optional and mainly useful for non-standard paths
* the quality-lab is a nested independent Git repository, not a submodule
* the main repository `.gitignore` ignores `markitdown-quality-lab/`
* checked-in public-only validation does not require cloning the quality-lab
* normal product/runtime paths do not read the quality-lab
* `moon test` and `./samples/check.sh` should also pass without the
  quality-lab; the main repository now keeps only the small repo-tracked
  fixtures they directly require
* local external manifests should prefer corpus-root-relative payload paths
  under `sources/...`
* legacy `.external/quality_corpus/...` paths remain fallback-only during the
  migration window
* sibling `../markitdown-quality-lab` and legacy `.external` fallbacks remain
  temporary migration-window compatibility only

Legacy fallback lifecycle:

* current primary workflow is repo-local:
  `markitdown-quality-lab/corpus`,
  `markitdown-quality-lab/quality_rows/manifest.tsv`,
  and `markitdown-quality-lab/pdf_layout_classifier`
* the remaining migration-window fallbacks are:
  * `samples/quality_corpus/external_manifest.local.tsv`
  * legacy `.external/quality_corpus/...` path resolution
  * legacy `.external/layout_model/...` path mapping
  * optional sibling `../markitdown-quality-lab`
  * debug/layout-assist fallback for older local manifests
* remove those fallbacks only after all of the following are true:
  * repo-root `markitdown-quality-lab` full quality still passes
    `330 / 1 / 0`
  * public-only quality still passes `24 / 0 / 0`
  * `moon test` and `./samples/check.sh` still pass
  * no non-doc runtime/product reference depends on `.external/...`
  * no active workflow still depends on `external_manifest.local.tsv`
  * quality-lab continues to track `quality_rows/manifest.tsv` and
    `corpus/MANIFEST.tsv`
  * at least one full post-migration validation cycle has completed

Recommended external-lab smoke:

```bash
bash samples/quality_corpus/check.sh --corpus-root "$MARKITDOWN_QUALITY_CORPUS"
python3 markitdown-quality-lab/pdf_layout_classifier/scripts/export_manifest_features.py \
  --manifest markitdown-quality-lab/pdf_layout_classifier/manifest.tsv \
  --corpus-root markitdown-quality-lab/corpus \
  --sample-id heading_basic \
  --output-dir .tmp/pdf_layout_classifier/quality_lab_smoke_features
```

Main-repo layout-model entrypoint:

```bash
moon build doc_parse/pdf/layout_model_tool --target native
moon run doc_parse/pdf/layout_model_tool -- --help
```

This MoonBit tool is the repo-tracked export/infer entrypoint that quality-lab
scripts call into. Training/eval scripts and larger model/report assets remain
in `markitdown-quality-lab/pdf_layout_classifier`.

The repository keeps `./samples/check.sh` and `./samples/bench.sh` as the main
public validation entrypoints. Most helpers under `samples/helpers/` remain
internal or maintainer-oriented, except the explicit contract/smoke scripts
that are documented elsewhere in this guide.

Lower-layer package work:

* `doc_parse/ooxml`, `doc_parse/pdf`, and `doc_parse/epub` should be treated as
  reusable parsing substrates, not as places to hide converter-only Markdown
  semantics
* when hardening `doc_parse/*`, prefer direct lower-layer tests over relying
  only on converter Markdown regression
* use [../doc_parse/README.md](../doc_parse/README.md) for the package map,
  examples, and lower-layer benchmark location
* use [docs/doc-parse-foundation.md](./doc-parse-foundation.md) as the package
  maturity contract

## PDF lower-layer dependency

The native PDF lower layer lives under `doc_parse/pdf`.

Its backend currently depends on the vendored package tree under:

```text
doc_parse/pdf/vendor/mbtpdf
```

This vendored tree is maintained as part of the repository rather than through
a path-only external dependency in the root `moon.mod.json`.

Current product-trim rule:

* keep `pdf` on the narrow read-only subset under `doc_parse/pdf/raw`
* avoid reintroducing the broad vendored `@mbtpdf` facade into the product
  component build closure
* prefer parse-only/product-only packages such as `graphics/pdfopsread`
  instead of write/render-oriented facades when product code only needs read
  paths
* large static decode tables in the product path should stay compactly encoded
  where practical so native generated-C size does not balloon again

Main regression:

```bash
./samples/check.sh --markdown-only
```

Metadata regression:

```bash
./samples/check.sh --metadata-only
```

Assets regression:

```bash
./samples/check.sh --assets-only
./samples/helpers/check_debug_contract.sh
```

Validation runner policy:

* sample validation prefers a probe-validated native CLI when one is available
* if no working native CLI is available, validation builds `cli` once with
  `moon build cli --target native`
* if a validation row needs PDF or ZIP, validation resolves the bundled
  `pdf` / `zip` components and passes those paths to lightweight `cli`
* debug/OCR-specific validation uses `debug` / `ocr` rather than asking
  lightweight `cli` to host those command trees
* validation only falls back to `moon run` when
  `MARKITDOWN_ALLOW_MOON_RUN=1` is set explicitly
* set `MARKITDOWN_CLI=/abs/path/to/cli` to force a specific native/prebuilt CLI
* set `MARKITDOWN_PDF_CLI` or `MARKITDOWN_ZIP_CLI` to force specific bundled
  PDF/ZIP component binaries
* set `MARKITDOWN_DEBUG_CLI`, `MARKITDOWN_OCR_CLI`, or `MARKITDOWN_BENCH_CLI`
  to force dedicated debug/OCR/bench binaries
* set `MARKITDOWN_PDF_LAYOUT_GATE=0` to disable the narrow normal-path PDF
  layout gate during regression triage
* explicit native override is useful for speed, but only when the caller knows
  the binary matches the current source state
* `moon run` is slower because it includes MoonBit wrapper overhead and should
  not be used as the H3++ native-performance proof point

## External Quality Corpus Hygiene

Keep the quality-lab-backed external intake local and reproducible:

* `markitdown-quality-lab/` is an independent local Git repository and must
  not be added to the main repo
* any legacy `samples/quality_corpus/external_manifest.local.tsv` is local-only
  and must not be committed
* macOS AppleDouble `._*` files under `samples/quality_corpus/` should be
  removed rather than checked in
* lab-only quality rows and local sample payloads must remain outside the main
  repository
* benchmark outputs, OCR/model artifacts, and local corpus outputs stay out of
  version control
* the Ubuntu shell-portability fixes for `samples/quality_corpus/check.sh`
  are now part of the checked workflow, so Bash array/argv assumptions should
  be validated on both macOS and Linux before changing the script again

Validation UX controls:

```bash
SAMPLES_VERBOSE=1 ./samples/check.sh --markdown-only
SAMPLES_KEEP_TMP=1 ./samples/check.sh --markdown-only
CHECK_CONTINUE=1 ./samples/check.sh
```

Behavior:

* default mode uses compact progress output plus final summary
* `SAMPLES_VERBOSE=1` restores per-sample convert/diff logs
* `SAMPLES_KEEP_TMP=1` or `KEEP_TMP=1` preserves temp outputs for debugging
* `CHECK_CONTINUE=1` keeps `samples/check.sh` running after a failed stage

Default verification set:

```bash
moon info
moon fmt
moon check
moon test
./samples/check.sh
bash samples/quality_corpus/check.sh
./samples/bench.sh --suite smoke --kind smoke
bash samples/helpers/check_cli_contract.sh
bash samples/helpers/check_pdf_contract.sh
bash samples/helpers/check_zip_contract.sh
bash samples/helpers/check_batch_contract.sh
bash samples/helpers/check_debug_contract.sh
bash samples/helpers/check_ocr_contract.sh
```

GitHub Actions CI:

* checked-in workflow: `.github/workflows/ci.yml`
* default validation matrix: `ubuntu-latest`, `macos-latest`
* default CI commands: `moon build cli --target native`, `moon check`,
  `moon test`, `./samples/check.sh`
* manual benchmark job: `./samples/bench.sh --suite smoke --kind smoke` on
  `workflow_dispatch` only
* benchmark compare and batch profile remain local/manual rather than mandatory
  CI gates
* Windows shell validation remains a WSL/POSIX-shell story until a dedicated
  Windows workflow is added
* `moon publish` remains manual and is not automated by CI
* `./samples/check.sh` remains the checked exact-regression and contract gate
* `samples/quality_corpus/` is the separate signal-level gate for checked-in
  public rows plus quality-lab-managed external/full local rows
* the checked public quality manifest stays small and repo-owned; the broader
  full/local row set is managed from `markitdown-quality-lab/quality_rows`
* local real documents and licensed fixture payloads remain lab-only and must
  stay out of the main repository

## Benchmark Commands

Public benchmark smoke:

```bash
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite smoke --kind all
BENCH_ITERATIONS=3 BENCH_WARMUP=1 ./samples/bench.sh --suite smoke --kind smoke
MARKITDOWN_CLI=/abs/path/to/cli ./samples/bench.sh --suite smoke --kind smoke
```

Public overlap-only comparison benchmark:

```bash
./samples/bench.sh --suite compare --help
./samples/bench.sh --suite compare
```

Public batch profiling benchmark:

```bash
./samples/bench.sh --suite batch-profile
./samples/bench.sh --suite batch-profile --formats csv,json,html,xlsx,docx,pdf --counts 1,3 --memory auto
```

Public doc_parse library benchmark:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
```

Public product-path attribution benchmark:

```bash
./samples/bench.sh --suite product-path --help
./samples/bench.sh --suite product-path --smoke
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
```

Optional maintainer-only warning helper:

```bash
./samples/helpers/bench_warn.sh --suite batch_profile
```

Historical benchmark governance/planning references:

* [docs/archive/benchmark/](./archive/benchmark/)
* [samples/benchmark/README.md](../samples/benchmark/README.md)
* `./samples/check.sh --manifest-only`

Current benchmark entrypoints and artifact layout:

* [docs/benchmarking.md](./benchmarking.md)
* [docs/performance.md](./performance.md)

Notes:

* all benchmark suites use `MARKITDOWN_TMP_DIR`
* smoke benchmark now follows the same native-preferred runner policy as sample
  validation: `MARKITDOWN_CLI`, then probe-validated prebuilt native CLI, then
  fallback `moon run`
* smoke `summary.tsv` and `results.jsonl` record runner metadata so local
  warnings can distinguish native runs from `moon run` wrapper overhead
* batch profiling writes additive local artifacts under `.tmp/bench/batch_profile`
* benchmark warning checks are manual; use `--strict` only when intentionally
  gating a local benchmark run
* checked-in benchmark samples are intentionally small and stable; broader
  public/private corpora should follow the phase-2 corpus policy instead of
  being added ad hoc
* corpus manifests are validated through `./samples/check.sh --manifest-only`;
  the lower-level helper remains internal
* comparison benchmark expects a user-managed external `markitdown` command
* comparison benchmark does not create a repository-local Python virtual environment
* sample validation scripts now use isolated temporary directories and can be
  run without sharing one fixed `.tmp/samples` output tree; benchmark outputs
  remain under `.tmp/bench/...` for inspection
* ZIP/EPUB archive conversion now materializes entries under per-conversion
  archive roots with per-entry private temp/output directories, so repeated
  `./samples/check.sh --markdown-only` and
  `./samples/check.sh --assets-only` runs do not share one fixed
  archive-entry temp tree

## Adding Or Expanding A Format

When adding a format or materially expanding one:

1. wire the converter or parser
2. add dispatcher routing
3. add regression samples and expected outputs
4. add metadata regression where applicable
5. add assets regression where applicable
6. update docs with the current contract

Recommended minimum for a new format:

* one positive sample
* one conservative-boundary sample
* one metadata sample if block/asset origin matters
* one test package or black-box regression entry

When adding samples, keep both sides in sync:

* add source input under `samples/main_process/<format>/...`
* add the matching expected Markdown under
  `samples/main_process/<format>/expected/...`
* add checked sidecar fixtures under the same
  `samples/main_process/<format>/expected/...` subtree when the case should
  have a stable exact metadata snapshot
* no generator step is required for normal validation; the checked samples and
  expectations are maintained directly in-repo

## Support Documentation Discipline

Keep doc responsibilities separated:

* `README.mbt.md`: product entry and short support summary
* `README.md`: repository landing page and product quick start
* `docs/README.md`: document map and current primary entrypoints
* `docs/support-and-limits.md`: detailed support contract
* `docs/architecture.md`: architecture view
* `docs/metadata-sidecar.md`: sidecar schema and fill behavior
* benchmark docs: benchmark-only scope
* historical milestone and audit docs: reference material, not primary
  current-state truth

Do not duplicate full support matrices across all docs.

## Test Package Discipline

Use the repository's two existing test mechanisms intentionally:

### `test/` subpackages

Preferred for:

* blackbox conversion tests
* package-level API tests
* sample/fixture-driven tests
* tests that should import the package the same way downstream code does

These subpackages should follow the existing `moon.pkg` pattern used by:

* `convert/*/test`
* `core/test`
* `doc_parse/pdf/api/test`

### `*_wbtest.mbt` files in the package root

Keep whitebox tests in the package directory when they must exercise
package-internal helpers that are intentionally not part of the exported
contract.

Do **not** widen public APIs just to avoid a root-level whitebox test unless
the helper is genuinely valuable as a reusable package surface.

Practical rule:

* use `test/` subpackages for stable external behavior
* use root `*_wbtest.mbt` only for true internal-helper whitebox coverage

Common whitebox examples in this repository:

* PDF decision/heuristic tests such as heading, noise, merge, link-matching,
  and table/caption guards
* PPTX grouped-shape traversal, explicit table XML, hidden-slide parsing, and
  notes helper tests
* DOCX lower-layer hyperlink / notes / header-footer / text-box helper tests
* ZIP safe-path and asset-namespace planner tests

If a test only needs the package the way downstream code sees it, keep it in
`test/`. If it needs package-private helper state or internal decision tags,
keep it as a root-level `*_wbtest.mbt`.

### Integration layers

The repository intentionally has a third validation layer beyond package tests:

* `convert/convert/test`: cross-format metadata/provenance invariants
* `samples/check.sh --manifest-only`: enrollment and manifest integrity
* `samples/helpers/list_sample_inventory.sh`: maintainer-only sample-family
  inventory summary
* `samples/check.sh --markdown-only`: focused checked-Markdown regression
* `samples/check.sh --metadata-only`: focused metadata sidecar
  regression
* `samples/check.sh --assets-only`: focused asset export and
  asset-reference regression
* `samples/check.sh --contracts-only`: CLI/debug/batch contract-only validation
* `samples/check.sh --manifest-only`: enrollment plus benchmark-manifest
  validation
* `bash ./samples/quality_corpus/check.sh`: signal-level public-baseline plus
  quality-lab quality check

These scripts intentionally stay separate:

* `check_samples.sh` validates enrollment only
* `check.sh --markdown-only` validates the unified checked-in sample tree
* `check.sh --metadata-only` narrows to metadata-oriented cases
* `check.sh --assets-only` narrows to asset-oriented cases
* `check.sh --contracts-only` narrows to contract surfaces
* `check.sh --manifest-only` narrows to manifest governance checks

Treat these as integration tests, not replacements for either blackbox package
tests or root-level whitebox coverage.

## Choosing Validation Scope

### Mainflow conversion changes

Run at least:

```bash
./samples/check.sh --markdown-only
```

Typical files:

* `convert/*`
* `core/emitter_markdown.mbt`
* mainflow expected outputs

### Metadata / provenance / image-context changes

Run at least:

```bash
./samples/check.sh --metadata-only
```

Typical files:

* `core/metadata.mbt`
* `core/ir.mbt`
* `samples/main_process/*/metadata/*`

Text-format reminder:

* TXT is a conservative plain-text converter, not a Markdown parser
* XML is a conservative source-preserving converter, not a semantic XML parser

### Asset naming / export changes

Run at least:

```bash
./samples/check.sh --assets-only
```

Typical files:

* image export logic
* asset naming logic
* asset-related samples under `samples/main_process/*/assets/*`

### ZIP changes

Keep these rules explicit:

* validate and normalize entry paths before materialization
* keep temp extraction under `MARKITDOWN_TMP_DIR`
* preserve archive asset remap under `assets/archive/<entry-id>/...`
* keep unsupported entries as warning blocks or fail-closed where required
* remember that `.txt` and `.xml` ZIP entries should continue to flow through
  normal dispatcher-driven conversion rather than custom semantic handling

### EPUB changes

Keep these rules explicit:

* use `container.xml` and OPF, not ZIP sort order
* resolve manifest paths relative to OPF
* preserve spine order
* keep safe extracted-tree handling for local images
* keep per-item warning fallback for unsupported spine items
* do not treat EPUB container/OPF parsing as generic standalone XML conversion

## Metadata / Origin / Assets Notes

Current stable development assumptions:

* metadata schema is additive and sparse
* `ImageBlock` / `ImageData` is the shared image contract
* sidecar provenance is lightweight, not full anchoring
* TXT and XML currently produce no assets
* ZIP and EPUB asset remap should preserve container-level provenance

Avoid:

* backfilling absent optional origin fields with dummy null-like values
* introducing schema changes as part of incidental converter cleanup
* changing asset naming rules without assets regression updates

## OCR Boundary

OCR remains:

* an explicit subcommand path
* dependent on external tooling
* separate from the default `normal` mainflow

Do not describe OCR as the project’s default PDF contract.
