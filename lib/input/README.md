# Input

> Internal 0.8 source implementation. The stable constructors are
> `@lib.Input::from_path/text/bytes/reader`.

`input/` describes external inputs and normalizes them into format identities the product understands. Its job is to answer “what is this input and how do I read it,” not “which high-level strategy should parse it.”

## Responsibilities

- Define path, text, byte, and caller-owned random-access reader inputs
- Handle explicit format hints, extensions, MIME types, magic bytes, and text heuristics
- Provide unified text and byte reading helpers

## Key Entry Points

- `input.mbt`
  `InputSource`, tagged `InputPayload`, `DetectedFormat`, `FormatDetectionResult`
- `input.mbt`
  `input_from_path`, `input_from_text`, `input_from_bytes`, `input_from_reader`,
  `make_input_reader`, `make_async_input_reader`
- `source_cursor.mbt`
  `SourceCursor`, asynchronous `open_source_cursor`, bounded
  `source_cursor_read_at`, `source_cursor_read_exact_at`, `discover_source_size`
- `input.mbt`
  `detect_format`, `detected_format_name`, `parse_detected_format`
- `input.mbt`
  `read_input_text`, `read_input_bytes`

## Key Types

- `InputSource`
  A wrapper whose single payload is `Path`, `Text`, `Bytes`, or `Reader`;
  `origin_path` remains separate provenance and relative-asset metadata
- `SourceCursor`
  A bounded seekable view used by PDF and package readers without forcing a
  complete in-memory payload
- `FormatDetectionResult`
  A stable record of which signals were used during one format-detection decision

## Maintenance Rules

- Centralize aliases, extensions, and detection rules for new formats here first
- Detection should answer only format identity, not parser mode or fidelity strategy
- Keep `InputSource` field semantics stable because CLI, convert, and tests construct it directly
- A `Reader` callback is caller-owned and must obey range/EOF semantics;
  readers must not bypass the `SourceCursor` size ceiling
- All input kinds use one asynchronous random-access protocol. A synchronous
  Reader constructor only adapts its callback. Detection never converts an
  async Reader into a complete byte payload before selecting a parser.
- Prefix and exact-range reads accumulate legal short reads. An empty read
  before a declared size is an error. Unknown-size package readers locate EOF
  with bounded one-byte probes; an extra byte at the effective ceiling rejects
  oversized input instead of silently truncating it.
- Native Path content reads use `async/fs` workers. A small C acquisition guard
  rejects nonregular files without blocking on a FIFO and holds the original
  descriptor while the asynchronous file wrapper opens its descriptor path.
- A conversion owns one `InputSession`; nested helpers borrow it. Its `defer`
  closes Path handles on success, failure and cancellation. Low-level callers
  outside a session must explicitly close a cursor. Caller Reader resources
  remain caller-owned; ending a session closes only its adapter access.
- Tree formats may still collect the text needed by their selected parser.
  CSV and JSONL retain bounded multipass semantics. These are not claims that
  all formats perform single-pass streaming or satisfy aggregate cache/IR
  budgets; the remaining work is tracked in the upgrade progress report.

## Validation

```bash
moon test lib/input --target native
```
