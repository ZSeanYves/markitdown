# Performance evidence and acceptance

The formal Native performance gate has not been completed. No latency or RSS
improvement, PDF target achievement, cross-platform performance pass or full
RC pass is claimed by this document.

The [Native upgrade plan](architecture/native-performance-plan.md) defines the
measurement protocol. Historical MoonX package timings, fake runners, and
comparisons with different inputs or extraction amounts do not enter a
same-quality Native speedup result.

## Prerequisites

Freeze the source/dependencies/toolchain, real baseline and candidate Native
executables, machine details, input hashes, modes, limits, assets and output
targets. First execute the full valid quality contracts. Compare Markdown,
Debug, RAG, provenance, stdout, stderr and asset sets/hashes separately.
An intentional correctness change needs a classified and reviewed golden
change before its performance comparison is admitted.

The active tools have narrower roles:

- `freeze_native.mbtx` records source, corpus, machine, toolchain and
  dependency fingerprints.
- `run_native_regression.mbtx` executes quality contracts against an actual
  Native executable.
- `compare_native.mbtx` compares saved outputs; changed outputs require
  review and are not automatically accepted.
- `native_install.mbtx` checks installation and independent library use.
  Its optional `--audit-bench true` audits the benchmark manifest, input
  sizes and hashes. That audit does not execute the timing protocol.

The retired `moonx_benchmark.mbtx` is not a Native performance runner.

## Formal protocol

Measure installation/build cost, installed CLI startup/single-file/batch
behavior, and repeated public-library conversion separately. Use two
independent windows, each with 3 warmups and 30 measurements per group.
Interleave baseline and candidate. For small inputs, add library-internal
batch measurements so clock resolution does not dominate.

Save per-case p50/p95, peak RSS, CPU, first output, throughput, installed
executable/dependency size, machine and compilation fingerprints. Keep raw
measurements and failed/incomplete-window evidence. A single timing, a
manifest audit or one local window is insufficient.

Quality is a hard prerequisite. Comparable per-case latency and RSS must not
regress by more than 10%; an aggregate mean cannot hide a slower case. Toolchain
changes get their own baseline. Installation-size increases need a corresponding
capability benefit.

Under the complete PDF quality contract, the optimization targets are at least
50% lower latency and 30% lower peak RSS. These are targets, not measured
results. Insufficient data or excessive variance is inconclusive.

## Remaining gates

P2–P4 execution, parsing and PDF work remain incomplete. P5 additionally needs
Linux x86_64 and macOS arm64 full regressions, both performance windows,
60-minute mixed workloads and 1/2/4 independent processes with stable RSS,
file-descriptor and temporary-file behavior. P6 published-version confirmation
is separate. Do not substitute local unit tests or public-façade smoke for
these gates.
