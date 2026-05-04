# Benchmark Comparison Baseline

This document records a historical same-machine overlap-only comparison baseline
between `markitdown-mb` and Microsoft MarkItDown.

It is a local reference, not a pass/fail performance target.

## Current PDF Overlap Baseline

This PDF baseline is for the current overlap-only text-PDF cases only. It does
not claim full semantic equivalence with Microsoft MarkItDown across all PDF
layouts or OCR scenarios.

### Command

```bash
tmp_corpus="$(mktemp /private/tmp/pdf_compare.XXXXXX)"
printf 'format\tsample\tinput_path\n' > "$tmp_corpus"
printf 'pdf\ttext_simple_compare\tsamples/main_process/pdf/text_simple.pdf\n' >> "$tmp_corpus"
printf 'pdf\theading_basic_compare\tsamples/main_process/pdf/heading_basic.pdf\n' >> "$tmp_corpus"
printf 'pdf\tpdf_repeated_header_footer_compare\tsamples/main_process/pdf/pdf_repeated_header_footer.pdf\n' >> "$tmp_corpus"
printf 'pdf\tpdf_cross_page_should_merge_compare\tsamples/main_process/pdf/pdf_cross_page_should_merge_phase15.pdf\n' >> "$tmp_corpus"
printf 'pdf\tpdf_cross_page_should_not_merge_compare\tsamples/main_process/pdf/pdf_cross_page_should_not_merge_phase15.pdf\n' >> "$tmp_corpus"
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/scripts/bench_compare_markitdown.sh --corpus "$tmp_corpus"
```

### Runners

* `markitdown-mb`: prebuilt native CLI
  `_build/native/debug/build/cli/cli.exe normal`
* Microsoft MarkItDown: `markitdown 0.1.5` from `PATH`

### Environment

This PDF baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan  2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Date (UTC): `2026-05-03T04:23:36Z`
* Git revision: `f268ac2`
* Timer precision: `ms`

### PDF Summary

```tsv
runner	format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	stderr_bytes_last
markitdown-mb	pdf	text_simple_compare	3	0	12	12	12	12	272	0
markitdown-python	pdf	text_simple_compare	3	0	496	515	518	509.7	271	0
markitdown-mb	pdf	heading_basic_compare	3	0	14	14	17	15	257	0
markitdown-python	pdf	heading_basic_compare	3	0	530	540	579	549.7	266	0
markitdown-mb	pdf	pdf_repeated_header_footer_compare	3	0	12	12	13	12.3	142	0
markitdown-python	pdf	pdf_repeated_header_footer_compare	3	0	520	524	539	527.7	207	0
markitdown-mb	pdf	pdf_cross_page_should_merge_compare	3	0	12	13	13	12.7	313	0
markitdown-python	pdf	pdf_cross_page_should_merge_compare	3	0	523	527	530	526.7	314	0
markitdown-mb	pdf	pdf_cross_page_should_not_merge_compare	3	0	11	12	12	11.7	246	0
markitdown-python	pdf	pdf_cross_page_should_not_merge_compare	3	0	518	528	530	525.3	243	0
```

### PDF Interpretation

* overlap scope only: simple text, heading/basic structure, repeated
  header/footer cleanup, cross-page merge, and cross-page no-merge
* warmup: `1`
* iterations: `3`
* `text_simple_compare`: semantic difference; `markitdown-mb` preserves heading
  structure and cleaner CJK text while Microsoft MarkItDown emits plain text
  with compatibility glyph artifacts; result: `win`
* `heading_basic_compare`: semantic difference; `markitdown-mb` preserves
  chapter/section heading structure and suppresses page noise, while Microsoft
  MarkItDown keeps flatter text and page residue; result: `win`
* `pdf_repeated_header_footer_compare`: semantic difference; `markitdown-mb`
  removes repeated edge noise while Microsoft MarkItDown keeps the repeated
  header/footer strings; result: `win`
* `pdf_cross_page_should_merge_compare`: semantic difference; both tools
  preserve the text, but `markitdown-mb` merges the paragraph across pages
  while Microsoft MarkItDown keeps the page break split; result: `win`
* `pdf_cross_page_should_not_merge_compare`: semantic difference; both tools
  keep the new section separate, but `markitdown-mb` restores heading/list
  structure while Microsoft MarkItDown keeps flatter text and form-feed residue;
  result: `win`
