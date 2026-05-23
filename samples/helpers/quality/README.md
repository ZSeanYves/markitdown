# Quality Runner

This directory now holds the internal signal-level quality runner
implementation used by:

```bash
bash ./samples/check_quality.sh
```

Most users should start from `./samples/check.sh` or
`bash ./samples/check_quality.sh`, not from this directory directly.

## What Lives Here

* `manifest.tsv`: repo-tracked public quality baseline
* `check.sh`: internal runner implementation
* `compare_tools.sh`: optional comparison helper
* `schemas/signals.tsv`: signal syntax reference
* `tools/`: helper scripts for fetching or curating lab-backed external samples

## Validation Modes

Preferred top-level entrypoints:

```bash
bash ./samples/check_quality.sh
bash ./samples/check_quality.sh --format pdf
```

Each top-level run writes isolated generated artifacts under:

```text
.tmp/quality/runs/<run_id>/
```

That run directory contains the current `summary.tsv`, `summary.md`,
`rows.tsv`, row-scoped `outputs/`, and a nested `workspace/` scratch root for
converter-local temporary files. This keeps full and filtered quality runs safe
to launch in parallel without sharing a single `.tmp/quality` workspace.

Current checked facts:

* `bash ./samples/check_quality.sh` runs only external/lab-managed rows
* row counts depend on the checked-out `markitdown-quality-lab` contents
* `bash ./samples/check_quality.sh --format pdf` is the focused PDF slice of
  that same external corpus

## Quality-Lab Boundary

Tracked lab-managed rows live in:

* `markitdown-quality-lab/external_quality/_quality_rows_staging/manifest.tsv`

Payloads live in:

* `markitdown-quality-lab/external_quality/`

Clone the quality-lab into the repo root:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

The quality-lab is:

* a separate Git repository
* not a submodule
* not a release artifact

## Internal Note

Internal/debug-only filters such as `--public-only`, `--private-only`, `--id`,
`--source`, and `--list` remain available here for maintainer use, but they are
not the recommended user entrypoints.

The top-level `bash ./samples/check_quality.sh` entrypoint now always requires
the external quality corpus and does not fall back to repo-local quality rows.
