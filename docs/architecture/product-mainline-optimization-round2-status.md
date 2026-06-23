# Product Mainline Optimization Round Two Status

## Summary

Round two completed the `P16-G` to `P17-D` product-mainline optimization loop:

- `P16-G` fixed benchmark summary/report tier metadata so regular runs no longer report top-level `smoke`.
- `P17-A` reduced textlike allocation churn in shared text parsing and delimited event setup.
- `P17-B` reused OOXML sorted-part and relationship lookup work for better medium-path package traversal.
- `P17-C` reduced HTML lowering traversal overhead without changing parser/render architecture boundaries.
- `P17-D` clarified partial external-baseline reporting so external-only failures are visible without being misreported as MoonBit regressions.

Architecture boundaries remained intact across all completed phases:

- parsers still do not emit Markdown directly
- renderer still only consumes Core IR
- pipeline remains format-independent
- CLI did not gain concrete format dependencies
- no benchmark-id product shortcuts were added
- no retired paths were restored

## Phase Status

| phase | status | commits | main files | validation | benchmark result |
| --- | --- | --- | --- | --- | --- |
| P16-G Benchmark tier metadata fix | completed | `cab9a13 bench: fix summary tier metadata` | `bench/runner/manifest/*`, `bench/runner/result/*`, `bench/runner/README.md`, `docs/architecture/benchmark-architecture.md` | runner `result/command/process` tests, `moon check`, release regular compare repro | regular compare now reports top-level `corpus.tier=regular` instead of incorrectly showing `smoke` |
| P17-A Textlike / structured scan allocation round 2 | completed | `01c8d21 text: reduce parser allocation churn` | `format_readers/text/text_parser.mbt`, `formats/txt/parser.mbt`, `formats/delimited_text/parser.mbt` | targeted text/csv/tsv tests, `moon check`, `moon test tests`, `moon test`, sample checks | `txt` stage and release engine improved clearly; `csv`/`tsv` showed smaller but stable shared-path wins |
| P17-B OOXML medium/large lookup optimization round 2 | completed | `4dc29f0 ooxml: reuse sorted parts and relationship lookups` | `format_readers/ooxml/package/*`, `format_readers/ooxml/pptx/pptx_layout.mbt` | targeted OOXML tests, `moon check`, `moon test tests`, sample checks | `pptx` regular/smoke release metrics and stage attribution improved after two focused attempts |
| P17-C HTML lowering / tree index optimization round 2 | completed | `3b531bd html: reduce lowering traversal overhead` | `formats/html/parser.mbt` | `formats/html`, `formats/epub`, `moon test tests`, `moon check`, `samples/check --format html` | release smoke `html` improved and stage `html_document_to_ir` / `registry_parse` / `convert_total` improved; one narrower second attempt was reverted because it was not stable |
| P17-D Benchmark report robustness / round-two status | completed | `bba237d bench: clarify partial external baseline reporting`, pending final doc commit | `bench/runner/result/*`, `bench/runner/README.md`, `docs/architecture/benchmark-architecture.md`, `docs/architecture/product-mainline-optimization-round2-status.md` | runner tests, full fmt/info/check/test/bench/sample/hygiene suite, release overhead/smoke/regular compare | reports now surface comparable-row coverage and external-only baseline gaps explicitly; regular `json` remains partial only because external `markitdown` failed one medium row |

## Phase Details

### P16-G Benchmark Tier Metadata Fix

- Start HEAD: `492365c`
- End HEAD: `cab9a13`
- Files changed:
  - `bench/runner/manifest/row.mbt`
  - `bench/runner/manifest/selector.mbt`
  - `bench/runner/result/summary.mbt`
  - `bench/runner/result/summary_wbtest.mbt`
  - `bench/runner/README.md`
  - `docs/architecture/benchmark-architecture.md`
- Main change:
  - recorded requested tier in selector stats and made summary/report top-level corpus tier prefer selector metadata over first-row `enabled_tier`
- Verification:
  - `moon test bench/runner/result`
  - `moon test bench/runner/command`
  - `moon test bench/runner/process`
  - `moon check`
  - release runner regular compare repro
- Result:
  - regular compare summary/report now show `corpus.tier=regular`

### P17-A Textlike / Structured Allocation Reduction

- Start HEAD: `cab9a13`
- End HEAD: `01c8d21`
- Files changed:
  - `format_readers/text/text_parser.mbt`
  - `formats/txt/parser.mbt`
  - `formats/delimited_text/parser.mbt`
- Main changes:
  - reused original normalized text when possible to avoid extra full-string scans
  - preallocated TXT event buffers and fused long-line counting into event generation
  - preallocated CSV/TSV event arrays and reused shared row/cell string fragments
