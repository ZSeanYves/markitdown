# Quality Comparison: xlsx-multisheet-table

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_multi_sheet_mixed.xlsx`
- feature focus: multi-sheet separation, table retention, cached typed-cell rendering
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/xlsx/xlsx_multi_sheet_mixed.xlsx .tmp/quality-comparisons/xlsx_multi_sheet_mixed_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_multi_sheet_mixed.xlsx -o .tmp/quality-comparisons/xlsx_multi_sheet_mixed_compare/ms.md`
- comparable scope: default local XLSX conversion only
- verdict: win

## Expected important structures

- multiple sheet sections
- readable Markdown tables
- typed cell values preserved conservatively
- sparse sheet rendered without misleading phantom data

## markitdown-mb result summary

- keeps sheet sections as `##` headings
- preserves the main tables
- keeps `TRUE` / `FALSE` and `#DIV/0!`
- keeps the sparse middle column visibly empty rather than naming or filling it

## Microsoft MarkItDown result summary

- keeps sheet sections and main tables
- normalizes boolean values to `True` / `False`
- converts the error cell to `NaN`
- labels the empty sparse column `Unnamed: 1` and fills sparse gaps with `NaN`
  and float-like `1.0` / `2.0`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | sheet boundaries survive on both sides |
| Paragraph | no | n/a | n/a | workbook is table-oriented |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | Microsoft MarkItDown injects placeholder semantics |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the original error-like signal by rewriting
  `#DIV/0!` to `NaN`
- Microsoft MarkItDown weakens sparse-table readability with placeholder names
  and values

## Extra noise

- `Unnamed: 1`
- `NaN`
- decimalized integers in sparse rows

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the main difference is workbook/table policy quality, not a failure to open
  the file

## Next action

- add future records for merged cells and cached-formula behavior
