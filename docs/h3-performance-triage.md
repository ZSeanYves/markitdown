# H3 Performance Triage

This document records the first H3 performance triage pass after benchmark
runner normalization, the post-XLSX-optimization benchmark refresh, and the
follow-up JSON large-structure profiling pass.

It is based on local-machine benchmark outputs under `.tmp/bench/...`. It is
not a universal performance claim, and it does not change converter semantics,
benchmark thresholds, benchmark corpora, or checked-in expected outputs.

## 1. Scope And Caveats

These passes answer two questions:

* after runner normalization, where should the first real H3 optimization pass
  land?
* after the XLSX worksheet materialization fix, what is the next real H3 target?
* after the JSON large-structure pass, which candidates remain in the first
  bottleneck group?

This pass does not:

* optimize converters in this document itself
* widen support claims
* redefine the `v0.3.0` baseline freeze
* treat selected overlap comparisons as blanket parity or blanket speed claims

## 2. Environment And Runner Normalization

Local benchmark commands used for these triage snapshots:

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

Refresh anchor for the post-XLSX rerun:

* local worktree refresh based on `HEAD` `eb3faac`
* current worktree still contains uncommitted H3 XLSX optimization/docs changes
* all refreshed benchmark conclusions below are therefore tied to the current
  local worktree state, not a previously tagged release snapshot

## 3. Smoke Slowest Samples

### Initial normalized triage snapshot

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
* the strongest same-machine slow rows were large structured data, large
  worksheets, and large flat text/table emission cases

### Post-XLSX optimization refresh

Refresh summary:

* sample count: `75`
* failures: `0`
* runner kind: `prebuilt-native`
* warning status: none

Top 10 slowest smoke rows by median after the XLSX worksheet materialization
pass:

| Rank | Format | Sample | Median ms | Runner | Notes |
| ---: | ------ | ------ | --------: | ------ | ----- |
| 1 | `json` | `json_large` | 196 | `prebuilt-native` | current top slow row; large structured-data lowering |
| 2 | `yaml` | `yaml_large` | 189 | `prebuilt-native` | large nested mapping/sequence lowering |
| 3 | `txt` | `txt_large` | 144 | `prebuilt-native` | large text emission path |
| 4 | `csv` | `csv_large` | 114 | `prebuilt-native` | large table emission |
| 5 | `tsv` | `tsv_large` | 96 | `prebuilt-native` | large table emission |
| 6 | `json` | `json_array_objects_large` | 85 | `prebuilt-native` | array/object-heavy structured-data lowering |
| 7 | `docx` | `golden` | 61 | `prebuilt-native` | still clean; no warning |
| 8 | `zip` | `zip_large_many_entries` | 56 | `prebuilt-native` | archive traversal / repeated dispatch |
| 9 | `markdown` | `markdown_medium` | 47 | `prebuilt-native` | text-like output path candidate |
| 10 | `yaml` | `yaml_sequence_mappings_large` | 46 | `prebuilt-native` | secondary YAML large case |

Key comparison for the previous top XLSX outlier:

* `xlsx_large` before optimization: about `212 ms`
* `xlsx_large` after optimization: `27 ms`
* smoke ranking shift: from the top outlier to rank `16` on this rerun

Current XLSX smoke rows after the refresh:

* `xlsx_large`: `27 ms`
* `xlsx_multi_sheet_large`: `23 ms`
* `xlsx_medium`: `17 ms`
* `xlsx_multi_sheet_mixed`: `17 ms`
* `xlsx_sparse_large`: `13 ms`
* `xlsx_small`: `12 ms`

Refresh interpretation:

* XLSX has exited the first-tier slow-path group
* the new top tier is now `json` / `yaml` / `txt` / `csv` / `tsv`
* `docx/golden` remains visible, but far below the current structured-data and
  large text-like leaders

### Post-JSON optimization refresh

After the JSON large-structure pass, the smoke board moved again:

| Rank | Format | Sample | Median ms | Runner | Notes |
| ---: | ------ | ------ | --------: | ------ | ----- |
| 1 | `yaml` | `yaml_large` | 147 | `prebuilt-native` | current top slow row after JSON fix |
| 2 | `txt` | `txt_large` | 127 | `prebuilt-native` | large text emission path |
| 3 | `csv` | `csv_large` | 99 | `prebuilt-native` | large table emission |
| 4 | `tsv` | `tsv_large` | 83 | `prebuilt-native` | large table emission |
| 5 | `zip` | `zip_large_many_entries` | 52 | `prebuilt-native` | archive traversal / repeated dispatch |
| 6 | `docx` | `docx_large` | 33 | `prebuilt-native` | moderate OOXML path |
| 7 | `yaml` | `yaml_sequence_mappings_large` | 31 | `prebuilt-native` | secondary YAML large case |
| 8 | `docx` | `golden` | 30 | `prebuilt-native` | still clean |
| 9 | `json` | `json_large` | 30 | `prebuilt-native` | no longer a top-tier outlier |
| 10 | `markdown` | `markdown_large` | 28 | `prebuilt-native` | text-like output path |

