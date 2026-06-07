# DOCX v2 Closeout Report

## 1. Current Runtime Status

DOCX runtime has been replaced by the v2 architecture. The old v1 runtime has been removed, and current DOCX conversion now goes through the new `doc_parse/docx` + `convert/docx` source/model/lowering pipeline.

The v2 pipeline follows the intended architecture:

```text
DOCX package
 -> part graph discovery
 -> DOCX source facts
 -> normalized DocxDocument model
 -> convert lowering
 -> core Document / Markdown / assets / metadata
```

There is no runtime v1 fallback, no legacy oracle in normal conversion, and no convert-layer raw WordprocessingML scanning.

## 2. Main Regression Status

Repo-local DOCX samples are currently green:

```text
bash samples/check.sh --format docx
markdown: 61/61
metadata: 10/10
assets: 9/9
```

Full repo-local samples are also green:

```text
bash samples/check.sh
markdown: 448/448
metadata: 85/85
assets: 90/90
```

The current checked-in DOCX expected files remain unchanged. The v2 runtime was adjusted to match current product behavior rather than updating expected output.

## 3. Unit and Build Validation

Focused DOCX tests pass:

```text
moon test doc_parse/docx/tests
moon test convert/docx/test
```

The latest reported counts after the runtime fixes were:

```text
doc_parse/docx/tests: 54/54
convert/docx/test: 62/62
```

`moon check` passes with two unrelated existing warnings.

A full `moon test` run previously reported one failure caused by a missing local PDF fixture:

```text
markitdown-quality-lab/external_quality/pdf/markitdown/test.pdf
```

That failure is not related to DOCX.

## 4. Runtime Fixes Completed

The recent DOCX v2 closeout work fixed the major runtime quality gaps exposed by external quality rows.

### Notes, comments, footnotes, and endnotes

The runtime now treats note/comment body marker glyphs as non-visible run children:

```text
w:annotationRef
w:footnoteRef
w:endnoteRef
separator markers
```

These no longer produce `[unsupported DOCX inline]`.

Comment appendix lowering now preserves rich inline content such as hyperlinks and inline images. Inline comment images are exported through the existing asset path.

### Hyperlink anchors

Hyperlink targets now compose relationship target plus `w:anchor`.

Example:

```text
http://foo.com/ + intro -> http://foo.com/#intro
```

### SVG companion media

DOCX drawings now support typed alternate media:

```text
DocxDrawing.alternate_media
```

The parser collects `asvg:svgBlip` relationships as typed media. The model carries this alternate media through to lowering. The converter exports SVG companion assets without emitting duplicate Markdown image references.

### Deep nested table guard

Pathological nested table input, including the Apache POI `deep-table-cell.docx` with 5000 nested tables, no longer times out.

Current behavior is bounded and explicit:

```text
Nested level 0..6
[Unsupported DOCX nested table depth limit]
```

The converter does not attempt to expand all 5000 nested levels. This is intentional product behavior.

## 5. Performance Status

The deep-table timeout was fixed.

Reported focused result:

```text
deep-table-cell.docx
old behavior: 30s / 120s timeout
current behavior: about 0.24s median after guard/scanner optimization
```

A small DOCX convert benchmark snapshot showed:

```text
current DOCX convert p50: 6ms
prior comparable-ish p50: 5ms
```

The comparison is not strict because iteration counts differed.

Benchmark caveats remain:

```text
parser bench: no enabled DOCX parser rows selected from external_bench
cli/compare bench: macOS Bash 3.2 portability issue from declare -A / local -n
```

These are benchmark harness issues, not DOCX runtime failures.

## 6. External Quality Status

After runtime fixes, the 22 rows classified as likely DOCX runtime bugs were resolved.

Remaining DOCX quality failures are not currently classified as core runtime bugs. They fall into policy or manifest-signal categories.

### Rows suitable for quality signal update

Five rows are ready for quality signal adjustment:

```text
docx_images_python_docx_having_images_counts
docx_deep_table_cell_apache_poi
docx_deep_table_cell_apache_poi_counts
docx_inline_images_python_docx_shp_inline_shape_access_counts
docx_notes_openxmlsdk_image_body_order_counts
```

