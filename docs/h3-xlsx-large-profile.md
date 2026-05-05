# H3 XLSX Large-Sheet Profile

This document records the first XLSX-focused H3 profiling pass after benchmark
runner normalization, and the follow-up worksheet XML materialization pass
driven by that profile.

It is a local-machine profiling note, not a universal performance claim. These
passes add opt-in timing instrumentation and a narrowly scoped XLSX worksheet
materialization optimization. They do not change XLSX output semantics,
metadata schema, expected sample outputs, checked-in corpora, or benchmark
thresholds.

## 1. Scope

Questions for these passes:

* where does current `xlsx_large` time go under the normalized native-preferred
  benchmark path?
* inside `worksheet_xml_read`, is the cost dominated by ZIP lookup,
  decompression, or bytes-to-string materialization?

Non-goals:

* no corpus or threshold change
* no benchmark-policy change
* no output-semantic change
* no streaming-parser rewrite
* no date/style/cell-decode behavior change

## 2. Environment And Runner

Validation and profiling were run on the same local machine used for the
current H3 benchmark work:

* OS: macOS `15.3`
* arch: `arm64`
* MoonBit: `moon 0.1.20260427 (48d7def 2026-04-27)`
* normalized smoke runner: prebuilt native CLI
* profiled CLI:
  `_build/native/debug/build/cli/cli.exe`

Profiling was enabled with:

```bash
MARKITDOWN_PROFILE_XLSX=1 _build/native/debug/build/cli/cli.exe \
  normal samples/benchmark/xlsx/xlsx_large.xlsx \
  .tmp/h3-xlsx-materialization-after3/xlsx_large.md
```

The profiling log is written only when the environment flag is enabled and is
kept as a local `.tmp` artifact:

* `.tmp/<run>/debug/<name>.xlsx.profile.log`

## 3. Pipeline Stage Map

Current XLSX conversion path for `normal` CLI:

1. ZIP/package open
2. `xl/workbook.xml` read
3. workbook relationships / sheet discovery
4. `sharedStrings.xml` parse if present
5. `styles.xml` parse if present
6. per-sheet worksheet XML read
7. worksheet XML scan for cells
8. merged-range scan
9. cell decode loop
10. sparse used-range to rectangular row rendering
11. workbook/sheet lowering into IR blocks
12. Markdown emission
13. markdown file write
14. optional OOXML document-properties read
15. optional metadata JSON emission
16. optional metadata file write

Current sample structure for `samples/benchmark/xlsx/xlsx_large.xlsx`:

* archive entries: `9`
* sheets: `1`
* sheet name: `Large`
* `sharedStrings.xml`: absent
* `styles.xml`: present
* worksheet XML bytes: `99,775`
* decoded cells: `2,406`
* rendered table rows: `401`
* rendered table cells: `2,406`
* emitted markdown bytes: `18,442`
* emitted metadata bytes: `43,819`

## 4. Profiling Implementation

These passes add an opt-in XLSX profiling path:

* env flag: `MARKITDOWN_PROFILE_XLSX=1`
* parser-side stage capture in `convert/xlsx`
* CLI-side stage capture for:
  * total parse
  * markdown emit
  * markdown write
  * metadata document-properties read
  * metadata JSON emit
  * metadata write
* profile output is written to a local debug log under the markdown output root

Normal output behavior remains unchanged when the env flag is unset.

The worksheet XML read stage was also split more finely so the profile can
separate:

* worksheet entry lookup
* worksheet entry decompress/read
* worksheet bytes-to-string decode
* total worksheet XML read

## 5. Worksheet XML Read Audit

Audit result for the `worksheet_xml_read` path:

| Stage | Current behavior | Possible cost | Action |
| ----- | ---------------- | ------------- | ------ |
| ZIP entry lookup | uses `archive.entry_index : Map[String, Int]` through `@zip.read_entry` | expected O(1), not a repeated linear scan hotspot | profiled separately |
| OOXML part existence | `pkg.part_index.contains(...)` lookup on normalized part name | tiny lookup cost; one redundant check was avoidable on worksheet read path | keep one lookup in profiled helper; remove redundant pre-read `has_part` on worksheet path |
| ZIP entry decompress/read | `@zip.read_entry` validates local header, slices payload, and inflates if needed | possible cost for large compressed XML | profiled separately |
| bytes to string | worksheet XML bytes decoded to UTF-8 text before parser scans string slices | strong candidate for repeated allocation / materialization cost | profiled separately; optimized |
| worksheet parser handoff | parser consumes one in-memory XML string | low if materialized string is already ready | no semantic change |

Key audit conclusion:

* worksheet entry lookup was already indexed and not the primary hotspot
* the main suspicion was bytes-to-string materialization rather than archive
  lookup

## 6. Native `xlsx_large` Timing Breakdown

Before the worksheet XML materialization pass, normalized smoke result for this
sample was:

* `xlsx/xlsx_large`: `212 ms` median in `bench_smoke.sh`
* runner: `prebuilt-native`

Representative pre-optimization native profile log:

| Stage | Elapsed ms | Notes |
| ----- | ---------: | ----- |
| `worksheet_entry_lookup:Large` | 0 | indexed lookup on normalized worksheet part name |
| `worksheet_entry_decompress:Large` | 0 | ZIP entry access and inflate were below timer resolution on this sample |
| `worksheet_bytes_to_string:Large` | 187 | dominant cost; worksheet XML bytes decoded to text |
| `worksheet_xml_read:Large` | 187 | read/materialization stage total |
| `worksheet_collect_cells:Large` | 3 | raw `<c ...>` scan |
| `worksheet_merged_ranges:Large` | 1 | merged range scan |
| `worksheet_cell_decode_loop:Large` | 2 | cell type decode / style / date formatting / map fill |
| `worksheet_render_rows:Large` | 0 | sparse used-range to rectangular rows |
| `worksheet_model_parse_total:Large` | 6 | total of worksheet-model build after XML read |
| `markdown_emit` | 2 | Markdown table emission is small for this sample |
| `metadata_json_emit` | 2 | metadata sidecar cost is small |
| `cli_parse_total` | 194 | total parse path, dominated by worksheet XML read |