Key comparison for JSON:

* `json_large` before JSON pass: `196 ms`
* `json_large` after JSON pass: `30 ms`
* `json_array_objects_large` before JSON pass: `85 ms`
* `json_array_objects_large` after JSON pass: `20 ms`

Updated interpretation:

* JSON has also exited the first-tier slow-path group
* the current leading candidates are now `yaml` and large text/table emission
* post-XLSX ordering is already stale after the JSON pass

## 4. Compare Bottom Speedups

### Initial normalized triage snapshot

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

### Post-XLSX optimization refresh

Comparison refresh summary:

* paired cases: `18`
* failures: `0`
* formats covered: `docx`, `pptx`, `xlsx`, `pdf`, `html`, `csv`, `txt`,
  `markdown`
* Python MarkItDown availability: available as `markitdown 0.1.5`

Bottom speedups by `python_ms / mb_ms` after the XLSX optimization:

| Rank | Format | Sample | mb ms | python ms | Speedup | Notes |
| ---: | ------ | ------ | ----: | --------: | ------: | ----- |
| 1 | `docx` | `docx_heading_levels_compare` | 32 | 636 | 19.88x | current minimum speedup; still a strong win |
| 2 | `docx` | `docx_list_nested_compare` | 30 | 608 | 20.27x | current lower DOCX tier |
| 3 | `pptx` | `pptx_slide_order_compare` | 15 | 524 | 34.93x | not a current concern |
| 4 | `csv` | `csv_basic_compare` | 14 | 508 | 36.29x | still a strong win |
| 5 | `docx` | `docx_table_multiline_cell_compare` | 16 | 597 | 37.31x | still large margin |
| 6 | `pptx` | `pptx_title_bullets_compare` | 15 | 574 | 38.27x | not a current concern |
| 7 | `pdf` | `pdf_repeated_header_footer_compare` | 14 | 536 | 38.29x | not a current concern |
| 8 | `pptx` | `pptx_hyperlink_shape_basic_compare` | 17 | 651 | 38.29x | not a current concern |
| 9 | `pdf` | `heading_basic_compare` | 14 | 538 | 38.43x | not a current concern |
| 10 | `pdf` | `text_simple_compare` | 13 | 515 | 39.62x | not a current concern |

Refresh interpretation:

* there are still no near-loss overlap rows
* the current minimum speedup is still almost `20x`
* XLSX overlap improved further on this rerun:
  `xlsx_multi_sheet_mixed_compare` moved to `12 ms` vs `520 ms`
  (`43.33x`)
* overlap data no longer argues for XLSX as the next optimization target
* nothing in overlap data suggests a JSON-specific external speed emergency

## 5. Batch Profile Bottlenecks

### Initial normalized triage snapshot

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

### Post-XLSX optimization refresh

Batch refresh summary:

* formats: `csv`, `json`, `html`, `xlsx`, `docx`, `pdf`
* group sizes: `1`, `3`, `8`, `16`
* metadata modes: `without-metadata`, `with-metadata`
* runner kind: `prebuilt-native`
* failures: `0`
* skipped groups: `0`
* memory probe: unavailable on this run (`none`)

Bottom batch speedups after the XLSX optimization:

| Format | Group size | Metadata | Process/file ms | Batch ms | Speedup | Notes |
| ------ | ---------: | -------- | --------------: | -------: | ------: | ----- |
| `xlsx` | 1 | on | 33 | 32 | 1.03x | small-group metadata noise; not a large-scale problem |
| `pdf` | 1 | on | 34 | 32 | 1.06x | tiny-group startup noise |
| `csv` | 1 | on | 32 | 24 | 1.33x | tiny-group noise, not main H3 driver |
| `docx` | 1 | off | 50 | 33 | 1.52x | startup still dominates at size `1` |
| `json` | 16 | on | 1036 | 679 | 1.53x | weakest meaningful large-group row |
| `docx` | 1 | on | 51 | 33 | 1.55x | startup still dominates at size `1` |
| `json` | 16 | off | 1092 | 695 | 1.57x | confirms large structured-data scaling weakness |
| `json` | 8 | off | 469 | 274 | 1.71x | same direction at mid-large groups |
| `json` | 8 | on | 422 | 234 | 1.80x | same direction at mid-large groups |
| `html` | 1 | off | 31 | 17 | 1.82x | small-group startup noise |

