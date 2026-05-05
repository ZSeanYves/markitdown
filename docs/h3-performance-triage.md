# H3 Performance Triage

This document records the first H3 performance triage pass after benchmark
runner normalization.

It is based on local-machine benchmark outputs under `.tmp/bench/...`. It is
not a universal performance claim, and it does not change converter semantics,
benchmark thresholds, benchmark corpora, or checked-in expected outputs.

## 1. Scope And Caveats

This pass answers one question:

* after runner normalization, where should the first real H3 optimization pass
  land?

This pass does not:

* optimize converters
* widen support claims
* redefine the `v0.3.0` baseline freeze
* treat selected overlap comparisons as blanket parity or blanket speed claims

## 2. Environment And Runner Normalization

Local benchmark commands used for this triage:

```bash
moon check
./samples/check.sh
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_compare_markitdown.sh
./samples/scripts/bench_batch_profile.sh
./samples/scripts/bench_warn.sh --all
```

Observed runner state:

* validation: native-preferred
* smoke benchmark: `prebuilt-native`
* overlap comparison: `prebuilt-native` for `markitdown-mb`
* batch profile: `prebuilt-native`
* warning script: runner-aware for smoke

Interpretation note:

* the earlier `docx/golden 10075 ms` smoke warning was a `moon run` wrapper
  artifact
* the normalized native smoke rerun placed `docx/golden` at `49 ms` on this
  machine
* current H3 triage should therefore focus on the normalized native data, not
  the older wrapper-inflated smoke result

## 3. Smoke Slowest Samples

Smoke summary:

* sample count: `75`
* failures: `0`
* runner kind: `prebuilt-native`
* warning status: none

Top 10 slowest smoke rows by median:

| Rank | Format | Sample | Median ms | Runner | Notes |
| ---: | ------ | ------ | --------: | ------ | ----- |
| 1 | `xlsx` | `xlsx_large` | 216 | `prebuilt-native` | clear top outlier; large workbook/table payload |
| 2 | `json` | `json_large` | 186 | `prebuilt-native` | large structured-data lowering |
| 3 | `yaml` | `yaml_large` | 158 | `prebuilt-native` | large structured-data lowering |
| 4 | `txt` | `txt_large` | 143 | `prebuilt-native` | large text emission path |
| 5 | `csv` | `csv_large` | 101 | `prebuilt-native` | large table emission |
| 6 | `tsv` | `tsv_large` | 90 | `prebuilt-native` | large table emission |
| 7 | `json` | `json_array_objects_large` | 87 | `prebuilt-native` | array/object-heavy structured-data lowering |
| 8 | `zip` | `zip_large_many_entries` | 62 | `prebuilt-native` | archive traversal / IO / repeated dispatch |
| 9 | `docx` | `golden` | 49 | `prebuilt-native` | no longer a warning; moderate only after normalization |
| 10 | `yaml` | `yaml_sequence_mappings_large` | 37 | `prebuilt-native` | sequence-heavy YAML lowering |

Per-format average median / max on this run:

| Format | Avg median ms | Max median ms | Notes |
| ------ | ------------: | ------------: | ----- |
| `json` | 61.80 | 186 | large structured rows dominate |
| `xlsx` | 53.33 | 216 | one large workbook clearly leads |
| `txt` | 47.50 | 143 | large text row is the main driver |
| `yaml` | 46.20 | 158 | large nested rows dominate |
| `csv` | 38.50 | 101 | large-table emission path |
| `tsv` | 32.75 | 90 | large-table emission path |
| `docx` | 28.43 | 49 | no native smoke crisis after normalization |

Current smoke read:

* the native smoke board is no longer DOCX-led
* the strongest same-machine slow rows are now large structured data, large
  worksheets, and large flat text/table emission cases

## 4. Compare Bottom Speedups

Comparison summary:

* paired cases: `18`
* failures: `0`
* formats covered: `docx`, `pptx`, `xlsx`, `pdf`, `html`, `csv`, `txt`,
  `markdown`
* Python MarkItDown availability: available as `markitdown 0.1.5`

Bottom speedups by `python_ms / mb_ms`:

