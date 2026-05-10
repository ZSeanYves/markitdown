# doc_parse Performance Baseline

This page records the measured benchmark snapshot used for the current
`doc_parse` release-preparation round.

It combines repository-level CLI timing with the first direct `doc_parse/*`
library-harness snapshot. It is still not a blanket cross-machine claim about
latency for every package and file shape.

## Capture Metadata

* date: `2026-05-10`
* repository state: current working tree after documentation/API-comment
  release-prep updates
* runner preference: prebuilt native binaries where available
* validation before benchmark:
  * `moon build --target native`
  * `moon check`
  * `moon test`
  * `./samples/check.sh`

## Benchmark Commands

Measured commands:

```bash
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
./samples/bench_product_path.sh --help
./samples/bench_product_path.sh --smoke
./samples/bench_product_path.sh --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format text --stage parse --profile text --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format json --stage parse --profile json --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format markdown --stage scan --profile markdown --iterations 10 --warmup 2
```

Artifacts:

* smoke summary:
  `.tmp/bench/smoke/summary.tsv`
* smoke raw results:
  `.tmp/bench/smoke/results.jsonl`
* batch profile summary:
  `.tmp/bench/batch_profile/summary.tsv`
* batch startup summary:
  `.tmp/bench/batch_profile/startup-summary.tsv`
* batch comparison summary:
  `.tmp/bench/batch_profile/comparison-summary.tsv`
* doc_parse library summary:
  `.tmp/bench/doc_parse/summary.tsv`
* doc_parse library raw runs:
  `.tmp/bench/doc_parse/summary.runs.tsv`
* product-path summary:
  `.tmp/bench/product_path/summary.tsv`
* product-path raw runs:
  `.tmp/bench/product_path/summary.runs.tsv`
* focused XLSX parse summary:
  `.tmp/bench/doc_parse/xlsx_after_parse.tsv`
* focused XLSX parse profile summary:
  `.tmp/bench/doc_parse/xlsx_profile.tsv`
* focused DOCX parse summary:
  `.tmp/bench/doc_parse/docx_after_parse.tsv`
* focused DOCX parse profile summary:
  `.tmp/bench/doc_parse/docx_profile_after.tsv`
* focused YAML parse summary:
  `.tmp/bench/doc_parse/yaml_after_parse.tsv`
* focused YAML parse profile summary:
  `.tmp/bench/doc_parse/yaml_profile_after.tsv`
* focused text parse profile summary:
  `.tmp/bench/doc_parse/text_profile_after_final.tsv`
* focused JSON parse profile summary:
  `.tmp/bench/doc_parse/json_profile_after.tsv`
* focused Markdown scan profile summary:
  `.tmp/bench/doc_parse/markdown_profile_after.tsv`

## Outcome Summary

* smoke suite: `96` rows, `0` failures
* batch-profile suite: `48` runs, `0` failures
* doc_parse library suite: `75` stage rows, `0` failures
* product-path suite: `78` stage rows, `0` failures
* no expectations or fixtures were changed to make the benchmark pass

## Smoke Benchmark Highlights

Representative small-case native CLI rows:

* `markdown_small`: `9 ms`
* `markdown_frontmatter_passthrough`: `9 ms`
* `csv_small`: `10 ms`
* `tsv_small`: `10 ms`
* `txt_small`: `10 ms`
* `html_small`: `11 ms`
* `json_small`: `11 ms`
* `xml_small`: `11 ms`
* `xlsx_small`: `11 ms`
* `pptx_small`: `12 ms`
* `docx_small`: `13 ms`
* `pdf_text_simple`: `13 ms`

Slowest smoke rows in this snapshot:

* `xlsx_formula_heavy_missing_cache`: `27 ms`
* `txt_large`: `25 ms`
* `yaml_large`: `24 ms`
* `pdf_heading_basic`: `23 ms`
* `json_large`: `23 ms`
* `zip_large_many_entries`: `22 ms`
* `xlsx_large`: `22 ms`

Per-format average smoke median in this run:

* `markdown`: `9.75 ms`
* `html`: `10.44 ms`
* `xml`: `10.50 ms`
* `csv`: `12.75 ms`
* `tsv`: `13.00 ms`
* `epub`: `13.71 ms`
* `pptx`: `13.80 ms`
* `txt`: `14.25 ms`
* `docx`: `14.45 ms`
* `zip`: `14.57 ms`
* `json`: `14.60 ms`
* `pdf`: `14.78 ms`
* `xlsx`: `14.77 ms`
* `yaml`: `15.00 ms`

