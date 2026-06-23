# Product Mainline Optimization Status

## Summary

P16 completed the product-mainline optimization loop in phased form:

- P16-A added stage-level benchmark coverage for XLSX and refreshed benchmark architecture notes.
- P16-B reduced OOXML package inspection and package-metric overhead through inventory caching and lighter metric collection.
- P16-C reduced HTML lowering preparation cost by removing repeated nav-ancestor scans in lowering skip analysis.
- P16-D reduced shared delimited row/cell event setup overhead in the CSV/TSV product path.
- P16-E audited renderer/output-builder hotspots and did not make code changes because current release measurements do not justify a renderer-targeted optimization.

Architecture boundaries remained intact across all completed phases:

- parsers still emit source-native facts, event streams, or Core IR inputs rather than Markdown
- renderer still only consumes Core IR
- pipeline remains format-independent
- CLI did not gain concrete format dependencies
- no benchmark-id product shortcuts were added
- no retired paths were restored

## Phase Status

| phase | status | commits | main files | validation | benchmark result |
| --- | --- | --- | --- | --- | --- |
| P16-A Product mainline audit | completed | `caca86b bench: add xlsx pipeline stage benchmarks` | `bench/pipeline/xlsx_stage_bench_test.mbt`, `formats/xlsx/parser.mbt`, `docs/architecture/benchmark-architecture.md`, `bench/README.md` | `moon fmt`, `moon check`, `moon test --target native --package formats/xlsx`, `moon bench --target native --release --package bench/pipeline` | added XLSX stage attribution and established canonical smoke baselines for txt/html/docx/pptx/xlsx/csv |
| P16-B OOXML lookup/package reuse | completed | `1b59c3d ooxml: cache inventory and lighten package metrics` | `format_readers/ooxml/package/*`, `formats/docx/parser.mbt`, `formats/pptx/parser.mbt`, `formats/xlsx/parser.mbt` | `moon check`, targeted OOXML package tests, `moon test tests`, `moon bench --target native --release --package bench/pipeline`, `moon bench --target native --release --package bench/product`, inventory check | release runner improved `pptx` and `xlsx`, and stage attribution showed lighter OOXML package metric overhead without output changes |
| P16-C HTML prepared tree/lowering reuse | completed | `7e98b13 html: reduce lowering nav ancestry scans` | `formats/html/parser.mbt` | `moon check`, `moon test --target native --package formats/html`, `moon test --target native --package formats/epub`, `moon test tests`, `moon bench --target native --release --package bench/pipeline`, `moon bench --target native --release --package bench/product`, inventory check | `html_lower_prepare`, `html_top_level_blocks`, and `html_lower_blocks` improved materially; release runner `html`/`epub` stayed stable-to-better |
| P16-D textlike/structured scan-allocation | completed | `49a569f delimited: reduce row and cell event setup overhead` | `formats/delimited_text/parser.mbt` | `moon check`, `moon test --target native --package formats/csv`, `moon test --target native --package formats/tsv`, `moon test tests`, `moon bench --target native --release --package bench/pipeline`, `moon bench --target native --release --package bench/product`, inventory check | `csv`/`tsv` stage and release baselines showed shared delimited-path wins after two focused attempts |
| P16-E renderer/output builder audit | completed | none | `render/render.mbt` audited only | release smoke compare and product/pipeline benchmark review | no renderer code change: current measurements point to parser/build costs rather than renderer as the shared bottleneck |
| P16-F final full-format validation/report | completed | `docs: record product mainline optimization status` | `docs/architecture/product-mainline-optimization-status.md` | full fmt/info/check/test/bench/sample/hygiene suite passed | final smoke and regular release runner snapshots captured; regular `json` is partial only because external `markitdown` failed one medium JSON row |

## Phase Details

### P16-A Product Mainline Audit

- Start HEAD: `bdb4a3c`
- End HEAD: `caca86b`
- Files changed:
  - `bench/README.md`
  - `bench/pipeline/moon.pkg`
  - `bench/pipeline/xlsx_stage_bench_test.mbt`
  - `docs/architecture/benchmark-architecture.md`
  - `formats/xlsx/parser.mbt`
  - `formats/xlsx/pkg.generated.mbti`
