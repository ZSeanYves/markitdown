# Benchmark Runner

`internal/bench_runner` owns CLI parsing, sample execution, resume/checkpoint state,
resource collection, report generation, and enforcement summaries for the
binary-only benchmark system.

It must not import format parsers as an alternate conversion path. MoonBit work
is measured through the built CLI/engine binaries so benchmark truth matches the
product path. External commands and input rows come from explicit scenario and
manifest records.

Key outputs are JSONL progress, atomic `samples.jsonl`, `summary.json`, and the
Markdown report. Schema changes require backward-reading tests for existing run
reports.

`change-risk` is the normal push/PR preset and requires truth plus MoonBit CLI
RSS; performance may be `not_applicable`. Scheduled CI runs the full external
comparison and mutation smoke. RSS gates use only `moonbit-cli` samples, never
an aggregate that includes the external tool process tree.

Validation:

```bash
moon test --package ZSeanYves/markitdown/internal/bench_runner
moon build --target native --release --package ZSeanYves/markitdown/internal/bench_runner
_build/native/release/build/internal/bench_runner/bench_runner.exe doctor
```

User-facing commands and gates are documented in
[../../../bench/README.md](../../../bench/README.md).