Important interpretation:

* `80 / 96` smoke rows are above `10 ms`
* this does **not** mean `80 / 96` library parse paths violate the intended
  small-case target
* the current public benchmark includes CLI startup, file I/O, converter
  lowering, and output work on the normal path

## Batch Profile Highlights

Measured startup probes:

* `help`: `13 ms`
* `empty-batch`: `13 ms`

This gives a useful same-machine estimate of fixed native CLI overhead before
format-local parsing/conversion dominates.

Representative process-per-file vs single-process-batch speedups:

* `csv`, group size `3`, without metadata: `77 ms` -> `13 ms` (`5.92x`)
* `json`, group size `3`, without metadata: `78 ms` -> `14 ms` (`5.57x`)
* `html`, group size `3`, without metadata: `77 ms` -> `14 ms` (`5.50x`)
* `xlsx`, group size `3`, without metadata: `83 ms` -> `17 ms` (`4.88x`)
* `docx`, group size `3`, without metadata: `95 ms` -> `26 ms` (`3.65x`)
* `pdf`, group size `3`, without metadata: `84 ms` -> `21 ms` (`4.00x`)

Observed pattern:

* one-file runs still pay a noticeable fixed startup cost
* grouped execution improves amortized throughput across all tested formats
* heavier OOXML/PDF rows still benefit from batching, but less dramatically
  than the smallest text/structured rows

## Product-path Benchmark Baseline

Commands:

```bash
./samples/bench_product_path.sh --help
./samples/bench_product_path.sh --smoke
./samples/bench_product_path.sh --iterations 10 --warmup 2
```

Current first-batch format coverage:

* `txt`
* `json`
* `yaml`
* `csv`
* `xlsx`
* `html`
* `docx`
* `pptx`

Current stage rows:

* `startup_probe`
* `file_read`
* `dispatch`
* `parse`
* `convert`
* `emit`
* `metadata`
* `assets`
* `total`

Current refined interpretation caveats:

* `startup_probe` is measured separately with a no-op native CLI launch
* `file_read` is a standalone probe row and is not subtracted from `parse`
* `parse` now measures direct `doc_parse` parse/model-build work for
  `txt/json/yaml/csv/xlsx`, a refined DOM/scan path for `html`, and partial
  staged converter ownership for `docx/pptx`
* `convert` now records separate lowering work for `txt/json/yaml/csv/xlsx`
  and `html`; `docx` now exposes benchmark-only `docx_final_block_build`
  rows extracted from `body_scan`, but paragraph policy and final IR block
  shape are still partially embedded upstream, while `pptx` now exposes a
  staged converter-owned grouping/caption/document-build slice
* `assets` now records measured discovery/export attribution for
  `html/docx/pptx` rather than only embedded notes

Current startup probe:

* `startup_probe`: `9.025 ms`

Slowest same-process `total` rows:

* `txt_large`: `5.755 ms`
* `docx_image_alt_title_basic`: `3.432 ms`
* `pptx_image_alt_title_basic`: `2.029 ms`
* `html_figure_figcaption_basic`: `1.091 ms`
* `xlsx_metadata_formula_or_merged_policy`: `0.992 ms`
* `yaml_metadata_nested`: `< 1 ms`
* `json_metadata_nested`: `< 1 ms`
* `csv_metadata_ragged_rows`: `< 1 ms`

Slowest product-path stage rows:

* `txt_large / convert`: `2.600 ms`
* `txt_large / txt_literal_wrap`: `2.500 ms`
* `txt_large / parse`: `2.100 ms`
* `docx_image_alt_title_basic / parse`: `1.300 ms`
* `docx_image_alt_title_basic / docx_body_scan`: `1.200 ms`
* `txt_large / emit`: `1.013 ms`
* `txt_large / txt_emit_write`: `0.885 ms`
* `pptx_image_alt_title_basic / metadata`: `0.693 ms`

Supporting observations:

* `dispatch` remains effectively negligible on this checked sample set
  (`0.003-0.004 ms`)
* standalone `file_read` probes are still small on the checked local corpus
  (`0.018-0.036 ms` for the current first-batch rows shown here)
* refined attribution now shows that `txt_large` is dominated by
  `doc_parse/text` parse plus TXT literal-markdown wrapping and final markdown
  file write, not parser work alone
