# Quality Comparison: pptx-links-images

- format: PPTX
- sample path: `samples/main_process/pptx/pptx_image_alt_title.pptx`
- feature focus: local image asset export, alt/title preservation
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pptx/pptx_image_alt_title.pptx .tmp/quality-comparisons/pptx_image_alt_title_compare/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pptx/pptx_image_alt_title.pptx -o .tmp/quality-comparisons/pptx_image_alt_title_compare/ms.md`
- comparable scope: default local PPTX conversion only
- verdict: win

## Expected important structures

- slide boundary
- exported local image asset
- alt text
- title-like source hint

## markitdown-mb result summary

- materializes the image asset, keeps the source alt text, and preserves the
  PowerPoint title hint on a separate line

## Microsoft MarkItDown result summary

- keeps the image and alt text, but leaves a source-local filename reference
  and drops the title hint

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | image-only slide |
| Paragraph | no | n/a | n/a | no body paragraph |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | yes | kept | partial | Microsoft keeps an image ref but not the repository asset-materialization policy |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the title hint

## Extra noise

- Microsoft MarkItDown emits a source-local filename instead of the repository
  asset path policy

## Asset behavior

- `markitdown-mb` writes `assets/image01.png`
- Microsoft MarkItDown keeps `Picture1.jpg` in Markdown output

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- image handling is an engineering-meaningful policy difference here: the local
  asset is materialized and accompanied by the source-native alt/title hints

## Next action

- keep PPTX image handling focused on deterministic local assets, not visual
  placement reconstruction
