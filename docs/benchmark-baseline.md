# Benchmark Baseline

This document records a reference internal benchmark baseline for the current
repository state. It is not a hard performance assertion and should not be used
as a pass/fail gate by itself.

Use it to detect large regressions, to compare runs on the same machine, and to
understand the rough cost profile of each benchmark tier.

## Baseline command

```bash
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/bench_smoke.sh --kind all
```

The command writes benchmark artifacts under:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
$TMP_ROOT/bench/smoke
```

Measured runs are written to `results.jsonl`, and aggregate sample metrics are
written to `summary.tsv`.

## Environment

This baseline was captured with:

* OS: `Linux zseanyves-MS-7D99 6.14.0-28-generic #28~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Fri Jul 25 10:47:01 UTC 2 x86_64 x86_64 x86_64 GNU/Linux`
* Shell: `/bin/bash`
* Date (UTC): `2026-05-01T00:55:52Z`
* Git revision: `ceb1a1a`
* Timer precision: `ms`

Notes:

* This is an internal baseline for the current machine and repository revision.
* The values will move with CPU model, filesystem cache, background load,
  MoonBit runtime behavior, and benchmark corpus changes.
* Warmup runs are not included in `results.jsonl` or `summary.tsv`.

## Summary

The table below is the `summary.tsv` produced by the baseline command above.

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
docx	golden	3	0	293	303	310	302	1445	1
pptx	pptx_simple	3	0	274	285	291	283.3	310	0
xlsx	xlsx_multi_sheet_mixed	3	0	280	284	287	283.7	301	0
pdf	text_simple	3	0	278	284	286	282.7	272	0
html	html_mixed	3	0	277	281	283	280.3	87	0
csv	csv_ragged_rows	3	0	270	270	272	270.7	115	0
tsv	tsv_basic	3	0	271	272	276	273	70	0
json	json_nested_object	3	0	266	271	272	269.7	121	0
yaml	yaml_nested_mapping	3	0	269	272	274	271.7	120	0
markdown	markdown_frontmatter_passthrough	3	0	267	270	273	270	107	0
docx	docx_image_alt_title_basic_img	3	0	272	278	283	277.7	59	1
pptx	pptx_image_single_caption_like_img	3	0	275	278	281	278	75	1
html	html_figure_figcaption_basic_img	3	0	271	277	279	275.7	72	1
pdf	pdf_image_single_caption_like_img	3	0	284	285	289	286	51	1
docx	golden_metadata	3	0	290	293	311	298	1445	1
docx	docx_image_alt_title_basic_metadata	3	0	269	278	309	285.3	59	1
pptx	pptx_image_alt_title_basic_metadata	3	0	276	277	279	277.3	71	1
yaml	yaml_mapping_basic_metadata	3	0	275	277	282	278	67	0
markdown	markdown_frontmatter_metadata	3	0	268	272	273	271	107	0
docx	docx_link_many_performance_guard_ext	3	0	285	287	292	288	2959	0
pptx	pptx_table_like_region_local_with_intro_outro_ext	3	0	282	286	288	285.3	145	0
xlsx	xlsx_cell_types_ext	3	0	282	291	296	289.7	154	0
pdf	pdf_repeated_header_footer_variants_ext	3	0	295	302	308	301.7	745	0
```

## Interpretation

Use this file as a reference point, not as a strict SLA:

* Compare new runs against the same `git_rev` and machine before drawing
  conclusions.
* Prefer looking for large step changes, not small single-digit millisecond
  movement.
* Re-run with the same command when benchmarking code that may benefit from
  filesystem cache or runtime warmup.
