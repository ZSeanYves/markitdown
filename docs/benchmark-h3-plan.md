# Benchmark H3 Plan

This document captures the current benchmark harness contract and the planned
H3 benchmark-discipline work.

It is intentionally a planning document, not a new benchmark baseline. The
current baseline values remain in:

* [docs/benchmark-baseline.md](./benchmark-baseline.md)
* [docs/benchmark-comparison-baseline.md](./benchmark-comparison-baseline.md)

## Current Benchmark Contract

### Smoke benchmark

The smoke benchmark is the repository's internal same-machine performance
tracking harness:

* script: `samples/bench_smoke.sh`
* corpus: `samples/benchmark/corpus.tsv`
* main output root: `.tmp/bench/smoke`
* primary artifacts:
  * `results.jsonl`
  * `summary.tsv`

Current behavior:

* reads checked-in corpus rows across `smoke`, `image`, `metadata`, and
  `extended`
* supports warmup and repeated measured iterations
* records median and average elapsed time
* records output bytes, asset count, and exit status
* builds once before benchmarking
* currently invokes the repository runner through `moon run`

Interpretation:

* useful for internal cross-format smoke tracking
* useful for same-machine trend observation
* not the final native-CLI speed contract for H3 claims

### Comparison benchmark

The overlap-only comparison benchmark is the repository's selected-case runner
comparison harness:

* script: `samples/bench_compare_markitdown.sh`
* corpus: `samples/benchmark/compare_corpus.tsv`
* main output root: `.tmp/bench/compare`
* primary artifacts:
  * `results.jsonl`
  * `summary.tsv`

Current behavior:

* supports TSV corpora with or without a header row
* supports warmup and repeated measured iterations
* resolves the repository runner in this order:
  * `MARKITDOWN_MB_CMD`
  * prebuilt native CLI
  * fallback `moon run`
* resolves the Microsoft runner in this order:
  * `MARKITDOWN_COMPARE_CMD`
  * `markitdown` from `PATH`
  * `MARKITDOWN_COMPARE_PY_BIN -m markitdown`
* records median, average, runner versions, output bytes, and stderr bytes
* isolates Python-side temp/cache/home state for cleaner local comparison

Interpretation:

* comparison is overlap-only
* comparison does not claim full semantic parity
* prebuilt native CLI is the preferred H3 speed reference
* `moon run` fallback is acceptable for functionality, but not for strong speed
  conclusions

### Shared current assumptions

* `.tmp/bench/...` outputs are temporary local artifacts for inspection and do
  not belong in version control
* benchmark outputs are intentionally kept on disk for manual inspection
* selected overlap speed wins are not blanket claims for every possible
  document or layout

## Current Harness Gaps

The current benchmark system is already useful, but it is not yet a complete H3
discipline.

Current gaps:

* no batch benchmark mode yet
* no normalized small/medium/large policy across every format
* no optional memory probe yet
* no lightweight regression-warning workflow yet
* smoke harness still uses `moon run`, so it mixes product work with wrapper
  overhead
* benchmark output roots are fixed under `.tmp/bench/smoke` and
  `.tmp/bench/compare`, which is convenient for inspection but not ideal for
  concurrent runs

See [docs/benchmark-batch-design.md](./benchmark-batch-design.md) for the H3.2
batch-design audit and recommendation set.

## H3 Target Capabilities

### 1. Batch benchmark

Target:

* measure per-process startup overhead separately from batch throughput
* allow one runner process to handle multiple files when the CLI grows that
  capability
* make text-like and structured-data formats easier to profile at scale
* keep `process-per-file` and `single-process` results clearly separated

Formats that benefit first:

* TXT
* Markdown
* CSV / TSV
* JSON
* HTML
* DOCX
* PDF

### 2. Large corpus benchmark

Target:

* make `small / medium / large` more consistent as a format-family convention
* ensure each supported format has at least one representative large case
* separate capability coverage from scale coverage more clearly

This does not require generating all missing large samples in one pass.

### 3. Memory profiling

Target:

* add an optional memory-observation path without introducing heavy tooling
* keep the default benchmark flow simple

