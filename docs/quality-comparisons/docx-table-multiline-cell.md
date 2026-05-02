# Quality Comparison: docx-table-multiline-cell

- format: DOCX
- sample path: `samples/main_process/docx/docx_table_multiline_cell.docx`
- feature focus: table header retention and multiline cell lowering
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/docx_table_multiline_cell.docx .tmp/quality-comparisons/docx_table_multiline_cell_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/docx_table_multiline_cell.docx -o .tmp/quality-comparisons/docx_table_multiline_cell_compare/ms.md`
- comparable scope: default local DOCX conversion only
- verdict: win

## Expected important structures

- one table
- explicit header row
- one multiline cell

## markitdown-mb result summary

- keeps a standard Markdown header row and preserves the cell line break as
  `<br>`

## Microsoft MarkItDown result summary

- keeps the table content, but emits an empty header row and flattens the
  multiline cell into a single text run

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | table-only sample |
| Paragraph | no | n/a | n/a | no paragraph focus |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | header and cell-break fidelity differ |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the clean header-row contract
- Microsoft MarkItDown loses the explicit line break inside the first data cell

## Extra noise

- Microsoft MarkItDown introduces a blank header row plus bold-text header
  workaround

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- `markitdown-mb` is closer to the repository's table-lowering policy and the
  expected main-process output

## Next action

- keep this as a narrow DOCX table-quality seed