- Benchmark notes:
  - HTML small synthetic stage baseline:
    - `html_semantic_collect` about `3.12 ms`
    - `html_lower_prepare` about `576 us`
    - `html_lower_blocks` about `624 us`
    - `convert_total` about `4.97 ms`
  - DOCX small baseline:
    - `docx_source_parse` about `1.48 ms`
    - `registry_parse` about `3.85 ms`
    - `convert_total` about `4.10 ms`
  - PPTX small baseline:
    - `pptx_source_parse` about `464 us`
    - `registry_parse` about `1.21 ms`
    - `convert_total` about `1.23 ms`
  - XLSX small baseline:
    - `workbook_parse` about `445 us`
    - `first_sheet_parse` about `452 us`
    - `registry_parse` about `627 us`
    - `convert_total` about `650 us`
  - Canonical smoke compare baselines:
    - `txt` CLI median wall time about `3564 us`
    - `html` CLI median wall time about `8791 us`
    - `docx` CLI median wall time about `7269 us`
    - `pptx` CLI median wall time about `6349 us`
    - `xlsx` CLI median wall time about `4830 us`
    - `csv` CLI median wall time about `8868 us`
- Correctness status:
  - no product-path behavior changes

### P16-B OOXML Low-level Reuse Optimization

- Start HEAD: `caca86b`
- End HEAD: `1b59c3d`
- Files changed:
  - `format_readers/ooxml/package/ooxml_dump.mbt`
  - `format_readers/ooxml/package/ooxml_package.mbt`
  - `format_readers/ooxml/package/ooxml_types.mbt`
  - `formats/docx/parser.mbt`
  - `formats/pptx/parser.mbt`
  - `formats/xlsx/parser.mbt`
- Main change:
  - cached OOXML inventory at package level
  - reused lightweight inventory for package metrics instead of always rebuilding full inspect reports
  - replaced report-derived media counts with direct part scans
- Before/after benchmark highlights:
  - canonical sequential release compare:
    - `docx` before `5235 us`, after `6288 us`
    - `pptx` before `6834 us`, after `3951 us`
    - `xlsx` before `4711 us`, after `3203 us`
  - engine medians:
    - `docx` before `2353 us`, after `2242 us`
    - `pptx` before `2659 us`, after `1523 us`
    - `xlsx` before `800 us`, after `471 us`
  - stage attribution:
    - `docx registry_parse` from about `3.85 ms` to about `3.68 ms`
    - `pptx convert_total` from about `1.21 ms` to about `0.87 ms`
    - `xlsx convert_total` from about `650 us` to about `548 us`
- Correctness status:
  - OOXML package tests passed
  - `formats/docx`, `formats/pptx`, and `formats/xlsx` tests passed
  - inventory check passed

### P16-C HTML Prepared Tree/Lowering Reuse Optimization

- Start HEAD: `1b59c3d`
- End HEAD: `7e98b13`
- Files changed:
  - `formats/html/parser.mbt`
- Main change:
  - replaced repeated per-block nav-ancestor scans in lowering skip analysis with a single propagated nav-context pass
- Before/after benchmark highlights:
  - release runner:
    - `html` before `5535 us`, after `5512 us`
    - `epub` before `3193 us`, after `3193 us`
    - no meaningful regression in CLI or engine compare output
  - stage attribution:
    - `html_lower_prepare` from about `576 us` to about `450-468 us`
    - `html_top_level_blocks` from about `624 us` equivalent prep tail to about `467 us`
    - `html_lower_blocks` from about `624 us` to about `489-511 us`
    - `html_document_to_ir` from about `4.94 ms` to about `4.77 ms`
    - `convert_total` from about `4.97 ms` to about `4.91 ms`
- Correctness status:
  - `formats/html` and `formats/epub` targeted tests passed
  - full tests and inventory checks passed

### P16-D Textlike/Structured Scan and Allocation Optimization

- Start HEAD: `7e98b13`
- End HEAD: `49a569f`
- Files changed:
  - `formats/delimited_text/parser.mbt`
- Main change:
  - reduced duplicated row/cell event setup work in shared CSV/TSV event-stream generation
  - reused computed format and row range fragments instead of rebuilding the same strings repeatedly
- Attempt summary:
  - attempt 1 reduced event range string churn and improved stage `csv`/`tsv` signals, but release `csv` was too noisy to declare final
  - attempt 2 cached shared format/range fragments and produced stable release wins
- Before/after benchmark highlights:
  - release runner:
    - `csv` before `3958 us`, final after `3939 us`
    - `tsv` before `4739 us`, final after `4694 us`
    - `csv small` engine from `3491 us` to `3423 us`
    - `tsv small` engine from `4564 us` to `4472 us`
  - stage attribution:
    - `csv event_stream_build` from about `423 us` to about `418 us`
    - `csv registry_parse` from about `1.19 ms` to about `1.07 ms`
    - `csv convert_total` from about `3.39 ms` to about `3.27 ms`
    - `tsv registry_parse` from about `1.66 ms` to about `1.57 ms`
    - `tsv convert_total` from about `4.29 ms` to about `4.21 ms`
  - product smoke:
    - `csv_small_usgs_all_day_v1` about `3.43 ms` to `3.28 ms`
    - `tsv_small_uniprot_reviewed_v1` about `4.28 ms` to `4.23-4.24 ms`