Practical direction:

* design for optional `/usr/bin/time -l` on macOS
* design for optional `/usr/bin/time -v` on Linux
* document platform differences explicitly
* do not make memory fields part of the required checked-in baseline yet

### 4. Regression warning

Target:

* surface suspicious benchmark changes early
* avoid turning benchmarking into a flaky hard gate

Practical direction:

* start with manual comparison against a prior summary
* keep thresholds lightweight and advisory
* only consider CI gating after the signal is stable

### 5. Runner isolation

Target:

* preserve today's easy-to-find `.tmp/bench/...` summaries
* allow future run-id based isolation when parallel benchmarking matters

Practical direction:

* keep current fixed roots for now
* later consider run-specific subdirectories or `BENCH_RUN_ID`
* do not break the current inspection workflow just to make the harness more
  abstract

## Format-specific H3 Needs

* TXT / Markdown: large passthrough runs and batch startup amortization
* CSV / TSV: large-table throughput and memory behavior
* JSON / YAML / XML: large nested structured-data cases
* HTML: DOM-heavy, table-heavy, and image-heavy cases
* XLSX: large workbook, sparse sheet, and multi-sheet cases
* ZIP: many-entry, asset-heavy, and materialization-sensitive cases
* EPUB: many-chapter and image-heavy ebook cases
* DOCX: large docs, tables, images, and list-heavy cases
* PPTX: many slides, dense layout, image-heavy, and table-like cases
* PDF: multipage text, noisy text, cross-page merge, image-heavy, and
  table-like cases

## Proposed Implementation Phases

### H3.1: benchmark harness audit and docs

This phase is the current step:

* benchmark harness behavior is audited
* current scope and limits are documented
* H3 implementation phases are defined before changing the harness too much

### H3.2: batch benchmark mode design

Next design step:

* define whether batch mode belongs in the CLI, the harness, or both
* decide output shape before implementation
* avoid changing existing smoke/comparison semantics by accident
* prefer benchmark-only process-per-file batch evidence before product CLI
  batch surface expansion

Design output for this phase:

* [docs/benchmark-batch-design.md](./benchmark-batch-design.md)

### H3.3: batch profiling

Current profiling step:

* add an additive batch profiling harness
* compare `process-per-file` and `single-process-batch` on the same groups
* capture optional memory observations when platform support exists
* keep profiling results out of checked-in baseline contracts

Current output for this phase:

* [docs/benchmark-batch-profiling.md](./benchmark-batch-profiling.md)

### H3.4: batch profiling scale extension

Current scale-extension step:

* extend group sizes from `1 / 3` to `1 / 3 / 8 / 16`
* profile metadata-off and metadata-on for both runner models
* allow repeated representative samples for larger synthetic groups without
  changing checked-in corpora
* keep the result schema local to H3 profiling artifacts rather than turning it
  into a stable benchmark API

Current output for this phase:

* [docs/benchmark-batch-profiling.md](./benchmark-batch-profiling.md)

### H3.5: regression warning prototype

Current warning step:

* add a manual benchmark warning script that reads local TSV outputs
* keep thresholds conservative and checked in as human-reviewed policy
* default to warning-only output rather than nonzero exits
* reserve `--strict` for intentional local gating, not default developer flow
* do not parse Markdown baseline documents as machine input

Current output for this phase:

* `samples/bench_warn.sh`
* `samples/benchmark/perf_thresholds.tsv`

### H3.6: corpus scale normalization

Next corpus step:

* fill the most important small/medium/large gaps
* keep capability-focused samples and scale-focused samples distinct
* avoid conflating "has a sample" with "has meaningful scale coverage"

### H3.7: regression warning expansion

Next quality-discipline step:

* expand warning coverage only after the benchmark signal stabilizes further
* keep warning thresholds conservative and low-noise
* continue avoiding flaky hard CI gates

## Non-goals For This H3 Planning Step

This planning step does not try to:

* redefine the checked-in benchmark baseline
* replace the current summary formats
* add a heavy external profiler
* claim memory parity or semantic parity across tools
* force benchmark execution into a strict CI gate
