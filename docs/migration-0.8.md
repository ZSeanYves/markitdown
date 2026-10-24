# Migration to the Native 0.8 API

The current 0.8 candidate is unreleased. Its product targets are Linux x86_64
and macOS arm64 with the Native backend. The
[Native plan](architecture/native-performance-plan.md) supersedes the former
Wasm/MoonX delivery policy. P2–P6 are not accepted as complete.

## Target and installation

Select `preferred_target = "native"` in the consumer's `moon.mod`. Product
Wasm, Wasm-GC and JavaScript targets and their portable adapters are retired.
Use MoonBit `0.1.20261021` / `moonc v0.10.17+093cb8f9c` and the platform C
toolchain.

Install the CLI from local source with `moon install --path .`, or from a
full fixed Git revision. After publication, use
`moon install ZSeanYves/markitdown@0.8.0` for the exact registry version.
Replace product `moonx` invocations with the installed Native executable.
Standalone `.mbtx` validation scripts may still be launched through the
script runtime; they must execute actual Native product artifacts.

## Public boundary

Move conversion calls from implementation packages to
`ZSeanYves/markitdown/lib`. Keep the thin root `main.mbt`, public `lib`
and private `internal` split. Reader/parser records, IR, runtime adapters and
community models are not compatibility-stable consumer imports.

Before 0.8:

```mbt
let source = @input.input_from_path(path)
let options = @convert.default_convert_options()
let result = @convert.convert_input(source, options)
```

0.8:

```mbt
let source = @lib.Input::from_path(path)
let result = @lib.convert(source)
```

The conversion call is async: make the containing function `async` and call
it directly. MoonBit has no `await` keyword. Keep error handling on the
façade-owned `Result`.

`Input::from_text`, `from_bytes`, `from_reader` and `from_async_reader`
remain supported constructors. Caller-owned readers stay caller-owned.
Callbacks must not exceed the requested byte count or a declared source size.
All constructors now enter the same bounded asynchronous random-access
protocol. Detection no longer materializes an async Reader into bytes before
routing. Selected tree parsers may collect their required text, and CSV/JSONL
retain multipass semantics. Aggregate work/cache/output budgets and complete
bounded lifecycles remain P2 work; the protocol migration alone is not P2
acceptance.

Use public immutable option modifiers:

```mbt
let options = @lib.ConvertOptions::default()
  .with_mode(Stream)
  .with_output_mode(Rag)
  .with_format_hint(Some("markdown"))
  .with_limits(
    @lib.ResourceLimits::default()
      .with_max_input_bytes(64L * 1024L * 1024L),
  )
  .with_rag(
    @lib.RagOptions::default()
      .with_chunk_size(1200)
      .with_chunk_overlap(120),
  )
let result = @lib.convert(source, options~)
```

The async public `convert_to_sink` is available and returns a
`ConversionSummary`; its `OutputSink` callbacks are asynchronous. Complete
budget coverage and P2 acceptance remain pending. Use the generated
[public interface](../lib/pkg.generated.mbti) to determine available APIs.

An additive resource option is available as
`ResourceLimits::with_max_temporary_bytes(Some(N))`; pass None to keep the
compatibility route. N is nonnegative Int64 bytes; zero forbids spool payload
growth while still allowing an empty file to be created and cleaned. The normal
JSONL/NDJSON collect and Sink routes use two conversion-owned sequential files
with a shared aggregate ceiling. Their UTF8/frame bytes have their own unit and
do not reuse `max_input_bytes`. Temporary exhaustion remains a typed
`ResourceLimitExceeded(kind="temporary_bytes", observed, limit)` and cannot
silently switch to full-memory processing.

This option does not complete P2: ordinary malformed-grammar recovery may still
collect raw text, final IR/RAG/metadata can remain resident, and CLI atomic-output
temporary siblings are not covered by this parser-spool ceiling. Other consumers
and default finite policy need separate acceptance. A finite opt-in profile is
explicitly marked and cannot be mixed into unconstrained measurement maxima.

