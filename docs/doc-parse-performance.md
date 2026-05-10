# doc_parse Performance

This document records the release-facing performance contract for the
`doc_parse/*` foundations inside `ZSeanYves/markitdown`.

It is intentionally narrower than the repository-wide benchmark docs:

* it focuses on lower-layer parsing / inspection foundations
* it distinguishes library hot paths from CLI end-to-end timing
* it does not turn checked local numbers into blanket format claims

## Scope

`doc_parse` performance discussions should separate:

* library parse / inspect / validate work
* converter-layer lowering work
* Markdown / metadata / asset emission
* CLI startup and file I/O

Only the first category belongs directly to `doc_parse`.

## Goal Layers

Performance goals are intentionally tiered.

### Small library hot path

For lightweight formats where startup and file I/O are not dominant:

* TXT / Markdown scanner / CSV / TSV / JSON / YAML / XML / HTML
* target sub-10ms small-case parse or scan paths where realistic
* treat this as a same-machine engineering target, not a universal SLA

### Native CLI end-to-end

Native CLI timings are measured separately because they include:

* process startup
* file open / path handling
* converter lowering
* Markdown / metadata / asset work

End-to-end CLI timing must not be read as library-only `doc_parse` cost.

### Medium and large files

For medium/large files, throughput and distribution matter more than a single
sub-10ms threshold.

Track:

* p50 / p95 where available
* slowest rows
* format-local hotspots

### Office / package / PDF families

Office/package/PDF formats are inherently heavier:

* ZIP / OOXML / EPUB pay archive/package costs
* XLSX / DOCX / PPTX pay OOXML relationship + XML model costs
* PDF pays native text extraction / geometry / model costs

These families should use separate budgets rather than inherit the lightweight
text-format target unchanged.

### Batch mode

Batch mode is a separate concern:

* amortized throughput matters more than single-file latency
* startup cost and repeated setup can dominate small rows
* compare normal-path vs batch-path behavior explicitly

## Current Benchmark Tooling Audit

Current public tooling:

* `./samples/bench.sh --suite smoke`
* `./samples/bench.sh --suite compare`
* `./samples/bench.sh --suite batch-profile`
* `./samples/bench_doc_parse.sh --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format text --stage parse --profile text --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format json --stage parse --profile json --iterations 10 --warmup 2`
* `./samples/bench_doc_parse.sh --format markdown --stage scan --profile markdown --iterations 10 --warmup 2`
* `./samples/bench_product_path.sh --help`
* `./samples/bench_product_path.sh --smoke`
* `./samples/bench_product_path.sh --iterations 10 --warmup 2`

Current benchmark corpus location:

* `samples/benchmark/`

What the current tooling measures well:

* same-machine native CLI smoke timing
* overlap comparison against Microsoft MarkItDown where a fair checked-in row
  exists
* batch-vs-normal profiling with startup and grouped outputs
* per-row summary artifacts under `.tmp/bench/...`
* direct `doc_parse/*` package timing for `open/parse/scan`, `inspect`, and
  `validate` on a checked local manifest without calling `convert/*`
* refined product-path attribution for `txt/json/yaml/csv/xlsx/html/docx/`
  `pptx`, including `startup_probe`, `dispatch`, `parse`, `convert`, `emit`,
  `metadata`, `assets`, and same-process `total`

What it still does not measure directly:

* a perfect `parse` vs `convert` split for every current normal-path format;
  the refined product harness now splits `txt/json/yaml/csv/xlsx`, but still
  records `convert` as `combined_in_parse_current_path=true` for
  `html/docx/pptx` where the shared converter seam is not yet safely split
* a perfect standalone `assets` stage for converter-local asset paths such as
  HTML, DOCX, and PPTX; the refined product harness now records asset counts
  plus discovery/export boundaries, but materialization is still embedded in
  the parse path
* full `doc_parse` coverage for every package and stage in one runner
  (`pdf` is still deferred in the first library-harness round)