* `html` now reports separate `parse`, `convert`, `html_dom_scan`,
  `html_block_lowering`, `html_asset_discovery`, and `html_asset_export`
  rows inside the product-path harness
* `docx` now reports staged `docx_package_open`, `docx_relationships`,
  `docx_styles`, `docx_numbering`, `docx_notes`, `docx_headers_footers`,
  `docx_text_boxes`, `docx_asset_map_build`, `docx_media_export`,
  `docx_asset_origin_attach`, `docx_body_xml_scan`, `docx_paragraph_scan`,
  `docx_table_scan`, `docx_inline_scan`, `docx_body_scan`,
  `docx_final_block_build`, and `docx_appended_sections` rows; `convert`
  is now partially extracted from `body_scan`, but paragraph policy and final
  IR block shape still share the current normal-path seam
* `pptx` now reports staged `pptx_package_open`, `pptx_presentation_rels`,
  `pptx_slide_parse`, `pptx_slide_relationships`, `pptx_shape_collect`,
  `pptx_text_extract`, `pptx_table_extract`, `pptx_reading_order`,
  `pptx_grouping`, `pptx_classification`, `pptx_caption_pairing`,
  `pptx_image_inventory`, `pptx_image_export`, `pptx_asset_origin_attach`,
  `pptx_notes_parse`, and `pptx_final_block_build` rows; the checked sample is
  small enough that many of these currently round to `0 ms`, but the seam is
  now visible without changing behavior

## TXT Focused Product-path Attribution

Current focused checked row:

* `txt_large / total`: `10.659 ms -> 5.755 ms`
* `txt_large / parse`: `6.400 ms -> 2.100 ms`
* `txt_large / convert`: `2.500 ms -> 2.600 ms`
* `txt_large / emit`: `1.724 ms -> 1.013 ms`

Current refined TXT substage attribution:

* `txt_literal_wrap`: `2.500 ms`
* `txt_lowering`: `0.100 ms`
* `txt_emit_blocks`: `0.129 ms`
* `txt_emit_write`: `0.885 ms`

Interpretation:

* the main remaining TXT product-path cost is no longer `doc_parse/text`
  paragraphization by itself
* the largest current TXT-specific cost is building passthrough literal
  markdown for large text bodies
* markdown string build itself is now small; the remaining emit-side cost is
  mostly markdown file write plus final same-process string handling
* these numbers are local benchmark observations, not cross-machine guarantees

Current split status:

* split parse vs convert:
  `txt`, `json`, `yaml`, `csv`, `xlsx`, `html`
* partially split with remaining combined seams:
  `docx`, `pptx`

Current combined reasons:

* `docx`:
  package/rels/styles/numbering, note/header/footer/text-box loading, asset
  discovery/export, and body-scan substages are now visible, while final
  paragraph policy and IR block shape are still only partially extracted from
  `scan_paragraph`
* `pptx`:
  package open, presentation rels, slide parse, shape/text/table extract,
  reading order, grouping, classification, caption pairing, notes parse, and
  image inventory/export are now staged, but final converter ownership still
  spans the current slide-loop document build and policy seam

Current assets notes:

* `html`:
  `asset_discovery_boundary=nodes_to_blocks`
  `asset_export_boundary=export_local_html_image`
* `docx`:
  `asset_discovery_boundary=build_docx_asset_path_map`
  `asset_export_boundary=extract_media_by_relationships`
* `pptx`:
  `asset_discovery_boundary=collect_slide_picture_shape_metas+rels_image_target_map`
  `asset_export_boundary=export_slide_images`
  `asset_metadata_attach_boundary=set_asset_origin`

## txt_large Focused Attribution

The refined product-path harness now makes the main `txt_large` ownership split
visible:

* `parse`: `2.100 ms`
  direct `doc_parse/text` document construction, including decode/newline/
  paragraph model work
* `convert`: `2.600 ms`
  `convert/txt` lowering into the product `Document` surface
* `emit`: `1.013 ms`
  Markdown emit plus markdown file write

Interpretation:

* the older unsplit `parse` row overstated parser-only ownership because it
  also included converter-local lowering work
* the refined split shows that `txt_large` is no longer just a parser hotspot;
  product-path convert and emit work are both material

## doc_parse Library Benchmark Baseline

Command:

