# Native regression

`run_native_regression.mbtx` validates an actual Native executable against the
independent `markitdown-quality-lab` checkout. The default checkout is the nested
`markitdown-quality-lab/` directory; use `--lab` for another location. The runner
reads it without changing fixtures, manifests, or goldens.

```text
moon check --deny-warn tools/regression/run_native_regression.mbtx
moon run tools/regression/run_native_regression.mbtx -- --self-test true
moon run tools/regression/run_native_regression.mbtx -- --validate-only true
moon run tools/regression/run_native_regression.mbtx -- --binary /absolute/path/to/markitdown.exe --suite all
```

The `.mbtx` orchestrator may run through `moonx`; it starts the supplied executable
as a separate Native process. The installed CLI and a source-built baseline must
be measured separately and identified by their recorded binary SHA-256. A source
baseline run is not an installation or publication acceptance result.
The supplied binary must have an ELF or Mach-O header; shell-script fake runners
are rejected. A header check does not replace installation provenance.

Options use explicit pairs: `--suite main|quality|accurate|all`, `--format FORMAT`,
`--case ID`, `--lab PATH`, `--evidence NEW_DIRECTORY`, and
`--validate-only true|false`. Every run creates a new evidence directory; an
existing directory is rejected. Omitting `--evidence` uses a timestamped directory
under `.tmp/native-regression/`.

The runner checks the entire requested manifest surface before applying case or
format filters. Missing manifests, input files or goldens, duplicate IDs, unknown
signals, unsafe paths, malformed rows, unapproved inputs, ambiguous expected
failure metadata, and zero selected tests fail the run. `reference` and `gate`
rows both execute. Retirement requires an explicit `retire` action and a reason.
The current manifest schema permits omitted optional empty tail cells and extra
empty tail cells; each normalization is recorded. Required columns and unknown
nonempty columns remain errors. A legacy quoted signal group followed by extra
semicolon signals is decoded explicitly and recorded.

Main cases use filename detection so diagnostics retain the golden's extension
probe contract; external quality/accurate cases use the declared explicit format.
Main Markdown cases compare exact text. RAG goldens are parsed as JSON with
duplicate keys rejected, then assert declared fields, diagnostics, metadata,
chunk counts and ordered chunk contracts, source counts, asset references, and
location metadata (path entries use substring containment, allowing checkout
prefixes). Unknown RAG contract fields fail. Asset goldens compare both
the file set and SHA-256 values. Other cases record actual asset hashes, enforce
declared asset assertions, and check reference reachability.

Signals read one channel at a time. Unprefixed signals use the manifest's
`validation_view` (Markdown by default). Explicit channel prefixes are
`markdown:`, `debug:`, `provenance:`, `stdout:`, and `stderr:`; for example,
`stderr:contains:InvalidInput`. Channels are never concatenated. Expected
rejections require `exit_code:N` and an explicit stderr content signal. The
proposed expected-failure/skip metadata fields do not silently disable a row.
Markdown signal operands and actual Markdown decode backslash-escaped punctuation
before matching, preserving the external lab's escaped and unescaped signal
conventions. Exact main goldens and other channels retain their original bytes.
Count signals split on their final `=`, so literal text such as `cb=10` remains
part of the assertion.

Evidence includes `summary.tsv` (total, retired, valid, filtered, selected,
executed, passed, failed, and manifest errors), `cases.tsv`, `errors.txt`,
`normalizations.tsv`, `fingerprints.tsv`, lab commit/status, source commit,
machine information, and toolchain version. Fingerprints include the harness.
Each executed case keeps its command JSON, stdout, stderr, exit code, output,
and asset hashes. Case exceptions fail that case and execution continues so the
summary also exists after failures. `validated_only` executes zero product cases
and is never a quality pass. Self-tests are evidence about the harness only.

The three historical `moonx_*`/`run_moonx_*` entrypoints are retired. Current
`moonx` runs standalone scripts using Wasm and no longer launches a Native
package. Native product installation uses `moon install`. Historical fake runner
outputs and package-coordinate MoonX results do not establish Native product,
installation, or publication acceptance.

This runner establishes the quality gate. It does not implement the two-window
performance protocol, Linux acceptance, the 60-minute reliability workload, or
published-version installation and library-consumer checks; those gates must be
recorded separately.

## Native benchmark protocol

### Budget measurements

