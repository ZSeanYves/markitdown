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
implementation and repository design.

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

Sealed `H2++ / H3++` scope: XLSX, HTML, ZIP, EPUB, DOCX, PPTX, and PDF for
native text-PDF scope.

The repository now centers its checked validation surface around
`./samples/check.sh` and `./samples/bench.sh`, while keeping external/private
quality intake separate under `samples/quality_corpus/`. External quality
sources remain manual-curated and local-cache driven rather than checked-in.

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
| CSV / TSV / JSON / YAML / TXT | stable structured/text paths | conservative boundaries documented in support docs; Markdown is handled separately as a lightweight scanner candidate |
| XML | source-preserving converter path + parser foundation candidate | source-preserving converter output today; `doc_parse/xml` is now an XML parser foundation candidate |

Benchmark and quality conclusions are limited to the checked-in corpora and
runner contracts named in the repository docs. They are not blanket claims
about all documents of a format family.

## doc_parse

`doc_parse/*` is the repository's reusable parsing foundation layer.

For overview, architecture contract, and split strategy, use:

* [doc_parse Overview](./doc_parse/README.md)
* [doc_parse Foundation](./docs/doc-parse-foundation.md)
* [doc_parse Package Strategy](./docs/package-publishing-strategy.md)

## Core Capabilities

* unified IR across document families
* shared rule-driven text-normalization substrate for output-safe cleanup
* profile/policy-gated cleanup reuse across PDF, TXT, HTML, DOCX, and PPTX,
  while canonical `NFD/NFC/NFKD/NFKC` remains explicit-only API surface
* conservative literal/source-preserving/structured-data paths that do not
  inherit aggressive cleanup by default
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
moon build --target native
```

Recommended invocation:

```bash
./_build/native/release/build/cli/cli.exe normal <input> [output]
```

Other product-path entrypoints:

```bash
./_build/native/release/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/release/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/release/build/cli/cli.exe debug --json <input>
./_build/native/release/build/cli/cli.exe ocr <input> [output]
```

`moon run` remains a development fallback. It is not the preferred runner for
H3++ performance conclusions.

## Validation

Recommended repository verification:

```bash
moon fmt
moon info
moon check
moon test
./samples/check.sh
./samples/bench.sh --suite smoke --kind smoke
```

Recommended focused benchmark entrypoints:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
./samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
```

Benchmark commands and output locations are tracked in
[docs/benchmarking.md](./docs/benchmarking.md).
Current performance baseline and caveats are tracked in
[docs/performance.md](./docs/performance.md).

Checked-in GitHub Actions CI now runs `moon build --target native`,
`moon check`, `moon test`, and `./samples/check.sh` on `ubuntu-latest` and
`macos-latest` for `push` and `pull_request`. `./samples/bench.sh --suite smoke
--kind smoke` remains available locally and as a manual `workflow_dispatch`
job; it is not part of the default PR gate. Windows core native support
remains documented, but the shell validation suite still targets WSL or
another POSIX shell rather than native Windows CI. `moon publish` remains a
manual release step.
Lower-layer parser/core and unsafe-boundary fixtures now live under
`samples/fixtures`; user-visible regression inputs now live under one unified
`samples/main_process` tree, with metadata-heavy and asset-heavy subcases
co-located under the same format roots. Each format package now keeps its
checked Markdown and exact CLI metadata expectations under
`samples/main_process/<format>/expected/`.
`samples/quality_corpus` is now reserved for signal-level external/private
quality intake. Its public manifest may stay intentionally empty until
externally sourced rows are manually curated and license-reviewed.
Current local hardening has already exercised manually curated rows from
Microsoft MarkItDown tests, Pandoc tests, `python-pptx`, and Open XML SDK
fixtures. Those rows are signal-level evidence only, not format or tool
oracles; the current remaining local `known_bad` boundary is
`pandoc_biblio_yaml`, a true multi-document YAML stream that remains
unsupported.
Current PDF hardening notes are intentionally conservative: the native path now
supports Level 1 `/ToUnicode` extraction, including current Type0/CIDFont
positive rows, while retained local `known_bad` rows still cover raw-GBK
simple fonts and `Identity-H` no-`/ToUnicode` CIDFont boundaries. For the
current matrix and limits, use [Support and Limits](./docs/support-and-limits.md)
and [doc_parse/pdf/README.md](./doc_parse/pdf/README.md).
Image-only PDFs stay on native image/assets output unless users explicitly
choose OCR.

Benchmark operations and performance caveats are tracked in
[docs/benchmarking.md](./docs/benchmarking.md) and
[docs/performance.md](./docs/performance.md).

## Text Cleanup Boundary

Text normalization in this repository is a conversion-quality substrate, not a
standalone product surface.

Current boundary:

* core owns rule-driven, profile/policy-gated pure string cleanup
* PDF output-safe extracted-text cleanup goes through that shared core layer
* PDF span/line/layout-aware repair stays in PDF-local text/model layers
* the default converter path does not enable canonical `NFD/NFC/NFKD/NFKC`
* literal/source-preserving/structured-data paths stay conservative
* the native PDF path no longer depends on known-phrase replacement, known
  split-word lists, global `replace_all("- ", "")`, or global slash-artifact
  cleanup as its main text-quality mechanism

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
* [Quality Corpus](./samples/quality_corpus/README.md)
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
* a full Unicode/ICU/UAX #15 conformance claim
* a benchmark claim beyond the checked-in corpora
