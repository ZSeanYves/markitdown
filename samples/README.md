# Samples

The `samples/` tree contains the repo-tracked validation corpus and developer
entrypoints.

Repository docs entrypoints:

* [docs/architecture.md](../docs/architecture.md)
* [docs/supported-formats.md](../docs/supported-formats.md)
* [docs/quality-and-release.md](../docs/quality-and-release.md)
* [docs/pdf.md](../docs/pdf.md)
* [docs/performance.md](../docs/performance.md)
* [docs/roadmap.md](../docs/roadmap.md)

Current primary commands:

* `bash samples/check.sh --manifest-only` runs the lightweight repo-local
  quick check.
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline.
* `bash samples/bench.sh --suite smoke --kind smoke` runs the benchmark smoke
  suite.

## Entry Points

### `samples/check.sh`

Repo-local validation entrypoint.

Use it for:

* checked sample regression
* metadata sidecar validation
* asset validation
* contract validation

Recommended commands:

* `bash samples/check.sh --manifest-only` for the lightweight quick check
* `bash samples/check.sh` for the full repo-local validation suite

It does not require `markitdown-quality-lab`.

### `samples/check_quality.sh`

Optional full quality entrypoint.

Use it for:

* the broader signal-level quality gate
* quality-lab-backed rows
* focused format checks such as `--format pdf`

Recommended commands:

* `bash samples/check_quality.sh --public-only` for the checked-in public
  baseline
* `bash samples/check_quality.sh` for optional full quality when
  `markitdown-quality-lab/` is available

It requires the repo-root quality-lab:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

### `samples/bench.sh`

Benchmark and compare entrypoint.

Use it for:

* smoke benchmark
* compare benchmark
* batch/profile runs

Recommended commands:

* `bash samples/bench.sh --suite smoke --kind smoke` for the smoke suite
* `bash samples/bench.sh --help` to list available suites

`samples/bench.sh` requires an explicit suite. Do not run it bare.

## Directory Roles

| Path | Role |
| --- | --- |
| `samples/main_process/` | repo-tracked user-visible sample corpus and expected outputs |
| `samples/fixtures/` | lower-layer and fail-closed fixtures |
| `samples/benchmark/` | checked benchmark corpus and manifests |
| `samples/helpers/bench/` | internal benchmark suite implementations and warning helpers |
| `samples/helpers/contracts/` | internal CLI, PDF, ZIP, batch, debug, and OCR contract checks |
| `samples/helpers/release/` | internal release-candidate and release-summary helpers |
| `samples/helpers/shared/` | shared shell helper libraries for temp dirs and runner resolution |
| `samples/helpers/validation/` | internal sample enrollment, manifest, and inventory helpers |
| `samples/helpers/quality/` | internal quality runner implementation and schema/helpers |
| `samples/fixtures/ocr/` | tiny license-clean OCR fixtures, manifest, and expected text for OCR policy/docs/optional smoke |

## Current Facts

Current checked sample validation:

* markdown: `444`
* metadata: `85`
* assets: `90`
* failures: `0`

Current quality validation:

* public-only: `24 / 0 / 0`
* full quality: `330 / 1 / 0`
* focused PDF quality: `101 / 1 / 0`

## Notes

* `samples/helpers/*` are internal focused rerun helpers, not the main user
  entrypoints
* `samples/fixtures/ocr/` is reserved for tiny, self-generated,
  project-license fixtures that stay provider-independent where possible
* OCR sample growth should stay split: tiny provider-independent fixtures in
  the main repo, real-world OCR corpus in `markitdown-quality-lab`
* the previous text-only OCR prototype has been retired; current OCR helper
  coverage is about fixture policy and future rebuild boundaries
* `samples/helpers/validation/check_ocr_fixtures.sh` validates OCR fixture
  manifest/licensing, path safety, and fixture-size policy without running OCR
  or requiring tesseract
* `bash samples/helpers/contracts/check_ocr_tesseract_smoke_optional.sh` is
  a skip-safe future wiring placeholder, not a required main entrypoint path or
  native quality gate
* `samples/helpers/quality/check.sh` remains available for compatibility, but
  it is an internal runner implementation rather than the preferred top-level
  entry
* the rest of `samples/helpers/` is now organized by role instead of a flat
  script list
* `samples/quality_corpus/` has been removed from the user-visible samples tree
* `samples/pdf_layout_classifier/` no longer exists in the main repo
* training/eval/model/report assets live in the repo-root quality-lab, not in
  `samples/`