`native_budget_profile.mbtx` collects budget provenance from an actual Native
executable. It follows the existing benchmark manifest/schema and CLI argument
contracts. The complete manifest is checked before filters: IDs and input paths
are unique, accepted inputs match size/SHA-256 and remain within the lab, and
disabled missing candidates stay explicitly unverified. The current corpus has
126 accepted inputs and nine missing candidates; those counts are observations,
not allowances for newly missing accepted files.

```text
moon check --target native --target-dir /private/tmp/markitdown-budget-profile-build --no-mbti --deny-warn tools/regression/native_budget_profile.mbtx
moon run --target native --target-dir /private/tmp/markitdown-budget-profile-build tools/regression/native_budget_profile.mbtx -- --self-test true
moon run --target native --target-dir /private/tmp/markitdown-budget-profile-build tools/regression/native_budget_profile.mbtx -- --binary /absolute/frozen-native-executable --lab /absolute/markitdown-quality-lab --evidence /absolute/new-preflight --validate-only true
moon run --target native --target-dir /private/tmp/markitdown-budget-profile-build tools/regression/native_budget_profile.mbtx -- --binary /absolute/frozen-native-executable --lab /absolute/markitdown-quality-lab --evidence /absolute/new-budget-profile --source-archive /absolute/frozen-source.tar --quality-evidence /absolute/profiled-quality-evidence
```

The default is one collecting CLI invocation per accepted input and each of
Markdown, Debug and RAG, using `balance`. Optional pairs are `--mode
balance|accurate|stream`, `--view all|markdown|debug|rag`, `--case ID`, `--format
FORMAT`, and `--timeout-ms N` (default 600000, maximum 3600000). Timeouts hard
cancel the process and retain its partial stdout/stderr. Each invocation uses
`--provenance-out`; its top-level `budget_usage` must contain the current explicit
measurement/coverage/unmeasured/resident policy and nonnegative Int64 decimal
strings. Missing, malformed, negative, overflowing, numeric JSON, unknown fields
or unconfirmed successful output fail the sample; none becomes zero usage.
Four exact partial schemas are supported: absent `budget_schema` means
`legacy_v1` (six counters, ZIP-only inflate/resident scope), `partial_v2` has
eight counters and adds the OOXML content-types cursor/work/map accounting,
`partial_v3` additionally measures PDF Flate output and modeled scratch, and
`partial_v4` adds relationship XML/retained string metadata, YAML reference
logical work and PDF structural-session work/payload cache.
Each schema requires its exact coverage and unmeasured policy. Non-Flate PDF
filters/predictors/text and other inflation remain unmeasured in v3. Older v1
sidecars that omitted `non_zip_inflate` from their limitations are rejected.
V4 ParseWork uses `modeled_parse_work_units`: cursor UTF8 work, YAML logical
node/merge-copy admission and PDF probe byte/code-unit/entry/visit/comparison
units. It is not uniformly UTF8 bytes or complete parse work. The exact models
and remaining omissions are in
[the budget contract](../../docs/architecture/conversion-budget-contract.md).
Schemas and measurement_only/explicit_enforced profiles remain separate groups.

`--quality-evidence` reads an existing complete passing all-suite Native run made
with `run_native_regression.mbtx --budget-profile true`, checks the same binary
SHA-256, and aggregates its sidecars without rewriting it. Expected rejections
retain `unavailable_expected_rejection`; they do not contribute zeroes or maxima.
`validated_only` runs no benchmark conversions and is not a measurement pass.

Evidence saves source/binary/lab/input fingerprints, commands, bodies, assets,
stdout/stderr, provenance and failures. `values.tsv` contains measured values;
`maxima.tsv` includes witnesses for each dimension globally, per format, per
view and per format/view, separately by corpus and combined. Every group
includes `schema` and `profile`: maxima never combine versions or combine
`measurement_only` with `explicit_enforced` observations. `all` combines
corpora only within the same schema/profile, and enforced observations can be
censored by their configured caps. Summary columns separately report benchmark
and quality measured/failed counts; `measured` remains their total. `coverage.tsv`
retains explicitly unmeasured dimensions and the scope-retained resident upper
bound policy. Each value/maximum also names its measurement scope: a zero ZIP
inflate counter under v1/v2 on PDF is not a measurement of PDF stream inflation.
Values and maxima name units: ParseWork uses modeled UTF8 work units (bytes
admitted/revisited by the XML cursor), while the other counters use bytes.
Partial ParseWork/source-metadata counters cover content-types only, and resident
peaks remain payload upper bounds with other cache/working storage unmeasured. Source
checkout fingerprints require the binary's independent
freeze/build evidence to establish their relationship.

