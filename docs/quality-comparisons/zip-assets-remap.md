# Quality Comparison: zip-assets-remap

- format: ZIP
- sample path: `samples/main_process/zip/zip_duplicate_asset_names.zip`
- feature focus: local HTML image extraction inside ZIP, duplicate asset-name remap, and figure/title/caption retention
- comparison date: 2026-05-06
- markitdown-mb command: `./_build/native/debug/build/cli/cli.exe normal samples/main_process/zip/zip_duplicate_asset_names.zip .tmp/quality-zip/mb-assets.md`
- Microsoft MarkItDown command: `markitdown samples/main_process/zip/zip_duplicate_asset_names.zip -o .tmp/quality-zip/ms-assets.md`
- comparable scope: default local ZIP conversion only; no remote fetch, no browser layout
- verdict: win

## Expected important structures

- both HTML entries should keep image alt/title/caption
- duplicate nested image filenames should not collide
- output Markdown image paths should match materialized archive assets when assets are exported

## markitdown-mb result summary

- materializes both nested HTML assets into archive namespaces
- keeps duplicate filenames separated under `assets/archive/<entry-id>/...`
- preserves `alt`, `title`, and caption for both figures

## Microsoft MarkItDown result summary

- preserves figure text and image references
- keeps entry-local relative paths like `img/img_red.jpg`
- does not remap or materialize duplicate asset filenames into isolated archive output roots

## Structure retention checklist

| Structure | Expected | markitdown-mb | Microsoft MarkItDown | Notes |
| --- | --- | --- | --- | --- |
| Heading | yes | kept | kept | both delimit entries |
| Paragraph | no | n/a | n/a | no body paragraph outside captions |
| List | no | n/a | n/a | no list |
| Table | no | n/a | n/a | no table |
| Link | no | n/a | n/a | no links |
| Image/asset | yes | kept | partial | `markitdown-mb` remaps/materializes safely; Microsoft MarkItDown leaves raw entry-local refs |
| Code/pre | no | n/a | n/a | no code |
| Metadata/origin | no | n/a | n/a | Markdown-only comparison |

## Lost structures

- Microsoft MarkItDown does not provide archive-level asset remap isolation for duplicate nested filenames

## Extra noise

- Microsoft MarkItDown also emits bare sections for the image files themselves

## Asset behavior

- `markitdown-mb` writes archive namespaced assets that match the emitted Markdown
- Microsoft MarkItDown keeps source-local references inside the archive path model

## Metadata/origin behavior

- not part of this Markdown-only record

## Degradation explanation

- this record is about safe container asset remap, not browser rendering

## Next action

- keep this sample as the checked-in ZIP asset-remap quality record
