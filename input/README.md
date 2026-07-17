# Input

`input/` describes external inputs and normalizes them into format identities the product understands. Its job is to answer “what is this input and how do I read it,” not “which high-level strategy should parse it.”

## Responsibilities

- Define path, text, byte, and caller-owned random-access reader inputs
- Handle explicit format hints, extensions, MIME types, magic bytes, and text heuristics
- Provide unified text and byte reading helpers

## Key Entry Points

- `input.mbt`
  `InputSource`, tagged `InputPayload`, `DetectedFormat`, `FormatDetectionResult`
- `input.mbt`
  `input_from_path`, `input_from_text`, `input_from_bytes`, `input_from_reader`
- `source_cursor.mbt`
  `SourceCursor`, `open_source_cursor`, bounded `source_cursor_read_at`
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

## Validation

```bash
moon test
```