Refresh interpretation:

* the meaningful weak-gain rows are now more clearly `json` than `xlsx`
* refreshed `xlsx` large-group rows are much healthier:
  `5.65x` to `5.91x` at `8/16` files
* XLSX no longer looks like the weakest batch-scaling format once the
  materialization hotspot is removed
* the already-recorded weak large-group `json` rows should now be rechecked in
  a future batch refresh before being treated as current bottleneck evidence

## 6. Metadata Overhead

### Initial normalized triage snapshot

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

### Post-XLSX optimization refresh

Largest absolute metadata deltas on the refresh rerun:

| Format | Group size | Batch off | Batch on | Delta ms | Delta % | Notes |
| ------ | ---------: | --------: | -------: | -------: | ------: | ----- |
| `xlsx` | 1 | 17 | 32 | 15 | 88.24% | tiny-group noise; not representative of large-sheet cost |
| `pdf` | 1 | 18 | 32 | 14 | 77.78% | tiny-group noise |
| `xlsx` | 16 | 77 | 79 | 2 | 2.60% | large-group XLSX metadata cost remains small |

More important pattern:

* many metadata deltas were flat or negative from run noise
* `json`, `csv`, and `docx` large-group rows do not point to metadata as the
  main budget center
* metadata still does not justify the next H3 optimization pass
* the JSON pass did not change that conclusion

## 7. Warning Status

`./samples/scripts/bench_warn.sh --all` result:

* smoke warnings: none
* batch profile warnings: none
* compare warnings: intentionally skipped / future work

Runner-aware note:

* smoke warnings now record runner kind
* the previous `docx/golden` warning was resolved by native runner
  normalization, not by changing thresholds or converter behavior
* post-XLSX refresh remains clean under the same runner-aware warning policy

## 8. Bottleneck Classification

### Initial normalized triage snapshot

Current H3 candidates and likely classification:

| Candidate | Evidence | Likely class | Reasoning |
| --------- | -------- | ------------ | --------- |
| `xlsx/xlsx_large` | slowest native smoke row at `216 ms`; weak `16`-file batch speedup (`1.63x`) | `parser` + `emitter` | this was the pre-fix picture before the worksheet materialization hotspot was removed |
| `json/json_large` | second-slowest native smoke row at `186 ms`; weak `16`-file batch speedup (`1.60x`) | `emitter` + `parser` | large structured lowering and string building appear heavier than process launch |
| `yaml/yaml_large` | third-slowest smoke row at `158 ms` | `parser` + `emitter` | similar to JSON, but without overlap/batch coverage this is a secondary follow-up target |
| `txt/txt_large` | smoke `143 ms` | `emitter` | plain text path has little parser complexity; large output size points more toward string / line / buffer work |
| `csv/tsv large` | smoke `101 / 90 ms`; batch speedups still decent (`2.04x+`) | `emitter` | likely table Markdown emission rather than startup or metadata |
| `zip_large_many_entries` | smoke `62 ms` | `IO` + `archive` | archive traversal cost exists, but current absolute time is below top-tier H3 urgency |
| `docx overlap low tier` | compare bottom speedups include DOCX heading/list cases | `parser` | useful relative profiling target, but absolute smoke/batch numbers no longer make DOCX the first optimization target |
| `pdf group-size=1` | batch speedup `0.97x` at `1` file | `startup/process model artifact` | disappears at larger group sizes; not a converter bottleneck |
| old `docx/golden` warning | resolved after runner normalization | `threshold/corpus artifact` | no longer a live performance problem |

### Post-XLSX optimization refresh

Current H3 candidates and likely classification after the rerun:

| Candidate | Evidence | Likely class | Reasoning |
| --------- | -------- | ------------ | --------- |
| `json/json_large` | slowest smoke row at `196 ms`; weak `16`-file batch speedups (`1.53x` / `1.57x`) | `parser` + `emitter` | large nested-structure traversal and output materialization now look like the clearest same-machine cost center |
| `yaml/yaml_large` | second-slowest smoke row at `189 ms`; secondary YAML large row also in top 10 | `parser` + `emitter` | likely similar to JSON, but currently without batch/compare corroboration |
| `txt/txt_large` | smoke `144 ms` | `emitter` | parser complexity is low; output construction is the likely cost |
| `csv/tsv large` | smoke `114 / 96 ms` | `emitter` | table Markdown emission is the likely main path |
| `zip_large_many_entries` | smoke `56 ms` | `IO` + `archive` | still visible, but below the current structured-data / text-like leaders |
| `docx/golden` | smoke `61 ms`, no warning | `parser` | no longer first-tier urgency |
| `xlsx` refresh rows | `xlsx_large` now `27 ms`; large-group batch rows `5.65x` to `5.91x` | addressed / no longer first-tier | worksheet XML materialization hotspot has been removed |

