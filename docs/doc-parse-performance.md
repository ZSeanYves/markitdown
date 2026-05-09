# doc_parse Performance

This document records the release-facing performance contract for the
`doc_parse/*` foundations inside `ZSeanYves/markitdown`.

It is intentionally narrower than the repository-wide benchmark docs:

* it focuses on lower-layer parsing / inspection foundations
* it distinguishes library hot paths from CLI end-to-end timing
* it does not turn checked local numbers into blanket format claims

## Scope

`doc_parse` performance discussions should separate:

* library parse / inspect / validate work
* converter-layer lowering work
* Markdown / metadata / asset emission
* CLI startup and file I/O

Only the first category belongs directly to `doc_parse`.

## Goal Layers

Performance goals are intentionally tiered.

### Small library hot path

For lightweight formats where startup and file I/O are not dominant:

* TXT / Markdown scanner / CSV / TSV / JSON / YAML / XML / HTML
* target sub-10ms small-case parse or scan paths where realistic
* treat this as a same-machine engineering target, not a universal SLA

### Native CLI end-to-end

Native CLI timings are measured separately because they include:

* process startup
* file open / path handling
* converter lowering
* Markdown / metadata / asset work

End-to-end CLI timing must not be read as library-only `doc_parse` cost.

### Medium and large files

For medium/large files, throughput and distribution matter more than a single
sub-10ms threshold.

Track:

* p50 / p95 where available
* slowest rows
* format-local hotspots

### Office / package / PDF families

Office/package/PDF formats are inherently heavier:

* ZIP / OOXML / EPUB pay archive/package costs
* XLSX / DOCX / PPTX pay OOXML relationship + XML model costs
* PDF pays native text extraction / geometry / model costs

These families should use separate budgets rather than inherit the lightweight
text-format target unchanged.

### Batch mode

Batch mode is a separate concern:

* amortized throughput matters more than single-file latency
* startup cost and repeated setup can dominate small rows
* compare normal-path vs batch-path behavior explicitly

## Current Benchmark Tooling Audit

Current public tooling:

* `./samples/bench.sh --suite smoke`
* `./samples/bench.sh --suite compare`
* `./samples/bench.sh --suite batch-profile`
* `./samples/bench_doc_parse.sh --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2`

Current benchmark corpus location:

* `samples/benchmark/`

What the current tooling measures well:

* same-machine native CLI smoke timing
* overlap comparison against Microsoft MarkItDown where a fair checked-in row
  exists
* batch-vs-normal profiling with startup and grouped outputs
* per-row summary artifacts under `.tmp/bench/...`
* direct `doc_parse/*` package timing for `open/parse/scan`, `inspect`, and
  `validate` on a checked local manifest without calling `convert/*`

What it still does not measure directly:

* `parse` vs `convert` vs `emit` vs `metadata/assets` split inside one
  end-to-end CLI row
* full `doc_parse` coverage for every package and stage in one runner
  (`pdf` is still deferred in the first library-harness round)
* broad p50 / p95 distribution rollups across all suites in a release-facing
  report

Current interpretation rule:

* smoke and compare numbers are still repository-level product timings first
* they are useful for release readiness and hotspot discovery
* they are not, by themselves, proof that a specific `doc_parse` package is
  solely responsible for a row's cost

## Library Harness

The direct `doc_parse/*` harness is intentionally separate from
`./samples/bench.sh`:

