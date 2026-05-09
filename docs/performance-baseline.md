# doc_parse Performance Baseline

This page records the measured benchmark snapshot used for the current
`doc_parse` release-preparation round.

It is intentionally a repository-level measurement note, not a blanket claim
about isolated library latency for every package.

## Capture Metadata

* date: `2026-05-10`
* repository state: current working tree after documentation/API-comment
  release-prep updates
* runner preference: prebuilt native CLI
* validation before benchmark:
  * `moon build --target native`
  * `moon check`
  * `moon test`
  * `./samples/check.sh`

## Benchmark Commands

Measured commands:

```bash
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

Artifacts:

* smoke summary:
  `.tmp/bench/smoke/summary.tsv`
* smoke raw results:
  `.tmp/bench/smoke/results.jsonl`
* batch profile summary:
  `.tmp/bench/batch_profile/summary.tsv`
* batch startup summary:
  `.tmp/bench/batch_profile/startup-summary.tsv`
* batch comparison summary:
  `.tmp/bench/batch_profile/comparison-summary.tsv`

## Outcome Summary

* smoke suite: `96` rows, `0` failures
* batch-profile suite: `48` runs, `0` failures
* no expectations or fixtures were changed to make the benchmark pass

## Smoke Benchmark Highlights

Representative small-case native CLI rows:

* `markdown_small`: `9 ms`
* `markdown_frontmatter_passthrough`: `9 ms`
* `csv_small`: `10 ms`
* `tsv_small`: `10 ms`
* `txt_small`: `10 ms`
* `html_small`: `11 ms`
* `json_small`: `11 ms`
* `xml_small`: `11 ms`
* `xlsx_small`: `11 ms`
* `pptx_small`: `12 ms`
* `docx_small`: `13 ms`
* `pdf_text_simple`: `13 ms`

Slowest smoke rows in this snapshot:

* `xlsx_formula_heavy_missing_cache`: `27 ms`
* `txt_large`: `25 ms`
* `yaml_large`: `24 ms`
* `pdf_heading_basic`: `23 ms`
* `json_large`: `23 ms`
* `zip_large_many_entries`: `22 ms`
* `xlsx_large`: `22 ms`

Per-format average smoke median in this run:

* `markdown`: `9.75 ms`
* `html`: `10.44 ms`
* `xml`: `10.50 ms`
* `csv`: `12.75 ms`
* `tsv`: `13.00 ms`
* `epub`: `13.71 ms`
* `pptx`: `13.80 ms`
* `txt`: `14.25 ms`
* `docx`: `14.45 ms`
* `zip`: `14.57 ms`
* `json`: `14.60 ms`
* `pdf`: `14.78 ms`
* `xlsx`: `14.77 ms`
* `yaml`: `15.00 ms`

Important interpretation:

* `80 / 96` smoke rows are above `10 ms`
* this does **not** mean `80 / 96` library parse paths violate the intended
  small-case target
* the current public benchmark includes CLI startup, file I/O, converter
  lowering, and output work on the normal path

## Batch Profile Highlights

Measured startup probes:

* `help`: `13 ms`
* `empty-batch`: `13 ms`

This gives a useful same-machine estimate of fixed native CLI overhead before
format-local parsing/conversion dominates.

Representative process-per-file vs single-process-batch speedups:

* `csv`, group size `3`, without metadata: `77 ms` -> `13 ms` (`5.92x`)
* `json`, group size `3`, without metadata: `78 ms` -> `14 ms` (`5.57x`)
* `html`, group size `3`, without metadata: `77 ms` -> `14 ms` (`5.50x`)
* `xlsx`, group size `3`, without metadata: `83 ms` -> `17 ms` (`4.88x`)
* `docx`, group size `3`, without metadata: `95 ms` -> `26 ms` (`3.65x`)
* `pdf`, group size `3`, without metadata: `84 ms` -> `21 ms` (`4.00x`)

Observed pattern:

* one-file runs still pay a noticeable fixed startup cost
* grouped execution improves amortized throughput across all tested formats
* heavier OOXML/PDF rows still benefit from batching, but less dramatically
  than the smallest text/structured rows

## What This Baseline Can And Cannot Tell Us

This baseline can tell us:

* current native normal-path timing on the checked local corpus
* which rows are currently slowest at the repository product level
* that startup cost is material for small rows
* that batch amortization is real and measurable

This baseline cannot yet tell us directly:

* isolated `doc_parse/*` library-only parse time
* `parse` vs `convert` vs `emit` vs `metadata/assets` cost split
* p50 / p95 library-path latency by package

## Current Decision

This round is baseline-first.

No hot-path behavior change was made from benchmark results alone. The next
optimization round should start from the hotspots and measurement gaps listed
in [`docs/performance-roadmap.md`](./performance-roadmap.md).
