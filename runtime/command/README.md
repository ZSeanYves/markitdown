# Runtime Command Boundary

`runtime/command/` is the shared native boundary for resolving and executing
optional external tools. Format packages describe a request; this package owns
command provenance, argv transport, timeout, cancellation, and output limits.

## Resolution Order

Commands may come from an explicit argument, a repo-managed record, an approved
environment variable, `PATH`, or a named fallback. A repo-managed record lives
at `env/managed-paths/<name>` under `MARKITDOWN_MODULE_ROOT` and must contain
exactly one absolute executable path. Empty, relative, multiline, missing, and
non-executable records are ignored.

## Execution Boundary

`run_resolved_command` and its async counterpart pass argv directly without
interpolating document text into a shell command. `CommandLimits` bounds wall
time, termination grace, stdout, and stderr. Cancellation and timeout reap the
child process group. Official wrappers establish their own deterministic child
environment.

## Validation

```bash
moon test runtime/command --target native
```
