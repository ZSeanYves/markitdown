# Quality Comparison: html-document-structure

- format: HTML
- sample path: `samples/main_process/html/html_simple.html`
- feature focus: heading, paragraphs, entity handling, list retention
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/html/html_simple.html .tmp/quality-comparisons/html_simple_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/html/html_simple.html -o .tmp/quality-comparisons/html_simple_compare/ms.md`
- comparable scope: default local HTML conversion only; no CSS/JS execution path
- verdict: close

## Expected important structures

- one top-level heading
- two paragraphs
- one list
- HTML entity decoding
- script/style ignored

## markitdown-mb result summary

- keeps heading, paragraphs, decoded entities, and Markdown list items

## Microsoft MarkItDown result summary

- keeps the same heading, paragraphs, decoded entities, and list items

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | equivalent |
| Paragraph | yes | kept | kept | equivalent |
| List | yes | kept | kept | bullet marker differs but semantics match |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code block |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- no meaningful structure loss on either side

## Extra noise

- none beyond bullet-marker style differences

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a good overlap sample where both tools are already at usable H2
  structure quality

## Next action

- add future HTML records for links, tables, unsafe-link boundaries, and local-image asset behavior
