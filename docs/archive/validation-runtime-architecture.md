# Regression, benchmark, and temporary workspace architecture

Status: adopted validation entrypoint and temporary workspace contract

This contract defines the architecture boundary for the main validation
entrypoints and ignored `.tmp` workspaces. It keeps repo-local regression,
external quality signal, external benchmark signal, and temporary run outputs in
separate areas.

## Problem Statement

The project has three validation surfaces that can look similar from the command
line but have different ownership:

- product regression over repo-local samples
- external quality regression over `external_quality/`
- external benchmark runs over `external_bench/`

When those surfaces share fallback behavior, staging manifests, local caches, or
ad hoc output directories, the result is ambiguous. A public product gate can
start depending on external data, an external quality run can accidentally use
repo-local samples, or benchmark output can be mistaken for a durable corpus
artifact.

The architecture keeps each entrypoint explicit and keeps all run output under
ignored `.tmp/<area>/runs/<run-id>/` workspaces.

## Architecture Boundary

There are three public main-repository entrypoints:

- `samples/check.sh`
- `samples/check_quality.sh`
- `samples/bench.sh`

`samples/check.sh` is the self-contained product regression gate. It owns no
external corpus behavior.

`samples/check_quality.sh` is a bridge to the external quality corpus. It owns
execution and reporting, not corpus data.

`samples/bench.sh` is a bridge to the external benchmark corpus. It owns
execution and reporting, not benchmark payloads.

Ignored `.tmp` directories store run output only. They are not product runtime,
formal corpus layout, source catalog, license evidence, or benchmark input.

## Responsibilities

`samples/check.sh` is responsible for:

- reading repo-local samples only
- validating product behavior in a self-contained checkout
- supporting full-format default runs
- supporting `--format FMT`
- supporting focused markdown, metadata, and asset checks
- writing run output under `.tmp/check/runs/<run-id>/`

`samples/check_quality.sh` is responsible for:

- reading `markitdown-quality-lab/external_quality/MANIFEST.tsv`
- running external quality rows
- supporting full-manifest default runs
- supporting `--format FMT`
- writing summaries, diffs, logs, and workspaces under
  `.tmp/quality/runs/<run-id>/`
- reporting missing external lab state clearly

`samples/bench.sh` is responsible for:

- reading `markitdown-quality-lab/external_bench/MANIFEST.tsv`
- running external benchmark rows
- supporting `--format FMT`
- supporting benchmark layers such as `parser`, `convert`, `cli`, and `compare`
- supporting iteration, warmup, output, output-directory, and profile options
  when implemented by the script
- writing raw runs, summaries, logs, and reports under
  `.tmp/bench/runs/<run-id>/`
- reporting missing external lab state clearly

## Non-responsibilities

The three entrypoints do not define product runtime architecture, parser
architecture, converter architecture, or external corpus layout.

`samples/check.sh` does not provide full external quality coverage and does not
read `markitdown-quality-lab`.

`samples/check_quality.sh` does not define the public self-contained product
gate, does not own external corpus files, and does not use repo-local samples as
fallback.

`samples/bench.sh` does not use repo-local samples as benchmark corpus and does
not make universal performance claims.

Temporary tools, audit scripts, cleanup reports, dry-run inventories, generated
expected outputs, and local caches are not architecture layers. They may support
maintenance, but they must not become public entrypoints or formal corpus
inputs.

## Architecture Layers / Areas

### Product Regression Area

The product regression area is:

```text
samples/check.sh
repo-local samples
.tmp/check/runs/<run-id>/
```

This area is self-contained in the main repository. It is valid without
`markitdown-quality-lab`.

Supported public options are:

- `--format FMT`
- `--markdown-only`
- `--metadata-only`
- `--assets-only`
- `-h` / `--help`

The focused `--markdown-only`, `--metadata-only`, and `--assets-only` modes are
mutually exclusive. When no focused mode is supplied, the script runs the normal
markdown, metadata, and asset coverage in product-regression order.

If a user requests asset-only coverage for a format with no asset fixtures, the
script should explain that the format has no asset regression coverage instead
of silently implying meaningful asset coverage.

### External Quality Area

The external quality area is:

```text
samples/check_quality.sh
markitdown-quality-lab/external_quality/MANIFEST.tsv
.tmp/quality/runs/<run-id>/
```

The bridge reads formal external quality rows. It must not read
`_quality_rows_staging/`, `_local_cache/`, temporary downloads, or repo-local
samples as formal input.

Supported public options are:

- `--format FMT`
- `-h` / `--help`

Missing `markitdown-quality-lab/`, `external_quality/`, or
`external_quality/MANIFEST.tsv` must produce an explicit message that includes
the expected path and a useful clone/download instruction.

