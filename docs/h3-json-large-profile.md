# H3 JSON Large-Structure Profile

This document records the H3 JSON large-structure profiling pass that followed
the post-XLSX optimization benchmark refresh.

It is a local-machine profiling note, not a universal performance claim. This
pass adds opt-in JSON timing instrumentation and a narrowly scoped UTF-8 decode
optimization that does not change JSON output semantics, metadata schema,
expected sample outputs, checked-in corpora, or benchmark thresholds.

## 1. Scope

Questions for this pass:

* where does `json_large` time go under the normalized native-preferred smoke
  path?
* is the current hotspot in file IO, bytes-to-string materialization, recursive
  JSON parse, uniform-table detection, nested compact stringification, Markdown
  emit, or metadata?
* does `json_array_objects_large` stress a different path from `json_large`?

Non-goals:

* no JSON syntax/grammar behavior change
* no metadata schema change
* no sample expected change
* no benchmark corpus or threshold change
* no broad emitter rewrite

## 2. Environment And Runner

Validation and profiling used the same local machine and native-preferred CLI
path already used by current H3 benchmark work:

* normalized smoke runner: prebuilt native CLI
* profiled CLI: `_build/native/debug/build/cli/cli.exe`
* opt-in env flag: `MARKITDOWN_PROFILE_JSON=1`

Representative profile commands:

```bash
MARKITDOWN_PROFILE_JSON=1 _build/native/debug/build/cli/cli.exe \
  normal samples/benchmark/json/json_large.json \
  .tmp/h3-json-large-only/json_large.md

MARKITDOWN_PROFILE_JSON=1 _build/native/debug/build/cli/cli.exe \
  normal samples/benchmark/json/json_array_objects_large.json \
  .tmp/h3-json-array-only/json_array_objects_large.md
```

Profile logs are local `.tmp` artifacts only:

* `.tmp/<run>/debug/<name>.json.profile.log`

## 3. JSON Pipeline Stage Map

Current JSON conversion path for `normal` CLI:

1. file read to bytes
2. UTF-8 bytes-to-string decode
3. BOM/CRLF normalization
4. recursive JSON parse
5. root-shape classification
6. object lowering to key/value RichTable, or
7. array lowering:
   * scalar list lowering, or
   * uniform object-array detection to RichTable, or
   * conservative CodeBlock fallback with compact JSON stringify
8. Markdown emission
9. markdown file write
10. metadata JSON emission
11. metadata file write

Two benchmark inputs used for this pass:

* `samples/benchmark/json/json_large.json`
  * bytes: `86,088`
  * root: object
  * output markdown bytes: `86,120`
* `samples/benchmark/json/json_array_objects_large.json`
  * bytes: `55,136`
  * root: array of uniform objects
  * output markdown bytes: `33,590`

## 4. Profiling Implementation

This pass adds opt-in JSON profiling in two layers:

Parser/lowering side in `convert/json`:

* `json_file_read`
* `json_bytes_to_string`
* `json_normalize_source`
* `json_parse_total`
* `json_detect_uniform_table`
* `json_compact_stringify_nested`
* `json_lower_to_ir`

CLI side:

* `cli_parse_total`
* `markdown_emit`
* `markdown_write`
* `metadata_document_properties`
* `metadata_json_emit`
* `metadata_write`

Normal output behavior remains unchanged when `MARKITDOWN_PROFILE_JSON` is not
set.

## 5. Baseline Profile Before The Tiny Fix

### `json_large`

Representative baseline profile:

| Stage | Elapsed ms | Notes |
| ----- | ---------: | ----- |
| `json_file_read` | 1 | file IO is small |
| `json_bytes_to_string` | 137 | dominant hotspot |
| `json_normalize_source` | 2 | small |
| `json_parse_total` | 2 | recursive parser is not the main issue |
| `json_detect_uniform_table` | 0 | not relevant for root object case |
| `json_compact_stringify_nested` | 4 | small nested fallback stringify |
| `json_lower_to_ir` | 5 | lowering is small |
| `cli_parse_total` | 147 | total parse path dominated by decode |
| `markdown_emit` | 6 | not the leading hotspot |
| `metadata_json_emit` | 7 | not the leading hotspot |

### `json_array_objects_large`

Representative baseline profile:

