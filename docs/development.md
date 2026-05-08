# Development Guide

This document explains how to work on the current repository as a developer.
It focuses on workflow, validation, and format-onboarding practice.

## CLI Entry Points

Recommended product-path build:

```bash
moon build --target native
```

Recommended product-path invocation:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

Normal conversion:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

OCR path:

```bash
./_build/native/debug/build/cli/cli.exe ocr <input> [output]
```

Batch path:

```bash
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
```

Debug path:

```bash
./_build/native/debug/build/cli/cli.exe debug --json <input>
./_build/native/debug/build/cli/cli.exe debug --with-ir --with-metadata-summary --with-normalization <input>
./_build/native/debug/build/cli/cli.exe debug <all|extract|raw|pipeline> <input> [output]
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
moon run cli -- normal <input> [output]
```

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

The repository keeps `./samples/check.sh` and `./samples/bench.sh` as the only
public validation entrypoints. Helpers under `samples/scripts/` remain
internal implementation detail or maintainer-only tooling.

Lower-layer package work:

* `doc_parse/ooxml`, `doc_parse/pdf`, and `doc_parse/epub` should be treated as
  reusable parsing substrates, not as places to hide converter-only Markdown
  semantics
* when hardening `doc_parse/*`, prefer direct lower-layer tests over relying
  only on converter Markdown regression
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
./samples/scripts/check_debug_contract.sh
```

Validation runner policy:

* sample validation prefers a probe-validated native CLI when one is available
* if the discovered native binary fails a small golden-output probe, validation
  falls back to `moon run`
* set `MARKITDOWN_CLI=/abs/path/to/cli` to force a specific native/prebuilt CLI
* explicit native override is useful for speed, but only when the caller knows
  the binary matches the current source state
* `moon run` is slower because it includes MoonBit wrapper overhead and should
  not be used as the H3++ native-performance proof point

Vendored PDF e2e policy:

* root `moon test` should pass without requiring generated vendored PDFs under
  `.tmp/scratch/mbtpdf/e2e`
* package/unit-style vendored PDF tests still run in the normal root suite
* optional vendored e2e remains available through:

```bash
moon test doc_parse/pdf/vendor/mbtpdf/e2e --include-skipped
```

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
moon build --target native
moon fmt
moon info
moon check
moon test
./samples/check.sh
./samples/check.sh --markdown-only
./samples/check.sh --metadata-only
./samples/check.sh --assets-only
./samples/check.sh --manifest-only
```

GitHub Actions CI:

* checked-in workflow: `.github/workflows/ci.yml`
* default validation matrix: `ubuntu-latest`, `macos-latest`
* default CI commands: `moon build --target native`, `moon check`, `moon test`,
  `./samples/check.sh`
* manual benchmark job: `./samples/bench.sh --suite smoke --kind smoke` on
  `workflow_dispatch` only
* benchmark compare and batch profile remain local/manual rather than mandatory
  CI gates
* Windows shell validation remains a WSL/POSIX-shell story until a dedicated
  Windows workflow is added
* `moon publish` remains manual and is not automated by CI
* `samples/real_world` now holds a checked-in complex-only scenario corpus
  with 11 long-form or stress rows
* default `./samples/check.sh` runs the full real-world corpus
* `./samples/check.sh --real-world` remains the focused rerun entrypoint, and
  `./samples/check.sh --real-world --tags complex` provides a complex-only
  rerun path

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

Optional maintainer-only warning helper:

```bash
./samples/scripts/bench_warn.sh --suite batch_profile
```

Phase-2 benchmark governance entry points:

* [docs/h3-phase-2-benchmark-governance.md](./h3-phase-2-benchmark-governance.md)
* [docs/benchmark-h3-plan.md](./benchmark-h3-plan.md)
* [samples/benchmark/README.md](../samples/benchmark/README.md)
* `./samples/check.sh --manifest-only`

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
* `docs/README.md`: document map and current primary entrypoints
* `docs/support-and-limits.md`: detailed support contract
* `docs/progress.md`: compact current project state and rollout summary
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
* `samples/scripts/list_sample_inventory.sh`: maintainer-only sample-family
  inventory summary
* `samples/check.sh --markdown-only`: focused checked-Markdown regression
* `samples/check.sh --metadata-only`: focused metadata sidecar
  regression
* `samples/check.sh --assets-only`: focused asset export and
  asset-reference regression
* `samples/check.sh --contracts-only`: CLI/debug/batch contract-only validation
* `samples/check.sh --manifest-only`: enrollment plus benchmark/real_world manifest validation
* `samples/check.sh --real-world [--tags complex]`: focused rerun of the
  complex-scenario corpus

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
