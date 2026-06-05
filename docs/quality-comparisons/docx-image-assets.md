# Quality Comparison: docx-image-assets

- format: DOCX
- sample path: `samples/main_process/docx/docx_image_alt_title.docx`
- feature focus: local image asset materialization plus alt/title preservation
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/docx_image_alt_title.docx .tmp/quality-comparisons/docx_image_assets_mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/docx_image_alt_title.docx -o .tmp/quality-comparisons/docx_image_assets_ms.md`
- comparable scope: default local DOCX conversion only; no metadata-sidecar comparison
- verdict: win

## Expected important structures

- one embedded image
- `alt`-like descriptive text
- title-like caption text
- local asset behavior

## markitdown-mb result summary

- emits a local asset reference `assets/image01.png`
- keeps the image alt text
- keeps the title as a following emphasis line

## Microsoft MarkItDown result summary

- keeps the image alt text
- emits a data-URI placeholder instead of a local exported asset path
- does not preserve the title line on this sample

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | image-only sample |
| Paragraph | no | n/a | n/a | no body paragraph |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no hyperlink |
| Image/asset | yes | kept | partial | local asset vs data URI placeholder |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the title-like line after the image on this sample

## Extra noise

- Microsoft MarkItDown substitutes a data-URI placeholder instead of using the
  repository's local-asset contract

## Asset behavior

- `markitdown-mb` materializes `assets/image01.png`
- Microsoft MarkItDown keeps the image inline as a placeholder URI

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- `markitdown-mb` is closer to the repository's local asset + companion-title
  policy for DOCX images

## Next action

- keep this as the main DOCX image-asset seed; table-contained images are
  covered separately by regression and unit tests
