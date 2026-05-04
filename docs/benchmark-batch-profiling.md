# Batch Benchmark Profiling

This document captures the H3.3 and H3.4 profiling passes for the current CLI
batch mode v1.

It is a local profiling report, not a checked-in performance baseline. The goal
is to understand:

* startup and per-process overhead
* batch throughput differences between runner models
* metadata sidecar write cost
* memory shape across representative formats and larger file groups

The current report keeps converter semantics, sample expectations, benchmark
corpora, and baseline documents unchanged.

## 1. Definitions

The profiling harness distinguishes two runner models:

* `process-per-file`: loop over files and run `normal` once per file
* `single-process-batch`: one `batch` command handles the whole directory

The measurements should be interpreted differently:

* `process-per-file` is the closest match to repeated single-file CLI usage
* `single-process-batch` reflects current Batch v1 product behavior
* the difference between them is mostly process startup and outer command
  orchestration overhead, not converter-semantic difference

Single-file timings still include:

```text
startup + dispatch + parse + convert + emit + write
```

Batch v1 timings include:

```text
one process startup + directory enumeration + repeated parse/convert/emit/write
```

## 2. Harness

Harness:

```bash
./samples/scripts/bench_batch_profile.sh
```

Key properties:

* additive script under `.tmp/bench/batch_profile`
* does not change `samples/scripts/bench_smoke.sh` behavior
* does not change `samples/scripts/bench_compare_markitdown.sh` behavior
* reuses checked-in smoke-corpus inputs without editing corpus files
* compares `normal` loop versus `batch` command on the same file groups
* supports metadata-off and metadata-on profiling
* supports optional memory probe detection
* allows representative-sample repetition for larger synthetic groups

Current memory-probe policy:

* Linux: prefer `/usr/bin/time -v`
* macOS/BSD: prefer `/usr/bin/time -l`
* if unavailable, memory fields stay optional unless explicitly required

Current output artifacts:

* `.tmp/bench/batch_profile/results.jsonl`
* `.tmp/bench/batch_profile/summary.tsv`
* `.tmp/bench/batch_profile/comparison-summary.tsv`
* `.tmp/bench/batch_profile/startup-summary.tsv`
* `.tmp/bench/batch_profile/file_results.tsv`

These outputs are H3 profiling artifacts, not a stable public API.

## 3. Harness Audit

Current harness support status:

| Feature | Current status | Gap |
| --- | --- | --- |
| Format coverage | Default focus is `csv,json,html,xlsx,docx,pdf` | Broader format expansion remains future work |
| Group sizes | Default is `1,3,8,16` | No checked-in dedicated large-group corpus yet |
| `--with-metadata` profiling | Supported through metadata modes `0/1/both` | No separate baseline contract for metadata mode |
| Select format list | Supported via `--formats` and `BATCH_PROFILE_FORMATS` | None for H3.4 |
| Select group-size list | Supported via `--group-sizes`, `BATCH_PROFILE_GROUP_SIZES`, and legacy `BATCH_PROFILE_COUNTS` | None for H3.4 |
| Warmup / iterations | Supported via `--warmup`, `--iterations`, `BATCH_PROFILE_WARMUP`, `BATCH_PROFILE_ITERATIONS` | Still light-weight by default |
| Memory probe switch | Supported via `BATCH_PROFILE_MEMORY=auto|off|required` | macOS/BSD probe may need unsandboxed execution |
| Raw output schema | `results.jsonl` keeps per-run records including model, metadata mode, bytes, elapsed, throughput, RSS, and startup fields | Still intentionally unstable |
| Process model recording | Raw and aggregate outputs distinguish `process-per-file` and `single-process-batch` | None for H3.4 |
| Group-level metrics | `file_count`, `total_input_bytes`, `total_output_bytes`, `elapsed_ms`, `avg_ms_per_file`, `speedup`, `peak_rss_kb`, `failure_count` are now available via `comparison-summary.tsv` | None for H3.4 |

## 4. Scope Of This Profiling Pass

Environment:

* runner kind: prebuilt native CLI
* memory probe: `/usr/bin/time -l`
* iterations: `3`
* warmup: `0`
* metadata modes:
  * `without-metadata`
  * `with-metadata`

Formats sampled in this pass:

* CSV
* JSON
* HTML
* XLSX
* DOCX
* PDF

Group sizes sampled:

* `1`
* `3`
* `8`
* `16`

Startup probes:

* `help`
* `empty-batch`

Observed startup medians:

| Probe | Median elapsed ms | Median peak RSS bytes |
| --- | ---: | ---: |
| `help` | 18 | 4,423,680 |
| `empty-batch` | 14 | 4,603,904 |