Every report is `measurement_not_performance`: one sample is not a timing/RSS
window, process RSS is not inferred from payload leases, missing/rejected cases
remain unavailable, and uninstrumented dimensions remain unmeasured. This tool
does not choose headroom, freeze numeric defaults, modify goldens, or establish
enforced-budget/P2 acceptance.

### Timing windows

`native_benchmark.mbtx` measures two supplied Native executables. Run it from the
product root. It does not build, install, publish, or change the quality lab.
All options are explicit pairs. Binary, lab, contract, quality-evidence and output
paths should be absolute; the evidence directory must not already exist.

```text
moon check --target-dir /private/tmp/markitdown-benchmark-build --target native --no-mbti --deny-warn tools/regression/native_benchmark.mbtx
moon run --target-dir /private/tmp/markitdown-benchmark-build --target native tools/regression/native_benchmark.mbtx -- --self-test true
moon run --target-dir /private/tmp/markitdown-benchmark-build --target native tools/regression/native_benchmark.mbtx -- --baseline /absolute/baseline --candidate /absolute/candidate --lab /absolute/markitdown-quality-lab --evidence /absolute/preflight --window 1 --validate-only true
```

Validation verifies the whole benchmark manifest before filters: accepted files
must exist inside `external_bench`, be regular files, and match both byte count
and SHA-256. Missing candidates must be disabled and absent. They are counted
separately, never executed or counted as successes. Unknown formats, status,
tiers, comparison contracts or signals, malformed rows, duplicate IDs, missing
accepted inputs, bad hashes and zero accepted/selected cases fail. Current
preflight verified 126 accepted and 9 missing candidates with zero conversions;
these counts are observations, not hardcoded allowances for missing files.

Each invocation selects one window, fixes 3 warmups and 30 measured executions
per case **for each binary**, and alternates AB/BA pairs. Window 2 reverses the
first order. A pair uses the same input, mode, view, relative output paths and
locale, with a fresh working/product directory per execution. Startup, single
file and batch are separate invocations and configurations:

- `--surface startup`: only `--help`; no mode, view or case filters.
- `--surface single`: `--mode balance|accurate|stream`,
  `--view markdown|debug|rag`, optional `--case ID` and/or `--format FORMAT`.
- `--surface batch --batch-input /absolute/lab/external_bench/subdirectory`:
  the complete existing directory, without filters or copied inputs. Its whole
  tree is fingerprinted, including adjacent assets. Accepted input bytes define
  throughput; all files actually discovered by the CLI remain part of the
  workload. Choose the directory explicitly and review its contents.

To measure a selected single-file workload, repeat the same command with two
fresh evidence paths and `--window 1` / `--window 2`, then aggregate:

```text
moon run --target-dir /private/tmp/markitdown-benchmark-build --target native tools/regression/native_benchmark.mbtx -- --baseline /absolute/baseline --candidate /absolute/candidate --lab /absolute/markitdown-quality-lab --evidence /absolute/window-1 --window 1 --surface single --mode balance --view markdown --case pdf_case_id --quality-baseline /absolute/baseline-quality --quality-candidate /absolute/candidate-quality --limits-contract /absolute/benchmark-contract.json
moon run --target-dir /private/tmp/markitdown-benchmark-build --target native tools/regression/native_benchmark.mbtx -- --baseline /absolute/baseline --candidate /absolute/candidate --lab /absolute/markitdown-quality-lab --evidence /absolute/window-2 --window 2 --surface single --mode balance --view markdown --case pdf_case_id --quality-baseline /absolute/baseline-quality --quality-candidate /absolute/candidate-quality --limits-contract /absolute/benchmark-contract.json
moon run --target-dir /private/tmp/markitdown-benchmark-build --target native tools/regression/native_benchmark.mbtx -- --aggregate /absolute/window-1,/absolute/window-2 --evidence /absolute/comparison
```

The CLI currently has no resource-limit override/introspection flag. A reviewed
JSON contract therefore binds effective defaults, compiler, build flags and
artifact provenance to the actual binary hashes. This is an audit assertion,
not information extracted from executable bytes. Example schema (replace both
hashes and the audit reference with real evidence):

