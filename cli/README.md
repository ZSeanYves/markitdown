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

Markdown file output uses an atomic unbuffered sink only for the explicit
assetless whitelist: TXT, CSV/TSV, SRT/VTT, JSON/JSONL/NDJSON, XML, YAML, and
TOML. The CLI writes a sibling temporary file and commits only after sink finish.
Write failures, unexpected assets, and true empty failures abort without a
target or temporary file. A fail-closed XML fence is valid output and may be
committed even when diagnostics retain the triggering parse error.

## Maintenance Rules

- New flags should normalize into `CliOptions` first instead of leaking intent through scattered booleans
- The CLI should expose only formal product paths, not experimental parser side routes
- Dependency-missing, degradation, and fail-closed messages should stay stable so scripts and regression tests can rely on them
- Unsupported modes must be rejected by the shared route policy, not handled by
  CLI-only fallback. Stdout must not contain local asset links that were never
  materialized, and batch must return non-zero on partial failure.

## Validation

```bash
moon test cli --target native
bash tools/regression/check_balance.sh
```
