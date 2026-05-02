# Quality Comparison: docx-notes-comments

- format: DOCX
- sample path: `samples/main_process/docx/docx_footnotes_endnotes_comments.docx`
- feature focus: footnote/endnote/comment retention and ordering policy
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/docx_footnotes_endnotes_comments.docx .tmp/quality-comparisons/docx_notes_comments_mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/docx_footnotes_endnotes_comments.docx -o .tmp/quality-comparisons/docx_notes_comments_ms.md`
- comparable scope: default local DOCX conversion only; no metadata-sidecar comparison
- verdict: win

## Expected important structures

- body references to a footnote, an endnote, and a comment
- note/comment bodies preserved in a readable append policy
- stable note ordering

## markitdown-mb result summary

- keeps the body markers
- emits dedicated `Footnotes`, `Endnotes`, and `Comments` sections
- keeps the comment author signal

## Microsoft MarkItDown result summary

- keeps footnote and endnote content via inline backlink-style list items
- drops the comment body entirely on this sample

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | note-focused sample |
| Paragraph | yes | kept | partial | body text remains, comment marker weakens |
| List | yes | kept | partial | Microsoft uses note lists but has no comment section |
| Link | no | n/a | n/a | backlink anchors are not the target here |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses the comment content and author attribution on this
  sample

## Extra noise

- Microsoft MarkItDown introduces backlink-style anchors for notes, which are
  readable but not the main contract being evaluated

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- `markitdown-mb` is closer to the repository's explicit append-section policy
  for notes/comments and preserves more useful review context

## Next action

- keep this as the primary DOCX notes/comments evidence row for second-round
  sealing
