# Quality Comparison: pdf-cross-page-merge

- format: PDF
- sample path: `samples/main_process/pdf/pdf_cross_page_should_merge_phase15.pdf`
- feature focus: cross-page paragraph merge
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/pdf_cross_page_should_merge_phase15.pdf .tmp/quality-comparisons/pdf-cross-page-merge/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/pdf_cross_page_should_merge_phase15.pdf -o .tmp/quality-comparisons/pdf-cross-page-merge/ms.md`
- comparable scope: native text-oriented PDF only; no OCR/cloud/plugin path
- verdict: win

## Expected important structures

- one section heading
- one merged paragraph that continues across the page break

## markitdown-mb result summary

- keeps the heading
- merges the broken paragraph back into a single semantic block

## Microsoft MarkItDown result summary

- keeps the heading
- preserves the paragraph, but leaves weaker page-break handling in the flow

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both keep the title |
| Paragraph | yes | kept | partial | `markitdown-mb` recovers the broken flow more cleanly |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- no major loss on the `markitdown-mb` side in this sample

## Extra noise

- Microsoft MarkItDown keeps a weaker page-break artifact in the recovered paragraph flow

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a page-flow / merge-confidence comparison, not a visual-layout claim

## Next action

- keep PDF work focused on native text-PDF merge heuristics
