# doc_parse Performance Baseline

This page records the measured benchmark snapshot used for the current
`doc_parse` release-preparation round.

It combines repository-level CLI timing with the first direct `doc_parse/*`
library-harness snapshot. It is still not a blanket cross-machine claim about
latency for every package and file shape.

## Capture Metadata

* date: `2026-05-10`
* repository state: current working tree after documentation/API-comment
  release-prep updates
* runner preference: prebuilt native binaries where available
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
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
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
* doc_parse library summary:
  `.tmp/bench/doc_parse/summary.tsv`
* doc_parse library raw runs:
  `.tmp/bench/doc_parse/summary.runs.tsv`

## Outcome Summary

* smoke suite: `96` rows, `0` failures
* batch-profile suite: `48` runs, `0` failures
* doc_parse library suite: `75` stage rows, `0` failures
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

## doc_parse Library Benchmark Baseline

Command:

```bash
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

Coverage in this first harness round:

* `text`
* `csv`
* `tsv`
* `json`
* `yaml`
* `xml`
* `html`
* `markdown`
* `zip`
* `ooxml`
* `epub`
* `xlsx`
* `docx`
* `pptx`

Current intentional gap:

* `pdf` is still deferred from the first library-only harness

Slowest `open/parse/scan` rows:

* `xlsx_formula_heavy_missing_cache / parse`: `14.367 ms`
* `docx_link_heavy / parse`: `8.631 ms`
* `yaml_large / parse`: `7.181 ms`
* `json_large / parse`: `3.857 ms`
* `txt_large / parse`: `3.769 ms`
* `markdown_large / scan`: `3.306 ms`
* `docx_small / parse`: `2.664 ms`
* `csv_large / parse`: `2.509 ms`
* `tsv_large / parse`: `2.330 ms`

Slowest `inspect` rows:

* `txt_large / inspect`: `0.694 ms`
* `ooxml_xlsx_small / inspect`: `0.215 ms`
* `json_large / inspect`: `0.144 ms`
* `zip_large_many_entries / inspect`: `0.138 ms`

Slowest `validate` rows:

* `zip_large_many_entries / validate`: `0.138 ms`
* `ooxml_xlsx_small / validate`: `0.127 ms`
* `epub_large_many_chapters / validate`: `0.007 ms`
* all other checked validation rows are below `0.01 ms` in this snapshot

Small-case rows above `10 ms` in the library harness:

* none

Rows above `10 ms` anywhere in the current library harness:

* `xlsx_formula_heavy_missing_cache / parse`: `14.367 ms`

## What This Baseline Can And Cannot Tell Us

This baseline can tell us:

* current native normal-path timing on the checked local corpus
* which rows are currently slowest at the repository product level
* that startup cost is material for small rows
* that batch amortization is real and measurable
* current direct `doc_parse/*` package timing for the first library-harness
  coverage set

This baseline still cannot yet tell us directly:

* `parse` vs `convert` vs `emit` vs `metadata/assets` cost split inside one
  end-to-end CLI row
* full-library coverage for every package, especially `pdf`
* cross-machine release SLOs from one checked local snapshot

## Current Decision

This round is baseline-first.

No hot-path behavior change was made from benchmark results alone. The next
optimization round should start from the hotspots and measurement gaps listed
in [`docs/performance-roadmap.md`](./performance-roadmap.md).
