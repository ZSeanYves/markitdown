# Benchmarking

This page is the current benchmark operations guide for the repository.

For current measured numbers, layer interpretation, and remaining performance
work, use [docs/performance.md](./performance.md).

## Recommended Validation Commands

Recommended verification chain before benchmark work:

```bash
moon info
moon fmt
moon check
moon test
./samples/check.sh
bash samples/quality_corpus/check.sh
```

## Recommended Benchmark Commands

Public benchmark entrypoint:

```bash
./samples/bench.sh
```

Product smoke:

```bash
./samples/bench.sh --suite smoke --kind smoke
```

Direct `doc_parse` library path:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
```

Same-process product path:

```bash
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
```

Cold CLI startup:

```bash
./samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
```

Product-path help and smoke:

```bash
./samples/bench.sh --suite product-path --help
./samples/bench.sh --suite product-path --smoke
```

Batch profile:

```bash
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

Optional overlap comparison:

```bash
./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

Optional PDF layout classifier spike evaluation:

```bash
./samples/pdf_layout_classifier/evaluate.sh --smoke
```

## Internal Helper Scripts

The public recommendation is to go through `./samples/bench.sh`.

Suite-specific rerun helpers now live under `samples/helpers/`:

* `./samples/helpers/bench_cold_start_helper.sh`
* `./samples/helpers/bench_doc_parse_helper.sh`
* `./samples/helpers/bench_product_path_helper.sh`

Internal implementation note:

* the direct library harness package now lives at `doc_parse/bench`
* the default checked manifests now live under `samples/benchmark/manifests/`
* smoke and normal-path benchmark helpers prefer an existing probe-validated
  native `cli`; if absent, they build `cli` once with
  `moon build cli --target native`
* when a normal-path benchmark row needs bundled PDF or ZIP support, helpers
  also resolve `pdf` / `zip` and build each component at most once
* hidden benchmark helpers (`product-path`, `cold-start`) prefer an existing
  probe-validated native `bench`; if absent, they build `bench` once
  with `moon build bench --target native`
* benchmark helpers do not silently use `moon run` unless
  `MARKITDOWN_ALLOW_MOON_RUN=1` is set explicitly

## Build Guardrail Snapshot

Recent Ubuntu native measurements for the current product/component split:

* `cli`: about `16s`, `18M / 382k` generated-C lines
* `pdf`: about `16s`, `18M / 381k`
* `zip`: about `15s`, `17M / 359k`
* `ocr`: about `9-10s`, `7.6M / 154k`

Current guardrail notes:

* main `cli` stays out of vendored `mbtpdf` and should remain `mbtpdf=0`
* a direct in-process PDF/ZIP reintegration experiment pushed `cli` to about
  `30M / 653k` generated-C lines and about `24.6s` cold rebuild time on the
  recent Ubuntu audit runner
* the accepted design therefore keeps PDF and ZIP on the user-visible `cli`
  surface while routing execution through bundled `pdf` / `zip`

## Output Directories

Benchmark artifacts are written under `.tmp/bench/`.

Current suite roots:

* smoke:
  `.tmp/bench/smoke/`
* compare:
  `.tmp/bench/compare/`
* batch profile:
  `.tmp/bench/batch_profile/`
* doc-parse library:
  `.tmp/bench/doc_parse/`
* product path:
  `.tmp/bench/product_path/`
* cold start:
  `.tmp/bench/cold_start/`

Typical outputs:

* smoke:
  `results.jsonl`, `summary.tsv`
* compare:
  `results.jsonl`, `summary.tsv`
* batch profile:
  `results.jsonl`, `summary.tsv`, `startup-summary.tsv`,
  `comparison-summary.tsv`, `file_results.tsv`
* doc-parse library:
  `summary.tsv`, `summary.runs.tsv`
* product path:
  `summary.tsv`, `summary.runs.tsv`, `stage-plan.tsv`, `sample-plan.tsv`
* cold start:
  `summary.tsv`, `summary.runs.tsv`, `startup_profile.runs.tsv`,
  `startup_profile.summary.tsv`

Focused profile reruns currently stay under `.tmp/bench/doc_parse/`.

## Caveats

Interpret benchmark output conservatively:

* `startup_probe` is tracked separately and should not be mixed into
  same-process `total`
* cold-start `summary.tsv` records both external wall-clock timing and hidden
  main-internal startup timing
* `estimated_process_runtime_ms` is an attribution estimate:
  `external_avg_ms - main_internal_avg_ms`
* `_bench-startup-profile` is a hidden benchmark-only command, not a normal
  user-facing CLI contract
* main-internal startup timing is not the whole cold-start process cost
* current cold-start suite records `noop`, `--help`, and one minimal TXT
  conversion; the main CLI now supports `--version`, but the checked helper
  still focuses on those three startup cases unless explicitly extended
* all figures are local observations on named checked-in corpora
* do not turn one machine's timings into cross-machine guarantees
* `doc_parse` library timing and product-path timing answer different questions
* PDF benchmark scope is native text-PDF by default
* OCR, scanned-PDF, and fallback paths are excluded unless explicitly called
  out
* a clean native CLI rebuild can be dramatically slower than incremental
  `moon build cli --target native`; avoid `moon clean` during routine benchmark
  iteration unless you are deliberately measuring full rebuild cost
* the native CLI surface is now split: treat lightweight `cli` numbers as the
  user-facing product-path baseline, treat `pdf` / `zip` as bundled
  PDF/ZIP support components kept for build guardrails, and treat `debug`,
  `ocr`, and `bench` numbers as dev/auxiliary surfaces rather than
  default-user startup costs
* the current local Ubuntu audit keeps normal `cli` out of the vendored PDF
  closure, trims `pdf` further through a parse-only `pdfopsread` package
  plus compact Shift-JIS and glyph lookup payloads, and measures one recent
  cold native rebuild at about `16s` for `cli`, `16s` for `pdf`,
  `15s` for `zip`, and `10s` for `ocr`; one direct in-process
  reintegration attempt for PDF/ZIP pushed `cli` to about `24.6s` and
  `30M / 653k` generated C, so the current bundled-component packaging is an
  intentional performance guardrail choice; the same `pdf` audit reduced
  generated C from about `21M / 454k` lines to about `18M / 381k`
* `cli ocr ...` is now part of the unified product CLI experience, but the
  actual OCR runtime closure still lives behind `ocr`; do not mix its
  timings into default non-OCR product-path claims
* `samples/pdf_layout_classifier/*` is developer training/evaluation tooling,
  not part of the default benchmark evidence story
