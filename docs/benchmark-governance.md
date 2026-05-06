# Benchmark Governance

This document defines the repository's benchmark governance contract for
second-round hardening.

It does not claim new performance results by itself. Its purpose is to make
future benchmark conclusions comparable, reviewable, and hard to overstate.

## Goals

Benchmark work in this repository should do three things:

* measure the default local non-OCR path without mixing in unrelated runners
* make runner/corpus/comparability boundaries explicit
* prevent unsupported or non-overlap cases from being counted as wins

This governance layer is intentionally stricter than the older "we have a bench
script" bar.

## Runner Classes

Benchmark records should distinguish these runner classes:

| Runner class | Meaning | Notes |
| --- | --- | --- |
| `native-binary` | prebuilt native `markitdown-mb` CLI binary | strongest local-performance reference |
| `moon-run-fallback` | `moon run` wrapper path for `markitdown-mb` | includes wrapper/build-tool overhead |
| `python-markitdown-path` | Microsoft MarkItDown command found in `PATH` | user-managed external environment |
| `python-markitdown-user-managed` | Microsoft MarkItDown command or Python explicitly supplied by env | still user-managed, still external |
| `user-override` | user supplied a non-default runner command | must not be mixed into default claims |

Execution-path labels should also stay explicit:

| Execution path | Meaning |
| --- | --- |
| `default-local-normal` | `normal` conversion path, no OCR, no cloud, no debug |
| `default-local-normal-vs-batch` | local `normal` loop vs `batch` comparison |
| `compare-overlap` | overlap-only local runner comparison vs Microsoft MarkItDown |
| `ocr` | explicit OCR path |
| `debug` | explicit debug/inspect path |

Default repository performance conclusions should be about the
`default-local-normal` path unless stated otherwise.

## Corpus Tiers

The checked-in benchmark corpus is split into tiers:

* `Tier 0`: regression samples under `samples/main_process`,
  `samples/metadata`, and `samples/assets`
* `Tier 1`: checked-in benchmark smoke corpus under
  `samples/benchmark/corpus.tsv`
* `Tier 2`: synthetic stress corpora and generators
* `Tier 3`: public real-world corpus via manifest
* `Tier 4`: private/manual local corpus via manifest

Tier 1 is the current checked-in benchmark baseline. Tier 3 and Tier 4 should
inform conclusions only when the manifest, provenance, and comparability notes
are recorded.

## Current Checked-in Corpus Coverage

The current checked-in benchmark controls live in:

* `samples/benchmark/corpus.tsv`
* `samples/benchmark/compare_corpus.tsv`
* `samples/benchmark/perf_thresholds.tsv`
* `samples/benchmark/corpus_manifest.example.tsv`

Coverage summary by format:

| Format | Small | Medium | Large | Batch | Assets-heavy | Metadata on/off | Degrade/error | Compare overlap | Current gap note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DOCX | yes | yes | yes | partial via batch-profile defaults | yes | yes | weak | yes | no explicit degrade/error benchmark row yet |
| PPTX | yes | yes | yes | no current batch-profile default | yes | yes | weak | yes | no metadata-rich compare row; no degrade/error benchmark row |
| XLSX | yes | yes | yes | partial via batch-profile defaults | no | yes | yes | yes | no assets-heavy row; formula cached/eval/unsupported/merged/typed rows now checked in |
| PDF | scenario-based, not strict size labels | scenario-based | scenario-based | partial via batch-profile defaults | yes | metadata gap in Tier 1 | yes | yes | no checked-in metadata-on benchmark row; no scanned/OCR corpus in default suite |
| HTML | yes | yes | yes | partial via batch-profile defaults | yes | yes | yes | yes | still overlap-only local HTML corpus; not a browser-grade workload |
| TXT | yes | yes | yes | no current batch-profile default | no | yes | weak | yes | no explicit degrade/error row |
| Markdown | yes | yes | yes | no current batch-profile default | no | yes | weak | yes | no explicit degrade/error row |
| CSV | yes | yes | yes | partial via batch-profile defaults | no | yes | yes | yes | no assets-heavy notion by design |
| TSV | yes | yes | yes | no current batch-profile default | no | yes | weak | no | no overlap corpus yet |
| JSON | yes | yes | yes | partial via batch-profile defaults | no | yes | weak | no | no overlap corpus yet |
| YAML | yes | yes | yes | no current batch-profile default | no | yes | weak | no | no overlap corpus yet |
| XML | yes | yes | yes | no current batch-profile default | no | yes | weak | no | no overlap corpus yet |
| ZIP | yes | yes | yes | partial via batch-profile manifest reuse | yes | yes | yes | no | no meaningful overlap corpus; native checked-in corpus is the current H3 reference |
| EPUB | yes | yes | yes | no current batch-profile default | yes | metadata gap in Tier 1 | weak | no | no metadata-on benchmark row; no overlap corpus |

Interpretation notes:

* `Batch` means "currently exercised by `bench_batch_profile.sh` defaults or
  easily by its current manifest reuse", not "every format already has a
  committed batch-profile baseline doc".
* `Metadata on/off` means checked-in benchmark rows exist for explicit metadata
  benchmarking in Tier 1, not merely that the product supports `--with-metadata`.
