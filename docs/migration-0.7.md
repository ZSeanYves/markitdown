# 0.7 local development migration

The 0.7 line is an unreleased local development line. No remote release or
artifact is produced by this repository.

## Request and limits

`product` owns `ConvertMode`, `OutputMode`, `ResourceLimits`, and the default
resource ceilings. The convert package re-exports compatibility type aliases,
but no longer defines a second strategy enum or resource-limit constructor.
`ConvertOptions` now stores the requested mode and output mode; fidelity and
stream intent are derived internally from the mode before route planning.

New sink callers can use `convert_input_to_sink(source, options, sink)` with
`make_output_sink(write, finish)`. The existing `convert_input` remains the
buffered convenience wrapper. Sink write or finish failures return a structured
`RenderFailed` error and do not call `finish` after a failed write.

## Compatibility notes

- `convert.ConvertMode` is an alias of `product.ConvertMode`.
- `convert.OutputFormat` is an alias of `product.OutputMode`; use `Markdown`,
  `Debug`, or `Rag` in new code.
- `convert.make_resource_limits` was removed; use
  `product.make_resource_limits`.
- `convert.ConvertOptions.fidelity_mode` and `stream_requested` are derived
  fields and are no longer part of the request record.

This document describes the local 0.7 checkpoint and is not a promise of
0.5.x source compatibility.
