# Quality Comparison: docx-header-footer-textbox

- format: DOCX
- sample path: `samples/main_process/docx/docx_textbox_body_and_table.docx`
- feature focus: textbox extraction policy without pretending to be a Word layout engine
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/docx/docx_textbox_body_and_table.docx .tmp/quality-comparisons/docx_header_footer_textbox_mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/docx/docx_textbox_body_and_table.docx -o .tmp/quality-comparisons/docx_header_footer_textbox_ms.md`
- comparable scope: default local DOCX conversion only; no metadata-sidecar comparison
- verdict: close

## Expected important structures

- main body paragraph
- body text box content
- table-contained text box content
- conservative non-visual downgrade

## markitdown-mb result summary

- keeps the body paragraph
- preserves text box content under a dedicated `Text Boxes` append section
- avoids pretending to know the original Word visual placement

## Microsoft MarkItDown result summary

- keeps the body paragraph
- keeps both text box texts inline with the body/table flow
- preserves readable content but with a different policy shape

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | sample is textbox-policy focused |
| Paragraph | yes | kept | kept | body text preserved |
| List | no | n/a | n/a | no list |
| Table | yes | partial | partial | both use conservative downgrade |
| Link | no | n/a | n/a | no hyperlink |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- neither side reconstructs the original visual placement, which is outside the
  intended DOCX contract

## Extra noise

- `markitdown-mb` uses an explicit append-section policy
- Microsoft MarkItDown inlines the textbox content into the body/table flow

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is mainly a policy difference, not a parse failure
- the repository contract favors explainable append sections over layout
  speculation

## Next action

- keep this as a DOCX textbox-policy record rather than a visual-layout contest
