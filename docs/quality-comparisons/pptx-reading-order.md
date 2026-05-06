# Quality Comparison: pptx-reading-order

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_grouped_shapes_boundary.pptx`
- feature focus: grouped shapes, reading order, heading promotion
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_grouped_shapes_boundary.pptx .tmp/quality-comparisons/pptx_grouped_shapes_boundary_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_grouped_shapes_boundary.pptx -o .tmp/quality-comparisons/pptx_grouped_shapes_boundary_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- slide boundary
- heading promoted from title-like grouped text
- grouped text items in stable reading order

## markitdown-mb result summary

- emits a slide boundary, a promoted heading, and the grouped body items in a
  readable top-to-bottom order

## Microsoft MarkItDown result summary

- keeps the grouped text, but flattens it into loose lines and leaves the
  title-like text at the end

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | partial | title-like text survives, but is not cleanly promoted |
| Paragraph | yes | kept | partial | loose lines instead of grouped reading flow |
| List | no | n/a | n/a | this sample is grouped plain text |
| Table | no | n/a | n/a | no explicit table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the heading/body grouping distinction

## Extra noise

- Microsoft MarkItDown keeps the content, but the order is harder to read as a
  slide outline

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the useful difference here is structural: grouped-title promotion and stable
  reading order matter more than visual box placement

## Next action

- keep the current conservative grouped-shape policy and avoid pretending to be
  a full layout engine
