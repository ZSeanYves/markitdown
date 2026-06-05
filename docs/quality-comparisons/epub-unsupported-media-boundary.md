# Quality Comparison: epub-unsupported-media-boundary

- format: EPUB
- sample path: `samples/main_process/epub/epub_spine_unsupported_item_boundary.epub`
- feature focus: unsupported spine-item degradation, warning explainability, continue-after-warning behavior
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/epub/epub_spine_unsupported_item_boundary.epub .tmp/epub_quality/mb_warn.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/epub/epub_spine_unsupported_item_boundary.epub -o .tmp/epub_quality/ms_warn.md`
- comparable scope: default local EPUB conversion only; no DRM/CSS/JS/reader rendering
- verdict: win

## Expected important structures

- supported XHTML chapter should still be converted
- unsupported spine media should not silently disappear
- unsupported media should not be dumped as misleading raw body text

## markitdown-mb result summary

- keeps the supported chapter
- emits a separate warning block for the unsupported `audio/mpeg` spine item
- makes the skipped item path explicit

## Microsoft MarkItDown result summary

- keeps the supported chapter
- then emits the raw `ID3fake-audio` bytes as plain text
- does not explain that the spine item was unsupported

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Supported chapter | yes | kept | kept | both keep XHTML chapter text |
| Warning/degrade | yes | kept | lost | only `markitdown-mb` explains the unsupported item |
| Unsupported media boundary | yes | kept | partial | Microsoft output leaks raw bytes as text |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the degrade explanation for the unsupported spine item

## Extra noise

- raw `ID3fake-audio` text appears in Microsoft output

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a safe-degradation policy comparison, not a claim of multimedia support

## Next action

- keep unsupported-media handling as explicit warning blocks rather than raw-body fallback
