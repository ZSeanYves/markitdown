# Quality Comparison: html-unsafe-link-boundary

- format: HTML
- sample path: `samples/main_process/html/html_link_unsafe_javascript.html`
- feature focus: unsafe-link fail-closed boundary for `javascript:`, `vbscript:`, `data:`, and empty href
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/html/html_link_unsafe_javascript.html .tmp/quality-comparisons/html_link_unsafe_javascript/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/html/html_link_unsafe_javascript.html -o .tmp/quality-comparisons/html_link_unsafe_javascript/ms.md`
- comparable scope: default local HTML conversion only; no browser execution path
- verdict: close

## Expected important structures

- four visible text lines
- no dangerous Markdown links emitted from unsafe href schemes
- stable degradation for empty href

## markitdown-mb result summary

- emits plain text lines only
- does not emit dangerous Markdown links

## Microsoft MarkItDown result summary

- also emits plain text lines only
- does not emit dangerous Markdown links in this overlap sample

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | yes | kept | kept | equivalent visible text |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | yes | partial | partial | both deliberately degrade unsafe links to text |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- hyperlink targets are intentionally dropped on both sides

## Extra noise

- none

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a security boundary record; dropping dangerous href schemes is the correct conservative behavior

## Next action

- keep this sample as the checked-in unsafe-link boundary record and do not reframe it as a browser feature gap
