# Benchmark Baseline

This document records the current checked-in smoke benchmark baseline for
`samples/scripts/bench_smoke.sh`.

It is a same-machine reference point, not a hard performance SLA.

The current smoke harness is an internal benchmark harness. It is useful for
same-machine trend tracking, but it is not the same thing as a prebuilt
native-CLI speed claim.

## Benchmark Scope

The harness supports the checked-in corpus under:

* `smoke`
* `image`
* `metadata`
* `extended`

The checked-in baseline in this document is the `smoke` tier used for the
release-polish check.

The checked-in smoke corpus includes:

* OOXML
* PDF
* HTML
* Structured data: CSV / TSV / JSON / YAML / XML
* Text-like: TXT / Markdown
* Container / ebook: ZIP / EPUB

For TXT hardening work, the smoke corpus now includes:

* `txt_paragraphs`
* `txt_small`
* `txt_medium`
* `txt_large`

For Markdown hardening work, the smoke corpus now includes:

* `markdown_frontmatter_passthrough`
* `markdown_small`
* `markdown_medium`
* `markdown_large`

For CSV / TSV hardening work, the smoke corpus now includes:

* `csv_ragged_rows`
* `csv_small`
* `csv_medium`
* `csv_large`
* `tsv_basic`
* `tsv_small`
* `tsv_medium`
* `tsv_large`

For JSON hardening work, the smoke corpus now includes:

* `json_nested_object`
* `json_small`
* `json_medium`
* `json_large`
* `json_array_objects_large`

For YAML hardening work, the smoke corpus now includes:

* `yaml_nested_mapping`
* `yaml_small`
* `yaml_medium`
* `yaml_large`
* `yaml_sequence_mappings_large`

For XML hardening work, the smoke corpus now includes:

* `xml_basic`
* `xml_small`
* `xml_medium`
* `xml_large`

For HTML H2-complete support coverage, the smoke corpus now includes:

* `html_mixed`
* `html_small`
* `html_medium`
* `html_large`
* `html_table_large`
* `html_mixed_content_large`

For XLSX H2-complete support coverage, the smoke corpus now includes:

* `xlsx_multi_sheet_mixed`
* `xlsx_small`
* `xlsx_medium`
* `xlsx_large`
* `xlsx_multi_sheet_large`
* `xlsx_sparse_large`

For ZIP H2-complete container coverage, the smoke corpus now includes:

* `zip_basic_structured`
* `zip_small`
* `zip_medium`
* `zip_large_many_entries`
* `zip_mixed_supported_large`
* `zip_assets_many_images`

For EPUB H2-complete ebook coverage, the smoke corpus now includes:

* `epub_small`
* `epub_medium`
* `epub_large_many_chapters`
* `epub_assets_many_images`

For DOCX H2-complete support coverage, the smoke corpus now includes:

* `docx_small`
* `docx_medium`
* `docx_large`
* `docx_tables_large`
* `docx_images_many`
* `docx_lists_large`

For PPTX H2-complete support coverage, the smoke corpus now includes:

* `pptx_small`
* `pptx_medium`
* `pptx_large`
* `pptx_images_many`
* `pptx_tables_large`
* `pptx_layout_dense`
* `pptx_many_slides`

For PDF H2-complete support coverage, the smoke corpus now includes:

* `pdf_text_simple`
* `pdf_text_multipage`
* `pdf_heading_basic`
* `pdf_heading_false_positive_guard`
* `pdf_repeated_header_footer`
* `pdf_repeated_header_footer_variants`
* `pdf_cross_page_merge`
* `pdf_cross_page_no_merge`
* `pdf_two_column_negative`

## Baseline Command

```bash
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/scripts/bench_smoke.sh --kind smoke
```

