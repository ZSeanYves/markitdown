# Quality Comparison: pptx-title-bullets

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_title_bullets.pptx`
- feature focus: slide order, title/body split, bullet-list retention
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_title_bullets.pptx .tmp/quality-comparisons/pptx_title_bullets_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_title_bullets.pptx -o .tmp/quality-comparisons/pptx_title_bullets_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- one slide
- slide marker or equivalent slide boundary
- slide title
- bullet list
- body paragraph

## markitdown-mb result summary

- emits a clear slide boundary, a slide title, Markdown bullet items, and the
  trailing body paragraph

## Microsoft MarkItDown result summary

- emits a slide comment marker and the slide title, but flattens bullets into
  plain lines

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep title-like structure |
| Paragraph | yes | kept | kept | body sentence survives |
| List | yes | kept | lost | Microsoft MarkItDown flattens list semantics |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link in this sample |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses bullet-list structure

## Extra noise

- Microsoft MarkItDown adds an HTML comment slide-number marker instead of the
  repository's heading-based slide framing

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the key quality difference is structural, not cosmetic: list semantics matter
  for chunking and downstream outline use

## Next action

- add a future PPTX record for shape-level hyperlinks or explicit tables
