# Quality And Release

This page explains the current validation and release-readiness workflow.

It distinguishes between the self-contained main-repo checks and the optional
full quality path that uses the repo-local quality-lab.

## Validation Layers

The repository currently uses four layers:

1. `moon test`
2. `bash samples/check.sh`
3. `bash samples/check_quality.sh`
4. `bash samples/bench.sh --suite smoke --kind smoke`

They answer different questions.

## Main User Entry Points

The public sample entrypoints are `samples/check.sh`,
`samples/check_quality.sh`, and `samples/bench.sh`.

Recommended commands:

* `bash samples/check.sh` runs the full repo-local validation suite.
* `bash samples/check.sh --manifest-only` runs a lightweight manifest-only
  quick check.
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline.
* `bash samples/check_quality.sh` runs optional full quality when
  `markitdown-quality-lab/` is available.
* `bash samples/bench.sh --suite smoke --kind smoke` runs the benchmark smoke
  suite.
* `bash samples/bench.sh --help` shows available benchmark suites.

Internal helper paths exist for maintainers, but they are not the primary
onboarding surface.

## Repo-Local Validation

These commands do not require `markitdown-quality-lab`:

```bash
moon check
moon test
bash samples/check.sh --manifest-only
bash samples/check_quality.sh --public-only
bash samples/bench.sh --suite smoke --kind smoke
```

Current checked facts:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`

Use this path for normal development, refactors, bug fixes, and most CI-facing
work.

## Optional Full Quality

The optional full quality gate uses the repo-root quality-lab:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Then run:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

Current checked facts:

* full quality: `330 rows / 1 skipped / 0 expected_fail`
* focused PDF quality: `101 rows / 1 skipped / 0 expected_fail`

`public-only` means the repo-tracked baseline in
`samples/helpers/quality/manifest.tsv`.

`full quality` means that public baseline plus lab-managed rows from
`markitdown-quality-lab/quality_rows/manifest.tsv`.

`bash samples/check_quality.sh --public-only` does not depend on
`markitdown-quality-lab/`.

## Quality-Lab Boundary

The quality-lab carries:

* external corpus payloads
* tracked full/local quality rows
* PDF layout classifier training/eval/model/report assets
* helper/generator scripts that do not belong in runtime

The main repo keeps:

* runtime code
* mandatory test fixtures
* public sample corpus
* public-only quality baseline
* user-facing sample entrypoints

Important current fact:

* normal runtime and public-only validation do not depend on quality-lab
* full quality and offline layout work do
* `samples/helpers/*` are internal focused rerun helpers, not the main user
  entrypoints

## No-Quality-Lab Behavior

If `markitdown-quality-lab/` is absent:

* `moon test` should still pass
* `bash samples/check.sh` should still pass
* `bash samples/check_quality.sh --public-only` should still pass
* `bash samples/check_quality.sh` should fail clearly with a clone hint

That is the expected behavior.

## Release Helpers

Current release-oriented helpers:

```bash
bash samples/helpers/release/check_release_candidate.sh
bash samples/helpers/release/check_release_candidate.sh --skip-bench
bash samples/helpers/release/check_release_candidate.sh --full
bash samples/helpers/release/print_release_summary.sh
```

Those helpers build on the same public validation entrypoints rather than a
separate release-only workflow.

## Legacy Fallbacks

Primary path:

```text
markitdown-quality-lab/
```

Migration-window compatibility still exists for:

* legacy local manifest fallback
* sibling quality-lab lookup
* legacy `.external/...` resolution

They are compatibility-only and are no longer the recommended workflow.
