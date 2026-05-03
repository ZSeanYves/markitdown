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

Enrollment integrity:

```bash
./samples/check_samples.sh
```

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

Default verification set:

```bash
moon fmt
moon check
moon test
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/check_samples.sh
```

## Benchmark Commands

Internal smoke benchmark:

```bash
./samples/bench_smoke.sh --kind smoke
./samples/bench_smoke.sh --kind all
BENCH_ITERATIONS=3 BENCH_WARMUP=1 ./samples/bench_smoke.sh --kind smoke
```

Overlap-only comparison benchmark:

```bash
./samples/bench_compare_markitdown.sh --help
./samples/bench_compare_markitdown.sh
```

Batch profiling benchmark:

```bash
./samples/bench_batch_profile.sh
./samples/bench_batch_profile.sh --formats csv,json,html,xlsx,docx,pdf --counts 1,3 --memory auto
./samples/bench_warn.sh --suite batch_profile
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
* `docs/support-and-limits.md`: detailed support contract
* `docs/progress.md`: current stage and next candidates
* `docs/architecture.md`: architecture view
* `docs/metadata-sidecar.md`: sidecar schema and fill behavior
* benchmark docs: benchmark-only scope

Do not duplicate full support matrices across all docs.

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