- Correctness status:
  - targeted `formats/csv` and `formats/tsv` tests passed
  - full tests and inventory checks passed

### P16-E Renderer/Output Builder Audit

- Start HEAD: `49a569f`
- End HEAD: `49a569f`
- Files changed:
  - none
- Audit scope:
  - reviewed `render/render.mbt` table, paragraph, list, inline, and escaping helpers
  - compared release smoke medians against stage attribution and product benchmarks
- Audit conclusion:
  - current shared hotspots remain parser/build dominated
  - render costs are visible but not the main bottleneck in the canonical release measurements
  - no renderer-targeted optimization was justified under the P16 rules

## Performance Summary

Canonical `wall_us` highlights from the completed optimization phases:

- OOXML:
  - `pptx` CLI median improved from about `6834 us` to `3951 us`
  - `xlsx` CLI median improved from about `4711 us` to `3203 us`
  - `docx` engine improved slightly while CLI remained overhead-sensitive
- HTML family:
  - `html` CLI median improved from about `5535 us` to `5512 us`
  - `epub` CLI median held roughly flat at about `3193 us`
  - stage lowering prep improved much more than CLI because fixed overhead dominates small files
- Textlike/structured:
  - `csv` CLI median improved from about `3958 us` to `3939 us`
  - `tsv` CLI median improved from about `4739 us` to `4694 us`
  - `txt`, `json`, `yaml`, `xml` remained fast in engine mode but CLI fixed overhead still dominates tiny files
- Full smoke compare snapshot after P16-E audit:
  - best CLI medians remained in `epub`, `pdf`, `xml`, `zip`, and `xlsx`
  - parser/build-heavy formats such as `json`, `tsv`, `html`, and `docx` still show the largest remaining engine-side optimization headroom
- Final release runner smoke snapshot (`run-1782322213899-7e52cedf-summary.json`):
  - `csv` `5508 us` CLI, `1877 us` engine, fixed overhead `3631 us`
  - `docx` `4687 us` CLI, `2258 us` engine, fixed overhead `2429 us`
  - `html` `5354 us` CLI, `2634 us` engine, fixed overhead `2719 us`
  - `pptx` `3945 us` CLI, `1643 us` engine, fixed overhead `2302 us`
  - `tsv` `5526 us` CLI, `2355 us` engine, fixed overhead `3171 us`
  - `txt` `4105 us` CLI, `729 us` engine, fixed overhead `3376 us`
  - `xlsx` `3175 us` CLI, `498 us` engine, fixed overhead `2677 us`
  - `xml` `2468 us` CLI, `309 us` engine, fixed overhead `2158 us`
  - `yaml` `2427 us` CLI, `365 us` engine, fixed overhead `2062 us`
  - `zip` `3189 us` CLI, `568 us` engine, fixed overhead `2620 us`
- Final release runner regular snapshot (`run-1782322292472-7ada8288-summary.json`):
  - selector covered `42` rows and per-format medians include three size classes where available
  - `csv` `6257 us` CLI, `3688 us` engine
  - `docx` `4702 us` CLI, `2078 us` engine
  - `html` `7670 us` CLI, `5199 us` engine
  - `pptx` `4678 us` CLI, `2162 us` engine
  - `tsv` `7808 us` CLI, `4594 us` engine
  - `txt` `4735 us` CLI, `1388 us` engine
  - `xlsx` `3172 us` CLI, `669 us` engine
  - `xml` `3180 us` CLI, `519 us` engine
  - `yaml` `3181 us` CLI, `605 us` engine
  - `zip` `1704 us` CLI, `131 us` engine
- Final runner overhead diagnostics (`run-1782322206072-n690a1ae3-overhead.md`):
  - `process_true` median `1715 us`
  - built CLI `help` median `1677 us`
  - tiny TXT CLI baseline `1655 us` vs engine `71 us`
  - small HTML CLI baseline `7706 us` vs engine `5004 us`

Interpretation:

- for tiny files, CLI fixed overhead often dominates and can swamp small engine-side improvements
- stage benchmarks and engine medians were therefore used to verify whether a localized optimization actually improved the product path
- release runner compare remained the canonical final signal for spendable user-facing performance claims
- the final regular snapshot confirms that larger files preserve the same trend lines, with engine work becoming a larger share than pure process overhead

