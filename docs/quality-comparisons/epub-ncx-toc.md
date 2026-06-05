# Quality Comparison: epub-ncx-toc

- format: EPUB
- sample path: `samples/main_process/epub/epub_ncx_toc_basic.epub`
- feature focus: EPUB2 NCX fallback TOC, TOC/body separation
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/epub/epub_ncx_toc_basic.epub .tmp/epub_quality/mb_ncx.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/epub/epub_ncx_toc_basic.epub -o .tmp/epub_quality/ms_ncx.md`
- comparable scope: default local EPUB conversion only; NCX is evaluated only on the checked-in minimal-support subset
- verdict: win

## Expected important structures

- NCX should act as TOC fallback when EPUB3 nav is absent
- TOC should stay separate from body
- body should still be preserved

## markitdown-mb result summary

- emits an explicit TOC from NCX
- keeps the chapter body after the TOC

## Microsoft MarkItDown result summary

- keeps the chapter body
- does not emit an NCX-derived TOC block on this sample

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| NCX TOC | yes | kept | lost | only `markitdown-mb` emits NCX fallback TOC |
| Chapter body | yes | kept | kept | body text survives on both sides |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the NCX fallback TOC

## Extra noise

- Microsoft MarkItDown adds a bold title preface instead of TOC emission

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this record is limited to the checked-in NCX minimal-support subset; it is not a claim of full NCX tree fidelity

## Next action

- keep NCX support explicitly scoped to the current minimal subset