This means the current native CLI still has a meaningful fixed process floor
before any real conversion work begins.

## 5. Scale Extension

The H3.4 scale extension expands the earlier `1 / 3` pass to `1 / 3 / 8 / 16`
and adds metadata-on profiling for both runner models.

Important interpretation notes:

* larger synthetic groups may repeat representative samples when the checked-in
  smoke corpus does not contain enough rows for a given format
* repeated samples are used to profile batch overhead and throughput shape, not
  corpus diversity
* reported speedups are local profiling observations, not blanket performance
  claims

### Group-size trend without metadata

Representative no-metadata results from
`.tmp/bench/batch_profile/comparison-summary.tsv`:

| Format | Files | Process-per-file ms | Single-process batch ms | Speedup | Process peak RSS KB | Batch peak RSS KB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CSV | 1 | 34 | 15 | 2.27x | 4,736 | 4,768 |
| CSV | 3 | 91 | 16 | 5.69x | 5,008 | 5,040 |
| CSV | 8 | 425 | 164 | 2.59x | 8,544 | 9,296 |
| CSV | 16 | 726 | 312 | 2.33x | 8,608 | 9,568 |
| JSON | 1 | 35 | 15 | 2.33x | 4,784 | 4,800 |
| JSON | 3 | 90 | 16 | 5.62x | 5,216 | 5,264 |
| JSON | 8 | 444 | 245 | 1.81x | 9,584 | 9,744 |
| JSON | 16 | 1,085 | 665 | 1.63x | 9,696 | 10,432 |
| HTML | 1 | 35 | 15 | 2.33x | 4,848 | 4,880 |
| HTML | 3 | 89 | 16 | 5.56x | 4,880 | 4,992 |
| HTML | 8 | 239 | 19 | 12.58x | 4,992 | 5,040 |
| HTML | 16 | 439 | 24 | 18.29x | 4,992 | 5,120 |
| XLSX | 1 | 45 | 25 | 1.80x | 6,192 | 6,144 |
| XLSX | 3 | 109 | 34 | 3.21x | 6,192 | 6,112 |
| XLSX | 8 | 460 | 243 | 1.89x | 8,944 | 9,024 |
| XLSX | 16 | 1,074 | 658 | 1.63x | 9,056 | 9,968 |
| DOCX | 1 | 50 | 29 | 1.72x | 6,944 | 6,928 |
| DOCX | 3 | 134 | 56 | 2.39x | 6,928 | 7,392 |
| DOCX | 8 | 310 | 100 | 3.10x | 6,960 | 7,648 |
| DOCX | 16 | 610 | 184 | 3.32x | 6,992 | 7,840 |
| PDF | 1 | 38 | 17 | 2.24x | 5,984 | 6,016 |
| PDF | 3 | 96 | 21 | 4.57x | 5,984 | 6,096 |
| PDF | 8 | 248 | 34 | 7.29x | 6,144 | 6,384 |
| PDF | 16 | 481 | 54 | 8.91x | 6,176 | 6,576 |

### Group-size `16` snapshot

The most important H3.4 extension point is the `16`-file group:

| Format | Metadata mode | Process-per-file ms | Single-process batch ms | Speedup | Process peak RSS KB | Batch peak RSS KB | RSS delta KB |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CSV | without-metadata | 726 | 312 | 2.33x | 8,608 | 9,568 | 960 |
| CSV | with-metadata | 754 | 324 | 2.33x | 8,640 | 9,600 | 960 |
| JSON | without-metadata | 1,085 | 665 | 1.63x | 9,696 | 10,432 | 736 |
| JSON | with-metadata | 1,089 | 658 | 1.66x | 9,744 | 10,240 | 496 |
| HTML | without-metadata | 439 | 24 | 18.29x | 4,992 | 5,120 | 128 |
| HTML | with-metadata | 449 | 25 | 17.96x | 5,008 | 5,104 | 96 |
| XLSX | without-metadata | 1,074 | 658 | 1.63x | 9,056 | 9,968 | 912 |
| XLSX | with-metadata | 1,095 | 655 | 1.67x | 9,008 | 9,920 | 912 |
| DOCX | without-metadata | 610 | 184 | 3.32x | 6,992 | 7,840 | 848 |
| DOCX | with-metadata | 632 | 186 | 3.40x | 6,960 | 7,792 | 832 |
| PDF | without-metadata | 481 | 54 | 8.91x | 6,176 | 6,576 | 400 |
| PDF | with-metadata | 492 | 56 | 8.79x | 6,192 | 6,576 | 384 |

