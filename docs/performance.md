# Performance

This page is the current measured performance and benchmarking summary for the
repository.

It records checked local facts and keeps claims conservative.

## Current Build Snapshot

Current checked local clean-build snapshot:

* `cli build`: `64.06s`
* `pdf build`: `69.07s`
* `zip build`: `63.48s`
* `cli.exe`: `3,790,168`
* `pdf.exe`: `4,354,040`
* `zip.exe`: `3,601,656`
* `cli.c`: `401,407`
* `pdf.c`: `450,869`
* `zip.c`: `378,571`

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
* `bash samples/bench.sh` runs the default recommended smoke suite and prints a
  short summary pointing to `.tmp/bench/smoke/summary.tsv` and
  `.tmp/bench/smoke/results.jsonl`.

Common suites:

```bash
bash samples/bench.sh
bash samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
bash samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
bash samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
bash samples/bench.sh --suite batch-profile --counts 1,3 --iterations 1 --warmup 0 --memory auto
bash samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
```

Benchmark artifacts are written under `.tmp/bench/`, with the default smoke
entrypoint writing:

* summary: `.tmp/bench/smoke/summary.tsv`
* raw results: `.tmp/bench/smoke/results.jsonl`
* converter scratch: `.tmp/bench/<suite>/workspace/`

Product-path attribution smoke:

```bash
moon build cli --target native
bash samples/helpers/bench/check_product_path_attribution_smoke.sh
```

That helper is a lightweight diagnostic layer over the public native
`cli.exe`. It prints TSV rows to stdout, writes transient files under `.tmp/`,
does not submit artifacts to the repository, and should be read as a
same-machine directional baseline rather than a release-facing performance
promise.

Current helper scratch path:

* `.tmp/bench/helpers/`

If you need to point at a different prebuilt binary, run:

```bash
MARKITDOWN_CLI=/path/to/cli.exe bash samples/helpers/bench/check_product_path_attribution_smoke.sh
```

Image OCR attribution smoke stays separate from that normal document baseline:

```bash
moon build cli --target native
bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh
```

That helper exercises the main-CLI image OCR path against the repo-local tiny
fixture with real local `tesseract` execution. It supports
`MARKITDOWN_CLI=/path/to/cli.exe`, skips cleanly when `tesseract` or `eng`
tessdata is unavailable, writes transient files under `.tmp/`, and should be
read as a same-machine directional signal rather than a release-facing latency
promise.

Current helper scratch path:

* `.tmp/bench/helpers/image_ocr_bench/`

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

The current OCR/Vision scaffold is also outside that contract:

* internal/dev-only `convert/vision` work does not define normal-path
  performance promises
* `tsv_preview_tool` and OCR quality-lab helpers are excluded from default
  runtime benchmark claims
* product-path attribution smoke is diagnostic only, not a release-facing
  latency guarantee
* image OCR attribution is measured separately because it depends on external
  `tesseract` plus installed tessdata rather than the normal document baseline

## Future PDF OCR Attribution Boundary

Any future PDF OCR path must stay outside the native PDF baseline.

Required interpretation rules for a future rollout:

* PDF OCR timing must be measured separately from the native PDF path
* PDF OCR timing must not be folded into the current normal product-path
  attribution smoke
* an OCRmyPDF-style PDF-level provider, a page-image-plus-image-OCR route, and
  heavier optional audited providers should each carry separate attribution
  rows
* future PDF OCR claims must name the provider family, sample scope, and local
  runtime prerequisites
* current builds ship no PDF OCR performance claim because PDF OCR is not
  wired

## Product-Path Attribution Smoke

Current helper:

* `bash samples/helpers/bench/check_product_path_attribution_smoke.sh`

Current contract:

* it uses the public native `cli.exe`, not hidden bench commands
* it recommends a prebuilt runner first:
  `moon build cli --target native`
* it supports `MARKITDOWN_CLI=/path/to/cli.exe`
* it does not use `moon run` in the measured loop
* it does not run OCR or `tesseract`
* it does not include internal/dev OCR/Vision scaffold behavior
* it does not currently measure the main-CLI image OCR path, which depends on
  local `tesseract` and tessdata and should be interpreted separately from the
  normal document baseline
