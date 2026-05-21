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

Public-only:

```bash
bash samples/helpers/quality/check.sh --public-only
```

Optional full quality through the preferred top-level entry:

```bash
bash ./samples/check_quality.sh
bash ./samples/check_quality.sh --format pdf
```

Current checked facts:

* public-only: `24 rows / 0 skipped / 0 expected_fail`
* full quality: `330 rows / 1 skipped / 0 expected_fail`
* focused PDF quality: `101 rows / 1 skipped / 0 expected_fail`

## Quality-Lab Boundary

Tracked lab-managed rows live in:

* `markitdown-quality-lab/quality_rows/manifest.tsv`

Payloads live in:

* `markitdown-quality-lab/corpus`

Clone the quality-lab into the repo root:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

The quality-lab is:

* a separate Git repository
* not a submodule
* not a release artifact

## Legacy Note

Legacy local manifests and legacy `.external/...` resolution still exist during
the migration window, but they are no longer the recommended path.