### Metadata on/off comparison at group size `16`

Metadata-on impact is small relative to total batch group time in this pass:

| Format | Batch delta ms | Batch delta % | Process delta ms | Process delta % |
| --- | ---: | ---: | ---: | ---: |
| CSV | +12 | +3.8% | +28 | +3.9% |
| JSON | -7 | -1.1% | +4 | +0.4% |
| HTML | +1 | +4.2% | +10 | +2.3% |
| XLSX | -3 | -0.5% | +21 | +2.0% |
| DOCX | +2 | +1.1% | +22 | +3.6% |
| PDF | +2 | +3.7% | +11 | +2.3% |

The negative deltas are run-to-run noise, not evidence that metadata writing is
intrinsically faster. The main signal is that metadata sidecar writing is small
compared with total end-to-end work for these groups.

## 6. Main Findings

### Startup overhead is still the fixed floor

The startup probes still cluster around `14-18 ms`, and one-file groups remain
the clearest indicator of fixed process cost.

Interpretation:

* tiny-file workflows are still startup-sensitive
* H3 speed claims should keep distinguishing single-file and batch measurements
* the `estimated_process_overhead_*` fields should continue to be treated as
  approximation fields, not pure startup-only fields

### Batch advantage remains real at larger scales, but not all formats grow the same way

The H3.4 question was whether batch throughput advantage still exists at
`8 / 16` groups. It does, but with format-specific shape:

* HTML keeps amplifying dramatically, reaching `18.29x` at `16`
* PDF also scales strongly, reaching `8.91x` at `16`
* DOCX improves from `1.72x` at `1` to `3.32x` at `16`
* CSV / JSON / XLSX still stay faster in batch at `16`, but the speedup is more
  moderate once heavier repeated samples dominate total work

Important caveat:

* speedup is not guaranteed to rise monotonically with group size
* larger groups may include heavier representative rows and repeated rows, so
  they measure the combined effect of startup amortization and actual sample mix

### Metadata sidecar cost is present but modest

The H3.4 metadata pass was meant to answer whether `--with-metadata`
substantially changes throughput or memory shape.

Current signal:

* batch wall-clock deltas at group size `16` stay within about `-1.1%` to
  `+4.2%`
* process-per-file deltas at group size `16` stay within about `+0.4%` to
  `+3.9%`
* there is no format here where metadata-on fundamentally changes the batch
  speed story

Interpretation:

* metadata sidecar writing is not a dominant cost in the current Batch v1 shape
* metadata-on is still worth keeping as a separate profiling mode, but it does
  not currently look like the first optimization target

### Memory stays bounded in this pass

Observed batch peak RSS ranges across all sampled group sizes and metadata modes:

* CSV: about `4.8 MB` to `9.6 MB`
* JSON: about `4.8 MB` to `10.4 MB`
* HTML: about `4.9 MB` to `5.1 MB`
* XLSX: about `6.1 MB` to `10.0 MB`
* DOCX: about `6.9 MB` to `7.8 MB`
* PDF: about `6.0 MB` to `6.6 MB`

Observed batch-memory behavior:

* batch peak RSS is usually slightly above process-per-file at the same group
* the deltas remain modest relative to total group size in this pass
* no format showed a runaway-memory signature or failure pattern at `16`

Interpretation:

* current Batch v1 does not show abnormal memory growth on these representative
  groups
* larger and more diverse corpora are still needed before making strong
  long-run memory-scaling claims

## 7. Per-format Notes

### CSV / JSON

These remain useful startup and throughput sentinels, but their larger-group
results are influenced strongly by the repeated representative rows chosen for
the synthetic `8 / 16` groups.

Current signal:

* `3`-file groups still show clear startup amortization wins
* `16`-file groups remain batch-positive
* metadata-on cost remains small

### HTML

HTML remains the clearest “batch is much better” example in this pass.

Current signal:

* `5.56x` at `3`
* `12.58x` at `8`
* `18.29x` at `16`
* peak RSS barely moves above the `5 MB` range

### XLSX

XLSX benefits from batch, but its larger-group speedup is moderate because real
parse and materialization work already dominates more of the wall-clock time.

Current signal:

* `1.80x` at `1`
* `3.21x` at `3`
* `1.63x` at `16`
* peak RSS approaches `10 MB` in the largest sampled groups

### DOCX

DOCX shows a more convincing larger-group trend than the smaller H3.3 pass did.

Current signal:

* `1.72x` at `1`
* `2.39x` at `3`
* `3.10x` at `8`
* `3.32x` at `16`

