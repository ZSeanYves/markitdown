# Convert

`convert/` is the unified public conversion API layer. CLI, tests, and future external integrations should prefer this layer instead of directly wiring parser, pipeline, and renderer together.

## Responsibilities

- Accept top-level conversion requests and normalize options
- Probe inputs first, then freeze execution plans and route plans
- Coordinate parser, pipeline, and render as one canonical path
- Return final content, diagnostics, assets, source map, and provenance

## Key Entry Points

- `convert.mbt`
  `convert_input`, `plan_input`, `convert_input_with_provenance`
- `types.mbt`
  `ConvertOptions`, `RoutePlan`, `ConvertProvenance`, `ConvertResult`
- `route_policy.mbt`
  Unified routing, profile, and strategy decisions
- `probe*.mbt`
  Probing logic for structured text, containers, and paged media
- `execution.mbt`
  Main execution orchestration for parse, pipeline, and render
- `json.mbt`
  JSON projections for route plans and provenance
- `convert_finalize.mbt`
  Final output assembly, diagnostics merging, and provenance finalization

## Key Types

- `ConvertOptions`
  User-facing options for mode, output format, OCR/audio, RAG, and resource limits
- `RoutePlan`
  A human-readable explanation of why the selected route was chosen
- `ConvertProvenance`
  The record of actual execution-time modes, profiles, features, providers, and strategy switches
- `ConvertResult`
  The unified public result object returned by the high-level API

## Maintenance Rules

- All route decisions should converge in `route_policy.mbt` and the probing modules, not be reimplemented inside CLI or format packages
- Provenance fields must stay explainable and regression-friendly; new strategy decisions usually need matching provenance fields
- New capabilities should extend the execution plan and canonical path instead of bypassing convert to call a parser directly
- Mode support is a route contract: unsupported `accurate`/`stream` requests
  fail before parse, while provider fallback may occur only inside an already
  supported route and must remain diagnostic/provenance-visible.

## Validation

```bash
moon build
moon test
```
