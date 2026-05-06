# Quality Comparison: xlsx-formula-eval-ranges

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx`
- feature focus: range aggregates on missing-cache formulas
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx .tmp/xlsx_formula_compare/mb_ranges.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx -o .tmp/xlsx_formula_compare/ms_ranges.md`
- comparable scope: default local XLSX conversion with formula evaluation limited to checked-in aggregate functions
- verdict: win

## Expected important structures

- input values should remain readable
- aggregate formulas should produce useful results for `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`, and `COUNTA`
- missing-cache formulas should not collapse into placeholder noise

## markitdown-mb result summary

- keeps the source values readable
- evaluates all six aggregate formulas correctly
- leaves non-expression cells blank rather than inventing placeholders

## Microsoft MarkItDown result summary

- preserves the sheet section and table shape
- rewrites blank value/expression cells to `NaN`
- leaves every aggregate result as `NaN`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | table-only sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | Microsoft MarkItDown keeps table shape but loses aggregate meaning |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the aggregate outputs for the checked-in supported range subset

## Extra noise

- `NaN`
- decimalized source values like `1.0`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- `markitdown-mb` is not reconstructing Excel semantics in general
- it is recovering a bounded set of common aggregate formulas that remain local, deterministic, and cheap

## Next action

- add follow-up records for mixed-type ranges and larger missing-cache formula sheets after performance runs