* broad p50 / p95 distribution rollups across all suites in a release-facing
  report

Current interpretation rule:

* smoke and compare numbers are still repository-level product timings first
* they are useful for release readiness and hotspot discovery
* they are not, by themselves, proof that a specific `doc_parse` package is
  solely responsible for a row's cost

Current checked state after the focused parser rounds:

* no direct `doc_parse` library row is currently above `10 ms`
* `inspect` and `validate` are not the active bottlenecks
* a refined product-path attribution harness now exists for the initial
  normal-path format set
* the next performance problem is no longer “find a parser hotspot blindly”;
  it is “refine product-path attribution until parse, convert, emit,
  metadata, and assets are cleanly owned”

## Product-path Harness

The repository now also keeps a real product-path attribution harness:

```bash
./samples/bench_product_path.sh --iterations 10 --warmup 2
```

This benchmark differs from `./samples/bench_doc_parse.sh` in two important
ways:

* it measures the actual markitdown normal product path rather than direct
  `doc_parse/*` APIs
* it keeps `startup_probe` separate from same-process `total`

Current measured stages:

* `startup_probe`
* `file_read`
* `dispatch`
* `parse`
* `convert`
* `emit`
* `metadata`
* `assets`
* `total`

Current stage ownership interpretation:

* `startup_probe`: hidden benchmark-only no-op CLI launch
* `file_read`: standalone file-read probe row, not subtracted from `parse`
* `dispatch`: format detection plus converter selection
* `parse`: current real normal-path parse/model-build entry
* `convert`: model lowering / IR construction where the current converter seam
  can be safely split
* `emit`: Markdown emit plus markdown write
* `metadata`: sidecar construction plus write
* `assets`: asset discovery/export notes; still embedded in parse for current
  HTML/DOCX/PPTX paths
* `total`: same-process product path total excluding `startup_probe`

Current split status:

* split now available:
  `txt`, `json`, `yaml`, `csv`, `xlsx`
* still combined for now:
  `html`, `docx`, `pptx`

Current combined reasons:

* `html`:
  DOM scan, block lowering, and local image export still share the current
  entrypoint
* `docx`:
  package/rels/notes/assets/IR scan still share the current entrypoint
* `pptx`:
  slide parse, final classification, and image export still share the current
  entrypoint

Current assets interpretation:

* `html/docx/pptx` now report asset counts plus discovery/export boundaries in
  the `assets` notes
* the measured `assets` row is still `0 ms` on those formats in the current
  harness because export remains embedded inside `parse`
* other current first-batch formats report `skipped=assets_disabled`

## Library Harness

The direct `doc_parse/*` harness is intentionally separate from
`./samples/bench.sh`:

```bash
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

Key design points:

* one native benchmark process performs many in-process iterations
* the harness calls `doc_parse/*` APIs directly and never routes through
  `convert/*`
* the checked manifest lives at `samples/doc_parse_bench/manifest.tsv`
* summary artifacts are written under `.tmp/bench/doc_parse/`
* `--profile xlsx` adds internal XLSX parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics
* `--profile docx` adds internal DOCX parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics
* `--profile yaml` adds internal YAML-subset parse sub-stage rows for hotspot
  attribution without changing the default benchmark manifest or parser
  semantics
* `--profile text` adds internal text parse sub-stage rows for hotspot
  attribution without changing the normalized text document model
* `--profile json` adds internal JSON parse sub-stage rows for hotspot
  attribution without changing JSON validity rules or value semantics
* `--profile markdown` adds internal Markdown scan sub-stage rows for hotspot
  attribution without turning the scanner into a full Markdown parser

Measured stage model:

* lightweight text/markup/scanner packages:
  `parse` or `scan`, then `inspect`, then `validate` where that surface exists
* package/container foundations:
  `open`, then `inspect`, then `validate`
* OOXML semantic sublayers:
  semantic `parse_*_from_package` is measured on a pre-opened OOXML package so
  generic ZIP/OOXML open cost can be attributed separately

Interpretation caveats:

* sample file I/O is intentionally excluded from the measured inner loops
* the harness measures package APIs as they are exposed today, so
  string-oriented parsers and byte/package-open foundations are not forced into
  one artificial shape
* stage columns still use `*_ms`, but the harness records them with sub-ms
  decimal precision
* xlsx profile rows are stage-attribution aids, not release-facing stable API
  or latency promises
* docx profile rows are stage-attribution aids, not release-facing stable API
  or latency promises
* yaml profile rows are stage-attribution aids, not release-facing stable API
  or latency promises
* text/json/markdown profile rows are stage-attribution aids, not
  release-facing stable API or latency promises
* these profile helpers exist for benchmark attribution only and are not the
  main stable candidate API surface of their packages

## Current Baseline Commands

Release-facing baseline commands for this round:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

## Current Baseline Snapshot

The measured snapshot for this round is recorded in
[`docs/performance-baseline.md`](./performance-baseline.md).

Interpretation notes stay the same:

* lightweight text/structured formats are the primary candidates for sub-10ms
  library-path goals
* Office/package/PDF families need format-local budgets
* CLI startup and output work remain mixed into the repository-level smoke rows
* the library harness is the current source of truth for direct `doc_parse/*`
  timing and hotspot attribution
* any row above 10ms in the current smoke benchmark is a hotspot candidate,
  not automatic evidence of a `doc_parse` regression by itself

## Focused XLSX Follow-up

The current harness now includes an XLSX-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format xlsx --stage parse --profile xlsx --iterations 10 --warmup 2
```

This mode exists to answer a narrow question: where the time goes inside
`parse_xlsx_workbook_from_package` on checked formula-heavy samples.

Current interpretation:

* the profile is only for hotspot attribution
* it does not change workbook semantics, formula trace policy, or validation
  behavior
* it should not be mistaken for a stable release-facing XLSX profiling API

## Focused DOCX Follow-up

The current harness also includes a DOCX-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format docx --stage parse --profile docx --iterations 10 --warmup 2
```

This mode exists to answer a similarly narrow question: where the time goes
inside `parse_docx_document_from_package` on checked link-heavy samples.

Current checked follow-up result:

* `docx_link_heavy / parse`: `8.735 ms -> 4.985 ms`
* main remaining stage in the profile: `body_scan`
* `text_boxes`, `hyperlink_resolution`, and `media_resolution` are now
  effectively no-op or near-no-op on this sample

Current interpretation:

* the profile is only for hotspot attribution
* it does not change the source-native DOCX semantic model
* it does not switch `convert/docx` normal-path ownership
* it should not be mistaken for a stable release-facing DOCX profiling API

## Focused YAML Follow-up

The current harness also includes a YAML-specific profile mode:

```bash
./samples/bench_doc_parse.sh --format yaml --stage parse --profile yaml --iterations 10 --warmup 2
```

This mode exists to answer a narrower parser question: where the time goes
inside `parse_yaml_document` on checked large subset samples.

Current checked follow-up result:

* `yaml_large / parse`: `6.907 ms -> 5.925 ms` on the focused parse run
* main remaining stages in the profile: `parse_sequence`, `parse_nodes`,
  `parse_mapping`
* the main improvement came from cheaper line preparation and less repeated
  trim/copy work, not from changing YAML subset behavior

Current interpretation:

* the profile is only for hotspot attribution
* it does not expand or narrow the YAML subset boundary
* it does not change `convert/yaml` output ownership
* it should not be mistaken for a stable release-facing YAML profiling API

## Focused Lightweight Large-input Follow-up

The current harness also includes focused profile modes for text, JSON, and
Markdown:

```bash
./samples/bench_doc_parse.sh --format text --stage parse --profile text --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format json --stage parse --profile json --iterations 10 --warmup 2
./samples/bench_doc_parse.sh --format markdown --stage scan --profile markdown --iterations 10 --warmup 2
```

Current checked follow-up results:

* `txt_large / parse`: `4.991 ms -> 1.952 ms`
* `json_large / parse`: `4.247 ms -> 2.805 ms`
* `markdown_large / scan`: `3.391 ms -> 2.181 ms`

Current interpretation:

* `text` improved by collapsing newline normalization, line splitting, and
  paragraph reconstruction into one pass without changing the plain-text
  source-native model
* `json` improved by preparing normalized char buffers directly and fast-path
  parsing plain strings without changing JSON validity or value semantics
* `markdown` improved by precomputing line-level trim metadata so the scanner
  stops re-trimming and re-classifying the same raw lines
* these profile modes exist only for hotspot attribution; they do not widen
  format support or change converter ownership boundaries

## Product-path Attribution Harness

The next performance phase is now implemented as a refined benchmark for the
repository product path:

```bash
./samples/bench_product_path.sh --help
./samples/bench_product_path.sh --smoke
./samples/bench_product_path.sh --iterations 10 --warmup 2
```

Current stage model:

* `startup_probe`
* `file_read`
* `dispatch`
* `parse`
* `convert`
* `emit`
* `metadata`
* `assets`
* `total`

Current first-batch format set:

* `txt`
* `json`
* `yaml`
* `csv`
* `xlsx`
* `html`
* `docx`
* `pptx`

Current implementation notes:

* the harness uses a hidden benchmark-only CLI entrypoint and does not change
  normal CLI behavior
* `startup_probe` is measured as a separate no-op process launch
* `file_read` is currently a standalone probe row; it is not subtracted from
  the measured `parse` row
* `parse` is the real current normal-path parse/conversion entry; for
  `txt/json/yaml/csv/xlsx` it now records direct parse/model-build work, and
  for intentionally unswitched formats it still records the converter-local
  combined path
* `convert` is now split for `txt/json/yaml/csv/xlsx`, and remains
  `combined_in_parse_current_path=true` for `html/docx/pptx`
* `assets` is still recorded as `embedded_in_parse_current_path=true` for
  current HTML/DOCX/PPTX asset flows while now reporting the current
  discovery/export boundaries

Current checked baseline snapshot from the refined harness:

* `startup_probe`: `12.886 ms` avg
* slowest total rows:
  * `txt_large`: `15.744 ms`
  * `docx_image_alt_title_basic`: `4.857 ms`
  * `pptx_image_alt_title_basic`: `2.916 ms`
  * `xlsx_metadata_formula_or_merged_policy`: `2.489 ms`
* slowest stage rows:
  * `txt_large / parse`: `9.300 ms`
  * `txt_large / convert`: `3.600 ms`
  * `docx_image_alt_title_basic / parse`: `3.666 ms`
  * `txt_large / emit`: `2.495 ms`
  * `pptx_image_alt_title_basic / parse`: `1.398 ms`
  * `pptx_image_alt_title_basic / metadata`: `1.198 ms`

Interpretation:

* this harness now makes the repository product path measurable without
  claiming that every stage is perfectly separated already
* it is precise enough to show whether startup, parse, emit, metadata, or
  asset-enabled rows dominate a sample
* the current refinement already split `parse` vs `convert` for
  `txt/json/yaml/csv/xlsx`
* the next refinement should isolate converter-local `assets` timing more
  cleanly and then extend the split to `html/docx/pptx` without changing
  behavior

## Library vs CLI Guidance

When diagnosing a slow row:

1. identify whether the row is lightweight text, package/container, OOXML
   semantic, or PDF
2. determine whether the dominant cost is likely parsing, converter lowering,
   Markdown emission, metadata/assets, or CLI startup
3. optimize `doc_parse` only when the lower-layer hotspot is real and the fix
   preserves correctness, validation, and safety boundaries

## Non-goals

This document does not claim:

* sub-10ms for every format and file size
* full parse/convert/emit decomposition from the current public harness
* full spec support as a prerequisite for performance claims
* that converter/product policy belongs in `doc_parse`
