# Quality Comparison: epub-assets-cover

- format: EPUB
- sample path: `samples/main_process/epub/epub_cover_image.epub`
- feature focus: cover image extraction, local asset remap, body preservation
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/epub/epub_cover_image.epub .tmp/epub_quality/mb_cover.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/epub/epub_cover_image.epub -o .tmp/epub_quality/ms_cover.md`
- comparable scope: default local EPUB conversion only; no reader rendering, no remote fetch
- verdict: win

## Expected important structures

- cover image should be materialized locally when source is a local manifest image
- chapter body should still follow the cover
- cover should not replace chapter text

## markitdown-mb result summary

- materializes the cover image under `assets/archive/...`
- keeps the chapter body after the image
- makes the cover/body order explicit in Markdown

## Microsoft MarkItDown result summary

- keeps only the textual title/chapter body on this sample
- does not emit the local cover image as a materialized asset

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Cover image | yes | kept | lost | local asset only materialized in `markitdown-mb` |
| Chapter heading | yes | kept | kept | both keep the chapter heading |
| Paragraph | yes | kept | kept | body paragraph survives on both sides |
| Asset remap | yes | kept | lost | only `markitdown-mb` writes `assets/archive/...` |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the local cover image as a materialized asset

## Extra noise

- Microsoft MarkItDown adds a bold title preface instead of cover extraction

## Asset behavior

- `markitdown-mb` exports one local image asset for the cover
- Microsoft MarkItDown emits no corresponding local asset on this sample

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a local-cover-asset comparison, not a reader-layout or CSS comparison

## Next action

- keep local cover-image export as the EPUB asset contract
