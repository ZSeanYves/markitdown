# Quality Comparison: pdf-header-footer-noise

- format: PDF
- sample path: `samples/main_process/pdf/pdf_repeated_header_footer.pdf`
- feature focus: repeated header/footer suppression
- comparison date: 2026-05-07
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/pdf/pdf_repeated_header_footer.pdf .tmp/quality-comparisons/pdf-header-footer-noise/mb.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/pdf/pdf_repeated_header_footer.pdf -o .tmp/quality-comparisons/pdf-header-footer-noise/ms.md`
- comparable scope: native text-oriented PDF only; no OCR/cloud/plugin path
- verdict: close

## Expected important structures

- two body paragraphs
- repeated header/footer removed

## markitdown-mb result summary

- keeps the body paragraphs
- suppresses repeated header/footer residue in the main flow

## Microsoft MarkItDown result summary

- keeps the body paragraphs
- leaves header/footer residue in the output

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | n/a | no heading |
| Paragraph | yes | kept | kept | both keep the body |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no image |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown keeps header/footer residue that `markitdown-mb` suppresses

## Extra noise

- Microsoft MarkItDown leaves visible `Project Report` / `Confidential` residue

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- the main difference is noise-policy quality, not broad semantic recovery

## Next action

- keep PDF work focused on repeated-edge cleanup and page-noise policy
