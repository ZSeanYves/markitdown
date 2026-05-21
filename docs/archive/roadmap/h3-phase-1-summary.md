# H3 Phase-1 Performance Summary

Status: historical phase summary.

For the current benchmark command menu and current measured snapshot, use:

* [docs/benchmarking.md](../../benchmarking.md)
* [docs/archive/performance/performance-baseline.md](../performance/performance-baseline.md)

This document is the long-term summary of the first H3 performance phase.

It follows:

* H2 full-format completion
* the `v0.3.0` release-line baseline freeze
* runner normalization across validation, smoke, compare, and batch profiling

It is based on local-machine benchmark outputs under `.tmp/bench/...`. It does
not claim universal performance dominance, and it does not change converter
semantics, metadata schema, benchmark corpora, benchmark thresholds, or
checked-in sample expectations.

## 1. Scope

H3 phase 1 focused on obvious native benchmark hotspots that were large enough
to justify narrow, low-risk optimization passes.

The main wins came from:

* XLSX worksheet XML materialization
* JSON input materialization
* TXT input materialization
* CSV / TSV input materialization
* YAML input materialization
* ZIP many-entry profiling plus a small orchestration reduction

This phase was intentionally not a blanket “optimize everything” pass. It
stopped once the native smoke board no longer showed stable first-tier outliers.

## 2. Runner Normalization

The first H3 cleanup step was benchmark runner normalization:

* validation now uses a native-preferred runner policy
* smoke now uses a native-preferred runner policy
* overlap comparison uses a prebuilt native CLI for `markitdown-mb`
* batch profiling uses a prebuilt native CLI
* smoke warnings are runner-aware

Important interpretation change:

* the earlier `docx/golden 10075 ms` smoke warning was a `moon run` wrapper
  artifact, not a native hot-path result
* phase-1 conclusions should therefore be read from native-preferred results,
  not from older wrapper-inflated measurements

## 3. Before / After Summary

The table below keeps the earlier local H3 anchors and compares them against
the post-phase-1 local range that remained after the consolidation refresh and
targeted follow-up reruns.

| Target | Before | After | Result |
| ------ | -----: | ----: | ------ |
| `XLSX large` | ~212 ms | ~24-34 ms | worksheet XML UTF-8 materialization fixed |
| `JSON large` | ~196 ms | ~30-38 ms | input materialization fixed |
| `TXT large` | ~130 ms | ~32-39 ms | input materialization fixed |
| `CSV large` | ~109 ms | ~27-31 ms | input materialization fixed |
| `TSV large` | ~99 ms | ~27-30 ms | input materialization fixed |
| `YAML large` | ~145 ms | ~27-32 ms | input materialization fixed; residual parser modest |
| `ZIP many entries` | ~40-62 ms | ~30-35 ms | bounded orchestration workload after profiling/stabilization |

Notes:

* `zip_large_many_entries` used both full-smoke and ZIP-only reruns; the stable
  local ZIP-only median settled around `34.5 ms`
* `yaml_large` used both full-smoke and YAML-only reruns; the stable local
  YAML-only median settled around `32 ms`

## 4. UTF-8 Materialization Audit Summary

The biggest repeated phase-1 pattern was a shared slow UTF-8 materialization
helper that built strings one character at a time.

What phase 1 fixed locally:

* `JSON`
* `TXT`
* `CSV / TSV`
* `YAML`
* `XLSX` XML-part read/materialization

What the audit classified as caution areas rather than blanket-replace targets:

* `HTML` byte-slice decode paths
* `ZIP / EPUB` text/binary boundaries
* `DOCX / PPTX` OOXML package-internal text-part reads
* `PDF` / vendored backend paths

The main H3 phase-1 lesson was not “every format is slow”; it was that a small
number of whole-file UTF-8 materialization paths were disproportionately
expensive and safely fixable.

## 5. ZIP Many-entry Summary

The ZIP follow-up established a different class of residual cost:

* `zip_large_many_entries` is not primarily a low-level archive parser problem
* archive open/list/filter/sort are cheap on the current local corpus
* the main cost is many small entry orchestration: staging, dispatch, and
  section aggregation across `101` converted entries
* after a small orchestration reduction plus ZIP-only stabilization reruns, the
  row looks bounded and good enough for this phase

The current conclusion is therefore:

* ZIP many-entry is not a P0 converter emergency
* future ZIP/EPUB work should be treated as broader container governance or
  residual orchestration cleanup, not as urgent low-level IO rescue

## 6. Final Benchmark Status

The phase-1 consolidation refresh used:

```bash
moon check
bash samples/check.sh
bash samples/bench.sh --suite smoke
bash samples/bench.sh --suite compare
bash samples/bench.sh --suite batch-profile
bash samples/scripts/bench_warn.sh --all
```

Current local status after the serial normalized rerun:

* smoke: `75` samples, `0` failures, `0` warnings
* compare: `18` paired cases, minimum selected overlap speedup `16.48x`
* batch: `96` runs, `0` failures, `0` warnings

Current local interpretation:

* there is no stable `100 ms+` native smoke outlier left
* there is no stable native smoke row above `50 ms`
* `bench_warn --all` is clean
* selected overlap comparison remains favorable, but it is still only a
  selected overlap benchmark
* batch weak rows remain concentrated in `group=1`, which makes them better
  read as process-model effects than as converter hot-path regressions

## 7. Next Phase

H3 phase 2 should focus on benchmark governance and broader corpus discipline
rather than on chasing local `20-40 ms` rows one by one.

Current recommended direction:

* broader representative corpus growth
* optional memory / RSS observation where available
* clearer daily vs pre-release vs investigation benchmark suite boundaries
* warning-policy governance
* public/private corpus strategy for larger real-world documents

Current priority framing:

* `P0`: no urgent converter hot-path target
* `P1`: benchmark governance, corpus strategy, and selective residual audits
* `P2`: later quality/performance cleanup only when refreshed evidence clearly
  re-elevates one
