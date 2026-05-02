# Quality Comparison: html-figure-image-assets

- format: HTML
- sample path: `samples/main_process/html/html_figure_figcaption_image.html`
- feature focus: local image export, title retention, figure/figcaption handling
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/html/html_figure_figcaption_image.html .tmp/quality-comparisons/html_figure_figcaption_image/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/html/html_figure_figcaption_image.html -o .tmp/quality-comparisons/html_figure_figcaption_image/ms.md`
- comparable scope: default local HTML conversion only; no remote fetch or browser rendering path
- verdict: win

## Expected important structures

- one local image
- image alt text
- image title
- figure caption text
- useful local asset behavior for downstream Markdown consumers

## markitdown-mb result summary

- exports the local image to `assets/image01.jpg`
- keeps the image title as a separate emphasis line
- keeps the figcaption as body text after the image block

## Microsoft MarkItDown result summary

- keeps the image and title inside Markdown image syntax
- keeps the figcaption as trailing text
- leaves the image reference pointing at the original HTML-relative source path

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | yes | kept | kept | caption text survives on both sides |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | yes | kept | partial | `markitdown-mb` materializes a local asset; Microsoft MarkItDown keeps source-relative path |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- no major structure loss on either side

## Extra noise

- none

## Asset behavior

- `markitdown-mb` wins on repository-local asset materialization for this local-image sample
- Microsoft MarkItDown output is still readable, but it depends on the original HTML-relative image path remaining valid

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a local-resource policy difference, not a question of visual fidelity

## Next action

- keep this sample as the checked-in HTML asset-behavior overlap record
