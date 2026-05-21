# Performance

This page is the current measured performance and benchmarking summary for the
repository.

It records checked local facts and keeps claims conservative.

## Current Build Snapshot

Current checked local clean-build snapshot:

* `cli build`: `64.06s`
* `pdf build`: `69.07s`
* `zip build`: `63.48s`
* `ocr build`: `54.72s`
* `cli.exe`: `3,790,168`
* `pdf.exe`: `4,354,040`
* `zip.exe`: `3,601,656`
* `ocr.exe`: `1,644,328`
* `cli.c`: `401,407`
* `pdf.c`: `450,869`
* `zip.c`: `378,571`
* `ocr.c`: `154,425`

Interpretation:

* these are local clean-build measurements
* they are not cross-machine guarantees
* build cost remains intentionally split across bundled components

## Closure Snapshot

Current checked closure counts:

* `cli mbtpdf count`: `0`
* `zip mbtpdf count`: `0`
* `pdf mbtpdf count`: `23339`

Current interpretation:

* lightweight `cli` stays outside the vendored PDF closure
* delegated product `zip` also stays outside that closure
* the heavy native text-PDF cost stays behind bundled `pdf`

## Benchmark Commands

Public benchmark entrypoint:

* `samples/bench.sh`
* `bash samples/bench.sh --help` shows available benchmark suites.
* `bash samples/bench.sh --suite smoke --kind smoke` is the lightweight
  copy-paste-safe smoke benchmark.

Common suites:

```bash
bash samples/bench.sh --suite smoke --kind smoke
bash samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
bash samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
bash samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
bash samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
bash samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

Benchmark artifacts are written under `.tmp/bench/`.

## Compare Snapshot

Current checked overlap-only compare timing against Microsoft MarkItDown
`0.1.5`:

* date: `2026-05-19`
* overlap rows per runner: `47`
* total runs: `282`
* failures: `0`
* `markitdown-mb`: `11.009 ms`
* `markitdown-python`: `421.715 ms`

Do not turn that into a universal speed guarantee.

It is:

* local
* sample-scoped
* overlap-corpus-scoped
* timing only

## Interpretation Rules

Current benchmark/performance language is intentionally bounded:

* same-machine only
* named runner path only
* named corpus only
* no blanket quality score attached
* no blanket “faster than” claim beyond the checked overlap run

OCR, scanned-PDF behavior, and optional quality-lab training/eval workflows are
not part of the default runtime performance contract.

## Current Direction

The repository’s current performance posture is:

* keep `cli` lightweight
* keep heavy PDF cost behind bundled `pdf`
* keep delegated product `zip` outside the PDF closure
* keep benchmark claims sample-scoped and reproducible
