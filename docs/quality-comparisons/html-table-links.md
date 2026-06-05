# Quality Comparison: html-table-links

- format: HTML
- sample path: `samples/main_process/html/html_table_ragged_links.html`
- feature focus: table retention, ragged-row handling, inline link preservation
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/html/html_table_ragged_links.html .tmp/quality-comparisons/html_table_ragged_links/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/html/html_table_ragged_links.html -o .tmp/quality-comparisons/html_table_ragged_links/ms.md`
- comparable scope: default local HTML conversion only; no JS/CSS/browser layout path
- verdict: win

## Expected important structures

- one Markdown table
- stable header row
- inline link inside a cell
- ragged trailing row should not collapse the column shape

## markitdown-mb result summary

- keeps the three-column table shape
- preserves the inline link in the `Docs` cell
- keeps the ragged final row as `Bob |  |`

## Microsoft MarkItDown result summary

- keeps the table and inline link
- drops the trailing empty cell in the ragged row, so the last row becomes shorter

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | no | n/a | n/a | no paragraph |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | ragged-row shape is cleaner in `markitdown-mb` |
| Link | yes | kept | kept | both keep the inline link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the final empty table cell in the ragged row

## Extra noise

- none

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a Markdown-table policy difference, not a browser-layout issue

## Next action

- keep using this sample as the checked-in HTML table-ragged overlap record
