# Regression Tooling

`tools/regression/` contains the release-facing validation entrypoints. The
scripts do not infer quality from file names or output size: every case is
enrolled in a manifest with an explicit expected output or executable signal.
Formal corpora come from the quality-lab commit pinned by
`MARKITDOWN_QUALITY_LAB_SHA` in CI.

## Entry Points and Verdicts

| Command | Evidence source | Pass/fail basis |
| --- | --- | --- |
| `check_balance.sh` | `external_main_process/MANIFEST.tsv` | Exact Markdown/OCR output, structured RAG expectations, and exact asset files |
| `check_balance_quality.sh` | `external_quality/MANIFEST.tsv` | Approved real-world files satisfy every declared semantic/asset signal |
| `check_accurate.sh` | `external_accurate/MANIFEST.tsv` | Accurate runtime preflight succeeds and every accurate-only signal passes |
| `check_coverage.sh --enforce` | MoonBit Cobertura output | core >=90%, formats >=80%, tools >=70% |
| `mutation_smoke.py` | Deterministic mutations of enrolled seeds | Two runs are identical and each mutation either succeeds with non-empty output or fails cleanly on stderr |
| `self_baseline.py` | Benchmark `samples.jsonl` plus the approved platform baseline from `markitdown-quality-lab/performance_baselines/` | Fingerprints, inputs and output hashes match; median time/RSS regress by no more than 10% |

## Main Contract: Exact Results

`check_balance.sh` reads rows with:

```text
id  format  lane  input_path  expected_path  notes
```

The lane selects the judge:

- `markdown` / `ocr`: generated Markdown must exactly match the checked-in
  expected file. A conversion error, missing expected file or diff is failure.
- `rag`: output must be valid JSON and contain the declared output/format/mode,
  metadata, diagnostics, source-map policy and chunk expectations. Expected
  arrays are subset checks unless an exact count is declared.
- `assets`: `result.md` must match exactly; every local `assets/...` reference
  must exist; relative file names and bytes under the actual `assets/` tree must
  exactly equal the expected tree.

The main gate does not accept skips. Its summary must report all manifest rows
checked with zero failures and zero skipped rows.

## Quality and Accurate: Executable Signals

Quality and accurate manifests identify provenance and legality as well as the
expected behavior. Important columns are:

- `path`, `format`, `features`, `validation_view`
- `source_id`, `original_url`, `local_cache_path`
- `license_status`, `license_review_status`, `privacy`
- `expected_signals`, `quality_tier`

An external row is runnable only when its license review is `approved` and its
payload exists. Each semicolon-separated signal must pass. Supported judges
include:

```text
no_empty_output
contains / contains_all / not_contains
exact_count / min_count / max_count / order
heading_marker / table_marker / image_ref / link_ref
asset_count_min / asset_count_exact / asset_exists
asset_sha256 / asset_magic
line_fragmentation_max / max_long_token_len / page_noise_absent
```

Signals are evaluated against the requested Markdown, debug or provenance view.
Asset paths must remain inside the artifact directory; hashes and magic bytes
validate actual files, not merely Markdown links.

`check_balance_quality.sh` rejects rows tagged `accurate`. It also requires the
managed balance/audio fingerprints. `check_accurate.sh` first checks the
PaddleOCR import, wrapper protocol, models, Tesseract and `pdftoppm`, then runs
only the declared accurate formats.

License rejection, missing payload and absent executable signals are recorded
as distinct skip reasons. Formal release evidence requires zero unexpected
skips. `known_bad` rows may be `expected_fail`; an unexpected pass is surfaced
separately and must be reviewed rather than silently changing the expectation.

## Coverage, Mutation and Baselines

Coverage groups are defined in `lib/coverage_gate.py`. Generated PDF tables are
excluded explicitly; parser/control-flow files are not. `--enforce` returns
non-zero when any group misses its threshold.

Mutation smoke covers PDF, ZIP, Office/EPUB, XML/HTML and EML using truncation,
middle-byte corruption and appended NUL data. Timeout, empty successful output,
stdout errors or nondeterministic results fail the check.

Self-baseline enforcement requires five successful samples per tool/case,
stable input/output hashes, recorded CLI RSS, an approved baseline, and exact
platform/runner/runtime fingerprints. Fingerprint drift creates a candidate; it
never silently reuses an incompatible baseline. The quality lab tracks the
reviewed macOS arm64 and Linux x64 baseline files and their shared JSON schema.

## Running and Reading Evidence

```bash
moon build cli --target native
./tools/regression/check_balance.sh
./tools/regression/check_balance_quality.sh
./tools/regression/check_accurate.sh
./tools/regression/check_coverage.sh --enforce
python3 tools/regression/mutation_smoke.py
```

Each entrypoint prints its run directory and writes a `summary.md`/`summary.tsv`
plus failure-only diffs, raw stdout/stderr and per-row reports under `.tmp/`.
`run_with_release_manifest.sh` additionally records repository/runtime
fingerprints and required artifacts. Any child non-zero exit or missing required
artifact is propagated as failure.

Use `--format`, `--source` or `--id` filters while diagnosing a row; filters do
not change its judge, license requirements or expected signals. Full evidence
must run without filters.
