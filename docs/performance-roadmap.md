# Performance Roadmap

This page turns the current benchmark baseline into a concrete optimization
plan for `doc_parse/*` and the surrounding converter stack.

## Budget By Format Group

### Lightweight text and structured formats

Formats:

* TXT
* Markdown scanner
* CSV
* TSV
* JSON
* YAML
* XML
* HTML

Budget:

* small library path target: `<10ms` where realistic on a same-machine native
  build
* CLI timing tracked separately because startup and file I/O can dominate

### Package / container formats

Formats:

* ZIP
* EPUB

Budget:

* small package inspect/open target: roughly `<10-20ms` when native runner and
  local I/O are favorable
* archive size, compression mix, and part inventory can move the result

### OOXML semantic formats

Formats:

* XLSX
* DOCX
* PPTX

Budget:

* establish baseline first
* optimize small native cases toward roughly `<10-30ms` only where realistic
* treat relationship/media scans, XML parsing, and converter policy as
  separate possible hotspots

### Native text-PDF

Formats:

* PDF native text path

Budget:

* separate budget from lightweight formats
* never mix OCR/scanned-PDF expectations into the native text-PDF target

## Current Hotspot Tracking

This page now tracks two benchmark families:

* repository-level CLI/product-path rows
* direct `doc_parse/*` library rows from `./samples/bench_doc_parse.sh`

Track each hotspot by:

* format
* sample
* current measured timing
* suspected bottleneck
* owner layer: `doc_parse` / `convert` / emitter / metadata-assets / CLI
* next action

## doc_parse Library Hotspot Attribution

Current highest-priority library rows:

* `doc_parse/yaml`
  `yaml_large / parse / 6.953 ms -> 5.974 ms`
  owner confirmed: line preparation plus repeated short mapping/scalar trim
  and copy work on a large sequence-of-mappings sample
  remaining breakdown on the checked sample:
  `parse_sequence ~4.1 ms`, `parse_nodes ~2.7 ms`,
  `parse_mapping ~2.7 ms`, `normalize_lines ~1.9 ms`,
  `scan_lines ~1.3 ms`
  next action: keep YAML as the lead library hotspot, but reassess whether
  deeper parser allocation work is worth it before moving on to CSV/TSV or a
  more surgical second YAML pass

* `doc_parse/text`
  `txt_large / parse / 3.966 ms -> 1.856 ms`
  owner confirmed: repeated newline normalization, line splitting, and
  paragraph reconstruction before the single-pass cleanup
  next action: keep on watch only; it is no longer a lead hotspot

* `doc_parse/json`
  `json_large / parse / 3.605 ms -> 2.736 ms`
  owner confirmed: normalized char preparation plus plain-string hot-path
  allocation
  remaining breakdown on the checked sample:
  `parse_value ~1.8 ms`, `tokenize ~1.0 ms`, `parse_string ~0.8 ms`
  next action: keep on watch only; if JSON comes back to the top, inspect
  object/array allocation churn more deeply

* `doc_parse/markdown`
  `markdown_large / scan / 3.130 ms -> 2.155 ms`
  owner confirmed: repeated trim/left-trim/block classification on the same
  raw lines before line-view precomputation
  remaining breakdown on the checked sample:
  `scan_lines ~1.2 ms`, `block_classify ~1.1 ms`,
  `normalize_lines ~0.8 ms`
  next action: keep on watch only; it is no longer a lead hotspot

Recent focused follow-up results:

* `doc_parse/xlsx`
  `xlsx_formula_heavy_missing_cache / parse / 14.367 ms -> 2.687 ms`
  owner confirmed: SpreadsheetML formula-heavy parse path, specifically
  repeated per-formula sheet-context rebuild before the current fix
  remaining breakdown on the checked sample:
  `collect_cells ~0.9 ms`, `formula_eval ~0.7 ms`, `read_xml ~0.6 ms`,
  `resolve_cells ~0.5 ms`, `formula_context ~0.2 ms`
  next action: keep XLSX on the watch list, but shift active optimization
  priority to YAML first

* `doc_parse/docx`
  `docx_link_heavy / parse / 8.735 ms -> 5.098 ms`
  owner confirmed: repeated body-level XML cleanup/traversal and no-op
  text-box scanning on a link-heavy sample without text boxes, not
  relationship lookup
  remaining breakdown on the checked sample:
  `body_scan ~2.6 ms`, `hyperlink_resolution ~0.3 ms`,
  `headers_footers ~0.2 ms`, `inline_scan ~0.2 ms`
  next action: keep DOCX on the watch list, but shift active optimization
  priority to YAML first and then reassess CSV/TSV, JSON, and text allocation
  costs

* `doc_parse/text/json/markdown`
  focused lightweight large-input follow-up is now complete
  current checked large rows:
  `txt_large / parse / 1.856 ms`,
  `json_large / parse / 2.736 ms`,
  `markdown_large / scan / 2.155 ms`
  next action: no immediate second pass unless a future baseline regression or
  new evidence re-promotes one of these rows into the top queue

