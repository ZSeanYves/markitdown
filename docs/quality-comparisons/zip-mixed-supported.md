# Quality Comparison: zip-mixed-supported

- format: ZIP
- sample path: `samples/main_process/zip/zip_mixed_supported_entries.zip`
- feature focus: nested supported-entry dispatch, archive entry ordering, and structure retention across mixed textlike entries
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/zip/zip_mixed_supported_entries.zip .tmp/quality-zip/mb-mixed.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/zip/zip_mixed_supported_entries.zip -o .tmp/quality-zip/ms-mixed.md`
- comparable scope: default local ZIP conversion only; no recursive archive traversal, no OCR, no cloud/plugin path
- verdict: win

## Expected important structures

- one heading per archive entry
- deterministic normalized entry order
- Markdown passthrough for nested markdown entry
- structured lowering for nested JSON/CSV entry
- HTML heading/paragraph preservation

## markitdown-mb result summary

- emits one `# <entry path>` heading per visible archive entry
- sorts entries by normalized path
- lowers nested JSON to a table
- lowers nested CSV to a table
- preserves nested Markdown and HTML structure

## Microsoft MarkItDown result summary

- emits one `## File:` section per raw archive entry
- preserves nested Markdown/CSV/HTML text reasonably
- keeps JSON as compact raw JSON text rather than structured table lowering
- keeps raw archive order rather than normalized path ordering

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both delimit entries, but heading policy differs |
| Paragraph | yes | kept | kept | nested text/HTML paragraph content survives on both sides |
| List | no | n/a | n/a | no list in sample |
| Table | yes | kept | partial | JSON becomes a structured table only in `markitdown-mb` |
| Link | no | n/a | n/a | no links in sample |
| Image/asset | no | n/a | n/a | no asset in sample |
| Code/pre | no | n/a | n/a | no code/pre in sample |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown loses structured JSON lowering by leaving the JSON object inline

## Extra noise

- Microsoft MarkItDown includes a wrapper line `Content from the zip file ...`

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this is a container-aggregation and nested-dispatch quality difference, not a request for recursive archive behavior

## Next action

- keep this sample as the checked-in ZIP mixed-supported quality record
