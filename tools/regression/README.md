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
Seven exact partial schemas are supported: absent `budget_schema` means
`legacy_v1` (six counters, ZIP-only inflate/resident scope), `partial_v2` has
eight counters and adds the OOXML content-types cursor/work/map accounting,
`partial_v3` additionally measures PDF Flate output and modeled scratch, and
`partial_v4` adds relationship XML/retained string metadata, YAML reference
logical work and PDF structural-session work/payload cache. `partial_v5` adds
core/app selected scalar work, admitted private buffers and retained strings,
plus PDF indexed dictionary/range payload, exact-read scratch and ObjStm member
work/cache. V5 retains the mixed ParseWork unit and excludes complete xref,
font/image/text workspace, allocator/container overhead and the other stated
unmeasured scopes. `partial_v6` adds CLI external SourcePath actual read traffic,
scope-held final Bytes cache and private collection/bounded-read payload working;
it preserves v5 ParseWork and SourceMetadata scopes. `partial_v7` adds custom
property cursor/serialized-value work, final name/type/value metadata,
namespace/value workspace, retained strings and Ranged parsed-font payloads.
Its unmeasured list changes only
`ooxml_validation_issues_and_temporary_metadata` to
`ooxml_validation_issues_and_other_temporary_metadata`. V1-v6 retain their exact
policies. A runtime's declared schema is uniform across routes, including
library conversions without CLI asset reads; absent activity in a covered
dimension can be zero without changing policy. Extra `cli_source_asset_*` or
font-cache diagnostics are not budget_usage fields: v7 still has exactly
thirteen fields and eight counters, with the same profile/resident contract.
Its groups remain separate from every historical schema.
Each schema requires its exact coverage and unmeasured policy. Non-Flate PDF
filters/predictors/text and other inflation remain unmeasured in v3. Older v1
sidecars that omitted `non_zip_inflate` from their limitations are rejected.
V4/V5/V6/V7 ParseWork uses `modeled_parse_work_units`: cursor UTF8 work, YAML logical
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
Values and maxima name units: v2/v3 ParseWork uses modeled UTF8 work units; v4
and later use the mixed admission units above, with v5/v6 adding selected core/app
scalars and indexed ObjStm code units, and v7 adding emitted custom-value scalars.
Other counters use bytes. V2/v3 source metadata covers content-types strings,
v4 adds relationship strings, v5/v6 add selected core/app strings, and v7 adds
custom property name/type/value strings. The font cache adds neither ParseWork
nor SourceMetadata. Resident peaks remain payload upper bounds with
other cache/working storage unmeasured. Source
checkout fingerprints require the binary's independent
freeze/build evidence to establish their relationship.

V6 external SourcePath assets borrow the conversion's account and owner. The
opened descriptor's admitted actual extent is read in at most 64 KiB requests;
a successfully cached pathname reads only once, while every logical asset still
counts toward the unchanged 32 MiB single/128 MiB total policy. Private Working
admission is `size + 2 * min(size, 65536)` and final Bytes reserve `size` Cache
through owner cleanup. Empty extents return empty Bytes without a collection
buffer/lease. Existing Bytes/Utf8 assets retain size admission without an extra
new CLI cache charge. Only typed ENOENT remains unavailable; other probe/read
errors are hard IO, resource limits remain distinct, and failure/cancellation
release owned scratch. These are payload models and opened-fd identity, not a
filesystem snapshot, RSS estimate or transaction over output files. V6 profile
execution is still pending; schema self-tests alone do not validate its corpus.

V7 custom strings charge UTF8 SourceMetadata and two bytes per retained UTF16
unit. Name/type and namespace Strings retained across cursor tokens use two
Working bytes per UTF16 unit; Char-buffer capacity uses four bytes per slot,
admitting old and new capacity together during growth. Final serialized value
work includes emitted wrappers, attributes, namespaces and escaping. The font
cache covers Ranged streams in one document, keyed by object ID, definition
offset, generation and parser kind. After pure parsing and before publication,
Cache admits actual capacities of three Int32 arrays × 4, two String-reference
arrays × 8, stored UTF16 strings × 2, a present default width × 4, and 20 numeric
key bytes. This Native64 retained-payload model excludes preparse/parser scratch,
allocator/container/map headers and alignment; it is not a preallocation guard
or RSS bound. Loaded/repair FontFiles remain outside the cache. V7 actual
profile execution awaits its own frozen source/binary; no old window is rerun
or relabeled to supply that evidence.

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

