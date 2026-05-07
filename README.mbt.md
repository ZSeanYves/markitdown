# markitdown-mb

![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Tests](https://img.shields.io/badge/tests-1275%20passed-16a34a)
![Main%20samples](https://img.shields.io/badge/main%20samples-346%20passed-16a34a)
![Metadata](https://img.shields.io/badge/metadata-82%20passed-16a34a)
![Assets](https://img.shields.io/badge/assets-42%20passed-16a34a)
![Bench%20smoke](https://img.shields.io/badge/bench%20smoke-96%20passed-16a34a)

Formats: DOCX, PPTX, XLSX, PDF, HTML, ZIP, EPUB, CSV, TSV, JSON, YAML, XML, Markdown, TXT

Sealed H2++ / H3++ scope: XLSX, HTML, ZIP, EPUB, DOCX, PPTX, and PDF for native text-PDF scope

`markitdown-mb` is a MoonBit-native lightweight document-to-Markdown
converter for local document structure extraction, RAG ingestion, and
knowledge-base import.

It is inspired by Microsoft MarkItDown, but it is an independent MoonBit-native
implementation and repository design. It is not a Python package, not a
Microsoft project, and not affiliated with the AutoGen team. The focus is
local, lightweight, explainable conversion paths, native CLI performance,
metadata sidecars, asset extraction, and reproducible checked-in
quality/benchmark evidence.

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Supported Platforms

The project is developed around MoonBit native builds and shell-based
validation scripts.

Current validated path:

* macOS / Unix-like shell environment
* MoonBit native build target
* prebuilt native CLI used by validation and benchmark scripts

Expected portable path:

* Linux or macOS with the MoonBit toolchain
* Windows is not the primary validated script environment today; WSL or another
  Unix-like shell is recommended for the current sample and benchmark scripts

## Current Status

| Format | Current status | Scope |
| --- | --- | --- |
| XLSX | H2++ complete / H3++ evidence-backed | native overlap corpus; lightweight formula evaluator v1, merged-cell boundary, typed cells, sheet state |
| HTML / HTM | H2++ complete / H3++ evidence-backed | lightweight safe parser; no browser-grade parsing, JS, CSS layout, or remote fetch |
| ZIP | H2++ complete / H3++ evidence-backed | safe container conversion; nested dispatch and asset remap; no nested archive recursion |
| EPUB | H2++ complete / H3++ evidence-backed | ZIP + OPF + spine + nav/NCX + XHTML chapters; no DRM/CSS/JS/remote fetch |
| DOCX | H2++ complete / H3++ evidence-backed | Word document structure recovery; not a Word layout engine |
| PPTX | H2++ complete / H3++ evidence-backed | presentation information structure recovery; not a PowerPoint layout engine |
| PDF | H2++ complete for native text-PDF scope / H3++ evidence-backed | native text-PDF only; no default OCR/scanned-PDF claim; no full PDF layout engine |
| CSV / TSV / JSON / YAML / XML / Markdown / TXT | stable structured/text paths | conservative boundaries documented in support docs; not all families are second-round sealed |

Benchmark and quality conclusions are always limited to the checked-in corpora
named in the relevant docs. They are not blanket claims about all documents of
that format.

## Validation Snapshot

Latest second-round closure run:

| Check | Result |
| --- | ---: |
| `moon test` | 1275 passed, 0 failed |
| Main process samples | 346 passed, 0 failed |
| Metadata sidecars | 82 passed, 0 failed |
| Asset checks | 42 passed, 0 failed |
| Benchmark smoke | 96 samples, 0 failures |
| Batch profile | 56 runs, 0 failures |
| MarkItDown compare | 94 runs, 0 failures |

These counts come from the current checked-in closure run and may change as the
sample corpus grows. Compare-harness success does not mean every format is
equally or fairly comparable with Microsoft MarkItDown.

## Core Capabilities

* unified IR across document families
* Markdown main output
* `assets/` export for materialized local images
* metadata sidecar via `--with-metadata`
* batch conversion with isolated per-document roots
* checked-in quality comparison records
* benchmark governance and checked-in benchmark corpora
* prebuilt-native runner preference for validation and benchmark work

## CLI

Build the native product-path binary:

```bash
moon build --target native
```

Recommended invocation:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

With metadata sidecar:

```bash
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
```

Batch conversion:

```bash
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/debug/build/cli/cli.exe batch --with-metadata <input_dir> <output_dir>
```

Debug and OCR entrypoints remain explicit non-default paths:

```bash
./_build/native/debug/build/cli/cli.exe debug <all|extract|raw|pipeline> <input> [output]
./_build/native/debug/build/cli/cli.exe ocr <input> [output]
```

Development fallback:

```bash
moon run cli -- normal <input> [output]
```

`moon run` is a functional fallback for development. It is not the preferred
runner for H3++ performance conclusions.

## Validation

Recommended repository verification:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
./samples/scripts/bench_smoke.sh --kind smoke
```

Useful additional checks:

```bash
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_cli_contract.sh
./samples/scripts/check_batch_contract.sh
./samples/scripts/check_corpus_manifest.sh
```

## Benchmark Notes

* prebuilt native CLI is the product performance path
* `moon run` is fallback and should be read as wrapper-inflated timing
* raw benchmark facts live in `results.jsonl`
* TSV summaries are generated per suite
* overlap comparison with Microsoft MarkItDown is sample-scoped and may be
  `not_comparable`
* OCR, cloud, plugin, and scanned-PDF paths are outside the default local H3++
  story

See [samples/benchmark/README.md](./samples/benchmark/README.md) and
[docs/benchmark-governance.md](./docs/benchmark-governance.md) for corpus,
runner, and comparability rules.

## Benchmark Results

Benchmark scripts write local artifacts under `.tmp/bench/`:

* smoke: `.tmp/bench/smoke/results.jsonl` and `.tmp/bench/smoke/summary.tsv`
* compare: `.tmp/bench/compare/results.jsonl` and `.tmp/bench/compare/summary.tsv`
* batch profile:
  `.tmp/bench/batch_profile/results.jsonl`,
  `.tmp/bench/batch_profile/summary.tsv`,
  `.tmp/bench/batch_profile/comparison-summary.tsv`,
  `.tmp/bench/batch_profile/startup-summary.tsv`

Run:

```bash
moon build --target native
./samples/scripts/bench_smoke.sh --kind smoke
./samples/scripts/bench_compare_markitdown.sh --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
./samples/scripts/bench_batch_profile.sh --formats xlsx,html,zip,epub,docx,pptx,pdf --counts 1,3 --iterations 1 --warmup 0 --memory auto
```

Notes:

* `prebuilt-native` is the product performance path
* `moon run` is a development fallback and should not be used for H3++ claims
* some formats are not fairly comparable with Microsoft MarkItDown on every
  scenario; use benchmark governance and quality records to interpret scope

## Documentation

* [Support and Limits](./docs/support-and-limits.md)
* [Second-Round Summary](./docs/second-round-summary.md)
* [Format Excellence Roadmap](./docs/format-excellence-roadmap.md)
* [Second-Round Hardening Audit](./docs/second-round-hardening-audit.md)
* [PDF H2++ Readiness Audit](./docs/pdf-h2pp-readiness-audit.md)
* [Benchmark Governance](./docs/benchmark-governance.md)
* [Quality Comparisons](./docs/quality-comparisons/README.md)
* [Samples Overview](./samples/README.md)
* [Benchmark Corpus Policy](./samples/benchmark/README.md)
* [Progress Summary](./docs/progress.md)
* [Architecture Overview](./docs/architecture.md)
* [Development Guide](./docs/development.md)

## Non-goals

`markitdown-mb` does not aim to be:

* a Word, PowerPoint, or PDF visual layout engine
* a browser-grade HTML renderer
* an OCR-first default converter
* a DRM/CSS/JS/remote-fetch pipeline
* a full Excel formula engine
* a benchmark claim beyond the checked-in corpora