The accompanying collected JSONL source correction keeps filtered table rows
aligned with their real input record ordinal, pointer and physical line. Earlier
scalar or mismatching records no longer shift those references. Body text and
table-before-code ordering are unchanged; affected RAG/source identities require
their own review rather than a broad source-ref comparison exemption.

## Errors, output and modes

Match `@lib.ConvertError` and persist `error.code().stable_name()`.
`error.message()` is display text. Output contains rendered content,
metadata JSON, stable diagnostics, provenance, assets, source maps and RAG
chunks using façade-owned types.

`balance` remains default. `accurate` preserves its declared additional
Office/ODF/PDF semantics. `stream` preserves promised output meaning and is
rejected where unsupported. It does not authorize lower extraction quality.
OCR, audio transcription and scanned-page recognition remain outside scope.

MIME structural limits now fail closed through the existing public
`ResourceLimitExceeded` variant. A child at depth9 exceeds the unchanged
depth8 limit (`kind="mime_nesting_depth"`); a container's1025th nonempty child
exceeds the unchanged1024-part limit (`kind="mime_multipart_parts"`). Both
carry exact `observed` and `limit` values. Older successful raw-text fallback
with an error diagnostic is no longer returned for these limits. The CLI
uses resource-error exit5; failed collection produces no output or asset files.

CP932 uses host iconv. The unused `horideicom/encoding_sjis` dependency and
portable adapter are removed; missing/invalid encoding support fails closed.

## Internal JSON renderer error effects

This change does not alter the public façade signatures. Debug/RAG JSON now
retains present SourceRef page, bbox, byte and time fields; absent new fields
are omitted, while existing keys and nulls keep their previous representation.
Coordinates use the source format's local system. Serialization preserves
existing offsets and does not establish that every producer has calibrated
raw byte ranges.

Implementation-package callers of `Renderer.render` or `render_input` must
now propagate or handle `JsonEncodingError::NonFiniteSourceBBox(coordinate)`.
The lazy JSON cursor and collecting renderer share that typed error; the
public conversion boundary returns the existing `RenderFailed` error instead
of producing invalid JSON. Consumer code importing only
`ZSeanYves/markitdown/lib` continues to match the existing `ConvertError`.

A Sink is nontransactional: valid framing or earlier fragments may have been
written before a later SourceRef fails encoding. The invalid coordinate is
never written, and the failed conversion does not call `OutputSink.finish`.
Callers that need atomic persistence should manage their destination commit
after successful conversion.

## JSON/XML byte-range basis

JSON scalar locations now cover the original lexical token, including String
quotes and escape spelling, and count UTF8 bytes instead of decoded String or
UTF16 lengths. The large root-array path skips its leading BOM and counts
monotonically consumed lexical ranges. Malformed XML fallback locations count
UTF8 in their actual prepared text. Present corrected byte refs carry
`extra.byte_basis=normalized_decoded_utf8` and a `byte_normalization` marker.
These are zero-based, half-open positions in the declared parser view. They
are local to a nested entry and are not offsets in its outer ZIP or compressed
file. Decoding and BOM/line-ending normalization can change the coordinate view.
Existing JSON and XML entry paths have distinct normalization policies; they
are recorded rather than silently unified. Physical-byte mapping is unfinished.

Public signatures are unchanged. Existing corpus RAG IDs remain stable. A
separate `json_list_v1` RAG consumer now retains the large-array producer's
existing literal preview rows and complete contributing refs in bounded scalar
windows; it does not reconstruct content absent from those events. Its new
path has deterministic IDs, while the XML shared window keeps its old identity
projection. Small wrapper-list child refs and full provenance coverage remain
pending.

## Verification and rollback

`api_v0_8()` and its version bridge remain available. Review generated
interface differences instead of importing an internal replacement.
Validate a separate Native consumer with
[installation tooling](../tools/regression/README.md), then all affected
quality contracts. Local, fixed Git and exact registry lanes are distinct.

Keep the frozen previous source/binary and the previous verified package
version for rollback. Restoring a previous integration requires its matching
imports, target and package coordinate. Local test passes do not certify
performance, full RC or post-publication confirmation.
