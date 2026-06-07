# Quality Runner

This directory holds the internal signal-level quality runner used by the
single quality entrypoint:

```bash
bash ./samples/check_quality.sh
```

Most users should start from `./samples/check.sh` or
`bash ./samples/check_quality.sh`, not from this directory directly.

## What Lives Here

* `check.sh`: internal runner implementation
* `manifest.tsv`: repo-tracked baseline metadata used by maintainers
* `schemas/signals.tsv`: signal syntax reference

The main repository does not provide fetch or curate scaffolding for external
quality samples. External sample selection, license review, source catalog
maintenance, and payload management belong to the separate quality lab.

## External Quality Corpus

The formal corpus root is:

```text
markitdown-quality-lab/external_quality/
```

The formal manifest is:

```text
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

Clone the quality lab into the repo root when running the external quality
checks locally:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

The quality lab is:

* a separate Git repository
* not a submodule
* not a release artifact

## Running Quality Checks

Preferred commands:

```bash
bash ./samples/check_quality.sh
bash ./samples/check_quality.sh --format pdf
```

`samples/check_quality.sh` passes explicit lab paths to `check.sh` and requires
the external quality manifest. It does not fall back to repo-local corpora or
alternate manifest layouts.

Each run writes isolated generated artifacts under:

```text
.tmp/quality/runs/<run-id>/
```

That run directory contains the current `summary.tsv`, `summary.md`,
`rows.tsv`, row-scoped `outputs/`, and a nested `workspace/` scratch root for
converter-local temporary files. This keeps full and filtered quality runs safe
to launch in parallel without sharing a single `.tmp/quality` workspace.
