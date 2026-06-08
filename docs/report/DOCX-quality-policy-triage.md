# DOCX Quality Policy Triage

## Snapshot

- Date: 2026-06-08
- HEAD at triage: `803bb97`
- Command: `bash samples/check_quality.sh --format docx || true`
- Run: `.tmp/quality/runs/docx-20260608-211519-78415`
- Manifest: `markitdown-quality-lab/external_quality/MANIFEST.tsv`
- Result: 57 rows, 54 checked, 3 skipped for license review, 7 failed

This report is documentation only. It does not change runtime code, repo-local samples expected output, or the quality-lab manifest.

## Failure Table

| row id | source file | failed signal | observed behavior | classification | recommendation |
|---|---|---|---|---|---|
| `docx_images_python_docx_having_images_counts` | `external_quality/docx/python-docx/having-images.docx` | `exact_count:![image](assets/=5` | Output has 6 image Markdown references and 3 exported assets. Existing `image_ref` and `asset_count_min:3` pass. | Product policy / manifest stale | Decide whether repeated image references are part of product behavior. If yes, update the external row to the current count or relax to asset/ref minimums. Do not change runtime just to hit count 5. |
| `docx_deep_table_cell_apache_poi` | `external_quality/docx/apache-poi/deep-table-cell.docx` | `contains_all:Nested level 0|Nested level 4999` | Output is bounded to nested levels 0 through 6 plus `[Unsupported DOCX nested table depth limit]`. | Bounded deep-table policy | Change this row from deepest-text preservation to bounded behavior. Assert level 0, the explicit unsupported placeholder, and no timeout. |
| `docx_deep_table_cell_apache_poi_counts` | same as above | missing `Nested level 2500`, `Nested level 4999`, order | Same bounded output: levels 0 through 6 only, explicit unsupported marker. | Bounded deep-table policy | Update quality policy to accept the hard guard. Keeping 2500/4999 as required conflicts with the architecture performance contract. |
| `docx_images_apache_poi_variouspictures` | `external_quality/docx/apache-poi/VariousPictures.docx` | `asset_count_min:5` | Output exports raster images only: `image01.png`, `image02.jpg`; non-raster WMF/EMF/PICT are represented as typed placeholders such as `[image: santa.wmf]`. | Non-raster unsupported policy | Update row to distinguish raster asset export from non-raster placeholder policy. Require typed placeholders for non-raster media rather than asset export count 5. |
| `docx_images_apache_poi_variouspictures_asset_counts` | same as above | missing `![santa.wmf](assets/image01.img)`, `asset_count_min:5`, order | Output preserves text and emits `[image: santa.wmf]`, `[image: cow.pict]`, `[image: wrench.emf]`, plus raster Markdown images for PNG/JPG. | Non-raster unsupported policy / manifest stale | Replace `.img` expectations with placeholder assertions or add an explicit future task for WMF/EMF/PICT rendering. Current runtime should not invent raster exports for unsupported formats. |
| `docx_inline_images_python_docx_shp_inline_shape_access_counts` | `external_quality/docx/python-docx/shp-inline-shape-access.docx` | `exact_count:.jpeg)=1` | Output exports `image01.png` and `image02.jpg`; the second image is JPEG content with `.jpg` extension. | Manifest stale | Make extension expectations content-policy aware. Prefer `image_ref` plus asset metadata/content-type checks over exact `.jpeg` spelling. |
| `docx_notes_openxmlsdk_image_body_order_counts` | `external_quality/docx/openxml-sdk/Notes.docx` | expected `.img` image paths and exact order | Output has correct body/note text order and two images, but image links are `assets/image01.png` and `assets/image02.png` rather than `.img`. | Manifest stale | Update image path expectations to current extension policy or relax to image refs plus order anchors that are not filename-extension specific. |

## Classification Summary

- Runtime bug: none confirmed by this run.
- Expected/manifest stale: filename extension expectations for `.img` / `.jpeg`.
- Product policy: repeated image reference count in `having-images.docx` needs an explicit product decision.
- Non-raster unsupported policy: WMF/EMF/PICT currently lower to typed image placeholders instead of exported assets.
- Bounded deep-table policy: preserving `Nested level 2500` and `Nested level 4999` conflicts with the hard depth guard.

## Recommended Follow-up

1. Move the two deep-table rows to a bounded-output policy: assert termination, `Nested level 0`, and `[Unsupported DOCX nested table depth limit]`.
2. Split raster asset export checks from non-raster media checks for `VariousPictures.docx`.
3. Replace `.img` / `.jpeg` exact path expectations with content-policy aware checks.
4. Decide whether repeated image Markdown references in `having-images.docx` should be normalized, deduplicated, or recorded as current product behavior.
