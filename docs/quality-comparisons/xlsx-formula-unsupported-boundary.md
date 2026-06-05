# Quality Comparison: xlsx-formula-unsupported-boundary

- format: XLSX
- sample path: `samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx`
- feature focus: unsupported-formula fail-closed behavior
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx .tmp/xlsx_formula_compare/mb_unsupported.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx -o .tmp/xlsx_formula_compare/ms_unsupported.md`
- comparable scope: default local XLSX conversion on formulas outside the checked-in evaluator v1 subset
- verdict: win

## Expected important structures

- stable table shape
- unsupported formulas must not panic
- unsupported formulas must not invent misleading computed values
- placeholder noise should be avoided where possible

## markitdown-mb result summary

- keeps the table shape
- leaves unsupported result cells blank
- does not pretend to support `VLOOKUP`, cross-sheet references, volatile functions, or array-like range arithmetic

## Microsoft MarkItDown result summary

- keeps the table shape
- rewrites every unsupported result to `NaN`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep sheet boundary |
| Paragraph | no | n/a | n/a | table-only sample |
| List | no | n/a | n/a | no list |
| Table | yes | kept | partial | Microsoft MarkItDown keeps the table but injects placeholder output |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no assets |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the conservative distinction between “unsupported” and “placeholder value”

## Extra noise

- `NaN`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- unsupported formulas are an explicit non-goal of evaluator v1
- the comparison is about degradation quality, not about broader Excel coverage

## Next action

- keep unsupported reasons visible in metadata sidecars and inspect/debug surfaces
