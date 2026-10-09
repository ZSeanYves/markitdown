# Stable Library API 0.8

`ZSeanYves/markitdown/lib` is the only compatibility-stable library package in
the 0.8 line. Its text contract builds on Native and linear Wasm. Native-only
extensions are isolated below the façade. All other project
packages are implementation or extension packages and may change without a
deprecation period before 1.0.

## Contract

The façade exposes only implementation-neutral models:

- `Input` with Path, Text, Bytes, synchronous Reader and asynchronous Reader
  constructors;
- `ConvertOptions`, `ResourceLimits`, `RagOptions`, conversion/output modes;
- `Output`, `Asset`, `SourceMap`, `Chunk`, `Diagnostic`, `Provenance` and
  `Capability`;
- typed `ConvertError`, stable `ErrorCode` strings and process exit mappings;
- asynchronous `convert`, `api_v0_8` and the explicit `ApiV0_8` version handle.

`Input` has private fields. The interface does not expose parser registries,
format-reader records, IR, pipeline contexts, renderer types, async handles,
FFI values or external-runtime provider types. The reviewed surface is frozen
in the generated `lib/pkg.generated.mbti` interface and the migration record.

## Example

```mbt check
test {
  let input = @lib.Input::from_text(
    "# Title\n\nBody\n",
    source_name="note.md",
  )
  let options = @lib.ConvertOptions::default()
    .with_mode(Accurate)
    .with_output_mode(Markdown)
  guard @lib.convert(input, options~) is Ok(output) else {
    fail("conversion failed")
  }
  assert_true(output.content.contains("Title"))
  assert_eq(output.detected_format, "markdown")
}
```

`convert` is asynchronous. Call it from an async entrypoint and await the
result; the façade owns parser scheduling and does not expose community futures
or FFI handles.

Reader callbacks receive `(offset, length)` and return at most `length` bytes.
An empty result means end of input. Reader resource ownership stays with the
caller. `Input::from_async_reader` is the asynchronous resource boundary; the
current shared parser chain materializes that reader once under
`ResourceLimits.max_input_bytes` before entering the same detection, routing
and semantic pipeline. The adapter rejects oversized chunks, reads beyond a
declared size and data beyond the input budget.

`ResourceLimits` and `RagOptions` are immutable. Start with `default()` and use
their `with_*` methods to set every supported field before attaching them to
`ConvertOptions`.

## Errors and CLI exits

| API error | Stable code | CLI exit |
| --- | --- | ---: |
| invalid option or CLI usage | `MID-0002` | 2 |
| detection/input failure | `MID-1001` | 3 |
| unsupported capability | `MID-1002` | 3 |
| parse/conversion failure | `MID-2001` | 4 |
| resource limit | `MID-4001` | 5 |
| render/write failure | `MID-3001` | 6 |

The human message can change to improve diagnostics. The code and exit class
are the machine contract. Callers must not parse message text.

## Capability and extension policy

`capabilities()` reports every accepted format with supported input kinds,
conversion modes, output modes and external requirements. Image and audio
inputs are explicitly `Unsupported` in the text-only core and produce the
typed `UnsupportedCapability` error. Core conversion performs no network or
Python runtime access. A future recognition or cloud implementation must be a
separate opt-in extension and cannot become a transitive requirement of this
package.

## Changing the surface

Run:

```text
moon info --package ZSeanYves/markitdown/lib
moon check --target all --warn-list +73 --deny-warn
```

An intentional golden change is Risk R3 and requires an accepted RFC or ADR,
API diff, migration example, target-native tests, compatibility review and a
regeneration note in the PR. Golden and generated interface edits are never
made by hand.
