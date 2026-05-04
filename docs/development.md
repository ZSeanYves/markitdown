# Development Guide

This document explains how to work on the current repository as a developer.
It focuses on workflow, validation, and format-onboarding practice.

## CLI Entry Points

Normal conversion:

```bash
moon run cli -- normal <input> [output]
```

OCR path:

```bash
moon run cli -- ocr <input> [output]
```

Batch path:

```bash
moon run cli -- batch <input_dir> <output_dir>
```

Debug path:

```bash
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

Metadata sidecar:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
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

## PDF lower-layer dependency

The native PDF lower layer lives under `doc_parse/pdf`.

Its backend currently depends on the vendored package tree under:

```text
vendor/mbtpdf
```

This vendored tree is maintained as part of the repository rather than through
a path-only external dependency in the root `moon.mod.json`.

Main regression:

```bash
./samples/diff.sh
```

Metadata regression:

```bash
./samples/check_metadata.sh
```

Assets regression:

```bash
./samples/check_assets.sh
```

Validation runner policy:

* sample validation prefers a probe-validated native CLI when one is available
* if the discovered native binary fails a small golden-output probe, validation
  falls back to `moon run`
* set `MARKITDOWN_CLI=/abs/path/to/cli` to force a specific native/prebuilt CLI
* explicit native override is useful for speed, but only when the caller knows
  the binary matches the current source state
* `moon run` is slower because it includes MoonBit wrapper overhead

Validation UX controls:

```bash
SAMPLES_VERBOSE=1 ./samples/diff.sh
SAMPLES_KEEP_TMP=1 ./samples/diff.sh
CHECK_CONTINUE=1 ./samples/check.sh
```

Behavior:

* default mode uses compact progress output plus final summary
* `SAMPLES_VERBOSE=1` restores per-sample convert/diff logs
* `SAMPLES_KEEP_TMP=1` or `KEEP_TMP=1` preserves temp outputs for debugging
* `CHECK_CONTINUE=1` keeps `samples/check.sh` running after a failed stage

Default verification set:

```bash
moon fmt
moon check
moon test
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_samples.sh
./samples/check.sh
```

## Benchmark Commands

Internal smoke benchmark:

```bash
./samples/scripts/bench_smoke.sh --kind smoke
./samples/scripts/bench_smoke.sh --kind all
BENCH_ITERATIONS=3 BENCH_WARMUP=1 ./samples/scripts/bench_smoke.sh --kind smoke
```

Overlap-only comparison benchmark:

```bash
./samples/scripts/bench_compare_markitdown.sh --help
./samples/scripts/bench_compare_markitdown.sh
```

Batch profiling benchmark:

```bash
./samples/scripts/bench_batch_profile.sh
./samples/scripts/bench_batch_profile.sh --formats csv,json,html,xlsx,docx,pdf --counts 1,3 --memory auto
./samples/scripts/bench_warn.sh --suite batch_profile
```

Notes:

* both benchmark scripts use `MARKITDOWN_TMP_DIR`
* batch profiling writes additive local artifacts under `.tmp/bench/batch_profile`
* benchmark warning checks are manual; use `--strict` only when intentionally
  gating a local benchmark run
* comparison benchmark expects a user-managed external `markitdown` command
* comparison benchmark does not create a repository-local Python virtual environment
* sample validation scripts now use isolated temporary directories and can be
  run without sharing one fixed `.tmp/samples` output tree; benchmark outputs
  remain under `.tmp/bench/...` for inspection
* ZIP/EPUB archive conversion now materializes entries under per-conversion
  archive roots with per-entry private temp/output directories, so repeated
  `./samples/diff.sh` and `./samples/check_assets.sh` runs do not share one
  fixed archive-entry temp tree

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

* add source input under the appropriate `samples/main_process/*` or
  `samples/metadata/*` family directory
* add the matching expected Markdown under the corresponding `expected/`
  directory

## Support Documentation Discipline

Keep doc responsibilities separated:

* `README.mbt.md`: product entry and short support summary
* `docs/full-format-h2-completion.md`: compact milestone summary after a major
  format-completion phase
* `docs/support-and-limits.md`: detailed support contract
* `docs/progress.md`: current stage and next candidates
* `docs/architecture.md`: architecture view
* `docs/metadata-sidecar.md`: sidecar schema and fill behavior
* benchmark docs: benchmark-only scope

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
* `samples/scripts/check_samples.sh`: enrollment integrity
* `samples/diff.sh`: main Markdown regression
* `samples/check_metadata.sh`: metadata sidecar regression
* `samples/check_assets.sh`: asset export regression

These scripts intentionally stay separate:

* `check_samples.sh` validates enrollment only
* `diff.sh` validates main Markdown only
* `check_metadata.sh` validates metadata Markdown only
* `check_assets.sh` validates asset-producing outputs and referenced files

Treat these as integration tests, not replacements for either blackbox package
tests or root-level whitebox coverage.

## Choosing Validation Scope

### Mainflow conversion changes

Run at least:

```bash
./samples/diff.sh
```

Typical files:

* `convert/*`
* `core/emitter_markdown.mbt`
* mainflow expected outputs

### Metadata / provenance / image-context changes

Run at least:

```bash
./samples/check_metadata.sh
```

Typical files:

* `core/metadata.mbt`
* `core/ir.mbt`
* metadata samples

Text-format reminder:

* TXT is a conservative plain-text converter, not a Markdown parser
* XML is a conservative source-preserving converter, not a semantic XML parser

### Asset naming / export changes

Run at least:

```bash
./samples/check_assets.sh
```

Typical files:

* image export logic
* asset naming logic
* asset-related samples

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