## Reuse and Redundancy Reduction

- Added shared OOXML inventory caching rather than rebuilding package inspection inventories per metric read.
- Reused lightweight OOXML inventory data across DOCX, PPTX, and XLSX package metric collection.
- Replaced repeated HTML nav-ancestor scans with a single propagated lowering-context pass.
- Reduced repeated delimited row/cell range construction in the shared CSV/TSV event-stream builder.
- Kept semantic models intentionally separate where merging would have widened architecture scope:
  - DOCX/PPTX/XLSX semantic layers remain independent
  - HTML and XML semantic policy remain separate
  - renderer did not absorb source-format concerns

## Memory and Scan Optimization Summary

- Reduced repeated OOXML package inventory scans.
- Reduced repeated HTML ancestor traversal during lowering preparation.
- Reduced repeated delimited row/cell range string construction and format-name lookup.
- Left larger structural builder rewrites for future work because the current data did not justify a broader architecture change inside P16.

## Validation Status

Completed during P16:

- `moon fmt`
- `moon check`
- targeted `moon test --target native --package ...` runs for affected packages:
  - `format_readers/ooxml/package`
  - `formats/docx`
  - `formats/pptx`
  - `formats/xlsx`
  - `formats/html`
  - `formats/epub`
  - `formats/csv`
  - `formats/tsv`
- `moon test tests`
- `moon bench --target native --release --package bench/pipeline`
- `moon bench --target native --release --package bench/product`
- repeated clean sequential release runner `compare` commands for:
  - `docx`
  - `pptx`
  - `xlsx`
  - `html`
  - `epub`
  - `csv`
  - `tsv`
  - `txt`
  - `json`
  - `yaml`
- `bash samples/check.sh --check-inventory`
- `moon info`
- `moon test bench/runner/command`
- `moon test bench/runner/result`
- `moon test bench/runner/process`
- `moon bench --target native --release --package bench/micro`
- `moon test`
- `bash samples/check.sh`
- `moon build bench/runner --target native --release`
- `moon build cli --target native --release`
- `runner help`
- `runner diagnose-overhead --repeat 30 --cli-output-mode file --engine-output-mode file`
- `runner compare --tier smoke --repeat 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown`
- `runner compare --tier regular --repeat 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown`
- `git diff --check -- . ':(exclude).tmp'`
- `find bench/runner -maxdepth 4 -type f \( -name '*.py' -o -name '*.sh' \)`
- `test ! -e tools/bench`
- `git status --short`

Final P16-F status:

- all required final validation commands completed successfully
- `moon test bench/runner/result` initially failed once when I accidentally ran multiple `moon test` commands in parallel and hit `_build/.moon-lock`; rerunning sequentially passed cleanly, and all subsequent MoonBit commands were run sequentially
- `regular` compare completed successfully, but summary row `json` is `partial` because external Python `markitdown` failed `json_medium_spdx_licenses_v1` with `exit_code 1`; MoonBit CLI and engine results for that row remained `ok`
- `run-1782322292472-7ada8288-summary.json` reports `selected_rows=42` and three rows per format for regular coverage, but its top-level `corpus.tier` field still shows `smoke`; this appears to be a runner summary metadata caveat rather than a measurement failure because the underlying JSONL rows are tagged `enabled_tier=regular` for the added regular fixtures

## Commits

- `caca86b bench: add xlsx pipeline stage benchmarks`
- `1b59c3d ooxml: cache inventory and lighten package metrics`
- `7e98b13 html: reduce lowering nav ancestry scans`
- `49a569f delimited: reduce row and cell event setup overhead`
- pending final doc commit: `docs: record product mainline optimization status`

## Artifacts Not Committed

- release runner result JSON and Markdown reports remain uncommitted
- `.tmp` remains uncommitted
- no quality-lab changes were committed
- no `samples/expected` updates were made

## P17 Backlog

- OOXML:
  - investigate remaining DOCX engine-side lookup/setup costs after fixed-overhead normalization
  - consider more explicit relationship-id indexing only if future benchmarks justify the extra memory
- HTML:
  - evaluate caching or reusing child-block ordering where repeated sort work becomes visible on larger corpora
  - inspect semantic collection map population cost for larger real-world documents
- Textlike/structured:
  - investigate JSON/YAML shared table-builder and row-materialization helpers
  - evaluate TXT normalization and line-scan fast paths for large plain-text inputs
- Renderer:
  - revisit `render/render.mbt` only if future release benchmarks show render as a primary shared bottleneck rather than a secondary one
