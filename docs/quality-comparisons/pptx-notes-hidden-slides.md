# Quality Comparison: pptx-notes-hidden-slides

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_hidden_slides_policy.pptx`
- feature focus: hidden slide preservation policy
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_hidden_slides_policy.pptx .tmp/quality-comparisons/pptx_hidden_slides_policy_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_hidden_slides_policy.pptx -o .tmp/quality-comparisons/pptx_hidden_slides_policy_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- slide order
- hidden slide state is not silently lost

## markitdown-mb result summary

- keeps slide order and marks the hidden slide explicitly as `Slide 2 (hidden)`

## Microsoft MarkItDown result summary

- keeps slide order and content, but drops the hidden-slide state

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep slide headings |
| Paragraph | yes | kept | kept | body text survives |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the hidden-slide state

## Extra noise

- Microsoft MarkItDown uses HTML comment slide markers instead of the
  repository heading policy

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- hidden-slide state is part of the useful presentation structure for downstream
  review; preserving it is more important than matching PowerPoint visuals

## Next action

- keep hidden-slide output explicit and conservative
