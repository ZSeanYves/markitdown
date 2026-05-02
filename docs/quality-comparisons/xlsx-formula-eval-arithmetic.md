# Quality Comparison: xlsx-formula-eval-arithmetic

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_formula_eval_arithmetic.xlsx`
- feature focus: lightweight evaluation of missing-cache arithmetic formulas
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/xlsx/xlsx_formula_eval_arithmetic.xlsx .tmp/xlsx_formula_compare/mb_arithmetic.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_formula_eval_arithmetic.xlsx -o .tmp/xlsx_formula_compare/ms_arithmetic.md`
- comparable scope: default local XLSX conversion with formula evaluation limited to the checked-in v1 subset
- verdict: win

## Expected important structures

- stable sheet heading
- readable four-column table
- missing-cache arithmetic results should be usable instead of placeholder noise
- no fake values outside the supported subset

## markitdown-mb result summary

- keeps the table shape
- evaluates `A2+B2`, `A3-B3`, `A4*B4`, `A5/B5`, and `(A6+B6)*2`
- emits readable numeric results: `3`, `2`, `24`, `5`, `20`

## Microsoft MarkItDown result summary

- keeps the table shape
- leaves every missing-cache arithmetic result as `NaN`
- escapes `*` in the expression column as Markdown text, but does not recover the value

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | table-only sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | Microsoft MarkItDown keeps the table but loses formula results |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses all computed values for the supported arithmetic subset

## Extra noise

- `NaN`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is not full Excel compatibility; it is a lightweight evaluator for a safe subset
- within that subset, `markitdown-mb` now keeps more useful workbook meaning on missing-cache inputs

## Next action

- keep the cached-value-first policy and benchmark the extra overhead on formula-heavy missing-cache workbooks