### External Benchmark Area

The external benchmark area is:

```text
samples/bench.sh
markitdown-quality-lab/external_bench/MANIFEST.tsv
.tmp/bench/runs/<run-id>/
```

The bridge reads formal external benchmark rows. It must not read
`_bench_rows_staging/`, `_local_cache/`, temporary downloads, or repo-local
samples as formal benchmark input.

Supported public options are:

- `--layer parser|convert|cli|compare`
- `--format FMT`
- `--iterations N`
- `--warmup N`
- `--output PATH`
- `--output-dir DIR`
- `--profile PROFILE`
- `-h` / `--help`

The compare layer may compare against Microsoft MarkItDown or another explicit
baseline, but every result is tied to the selected corpus, machine, parameters,
and tool versions.

### Temporary Workspace Area

The temporary workspace areas are:

```text
.tmp/check/runs/<run-id>/
.tmp/quality/runs/<run-id>/
.tmp/bench/runs/<run-id>/
```

The same pattern may exist in the external lab when a run is intentionally
executed there:

```text
markitdown-quality-lab/.tmp/quality/runs/<run-id>/
markitdown-quality-lab/.tmp/bench/runs/<run-id>/
```

Run directories may contain:

- `entrypoint.log`
- `summary.tsv`
- `diff/`
- `workspace/`
- `raw/`
- `reports/`

`.tmp` is ignored and disposable. It stores run output, diffs, logs, temporary
downloads, unpacked workspaces, generated-in-progress expected files, and
temporary reports. It never stores the only copy of a formal sample, expected
output, source catalog, license record, or benchmark corpus row.

## Invariants

- `samples/check.sh` reads repo-local samples only.
- `samples/check.sh` succeeds without the external lab.
- `samples/check_quality.sh` reads `external_quality/MANIFEST.tsv` as its
  formal input.
- `samples/check_quality.sh` never falls back to repo-local samples.
- `samples/bench.sh` reads `external_bench/MANIFEST.tsv` as its formal input.
- `samples/bench.sh` never uses repo-local samples as benchmark corpus.
- Missing external lab, corpus area, or manifest state is explicit.
- Formal manifests and source catalogs never reference `.tmp`.
- `.tmp` content is disposable and not formal corpus data.
- Validation scripts do not modify runtime, parser, or converter code.
- Temporary tools, audit scripts, and cleanup reports are not architecture
  layers.

## Validation Strategy

Validate the self-contained product path with:

- `moon check`
- `moon test`
- `samples/check.sh`
- `samples/check.sh --format FMT` for affected formats

Validate the external quality bridge with:

- `samples/check_quality.sh` when the external quality corpus is present
- `samples/check_quality.sh --format FMT` for affected formats
- explicit missing-lab checks when the external lab is absent

Validate the external benchmark bridge with:

- `samples/bench.sh` when the external benchmark corpus is present
- `samples/bench.sh --format FMT` and `--layer ...` for affected benchmark
  surfaces
- explicit missing-lab checks when the external lab is absent

Validate temporary workspace behavior by confirming run outputs land under
`.tmp/<area>/runs/<run-id>/` and no formal manifest or source catalog references
`.tmp`.

## Runtime Invariants

- Main repository build, test, and product regression do not require
  `markitdown-quality-lab`.
- External quality and benchmark bridges are optional signals with explicit
  failure messages when unavailable.
- Bridge scripts use formal manifests, not staging manifests, caches, or local
  samples.
- Benchmark results are contextual measurements, not product performance
  guarantees.
- Temporary workspace contents are never the only source of durable corpus or
  provenance data.

## Non-goals

This contract does not:

- migrate external corpus directories
- modify `samples/check.sh`, `samples/check_quality.sh`, or `samples/bench.sh`
- modify runtime, parser, or converter code
- modify quality or benchmark manifests
- clean `.tmp`
- define `pdf_model_training/`
- create public, private, local, suite, manifest-only, tag-query, or legacy
  entrypoint modes
- turn benchmark results into universal performance claims

## Change Rules

New validation behavior must preserve the three-entrypoint boundary. A new mode
is allowed only when it belongs clearly to one entrypoint and does not create
implicit fallback across product regression, external quality, and external
benchmark areas.

Bridge changes must keep missing external lab behavior explicit. They must not
silently skip unavailable corpora or substitute repo-local samples.

Temporary workspace changes must keep run output under
`.tmp/<area>/runs/<run-id>/` or an explicitly equivalent ignored workspace. No
formal manifest, source catalog, license record, expected output, or sample
payload may depend on `.tmp` as its only durable location.

Historical migration notes may document why staging paths or older modes were
retired. They must not make those paths or modes part of the current
architecture.
