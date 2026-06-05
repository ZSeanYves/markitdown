# Quality Comparison: epub-nav-toc

- format: EPUB
- sample path: `samples/main_process/epub/epub_nav_toc_basic.epub`
- feature focus: EPUB3 nav TOC extraction, TOC/body separation, safe local link retention
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/epub/epub_nav_toc_basic.epub .tmp/epub_quality/mb_nav.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/epub/epub_nav_toc_basic.epub -o .tmp/epub_quality/ms_nav.md`
- comparable scope: default local EPUB conversion only; no reader UI, no CSS/JS execution
- verdict: win

## Expected important structures

- one explicit table of contents block
- TOC link text preserved
- chapter body preserved
- TOC should not duplicate or pollute the chapter body

## markitdown-mb result summary

- emits `# Table of Contents`
- keeps both TOC links
- keeps the chapter body and section headings after the TOC

## Microsoft MarkItDown result summary

- keeps the chapter body and section headings
- does not emit a TOC block from the EPUB3 nav document on this sample

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| TOC heading | yes | kept | lost | only `markitdown-mb` emits TOC |
| TOC links | yes | kept | lost | section links absent in Microsoft output |
| Chapter body | yes | kept | kept | body text survives on both sides |
| Anchor links | yes | kept | partial | only visible through TOC in `markitdown-mb` |
| Image/asset | no | n/a | n/a | no images |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the EPUB3 TOC structure on this sample

## Extra noise

- Microsoft MarkItDown adds a bold title preface instead of a TOC section

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this record is about safe TOC extraction, not reading-system navigation UX

## Next action

- keep EPUB3 nav as the primary TOC source and keep NCX as fallback only