```bash
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

Coverage in this first harness round:

* `text`
* `csv`
* `tsv`
* `json`
* `yaml`
* `xml`
* `html`
* `markdown`
* `zip`
* `ooxml`
* `epub`
* `xlsx`
* `docx`
* `pptx`

Current intentional gap:

* `pdf` is still deferred from the first library-only harness

Slowest `open/parse/scan` rows in the current full harness snapshot:

* `yaml_large / parse`: `5.974 ms`
* `docx_link_heavy / parse`: `5.098 ms`
* `json_large / parse`: `2.736 ms`
* `xlsx_formula_heavy_missing_cache / parse`: `2.687 ms`
* `csv_large / parse`: `2.410 ms`
* `markdown_large / scan`: `2.155 ms`
* `tsv_large / parse`: `2.070 ms`
* `docx_small / parse`: `1.944 ms`
* `txt_large / parse`: `1.856 ms`

Slowest `inspect` rows:

* `txt_large / inspect`: `0.672 ms`
* `ooxml_xlsx_small / inspect`: `0.203 ms`
* `zip_large_many_entries / inspect`: `0.138 ms`
* `json_large / inspect`: `0.137 ms`

Slowest `validate` rows:

* `zip_large_many_entries / validate`: `0.138 ms`
* `ooxml_xlsx_small / validate`: `0.118 ms`
* `epub_large_many_chapters / validate`: `0.006 ms`
* all other checked validation rows are below `0.01 ms` in this snapshot

Small-case rows above `10 ms` in the library harness:

* none

Rows above `10 ms` anywhere in the current library harness:

* none

Interpretation:

* the current `doc_parse` library layer no longer has an obvious `>10 ms`
  parse/open/scan hotspot on the checked local corpus
* `inspect` and `validate` remain secondary costs, not primary performance
  bottlenecks
* future performance work should shift from package-local parse cleanup toward
  repository product-path attribution unless a new library regression appears

## Completed Optimization Passes

Completed checked library-path passes so far:

* XLSX formula context reuse
* DOCX body/text-box/inline scan cleanup
* YAML line preprocessing cleanup
* text single-pass line/paragraph scan
* JSON direct char buffer plus plain-string fast path
* Markdown line-view metadata reuse

These passes all preserved:

* converter output behavior
* validation and classifier signals
* format support boundaries
* current `doc_parse` vs `convert` ownership

## Focused XLSX Formula-heavy Follow-up

Follow-up commands:

```bash
./samples/bench_doc_parse.sh --format xlsx --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/xlsx_after_parse.tsv
./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/xlsx_profile.tsv
```

Before this optimization round, the checked XLSX library baseline showed:

* `xlsx_small / parse`: `0.200 ms` avg, `0.198 ms` p50, `0.217 ms` p95
* `xlsx_formula_heavy_missing_cache / parse`: `14.367 ms` avg,
  `13.316 ms` p50, `21.843 ms` p95

After the formula-heavy parse follow-up, the focused XLSX run now shows:

* `xlsx_small / parse`: `0.222 ms` avg, `0.222 ms` p50, `0.228 ms` p95
* `xlsx_formula_heavy_missing_cache / parse`: `2.929 ms` avg,
  `2.932 ms` p50, `2.996 ms` p95

Interpretation:

* the formula-heavy row is now below the current small-case `<10 ms` library
  target band
* the small workbook row remains in the same sub-millisecond range
* the hotspot moved from “formula-heavy XLSX dominates the library harness” to
  “DOCX and YAML now lead the remaining parse-cost queue”

Current rounded XLSX internal profile breakdown for
`xlsx_formula_heavy_missing_cache`:

* `sheet:FormulaPolicy:collect_cells`: `0.900 ms` avg
* `sheet:FormulaPolicy:formula_eval`: `0.700 ms` avg
* `sheet:FormulaPolicy:read_xml`: `0.600 ms` avg
* `sheet:FormulaPolicy:resolve_cells`: `0.500 ms` avg
* `sheet:FormulaPolicy:formula_context`: `0.200 ms` avg

These profile rows are attribution aids only:

* they are stage-local and rounded to package-local millisecond resolution
* they do not change the semantic workbook model
* they should not be read as cross-machine guarantees

## Post-optimization Library Snapshot

After the focused XLSX, DOCX, YAML, text, JSON, and Markdown changes, the full
`./samples/bench_doc_parse.sh` slowest rows are now:

* `yaml_large / parse`: `8.253 ms`
* `docx_link_heavy / parse`: `7.350 ms`
* `json_large / parse`: `3.501 ms`
* `xlsx_formula_heavy_missing_cache / parse`: `3.476 ms`
* `csv_large / parse`: `3.393 ms`
* `tsv_large / parse`: `2.873 ms`
* `txt_large / parse`: `2.769 ms`
* `docx_small / parse`: `2.725 ms`
* `markdown_large / scan`: `2.686 ms`

## Remaining Library Hotspots

The current remaining library queue is now comparatively narrow:

* YAML sequence/mapping allocation and nested subset-node build work
* DOCX `body_scan`
* JSON tree build after cheaper char preparation
* TXT literal wrap if TXT becomes a priority again on the product path
* CSV/TSV large parse only if they rise in a future full-harness snapshot
* PDF still deferred from the direct library harness

This means the next optimization phase should prefer product-path attribution
over more parser-only cleanup unless new evidence re-promotes a library row.

## Focused Lightweight Large-input Follow-up

Follow-up commands:

```bash
./samples/bench_doc_parse.sh --format text --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/text_before_parse.tsv
./samples/bench_doc_parse.sh --format text --stage parse --profile text --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/text_profile_after_final.tsv
./samples/bench_doc_parse.sh --format json --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/json_before_parse.tsv
./samples/bench_doc_parse.sh --format json --stage parse --profile json --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/json_profile_after.tsv
./samples/bench_doc_parse.sh --format markdown --stage scan --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/markdown_before_scan.tsv
./samples/bench_doc_parse.sh --format markdown --stage scan --profile markdown --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/markdown_profile_after.tsv
```

Focused before/after rows:

* `txt_small / parse`: `0.004 ms -> 0.002 ms`
* `txt_large / parse`: `4.991 ms -> 1.952 ms`
* `json_small / parse`: `0.002 ms -> 0.003 ms`
* `json_large / parse`: `4.247 ms -> 2.805 ms`
* `markdown_small / scan`: `0.004 ms -> 0.003 ms`
* `markdown_large / scan`: `3.391 ms -> 2.181 ms`

Current rounded internal profile breakdowns on the checked large samples:

* `txt_large`
  * `newline_scan`: `1.000 ms`
  * `build_document`: `1.000 ms`
  * `line_build`: `0.200 ms`
  * `paragraph_build`: `0.000 ms`
* `json_large`
  * `tokenize`: `1.000 ms`
  * `parse_value`: `1.800 ms`
  * `parse_object`: `4.100 ms`
  * `parse_array`: `2.100 ms`
  * `parse_string`: `0.800 ms`
  * `parse_number`: `0.300 ms`
* `markdown_large`
  * `normalize_lines`: `0.800 ms`
  * `scan_lines`: `1.200 ms`
  * `block_classify`: `1.100 ms`
  * `build_document`: `0.200 ms`

Interpretation:

* the text improvement came from collapsing newline normalization, line
  inventory construction, and paragraph reconstruction into one pass without
  changing the normalized source-native model
* the JSON improvement came from cheaper normalized char preparation and a
  fast path for plain strings without changing JSON validity rules or value
  semantics
* the Markdown improvement came from precomputing trimmed and left-trimmed
  line views so the scanner stops re-trimming and re-classifying the same raw
  line data
* these profile rows remain attribution aids only; they do not widen format
  support or change converter ownership boundaries

## Focused DOCX Link-heavy Follow-up

Follow-up commands:

```bash
./samples/bench_doc_parse.sh --format docx --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/docx_before_parse.tsv
./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/docx_profile_before.tsv
./samples/bench_doc_parse.sh --format docx --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/docx_after_parse.tsv
./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/docx_profile_after.tsv
```

Before this optimization round, the checked DOCX library baseline showed:

* `docx_small / parse`: `2.887 ms` avg, `2.898 ms` p50, `2.922 ms` p95
* `docx_link_heavy / parse`: `8.735 ms` avg, `8.786 ms` p50,
  `8.861 ms` p95

The focused DOCX profile baseline before optimization showed:

* `docx_small / parse`: `2.701 ms` avg
* `docx_link_heavy / parse`: `8.216 ms` avg
* `docx_link_heavy` stage breakdown:
  * `body_scan`: `5.200 ms`
  * `text_boxes`: `1.600 ms`
  * `inline_scan`: `0.600 ms`
  * `relationships`: `0.500 ms`
  * `hyperlink_resolution`: `0.200 ms`

After the link-heavy parse follow-up, the focused DOCX run now shows:

* `docx_small / parse`: `1.867 ms` avg, `1.865 ms` p50, `1.891 ms` p95
* `docx_link_heavy / parse`: `4.985 ms` avg, `4.930 ms` p50,
  `5.046 ms` p95

Current rounded DOCX internal profile breakdown for `docx_link_heavy`:

* `body_scan`: `2.500 ms`
* `inline_scan`: `0.600 ms`
* `headers_footers`: `0.200 ms`
* `document_xml`: `0.100 ms`
* `styles`: `0.100 ms`
* `text_boxes`: `0.000 ms`
* `hyperlink_resolution`: `0.000 ms`
* `media_resolution`: `0.000 ms`

Interpretation:

* the biggest win came from reducing repeated body-level scanning and skipping
  no-op text-box scans on samples that do not contain any text boxes
* relationship lookup was never the primary hotspot on this sample
* the DOCX semantic model, relationship validation, and `convert/docx`
  boundary stayed unchanged
* the new profile helper only adds attribution rows for benchmarking; it does
  not change the stable DOCX parse API surface

## Focused YAML Large Follow-up

Follow-up commands:

```bash
./samples/bench_doc_parse.sh --format yaml --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/yaml_before_parse.tsv
./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 2 --warmup 0 --output .tmp/bench/doc_parse/yaml_profile_before.tsv
./samples/bench_doc_parse.sh --format yaml --stage parse --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/yaml_after_parse.tsv
./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2 --output .tmp/bench/doc_parse/yaml_profile_after.tsv
```

Before this optimization round, the focused YAML parse run showed:

* `yaml_small / parse`: `0.003 ms` avg, `0.003 ms` p50, `0.004 ms` p95
* `yaml_large / parse`: `6.907 ms` avg, `6.980 ms` p50, `7.032 ms` p95

The focused YAML profile baseline before optimization showed:

* `yaml_large / parse`: `7.010 ms` avg on the profiled run
* `yaml_large` stage breakdown:
  * `parse_sequence`: `5.500 ms`
  * `scan_lines`: `3.500 ms`
  * `parse_nodes`: `3.000 ms`
  * `parse_mapping`: `3.000 ms`
  * `parse_scalar`: `1.000 ms`
  * `normalize_lines`: `0.500 ms`

After the large-parse follow-up, the focused YAML run now shows:

* `yaml_small / parse`: `0.009 ms` avg, `0.009 ms` p50, `0.009 ms` p95
* `yaml_large / parse`: `5.925 ms` avg, `5.930 ms` p50, `6.021 ms` p95

Current rounded YAML internal profile breakdown for `yaml_large`:

* `parse_sequence`: `4.100 ms`
* `parse_nodes`: `2.700 ms`
* `parse_mapping`: `2.700 ms`
* `normalize_lines`: `1.900 ms`
* `scan_lines`: `1.300 ms`
* `parse_scalar`: `0.700 ms`

Interpretation:

* the main win came from replacing full-text newline normalization/splitting
  with cheaper raw-line collection and reducing repeated trim/copy work in the
  hot subset paths
* the YAML subset boundary, fail-closed behavior, inspect surface, and
  `convert/yaml` boundary stayed unchanged
* the new profile helper only adds attribution rows for benchmarking; it does
  not change the stable YAML parse API surface

## What This Baseline Can And Cannot Tell Us

This baseline can tell us:

* current native normal-path timing on the checked local corpus
* which rows are currently slowest at the repository product level
* that startup cost is material for small rows
* that batch amortization is real and measurable
* current direct `doc_parse/*` package timing for the first library-harness
  coverage set

This baseline still cannot yet tell us directly:

* a perfect `parse` vs `convert` split for all current normal-path formats
* a perfect standalone `assets` stage for current HTML/DOCX/PPTX converter
  flows
* full-library coverage for every package, especially `pdf`
* cross-machine release SLOs from one checked local snapshot

## Next Step

The next measurement step is product-path attribution refinement:

* keep the current `startup_probe`, `dispatch`, `emit`, `metadata`, and
  same-process `total` rows
* split `parse` vs `convert` where the shared normal path allows it safely
* break out current HTML/DOCX/PPTX asset work from the combined parse path
* add `pdf` only when its current product path can be instrumented without
  distorting the measurement contract

## Current Decision

This round is baseline-sync only after the focused parser and TXT product-path
passes. The next step is attribution-guided product-path work rather than more
blind parser churn.

The next optimization round should start from the remaining hotspots and
measurement gaps listed in
[`docs/performance-roadmap.md`](./performance-roadmap.md).
