# Core

`core/` defines the cross-format shared core model. It is the long-term stable boundary between parser, pipeline, and render.

It mainly contains:

- document IR
- block / event / asset models
- diagnostics
- source refs
- shared low-level constructors used across layers

Main files:

- `core.mbt`: package entry
- `constructors.mbt`: common IR constructors
- `diagnostics.mbt`: diagnostics and status helpers
- `source_refs.mbt`: source-ref and source-map helpers

Maintenance rules:

- shared fields should be defined here first and then propagated upward
- `core/` should only contain truly cross-format, cross-layer stable models
- temporary format-local details should not leak into the shared core model

Validation:

```bash
moon test
```
