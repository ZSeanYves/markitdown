# Quality Comparison: pdf-table-like

- format: PDF
- sample path: `samples/main_process/pdf/pdf_simple_table_like.pdf`
- feature focus: simple table-like detection
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/pdf_simple_table_like.pdf .tmp/quality-comparisons/pdf-table-like/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/pdf_simple_table_like.pdf -o .tmp/quality-comparisons/pdf-table-like/ms.md`
- comparable scope: native text-oriented PDF only; no OCR/cloud/plugin path
- verdict: win

## Expected important structures

- one 3-column table

## markitdown-mb result summary

- lowers the aligned text into a Markdown table
- keeps the header row explicitly

## Microsoft MarkItDown result summary

- lowers the content into a visually padded table
- keeps the structure, but with weaker row/cell boundary clarity

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | no | n/a | n/a | table-only sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | kept | both emit a table, but `markitdown-mb` is cleaner on boundaries |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- none on the native `markitdown-mb` side

## Extra noise

- Microsoft MarkItDown keeps a more padded/spaced table representation

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a conservative text-grid recovery case, not a generic table-engine claim

## Next action

- keep PDF table work limited to high-confidence aligned text grids
