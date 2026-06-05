# Quality Comparison: zip-unsupported-entry-boundary

- format: ZIP
- sample path: `samples/main_process/zip/zip_unsupported_entries.zip`
- feature focus: unsupported entry visibility and warning explainability
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/zip/zip_unsupported_entries.zip .tmp/quality-zip/mb-unsupported.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/zip/zip_unsupported_entries.zip -o .tmp/quality-zip/ms-unsupported.md`
- comparable scope: default local ZIP conversion only; no binary-preview expectation
- verdict: win

## Expected important structures

- supported markdown entry should survive
- unsupported binary/jpg entries should stay visible as explainable degradations
- unsupported entries should not silently disappear

## markitdown-mb result summary

- keeps the supported Markdown entry
- emits explicit warning blocks for unsupported `.bin` and `.jpg` entries
- does not invent binary text

## Microsoft MarkItDown result summary

- keeps the supported Markdown entry
- tries to render the `.bin` entry as mojibake-like text
- leaves the `.jpg` entry as an empty file section without an explicit degrade explanation

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both delimit entries |
| Paragraph | yes | kept | partial | supported markdown body is preserved on both sides |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no links |
| Image/asset | no | n/a | n/a | no materialized asset expected |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses explainable degradation for unsupported entries

## Extra noise

- Microsoft MarkItDown emits mojibake-like text for the binary entry

## Asset behavior

- no archive assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this record is about stable unsupported-entry handling rather than “opening more bytes”

## Next action

- keep this sample as the checked-in ZIP unsupported-entry quality record
