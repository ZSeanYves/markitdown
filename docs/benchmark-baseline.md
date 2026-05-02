# Benchmark Baseline

This document records the current checked-in smoke benchmark baseline for
`samples/bench_smoke.sh`.

It is a same-machine reference point, not a hard performance SLA.

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

For HTML H1/H2 review, the smoke corpus now includes:

* `html_mixed`
* `html_small`
* `html_medium`
* `html_large`
* `html_table_large`
* `html_mixed_content_large`

For XLSX H1/H2 review, the smoke corpus now includes:

* `xlsx_multi_sheet_mixed`
* `xlsx_small`
* `xlsx_medium`
* `xlsx_large`
* `xlsx_multi_sheet_large`
* `xlsx_sparse_large`

For ZIP H1/H2 container review, the smoke corpus now includes:

* `zip_basic_structured`
* `zip_small`
* `zip_medium`
* `zip_large_many_entries`
* `zip_mixed_supported_large`
* `zip_assets_many_images`

For EPUB H1/H2 ebook review, the smoke corpus now includes:

* `epub_small`
* `epub_medium`
* `epub_large_many_chapters`
* `epub_assets_many_images`

For DOCX H2 market-parity review, the smoke corpus now includes:

* `docx_small`
* `docx_medium`
* `docx_large`
* `docx_tables_large`
* `docx_images_many`
* `docx_lists_large`

For PPTX H2 layout-quality review, the smoke corpus now includes:

* `pptx_small`
* `pptx_medium`
* `pptx_large`
* `pptx_images_many`
* `pptx_tables_large`
* `pptx_layout_dense`
* `pptx_many_slides`

## Baseline Command

```bash
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/bench_smoke.sh --kind smoke
```

Artifacts are written under:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
$TMP_ROOT/bench/smoke
```

Main outputs:

* `results.jsonl`
* `summary.tsv`

## Environment

This baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan 2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Shell: `/bin/bash`
* Date (UTC): `2026-05-02T13:51:31Z`
* Git revision: `e9aa483`
* Timer precision: `ms`

## Summary

The checked-in baseline summary is the `summary.tsv` produced by the command
above:

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
docx	golden	3	0	371	373	376	373.3	1445	1
docx	docx_small	3	0	369	373	377	373	296	0
docx	docx_medium	3	0	365	367	373	368.3	179	0
docx	docx_large	3	0	370	370	373	371	1445	1
docx	docx_tables_large	3	0	349	354	368	357	61	0
docx	docx_images_many	3	0	355	357	372	361.3	59	1
docx	docx_lists_large	3	0	368	369	382	373	188	0
pptx	pptx_small	3	0	358	362	365	361.7	81	0
pptx	pptx_medium	3	0	370	379	381	376.7	177	0
pptx	pptx_large	3	0	362	363	379	368	310	0
pptx	pptx_images_many	3	0	360	361	363	361.3	194	3
pptx	pptx_tables_large	3	0	383	386	387	385.3	145	0
pptx	pptx_layout_dense	3	0	368	373	384	375	105	0
pptx	pptx_many_slides	3	0	367	367	395	376.3	91	0
xlsx	xlsx_multi_sheet_mixed	3	0	368	369	372	369.7	301	0
xlsx	xlsx_small	3	0	362	372	375	369.7	281	0
xlsx	xlsx_medium	3	0	373	374	387	378	3843	0
xlsx	xlsx_large	3	0	578	581	585	581.3	18442	0
xlsx	xlsx_multi_sheet_large	3	0	389	393	399	393.7	9498	0
xlsx	xlsx_sparse_large	3	0	358	363	369	363.3	1136	0
zip	zip_basic_structured	3	0	367	373	392	377.3	398	0
zip	zip_small	3	0	369	369	374	370.7	134	0
zip	zip_medium	3	0	398	400	411	403	8340	0
zip	zip_large_many_entries	3	0	475	490	509	491.3	30374	0
zip	zip_mixed_supported_large	3	0	398	407	427	410.7	7619	0
zip	zip_assets_many_images	3	0	380	381	386	382.3	677	0
epub	epub_small	3	0	376	378	386	380	249	0
epub	epub_medium	3	0	385	388	399	390.7	1249	0
epub	epub_large_many_chapters	3	0	392	401	413	402	4535	0
epub	epub_assets_many_images	3	0	391	396	416	401	1999	0
pdf	text_simple	3	0	369	379	395	381	272	0
html	html_mixed	3	0	366	368	369	367.7	87	0
html	html_small	3	0	364	375	379	372.7	61	0
html	html_medium	3	0	360	368	377	368.3	192	0
html	html_large	3	0	363	364	393	373.3	388	0
html	html_table_large	3	0	366	368	375	369.7	206	0
html	html_mixed_content_large	3	0	361	365	384	370	165	0
csv	csv_ragged_rows	3	0	363	364	375	367.3	115	0
csv	csv_small	3	0	362	366	367	365	49	0
csv	csv_medium	3	0	368	370	386	374.7	2785	0
csv	csv_large	3	0	484	487	499	490	65527	0
tsv	tsv_basic	3	0	365	372	375	370.7	70	0
tsv	tsv_small	3	0	366	377	377	373.3	49	0
tsv	tsv_medium	3	0	377	383	388	382.7	2485	0
tsv	tsv_large	3	0	476	477	490	481	63727	0
txt	txt_paragraphs	3	0	363	367	373	367.7	57	0
txt	txt_small	3	0	369	370	379	372.7	43	0
txt	txt_medium	3	0	373	374	396	381	3981	0
txt	txt_large	3	0	570	577	580	575.7	72983	0
xml	xml_basic	3	0	366	369	370	368.3	47	0
xml	xml_small	3	0	370	370	390	376.7	109	0
xml	xml_medium	3	0	370	374	379	374.3	693	0
xml	xml_large	3	0	370	371	372	371	1712	0
json	json_nested_object	3	0	372	379	384	378.3	121	0
json	json_small	3	0	370	378	387	378.3	65	0
json	json_medium	3	0	370	374	387	377	2666	0
json	json_large	3	0	610	612	615	612.3	86120	0
json	json_array_objects_large	3	0	479	481	499	486.3	33590	0
yaml	yaml_nested_mapping	3	0	370	385	392	382.3	120	0
yaml	yaml_small	3	0	373	379	386	379.3	65	0
yaml	yaml_medium	3	0	373	378	383	378	2854	0
yaml	yaml_large	3	0	575	590	592	585.7	55735	0
yaml	yaml_sequence_mappings_large	3	0	424	430	437	430.3	21522	0
markdown	markdown_frontmatter_passthrough	3	0	372	372	379	374.3	107	0
markdown	markdown_small	3	0	373	373	392	379.3	24	0
markdown	markdown_medium	3	0	377	379	386	380.7	205	0
markdown	markdown_large	3	0	442	448	460	450	20503	0
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