| Rank | Format | Sample | mb ms | python ms | Speedup | Notes |
| ---: | ------ | ------ | ----: | --------: | ------: | ----- |
| 1 | `docx` | `docx_heading_levels_compare` | 34 | 599 | 17.62x | lowest overlap speedup in current set |
| 2 | `docx` | `docx_list_nested_compare` | 28 | 630 | 22.50x | still a strong win, but lowest DOCX cluster |
| 3 | `xlsx` | `xlsx_multi_sheet_mixed_compare` | 22 | 502 | 22.82x | useful signal for workbook traversal cost |
| 4 | `pptx` | `pptx_slide_order_compare` | 14 | 502 | 35.86x | not a current concern |
| 5 | `pptx` | `pptx_title_bullets_compare` | 16 | 574 | 35.88x | not a current concern |
| 6 | `docx` | `docx_table_multiline_cell_compare` | 17 | 656 | 38.59x | still large margin |
| 7 | `pdf` | `text_simple_compare` | 13 | 512 | 39.38x | not a current concern |
| 8 | `pptx` | `pptx_hyperlink_basic_compare` | 14 | 561 | 40.07x | not a current concern |
| 9 | `pdf` | `heading_basic_compare` | 13 | 521 | 40.08x | not a current concern |
| 10 | `pdf` | `pdf_repeated_header_footer_compare` | 13 | 527 | 40.54x | not a current concern |

Interpretation:

* no overlap case is close to parity loss
* nothing in the current overlap set suggests an urgent “Python beats us”
  emergency
* the relative bottom tier is still informative: `docx` heading/list cases and
  `xlsx_multi_sheet_mixed` are the best places to inspect if we want to reduce
  internal overhead even where we already hold a large external speed lead

Output caveat:

* this is semantic-overlap-only
* it does not guarantee identical Markdown, metadata, or asset semantics

## 5. Batch Profile Bottlenecks

Batch profiling summary:

* formats: `csv`, `json`, `html`, `xlsx`, `docx`, `pdf`
* group sizes: `1`, `3`, `8`, `16`
* metadata modes: `without-metadata`, `with-metadata`
* runner kind: `prebuilt-native`
* failures: `0`
* skipped groups: `0`
* memory probe: unavailable on this run (`none`)

Bottom batch speedups:

| Format | Group size | Metadata | Process/file ms | Batch ms | Speedup | Notes |
| ------ | ---------: | -------- | --------------: | -------: | ------: | ----- |
| `pdf` | 1 | off | 33 | 34 | 0.97x | small-group noise; not a product-path concern |
| `docx` | 1 | on | 48 | 31 | 1.55x | startup dominates at tiny scale |
| `json` | 16 | on | 1026 | 657 | 1.56x | weakest large-group speedup; real H3 candidate |
| `docx` | 1 | off | 49 | 31 | 1.58x | startup dominates at tiny scale |
| `xlsx` | 16 | on | 1066 | 673 | 1.58x | weak large-group speedup; real H3 candidate |
| `json` | 16 | off | 1100 | 686 | 1.60x | consistent with parser/emitter-heavy work |
| `xlsx` | 16 | off | 1083 | 666 | 1.63x | consistent with parser/emitter-heavy work |
| `docx` | 3 | on | 124 | 74 | 1.68x | moderate, but not a smoke outlier |
| `xlsx` | 8 | off | 431 | 248 | 1.74x | workbook path scales less than HTML/PDF |
| `json` | 8 | on | 408 | 229 | 1.78x | structured-data path scales less than HTML/PDF |

Startup probe summary:

| Probe | Median elapsed ms | Peak RSS bytes |
| ------ | ----------------: | -------------: |
| `help` | 19 | 0 |
| `empty-batch` | 21 | 0 |

Interpretation:

* batch/startup is already doing its job for HTML and PDF
* `json` and `xlsx` large-group rows gain relatively less from batching,
  suggesting the dominant cost is not process launch alone
* `pdf` at group size `1` is a small-sample artifact, not a real H3 priority

## 6. Metadata Overhead

Largest metadata-on minus metadata-off deltas from batch rows:

| Format | Group size | Batch ms metadata off | Batch ms metadata on | Delta ms | Delta % |
| ------ | ---------: | --------------------: | -------------------: | -------: | ------: |
| `docx` | 3 | 61 | 74 | 13 | 21.31% |
| `xlsx` | 16 | 666 | 673 | 7 | 1.05% |
| `pdf` | 8 | 34 | 37 | 3 | 8.82% |
| `docx` | 16 | 212 | 213 | 1 | 0.47% |

Important note:

* many rows were noise-flat or slightly negative
* there is no current evidence that metadata sidecar generation is the main H3
  cost center across the benchmark set
