# Migration to the 0.8 API

## Who must migrate

Library consumers importing `convert`, `input`, `parser`, `product`, `rag`,
`core`, `pipeline`, `render`, `formats/*` or `format_readers/*` directly must
move product conversion calls to `ZSeanYves/markitdown/api`. Those packages
remain available temporarily for repository internals, but they are not 0.8
compatibility promises.

## Conversion entrypoint

Before 0.8:

```mbt
let source = @input.input_from_path(path)
let options = @convert.default_convert_options()
let result = @convert.convert_input(source, options)
```

0.8:

```mbt
let source = @api.Input::from_path(path)
let result = @api.convert(source)
```

Use `Input::from_text`, `Input::from_bytes` and `Input::from_reader` for the
other stable input forms. Use immutable option modifiers instead of
constructing internal records:

```mbt
let options = @api.ConvertOptions::default()
  .with_mode(Stream)
  .with_output_mode(Rag)
  .with_format_hint(Some("markdown"))
let result = @api.convert(source, options~)
```

## Error handling

Before 0.8, callers commonly formatted `@convert.ConvertError` or propagated
plain strings. Match `@api.ConvertError` instead and persist
`error.code().stable_name()`. The text from `error.message()` is display-only.

## Result models

Internal `DocumentIR`, parser diagnostics and provider types no longer cross
the stable boundary. `Output` provides rendered content, format/mode,
deterministic metadata JSON, stable diagnostics, projected provenance, assets,
source maps and RAG chunks using façade-owned records. Code that edits internal
IR must remain an internal package or be proposed as a separately versioned
extension API.

## Version bridge and rollback

`api_v0_8()` returns an explicit `ApiV0_8` handle. Its `v1_migration()` method
states the target version and reminds callers that breaking changes remain
allowed before 1.0. Rollback consists of pinning the previous 0.7 module and
restoring legacy imports; no persisted output format migration is required.