| Stage | Elapsed ms | Notes |
| ----- | ---------: | ----- |
| `json_file_read` | 0 | file IO is tiny |
| `json_bytes_to_string` | 58 | dominant hotspot |
| `json_normalize_source` | 1 | small |
| `json_parse_total` | 2 | parser not dominant |
| `json_detect_uniform_table` | 0 | uniform table detection is cheap on this case |
| `json_compact_stringify_nested` | 0 | no nested stringify fallback here |
| `json_lower_to_ir` | 0 | lowering is small |
| `cli_parse_total` | 61 | total parse path dominated by decode |
| `markdown_emit` | 2 | small |
| `metadata_json_emit` | 4 | small |

Initial interpretation:

* the main hotspot was not recursive parse
* the main hotspot was not RichTable detection
* the main hotspot was not Markdown emission
* the main hotspot was bytes-to-string materialization

## 6. Tiny Fix

The evidence matched the earlier XLSX pattern closely, so this pass made one
small targeted optimization:

* switch JSON decode from `@cor.utf8_bytes_to_string(...)` to
  `@utf8.decode(..., ignore_bom=false)`

Why this was safe:

* BOM handling still remains in the JSON normalization stage
* parser grammar, root-shape classification, lowering, nested stringify,
  Markdown output, and metadata schema were unchanged
* output bytes for the profiled benchmark cases remained identical before and
  after the change

## 7. After The Tiny Fix

### `json_large`

Representative post-fix profile:

| Stage | Before ms | After ms | Notes |
| ----- | --------: | -------: | ----- |
| `json_bytes_to_string` | 137 | <1 | hotspot removed below timer resolution |
| `json_parse_total` | 2 | 3 | parser becomes more visible only because decode shrank |
| `json_compact_stringify_nested` | 4 | 3 | still small |
| `json_lower_to_ir` | 5 | 3 | still small |
| `cli_parse_total` | 147 | 8 | parse path no longer dominated by decode |
| `markdown_emit` | 6 | 5 | emitter is visible but not dominant |
| `metadata_json_emit` | 7 | 7 | unchanged scale |

### `json_array_objects_large`

Representative post-fix profile:

| Stage | Before ms | After ms | Notes |
| ----- | --------: | -------: | ----- |
| `json_bytes_to_string` | 58 | 1 | hotspot nearly removed |
| `json_parse_total` | 2 | 2 | parser still small |
| `json_detect_uniform_table` | 0 | 0 | table detection still cheap |
| `json_lower_to_ir` | 0 | 0 | still tiny |
| `cli_parse_total` | 61 | 4 | parse path largely cleared |
| `markdown_emit` | 2 | 2 | unchanged |
| `metadata_json_emit` | 4 | 4 | unchanged |

Current timer caveat:

* sub-millisecond stages collapse to `0` under the current coarse stage timer
* interpret those rows as "below current timer resolution", not literal zero

## 8. Smoke Impact

Current smoke comparison for JSON benchmark rows:

| Sample | Before median ms | After median ms | Delta |
| ------ | ---------------: | --------------: | ----: |
| `json_large` | 196 | 30 | -166 |
| `json_array_objects_large` | 85 | 20 | -65 |

Other current smoke JSON rows:

* `json_nested_object`: `12 ms`
* `json_small`: `10 ms`
* `json_medium`: `11 ms`

After this fix, JSON is no longer the top H3 smoke bottleneck on this local
machine.

## 9. Hotspot Classification

Updated evidence-based classification after the tiny fix:

* original primary hotspot: UTF-8 bytes-to-string materialization
* parser: not dominant for the current benchmark cases
* uniform object-array RichTable detection: not dominant
* nested compact stringify: visible on `json_large`, but small
* Markdown emitter: visible but not the main budget consumer
* metadata: not a leading cost center
* file IO: not a leading cost center

This makes JSON much closer to a solved H3 micro-pass than an open first-tier
bottleneck.

## 10. Recommended Next Pass

After this JSON pass, the next likely H3 targets shift again:

* `yaml` large structured-data profiling
* large text/table emission profiling across `txt` / `csv` / `tsv`

JSON may still merit later parser/allocation cleanup, but it no longer looks
like the next top-priority same-machine hotspot.

## 11. Validation

Validation for this pass:

```bash
moon fmt
moon check
moon test convert/json/test
moon test convert/convert/test
./samples/check.sh
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_warn.sh --all
```

Observed result:

* validation passed
* sample checks remained green
* smoke remained clean
* `bench_warn --all` remained clean
* JSON output bytes for the profiled benchmark samples were unchanged
