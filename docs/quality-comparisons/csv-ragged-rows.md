# Quality Comparison: csv-ragged-rows

- format: CSV
- sample path: `samples/main_process/csv/csv_ragged_rows.csv`
- feature focus: ragged-row table retention
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/csv/csv_ragged_rows.csv .tmp/quality-comparisons/csv_ragged_rows/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/csv/csv_ragged_rows.csv -o .tmp/quality-comparisons/csv_ragged_rows/ms.md`
- comparable scope: default local CSV conversion only
- verdict: win

## Expected important structures

- a table with a ragged final row
- no silent truncation of the extra cell

## markitdown-mb result summary

- keeps the extra column explicitly and preserves `Extra` in the final row

## Microsoft MarkItDown result summary

- keeps a readable table for the common-width portion, but truncates the extra
  trailing cell by staying with the shorter header width

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | CSV table only |
| Paragraph | no | n/a | n/a | no paragraph |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | ragged width preservation differs |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the extra trailing cell in the second data row

## Extra noise

- none; the issue is omission, not noise

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- ragged-row policy matters for structured-data preservation; preserving the
  widest row is more useful for downstream ingestion than silent truncation

## Next action

- add a future CSV record for quoted-newline behavior