### Public-library collecting loop (draft tool)

`native_library_benchmark.mbtx` adds an independent public `lib` collecting
surface. It does not modify or replace `native_benchmark.mbtx` and does not
turn CLI, installation or quality evidence into library-performance evidence.
The first version supports collecting `convert` only. `first_output_ms` is
always null; Sink first-callback latency and discard-Sink memory are separate
pending gates. Internal budget counters and phase hotspots are
`unavailable_public_api`.

The generated consumers import the product solely as
`ZSeanYves/markitdown/lib`, together with ordinary core/async/crypto utilities.
No parser, internal convert, renderer, ZIP or budget API is imported. Each
lane has the same generated consumer source, its own Native release build,
and a workspace bound to an explicit frozen source root. Build commands use
`--warn-list +73 --deny-warn`.

Prepare from two independent source snapshots and provide their archives as
provenance annotations. The tool fingerprints the **actual build source tree**,
including hidden files and internal file symlink targets, and separately the
archive bytes. An archive is not claimed to be the origin of a supplied root
merely because both paths were supplied. Root caches, `.git`, `_build`, `.tmp`
and `.audit` are excluded from the source identity. Resolved dependency source
bytes, dependency identities, workspace, consumer source/package/executable,
toolchain versions and executable hashes, machine, inputs and running harness
source are also frozen. Dependency bytes must be inspectable; missing hashes
fail preparation. Source, input, dependency, compiler, harness or consumer drift
makes subsequent evidence inconclusive.

A case manifest has exact schema 1 keys `schema` and `cases`, with at least one
unique case. Every case contains exactly these fields:

```json
{
  "id": "tiny_markdown",
  "input": "/absolute/frozen/input.md",
  "input_sha256": "64 lowercase hexadecimal characters",
  "source_name": "input.md",
  "input_kind": "bytes",
  "format": "markdown",
  "mode": "balanced",
  "view": "markdown",
  "limits": {
    "max_rows": "2000",
    "max_cols": "50",
    "max_cells": "100000",
    "max_line_chars": "4000",
    "max_input_bytes": "536870912",
    "max_asset_bytes": "33554432",
    "max_total_asset_bytes": "134217728"
  },
  "rag": {
    "chunk_size": 1200,
    "chunk_overlap": 150,
    "preserve_heading_path": true,
    "preserve_source_ref": true,
    "split_tables": true,
    "split_code_blocks": true
  },
  "asset_demand": "public_metadata_only"
}
```

Input kind is one of `path`, `text`, `bytes`, `reader`, `async_reader`; mode is
`balanced`, `accurate`, `stream`; view is `markdown`, `debug`, `rag`. A nonempty
format must be canonical and must equal the detected output format. Empty format
freezes autodetection. Text strictly decodes the frozen UTF-8 bytes with BOM
preserved for the public API. Path includes per-call file IO. Other kinds preload
the fixture outside call timing. Both Reader variants expose the known input
size, return up to the requested remaining bytes, and record actual returned
bytes; no artificial delay or short-read schedule is added.
For Path, `source_name` does not override the actual input path. SourceRefs may
therefore differ between constructors; equality is required between lanes for
the same case, rather than between all five constructors.

All seven limits are explicit decimal Int64 strings; the four Int32 dimensions
must fit Int32. The example records current defaults rather than changing them.
The public facade has no CLI ExistingOutputAssets demand: asset requirements
here are its returned metadata and any payloads actually present. Full asset
metadata/payload equality is checked; the tool cannot silently promote this to
CLI file-export semantics.

For every consumer invocation, one untimed oracle conversion produces the full
public result. Its complete Debug representation is rendered with explicit
maximum depth and hashed outside call timing. Each measured conversion is
bracketed with Native `core/bench.monotonic_clock_start/end`; **after its stop**,
the entire public Output is compared with the oracle, including content,
metadata, all diagnostics, provenance, sources, chunks, assets and payloads.
Counts and reader bytes are checked on every iteration. The timing-field
normalization allowlist is empty: current `lib/adapter.mbt::stable_diagnostics`
does not export internal timing metrics. Future time-varying diagnostics must
be individually reviewed; dropping diagnostics as a group is forbidden.
Cross-lane or cross-window output-fingerprint differences are inconclusive.
Correctness changes need a separate quality review before a performance window.

