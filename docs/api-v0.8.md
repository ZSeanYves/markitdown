# Stable Library API 0.8

`ZSeanYves/markitdown/lib` is the only compatibility-stable library package in
the 0.8 line. The product supports Native on Linux x86_64 and macOS arm64;
Wasm/JavaScript product targets are retired under the
[Native plan](architecture/native-performance-plan.md). P2–P6 remain unfinished
acceptance gates. Host bindings are isolated below the façade. All other project
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
- façade-owned `OutputSink`, asynchronous `convert_to_sink`, and
  `ConversionSummary` without a body or chunk text.

`Input` has private fields. The interface does not expose parser registries,
format-reader records, IR, pipeline contexts, renderer types, async handles,
FFI values or external-runtime provider types. The reviewed surface is frozen
in the generated `lib/pkg.generated.mbti` interface and the migration record.

## Example

```mbt check
import {
  "ZSeanYves/markitdown/lib",
}

async test "stable library conversion" {
  let input = @lib.Input::from_text(
    "# Title\n\nBody\n",
    source_name="note.md",
  )
  let options = @lib.ConvertOptions::default()
    .with_mode(@lib.Balanced)
    .with_output_mode(@lib.Markdown)
  guard @lib.convert(input, options~) is Ok(output) else {
    fail("conversion failed")
  }
  assert_true(output.content.contains("Title"))
  assert_eq(output.detected_format, "markdown")
}
```

`convert` is asynchronous. Call it from an `async` function; MoonBit propagates
the asynchronous call directly and does not use an `await` keyword. The façade
owns parser scheduling and does not expose community futures or FFI handles.

## Sink delivery

`OutputSink::new(write, finish)` accepts asynchronous callbacks returning
`Result[Unit, String]`. `convert_to_sink(input, sink, options~)` waits for each
write before producing the next fragment, then calls `finish` once on success.
Read/write failures and cancellation stop delivery; failure does not call
`finish`. A callback failure maps to the existing `RenderFailed` error class.

Markdown, Debug and RAG use this boundary. The JSON collector and Sink share
the same fragment cursor. The summary retains metadata, diagnostics, assets,
source map and chunk count, and does not contain the rendered body. It is a
separate type from collected `Output`; existing `convert` calls retain their
return type and behavior. Consumers import only the façade for these types.

Path handles opened by a conversion belong to its input session and close on
success, error or cancellation. Reader callbacks remain caller-owned. This
ownership and output delivery work does not establish bounded memory for the
whole parse: IR, RAG chunks and metadata can still reside in memory. Aggregate
cache, work, output and temporary-storage budgets remain tracked P2 work.

Reader callbacks receive `(offset, length)` and return at most `length` bytes.
An empty result means end of input. Reader resource ownership stays with the
caller. Synchronous and asynchronous constructors adapt to one asynchronous
read protocol used by detection and parsers; there is no complete-input
materialization adapter before routing. Prefix and fixed-range reads fill
legal short reads. An empty result before a declared size, callback over-read,
I/O failure or exceeded byte ceiling terminates conversion. Subsequent reads
cannot clear the first hard input error. Invalid UTF16 in `Input::from_text`
returns a controlled error before Native UTF8 encoding can abort.

Selected tree formats still collect their required text. CSV/JSONL preserve
their established bounded multipass ordering; these protocol changes do not
claim that every format is a single-pass stream.

`ResourceLimits` and `RagOptions` are immutable. Start with `default()` and use
their `with_*` methods to set every supported field before attaching them to
`ConvertOptions`.

### Optional JSONL temporary storage

`ResourceLimits::with_max_temporary_bytes(Some(N))` opts JSONL/NDJSON into a
conversion-owned spool with a nonnegative Int64 capacity. The default is `None`,
which keeps the compatibility route. `Some(0)` permits empty stores but forbids
payload growth; it does not promise no filesystem activity. Negative values
return `InvalidOption` before any input or Sink callback. This ceiling is
independent of original input bytes and the existing per-asset/total-asset caps.

The normal successful spool path parses/inspects each admitted record once,
writes table and non-table event frames to two sequential files sharing the
same account, then replays the table before code records. Capacity counts actual
UTF8 values and the private frame headers. Multiple live stores and nested
documents share the effective ceiling; a larger child request cannot relax a
smaller parent allowance. Exceeding it returns
`ResourceLimitExceeded(kind="temporary_bytes", observed, limit)`, and does not
fall back to an in-memory route or call Sink.finish.

Collected conversion retains table source fields (including JSON pointers,
cell ranges and synthetic-header markers); the pull Sink keeps its established
line-based table refs. A filtered matching row now refers to its actual input
record ordinal and line, including when scalar or mismatching records precede
it. The body and table/code ordering are preserved.

This is a transitional opt-in, not complete P2 acceptance. Ordinary malformed
JSON grammar can still use the existing raw-text recovery, which may collect
the complete text even with Some(N). Consumed encoding, input, budget or cleanup
errors cannot take that recovery. The pull Sink keeps its existing row/line
limits and does not poll beyond the admitted record prefix. Collected conversion
keeps the old LF-split/record-BOM and blank-line diagnostics, and validates the
complete input even after its row projection stops; that remaining drain does
not parse or spool omitted records. Source Text/Bytes, final events/IR/RAG and metadata may still be
resident. The codec accounts its transient buffers and retains conservative
UTF16 payload credit for strings that may escape as events; this is not RSS.

The ceiling currently covers registered parser spool files. CLI atomic-output
temporary siblings are **not yet charged to it**; it is not a promise about all
temporary disk usage. Other consumers and finite production defaults remain
unfinished. Explicit finite caps also censor measurements; their effective
configuration must be recorded separately from unconstrained measurement-only
maxima. A finite effective temporary limit uses the `partial_v12` schema and
`measurement_with_temporary_limit` profile. The sidecar reports that actual
effective limit, shared-ledger lifetime temporary peak and current credit;
caller history may make the peak exceed a later tightened limit, and another
owner's live credit may make current nonzero. Older profile harnesses reject
this distinct profile.

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
moon info lib
moon check --target native --warn-list +73 --deny-warn
```

An intentional golden change is Risk R3 and requires an accepted RFC or ADR,
API diff, migration example, target-native tests, compatibility review and a
regeneration note in the PR. Golden and generated interface edits are never
made by hand.
