# CLI

`cli/` provides the formal command-line entry point for the project. It is the main product surface that users interact with directly.

Main responsibilities:

- parse CLI arguments and normalize them into stable conversion requests
- execute single-file and batch conversion
- print help, version, and user-facing error messages
- expose formal `convert` capabilities through one consistent CLI surface

Main files:

- `main.mbt`: native executable entry
- `cli.mbt`: top-level execution flow
- `cli_parse.mbt`: argument parsing and normalization
- `cli_batch.mbt`: batch conversion, manifest output, and asset persistence
- `cli_help.mbt`: help text and user-facing warning messages

Maintenance rules:

- new flags should normalize into `CliOptions` first
- the CLI should expose only formal product paths
- user-facing warnings, fallbacks, and dependency guidance must stay stable and regression-testable

Validation:

```bash
moon test
bash samples/check_balance.sh
```
