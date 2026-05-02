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

For TXT hardening work, the smoke corpus now includes:

* `txt_paragraphs`
* `txt_small`
* `txt_medium`
* `txt_large`

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
* Date (UTC): `2026-05-02T07:40:56Z`
* Git revision: `52a8135`
* Timer precision: `ms`

## Summary

The checked-in baseline summary is the `summary.tsv` produced by the command
above:

```tsv
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last
docx	golden	3	0	356	358	361	358.3	1445	1
pptx	pptx_simple	3	0	346	346	352	348	310	0
xlsx	xlsx_multi_sheet_mixed	3	0	348	350	356	351.3	301	0
pdf	text_simple	3	0	339	343	345	342.3	272	0
html	html_mixed	3	0	333	333	336	334	87	0
csv	csv_ragged_rows	3	0	334	335	343	337.3	115	0
tsv	tsv_basic	3	0	333	336	337	335.3	70	0
txt	txt_paragraphs	3	0	335	337	339	337	57	0
txt	txt_small	3	0	332	333	333	332.7	43	0
txt	txt_medium	3	0	340	341	348	343	3981	0
txt	txt_large	3	0	520	522	528	523.3	72983	0
xml	xml_basic	3	0	337	341	350	342.7	47	0
json	json_nested_object	3	0	333	334	336	334.3	121	0
yaml	yaml_nested_mapping	3	0	334	337	343	338	120	0
markdown	markdown_frontmatter_passthrough	3	0	334	334	337	335	107	0
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
