# Pipeline

`pipeline/` continues transforming parser output into document structures that are ready for final rendering.

Main responsibilities:

- structural normalization
- reading-order organization and assembly
- render hints
- debug-related passes

Main files:

- `pipeline.mbt`: top-level execution entry
- `passes_*.mbt`: concrete transformation passes

Maintenance rules:

- new transformation logic should usually be introduced as a dedicated pass
- do not keep piling every rule into one large file
- passes should keep focused responsibilities so they remain maintainable and regression-testable

Validation:

```bash
moon test
```
