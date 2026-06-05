# Quality Comparison: txt-literal-safe

- format: TXT
- sample path: `samples/main_process/txt/txt_plain.txt`
- feature focus: literal-safe plain text path
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/txt_plain.txt .tmp/quality-comparisons/txt_plain_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/txt/txt_plain.txt -o .tmp/quality-comparisons/txt_plain_compare/ms.md`
- comparable scope: default local TXT conversion only
- verdict: close

## Expected important structures

- literal text preserved
- no invented heading/list/table semantics

## markitdown-mb result summary

- preserves the literal plain-text line exactly

## Microsoft MarkItDown result summary

- preserves the literal plain-text line exactly

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | plain-text sample |
| Paragraph | yes | kept | kept | identical |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- none

## Extra noise

- none

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a stable overlap sample, not a differentiator

## Next action

- keep this as the baseline TXT overlap record
