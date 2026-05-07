# Quality Comparison: zip-unsafe-path-boundary

- format: ZIP
- sample path: `samples/fixtures/zip/zip_path_traversal_boundary.zip`
- feature focus: unsafe archive path fail-closed behavior
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/fixtures/zip/zip_path_traversal_boundary.zip .tmp/quality-zip/mb-unsafe.md`
- Microsoft MarkItDown command: `markitdown samples/fixtures/zip/zip_path_traversal_boundary.zip -o .tmp/quality-zip/ms-unsafe.md`
- comparable scope: safety-boundary review only
- verdict: not_comparable

## Expected important structures

- container-level unsafe path should not be treated as a normal successful conversion

## markitdown-mb result summary

- fails closed at container level because the archive path is unsafe

## Microsoft MarkItDown result summary

- emits a visible section for `../evil.txt` and treats it as ordinary content

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | no | n/a | partial | the sample is a safety boundary, not a structure-retention case |
| Paragraph | no | n/a | partial | content visibility here is not a quality win |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no link |
| Image/asset | no | n/a | n/a | no asset |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | not part of this record |

## Lost structures

- not applicable; this is a safety-boundary case

## Extra noise

- Microsoft MarkItDown treats the unsafe path as a normal file section

## Asset behavior

- no assets expected

## Metadata/origin behavior

- not part of this record

## Degradation explanation

- this record is intentionally `not_comparable` because the main point is container safety policy, not same-scope Markdown quality

## Next action

- keep using this sample to document unsafe-path fail-closed policy rather than counting it as a benchmark or quality win
