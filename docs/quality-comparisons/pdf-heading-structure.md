# Quality Comparison: pdf-heading-structure

- format: PDF
- sample path: `samples/main_process/pdf/heading_basic.pdf`
- feature focus: heading retention, section separation, page-noise suppression
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/heading_basic.pdf .tmp/quality-comparisons/heading_basic_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/heading_basic.pdf -o .tmp/quality-comparisons/heading_basic_compare/ms.md`
- comparable scope: text-oriented PDF only; no OCR, cloud, or plugin path
- verdict: win

## Expected important structures

- chapter heading
- section heading
- body paragraphs
- no page-number/footer noise in the main content stream

## markitdown-mb result summary

- restores chapter and section headings as Markdown headings
- keeps the body paragraphs
- suppresses page-number residue from the main flow

## Microsoft MarkItDown result summary

- keeps the text content, but does not recover heading structure
- keeps page-number/footer residue in the output
- includes glyph-compatibility artifacts in some CJK text

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | lost | chapter and section headings are flattened on the Microsoft side |
| Paragraph | yes | kept | kept | both keep the narrative text |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses heading hierarchy

## Extra noise

- Microsoft MarkItDown leaves page-number/footer residue such as `1` and
  `第 2 ⻚`
- CJK text includes compatibility-glyph artifacts like `第⼀章`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this difference reflects lower-layer PDF text/block/heading signal quality
  more than emitter policy

## Next action

- keep PDF quality work focused on substrate signals before extra converter
  heuristics
