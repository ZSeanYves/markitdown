# Benchmark Comparison Baseline

This document records a historical same-machine overlap-only comparison baseline
between `markitdown-mb` and Microsoft MarkItDown.

It is a local reference, not a pass/fail performance target.

## Scope

The baseline covers the current overlap-only comparison harness:

* success rate
* elapsed time
* output size
* stderr size

It does not compare:

* Markdown quality
* metadata semantics
* asset semantics

## Environment Note

This baseline used a pre-existing base/miniforge environment for the Python
runner. That is a historical environment fact, not a project dependency.

The current preferred workflow is still the user-managed external-command setup
described in
[docs/benchmark-comparison.md](/home/zseanyves/markitdown/docs/benchmark-comparison.md).

## Baseline Command

```bash
BENCH_WARMUP=1 BENCH_ITERATIONS=3 \
MARKITDOWN_COMPARE_CMD="/home/zseanyves/miniforge3/bin/markitdown" \
./samples/bench_compare_markitdown.sh
```

## Environment

This baseline was captured with:

* OS: `Linux zseanyves-MS-7D99 6.14.0-28-generic #28~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Fri Jul 25 10:47:01 UTC 2 x86_64 x86_64 x86_64 GNU/Linux`
* Shell: `/bin/bash`
* Date (UTC): `2026-05-01T01:20:54Z`
* Git revision: `ceb1a1a`
* Timer precision: `ms`
* Python version: `Python 3.12.11`
* MarkItDown version: `markitdown 0.1.5`
* Python path: `/home/zseanyves/miniforge3/bin/python`
* MarkItDown path: `/home/zseanyves/miniforge3/bin/markitdown`

## Summary

The checked-in summary is:

```tsv
runner	format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	stderr_bytes_last
markitdown-mb	docx	docx_heading_levels_compare	3	0	291	294	299	294.7	296	0
markitdown-python	docx	docx_heading_levels_compare	3	0	499	501	505	501.7	295	262
markitdown-mb	pptx	pptx_title_bullets_compare	3	0	282	291	295	289.3	81	0
markitdown-python	pptx	pptx_title_bullets_compare	3	0	483	497	504	494.7	85	262
markitdown-mb	xlsx	xlsx_multi_sheet_mixed_compare	3	0	287	290	291	289.3	301	0
markitdown-python	xlsx	xlsx_multi_sheet_mixed_compare	3	0	496	504	508	502.7	320	262
markitdown-mb	pdf	text_simple_compare	3	0	287	287	289	287.7	272	0
markitdown-python	pdf	text_simple_compare	3	0	495	495	527	505.7	271	262
markitdown-mb	html	html_simple_compare	3	0	270	273	275	272.7	116	0
markitdown-python	html	html_simple_compare	3	0	481	504	518	501	115	262
markitdown-mb	csv	csv_basic_compare	3	0	270	274	293	279	70	0
markitdown-python	csv	csv_basic_compare	3	0	502	504	520	508.7	69	262
```

## Interpretation

Treat this as:

* a historical baseline for the current machine
* a same-runner comparison reference
* an example of environment-dependent benchmark behavior

Do not treat it as:

* a repository dependency on miniforge/base
* a portability guarantee
* a semantic quality comparison
