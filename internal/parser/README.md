# Parser

> Internal 0.8 extension contract. Registry, context, capability and result
> records are not part of the stable library API.

`internal/parser/` defines the unified parser contract for the whole repository. Any format that wants to join the main product path must declare its capabilities, context, and result shape here before it can be exposed through the registry.

## Responsibilities

- Define parser modes, streaming granularity, and capability declarations
- Define the shared parse-stage `ParseContext`
- Define the unified `ParseResult`
- Use one `ParserRegistry` with asynchronous `Parser.parse` and optional
  `Parser.open_stream` callbacks. Pure scanning and semantic lowering helpers
  remain synchronous; they run inside the same parser protocol.
- Expose controlled pull streams for formats that can preserve canonical line
  or table semantics without materializing an event array

## Key Entry Points

- `types.mbt`
  `ParserMode`, `StreamingGranularity`, `ParserCapability`, `ParseResult`
- `capabilities.mbt`
  `make_parser_capability` and common capability templates
- `context.mbt`
  `new_parse_context`, `parse_context_with_product_modes`, `parse_context_with_limits`
- `registry.mbt`
  `registry_register`, `registry_parse`, `registry_open_event_stream`
- `constructors.mbt`
  `make_parser`, `parse_result_with_*`

## Key Types

- `ParserCapability`
  Declares whether a parser can stream, whether it needs random access, and which semantics or provenance it can preserve
- `ParseContext`
  Carries mode, fidelity, PDF policy, and resource limits
- `ParseResult`
  Carries exactly one of event stream, block stream, or `DocumentIR`, plus diagnostics, assets, metadata, and source map side channels
- `ParseEventStream`
  Offers asynchronous `next` and `finish`; each consumer awaits one operation
  before requesting the next event. `finish` supplies the final side channels.

Parser pull is an internal producer/consumer contract. It is not the same as
the product `stream` mode, and it is not the renderer's incremental sink. A
pull implementation must return an equivalent final parse summary, including
diagnostics, metadata, assets, source map, mode, and provenance inputs.

The asynchronous parser protocol does not yet imply asynchronous input I/O.
`AsyncReader` normalization still materializes the input before parsing; its
replacement with asynchronous source reads is a separate migration.

## Maintenance Rules

- Every new parser should declare capabilities first and then register through the registry; upper layers should not call concrete parsers directly
- `ParseResult` should expose only one primary IR shape so downstream code never has to guess which output is canonical
- New runtime policy, limits, or mode toggles should be added through `ParseContext` instead of being scattered across format packages

## Validation

```text
moon test --package ZSeanYves/markitdown/internal/parser --target native --no-parallelize
```