Artifacts are written under:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
$TMP_ROOT/bench/smoke
```

Main outputs:

* `results.jsonl`
* `summary.tsv`

These artifacts are temporary local outputs for manual inspection and are not
checked in.

## Runner Note

The smoke harness now builds once and resolves the repository runner in this
order:

* `MARKITDOWN_CLI`
* probe-validated prebuilt native CLI
* fallback `moon run`

This keeps smoke, sample validation, and comparison runs on the same
native-preferred policy while preserving `moon run` as a functional fallback.
When smoke falls back to `moon run`, the reported elapsed time includes MoonBit
wrapper overhead and should not be read as a native-only speed claim.

Current smoke local outputs also record:

* `runner_kind`
* `runner_label`

so warning checks can distinguish native runs from wrapper-affected fallback
runs.

## Current PDF Smoke Baseline

This PDF refresh was captured with the same smoke command above, using:

* warmup: `1`
* iterations: `3`
* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan 2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Date (UTC): `2026-05-03T04:23:13Z`
* Git revision: `f268ac2`
* Timer precision: `ms`

### PDF Summary

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
pdf	pdf_text_simple	3	0	379	380	387	382	272	0
pdf	pdf_text_multipage	3	0	375	378	383	378.7	37	0
pdf	pdf_heading_basic	3	0	386	388	395	389.7	257	0
pdf	pdf_heading_false_positive_guard	3	0	382	382	387	383.7	336	0
pdf	pdf_repeated_header_footer	3	0	387	391	398	392	142	0
pdf	pdf_repeated_header_footer_variants	3	0	423	439	457	439.7	745	0
pdf	pdf_cross_page_merge	3	0	386	397	397	393.3	313	0
pdf	pdf_cross_page_no_merge	3	0	382	386	389	385.7	246	0
pdf	pdf_two_column_negative	3	0	384	386	396	388.7	412	0
```

### PDF Notes

* coverage is now broader than the previous single `text_simple` case
* current smoke rows cover basic text, multipage text, heading precision,
  false-positive heading guard, repeated edge noise cleanup, cross-page merge,
  cross-page no-merge, and two-column negative behavior
* this remains a text-PDF baseline; it does not measure OCR, image-heavy OCR
  fallback, or LLM/vision paths

## Environment

This baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan 2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Shell: `/bin/bash`
* Date (UTC): `2026-05-03T04:23:13Z`
* Git revision: `f268ac2`
* Timer precision: `ms`

## Summary

