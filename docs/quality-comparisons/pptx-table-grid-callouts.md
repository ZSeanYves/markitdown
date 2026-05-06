# Quality Comparison: pptx-table-grid-callouts

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_callout_blocks_basic.pptx`
- feature focus: callout/card grouping and reading order
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_callout_blocks_basic.pptx .tmp/quality-comparisons/pptx_callout_blocks_basic_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_callout_blocks_basic.pptx -o .tmp/quality-comparisons/pptx_callout_blocks_basic_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- slide heading
- paired callout title/body reading order
- readable conservative downgrade for card-like layout

## markitdown-mb result summary

- promotes the overall slide heading and keeps each callout pair in readable
  title-then-description order

## Microsoft MarkItDown result summary

- keeps the raw text but flattens the card structure into a noisier sequence

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | partial | heading text survives, but without the same conservative grouping |
| Paragraph | yes | kept | partial | card descriptions survive, but ordering is noisier |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | heuristic cards, not an explicit table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the title/body pairing signal of the callout cards

## Extra noise

- Microsoft MarkItDown presents a flatter text wall with weaker grouping cues

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a heuristic-layout record, not a visual-layout one: the important win
  is readable grouping, not geometric fidelity

## Next action

- keep heuristic card/callout grouping bounded and explicit
