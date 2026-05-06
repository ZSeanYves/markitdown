# Quality Comparison: epub-spine-order

- format: EPUB
- sample path: `samples/main_process/epub/epub_spine_order.epub`
- feature focus: OPF spine ordering, archive-path retention, chapter aggregation
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/epub/epub_spine_order.epub .tmp/epub_quality/mb_spine.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/epub/epub_spine_order.epub -o .tmp/epub_quality/ms_spine.md`
- comparable scope: default local EPUB conversion only; no DRM/CSS/JS/reading-system rendering
- verdict: win

## Expected important structures

- chapter order must follow OPF spine order, not ZIP entry order
- each chapter boundary should stay explicit
- chapter-local body text should stay readable

## markitdown-mb result summary

- keeps OPF spine order
- emits explicit `# <archive path>` chapter headings
- then emits chapter headings/body in the same spine order

## Microsoft MarkItDown result summary

- keeps the body chapter order correctly on this sample
- drops the explicit archive-path chapter boundary
- emits only a book title preface plus chapter headings/body

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Spine order | yes | kept | kept | both follow OPF order here |
| Chapter boundary | yes | kept | partial | archive-path boundary only visible in `markitdown-mb` |
| Paragraph | yes | kept | kept | body paragraphs survive on both sides |
| TOC | no | n/a | n/a | no TOC in this sample |
| Image/asset | no | n/a | n/a | no images |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses explicit archive-path chapter boundaries

## Extra noise

- Microsoft MarkItDown adds a bold title preface instead of container-path headings

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is not a reader-rendering comparison; it is a container/spine aggregation comparison

## Next action

- keep OPF-spine-first aggregation as the EPUB container contract