* non-goals for this baseline:
  * proving full PDF semantic parity
  * covering OCR/image-heavy PDFs
  * covering complex table/layout reconstruction

## Current PPTX Overlap Baseline

This PPTX baseline is for the current overlap-only PPTX cases only. It does not
claim full semantic equivalence with Microsoft MarkItDown across all PPTX
features.

### Command

```bash
tmp_corpus="$(mktemp /private/tmp/pptx_compare_final.XXXXXX)"
printf 'format\tsample\tinput_path\n' > "$tmp_corpus"
printf 'pptx\tpptx_title_bullets_compare\tsamples/main_process/pptx/pptx_title_bullets.pptx\n' >> "$tmp_corpus"
printf 'pptx\tpptx_hyperlink_basic_compare\tsamples/main_process/pptx/pptx_hyperlink_basic.pptx\n' >> "$tmp_corpus"
printf 'pptx\tpptx_hyperlink_shape_basic_compare\tsamples/main_process/pptx/pptx_hyperlink_shape_basic.pptx\n' >> "$tmp_corpus"
printf 'pptx\tpptx_slide_order_compare\tsamples/main_process/pptx/pptx_slide_order.pptx\n' >> "$tmp_corpus"
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/scripts/bench_compare_markitdown.sh --corpus "$tmp_corpus"
```

### Runners

* `markitdown-mb`: prebuilt native CLI
  `_build/native/debug/build/cli/cli.exe normal`
* Microsoft MarkItDown: `markitdown 0.1.5` from `PATH`

### Environment

This PPTX baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan  2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Date (UTC): `2026-05-02T13:51:31Z`
* Git revision: `e9aa483`
* Timer precision: `ms`

### PPTX Summary

```tsv
runner	format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	stderr_bytes_last
markitdown-mb	pptx	pptx_title_bullets_compare	3	0	12	12	13	12.3	81	0
markitdown-python	pptx	pptx_title_bullets_compare	3	0	459	470	484	471	85	0
markitdown-mb	pptx	pptx_hyperlink_basic_compare	3	0	11	11	12	11.3	111	0
markitdown-python	pptx	pptx_hyperlink_basic_compare	3	0	485	491	495	490.3	89	0
markitdown-mb	pptx	pptx_hyperlink_shape_basic_compare	3	0	11	11	12	11.3	62	0
markitdown-python	pptx	pptx_hyperlink_shape_basic_compare	3	0	483	489	507	493	43	0
markitdown-mb	pptx	pptx_slide_order_compare	3	0	13	13	13	13	91	0
markitdown-python	pptx	pptx_slide_order_compare	3	0	484	491	511	495.3	118	0
```

### PPTX Interpretation

* overlap scope only: title/body+list, run hyperlink, shape hyperlink, and
  slide-order cases
* warmup: `1`
* iterations: `3`
* `pptx_title_bullets_compare`: both tools preserve the title/body content, but
  `markitdown-mb` keeps Markdown list structure while Microsoft MarkItDown
  flattens bullets into plain lines
* `pptx_hyperlink_basic_compare`: both tools preserve the visible URL text, but
  `markitdown-mb` emits Markdown link syntax while Microsoft MarkItDown keeps
  plain text
* `pptx_hyperlink_shape_basic_compare`: `markitdown-mb` preserves the
  shape-level external hyperlink target; Microsoft MarkItDown keeps the heading
  text only
* `pptx_slide_order_compare`: both tools preserve slide order, but marker and
  heading-level conventions differ
* result: PPTX runner-level performance is a clear `win` for `markitdown-mb`
  on this machine and this runner setup
* non-goal for this baseline: proving full PPTX semantic parity

## Current DOCX Overlap Baseline

This DOCX baseline is for the current overlap-only DOCX cases only. It does not
claim full semantic equivalence with Microsoft MarkItDown across all DOCX
features.

### Command

```bash
tmp_corpus="$(mktemp /private/tmp/docx_compare.XXXXXX)"
printf 'format\tsample\tinput_path\n' > "$tmp_corpus"
printf 'docx\tdocx_heading_levels_compare\tsamples/main_process/docx/docx_heading_levels.docx\n' >> "$tmp_corpus"
printf 'docx\tdocx_link_basic_compare\tsamples/main_process/docx/docx_link_basic.docx\n' >> "$tmp_corpus"
printf 'docx\tdocx_list_nested_compare\tsamples/main_process/docx/docx_list_nested.docx\n' >> "$tmp_corpus"
printf 'docx\tdocx_table_multiline_cell_compare\tsamples/main_process/docx/docx_table_multiline_cell.docx\n' >> "$tmp_corpus"
BENCH_WARMUP=1 BENCH_ITERATIONS=3 ./samples/scripts/bench_compare_markitdown.sh --corpus "$tmp_corpus"
```