- Before/after highlights:
  - stage `txt_small_rfc8259_v1.normalize_and_parse_text`: about `321.80 us` -> about `241.71 us`
  - stage `txt_small_rfc8259_v1.parse_text_document`: about `298.73 us` -> about `221.11 us`
  - stage `txt_small_rfc8259_v1.registry_parse`: about `564.81 us` -> about `498.59 us`
  - smoke release `txt` engine: about `838 us` -> about `739 us`
  - smoke release `csv` engine: about `1856 us` -> about `1956 us` in compare noise, while stage/product stayed slightly better
  - smoke release `tsv` engine: about `2290 us` -> about `2420 us` in compare noise, while stage/product stayed slightly better
- Verification:
  - targeted text/csv/tsv native tests
  - `moon check`
  - `moon test tests`
  - `moon test`
  - `bash samples/check.sh --format txt`
  - `bash samples/check.sh --format csv`
  - `bash samples/check.sh --format tsv`
  - `bash samples/check.sh --format json`
  - `bash samples/check.sh --format yaml`
  - `bash samples/check.sh --format xml`
  - `bash samples/check.sh --check-inventory`

### P17-B OOXML Sorted-Part / Relationship Reuse

- Start HEAD: `01c8d21`
- End HEAD: `4dc29f0`
- Files changed:
  - `format_readers/ooxml/package/ooxml_package.mbt`
  - `format_readers/ooxml/package/ooxml_relationships.mbt`
  - `format_readers/ooxml/package/ooxml_types.mbt`
  - `format_readers/ooxml/pptx/pptx_layout.mbt`
- Main changes:
  - cached sorted OOXML part lists on package open
  - reused prefix-filtered layout/master part discovery in PPTX
  - added exact-match relationship-type fast path and preallocated relationship clones
- Before/after highlights:
  - smoke release `pptx` CLI/engine: about `4020/1763 us` -> about `3953/1598 us`
  - regular release `pptx` CLI/engine: about `4732/2924 us` -> about `4684/2234 us`
  - stage `pipeline.pptx.speaker_notes.presentation_relationships_read`: to about `665 ns`
  - stage `pipeline.pptx.speaker_notes.convert_total`: held around `862 us` with better relationship/read attribution
- Verification:
  - targeted OOXML package / `pptx` / `docx` / `xlsx` tests
  - `moon test tests`
  - `moon check`
  - `bash samples/check.sh --format docx`
  - `bash samples/check.sh --format pptx`
  - `bash samples/check.sh --format xlsx`
  - `bash samples/check.sh --check-inventory`

### P17-C HTML Lowering Traversal Reduction

- Start HEAD: `4dc29f0`
- End HEAD: `3b531bd`
- Files changed:
  - `formats/html/parser.mbt`
- Main changes:
  - removed repeated child-block re-sorting in lowering helpers that already consume source-ordered semantic children
  - turned inline-segment region assignment into a monotonic forward walk instead of restarting from zero for each inline fact
  - collapsed child-block match fallback from a second full pass into a single-pass exact-or-first-tag fallback
- Attempt summary:
  - attempt 1 produced the kept change set above and passed targeted correctness with stable positive signals
  - attempt 2 also removed top-level block re-sorting, but follow-up release/stage measurements were less stable, so that narrower patch was reverted
- Before/after highlights from the kept attempt:
  - smoke release `html` by-format CLI/engine: `6179/2867 us` -> `5463/2879 us` on first compare and later final smoke `5206/2699 us`
  - regular focused `moonbit-engine` HTML run:
    - `html_small_synthetic_articles_v1` median about `6510 us` baseline compare -> about `5381 us`
    - `html_medium_wcag22_v1` median about `55131 us` baseline compare -> about `51269 us`
  - final release pipeline stage:
    - `html_document_to_ir` about `4.60 ms`
    - `html_lower_prepare` about `444.49 us`
    - `registry_parse` about `4.72 ms`
    - `convert_total` about `4.79 ms`
  - final release product smoke:
    - `html_small_synthetic_articles_v1` about `4.81 ms`
    - `epub_small_basic_spine_v1` about `181.54 us`
- Verification:
  - `moon test --target native --package formats/html`
  - `moon test --target native --package formats/epub`
  - `moon test --target native --package formats/xml`
  - `moon test tests`
  - `moon check`
  - `bash samples/check.sh --format html`
  - `bash samples/check.sh --format epub`
  - `bash samples/check.sh --format xml`
  - `bash samples/check.sh --check-inventory`

### P17-D Benchmark Report Robustness and Round-Two Report

- Start HEAD: `3b531bd`
- End HEAD: `bba237d` before final round-two status doc commit
- Files changed:
  - `bench/runner/result/summary.mbt`
  - `bench/runner/result/summary_wbtest.mbt`
  - `bench/runner/README.md`
  - `docs/architecture/benchmark-architecture.md`
  - `docs/architecture/product-mainline-optimization-round2-status.md`
- Main changes:
  - summary warnings now explicitly flag non-ok external baseline rows and external-only gaps where MoonBit CLI/engine remained ok
  - markdown reports now include `Comparison Coverage`, `External Baseline Non-OK Rows`, and `MoonBit Non-OK Rows`
  - by-format tables now surface CLI/engine/external ok-row counts beside comparable-row counts
