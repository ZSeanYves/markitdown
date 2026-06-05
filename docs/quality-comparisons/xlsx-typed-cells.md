# Quality Comparison: xlsx-typed-cells

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx`
- feature focus: boolean, error, numeric, string, and inline-string cell rendering
- comparison date: 2026-05-05
- markitdown-mb command: `moon run cli -- normal samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx .tmp/xlsx_compare/mb/xlsx_typed_cells_matrix.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx -o .tmp/xlsx_compare/ms/xlsx_typed_cells_matrix.md`
- comparable scope: default local XLSX conversion only
- verdict: win

## Expected important structures

- readable table
- boolean values preserved as booleans
- error cell preserved as error-like signal
- string, inline-string, and numeric cells preserved conservatively

## markitdown-mb result summary

- keeps the table shape
- preserves `TRUE` / `FALSE`
- preserves `#DIV/0!`
- keeps string and inline-string cells readable

## Microsoft MarkItDown result summary

- keeps the table shape
- normalizes booleans to `True` / `False`
- rewrites the error cell to `NaN`
- keeps string, inline-string, and numeric cells readable

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | no paragraph content |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | table shape survives; error semantics differ |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the explicit error signal by rewriting `#DIV/0!`
  to `NaN`

## Extra noise

- `NaN`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the main difference is typed-cell policy, not workbook-opening ability

## Next action

- extend typed-cell records to date/time/datetime samples in a later XLSX sprint