Lower-priority library observations:

* `inspect` and `validate` rows are mostly sub-`1 ms`
* `zip`, `ooxml`, and `epub` `open` rows are currently sub-`1 ms` on the
  checked small/large manifest files
* the current library baseline still suggests the main optimization headroom is
  in parse/scan stages, not in inspect/validate traversal
* the XLSX formula-heavy row is no longer the lead library hotspot after the
  focused context-reuse fix
* the DOCX link-heavy row is no longer the lead library hotspot after the
  focused body-scan and text-box-scan cleanup
* the YAML large row still leads the remaining library parse-cost queue after
  the current low-risk cleanup
* DOCX still leads the OOXML semantic queue after XLSX was substantially
  reduced
* CSV/TSV are now more competitive with the lightweight hotspots than
  Markdown or text, so the next lightweight follow-up should be chosen from
  fresh evidence rather than from the old pre-optimization ordering

## Completed Optimization Passes

Completed parser/scanner cleanup passes:

* XLSX formula-heavy parse: per-sheet formula context reuse
* DOCX link-heavy parse: body/text-box/inline scan cleanup
* YAML large parse: line preprocessing cleanup
* text large parse: single-pass newline/line/paragraph scan
* JSON large parse: direct normalized char buffer plus plain-string fast path
* Markdown large scan: line-view metadata reuse

These are complete enough that the roadmap should now bias toward
product-path attribution, not more package-local churn by default.

## CLI/Product-Path Interpretation

Current CLI smoke and batch-profile numbers still matter because they include:

* startup
* file I/O
* converter lowering
* Markdown / metadata / assets work

That means:

* rows above `10 ms` in CLI smoke are not automatically `doc_parse` problems
* the library harness is the better owner-attribution tool for parser work
* PDF and output-heavy HTML/EPUB/ZIP rows still need repo-level measurement in
  addition to package-local timing

## Product-path Attribution

The repository now has a refined staged benchmark for the normal product
path:

```bash
./samples/bench_product_path.sh --iterations 10 --warmup 2
```

Implemented stages:

* `startup_probe`
* `file_read`
* `dispatch`
* `parse`
* `convert`
* `emit`
* `metadata`
* `assets`
* `total`

Planned ownership split:

* `startup_probe`, `file_read`, `dispatch`: CLI / product-path harness
* `parse`: direct `doc_parse` parse/model-build work where the current seam is
  already safely split; otherwise the real combined normal-path parse entry
* `convert`: model lowering / IR construction where the seam is safely split;
  otherwise recorded as a partial split with benchmark-only substages where
  the current normal-path seam still mixes converter ownership
* `emit`: Markdown/string emission plus markdown write
* `metadata`: sidecar construction plus write
* `assets`: discovery/export notes where possible, with measured rows for
  `html/docx/pptx`; some export work still remains coupled to current
  converter-local seams

Implemented current format set:

* `txt`
* `json`
* `yaml`
* `csv`
* `xlsx`
* `html`
* `docx`
* `pptx`

## Current TXT Product-path Follow-up

Focused checked TXT product-path row:

* `txt_large / total / 10.659 ms -> 5.755 ms`
* `txt_large / parse / 6.400 ms -> 2.100 ms`
* `txt_large / convert / 2.500 ms -> 2.600 ms`
* `txt_large / emit / 1.724 ms -> 1.013 ms`

Interpretation:

* the parser-side portion was reduced by skipping redundant shared cleanup on
  already-clean large text and by avoiding another whole-document string copy
  in the normalized text parser path
* the remaining largest TXT-specific cost is now `txt_literal_wrap`
* `emit` is no longer dominated by markdown-string construction; most of the
  remaining cost is `txt_emit_write`

Next action:

* do not start another TXT parser pass immediately
* if TXT returns to the top of the product-path queue, the next low-risk seam
  to inspect is literal passthrough construction, not source parsing

Planned output schema:

* `format`
* `sample`
* `stage`
* `iterations`
* `total_ms`
* `avg_ms`
* `p50_ms`
* `p95_ms`
* `max_ms`
* `bytes`
* `notes`

## Product-path Attribution Current Split

Current split-supported formats:

* `txt`
* `json`
* `yaml`
* `csv`
* `xlsx`
* `html`

Current partially split formats with remaining combined seams:

* `docx`
* `pptx`

Current blockers:

* `docx`:
  package/rels/styles/numbering, notes/header/footer/text-box loading, asset
  discovery/export, and body-scan substages are now visible, but final
  paragraph policy and IR block shape are still only partially extracted from
  `scan_paragraph`
* `pptx`:
  package open, presentation rels, slide parse, shape/text/table extract,
  reading order, grouping, classification, caption pairing, notes parse, and
  image inventory/export are now staged, but final converter ownership still
  spans the current slide-loop document build and policy seam

