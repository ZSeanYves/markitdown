# Quality Comparison: pdf-image-caption

- format: PDF
- sample path: `samples/main_process/pdf/pdf_image_caption_like.pdf`
- feature focus: image asset export and nearby caption pairing
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/pdf_image_caption_like.pdf .tmp/quality-comparisons/pdf-image-caption/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/pdf_image_caption_like.pdf -o .tmp/quality-comparisons/pdf-image-caption/ms.md`
- comparable scope: native text-oriented PDF only; no OCR/cloud/plugin path
- verdict: win

## Expected important structures

- local image asset
- nearby caption text

## markitdown-mb result summary

- materializes the local image asset
- preserves the caption text as a separate line
- keeps asset provenance

## Microsoft MarkItDown result summary

- keeps the caption text, but does not surface the local asset in the same way

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | yes | kept | kept | both keep the caption text |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | yes | kept | partial | `markitdown-mb` materializes the asset explicitly |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- none on the native `markitdown-mb` side

## Extra noise

- none

## Asset behavior

- `markitdown-mb` exports `assets/image01.jpg`

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a local-image-plus-caption case in the native text-PDF path

## Next action

- keep PDF asset work limited to high-confidence caption pairing