```json
{
  "baseline_sha256": "BASELINE_SHA256",
  "candidate_sha256": "CANDIDATE_SHA256",
  "baseline_compiler": "moonc v0.10.17+093cb8f9c",
  "candidate_compiler": "moonc v0.10.17+093cb8f9c",
  "baseline_build_flags": "--target native --release",
  "candidate_build_flags": "--target native --release",
  "baseline_origin": "installed_cli",
  "candidate_origin": "installed_cli",
  "audit_reference": "/absolute/reviewed-source-and-install-evidence",
  "exclusive_window": true,
  "execution_conditions": "Record idle host, power/thermal state and absence of competing builds here",
  "baseline_limits": {
    "max_rows": 2000, "max_cols": 50, "max_cells": 100000,
    "max_line_chars": 4000, "max_input_bytes": 536870912,
    "max_asset_bytes": 33554432, "max_total_asset_bytes": 134217728
  },
  "candidate_limits": {
    "max_rows": 2000, "max_cols": 50, "max_cells": 100000,
    "max_line_chars": 4000, "max_input_bytes": 536870912,
    "max_asset_bytes": 33554432, "max_total_asset_bytes": 134217728
  }
}
```

Limits must match the current CLI defaults exactly; the CLI has no override.
Compiler, flags and
origin must match; a compiler upgrade needs its own baseline. Both quality
directories must contain an unfiltered, fully passing `suite=all` Native
regression summary and fingerprints bound to the corresponding executable.
Missing/mismatched quality evidence or contract permits saved measurements but
forces `inconclusive`. Control of competing work and the accuracy of the audit
assertion still require operator review; the harness does not infer an idle
machine from elapsed times.

Per-run artifacts include structured command, stdout/stderr, raw `/usr/bin/time`
output, product files, an output-file hash inventory and `sample.json`. macOS
uses `time -l` (RSS in bytes); Linux uses `time -v` (RSS KiB converted to bytes).
Window artifacts include p50/p95/count for wall time, peak RSS, user+system CPU,
first observable output and throughput; binary sizes/hashes, complete corpus
hashes, harness hash, machine/hardware, toolchain and lab Git state are saved.
Percentiles use nearest rank. Startup throughput is operations/s; conversion
throughput is accepted input bytes/s.

Markdown, stdout/stderr and assets compare exact bytes and file sets. Generated
Debug/RAG/provenance/manifest JSON is canonicalized with duplicate keys rejected;
only `diagnostics.metrics`' five declared `timing_*_ms` fields and root
`stage_timings_ms` are excluded. JSON assets still compare raw byte hashes.
Any other output/structure/order/metadata/source/asset/diagnostic change fails
comparison and suppresses all improvement ratios. A correctness fix needs its
own reviewed contract update before same-output performance comparison.

Single-file first output is the first observed nonempty **final path**; batch
uses visibility of `manifest.json`. Both are 1 ms polling upper bounds, not
proof of a streaming first byte or atomic commit. Startup stdout uses the
official process pipe reader's first successful read. These observations use
the runtime's millisecond wall clock and include wrapper/scheduling overhead.
Wall/CPU/RSS remain the process metrics from `time`; an unavailable metric is
never substituted. Timeouts (default `--timeout-ms 600000`) stop the window and
retain failure evidence; process-tree cleanup is a separate reliability gate.

A window reports `window_complete_pending_second`, never an acceptance pass.
Aggregation rejects overlapping windows, different fingerprints/configurations,
changed saved outputs, or per-case p50/p95 latency/RSS regression above 10%.
Incomplete 3/30 data, missing/zero metrics, wall p50 below 20 ms, or wall p95/p50
above `--max-spread 1.20` are `inconclusive` and suppress ratios. The threshold
must be fixed before measuring. Only two complete admissible windows can report
`cli_two_window_pass`; PDF's 50% latency / 30% RSS goals are reported separately
as met/not met. No overall average can hide an individual regression.

`formal_plan_status` always remains `inconclusive`: public-library stable-loop
measurement and profiles, installation/build/dependency cost, two-platform
coverage, 60-minute load and process/FD/temp cleanup are separate pending gates.
Small workloads require the future library loop; CLI startup must not stand in
for library conversion. `--self-test true` validates parser, manifest failure,
asset fingerprint and scheduling/statistics behavior plus one harmless echo
subprocess; `--validate-only true` executes zero product cases. Neither is
performance evidence. The earlier P0 engineering measurements also retain
their CPU-contention/shared-assets/noninterleaving limitations.
