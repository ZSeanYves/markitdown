# Quality And Release

This page describes the current validation and release-readiness workflow. It
separates public repo-local checks from optional external quality-lab checks.

## Public Entry Points

Use these from the main repository:

```bash
moon check
bash samples/check.sh
bash samples/bench.sh --help
```

`moon test` is recommended before behavior-affecting changes, but a
documentation-only change does not normally require it.

`samples/check.sh` is the repo-local sample validation entrypoint. It does not
require `markitdown-quality-lab/`.

## External Quality

The external quality entrypoint is:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

It expects a repo-root `markitdown-quality-lab/` checkout with
`external_quality/` rows. It does not make quality-lab a runtime dependency and
does not mean those corpus files should be committed to the main repository.

`docs/quality-comparisons/` is preserved as a notebook area for comparison
writeups. It was not cleaned up in this documentation reset and should be
updated separately.

## Release Readiness

The release summary helper is:

```bash
bash samples/helpers/release/summarize_release_readiness.sh
```

Its current role is to collect required checks and optional diagnostics into a
single local snapshot. It does not download dependencies, build every optional
tool automatically, or run a full benchmark suite as a hidden side effect.

Use the result as a maintainer-facing release note/checklist input, not as a
checked-in generated report.

## OCR And PDF Diagnostics

Image OCR is a shipped product path, but it depends on local `tesseract` and
language data. Public repo-local checks must not require local OCR runtime
support.

PDF scan diagnostics are report-only:

* they may classify a PDF as low-text or image-heavy
* they do not run OCR
* they do not probe providers
* they do not change normal PDF output

PDF OCR is still future explicit provider work.

## Benchmark Boundary

`samples/bench.sh --help` is safe as a quick check. Real benchmark runs are
manual, sample-scoped, and should be interpreted with
[performance.md](./performance.md).

Do not treat benchmark numbers as universal guarantees.

## Release Hygiene

Before proposing a release or force push:

* keep the main repo clean
* keep `markitdown-quality-lab/` out of the main repo index
* keep `.external/`, `_build/`, `.tmp/`, `.mooncakes/`, and local manifests out
  of tracked files
* keep generated reports and benchmark outputs out of commits unless a task
  explicitly asks for them
* keep documentation claims aligned with current shipped behavior