Use an explicit calibration operation to select the same iteration count N
for both lanes, requiring at least 20 ms summed public-call duration in both.
N is fixed for the two windows; samples below 20 ms remain inconclusive and are
not silently resized. The calibration safety ceiling is one million iterations
and is a harness bound, not a production resource default.

Each independent window records three warmup samples per lane and thirty
measured samples per lane. Measurement consists of fifteen ABBA quartets;
window 2 uses BAAB. Full per-case/lane/window p50/p95, throughput and ratios are
preserved; no overall average hides individual regressions. Missing, duplicate,
out-of-order or overlapping samples, insufficient duration, absent/zero-resolution
metrics, excessive p95/p50 spread, fingerprint drift or quality failure produce
inconclusive evidence. The scoped 10% comparison is distinct from full P5
acceptance.
Aggregation binds each window's exact case list to the actual frozen
`prepared.json`, and every sample's N to the actual hashed `calibration.json`.
It canonicalizes both evidence directories, rejects directory aliases and
overlapping complete window intervals, and rechecks source/dependency/consumer
fingerprints. Matching annotations in two window files alone are insufficient.

The scopes of the two timing families must remain separate:

- `conversion_us` sums only monotonic public-call intervals. Throughput is
  conversions per second over those intervals. Input construction and complete
  verification occur outside them.
- `/usr/bin/time` process wall/CPU/peak RSS includes startup, preload, oracle,
  complete fingerprint storage, calls and all untimed checks. Its raw logs are
  retained with locale C. It is **not conversion-only CPU/RSS**. In particular,
  this verifier process cannot establish the PDF pure-conversion RSS target.
- Missing CPU/RSS/wall values remain null. No unavailable value is converted to
  zero. Collecting first output remains null. Budget ledger counters remain
  unavailable and are not inferred from public content lengths.

Proposed commands, all with new evidence directories:

```sh
moon check --target-dir /tmp/lib-bench-check --warn-list +73 --deny-warn /absolute/native_library_benchmark.mbtx
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --self-test true
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --prepare true --harness /absolute/native_library_benchmark.mbtx --baseline-source /absolute/frozen-baseline --candidate-source /absolute/frozen-candidate --baseline-archive /absolute/baseline.tar --candidate-archive /absolute/candidate.tar --cases /absolute/cases.json --evidence /absolute/prepared
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --calibrate true --prepared /absolute/prepared --evidence /absolute/calibration
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --window 1 --prepared /absolute/prepared --calibration /absolute/calibration --evidence /absolute/window-1
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --window 2 --prepared /absolute/prepared --calibration /absolute/calibration --evidence /absolute/window-2
moon run --target-dir /tmp/lib-bench-tool /absolute/native_library_benchmark.mbtx -- --aggregate /absolute/window-1,/absolute/window-2 --evidence /absolute/comparison
```

`--dev-smoke true` uses the prepare arguments, builds the two real consumers,
and runs one iteration per lane/case. It is deliberately not calibration, a
formal sample or a performance pass. Selftests use synthetic tool records only.
All failure evidence is saved; `formal_plan_status` remains inconclusive because
installation, full quality, complete required case coverage, CLI surfaces,
platforms, soak, Sink and hotspot gates are independent.

Tool-development evidence is under
`.audit/2026-10-23-native-upgrade/native-library-benchmark-draft` and
`native-library-benchmark-dev-smoke-v3`. Standalone `+73 --deny-warn` checking,
format checking and synthetic fail-closed selftests pass. The selftest runtime
also emits a dependency/script-driver duplicate-import warning for
`moonbitlang/async/internal/c_buffer`; it is preserved in the log.

The real Native smoke built both public-only consumers with `+73 --deny-warn`
and executed five tiny cases (all five constructors), one iteration per lane:
ten consumer processes plus their untimed oracles, all full public fingerprints
equal between lanes. The final generated consumer SHA-256 remains
`45a442646b3ada684b0d4e4d74bd74dd8fdc39a2f2f3909958d0eba59dcaabde`, equal to
both actually compiled `main.mbt` files. Later harness-only binding fixes were
validated by pure selftests; the original smoke harness and failed v1/v2 tool
attempts remain preserved. Those smoke prepared records are tied to their
original harness hash and must not be reused for formal windows after an edit.
No formal calibration or window has been executed. This is tool-development
evidence, not P5 performance acceptance.
