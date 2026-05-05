# H3 Baseline Freeze For v0.3.0

This document records the starting H3 benchmark baseline after the `v0.3.0`
full-format H2 milestone.

It is a local-machine benchmark snapshot, not a universal performance claim.

Follow-up triage for normalized native-preferred benchmark data now lives in
[docs/h3-performance-triage.md](./h3-performance-triage.md).

The first XLSX-targeted profiling follow-up now lives in
[docs/h3-xlsx-large-profile.md](./h3-xlsx-large-profile.md).

## 1. Scope

This baseline freeze is the H3 starting reference for the `v0.3.0`
full-format H2 release line.

Important commit/tag note:

* published release tag: `v0.3.0`
* release tag commit: `7d5dc74`
* baseline freeze commit: `e79756d`
* `git describe --tags`: `v0.3.0-1-ge79756d`

So this document is anchored to the `v0.3.0` release milestone, but the local
freeze was recorded from the clean first post-tag H3 baseline commit rather
than the exact tag object itself.

This baseline does not:

* change converter semantics
* change benchmark algorithms
* change the checked-in benchmark corpus

## 2. Environment

Environment for this run:

* OS: macOS `15.3`
* arch: `arm64`
* MoonBit version: `moon 0.1.20260427 (48d7def 2026-04-27)`
* native CLI path:
  `/Users/winter/Documents/Moonbit/markitdown/_build/native/debug/build/cli/cli.exe`
* Python MarkItDown availability: available in `PATH` as
  `/Users/winter/miniconda3/bin/markitdown`
* Python MarkItDown version: `markitdown 0.1.5`
* timestamp: `2026-05-05 02:13:53 CST`

Runner caveat:

* sample validation preferred the probe-validated native CLI
* overlap comparison used the prebuilt native CLI
* batch profiling used the prebuilt native CLI
* the original baseline smoke run used `moon run`, so it includes
  wrapper/startup overhead and should be treated as an internal same-machine
  smoke baseline, not the strongest native-CLI speed claim
* after this freeze, `bench_smoke.sh` was normalized to the same
  native-preferred runner policy as validation and comparison harnesses; any
  later local reruns should be read as post-freeze normalization data, not as a
  retroactive replacement for the original baseline snapshot

## 3. Validation Status

Validation commands requested for the freeze:

* `moon check`: passed
* `moon test`: failed in `vendor/mbtpdf` e2e due missing generated fixtures
  under `vendor/mbtpdf/.tmp/scratch/mbtpdf/e2e/*.pdf`
* `./samples/check.sh`: passed

Observed `moon test` failure shape:

* 1,273 total tests
* 1,245 passed
* 28 failed
* all observed failures were missing-fixture failures in vendored `mbtpdf`
  e2e coverage, not converter benchmark regressions from this freeze step

Post-baseline follow-up:

* `vendor/mbtpdf/e2e` has now been reclassified as optional/manual vendor e2e
  coverage for root-suite purposes
* those tests also had a test-helper bug: generated outputs under
  `.tmp/scratch/mbtpdf/e2e` were being read back through the fixture-path
  helper, which incorrectly rewrote them under `vendor/mbtpdf/...`

Interpretation:

* repository validation was not fully green because `moon test` was not green
  on this machine/worktree state
* benchmark baseline recording still proceeded because the benchmark harnesses
  themselves were runnable and the missing-fixture failures were outside the
  benchmark/documentation work in this round

## 4. Smoke Benchmark Summary

Command run:

```bash
./samples/scripts/bench_smoke.sh
```

Summary:

* samples run: `75`
* failures: `0`
* runner for the original freeze run: `moon run` fallback path inside the
  harness
* formats covered: `docx`, `pptx`, `xlsx`, `zip`, `epub`, `pdf`, `html`,
  `csv`, `tsv`, `txt`, `xml`, `json`, `yaml`, `markdown`

Fastest / slowest groups in this run:

* fastest sample: `xlsx/xlsx_sparse_large` at `837 ms`
* slowest regular large-data cluster:
  * `json/json_large`: `1142 ms`
  * `yaml/yaml_large`: `1106 ms`
  * `txt/txt_large`: `1103 ms`
  * `xlsx/xlsx_large`: `1067 ms`
  * `tsv/tsv_large`: `1023 ms`
  * `csv/csv_large`: `1021 ms`
* slowest overall sample and clear outlier: `docx/golden` at `10075 ms`

Notable outliers / interpretation:

* `docx/golden` is far above the rest of the smoke corpus and was the only
  sample that triggered the manual warning policy in this run
* most non-outlier smoke rows clustered in the roughly `840-1140 ms` band,
  which is consistent with the current harness using `moon run`
* format-average medians were lowest for `pptx` (`852.43 ms`) and highest for
  `docx` (`2170.86 ms`) because the `golden` doc dominated the DOCX average

## 5. MarkItDown Overlap Comparison

Command run:

```bash
./samples/scripts/bench_compare_markitdown.sh
```

Availability:

* repository runner: available
* Python MarkItDown runner: available
* failures: `0`

Overlap corpus actually covered these format families:

* `docx`
* `pptx`
* `xlsx`
* `pdf`
* `html`
* `csv`
* `txt`
* `markdown`

Formats not covered by the overlap corpus in this freeze:

* `tsv`
* `json`
* `yaml`
* `xml`
* `zip`
* `epub`

Speedup summary against Python MarkItDown `0.1.5`:

* compared overlap cases: `18`
* `markitdown-mb` was faster on all `18/18` overlap cases
* average speedup: `36.26x`
* min speedup: `1.11x` on `docx/docx_heading_levels_compare`
* max speedup: `47.90x` on `csv/csv_basic_compare`
* `17/18` overlap cases were at least `10x` faster
* `15/18` overlap cases were at least `30x` faster