Current refined assets notes:

* `html`:
  `asset_discovery_boundary=nodes_to_blocks`,
  `asset_export_boundary=export_local_html_image`
* `docx`:
  `asset_discovery_boundary=build_docx_asset_path_map`,
  `asset_export_boundary=extract_media_by_relationships`
* `pptx`:
  `asset_discovery_boundary=collect_slide_picture_shape_metas+rels_image_target_map`,
  `asset_export_boundary=export_slide_images`,
  `asset_metadata_attach_boundary=set_asset_origin`

## Next Product-path Work

Immediate next attribution targets:

* keep `html` on the current split path and validate that `dom_scan`,
  `block_lowering`, `asset_discovery`, and `asset_export` stay attributable
  without changing output policy
* further refine `docx` until `body_scan` vs final converter lowering is more
  explicit without changing appended-section behavior
* further refine `pptx` until grouping/classification/document-build ownership
  is more explicit without changing reading-order/caption/export behavior
* keep `startup_probe` separate from same-process `total`
* expand the manifest carefully only after the current eight-format split is
  stable

Immediate next optimization candidates after attribution is stable:

* `docx`:
  now that package/rels/notes/assets/body-scan substages are visible, inspect
  whether paragraph policy / final IR block shape can be separated more
  cleanly from `docx_body_scan` without changing output
* `pptx`:
  refine grouping/classification/document-build ownership before any
  converter-local optimization pass
* `yaml`:
  revisit allocation-heavy sequence/mapping work only if it remains the top
  library hotspot after product-path work is clearer

Current checked observations:

* `startup_probe`: `9.025 ms`
* slowest same-process total rows:
  * `txt_large`: `5.755 ms`
  * `docx_image_alt_title_basic`: `3.432 ms`
  * `pptx_image_alt_title_basic`: `2.029 ms`
  * `html_figure_figcaption_basic`: `1.091 ms`
  * `xlsx_metadata_formula_or_merged_policy`: `0.992 ms`
* slowest measured stage rows:
  * `txt_large / convert`: `2.600 ms`
  * `txt_large / parse`: `2.100 ms`
  * `docx_image_alt_title_basic / parse`: `1.300 ms`
  * `docx_image_alt_title_basic / docx_body_scan`: `1.200 ms`
  * `txt_large / emit`: `1.013 ms`
  * `pptx_image_alt_title_basic / metadata`: `0.693 ms`

Current interpretation:

* the benchmark is real and uses a hidden benchmark-only CLI entrypoint
* it does not change normal CLI behavior or `samples/bench.sh`
* `file_read` is still a standalone probe row
* `parse` is now cleanly split from `convert` for
  `txt/json/yaml/csv/xlsx/html`
* `docx/pptx` still keep partial combined seams
* `docx` now already exposes `docx_body_xml_scan`, `docx_paragraph_scan`,
  `docx_table_scan`, `docx_inline_scan`, `docx_final_block_build`, and
  `docx_appended_sections` benchmark rows inside that partial seam
* `pptx` now already exposes `pptx_presentation_rels`, `pptx_text_extract`,
  `pptx_reading_order`, `pptx_grouping`, `pptx_classification`,
  `pptx_image_inventory`, `pptx_asset_origin_attach`, and
  `pptx_final_block_build` benchmark rows inside that partial seam; on the
  tiny checked sample, several of them currently round to `0 ms`
* `assets` attribution is now visible for `html/docx/pptx`, but some current
  discovery/export work still shares converter-local seams

Next attribution refinement:

* keep HTML on the current split path while refining DOCX/PPTX final converter
  ownership
* further separate DOCX final paragraph policy / IR block shape from the now
  visible `docx_body_scan` and `docx_final_block_build` rows where the current
  normal path safely allows it
* further separate PPTX grouping/classification/document-build ownership where
  the current normal path safely allows it
* keep the benchmark-only instrumentation hidden and out of the default CLI UX

## Optimization Stages

### P1: Measurement and obvious allocation fixes

Focus:

* better baseline reporting
* keep library and CLI harnesses side by side
* same-part repeated-read audit
* obvious string-concatenation or repeated-scan cleanup
* no behavior changes and no safety-boundary weakening

### P2: Parser / emitter hot path optimization

Focus:

* format-local parser hotspots
* repeated relationship lookup or XML walk reductions
* lower allocation churn in clearly bounded loops
* keep validation and safety behavior intact

### P3: Regression guard and comparison refinement

Focus:

* lightweight perf regression guard for checked-in rows
* clearer format-group summaries
* better library-vs-CLI interpretation
* comparison and loss analysis where mainstream tools are relevant

## Release Rule

Do not accept a performance win that:

* changes checked conversion output
* removes validation or classifier signal
* weakens unsafe-path / XXE / script / external-fetch boundaries
* introduces opaque global caches without a clearly documented safety story