Interpretation:

* the dominant cost in this sample is not metadata
* the dominant cost in this sample is not Markdown emission
* the dominant cost in this sample is not the cell-decode loop itself
* the largest visible hotspot is worksheet XML bytes-to-string materialization
* ZIP lookup and decompress are not the main hotspot for this sample
* parser-side lowering after the XML string is in memory is comparatively small

## 7. Worksheet XML Materialization Pass

The materialization pass made two narrowly scoped changes:

1. switch XLSX part decoding from `@cor.utf8_bytes_to_string(...)` to
   `@utf8.decode(..., ignore_bom=true)`
2. remove one redundant worksheet `has_part(...)` check before the actual read

Why this was safe:

* it preserves the same UTF-8 text semantics expected by the XLSX parser
* it does not alter worksheet traversal, style/date handling, sparse rendering,
  Markdown emission, or metadata schema
* XLSX sample and package tests stayed green after the change

Representative post-optimization native profile log:

| Stage | Elapsed ms | Notes |
| ----- | ---------: | ----- |
| `worksheet_entry_lookup:Large` | 0 | unchanged; still not the hotspot |
| `worksheet_entry_decompress:Large` | 0 | unchanged; still below timer resolution |
| `worksheet_bytes_to_string:Large` | 0 | hotspot collapsed below timer resolution |
| `worksheet_xml_read:Large` | 0 | total worksheet XML read also below timer resolution |
| `worksheet_collect_cells:Large` | 2 | parser scanning now shows up as a larger visible share |
| `worksheet_merged_ranges:Large` | 1 | unchanged scale |
| `worksheet_cell_decode_loop:Large` | 2 | unchanged scale |
| `worksheet_render_rows:Large` | 1 | unchanged scale |
| `worksheet_model_parse_total:Large` | 6 | unchanged order of magnitude |
| `markdown_emit` | 1 | still small |
| `metadata_json_emit` | 3 | still small |
| `cli_parse_total` | 7 | main parse path now dominated by non-materialization work |

The stage timer is millisecond-granularity, so post-change zeroes should be
read as "below current timer resolution" rather than literal zero-cost.

## 8. Before / After Summary

| Metric | Before | After | Delta |
| ----- | -----: | ----: | ----: |
| smoke `xlsx/xlsx_large` median ms | 212 | 22 | -190 |
| profile `worksheet_bytes_to_string:Large` ms | 187 | <1 | hotspot removed below timer resolution |
| profile `worksheet_xml_read:Large` ms | 187 | <1 | hotspot removed below timer resolution |
| profile `cli_parse_total` ms | 194 | 7 | -187 |

Other native smoke XLSX rows after the pass:

* `xlsx_small`: `11 ms`
* `xlsx_medium`: `13 ms`
* `xlsx_multi_sheet_mixed`: `12 ms`
* `xlsx_multi_sheet_large`: `18 ms`
* `xlsx_sparse_large`: `12 ms`

## 9. Hotspot Classification

Current evidence-based classification:

* original primary hotspot: `worksheet XML bytes-to-string materialization`
* ZIP lookup/decompress: not the primary hotspot on this corpus
* current visible cost after the pass: lightweight worksheet parser work
  (`collect_cells` + decode + row rendering), but all at much lower scale
* not currently primary:
  * `metadata`
  * `Markdown emitter`
  * `assets`

Why this matters:

* the first profile correctly pointed at worksheet XML materialization rather
  than Markdown or metadata
* the narrow materialization pass removed that hotspot without changing output
  semantics
* `xlsx_large` is no longer a high-hundreds-of-ms outlier in the normalized
  smoke harness

## 10. Recommended Next Pass

Recommended next optimization passes after this materialization work:

* `H3 XLSX parser allocation / cell scan pass`
* `H3 large structured-data normalization pass` across `json` / `yaml` /
  `txt` / `csv` / `tsv`

Specific follow-up questions:

* are substring allocations inside worksheet scanning still meaningful now that
  decode cost has dropped out?
* does larger multi-sheet or shared-string-heavy corpus shift the hotspot back
  toward parser or archive work?
* should future stage profiling move to a finer-granularity clock for small
  native runs?

Secondary follow-up after that:

* `H3 XLSX emitter/table-allocation pass` only if larger sheets show emitter
  cost rising materially

## 11. Caveats

Important caveats for reading this profile:

* this is local-machine data
* the profile log is diagnostic, not a checked-in benchmark artifact
* stage percentages are only meaningful for this current instrumentation
  boundary
* the current CLI profiling path still writes metadata sidecar stages in the
  log because local output-path parsing currently routes this command shape
  through a markdown-root path that produces sidecar files; this did not affect
  the hotspot conclusion because metadata cost remained tiny

## 12. Validation

Validation for this pass:

```bash
moon fmt
moon check
moon test convert/xlsx/test
moon test convert/convert/test
./samples/check.sh
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_warn.sh --all
```

Observed result after the materialization pass:

* validation passed
* smoke remained clean
* `bench_warn --all` remained clean
* no converter-semantics regressions were introduced in this pass