* the only visibly positive metadata spike is `docx` at group size `3`, which
  is too small and isolated to justify “metadata first” as the opening H3 pass

## 7. Warning Status

`./samples/scripts/bench_warn.sh --all` result:

* smoke warnings: none
* batch profile warnings: none
* compare warnings: intentionally skipped / future work

Runner-aware note:

* smoke warnings now record runner kind
* the previous `docx/golden` warning was resolved by native runner
  normalization, not by changing thresholds or converter behavior

## 8. Bottleneck Classification

Current H3 candidates and likely classification:

| Candidate | Evidence | Likely class | Reasoning |
| --------- | -------- | ------------ | --------- |
| `xlsx/xlsx_large` | slowest native smoke row at `216 ms`; weak `16`-file batch speedup (`1.63x`) | `parser` + `emitter` | batching helps only modestly, which suggests workbook traversal / cell lowering / Markdown table emission dominate more than startup |
| `json/json_large` | second-slowest native smoke row at `186 ms`; weak `16`-file batch speedup (`1.60x`) | `emitter` + `parser` | large structured lowering and string building appear heavier than process launch |
| `yaml/yaml_large` | third-slowest smoke row at `158 ms` | `parser` + `emitter` | similar to JSON, but without overlap/batch coverage this is a secondary follow-up target |
| `txt/txt_large` | smoke `143 ms` | `emitter` | plain text path has little parser complexity; large output size points more toward string / line / buffer work |
| `csv/tsv large` | smoke `101 / 90 ms`; batch speedups still decent (`2.04x+`) | `emitter` | likely table Markdown emission rather than startup or metadata |
| `zip_large_many_entries` | smoke `62 ms` | `IO` + `archive` | archive traversal cost exists, but current absolute time is below top-tier H3 urgency |
| `docx overlap low tier` | compare bottom speedups include DOCX heading/list cases | `parser` | useful relative profiling target, but absolute smoke/batch numbers no longer make DOCX the first optimization target |
| `pdf group-size=1` | batch speedup `0.97x` at `1` file | `startup/process model artifact` | disappears at larger group sizes; not a converter bottleneck |
| old `docx/golden` warning | resolved after runner normalization | `threshold/corpus artifact` | no longer a live performance problem |

## 9. Recommended H3 Optimization Order

| Priority | Target | Evidence | Hypothesis | Suggested next pass |
| -------: | ------ | -------- | ---------- | ------------------- |
| 1 | `xlsx` large-workbook path | slowest smoke row; weak large-group batch gains; overlap low tier includes `xlsx_multi_sheet_mixed` | workbook traversal, row/cell normalization, and/or Markdown table emission dominate native cost | `H3 XLSX large-sheet profiling pass` |
| 2 | `json` / `yaml` large structured lowering | `json_large` and `yaml_large` are top smoke rows; `json` has weakest large-group batch gains | large nested structure traversal plus Markdown/code-fence/string emission is the current structured-data hot path | `H3 structured-data lowering and emitter pass` |
| 3 | large text/table emission (`txt`, `csv`, `tsv`) | `txt_large`, `csv_large`, `tsv_large` are all high on smoke; batch gains are moderate-to-good | parser cost is low; output construction and table formatting likely dominate | `H3 Markdown table/text emitter allocation pass` |
| 4 | `docx` relative cleanup | compare bottom speedups include DOCX heading/list cases, but smoke/batch are no longer alarming | some OOXML traversal or relationship/document walk overhead may still be reducible | `H3 DOCX parser micro-profile pass` |
| 5 | archive/container IO (`zip`, later `epub`) | `zip_large_many_entries` is the main archive row, but well below top structured-data/XLSX costs | entry enumeration/materialization overhead exists, but is not the first bottleneck to tackle | `H3 archive IO profiling pass` |
| 6 | metadata overhead | only isolated small positive deltas; most rows are flat/noisy | metadata is not the current main budget consumer | defer until after parser/emitter profiling |

Recommended first target:

* `xlsx` large-workbook profiling should be the first real H3 optimization
  target

Why this wins:

* it is the slowest native smoke row
* it stays weak in batch scaling at `8` and `16` files
* it appears again in the compare bottom tier
* unlike the old DOCX warning, it is not explained away by runner artifacts

## 10. Non-goals For This Pass

This triage pass does not:

* optimize converter code
* adjust performance thresholds
* adjust benchmark corpora
* reinterpret local results as universal claims
* claim that the selected comparison cases are a full parity proof
