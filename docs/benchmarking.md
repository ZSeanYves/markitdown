# Benchmarking

This page is the current benchmark operations guide for the repository.

Recommended public benchmark entrypoint:

```bash
./samples/bench.sh
```

For current measured numbers, use
[docs/performance-baseline.md](./performance-baseline.md).

For performance-layer interpretation and ownership boundaries, use
[docs/doc-parse-performance.md](./doc-parse-performance.md) and
[docs/performance-roadmap.md](./performance-roadmap.md).

## Validation Before Benchmarking

Recommended verification chain:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
```

## Recommended Benchmark Commands

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

Product-path stage/help probes:

```bash
./samples/bench.sh --suite product-path --help
./samples/bench.sh --suite product-path --smoke
```

Batch profile:

```bash
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

Overlap comparison:

```bash
./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

## Performance Layers

Keep these layers separate:

* `doc_parse` library path:
  direct package APIs, no CLI startup, mostly no emit/metadata/assets work
* same-process product path:
  staged warm-runner normal conversion path, excluding `startup_probe`
* cold CLI / process-per-file:
  includes startup and process launch overhead

Do not mix `startup_probe` into same-process `total`.

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
  `summary.tsv`, `summary.runs.tsv`
* product-path smoke plan:
  `stage-plan.tsv`, `sample-plan.tsv`

Focused profile reruns currently stay under `.tmp/bench/doc_parse/`, for
example:

* `xlsx_profile.tsv`
* `docx_profile_after.tsv`
* `yaml_profile_after.tsv`
* `text_profile_after_final.tsv`
* `json_profile_after.tsv`
* `markdown_profile_after.tsv`

## Focused Helper Scripts

The public recommendation is to go through `./samples/bench.sh`.

These helpers remain compatible for focused work:

* `./samples/bench_doc_parse.sh`
* `./samples/bench_product_path.sh`

Use them when you need direct stage/profile control without changing the public
entrypoint contract.

## Caveats

Interpret benchmark output conservatively:

* all numbers are local observations on named checked-in corpora
* do not turn one machine's timings into cross-machine guarantees
* direct `doc_parse` timing and product-path timing answer different questions
* PDF benchmark scope is native text-PDF by default
* OCR, scanned-PDF, and fallback paths are excluded unless explicitly called
  out
* some product-path `parse` vs `convert` splits are still partial for
  `docx/pptx`
