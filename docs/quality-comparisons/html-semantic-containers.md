# Quality Comparison: html-semantic-containers

- format: HTML
- sample path: `samples/main_process/html/html_semantic_containers.html`
- feature focus: semantic wrappers such as `main`, `section`, `article`, `aside`, `nav`
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/html/html_semantic_containers.html .tmp/quality-comparisons/html_semantic_containers/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/html/html_semantic_containers.html -o .tmp/quality-comparisons/html_semantic_containers/ms.md`
- comparable scope: default local HTML conversion only; semantic text recovery only
- verdict: close

## Expected important structures

- one heading
- one paragraph
- one aside-like note
- one nav-like paragraph

## markitdown-mb result summary

- keeps the heading and all body text in readable block order

## Microsoft MarkItDown result summary

- keeps the same heading and body text in the same effective order

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | equivalent |
| Paragraph | yes | kept | kept | equivalent |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- no meaningful structure loss on either side

## Extra noise

- none

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this overlap sample is already at good H2 quality on both sides

## Next action

- use this record to show that semantic-wrapper passthrough is stable, while richer provenance remains a sidecar concern
