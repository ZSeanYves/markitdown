# Container Contracts

`container/` defines the shared contracts used when ZIP-like parents dispatch
supported child documents. It owns container policy and provenance vocabulary,
not ZIP decoding or format-specific lowering.

## Responsibilities

- Describe entry selection, recursion, dispatch, and asset ownership outcomes
- Keep child provenance anchored to normalized container paths
- Carry bounded container diagnostics into the root conversion result

## Boundaries

Raw ZIP access stays in `format_readers/zip`; product dispatch stays in the
relevant `formats/*` package and reuses the root registry/pipeline through
`runtime`. Nested archives, unsafe paths, duplicate output names, entry bombs,
and budget overruns fail closed. Child assets retain explicit `AssetPayload`
ownership and are materialized only at an approved output boundary.

## Validation

```bash
moon test container
moon test tests/container_integration_test.mbt
```
