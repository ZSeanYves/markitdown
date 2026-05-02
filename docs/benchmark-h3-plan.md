# Benchmark H3 Plan

This document captures the current benchmark-harness contract and the planned
H3 phase-2 direction after the first performance wave was closed out.

Current stable benchmark anchors remain in:

* [docs/benchmark-baseline.md](./benchmark-baseline.md)
* [docs/benchmark-comparison-baseline.md](./benchmark-comparison-baseline.md)
* [docs/h3-phase-1-summary.md](./h3-phase-1-summary.md)

## Current Benchmark Contract

The repository currently uses three benchmark layers:

* smoke benchmark:
  * `samples/scripts/bench_smoke.sh`
  * internal same-machine cross-format tracking
  * native-preferred runner policy with `moon run` fallback
* overlap comparison benchmark:
  * `samples/scripts/bench_compare_markitdown.sh`
  * selected overlap-only comparison against Python `markitdown`
  * no blanket parity claim
* batch profiling benchmark:
  * `samples/scripts/bench_batch_profile.sh`
  * `process-per-file` vs `single-process-batch`
  * optional memory observation when platform support exists

Shared assumptions:

* `.tmp/bench/...` outputs are local artifacts and do not belong in version
  control
* native-preferred runs are the stronger performance reference
* `moon run` timings remain useful for functionality, but include wrapper
  overhead
* selected overlap wins are not universal speed claims

## Phase-1 Status

H3 phase 1 is now complete as a local performance wave:

* runner normalization is done
* major UTF-8 materialization hotspots have been cut down
* ZIP many-entry residual work has been profiled and locally stabilized
* the current serial normalized rerun shows no stable native smoke row above
  `50 ms`
* `bench_warn --all` is currently clean on the local consolidation refresh

See [docs/h3-phase-1-summary.md](./h3-phase-1-summary.md) for the final phase-1
before/after table and current local benchmark posture.

## Phase-2 Direction

H3 phase 2 should focus on benchmark governance rather than on chasing every
remaining `20-40 ms` local row.

The active phase-2 themes are:

* clearer suite tiers:
  * daily/local fast checks
  * pre-release benchmark suite
  * manual investigation/profile suite
* larger representative corpora
* optional memory / RSS observation where available
* warning-policy governance
* corpus expansion policy, including local/private investigation corpora

See [docs/h3-phase-2-benchmark-governance.md](./h3-phase-2-benchmark-governance.md)
for the working phase-2 governance outline.

Phase-2 corpus policy templates now live in:

* [samples/benchmark/README.md](../samples/benchmark/README.md)
* [samples/benchmark/corpus_manifest.example.tsv](../samples/benchmark/corpus_manifest.example.tsv)

## Active Benchmark Docs

The benchmark docs that should now be treated as active are:

* [docs/benchmark-baseline.md](./benchmark-baseline.md)
* [docs/benchmark-comparison.md](./benchmark-comparison.md)
* [docs/benchmark-comparison-baseline.md](./benchmark-comparison-baseline.md)
* [docs/benchmark-batch-design.md](./benchmark-batch-design.md)
* [docs/benchmark-batch-profiling.md](./benchmark-batch-profiling.md)
* [docs/h3-phase-1-summary.md](./h3-phase-1-summary.md)
* [docs/h3-phase-2-benchmark-governance.md](./h3-phase-2-benchmark-governance.md)

Historical per-pass profiling notes are no longer the primary benchmark entry
point. Their lasting conclusions should be read from the summary/planning docs
above.

## Current Non-goals

This planning document does not:

* redefine the checked-in baseline as a universal claim
* turn local benchmarks into a strict flaky CI gate
* imply that all remaining local `20-40 ms` rows are urgent converter
  regressions
* replace targeted profiling when a future refreshed board clearly re-elevates
  a specific format family
* keep the result schema local to H3 profiling artifacts rather than turning it
  into a stable benchmark API
* the later H3 phase-1 consolidation refresh now gives a cleaner local stop
  condition for this wave: a serial normalized rerun places the current smoke
  top board in roughly the `27-41 ms` range, keeps `bench_warn --all` clean,
  and leaves no stable native smoke row above `50 ms`
* this suggests the next H3 step should shift from “keep cutting obvious hot
  paths” toward larger-corpus discipline, optional memory observation, and
  selective residual audits when a refreshed board clearly re-elevates one

## Non-goals For This H3 Planning Step

This planning step does not try to:

* redefine the checked-in benchmark baseline
* replace the current summary formats
* add a heavy external profiler
* claim memory parity or semantic parity across tools
* force benchmark execution into a strict CI gate