Selected examples:

* `pdf/text_simple_compare`: `13 ms` vs `473 ms`
* `pdf/pdf_cross_page_should_merge_compare`: `11 ms` vs `468 ms`
* `pptx/pptx_title_bullets_compare`: `14 ms` vs `478 ms`
* `xlsx/xlsx_multi_sheet_mixed_compare`: `21 ms` vs `475 ms`

Cases skipped:

* none in this run
* if Python MarkItDown had been missing, this section would have been recorded
  as unavailable rather than treated as a hard failure

Output comparison caveat:

* this harness is semantic-overlap-only
* it is not an identical-output guarantee
* it does not claim metadata parity, asset parity, OCR parity, or full
  converter parity outside the selected overlap cases

## 6. Batch Profile Summary

Command run:

```bash
./samples/scripts/bench_batch_profile.sh
```

Run configuration:

* runner kind: `prebuilt-native`
* formats: `csv`, `json`, `html`, `xlsx`, `docx`, `pdf`
* group sizes: `1`, `3`, `8`, `16`
* metadata modes: `without-metadata`, `with-metadata`
* models:
  * `process-per-file`
  * `single-process-batch`
* runs: `96`
* failures: `0`
* skipped groups: `0`

Main result:

* `single-process-batch` beat `process-per-file` for every measured row in
  this run

Speedup range:

* without metadata: `1.53x` to `17.12x`
* with metadata: `1.10x` to `17.04x`

Representative `16`-file groups:

* `csv`:
  * without metadata: `706 ms` vs `339 ms` (`2.08x`)
  * with metadata: `742 ms` vs `361 ms` (`2.06x`)
* `json`:
  * without metadata: `1094 ms` vs `715 ms` (`1.53x`)
  * with metadata: `1097 ms` vs `720 ms` (`1.52x`)
* `html`:
  * without metadata: `411 ms` vs `24 ms` (`17.12x`)
  * with metadata: `409 ms` vs `24 ms` (`17.04x`)
* `xlsx`:
  * without metadata: `1121 ms` vs `718 ms` (`1.56x`)
  * with metadata: `1115 ms` vs `782 ms` (`1.43x`)
* `docx`:
  * without metadata: `623 ms` vs `228 ms` (`2.73x`)
  * with metadata: `621 ms` vs `231 ms` (`2.69x`)
* `pdf`:
  * without metadata: `443 ms` vs `57 ms` (`7.77x`)
  * with metadata: `446 ms` vs `57 ms` (`7.82x`)

Startup overhead estimate:

* startup probes:
  * `help`: median `13 ms`
  * `empty-batch`: median `13 ms`
* for `1`-file groups, the median extra cost of `process-per-file` over
  `single-process-batch` was about `20 ms`
* for `1`-file groups, the delta ranged from `3 ms` (`html:true`) to `43 ms`
  (`docx:false`)

Metadata on/off note:

* metadata on/off differences were small relative to total end-to-end group
  time in this run
* the main H3 signal is still process amortization and batch normalization,
  not metadata cost

Memory / RSS summary:

* memory probe mode resolved to `none` on this machine/run
* `peak_rss_kb_*` fields in the summary were therefore `0`/unavailable rather
  than meaningful measured RSS values
* no memory leadership claim should be made from this freeze alone

## 7. Regression Warning Status

Command run:

```bash
./samples/scripts/bench_warn.sh --all
```

Result:

* batch profile warnings: none
* compare warnings: not implemented yet and explicitly skipped by the script
* smoke warnings: `1`

Triggered warning:

* `golden median_ms=10075 not <= 2000`

Interpretation:

* the warning thresholds are conservative manual warnings, not a CI SLA
* this warning does not block baseline recording, but it does confirm that the
  current `docx/golden` smoke row should remain a first-class H3 watchpoint
* follow-up triage shows the same `golden.docx` converts in roughly
  `0.02-0.03s` with the prebuilt native CLI and about `0.81-0.88s` through
  `moon run`, so the current smoke warning is not evidence by itself that the
  DOCX converter has a 10-second native hot path
* after runner normalization, smoke warnings also report `runner=...` so
  `moon-run` warnings are easier to classify as wrapper-sensitive observations
  rather than native-only hot-path conclusions

Post-normalization local rerun note:

* after `bench_smoke.sh` was switched to the native-preferred runner policy, a
  local rerun on the same machine reported `docx/golden median_ms=32` with
  `runner_kind=prebuilt-native`
* that rerun cleared the manual smoke warning without any converter or
  threshold change
* this supports the conclusion that the original `10075 ms` warning was a
  runner/harness artifact rather than evidence of a 10-second native DOCX hot
  path

## 8. H3 Priorities

From this baseline, the next H3 priorities are:

* optimize the slowest format groups, especially the `docx/golden` smoke
  outlier and the larger structured-data rows
* normalize larger/batch corpora so scale evidence is more representative and
  less dependent on repeated synthetic groups
* make memory profiling reliable enough to produce nonzero RSS summaries on
  supported local environments
* pursue parser-level optimization where large-format hot spots justify it
* measure emitter / metadata / asset overhead separately where the current
  end-to-end timings are still too coarse
* decide whether manual warning checks should remain local-only or become an
  optional CI/manual integration path

## 9. Known Limitations

Known limitations of this baseline:

* benchmarks are local-machine observations
* overlap comparison covers selected overlap cases only
* Python MarkItDown availability affects whether overlap comparison can run
* the original freeze's smoke benchmark includes `moon run` wrapper overhead
* no OCR path or LLM-assisted path is benchmarked here
* this document is a freeze summary, not a claim that all validation on this
  machine was fully green
