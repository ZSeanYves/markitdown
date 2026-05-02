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
* Date (UTC): `2026-05-02T06:59:45Z`
* Git revision: `8a5806a`
* Timer precision: `ms`

## Summary

The checked-in baseline summary is the `summary.tsv` produced by the command
above:

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
docx	golden	3	0	351	352	358	353.7	1445	1
pptx	pptx_simple	3	0	345	345	347	345.7	310	0
xlsx	xlsx_multi_sheet_mixed	3	0	344	344	351	346.3	301	0
pdf	text_simple	3	0	339	340	340	339.7	272	0
html	html_mixed	3	0	331	332	337	333.3	87	0
csv	csv_ragged_rows	3	0	336	341	350	342.3	115	0
tsv	tsv_basic	3	0	330	331	333	331.3	70	0
txt	txt_paragraphs	3	0	326	333	336	331.7	56	0
xml	xml_basic	3	0	328	332	336	332	47	0
json	json_nested_object	3	0	331	331	332	331.3	121	0
yaml	yaml_nested_mapping	3	0	329	331	333	331	120	0
markdown	markdown_frontmatter_passthrough	3	0	331	338	346	338.3	107	0
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
