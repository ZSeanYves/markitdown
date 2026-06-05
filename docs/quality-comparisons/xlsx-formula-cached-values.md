# Quality Comparison: xlsx-formula-cached-values

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_formula_cached_values.xlsx`
- feature focus: cached formula values, cached-first policy, and missing-cache evaluation fallback
- comparison date: 2026-05-05
- markitdown-mb command: `moon run cli -- normal samples/main_process/xlsx/xlsx_formula_cached_values.xlsx .tmp/xlsx_compare/mb/xlsx_formula_cached_values.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_formula_cached_values.xlsx -o .tmp/xlsx_compare/ms/xlsx_formula_cached_values.md`
- comparable scope: default local XLSX conversion with cached-first policy and lightweight missing-cache evaluation v1
- verdict: win

## Expected important structures

- readable sheet heading
- stable two-column table
- cached numeric/string/boolean/error values
- missing cached formula should not invent a fake value

## markitdown-mb result summary

- keeps all rows in a clean table
- preserves cached string and boolean results
- preserves cached error text as `#DIV/0!`
- uses the cached result when available
- evaluates the missing-cache arithmetic row to `5` on the local safe subset

## Microsoft MarkItDown result summary

- keeps the same overall table shape
- preserves cached numeric and string values
- normalizes boolean to `True`
- rewrites cached error and missing-cache cells to `NaN`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | table-oriented sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | kept | table shape survives on both sides |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the distinction between cached error text and a
  generic missing/invalid placeholder
- Microsoft MarkItDown loses the missing-cache arithmetic result entirely

## Extra noise

- `NaN`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- both tools open the workbook, but only `markitdown-mb` now recovers the
  missing-cache row inside the checked-in evaluator-v1 subset while still
  preferring cached workbook values when they exist

## Next action

- keep formula text visible in metadata/debug and benchmark the formula-eval
  overhead on missing-cache-heavy workbooks
