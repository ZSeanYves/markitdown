# Runtime

`runtime/` holds cross-format and cross-package runtime helpers that isolate platform differences and shared glue code.

Main responsibilities:

- common runtime helpers
- runtime glue that does not fit cleanly inside one format package

Main files:

- `runtime.mbt`

Maintenance rules:

- only truly cross-package, cross-format runtime helpers should live here
- format-private runtime logic should stay with the owning format whenever possible

Validation:

```bash
moon test
```
