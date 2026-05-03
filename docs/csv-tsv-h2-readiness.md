# CSV / TSV H2 Readiness

This document records the H2 readiness audit and implementation pass for CSV
and TSV in `markitdown-mb`.

Scope:

* parser completeness for conservative delimited text
* Markdown table stability
* table metadata / origin behavior
* mainstream lightweight-tool expectations
* explicit non-goals and streaming boundary

This is not a promise of spreadsheet semantics. CSV / TSV remain conservative
plain-text table conversion paths.

## CSV Current Behavior

Current CSV behavior is now suitable for H2:

* UTF-8 BOM is removed
* CRLF / CR / LF inputs normalize to stable row parsing
* comma delimiter selection is extension-driven
* quoted delimiter, escaped quote, and quoted newline are supported
* trailing empty cells are preserved
* ragged rows are padded to stable rectangular output
* blank physical rows are skipped instead of emitting all-empty body rows
* malformed unterminated quoted fields fail closed
* Markdown output remains a single stable table
* metadata keeps `source_name`, physical line range, `row_index`, and
  `column_index`
* metadata now carries explicit `table.rows` and `table.header_rows`

## TSV Current Behavior

Current TSV behavior is now suitable for H2:

* UTF-8 BOM is removed
* CRLF / CR / LF inputs normalize to stable row parsing
* tab delimiter selection is extension-driven
* quoted tab, escaped quote, and quoted newline are supported through the
  shared delimited parser
* trailing empty cells are preserved
* ragged rows are padded to stable rectangular output
* blank physical rows are skipped instead of emitting all-empty body rows
* Markdown-sensitive cell content remains pipe-safe
* metadata keeps `source_name`, physical line range, `row_index`, and
  `column_index`
* metadata now carries explicit `table.rows` and `table.header_rows`

## Parser Edge-case Matrix

| Area | Current behavior | H2 expectation | Gap | Action |
| --- | --- | --- | --- | --- |
| UTF-8 BOM | Removed before parsing | Stable UTF-8 input path | Closed | keep |
| CRLF / CR / LF | All normalize to stable row boundaries | Cross-platform stability | Closed | keep |
| Quoted delimiter | Supported for CSV and TSV | RFC-4180-ish behavior where reasonable | Closed | keep |
| Escaped quote | `\"\"` becomes literal `\"` | Conservative quote recovery | Closed | keep |
| Quoted newline | Preserved inside one cell | Multiline-cell stability | Closed | keep |
| Empty quoted vs empty unquoted | Both render as empty text cells | Stable empty-cell semantics | Acceptable | document no type distinction |
| Trailing delimiter | Preserved as trailing empty cell | No silent column loss | Closed | tests added |
| Blank line | Skipped instead of becoming empty row | Stable table output | Closed | parser hardened |
| Ragged rows | Padded to max width | Deterministic rectangular Markdown | Closed | keep |
| Unterminated quote | Fail closed with parser error | Document malformed-input policy | Closed | tests added |
| TSV delimiter | Tab-only by extension | No sniffing ambiguity | Closed | keep |
| Mixed newline styles | Stable after normalization | Real exported file tolerance | Closed | keep |
| Large row / long cell | No special truncation | Literal-safe large row handling | Acceptable | H3/streaming future |

## Table Semantics / RichTable Decision

Decision: CSV and TSV should use `RichTable`.

Why:

* `core/ir.mbt` already supports `RichTable(TableData { rows, header_rows })`
* Markdown emitter already renders `RichTable` without changing CSV/TSV output
  shape
* metadata sidecar only emits sparse `blocks[].table` for `RichTable`
* H2 should preserve explicit header semantics where the format obviously has a
  first table row

Implementation status:

* implemented in this pass
* CSV / TSV now emit `RichTable({ rows, header_rows: 1 })`
* Markdown output remains the same first-row-header table style
* metadata snapshots now include explicit `table.rows` / `header_rows`

Backward-compatibility risk:

* low for Markdown output
* metadata becomes richer but stays within the existing schema

## Metadata / Origin Behavior

Current metadata/origin behavior:

* `format` remains `csv` / `tsv`
* `source_name` is preserved
* table blocks keep `line_start`, `line_end`, `row_index`, `column_index`
* sidecar `blocks[].table.rows` mirrors the rectangularized row matrix
* `header_rows` is explicitly `1`
* ZIP-contained CSV entries inherit the same richer table metadata

This is an H2 improvement in semantics without a schema expansion.

## Benchmark / Comparison Status

Current evidence:

* smoke benchmark small / medium / large exists for CSV and TSV
* batch profiling covers CSV and can generalize to TSV through the same parser
  path
* checked-in overlap comparison currently exists for CSV
* TSV is not yet a checked-in overlap format; practicality depends on upstream
  comparison support and comparable semantics

Current judgment:

* this is sufficient to mark CSV / TSV H2 complete
* additional real exported corpora remain useful, but are no longer blockers

## H2 Non-goals

CSV / TSV H2 does not include:

* Excel formula evaluation
* schema inference
* date / number / type inference
* delimiter sniffing beyond extension
* arbitrary encoding auto-detection
* spreadsheet layout semantics
* streaming parser implementation

Streaming and very-large-table memory behavior remain important, but belong to
post-H2 lower-layer / H3 follow-up rather than blocking current H2 quality.

## Decision

* CSV: H2 complete
* TSV: H2 complete

Reasoning:

* parser completeness is now robust for conservative delimited text
* Markdown table output is stable and literal-safe
* explicit table semantics now flow through metadata via `RichTable`
* malformed input policy is documented and fail-closed
* remaining work is largely streaming / large-scale behavior, not core H2
  output quality
