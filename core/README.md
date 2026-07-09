# Core

`core/` defines the shared public IR and foundational models used across formats. It is the most stable contract layer between parser, pipeline, render, and convert.

## Responsibilities

- Define document, block, inline, event, asset, and diagnostics models
- Define provenance, source refs, and container-entry location structures
- Provide shared constructors, document operations, and debug helpers

## Key Entry Points

- `core.mbt`
  `DocumentIR`, `CoreBlock`, `CoreInline`, `SourceRef`, `AssetRef`, `Diagnostics`
- `constructors.mbt`
  Shared `make_*` constructors and stable naming helpers
- `document_ops.mbt`
  `document_from_blocks`, `document_with_*`
- `source_refs.mbt`
  `empty_source_ref`, `source_ref_with_*`, `make_container_entry`
- `diagnostics.mbt`
  Diagnostics accumulation and dependency-diagnostic constructors
- `event_document_builder.mbt`
  Recovery of a basic document tree from event streams

## Key Types

- `DocumentIR`
  The canonical document object carried through the main product path
- `DocumentAssembly`
  Structural overlays such as section trees, reading order, caption bindings, and asset ownership
- `SourceRef` / `SourceMap`
  The unified provenance location model
- `Diagnostics`
  Cross-stage aggregation of warnings, errors, fallback traces, pass traces, and dependency state

## Maintenance Rules

- Only truly cross-format, cross-layer stable fields should enter `core/`
- Do not leak format-private state into the public IR; prefer metadata, signals, or assembly side channels when needed
- Adding a new `core` field usually affects parser, pipeline, render, and provenance together, so evaluate the full blast radius first

## Validation

```bash
moon test
```
