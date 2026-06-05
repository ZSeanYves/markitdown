# Quality Comparison: golden-docx

- format: DOCX
- sample path: `samples/main_process/docx/golden.docx`
- feature focus: headings, paragraphs, image handling, simple table retention
- comparison date: 2026-05-05
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/golden.docx .tmp/quality-comparisons/golden_docx_mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/golden.docx -o .tmp/quality-comparisons/golden_docx_ms.md`
- comparable scope: default local DOCX conversion only; no metadata-sidecar comparison
- verdict: close

## Expected important structures

- title and nested headings
- body paragraphs
- one embedded image
- one simple table with a header row

## markitdown-mb result summary

- keeps heading levels, paragraphs, image as exported asset reference, and a
  readable header-first Markdown table

## Microsoft MarkItDown result summary

- keeps heading levels and paragraphs
- keeps the image but uses a truncated data-URI placeholder instead of exported
  local asset linking
- keeps the table content, but emits an empty header row followed by bold text
  cells

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | heading levels match on this sample |
| Paragraph | yes | kept | kept | body text is equivalent |
| List | no | n/a | n/a | no list in this sample |
| Table | yes | kept | partial | Microsoft MarkItDown keeps content but weakens the header model |
| Link | no | n/a | n/a | no explicit hyperlink in this sample |
| Image/asset | yes | kept | partial | exported local asset path versus inline data-URI placeholder |
| Code/pre | no | n/a | n/a | no code block in this sample |
| Metadata/origin | no | n/a | n/a | record is Markdown-only |

## Lost structures

- no critical structure loss on either side for the main narrative flow

## Extra noise

- Microsoft MarkItDown adds a weaker table-header pattern with an empty header
  row

## Asset behavior

- `markitdown-mb` emits `assets/image01.png`
- Microsoft MarkItDown keeps the image via a data-URI placeholder

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the main difference is output policy, not a full DOCX parse failure
- `markitdown-mb` is closer to the repository's local-asset contract, while the
  Microsoft output remains readable enough for Markdown consumers

## Next action

- keep this as a representative combined-structure DOCX seed
- add a future DOCX record for headings + list + hyperlink in one richer sample
