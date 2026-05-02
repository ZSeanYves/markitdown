# Quality Comparison: xlsx-merged-cells-policy

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx`
- feature focus: top-left merged-cell ownership without misleading covered-cell duplication
- comparison date: 2026-05-05
- markitdown-mb command: `moon run cli -- normal samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx .tmp/xlsx_compare/mb/xlsx_merged_cells_policy.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx -o .tmp/xlsx_compare/ms/xlsx_merged_cells_policy.md`
- comparable scope: default local XLSX conversion without visual merged-cell reconstruction
- verdict: win

## Expected important structures

- readable table columns
- top-left merged ownership
- covered cells should stay empty instead of gaining fake values

## markitdown-mb result summary

- keeps the table aligned
- leaves covered merged cells blank
- preserves the explanatory notes column without injecting placeholder values

## Microsoft MarkItDown result summary

- keeps the overall row/column structure
- fills covered merged cells with `NaN`
- decimalizes the normal numeric row as `42.0`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | table-only sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | Microsoft MarkItDown injects placeholder values into covered cells |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the conservative “covered cells are empty”
  interpretation by inserting `NaN`

## Extra noise

- `NaN`
- `42.0`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- neither tool attempts visual merged-cell reconstruction; the difference is
  whether covered cells remain blank or turn into misleading placeholders

## Next action

- keep merged range refs visible in metadata sidecar and inspect output
