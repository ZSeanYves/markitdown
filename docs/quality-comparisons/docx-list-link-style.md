# Quality Comparison: docx-list-link-style

- format: DOCX
- sample path: `samples/main_process/docx/docx_list_links_linebreaks.docx`
- feature focus: list structure, inline hyperlink retention, line-break policy
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/docx_list_links_linebreaks.docx .tmp/quality-comparisons/docx_list_link_style_mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/docx_list_links_linebreaks.docx -o .tmp/quality-comparisons/docx_list_link_style_ms.md`
- comparable scope: default local DOCX conversion only; no metadata-sidecar comparison
- verdict: close

## Expected important structures

- document heading
- one unordered list item containing an external hyperlink
- one ordered list item containing an explicit line break

## markitdown-mb result summary

- keeps the heading and list structure
- keeps the external hyperlink inside the unordered list item
- keeps the ordered list item's explicit line break as `<br>`

## Microsoft MarkItDown result summary

- keeps the heading and list structure
- keeps the external hyperlink inside the unordered list item
- keeps the ordered list item as a wrapped continuation line rather than an
  explicit `<br>`

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | same main heading |
| Paragraph | yes | kept | kept | intro paragraph preserved |
| List | yes | kept | kept | bullet marker style differs |
| Link | yes | kept | kept | same external URL |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code block |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- no critical structure loss on either side

## Extra noise

- Microsoft MarkItDown inserts an extra blank line between the unordered and
  ordered list items

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- both tools keep the useful DOCX list/link shape on this sample
- the main difference is line-break policy inside the ordered list item

## Next action

- keep this as a DOCX list/link/style seed and pair it with richer nested-list
  and style-linked-heading evidence in the full DOCX sprint summary
