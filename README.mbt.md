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
* Markdown main output
* `assets/` export for materialized local images
* metadata sidecar via `--with-metadata`
* batch conversion with isolated per-document roots
* unified multi-format debug inspect CLI
* benchmark governance and checked-in benchmark corpora
* prebuilt-native runner preference for validation and benchmark work

## Performance Snapshot

The H3++ performance evidence is based on the prebuilt-native CLI path, not
`moon run`.

The checked-in overlap comparison uses Microsoft MarkItDown `0.1.5` on named
local samples from `samples/benchmark/compare_corpus.tsv`. Representative
single-run examples currently sit in roughly the `20x` to `50x` range:

| Format / case | markitdown-mb | Microsoft MarkItDown 0.1.5 | Ratio |
| --- | ---: | ---: | ---: |
| XLSX formula cached values | 10 ms | 480 ms | ~48x |
| DOCX nested lists mixed | 31 ms | 821 ms | ~26x |
| PPTX title bullets | 18 ms | 710 ms | ~39x |
| PDF URI link basic | 11 ms | 516 ms | ~47x |

These measurements are corpus-scoped local benchmark facts, not universal
performance claims. PDF comparison rows apply only to the native text-PDF
overlap corpus. Full raw results, representative tables, and caveats live in
[docs/validation-and-benchmark-summary.md](./docs/validation-and-benchmark-summary.md)
and [docs/benchmark-governance.md](./docs/benchmark-governance.md).

## CLI

Build the native product-path binary:

```bash
moon build --target native
```

Recommended invocation:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

Other product-path entrypoints:

```bash
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/debug/build/cli/cli.exe debug --json <input>
./_build/native/debug/build/cli/cli.exe ocr <input> [output]
```

`moon run` remains a development fallback. It is not the preferred runner for
H3++ performance conclusions.

## Validation

Recommended repository verification:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
./samples/scripts/bench_smoke.sh --kind smoke
```

Checked-in GitHub Actions CI now runs `moon build --target native`,
`moon check`, `moon test`, and `./samples/check.sh` on `ubuntu-latest` and
`macos-latest` for `push` and `pull_request`. `bench_smoke.sh --kind smoke`
remains available locally and as a manual `workflow_dispatch` job; it is not
part of the default PR gate. Windows core native support remains documented,
but the shell validation suite still targets WSL or another POSIX shell rather
than native Windows CI. `moon publish` remains a manual release step.

Detailed validation counts, sample matrices, metadata/assets checks, benchmark
smoke counts, batch profile results, and MarkItDown comparison runs are tracked
in [docs/validation-and-benchmark-summary.md](./docs/validation-and-benchmark-summary.md).

## Documentation

* [Changelog](./CHANGELOG.md)
* [Second-Round Summary](./docs/second-round-summary.md)
* [Validation and Benchmark Summary](./docs/validation-and-benchmark-summary.md)
* [Support and Limits](./docs/support-and-limits.md)
* [Benchmark Governance](./docs/benchmark-governance.md)
* [Quality Comparisons](./docs/quality-comparisons/README.md)
* [Samples Overview](./samples/README.md)
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
