# Product

`product/` holds the top-level product vocabulary. It defines the shared modes, profiles, features, and resource ceilings consumed together by CLI, convert, parser, pipeline, and render.

## Responsibilities

- Define product-level convert, fidelity, and output modes
- Define execution, lowering, and render profiles
- Define accurate-feature switches and default mappings
- Define shared resource limits and product defaults

## Key Entry Points

- `options.mbt`
  `ConvertMode`, `FidelityMode`, `OutputMode`
- `options.mbt`
  `ExecutionProfile`, `LoweringProfile`, `RenderProfile`
- `options.mbt`
  `AccurateFeature`, `AccurateFeatureProfile`
- `options.mbt`
  `ResourceLimits`, `ProductOptions`
- `options.mbt`
  `default_product_options`, `make_product_options`

## Key Types

- `AccurateFeatureProfile`
  The fine-grained enhancement set enabled per format in accurate mode
- `ResourceLimits`
  Shared ceilings used by probing, parsing, and lowering
- `ProductOptions`
  The standard carrier for top-level product defaults and strategy combinations

## Maintenance Rules

- Each product concept should have one formal name here
- Any new mode or profile should be evaluated across CLI, route planning, render, and provenance together
- Keep resource-limit definitions aligned across layers instead of letting convert, parser, and format packages invent separate ceilings

## Validation

```bash
moon test
```
