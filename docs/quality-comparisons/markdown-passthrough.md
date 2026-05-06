# Quality Comparison: markdown-passthrough

- format: Markdown
- sample path: `samples/main_process/markdown/markdown_basic_heading_paragraph.md`
- feature focus: passthrough behavior
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/markdown/markdown_basic_heading_paragraph.md .tmp/quality-comparisons/markdown_basic_heading_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/markdown/markdown_basic_heading_paragraph.md -o .tmp/quality-comparisons/markdown_basic_heading_compare/ms.md`
- comparable scope: default local Markdown input only
- verdict: close

## Expected important structures

- existing heading preserved
- existing paragraph preserved
- no extra reinterpretation

## markitdown-mb result summary

- output matches the input structure directly

## Microsoft MarkItDown result summary

- output matches the input structure directly

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | identical on this sample |
| Paragraph | yes | kept | kept | identical on this sample |
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

- this sample confirms overlap behavior, not a differentiating quality edge

## Next action

- add a future Markdown record for frontmatter or raw-HTML passthrough policy