Recommended updates:

* `having_images_counts`: align signal with explicit product semantics, either unique exported assets or visible Markdown image references. Current output has repeated refs including header usage, while source has three unique PNG media parts.
* `deep_table`: stop expecting `Nested level 2500` or `Nested level 4999`; assert bounded placeholder behavior instead.
* inline JPEG: accept canonical `.jpg` for `image/jpeg` rather than requiring original `.jpeg`.
* Notes PNG: expect content-type-driven `.png`, not stale `.img`.

### Rows requiring product strategy decision

Two rows involve Apache POI `VariousPictures.docx`:

```text
docx_images_apache_poi_variouspictures
docx_images_apache_poi_variouspictures_asset_counts
```

The fixture includes non-raster media such as:

```text
WMF
EMF
PICT
```

Current runtime strategy exports raster PNG/JPG assets and leaves non-raster content as explicit placeholder/warning.

Recommended short-term product strategy:

```text
Raster-only export + explicit non-raster placeholder/warning.
```

Do not silently mark non-raster assets as passing. Do not claim full WMF/EMF/PICT support unless a product decision is made to raw-export originals or convert/render them.

Possible long-term options:

1. Keep raster-only export and update quality rows to assert warnings/placeholders for non-raster media.
2. Raw-export WMF/EMF/PICT originals as assets with correct extensions and metadata.
3. Add conversion/rendering support for non-raster formats.

Option 1 is safest for the current release line.

## 7. Quality Policy Recommendation

The quality corpus should distinguish between:

```text
runtime correctness bugs
product policy decisions
manifest/test signal mismatches
unsupported-but-explicitly-warned features
pathological input guard behavior
```

Pathological deep table rows should not require full expansion of thousands of nested tables. A better signal is:

```text
conversion completes within bounded time
output contains early visible levels such as Nested level 0
output contains the explicit nested-table-depth placeholder
output does not panic or silently return empty content
```

This aligns quality with the v2 design goal: stable, bounded, explicit conversion rather than unbounded Word-layout emulation.

## 8. Current Commit Candidates

The current working tree should be split into separate commits.

### Runtime bug fixes

Suggested commit message:

```text
docx: fix note/comment definitions and hyperlink anchors
```

This covers:

```text
note/comment/endnote marker cleanup
rich comment body lowering
hyperlink target + anchor composition
inline comment media export
```

### SVG companion media export

Suggested commit message:

```text
docx: export SVG companion media assets
```

This covers:

```text
alternate media model
asvg:svgBlip parsing
SVG companion asset export
focused tests
```

### Deep table and parser performance

Suggested commit message:

```text
docx: bound parser traversal for pathological documents
```

This covers:

```text
deep nested table guard
bounded table placeholder
scanner optimization
deep-table tests
```

### Docs cleanup

Suggested commit message:

```text
docs: reset archive and consolidate current documentation
```

This should stay separate from runtime work.

## 9. Remaining Work

### Before final DOCX closeout

1. Apply reviewed quality policy updates for the five manifest-signal mismatch rows.
2. Decide non-raster media policy for WMF/EMF/PICT.
3. Fix benchmark harness portability on macOS Bash 3.2.
4. Add or enable DOCX parser benchmark rows in external_bench.
5. Rerun:

   ```text
   bash samples/check.sh
   bash samples/check_quality.sh --format docx
   moon check
   focused DOCX benchmark
   ```

### Future DOCX improvements

These are not blockers for the current v2 runtime:

```text
full OMML conversion
field evaluation
Word-layout-perfect complex table rendering
raw-export or rendering for WMF/EMF/PICT
richer asset policy metadata
more stable cross-platform benchmark harness
```

## 10. Current Assessment

DOCX v2 is now structurally sound and operationally strong:

* main regression is green
* v2 runtime no longer depends on v1
* source/model/lowering separation is preserved
* deep pathological input is bounded
* the largest runtime quality bugs have been fixed
* remaining external quality failures are mostly policy or manifest alignment work

The main remaining closeout risk is not architecture. It is quality policy alignment and benchmark harness reliability.
