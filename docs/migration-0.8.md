# Migration to the 0.8 API

## Who must migrate

Library consumers importing `convert`, `input`, `product`, `rag`, `core`,
`render`, `formats/*` or any implementation package directly must move product
conversion calls to `ZSeanYves/markitdown/api`. The old `parser/`, `pipeline/`
and `format_readers/` package roots were removed. Their implementations now
live under `internal/` for repository use and are not compatibility promises.

The package graph was reduced from 108 packages at audit time to 68. Standalone
reader test packages, benchmark helper packages, and closely coupled text
reader/lowering packages no longer exist as separately importable libraries.
The audit-time `pub(all)` count was reduced from 223 to 210, including a
reduction of constructible/mutable records from 32 to 22. Profile reports in
the consolidated TXT, Markdown, and JSON packages remain readable but can no
longer be constructed or mutated field-by-field by consumers.

The repository now stores every MoonBit package below `src/`. This is a
filesystem-only normalization for library consumers: the module source root is
configured as `src`, so package names such as `ZSeanYves/markitdown/api` and
`ZSeanYves/markitdown/formats/pdf` do not gain a `src` segment. Contributors
using filesystem filters should pass `src/<package>` or use `--package` with
the full logical package name.

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
  .with_limits(
    @api.ResourceLimits::default()
      .with_max_input_bytes(64L * 1024L * 1024L)
      .with_external_command_timeout_ms(30000),
  )
  .with_rag(
    @api.RagOptions::default()
      .with_chunk_size(1200)
      .with_chunk_overlap(120),
  )
let result = @api.convert(source, options~)
```

Reader callbacks must return no more than the requested byte count and must not
return bytes beyond a declared size. Violations now fail with a typed resource
or parse error instead of being accepted by a later format fallback.

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
