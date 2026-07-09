# Parser

`parser/` defines the unified parser contract for the whole repository. Any format that wants to join the main product path must declare its capabilities, context, and result shape here before it can be exposed through the registry.

## Responsibilities

- Define parser modes, streaming granularity, and capability declarations
- Define the shared parse-stage `ParseContext`
- Define the unified `ParseResult`
- Provide synchronous and asynchronous registry registration and dispatch

## Key Entry Points

- `types.mbt`
  `ParserMode`, `StreamingGranularity`, `ParserCapability`, `ParseResult`
- `capabilities.mbt`
  `make_parser_capability` and common capability templates
- `context.mbt`
  `new_parse_context`, `parse_context_with_product_modes`, `parse_context_with_limits`
- `registry.mbt`
  `registry_register`, `registry_parse`, `async_registry_from_sync`
- `constructors.mbt`
  `make_parser`, `parse_result_with_*`

## Key Types

- `ParserCapability`
  Declares whether a parser can stream, whether it needs random access, and which semantics or provenance it can preserve
- `ParseContext`
  Carries mode, fidelity, OCR, audio, PDF policy, and resource limits
- `ParseResult`
  Carries exactly one of event stream, block stream, or `DocumentIR`, plus diagnostics, assets, metadata, and source map side channels

## Maintenance Rules

- Every new parser should declare capabilities first and then register through the registry; upper layers should not call concrete parsers directly
- `ParseResult` should expose only one primary IR shape so downstream code never has to guess which output is canonical
- New runtime policy, limits, or mode toggles should be added through `ParseContext` instead of being scattered across format packages

## Validation

```bash
moon build
moon test
```
