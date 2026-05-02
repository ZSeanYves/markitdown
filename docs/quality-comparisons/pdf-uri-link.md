# Quality Comparison: pdf-uri-link

- format: PDF
- sample path: `samples/main_process/pdf/pdf_uri_link_basic.pdf`
- feature focus: URI annotation link emission
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/pdf_uri_link_basic.pdf .tmp/quality-comparisons/pdf-uri-link/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/pdf_uri_link_basic.pdf -o .tmp/quality-comparisons/pdf-uri-link/ms.md`
- comparable scope: native text-oriented PDF only; no OCR/cloud/plugin path
- verdict: win

## Expected important structures

- a single visible Markdown link

## markitdown-mb result summary

- emits the URI annotation as a Markdown link

## Microsoft MarkItDown result summary

- keeps only plain paragraph text

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | yes | kept | kept | both keep the text |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | yes | kept | lost | `markitdown-mb` emits the annotation as a link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the URI link structure

## Extra noise

- none

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a high-confidence annotation-link case in the native text-PDF path

## Next action

- keep PDF link work conservative and annotation-driven
