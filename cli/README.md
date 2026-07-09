# CLI

`cli/` provides the formal command-line entry point for the project and is the product surface most end users interact with. It is responsible for normalizing command-line syntax into convert-layer requests and handling single-file, batch, and output-boundary concerns.

## Responsibilities

- Parse CLI arguments and build `CliOptions`
- Execute single-file conversion and batch conversion
- Print help, version, warnings, and user-actionable error messages
- Persist content, provenance, and asset files at the output boundary

## Key Entry Points

- `main.mbt`
  Native executable entry point
- `cli.mbt`
  `run_cli_app`, `run_cli`, and the main output-persistence flow
- `cli_parse.mbt`
  Argument parsing, defaults, and compatibility/removal guidance
- `cli_batch.mbt`
  Batch conversion, manifest generation, and batch-status aggregation
- `cli_types.mbt`
  `CliOptions` and batch-task result structures
- `cli_help.mbt`
  Help text, usage, and dependency guidance

## Key Types

- `CliOptions`
  The normalized CLI input that feeds directly into the convert layer
- `BatchTaskResult`
  A per-task summary of detection, route selection, and failure reasons in batch mode

## Maintenance Rules

- New flags should normalize into `CliOptions` first instead of leaking intent through scattered booleans
- The CLI should expose only formal product paths, not experimental parser side routes
- Dependency-missing, degradation, and fail-closed messages should stay stable so scripts and regression tests can rely on them

## Validation

```bash
moon test
bash samples/check_balance.sh
```