- Final release validation artifacts:
  - overhead report: `bench/runner/reports/run-1782339581097-n690a1ae3-overhead.md`
  - smoke summary/report: `bench/runner/results/run-1782339582021-7e52cedf-summary.json`, `bench/runner/reports/run-1782339582021-7e52cedf.md`
  - regular summary/report: `bench/runner/results/run-1782339619815-7ada8288-summary.json`, `bench/runner/reports/run-1782339619815-7ada8288.md`
- Final release highlights:
  - smoke by-format medians:
    - `txt` CLI/engine `3327/745 us`
    - `csv` CLI/engine `4582/1813 us`
    - `tsv` CLI/engine `5205/2371 us`
    - `html` CLI/engine `5206/2699 us`
    - `epub` CLI/engine `3282/660 us`
    - `pptx` CLI/engine `3322/1581 us`
    - `xlsx` CLI/engine `2695/477 us`
  - regular by-format medians:
    - `txt` CLI/engine `3982/1385 us`
    - `csv` CLI/engine `6486/3584 us`
    - `tsv` CLI/engine `7736/4593 us`
    - `html` CLI/engine `7718/5364 us`
    - `epub` CLI/engine `3937/1159 us`
    - `pptx` CLI/engine `5183/2196 us`
    - `xlsx` CLI/engine `2711/706 us`
    - `json` status `partial` only because external `markitdown` failed `json_medium_spdx_licenses_v1`
  - regular report coverage:
    - selected rows `42 / 42`
    - CLI comparable rows `41`
    - engine comparable rows `41`
    - MoonBit CLI ok rows `42`
    - MoonBit engine ok rows `42`
    - MarkItDown ok rows `41`
    - MarkItDown non-ok rows `1`
    - MoonBit-only success rows excluded by external baseline `1`
  - final overhead medians:
    - `process_true` `1491 us`
    - `moonbit_cli_help` `2799 us`
    - `moonbit_cli_tiny_txt` `2734 us`
    - `moonbit_cli_small_html` `7735 us`
    - `moonbit_engine_tiny_txt` `78 us`
    - `moonbit_engine_small_html` `5052 us`
- Partial external baseline caveat:
  - `json_medium_spdx_licenses_v1` finished `moonbit-cli=ok`, `moonbit-engine=ok`, `markitdown=failed`
  - summary/report now call this an external-only gap instead of leaving it implicit behind format-level `partial`

## Reuse and Redundancy Reduction

- Reused selector metadata to report requested tier accurately at the summary/report top level.
- Reused normalized/original text and preallocated shared event builders in the textlike path.
- Reused cached OOXML sorted-part and relationship lookup work instead of rescanning package structures.
- Reused source-ordered HTML semantic children directly in lowering helpers instead of redoing the same ordering and fallback scans repeatedly.
- Reused summary comparison aggregates to derive external-gap warnings and report coverage tables without changing benchmark raw row semantics.

## Memory and Scan Optimization Summary

- Removed one full-string equality scan and avoided redundant text reconstruction in shared TXT normalization.
- Reduced repeated CSV/TSV row/cell string assembly and shared event-list growth churn.
- Reduced OOXML part sorting and relationship suffix scan overhead on repeated package lookups.
- Reduced HTML lowering child-block reordering and inline region reassignment work.
- Kept semantic-model boundaries intact rather than introducing a broader shared HTML/XML/OOXML abstraction.

## Correctness and Validation Status

Final round-two validation completed successfully:

- `moon fmt`
- `moon info`
- `moon check`
- `moon test bench/runner/command`
- `moon test bench/runner/result`
- `moon test bench/runner/process`
- `moon bench --target native --release --package bench/micro`
- `moon bench --target native --release --package bench/pipeline`
- `moon bench --target native --release --package bench/product`
- `moon test tests`
- `moon test`
- `bash samples/check.sh --check-inventory`
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

## Artifacts Not Committed

- `bench/runner/results/**`
- `bench/runner/reports/**`
- `.tmp/**`
- `.vscode/settings.json`

## Skipped Optimizations and Reasons

- No renderer-targeted code change was added in round two because release measurements still point to parser/build paths rather than renderer as the shared bottleneck.
- A narrower second `P17-C` attempt that also removed top-level block resorting was reverted because follow-up signals were less stable than the kept first attempt.
- The external `markitdown` failure on `json_medium_spdx_licenses_v1` was not treated as a MoonBit regression because MoonBit CLI/engine both remained `ok`.

## P18 Backlog

- Investigate HTML semantic collection map population cost on larger real documents once we have a more targeted stage bench for medium HTML.
- Revisit JSON/YAML structured builder reuse if future release regular numbers show enough engine-side headroom to justify a dedicated phase.
- Continue OOXML medium/large attribution for DOCX where engine time still dominates but current lookup reuse did not justify broader abstraction.
- Evaluate whether benchmark summary JSON should eventually carry explicit external-gap counters in schema, not only report-level warnings.
