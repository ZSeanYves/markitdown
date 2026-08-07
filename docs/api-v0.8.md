# Stable Library API 0.8

`ZSeanYves/markitdown/api` is the only compatibility-stable library package in
the 0.8 line. It is native-only and supports macOS and Linux. All other project
packages are implementation or extension packages and may change without a
deprecation period before 1.0.

## Contract

The façade exposes only implementation-neutral models:

- `Input` with Path, Text, Bytes and Reader constructors;
- `ConvertOptions`, `ResourceLimits`, `RagOptions`, conversion/OCR/output modes;
- `Output`, `Asset`, `SourceMap`, `Chunk`, `Diagnostic`, `Provenance` and
  `Capability`;
- typed `ConvertError`, stable `ErrorCode` strings and process exit mappings;
- `convert`, `api_v0_8` and the explicit `ApiV0_8` version handle.

`Input` has private fields. The interface does not expose parser registries,
format-reader records, IR, pipeline contexts, renderer types, async handles,
FFI values or external-runtime provider types. The reviewed surface is frozen
in `tools/governance/api-v0.8.mbti`.

## Example

```mbt check
test {
  let input = @api.Input::from_text(
    "# Title\n\nBody\n",
    source_name="note.md",
  )
  let options = @api.ConvertOptions::default()
    .with_mode(Accurate)
    .with_output_mode(Markdown)
  guard @api.convert(input, options~) is Ok(output) else {
    fail("conversion failed")
  }
  assert_true(output.content.contains("Title"))
  assert_eq(output.detected_format, "markdown")
}
```

Reader callbacks receive `(offset, length)` and return at most `length` bytes.
An empty result means end of input. Reader resource ownership stays with the
caller. The adapter rejects oversized chunks, reads beyond a declared size and
data beyond `ResourceLimits.max_input_bytes`.

`ResourceLimits` and `RagOptions` are immutable. Start with `default()` and use
their `with_*` methods to set every supported field before attaching them to
`ConvertOptions`.

## Errors and CLI exits

| API error | Stable code | CLI exit |
| --- | --- | ---: |
| invalid option or CLI usage | `MID-0002` | 2 |
| detection/input failure | `MID-1001` | 3 |
| parse/conversion failure | `MID-2001` | 4 |
| resource limit | `MID-4001` | 5 |
| render/write failure | `MID-3001` | 6 |

The human message can change to improve diagnostics. The code and exit class
are the machine contract. Callers must not parse message text.

## Capability and extension policy

`capabilities()` reports every accepted format with supported input kinds,
conversion modes, output modes and external requirements. Image OCR and audio
formats are `ExternalRuntime`; their provider and process types remain outside
the stable API. Core conversion performs no network access. A future network or
cloud implementation must be a separate opt-in extension and cannot become a
transitive requirement of this package.

## Changing the surface

Run:

```bash
moon info api
python3 tools/governance/check_architecture.py
```

An intentional golden change is Risk R3 and requires an accepted RFC or ADR,
API diff, migration example, target-native tests, compatibility review and a
regeneration note in the PR. Golden and generated interface edits are never
made by hand.
