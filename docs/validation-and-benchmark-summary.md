# Validation and Benchmark Summary

This document is the repository's detailed validation and benchmark snapshot.
It is the authoritative location for checked-in counts, representative local
benchmark examples, and result-file locations.

For scope boundaries and support claims, use
[docs/support-and-limits.md](./support-and-limits.md).

For second-round sealed-format status, use
[docs/second-round-summary.md](./second-round-summary.md).

For runner, corpus, and comparability rules, use
[docs/benchmark-governance.md](./benchmark-governance.md).

## Latest Validation Snapshot

Latest checked validation facts:

| Check | Current result |
| --- | --- |
| `moon test` | `1298 passed, 0 failed` |
| Main process samples | `346 passed, 0 failed` |
| Metadata sidecars | `82 passed, 0 failed` |
| Asset checks | `42 passed, 0 failed` |
| Benchmark smoke corpus | `96 runs, 0 failures` |
| Batch profile corpus | `56 runs, 0 failures` |
| MarkItDown overlap compare | `94 runs, 0 failures` |

These numbers are repository-local checked facts, not a promise that every
future corpus size will stay constant.

## Runner

Repository performance conclusions use:

* prebuilt-native CLI
* named checked-in corpus
* explicit execution path

`moon run` remains a supported development fallback, but it is not the
preferred H3++ performance reference.

Current compare baseline:

* local runner: `markitdown-mb` prebuilt-native CLI
* comparison runner: Microsoft MarkItDown `0.1.5`
* compare corpus: `samples/benchmark/compare_corpus.tsv`

## Result Locations

Benchmark scripts write local artifacts under `.tmp/bench/`.

Current suite roots:

* smoke: `.tmp/bench/smoke/`
* compare: `.tmp/bench/compare/`
* batch profile: `.tmp/bench/batch_profile/`

Typical files:

* smoke: `.tmp/bench/smoke/results.jsonl`, `.tmp/bench/smoke/summary.tsv`
* compare:
  `.tmp/bench/compare/results.jsonl`,
  `.tmp/bench/compare/summary.tsv`
* batch profile:
  `.tmp/bench/batch_profile/results.jsonl`,
  `.tmp/bench/batch_profile/summary.tsv`,
  `.tmp/bench/batch_profile/comparison-summary.tsv`,
  `.tmp/bench/batch_profile/startup-summary.tsv`

## Representative Speed Ratios

Representative overlap examples from the current checked-in compare summary:

| Format | Case | markitdown-mb | Microsoft MarkItDown 0.1.5 | Ratio | Scope note |
| --- | --- | ---: | ---: | ---: | --- |
| XLSX | `xlsx_formula_cached_values_compare` | 10 ms | 480 ms | ~48x | overlap corpus, prebuilt-native vs local Python tool |
| XLSX | `xlsx_formula_eval_arithmetic_compare` | 10 ms | 508 ms | ~51x | overlap corpus, bounded evaluator-v1 scenario |
| DOCX | `docx_nested_lists_mixed_compare` | 31 ms | 821 ms | ~26x | overlap corpus, selected local Word sample |
| DOCX | `docx_table_multiline_complex_compare` | 14 ms | 673 ms | ~48x | overlap corpus, selected local table-heavy sample |
| PPTX | `pptx_title_bullets_compare` | 18 ms | 710 ms | ~39x | overlap corpus, selected local presentation sample |
| PPTX | `pptx_image_alt_title_compare` | 13 ms | 651 ms | ~50x | overlap corpus, selected local image/title sample |
| PDF | `pdf_uri_link_basic_compare` | 11 ms | 516 ms | ~47x | native text-PDF overlap only |
| HTML | `html_simple_compare` | 10 ms | 499 ms | ~50x | overlap corpus, lightweight local HTML parser scope |

These are representative rows, not an attempt to summarize every format with a
single multiplier.

## Validation Surface

Primary repository validation:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
```

Supporting validation chains:

```bash
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_cli_contract.sh
./samples/scripts/check_batch_contract.sh
./samples/scripts/check_debug_contract.sh
./samples/scripts/check_corpus_manifest.sh
```

Benchmark entrypoints:

```bash
./samples/scripts/bench_smoke.sh --kind smoke
./samples/scripts/bench_compare_markitdown.sh --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
./samples/scripts/bench_batch_profile.sh --formats xlsx,html,zip,epub,docx,pptx,pdf --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

## Caveats

Interpret these numbers conservatively:

* they are local benchmark facts on a named checked-in corpus
* they do not imply all files of a format family behave the same way
* not all formats are equally comparable with Microsoft MarkItDown
* compare rows are overlap-only and sample-scoped
* RSS / memory numbers may be unavailable depending on suite and platform
* OCR, cloud, plugin, and scanned-PDF paths are outside the default H3++ local
  performance claim