This still suggests that startup matters, but converter hot paths remain an
important future optimization area for DOCX.

### PDF

PDF continues to respond well to batch even at the larger groups.

Current signal:

* `2.24x` at `1`
* `4.57x` at `3`
* `7.29x` at `8`
* `8.91x` at `16`

This makes PDF a strong candidate for future larger-document and mixed-size
batch profiling.

## 8. Output Schema Notes

Current aggregate outputs:

* `summary.tsv`
  * `model`
  * `format`
  * `file_count`
  * `metadata_enabled`
  * `metadata_mode`
  * `runs`
  * `failed`
  * `median_elapsed_ms`
  * `avg_elapsed_ms`
  * `median_files_per_sec`
  * `median_input_bytes_per_sec`
  * `median_peak_rss_bytes`
  * `median_fixed_overhead_ms`
  * `median_estimated_process_overhead_per_file_ms`
* `comparison-summary.tsv`
  * `format`
  * `group_size`
  * `metadata_enabled`
  * `metadata_mode`
  * `process_per_file_ms`
  * `single_process_batch_ms`
  * `speedup`
  * `total_input_bytes`
  * `total_output_bytes`
  * `avg_ms_per_file_process`
  * `avg_ms_per_file_batch`
  * `peak_rss_kb_process`
  * `peak_rss_kb_batch`
  * `rss_delta_kb`
  * `failure_count`

Current raw `results.jsonl` records keep:

* `model`
* `format`
* `file_count`
* `iteration`
* `runner_kind`
* `runner_command`
* `input_bytes`
* `output_bytes`
* `success_count`
* `failure_count`
* `elapsed_ms`
* `median_file_ms`
* `throughput_files_per_sec`
* `throughput_input_bytes_per_sec`
* `peak_rss_bytes`
* `peak_footprint_bytes`
* `fixed_overhead_ms`
* `estimated_process_overhead_total_ms`
* `estimated_process_overhead_per_file_ms`
* `startup_probe_ms`
* `startup_probe_kind`
* `with_metadata`
* `metadata_mode`
* `timestamp`
* `git_rev`
* `memory_probe`

These fields are intentionally profiling-oriented and may still evolve.

## 9. Current Limits

This pass is still intentionally bounded.

Known limits:

* still only `3` measured iterations per group
* no warmup in the published numbers
* repeated representative samples are used for larger groups
* no checked-in dedicated batch corpus yet
* no recursive/manifest/parallel product modes
* macOS `time -l` still reports group peak memory for batch, not isolated
  per-file peaks inside one process

Also note:

* `single-process-batch` per-file elapsed numbers come from `batch-summary.tsv`
* those internal per-file numbers are useful for distribution shape, but the
  more important H3 user-facing number is group wall-clock time

## 10. Recommendations

Recommended next steps:

1. Keep `samples/scripts/bench_batch_profile.sh` as a separate profiling tool instead of
   overloading existing smoke/comparison baselines.
2. Preserve `comparison-summary.tsv` as the easiest place to compare runner
   models across group size and metadata mode.
3. Add larger representative documents for PDF / DOCX / XLSX before making
   stronger office-document throughput claims.
4. If future optimization is needed, prioritize:
   * startup reduction for tiny-file workflows
   * batch throughput for HTML / PDF and other startup-sensitive workloads
   * converter hot paths for JSON / XLSX / DOCX workloads where larger groups
     still leave meaningful per-file work
5. Treat the current memory observations as “no obvious anomaly found” rather
   than final proof of long-run memory scaling.

## 11. Warning Checks

The repository now has a manual warning helper:

```bash
./samples/scripts/bench_warn.sh --suite batch_profile
./samples/scripts/bench_warn.sh --strict --suite batch_profile
```

How it works:

* it reads local profiling output from `.tmp/bench/batch_profile/comparison-summary.tsv`
* it compares a small set of conservative checked-in thresholds from
  `samples/benchmark/perf_thresholds.tsv`
* default mode only reports `ok` / `warn`
* `--strict` converts warnings into exit code `1` for intentional local gating
* malformed policy or missing input still exits `2`

Important framing:

* this is a manual engineering radar, not a CI hard gate
* the threshold file is a conservative warning policy, not a formal SLA
* `batch_profile` is the primary supported suite in v1 because its summary TSV
  is the most stable of the current local profiling outputs

## 12. Non-goals In This Round

This round does not:

* change converter semantics
* change sample expected outputs
* change benchmark corpus files
* change checked-in benchmark baselines
* introduce heavy external profiling dependencies
* claim final memory scaling results for large corpora