The checked-in baseline summary below is a historical local sample from the
`summary.tsv` produced by the command above. Newer smoke runs may include the
additional trailing columns `runner_kind` and `runner_label`:

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
docx	golden	3	0	384	390	395	389.7	1445	1
docx	docx_small	3	0	379	383	387	383	296	0
docx	docx_medium	3	0	377	379	391	382.3	179	0
docx	docx_large	3	0	381	455	470	435.3	1445	1
docx	docx_tables_large	3	0	364	367	370	367	61	0
docx	docx_images_many	3	0	368	372	373	371	59	1
docx	docx_lists_large	3	0	378	379	390	382.3	188	0
pptx	pptx_small	3	0	371	377	378	375.3	81	0
pptx	pptx_medium	3	0	380	382	388	383.3	177	0
pptx	pptx_large	3	0	374	377	381	377.3	310	0
pptx	pptx_images_many	3	0	371	374	375	373.3	194	3
pptx	pptx_tables_large	3	0	375	379	388	380.7	145	0
pptx	pptx_layout_dense	3	0	375	375	401	383.7	105	0
pptx	pptx_many_slides	3	0	378	380	393	383.7	91	0
xlsx	xlsx_multi_sheet_mixed	3	0	374	378	383	378.3	301	0
xlsx	xlsx_small	3	0	367	376	380	374.3	281	0
xlsx	xlsx_medium	3	0	376	378	391	381.7	3843	0
xlsx	xlsx_large	3	0	585	586	587	586	18442	0
xlsx	xlsx_multi_sheet_large	3	0	401	402	404	402.3	9498	0
xlsx	xlsx_sparse_large	3	0	370	371	378	373	1136	0
zip	zip_basic_structured	3	0	378	386	387	383.7	398	0
zip	zip_small	3	0	382	385	392	386.3	134	0
zip	zip_medium	3	0	400	408	425	411	8340	0
zip	zip_large_many_entries	3	0	490	497	497	494.7	30374	0
zip	zip_mixed_supported_large	3	0	410	413	426	416.3	7619	0
zip	zip_assets_many_images	3	0	388	389	399	392	677	0
epub	epub_small	3	0	379	381	392	384	249	0
epub	epub_medium	3	0	392	395	403	396.7	1249	0
epub	epub_large_many_chapters	3	0	408	419	420	415.7	4535	0
epub	epub_assets_many_images	3	0	399	403	403	401.7	1999	0
pdf	pdf_text_simple	3	0	379	380	387	382	272	0
pdf	pdf_text_multipage	3	0	375	378	383	378.7	37	0
pdf	pdf_heading_basic	3	0	386	388	395	389.7	257	0
pdf	pdf_heading_false_positive_guard	3	0	382	382	387	383.7	336	0
pdf	pdf_repeated_header_footer	3	0	387	391	398	392	142	0
pdf	pdf_repeated_header_footer_variants	3	0	423	439	457	439.7	745	0
pdf	pdf_cross_page_merge	3	0	386	397	397	393.3	313	0
pdf	pdf_cross_page_no_merge	3	0	382	386	389	385.7	246	0
pdf	pdf_two_column_negative	3	0	384	386	396	388.7	412	0
html	html_mixed	3	0	373	380	394	382.3	87	0
html	html_small	3	0	378	387	387	384	61	0
html	html_medium	3	0	376	384	384	381.3	192	0
html	html_large	3	0	382	383	394	386.3	388	0
html	html_table_large	3	0	371	376	385	377.3	206	0
html	html_mixed_content_large	3	0	382	383	390	385	165	0
csv	csv_ragged_rows	3	0	375	391	457	407.7	115	0
csv	csv_small	3	0	393	394	513	433.3	49	0
csv	csv_medium	3	0	388	403	405	398.7	2785	0
csv	csv_large	3	0	509	510	522	513.7	65527	0
tsv	tsv_basic	3	0	387	389	398	391.3	70	0
tsv	tsv_small	3	0	383	394	401	392.7	49	0
tsv	tsv_medium	3	0	390	392	411	397.7	2485	0
tsv	tsv_large	3	0	495	499	516	503.3	63727	0
txt	txt_paragraphs	3	0	385	391	406	394	57	0
txt	txt_small	3	0	393	393	404	396.7	43	0
txt	txt_medium	3	0	395	396	407	399.3	3981	0
txt	txt_large	3	0	603	607	609	606.3	72983	0
xml	xml_basic	3	0	390	398	401	396.3	47	0
xml	xml_small	3	0	394	410	410	404.7	109	0
xml	xml_medium	3	0	397	399	419	405	693	0
xml	xml_large	3	0	397	399	402	399.3	1712	0
json	json_nested_object	3	0	393	396	403	397.3	121	0
json	json_small	3	0	391	396	404	397	65	0
json	json_medium	3	0	392	396	407	398.3	2666	0
json	json_large	3	0	655	662	667	661.3	86120	0
json	json_array_objects_large	3	0	537	537	538	537.3	33590	0
yaml	yaml_nested_mapping	3	0	415	420	433	422.7	120	0
yaml	yaml_small	3	0	416	418	424	419.3	65	0
yaml	yaml_medium	3	0	423	427	437	429	2854	0
yaml	yaml_large	3	0	653	658	665	658.7	55735	0
yaml	yaml_sequence_mappings_large	3	0	481	484	498	487.7	21522	0
markdown	markdown_frontmatter_passthrough	3	0	430	440	448	439.3	107	0
markdown	markdown_small	3	0	429	430	448	435.7	24	0
markdown	markdown_medium	3	0	434	435	445	438	205	0
markdown	markdown_large	3	0	507	508	521	512	20503	0
```

## Interpretation

Use this file to:

* detect large regressions on the same machine
* compare runs with the same corpus and similar environment
* reason about relative benchmark tiers

Do not use it as:

* a strict pass/fail gate
* a portability claim across machines
* a guarantee that timings stay stable when the corpus changes