```bash
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

Key design points:

* one native benchmark process performs many in-process iterations
* the harness calls `doc_parse/*` APIs directly and never routes through
  `convert/*`
* the checked manifest lives at `samples/doc_parse_bench/manifest.tsv`
* summary artifacts are written under `.tmp/bench/doc_parse/`
* `--profile xlsx` adds internal XLSX parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics
* `--profile docx` adds internal DOCX parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics
* `--profile yaml` adds internal YAML-subset parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics

Measured stage model:

* lightweight text/markup/scanner packages:
  `parse` or `scan`, then `inspect`, then `validate` where that surface exists
* package/container foundations:
  `open`, then `inspect`, then `validate`
* OOXML semantic sublayers:
  semantic `parse_*_from_package` is measured on a pre-opened OOXML package so
  generic ZIP/OOXML open cost can be attributed separately

Interpretation caveats:

* sample file I/O is intentionally excluded from the measured inner loops
* the harness measures package APIs as they are exposed today, so
  string-oriented parsers and byte/package-open foundations are not forced into
  one artificial shape
* stage columns still use `*_ms`, but the harness records them with sub-ms
  decimal precision
* xlsx profile rows are stage-attribution aids, not release-facing stable API
  or latency promises
* docx profile rows are stage-attribution aids, not release-facing stable API
  or latency promises
* yaml profile rows are stage-attribution aids, not release-facing stable API
  or latency promises

## Current Baseline Commands

Release-facing baseline commands for this round:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

## Current Baseline Snapshot

The measured snapshot for this round is recorded in
[`docs/performance-baseline.md`](./performance-baseline.md).

Interpretation notes stay the same:

* lightweight text/structured formats are the primary candidates for sub-10ms
  library-path goals
* Office/package/PDF families need format-local budgets
* CLI startup and output work remain mixed into the repository-level smoke rows
* the library harness is the current source of truth for direct `doc_parse/*`
  timing and hotspot attribution
* any row above 10ms in the current smoke benchmark is a hotspot candidate,
  not automatic evidence of a `doc_parse` regression by itself

## Focused XLSX Follow-up

The current harness now includes an XLSX-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2
```

This mode exists to answer a narrow question: where the time goes inside
`parse_xlsx_workbook_from_package` on checked formula-heavy samples.

Current interpretation:

* the profile is only for hotspot attribution
* it does not change workbook semantics, formula trace policy, or validation
  behavior
* it should not be mistaken for a stable release-facing XLSX profiling API

## Focused DOCX Follow-up

The current harness also includes a DOCX-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2
```

This mode exists to answer a similarly narrow question: where the time goes
inside `parse_docx_document_from_package` on checked link-heavy samples.

Current checked follow-up result:

* `docx_link_heavy / parse`: `8.735 ms -> 4.985 ms`
* main remaining stage in the profile: `body_scan`
* `text_boxes`, `hyperlink_resolution`, and `media_resolution` are now
  effectively no-op or near-no-op on this sample

Current interpretation:

* the profile is only for hotspot attribution
* it does not change the source-native DOCX semantic model
* it does not switch `convert/docx` normal-path ownership
* it should not be mistaken for a stable release-facing DOCX profiling API

## Focused YAML Follow-up

The current harness also includes a YAML-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2
```

This mode exists to answer a narrower parser question: where the time goes
inside `parse_yaml_document` on checked large subset samples.

Current checked follow-up result:

* `yaml_large / parse`: `6.907 ms -> 5.925 ms` on the focused parse run
* main remaining stages in the profile: `parse_sequence`, `parse_nodes`,
  `parse_mapping`
* the main improvement came from cheaper line preparation and less repeated
  trim/copy work, not from changing YAML subset behavior

Current interpretation:

* the profile is only for hotspot attribution
* it does not expand or narrow the YAML subset boundary
* it does not change `convert/yaml` output ownership
* it should not be mistaken for a stable release-facing YAML profiling API

## Library vs CLI Guidance

When diagnosing a slow row:

1. identify whether the row is lightweight text, package/container, OOXML
   semantic, or PDF
2. determine whether the dominant cost is likely parsing, converter lowering,
   Markdown emission, metadata/assets, or CLI startup
3. optimize `doc_parse` only when the lower-layer hotspot is real and the fix
   preserves correctness, validation, and safety boundaries

## Non-goals

This document does not claim:

* sub-10ms for every format and file size
* full parse/convert/emit decomposition from the current public harness
* full spec support as a prerequisite for performance claims
* that converter/product policy belongs in `doc_parse`
