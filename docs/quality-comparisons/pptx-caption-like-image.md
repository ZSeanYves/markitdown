# Quality Comparison: pptx-caption-like-image

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_image_caption_like_boundary.pptx`
- feature focus: image caption-like pairing
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_image_caption_like_boundary.pptx .tmp/quality-comparisons/pptx_image_caption_like_boundary_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_image_caption_like_boundary.pptx -o .tmp/quality-comparisons/pptx_image_caption_like_boundary_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- local image asset
- short nearby caption-like text

## markitdown-mb result summary

- materializes the image asset and keeps the nearby caption-like text directly
  beside it

## Microsoft MarkItDown result summary

- output is not meaningfully comparable on this local asset path because the
  caption-like text and local asset policy are not retained in the same way

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | image-only slide |
| Paragraph | yes | kept | partial | caption-like text handling differs |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | yes | kept | partial | local asset and pairing policy differ |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown does not keep the same local-asset-plus-caption pairing

## Extra noise

- none beyond the local asset policy difference

## Asset behavior

- `markitdown-mb` emits `assets/image01.png`
- Microsoft MarkItDown does not match the same local asset materialization story

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- caption-like pairing is intentionally conservative in this repository; the
  point is to keep useful nearby text without pretending to infer full visual
  anchors

## Next action

- keep caption-like pairing bounded and evidence-driven
