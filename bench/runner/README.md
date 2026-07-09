# Bench Runner

`bench/runner/` is the formal benchmark executor. It combines external corpora, comparison tools, scenario presets, and resource measurements into reproducible performance experiments, without participating in the normal product conversion path.

## Responsibilities

- Parse benchmark CLI commands and presets
- Read manifests, filter sample rows, and expand scenarios
- Schedule tool execution, timing, and resource sampling
- Aggregate results and emit reports, gates, and summary statistics

## Key Entry Points

- `main.mbt`
  Benchmark CLI entry point
- `runner.mbt`
  Scenario execution, sample aggregation, and overall report structures
- `cli.mbt`
  Runner subcommand dispatch
- `execution.mbt`
  Concrete execution orchestration
- `aggregate.mbt` / `report.mbt`
  Aggregation and report generation
- `manifest/`
  Manifest row models, parser, and selector logic
- `tools/`
  Adapters for `markitdown`, MoonBit CLI, MoonBit engine, and other benchmark tools
- `measure/`
  Monotonic timing and native resource-usage sampling

## Key Types

- `RunOptions`
  Global configuration for one benchmark run
- `ScenarioSpec`
  The input, tools, and strategy definition for one comparison scenario
- `RunSummary`
  The cross-scenario aggregate summary
- `BenchTool`
  The unified command-construction interface for a benchmarked tool

## Maintenance Rules

- Keep benchmark strategy, sample selection, and gate rules centralized instead of creating one-off script paths
- The runner may call external tools, but should not affect main product CLI behavior or dependency boundaries
- Report fields should remain stable so historical comparisons and automation stay reliable

## Validation

```bash
moon test
bash samples/check_balance_quality.sh
```
