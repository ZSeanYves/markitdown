# Benchmark Runner

`bench/runner` owns CLI parsing, sample execution, resume/checkpoint state,
resource collection, report generation, and enforcement summaries for the
binary-only benchmark system.

It must not import format parsers as an alternate conversion path. MoonBit work
is measured through the built CLI/engine binaries so benchmark truth matches the
product path. External commands and input rows come from explicit scenario and
manifest records.

Key outputs are JSONL progress, atomic `samples.jsonl`, `summary.json`, and the
Markdown report. Schema changes require backward-reading tests for existing run
reports.

Validation:

```bash
moon test --package ZSeanYves/markitdown/bench/runner
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe doctor
```

User-facing commands and gates are documented in [../README.md](../README.md).
