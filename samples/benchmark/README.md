# Benchmark Corpus Policy

This directory holds the repository's checked-in benchmark corpora, manifests,
and warning-policy files.

It is meant to make performance work reviewable and reproducible. It is not a
dumping ground for arbitrary local inputs.

For the recommended benchmark command menu and output layout, use
[docs/benchmarking.md](../../docs/benchmarking.md).

For current performance layers, measured baseline, and caveats, use
[docs/performance.md](../../docs/performance.md).

## Checked-in Control Files

* `corpus.tsv`
* `compare_corpus.tsv`
* `perf_thresholds.tsv`
* `corpus_manifest.example.tsv`
* `manifests/doc_parse.tsv`
* `manifests/product_path.tsv`

Related helper:

* `../scripts/check_corpus_manifest.sh`

Public benchmark entrypoint:

* `../bench.sh`

## Corpus Roles

### `corpus.tsv`

Checked-in smoke and metadata benchmark rows for the repository's default local
path.

This corpus supports:

* smoke timing
* metadata-on overhead rows
* selected format-heavy cases such as assets-heavy, link-heavy, table-heavy, or
  notes-heavy rows where relevant

### `compare_corpus.tsv`

Checked-in overlap-only comparison rows against Microsoft MarkItDown.

This corpus is intentionally narrower than `corpus.tsv`:

* only include fair local overlaps
* do not treat compare rows as a blanket support list
* use `not_comparable` where overlap is not fair

### `perf_thresholds.tsv`

Conservative local warning thresholds for selected benchmark suites and rows.

These are:

* local warnings
* not a universal SLA
* not a blanket product claim

## Result Output

Benchmark scripts write local artifacts under `.tmp/bench/...`.

Current suite roots:

* smoke: `.tmp/bench/smoke/`
* compare: `.tmp/bench/compare/`
* batch profile: `.tmp/bench/batch_profile/`
* doc-parse library: `.tmp/bench/doc_parse/`
* product path: `.tmp/bench/product_path/`

Typical outputs:

* `results.jsonl`: raw fact layer
* `summary.tsv`: suite summary
* additional suite-specific TSV files where relevant

## Runner Policy

Repository benchmark conclusions are based on:

* prebuilt native CLI
* explicit execution path
* checked-in named corpus

`moon run` remains a development fallback but is not the preferred H3++
performance reference.

## Reproduction

Smoke benchmark:

```bash
./samples/bench.sh
```

Default smoke results are written to:

* `.tmp/bench/smoke/summary.tsv`
* `.tmp/bench/smoke/results.jsonl`

Overlap comparison:

```bash
command -v markitdown
markitdown --version || true
./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

Do not turn this overlap-only suite into a blanket quality percentage by
itself.
Record the competitor version, machine, corpus size, and exact metric before
publishing any README claim.

Batch profiling:

```bash
./samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

doc_parse library benchmark:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
```

Default manifest:

```text
samples/benchmark/manifests/doc_parse.tsv
```

Internal harness package:

```text
doc_parse/bench
```

Product-path attribution benchmark:

```bash
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
./samples/bench.sh --suite product-path --smoke
```

Default manifest:

```text
samples/benchmark/manifests/product_path.tsv
```

Repo-local sample validation:

```bash
./samples/check.sh
```

Internal direct helper:

```bash
./samples/helpers/validation/check_corpus_manifest.sh
./samples/helpers/validation/check_corpus_manifest.sh samples/benchmark/corpus_manifest.example.tsv
```

## Comparability Rules

Read compare results conservatively:

* compare rows are sample-scoped
* quality and performance overlap are different questions
* OCR, cloud, plugin, and scanned-PDF paths are outside the default local
  compare story
* PDF compare claims apply only to native text-PDF scope

For benchmark-layer interpretation and current caveats, use
[docs/performance.md](../../docs/performance.md).

## Current Sealed-format Benchmark Scope

The second-round sealed formats use checked-in benchmark rows as follows:

* XLSX: native overlap corpus plus formula/merged/type-heavy smoke rows
* HTML: native overlap corpus plus malformed/local-asset/metadata rows
* ZIP: native corpus plus container/degrade/assets rows
* EPUB: native EPUB corpus plus nav/NCX/assets/warning rows
* DOCX: native overlap corpus plus table/link/image/notes-heavy rows
* PPTX: native overlap corpus plus link/notes/layout-heavy rows
* PDF: native text-PDF corpus plus link/table/caption/metadata rows

These are checked-in engineering corpora, not blanket claims about all
documents of those families.

## Sample Placement Rules

Benchmark samples may reuse content already represented elsewhere, but their
role should stay explicit:

* benchmark rows are not the sole correctness evidence
* quality comparison docs are not benchmark manifests
* metadata rows should be called out explicitly when they are intended to
  measure metadata-on overhead

## Future Corpora

For larger real-world or private corpora:

* keep the files out of the repository
* use a manifest derived from `corpus_manifest.example.tsv`
* keep provenance and license explicit
* do not turn local-only findings into universal claims
