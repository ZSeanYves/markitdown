# ADR 0002: Establish the Stable 0.8 Façade

- Status: accepted
- Date: 2026-08-05
- Owners: @ZSeanYves
- Related: Phase 1 package/API restructuring

## Context

The conversion entrypoint exposed input, parser, product, IR, RAG and provider
records from multiple packages. More than two hundred legacy `pub(all)`
declarations made implementation changes look like public compatibility
commitments. MoonBit's current native ecosystem also requires async, process
FFI and external tools to be isolated from portable data contracts.

## Options considered

Keeping every existing package stable would freeze parser and pipeline details.
Renaming the entire tree to `internal` would create a large mechanical diff
without enforcing consumer behavior. A small façade with private adapters gives
callers a durable contract while allowing staged internal migration.

## Decision

`ZSeanYves/markitdown/api` is the sole stable 0.8 library package. `Input` is
abstract, all output fields use stable local types, and errors have fixed codes
and exit classes. Parser registries, format models, pass contexts, async, FFI
and external providers are internal/extension contracts. Existing packages are
legacy migration surfaces, not stable APIs.

The generated interface is reviewed as a golden. Public enum variants use
MoonBit's required `pub(all)` visibility; records remain readonly or abstract.
CI forbids internal type leaks, mutable façade records, dependency drift,
unreviewed visibility growth and additional deep-format coupling in top-level
packages.

## Consequences

Internal refactors and community-library adapters can proceed without changing
user code. Consumers needing raw IR must remain on an unstable internal API or
propose a versioned extension. The façade is native-only until a portable
filesystem/process product path has equivalent behavior.

## Verification and rollback

```bash
moon test --target native -p ZSeanYves/markitdown/api
moon info --package ZSeanYves/markitdown/api
python3 tools/governance/check_architecture.py
```

Rollback removes the façade and restores the five-dependency module manifest;
no parser or output implementation was deleted by this decision.