### Post-JSON optimization refresh

Current H3 candidates and likely classification after the JSON pass:

| Candidate | Evidence | Likely class | Reasoning |
| --------- | -------- | ------------ | --------- |
| `yaml/yaml_large` | current slowest smoke row at `147 ms` | `parser` + `emitter` | likely the nearest remaining structured-data analogue to pre-fix JSON |
| `txt/txt_large` | current smoke `127 ms` | `emitter` | parser complexity is low; output construction is the likely main budget consumer |
| `csv/tsv large` | current smoke `99 / 83 ms` | `emitter` | table Markdown emission is the likely budget center |
| `zip_large_many_entries` | current smoke `52 ms` | `IO` + `archive` | visible archive/container cost remains, but below YAML/text-like leaders |
| `json` refresh rows | `json_large` now `30 ms`; `json_array_objects_large` now `20 ms` | addressed / no longer first-tier | UTF-8 materialization hotspot has been removed |

## 9. Recommended H3 Optimization Order

### Initial normalized triage snapshot

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

### Post-XLSX optimization refresh

Updated priority order after the rerun:

| Priority | Target | Evidence | Hypothesis | Suggested next pass |
| -------: | ------ | -------- | ---------- | ------------------- |
| 1 | `json` / `yaml` large structured-data lowering | `json_large` and `yaml_large` are now the top two smoke rows; `json` has the weakest meaningful large-group batch gains | nested-structure traversal plus large output materialization now dominate the structured-data path | `H3 structured-data large-file profiling pass` |
| 2 | large text/table emission (`txt`, `csv`, `tsv`) | `txt_large`, `csv_large`, and `tsv_large` now form the next smoke tier | parser cost is likely low; output/string/table formatting is the likely budget consumer | `H3 text-and-table emitter profiling pass` |
| 3 | `zip` / later `epub` archive IO | `zip_large_many_entries` remains the most visible archive/container row | repeated dispatch and archive traversal still merit later profiling, but not before structured-data/text-like work | `H3 archive IO profiling pass` |
| 4 | `docx` relative cleanup | DOCX remains strong externally and moderate internally | any remaining gains are incremental, not urgent | `H3 DOCX parser micro-profile pass` |
| 5 | metadata overhead | refresh rerun still shows mostly flat/noisy deltas | metadata remains a non-primary cost center | defer |

Current recommendation:

* XLSX has exited the first-tier bottleneck group
* the next real H3 target should be `json` / `yaml` large structured-data
  profiling, not another immediate XLSX pass

### Post-JSON optimization refresh

Updated priority order after the JSON pass:

| Priority | Target | Evidence | Hypothesis | Suggested next pass |
| -------: | ------ | -------- | ---------- | ------------------- |
| 1 | `yaml` large structured-data lowering | `yaml_large` is now the current slowest smoke row; YAML still has no equivalent micro-profile pass | YAML likely still carries the same class of decode/parser/lowering/emitter questions JSON had before this pass | `H3 YAML large-structure profiling pass` |
| 2 | large text/table emission (`txt`, `csv`, `tsv`) | `txt_large`, `csv_large`, and `tsv_large` now dominate the next smoke tier | output construction and table formatting are the likely budget consumers | `H3 text-and-table emitter profiling pass` |
| 3 | `zip` / later `epub` archive IO | `zip_large_many_entries` remains the main archive row | repeated dispatch and archive traversal still merit profiling later | `H3 archive IO profiling pass` |
| 4 | `docx` relative cleanup | DOCX rows are now moderate, not alarming | remaining gains are incremental | `H3 DOCX parser micro-profile pass` |
| 5 | metadata overhead | still flat/noisy and non-primary | metadata remains a non-priority cost center | defer |

Current recommendation:

* XLSX and JSON have both exited the first-tier bottleneck group
* the next real H3 target should now be YAML or large text/table emission

## 10. Non-goals For This Pass

This triage pass does not:

* optimize converter code
* adjust performance thresholds
* adjust benchmark corpora
* reinterpret local results as universal claims
* claim that the selected comparison cases are a full parity proof