* it writes transient output under `.tmp/` and removes it unless temp
  preservation is explicitly enabled

Current sample scope is intentionally small and repo-local:

* one markdown-only TXT row
* one metadata-enabled JSON row
* one local-assets HTML row
* one local-assets + metadata DOCX row
* one small batch row for directional amortization

Output columns:

* `case`
* `mode`
* `runs`
* `median_ms`
* `min_ms`
* `max_ms`
* `input`
* `output_bytes`
* `notes`

Interpretation rules:

* startup is included in each measured CLI invocation
* dispatcher / parse / emit are observed as public product-path timing, not
  internal stage hooks
* metadata and asset effects are observed through current output modes rather
  than hidden instrumentation
* batch output is a directional amortization signal, not a replacement for the
  existing `batch-profile` suite
* OCR latency depends on external `tesseract` and installed tessdata, so image
  OCR performance should be measured separately from the default document path
* measured numbers vary with machine, cache state, filesystem behavior, and
  build mode, so this helper should not be used as a fixed performance
  guarantee

Boundary reminder:

* do not compare these normal-path rows directly against image OCR rows without
  noting that image OCR includes external OCR work plus OCR-specific layout
  recovery stages

## Image OCR Attribution Smoke

Current helper:

* `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`

Current contract:

* it is separate from normal product-path attribution smoke
* it uses the public native `cli.exe`, not hidden bench commands
* it recommends a prebuilt runner first:
  `moon build cli --target native`
* it supports `MARKITDOWN_CLI=/path/to/cli.exe`
* it does not build binaries internally
* it requires local `tesseract` plus installed `eng` tessdata
* it prints `IMAGE OCR ATTRIBUTION SMOKE SKIPPED: tesseract not installed`
  when `tesseract` is unavailable
* it prints `IMAGE OCR ATTRIBUTION SMOKE SKIPPED: eng tessdata not installed`
  when `eng` tessdata is unavailable
* it exercises the repo-local tiny fixture
  `samples/fixtures/ocr/tiny_ocr_sample.png`
* it currently measures three success modes:
  `image_auto`, `image_ocr_lang_eng`, and `image_explicit_ocr`
* it runs each success mode three times by default
* it validates that each run contains the expected OCR text from
  `samples/fixtures/ocr/tiny_ocr_sample.expected.txt`
* it writes transient output under `.tmp/helpers/image_ocr_bench/` and removes
  it unless temp preservation is explicitly enabled
* it does not write checked-in result artifacts
* it is an optional diagnostic, not a main validation gate or release hard gate

Output columns:

* `case`
* `mode`
* `runs`
* `median_ms`
* `min_ms`
* `max_ms`
* `input`
* `output_bytes`
* `notes`

Interpretation rules:

* it measures the real main-CLI image OCR path, including external
  `tesseract` work
* it does not redefine the normal document benchmark baseline
* it should not be compared directly against normal document-path rows without
  context about external OCR dependency, fixture scope, and different stage
  mix
* it does not imply scanned-PDF OCR timing or support
* measured numbers vary with machine, cache state, filesystem behavior,
  `tesseract` build, and installed tessdata
* rows should be interpreted as same-machine directional signals, not fixed
  performance promises

Current release-stage interpretation:

* normal product-path attribution remains the baseline for non-OCR document
  conversion
* image OCR attribution is a separate directional observation path for the
  shipped image OCR MVP
* OCR timing depends on local `tesseract` and installed tessdata, so it should
  not be folded into broad “normal document path” claims
* deeper OCR phase attribution remains future work if the current directional
  smoke stops being sufficient

## Current Direction

The repository’s current performance posture is:

* keep `cli` lightweight
* keep heavy PDF cost behind bundled `pdf`
* keep delegated product `zip` outside the PDF closure
* keep benchmark claims sample-scoped and reproducible
* avoid performance claims for OCR, scanned-PDF, or unverified future paths