* `PDF` currently uses scenario-oriented text-PDF samples rather than a strict
  `small/medium/large` naming ladder.

## Current Harnesses

### `bench_smoke.sh`

Purpose:

* same-machine local smoke signals
* cross-format checked-in Tier 1 corpus
* optional metadata/image/extended tiers

Current strengths:

* broad checked-in format coverage
* native-preferred runner resolution
* explicit metadata-on rows through `run_kind=metadata`

Current limitations:

* no RSS measurement
* no explicit degraded/not-comparable taxonomy
* summary TSV is suite-specific rather than cross-suite normalized

### `bench_compare_markitdown.sh`

Purpose:

* overlap-only comparison against Microsoft MarkItDown

Current strengths:

* explicit external-runner isolation
* avoids OCR/cloud/plugin env vars
* overlap corpus is separate from smoke corpus

Current limitations:

* only overlap formats are compared
* no checked-in not-comparable registry yet
* summary TSV is runner-level only, not quality-aware

### `bench_batch_profile.sh`

Purpose:

* compare repeated `normal` runs against one `batch` run
* optional metadata-on/off and RSS probing

Current strengths:

* process model separation is explicit
* can measure startup floor and batch speedup shape
* already carries richer raw metrics than the other harnesses

Current limitations:

* default format scope is narrower than the smoke corpus
* raw schema is useful but not yet formally documented as a repository
  governance contract
* no "not comparable" concept because this is internal runner profiling only

## Result Field Policy

The current governance target is:

* keep suite-specific TSV summaries where they are already useful
* treat `results.jsonl` as the raw facts layer
* converge raw JSON fields across harnesses before trying to unify every TSV

Recommended raw field set:

| Field | Meaning |
| --- | --- |
| `suite` | `smoke`, `compare`, or `batch-profile` |
| `format` | format family |
| `sample` | stable sample id when applicable |
| `runner` | product/tool name |
| `runner_kind` | concrete runner resolution kind |
| `runner_class` | normalized runner class |
| `command` | executed command string |
| `execution_path` | `default-local-normal`, `compare-overlap`, etc. |
| `input_bytes` | input size in bytes |
| `output_bytes` | output Markdown size in bytes |
| `asset_count` | output asset count when meaningful; `null` otherwise |
| `metadata_enabled` | whether metadata sidecar mode was enabled |
| `debug_enabled` | whether debug mode was enabled |
| `ocr_enabled` | whether OCR path was used |
| `elapsed_ms` | wall-clock time in ms |
| `peak_rss_kb` | peak RSS in KB when measurable; `null` otherwise |
| `status` | `success`, `fail`, `degraded`, or `not_comparable` |
| `note` | optional human-readable clarification |

Current repository implementation after this P0.3 pass:

* raw JSON outputs now carry explicit suite/runner/status/execution-path fields
* RSS remains optional and suite-dependent
* TSV summaries remain suite-specific and are not yet a universal benchmark API

## Comparability Policy

Comparison results must separate four states:

* `success`: run completed and belongs to the stated comparable scope
* `fail`: run failed unexpectedly
* `degraded`: run completed, but the harness observed partial failures or a
  mixed batch result
* `not_comparable`: result must not be used in win/loss interpretation

`not_comparable` applies when any of these hold:

* format is unsupported on one side
* one side requires an optional dependency not present in the benchmark setup
* one side requires OCR/cloud/LLM/plugin assistance for the scenario being
  tested
* input ability does not overlap in a fair way
* output structures are too different for the intended comparison claim

Rules:

* `not_comparable` must never be counted as a win
* overlap-only comparison docs must say what overlap is being compared
* OCR/cloud/plugin-assisted paths are separate benchmark stories, not fallback
  evidence for the default local path

## H3 Conclusion Admission Rules

The repository may say:

* it has benchmark harnesses for smoke, overlap comparison, and batch profiling
* selected overlap corpora on a named machine favored one runner over another
* native-binary measurements are the strongest current local-performance
  reference
* `moon run` is a functional fallback but not the preferred proof point
* batch/profile/smoke scripts prefer prebuilt native CLI discovery and only
  fall back to `moon run` with an explicit warning

The repository should not say without broader evidence:

* "all formats are faster"
* "the project is universally faster than Microsoft MarkItDown"
* "OCR/cloud/plugin paths are part of the same local speed story"
* "one local benchmark baseline implies portability or universal parity"

## Current P0.3 TODOs

Still missing after this governance pass:

* explicit checked-in not-comparable registry rows for compare corpus growth
* broader overlap corpus for TSV / JSON / YAML / XML / ZIP / EPUB where fair
  and practical
* dedicated metadata-on benchmark rows for PDF / HTML / EPUB
* a more formal degraded/fail reason taxonomy in all summary TSV outputs
* optional checked-in benchmark result snapshots that are clearly labeled as
  historical local references rather than universal claims

## Recommended Next Step

The next benchmark-governance step should be:

1. expand Tier 1 compare/corpus annotations rather than claiming broader speed
   conclusions
2. add a lightweight comparability registry or compare-corpus notes file
3. keep any future "performance leadership" statement scoped to named runner,
   corpus, and machine evidence
