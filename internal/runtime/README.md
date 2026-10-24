# Internal Native runtime

`internal/runtime` owns shared coordination between parsing, pipeline and
rendering. These types and helpers do not cross the stable
`ZSeanYves/markitdown/lib` façade.

## Current responsibilities

- Normalize `ParseResult` into the shared IR input.
- Merge diagnostics across parent and child documents.
- Reuse the root registry and pipeline for nested/container documents.
- Keep repository process helpers separate from format semantics.

`runtime.mbt` provides `parse_result_to_ir_input`,
`merge_diagnostics_unique`, `merge_diagnostics_append`,
`parse_child_to_block_product` and `parse_child_to_document`.
`ChildBlockProduct` bundles blocks, assets and diagnostics for nested input.

The current child-document adapters include synchronous internals. The
single async Reader/Registry/pull/Sink protocol, deterministic session cleanup
and cumulative budgets remain P2 work in the
[Native plan](../../docs/architecture/native-performance-plan.md). The current
async public entrypoint does not prove that all internal execution is unified.

## Process support

`command/` contains executable resolution and bounded direct-argv process
helpers. Its current consumer is the repository's hermetic test support;
conversion does not require an external converter, OCR/audio process or
runtime installer. The C ownership and removal conditions are in the
[FFI inventory](../../docs/ffi-inventory.md).

Keep format-private logic in its format package. Child parsing must use the
shared registry/pipeline rather than establish another conversion chain.
Do not convert I/O, cancellation, integrity or resource failures into a more
permissive provider.

## Validation

```text
moon test --target native internal/runtime --no-parallelize
```

Installed Native products and independent public consumers are checked through
[repository regression tools](../../tools/regression/README.md). P2–P6 remain
separate implementation, platform, performance, reliability and publication
gates.
