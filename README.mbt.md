# markitdown-mb

[![CI](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml/badge.svg)](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-6b7280)
![Formats](https://img.shields.io/badge/formats-14%2B-0ea5e9)
![Status](https://img.shields.io/badge/status-H2%2B%2B%20sealed%20%7C%20H3%2B%2B%20scoped-16a34a)
![Validation](https://img.shields.io/badge/validation-passing-16a34a)
![License](https://img.shields.io/badge/license-Apache--2.0-f59e0b)

`markitdown-mb` is a MoonBit-native document-to-Markdown converter for local
document structure extraction, RAG ingestion, and knowledge-base import. The
project is built around a native CLI, a unified IR, deterministic metadata and
asset sidecars, and checked-in validation and benchmark evidence.

It is inspired by Microsoft MarkItDown, but it is an independent MoonBit-native
implementation and repository design. It is not a Python package, not a
Microsoft project, and not affiliated with the AutoGen team.

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

Sealed `H2++ / H3++` scope: XLSX, HTML, ZIP, EPUB, DOCX, PPTX, and PDF for
native text-PDF scope.

The repository now centers its checked validation surface around
`./samples/check.sh` and `./samples/bench.sh`, and keeps the checked-in
`samples/real_world` corpus focused on longer complex-scenario documents.

## Supported Platforms

`markitdown-mb` targets MoonBit native builds on:

* Windows
* Linux
* macOS

The core converter is designed as a MoonBit-native CLI across those platforms.
The repository's validation and benchmark scripts are shell-based and are
primarily exercised in Unix-like environments; Windows users can use the native
build path and run the sample/benchmark script layer through WSL or an
equivalent POSIX shell until a dedicated Windows CI/script layer is added.
GitHub Actions validation is currently checked in for Ubuntu and macOS.

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

Benchmark and quality conclusions are limited to the checked-in corpora and
runner contracts named in the repository docs. They are not blanket claims
about all documents of a format family.

## Core Capabilities

* unified IR across document families
* shared profile-driven Text Normalization v2 substrate with staged PDF
  extracted-text and comparison cleanup
* shared document-text cleanup facade already reused by PDF, TXT, HTML, DOCX,
  and PPTX,
  while canonical `NFD/NFC/NFKD/NFKC` remains explicit-only API surface
* Markdown main output
* `assets/` export for materialized local images
* metadata sidecar via `--with-metadata`
* batch conversion with isolated per-document roots
* unified multi-format debug inspect CLI
* benchmark governance and checked-in benchmark corpora
* prebuilt-native runner preference for validation and benchmark work

## Performance Snapshot

Current repository performance conclusions are scoped to checked-in corpora and
explicit runner paths. Latest checked overlap comparisons against Microsoft
MarkItDown `0.1.5` on named local samples from
`samples/benchmark/compare_corpus.tsv` currently show representative
single-run gaps like:

| Format / case | markitdown-mb | Microsoft MarkItDown 0.1.5 | Ratio |
| --- | ---: | ---: | ---: |
| XLSX formula cached values | 10 ms | 425 ms | ~42x |
| DOCX nested lists mixed | 13 ms | 471 ms | ~36x |
| PPTX title bullets | 12 ms | 476 ms | ~40x |
| PDF URI link basic | 10 ms | 426 ms | ~43x |
| HTML figure + figcaption image | 10 ms | 442 ms | ~44x |
| EPUB nav TOC basic | 12 ms | 448 ms | ~37x |

Many checked overlap rows currently land in roughly the `35x-45x` faster band
on this local corpus. Separately from the Microsoft comparison, the direct
`doc_parse` library benchmark and the same-process product-path benchmark still
show no obvious `>10 ms` rows in the checked first-pass corpus. Cold CLI
startup/front-end is tracked separately; latest local checked `noop`,
`--help`, and minimal TXT cold-start rows sit around `8.7-9.3 ms` external and
must not be mixed into same-process totals.

These figures are local observations, not cross-machine guarantees. PDF
comparison rows apply only to the native text-PDF overlap corpus. For the
current baseline, cold-start attribution closure, and remaining follow-up work,
use [docs/performance.md](./docs/performance.md). For benchmark commands and
artifact directories, use [docs/benchmarking.md](./docs/benchmarking.md). For
overlap corpus scope and output-quality comparisons, use
[samples/benchmark/README.md](./samples/benchmark/README.md) and
[docs/quality-comparisons/README.md](./docs/quality-comparisons/README.md).

## CLI

Build the native product-path binary:

```bash
moon build cli --target native
moon build cli_pdf --target native
moon build cli_zip --target native
moon build cli_ocr --target native
```

Recommended invocation:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

Other product-path entrypoints:

```bash
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/debug/build/cli/cli.exe ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]
./_build/native/debug/build/cli_pdf/cli_pdf.exe [normal] [--with-metadata] <input.pdf> [output]
./_build/native/debug/build/cli_zip/cli_zip.exe [normal] [--with-metadata] <input.zip> [output]
./_build/native/debug/build/cli_debug/cli_debug.exe [debug] --json <input>
./_build/native/debug/build/cli_ocr/cli_ocr.exe [ocr] <input> [output]
./_build/native/debug/build/cli_bench/cli_bench.exe _bench-noop
```

`moon run` remains a development fallback. It is not the preferred runner for
H3++ performance conclusions.

The lightweight `cli` binary now owns the product-path user entry surface:
`normal`, `batch`, and explicit `ocr`. It delegates PDF conversion to
`cli_pdf`, ZIP conversion to `cli_zip`, and OCR execution to `cli_ocr`, so the
user-facing product entry stays unified while the heavy native closures remain
split behind component binaries. `debug` and hidden benchmark commands remain
explicit dev binaries. The launcher never silently falls back to `moon run`.

For repository scripts, prefer reusing the native CLI binary. Validation and
benchmark helpers probe existing native binaries first and only build
`cli`, `cli_pdf`, and `cli_zip` once when needed; they do not silently use
`moon run` unless `MARKITDOWN_ALLOW_MOON_RUN=1` is set explicitly. Native
runner overrides are available through `MARKITDOWN_CLI`,
`MARKITDOWN_PDF_CLI`, `MARKITDOWN_ZIP_CLI`, `MARKITDOWN_DEBUG_CLI`,
`MARKITDOWN_OCR_CLI`, and `MARKITDOWN_BENCH_CLI`.

## Validation

Recommended repository verification:

```bash
moon build cli --target native
moon build cli_pdf --target native
moon build cli_zip --target native
moon check
moon test
./samples/check.sh
./samples/bench.sh --suite smoke --kind smoke
```

Checked-in GitHub Actions CI now runs `moon build cli --target native`,
`moon check`, `moon test`, and `./samples/check.sh` on `ubuntu-latest` and
`macos-latest` for `push` and `pull_request`. `./samples/bench.sh --suite smoke
--kind smoke` remains available locally and as a manual `workflow_dispatch`
job; it is not part of the default PR gate. Windows core native support
remains documented, but the shell validation suite still targets WSL or
another POSIX shell rather than native Windows CI. `moon publish` remains a
manual release step.

Build-performance notes:

* `moon check` and incremental `moon build cli --target native` still carry
  noticeable fixed overhead
* the native CLI surface is now split across `cli`, `cli_pdf`, `cli_zip`,
  `cli_debug`, `cli_ocr`, and `cli_bench`; normal validation and benchmark
  gates should stay on lightweight `cli`
* the local audit reduced normal `cli.c` from about `37M / 824k` lines to
  about `18M / 381k` lines, removed vendored `mbtpdf` from normal `cli`
  entirely, and reduced one recent clean native rebuild from about
  `476-500s` to about `161s`
* the remaining heavy native text-PDF closure now lives behind `cli_pdf`;
  the latest measured clean-ish `cli_pdf` build is about `272s`
* `cli_zip` now delegates embedded PDF entries to `cli_pdf`, so ZIP no longer
  embeds vendored `mbtpdf` even though archive conversion can recurse into PDF
  entries; the latest measured clean-ish `cli_zip` build is about `158s`
* `cli ocr ...` now stays on the unified product CLI surface while delegating
  execution to `cli_ocr`
* avoid parallel `moon` commands and avoid habitual `moon clean`
* if scripts need the CLI, prefer one native build plus binary reuse across the
  whole validation or benchmark run
Lower-layer parser/core and unsafe-boundary fixtures now live under
`samples/fixtures`; user-visible regression inputs now live under one unified
`samples/main_process` tree, with metadata-heavy and asset-heavy subcases
co-located under the same format roots. Each format package now keeps its
checked Markdown and exact CLI metadata expectations under
`samples/main_process/<format>/expected/`.
A checked-in `samples/real_world` corpus now complements the smaller
feature-focused `samples/main_process` set with complex-only scenario files
across DOCX, PPTX, XLSX, PDF, HTML, ZIP, and EPUB. The default
`./samples/check.sh` chain runs the full real-world set, and
`./samples/check.sh --real-world --tags complex` remains available for focused
reruns.

Benchmark operations and performance caveats are tracked in
[docs/benchmarking.md](./docs/benchmarking.md) and
[docs/performance.md](./docs/performance.md).

## Documentation

* [Changelog](./CHANGELOG.md)
* [Documentation Map](./docs/README.md)
* [Performance](./docs/performance.md)
* [Roadmap](./docs/roadmap.md)
* [Benchmarking Guide](./docs/benchmarking.md)
* [Support and Limits](./docs/support-and-limits.md)
* [doc_parse Overview](./doc_parse/README.md)
* [doc_parse Foundation](./docs/doc-parse-foundation.md)
* [doc_parse Package Strategy](./docs/package-publishing-strategy.md)
* [Quality Comparisons](./docs/quality-comparisons/README.md)
* [Samples Overview](./samples/README.md)
* [Real-World Corpus](./samples/real_world/README.md)
* [Benchmark Corpus Policy](./samples/benchmark/README.md)
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
