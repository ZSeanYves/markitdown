# Quality Comparison: txt-markdown-like-literal

- format: TXT
- sample path: `samples/main_process/txt/txt_markdown_like_literal.txt`
- feature focus: literal-safe text versus accidental Markdown reinterpretation
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/txt_markdown_like_literal.txt .tmp/quality-comparisons/txt_markdown_like_literal/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/txt/txt_markdown_like_literal.txt -o .tmp/quality-comparisons/txt_markdown_like_literal/ms.md`
- comparable scope: default local TXT conversion only
- verdict: loss

## Expected important structures

- preserve the file as literal plain text
- preserve line boundaries well enough for downstream inspection
- avoid reinterpreting plain text as structured Markdown

## markitdown-mb result summary

- escapes Markdown-sensitive characters and avoids semantic reinterpretation
- collapses the original multi-line text into a single line, which weakens
  plain-text readability

## Microsoft MarkItDown result summary

- preserves the original line boundaries
- does not escape the Markdown-looking content, so the rendered Markdown may be
  interpreted as headings, lists, code fences, and blockquotes instead of
  literal text

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | partial | Microsoft Markdown renderers may reinterpret plain text as heading |
| Paragraph | yes | partial | kept | line-structure preservation differs |
| List | no | n/a | partial | plain text may be reinterpreted as list syntax |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | partial | literal text may render as a link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | partial | fenced code markers may be reinterpreted |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- `markitdown-mb` loses line boundaries by flattening the sample into one line
- Microsoft MarkItDown loses literal-safe intent by keeping Markdown-significant
  syntax unescaped

## Extra noise

- Microsoft MarkItDown introduces implicit Markdown semantics

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this sample exposes a real TXT policy trade-off
- for plain-text ingestion, line preservation and literal safety are both
  valuable; today each tool keeps one side better than the other
- this record is scored `loss` because the current `markitdown-mb` output is
  less inspectable as plain text despite better escaping discipline

## Next action

- treat TXT line-preservation policy as a follow-up hardening topic
- do not solve it by making TXT auto-semantic; keep the literal-safe contract