### Runners

* `markitdown-mb`: prebuilt native CLI
  `_build/native/debug/build/cli/cli.exe normal`
* Microsoft MarkItDown: `markitdown 0.1.5` from `PATH`

### Environment

This DOCX baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan  2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Date (UTC): `2026-05-02T13:31:21Z`
* Git revision: `e9aa483`
* Timer precision: `ms`

### DOCX Summary

```tsv
runner	format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	stderr_bytes_last
markitdown-mb	docx	docx_heading_levels_compare	3	0	24	24	25	24.3	296	0
markitdown-python	docx	docx_heading_levels_compare	3	0	451	451	487	463	295	0
markitdown-mb	docx	docx_link_basic_compare	3	0	11	11	12	11.3	29	0
markitdown-python	docx	docx_link_basic_compare	3	0	519	522	533	524.7	28	0
markitdown-mb	docx	docx_list_nested_compare	3	0	22	23	23	22.7	179	0
markitdown-python	docx	docx_list_nested_compare	3	0	452	452	453	452.3	178	0
markitdown-mb	docx	docx_table_multiline_cell_compare	3	0	10	10	11	10.3	61	0
markitdown-python	docx	docx_table_multiline_cell_compare	3	0	450	451	466	455.7	73	0
```

### DOCX Interpretation

* overlap scope only: heading, hyperlink, nested-list, and simple-table cases
* warmup: `1`
* iterations: `3`
* `docx_heading_levels_compare`: output shape is effectively the same, with
  trailing-newline byte differences only
* `docx_link_basic_compare`: output shape is effectively the same, with
  trailing-newline byte differences only
* `docx_list_nested_compare`: both tools preserve nested list structure, but
  bullet marker choices differ
* `docx_table_multiline_cell_compare`: both tools preserve a readable table,
  but header and multiline-cell strategies differ
* result: DOCX runner-level performance is a clear `win` for `markitdown-mb`
  on this machine and this runner setup
* non-goal for this baseline: proving full DOCX semantic parity

## Current TXT Overlap Baseline

This TXT baseline is for the current overlap-only TXT case only. It does not
claim the same result shape for every compared format.

### Command

```bash
tmp_corpus="$(mktemp /private/tmp/compare_txt_baseline.XXXXXX)"
printf 'format\tsample\tinput_path\n' > "$tmp_corpus"
printf 'txt\ttxt_plain_compare\tsamples/main_process/txt/txt_plain.txt\n' >> "$tmp_corpus"
BENCH_WARMUP=1 BENCH_ITERATIONS=5 ./samples/scripts/bench_compare_markitdown.sh --corpus "$tmp_corpus"
```

### Runners

* `markitdown-mb`: prebuilt native CLI
  `_build/native/debug/build/cli/cli.exe normal`
* Microsoft MarkItDown: `markitdown 0.1.5` from `PATH`

### Environment

This TXT baseline was captured with:

* OS: `Darwin winterdeMacBook-Air.local 24.3.0 Darwin Kernel Version 24.3.0: Thu Jan  2 20:31:46 PST 2025; root:xnu-11215.81.4~4/RELEASE_ARM64_T8132 arm64`
* Date (UTC): `2026-05-02T08:02:35Z`
* Git revision: `52a8135`
* Timer precision: `ms`

### TXT Summary

```tsv
runner	format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	stderr_bytes_last
markitdown-mb	txt	txt_plain_compare	5	0	9	10	10	9.6	17	0
markitdown-python	txt	txt_plain_compare	5	0	434	437	443	437	17	0
```

### TXT Interpretation

* overlap scope only: TXT `txt_plain_compare`
* warmup: `1`
* iterations: `5`
* output: identical
* result: TXT = win for `markitdown-mb` on this machine and this runner setup

## Historical Multi-Format Reference

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
[docs/benchmark-comparison.md](./benchmark-comparison.md).

## Baseline Command

```bash
BENCH_WARMUP=1 BENCH_ITERATIONS=3 \
MARKITDOWN_COMPARE_CMD="/home/zseanyves/miniforge3/bin/markitdown" \
./samples/scripts/bench_compare_markitdown.sh
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
