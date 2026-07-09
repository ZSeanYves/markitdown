# Runtime

`runtime/` contains repository-wide runtime glue. It centralizes recurring coordination logic shared by parser, pipeline, and render, and isolates concerns such as command resolution, nested-document reuse, and diagnostics merging that do not belong to one format package alone.

## Responsibilities

- Normalize `ParseResult` into the unified `core.IRInput`
- Merge `Diagnostics` across parent and child document flows
- Reuse the root `ParserRegistry` and default pipeline for containers, nested documents, and child resources
- Resolve repo-managed commands, `PATH` commands, and shell command assembly rules

## Key Entry Points

- `runtime.mbt`
  `parse_result_to_ir_input`, `merge_diagnostics_unique`, `merge_diagnostics_append`
- `runtime.mbt`
  `parse_child_to_block_product`, `parse_child_to_document`
- `command/command.mbt`
  `resolve_executable_path`, `resolve_repo_managed_command`, `join_shell_command`

## Key Types

- `ChildBlockProduct`
  The smallest complete block, asset, and diagnostics bundle returned from child-document parsing
- `ResolvedCommand`
  A unified description of an external command source, path, arguments, and fallback context

## Maintenance Rules

- Keep only cross-package, cross-format runtime glue here; format-private logic should stay in `formats/*` or `format_readers/*`
- Child-document parsing must continue to use the root registry and default pipeline to avoid format-private side paths
- Runtime helpers may coordinate external commands, but should not introduce new product-level routing policy

## Validation

```bash
moon test
```
