# Product

`product/` holds the top-level product vocabulary shared by CLI, convert, parser, and other upper layers.

Main responsibilities:

- `FidelityMode`
- `OutputMode`
- `ExecutionProfile`
- `LoweringProfile`
- `RenderProfile`

Main files:

- `options.mbt`

Maintenance rules:

- new top-level modes, profiles, and formal product terms should be defined here first
- avoid having multiple names for the same product concept in different layers

Validation:

```bash
moon test
```
