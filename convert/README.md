# Convert

`convert/` is the unified public conversion entry point. CLI code, tests, and future integrations should prefer this layer.

Main responsibilities:

- accept top-level conversion requests
- freeze execution plans from format, mode, and runtime signals
- coordinate the formal parser, pipeline, and render path
- produce provenance so behavior stays explainable and regression-testable

Main files:

- `convert.mbt`: public `convert_input*` APIs
- `convert_types.mbt`: conversion options, execution-plan models, and provenance models
- `route_policy.mbt`: route planning and strategy decisions
- `convert_finalize.mbt`: result finalization and provenance assembly

Maintenance rules:

- all route decisions should converge in `route_policy.mbt`
- provenance fields should be maintained centrally
- new capabilities should extend the formal plan instead of bypassing the main path through one parser directly

Validation:

```bash
moon build
moon test
```
