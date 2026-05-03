# JSON H2 Readiness

This document records the H2 readiness audit and implementation pass for JSON
in `markitdown-mb`.

Scope:

* standard JSON parser completeness
* deterministic conservative lowering
* RichTable / metadata semantics
* unicode escape and number grammar policy
* malformed fail-closed behavior
* explicit non-goals and large/nested boundary

This is not a schema inference or JSON Lines feature pass.

## JSON Current Behavior

Current JSON behavior is now suitable for H2:

* UTF-8 BOM is removed
* CRLF / CR / LF whitespace normalizes cleanly
* standard escapes are decoded:
  * `\"`
  * `\\`
  * `\/`
  * `\b`
  * `\f`
  * `\n`
  * `\r`
  * `\t`
  * valid `\uXXXX`
* valid surrogate pairs are decoded
* invalid unicode escapes and lone surrogates fail closed
* number grammar accepts standard JSON integer / fraction / exponent forms
* invalid leading zero / bad fraction / bad exponent forms fail closed
* root object lowers to a `Key | Value` RichTable
* scalar root lowers to a paragraph
* scalar array lowers to list items
* uniform array-of-objects lowers to RichTable
* mixed or non-tabular array/object structures keep conservative compact JSON
  value rendering or full fenced fallback
* metadata keeps `format = json`, `source_name`, root `key_path = "$"`, and
  sparse RichTable metadata

## Parser Completeness Matrix

| Area | Current behavior | H2 expectation | Gap | Action |
| --- | --- | --- | --- | --- |
| UTF-8 BOM | Removed before parsing | Stable UTF-8 path | Closed | keep |
| CRLF / CR / LF | Normalized as JSON whitespace | Cross-platform stability | Closed | keep |
| Standard string escapes | Decoded | Standard parser behavior | Closed | keep |
| `\uXXXX` BMP escapes | Decoded to Unicode text | Better fidelity for non-ASCII JSON | Closed | implemented |
| Surrogate pair | Decoded when valid pair | Standard emoji/non-BMP handling | Closed | implemented |
| Invalid unicode escape | Fail closed | Parser correctness | Closed | tests added |
| Lone surrogate | Fail closed | Parser correctness | Closed | tests added |
| Number grammar | integer / negative / decimal / exponent supported | Standard JSON number coverage | Closed | hardened |
| Invalid leading zero | Rejected | Standard JSON correctness | Closed | implemented |
| Bool / null | Supported | Primitive completeness | Closed | keep |
| Empty object / array | Supported | Stable empty-value behavior | Closed | keep |
| Trailing comma | Fail closed | Strict JSON only | Closed | tests added |
| Unclosed string | Fail closed | Strict malformed handling | Closed | tests added |
| Raw control char in string | Fail closed | Strict JSON correctness | Closed | implemented |
| Duplicate key | Preserved in source order | Stable parser policy | Acceptable | document current policy |
| Deep/nested object | Conservatively lowered | No lossy flattening | Closed | keep |
| Large array of objects | Stable RichTable or fallback | H2 quality, not streaming | Acceptable | H3/streaming future |

## Unicode Escape Policy

Decision: decode valid unicode escapes.

Implemented policy:

* valid `\uXXXX` escapes decode to the corresponding Unicode character
* valid surrogate pairs decode to non-BMP characters
* malformed hex escapes fail closed
* lone high / lone low surrogates fail closed

Why this is the right H2 boundary:

* closer to standard JSON parser behavior
* materially improves Markdown fidelity for non-ASCII content
* still keeps parser correctness strict rather than heuristically repairing bad
  input

## Number Grammar Policy

Implemented policy:

Accepted:

* `0`
* `-1`
* `12`
* `3.14`
* `-0.5`
* `1e10`
* `-2.5E-3`

Rejected:

* `01`
* `1.`
* `.5`
* `1e`
* `NaN`
* `Infinity`

This matches conservative standard-JSON expectations and is suitable for H2.

## Structured Lowering / RichTable Decision

Current lowering policy is suitable for H2:

* object root -> RichTable with `["Key", "Value"]`
* scalar root -> paragraph
* scalar array -> list
* uniform object array -> RichTable with `header_rows = 1`
* column order follows the first object key order
* later objects may reorder keys and still stay table-compatible if the key set
  matches exactly
* missing/extra keys fall back instead of inventing misleading blanks
* mixed arrays fall back to compact fenced JSON

Nested values inside an otherwise uniform object array:

* current policy keeps the array as RichTable when the object key set is stable
* nested object/array cell values are rendered as compact JSON strings
* this is conservative and non-lossy enough for H2, and avoids flattening

This means JSON H2 favors:

* explicit tabular lowering where the outer shape is clearly tabular
* compact literal preservation for nested cell values
* fenced fallback for non-tabular or irregular shapes

## Metadata / Origin Behavior

Current metadata/origin behavior:

* `format = json`
* `source_name` is preserved
* root-origin `key_path = "$"` is preserved
* no false per-line or per-cell origin is invented
* RichTable blocks emit sparse `blocks[].table.rows` and `header_rows`
* nested fallback remains one conservative block with root `key_path`

This is an H2-complete metadata boundary without schema change.

## Benchmark / Comparison Status

Current evidence:

* smoke benchmark small / medium / large exists
* batch profiling can exercise JSON through the existing structured-data path
* ZIP entry dispatch already covers JSON
* no checked-in overlap comparison row is currently required for H2 completion

Current judgment:

* parser completeness and output determinism are now strong enough for H2
* broader comparison corpus can remain follow-up work rather than blocker

## H2 Non-goals

JSON H2 does not include:

* JSON Lines
* schema inference
* arbitrary nested flattening
* semantic type inference beyond primitive rendering
* relaxed JSON comments / trailing comma support
* non-UTF encoding detection
* streaming parser implementation

Large/nested profiling and streaming remain valuable later work, but they are
not blockers for current H2 output quality.

## Decision

* JSON: H2 complete

Reasoning:

* parser completeness is now strong for standard JSON
* unicode and number grammar behavior are materially closer to standard parser
  expectations
* lowering is deterministic, conservative, and non-lossy
* RichTable and metadata semantics are already in place
* malformed input remains strict fail-closed
