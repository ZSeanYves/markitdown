# DOCX Quality Policy Triage

## Policy Alignment Applied

- Date: 2026-06-09
- Main repo HEAD before policy update: `293f570`
- Quality-lab HEAD before policy update: `57f30f4`
- Updated quality-lab file: `markitdown-quality-lab/external_quality/MANIFEST.tsv`
- Command after update: `bash samples/check_quality.sh --format docx`
- Run: `.tmp/quality/runs/docx-20260609-093538-40509`
- Result: 57 rows, 54 checked, 3 skipped for license review, 0 failed

The policy update changed only DOCX quality row expectations in the external
quality-lab manifest. DOCX runtime, repo-local sample expected output, and
quality sample files were not changed.

### Applied Row Decisions

| row id/group | applied decision |
|---|---|
| `docx_deep_table_cell_apache_poi*` | Accept bounded nested-table behavior. The rows now require `Nested level 0`, the explicit `[Unsupported DOCX nested table depth limit]` marker, table output, and absence of deep levels such as 2500/4999/5000. |
| `docx_images_apache_poi_variouspictures*` | Treat PNG/JPG as exported raster assets and WMF/PICT/EMF as explicit unsupported image placeholders. The rows no longer require fake `.img` raster exports for non-raster media. |
| `docx_inline_images_python_docx_shp_inline_shape_access_counts` | Align JPEG extension expectation with current canonical `.jpg` asset output. |
| `docx_notes_openxmlsdk_image_body_order_counts` | Align image order checks with current canonical `.png` asset output instead of stale `.img` paths. |
| `docx_images_python_docx_having_images_counts` | Record current product behavior: six rendered image references with at least three exported assets, allowing media-part deduplication while preserving repeated document references. |

## Snapshot

- Date: 2026-06-08
- HEAD at P1 follow-up: `57260fb`
- Command: `bash samples/check_quality.sh --format docx || true`
- Run: `.tmp/quality/runs/docx-20260608-214624-7118`
- Manifest: `markitdown-quality-lab/external_quality/MANIFEST.tsv`
- Result: 57 rows, 54 checked, 3 skipped for license review, 7 failed

This report is documentation only. It does not change runtime code, repo-local samples expected output, or the quality-lab manifest. Quality-lab policy rows were left untouched in this slice so the next policy update can be reviewed as an explicit quality-lab change.

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

## P1 Follow-up Plan

| priority | rows | policy decision | next action |
|---|---|---|---|
| P1 | `docx_deep_table_cell_apache_poi`, `docx_deep_table_cell_apache_poi_counts` | Bounded nested-table output is accepted product behavior. The quality row should verify termination, visible early content, and the typed unsupported placeholder, not deepest-level preservation. | Update quality-lab manifest/expected in a dedicated policy commit after review. Suggested required signals: `Nested level 0`, `[Unsupported DOCX nested table depth limit]`, no timeout/crash. |
| P1 | `docx_images_apache_poi_variouspictures`, `docx_images_apache_poi_variouspictures_asset_counts` | Raster images are exported; non-raster WMF/EMF/PICT remain typed unsupported image placeholders. | Split raster asset-count checks from non-raster placeholder checks. Remove `.img` rasterization expectations unless a future renderer is added. |
| P1 | `docx_notes_openxmlsdk_image_body_order_counts` | Current extension policy emits actual raster extensions (`.png`) rather than generic `.img`. Text/body/note order remains the important quality signal. | Replace filename-extension-specific `.img` checks with image reference/order anchors or content-type-aware asset checks. |
| P2 | `docx_inline_images_python_docx_shp_inline_shape_access_counts` | `.jpg` and `.jpeg` spelling should not be a quality failure when the exported asset content/type is correct. | Relax exact `.jpeg)` assertion to image-ref or MIME/content-type policy. |
| P2 | `docx_images_python_docx_having_images_counts` | Repeated image references are currently emitted as document references while asset export is deduplicated. | Decide product policy: keep repeated Markdown refs and adjust exact count, or add a future runtime normalization slice. Do not change runtime only to match stale count 5. |

## Quality-Lab Change Status

- `markitdown-quality-lab/external_quality/MANIFEST.tsv`: updated on 2026-06-09 for the seven DOCX rows above.
- Repo-local samples expected output: not modified.
- DOCX runtime: not modified.
- Quality result after update: `bash samples/check_quality.sh --format docx` passed with 57 rows, 54 checked, 3 skipped, 0 failed.

## Recommended Follow-up

1. Keep future DOCX quality additions policy-aware: distinguish exported raster assets, unsupported non-raster placeholders, and rendered image references.
2. If WMF/EMF/PICT rasterization is added later, introduce a separate runtime/product slice and then update these rows deliberately.
3. If repeated image references are normalized later, update `having-images.docx` quality rows together with a runtime behavior change and sample review.
