# Input

`input/` describes external inputs and normalizes them into format identities the product understands. Its job is to answer “what is this input and how do I read it,” not “which high-level strategy should parse it.”

## Responsibilities

- Define path, text, and byte input sources
- Handle explicit format hints, extensions, MIME types, magic bytes, and text heuristics
- Provide unified text and byte reading helpers

## Key Entry Points

- `input.mbt`
  `InputSource`, `DetectedFormat`, `FormatDetectionResult`
- `input.mbt`
  `input_from_path`, `input_from_text`, `input_from_bytes`
- `input.mbt`
  `detect_format`, `detected_format_name`, `parse_detected_format`
- `input.mbt`
  `read_input_text`, `read_input_bytes`

## Key Types

- `InputSource`
  A unified wrapper for path-backed, in-memory text, and in-memory byte inputs
- `FormatDetectionResult`
  A stable record of which signals were used during one format-detection decision

## Maintenance Rules

- Centralize aliases, extensions, and detection rules for new formats here first
- Detection should answer only format identity, not parser mode or fidelity strategy
- Keep `InputSource` field semantics stable because CLI, convert, and tests construct it directly

## Validation

```bash
moon test
```
