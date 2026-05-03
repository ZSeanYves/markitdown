# markitdown-mb

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown tool.
It is inspired by Microsoft MarkItDown’s product direction, but it is not a
Python-port clone. The project focuses on conservative, auditable conversion,
stable degradation, and reusable parsing infrastructure.

The current pipeline is:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Current Scope

Supported input families:

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

Core project capabilities:

* MoonBit native CLI
* self-managed OOXML / ZIP / PDF foundations
* unified IR
* Markdown emitter
* asset export
* metadata sidecar
* origin provenance
* PDF debug pipeline
* regression samples
* internal and comparison benchmark harnesses

## Output Model

The tool can produce:

* Markdown main output
* `assets/` export when the source contains materialized images
* `metadata/*.metadata.json` sidecar when `--with-metadata` is enabled

Typical layout:

```text
out/
  demo.md
  assets/
    image01.png
  metadata/
    demo.metadata.json
```

## Quick Start

Normal conversion:

```bash
moon run cli -- normal <input> [output]
```

With metadata sidecar:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
```

Other entrypoints:

```bash
moon run cli -- ocr <input> [output]
moon run cli -- batch <input_dir> <output_dir>
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

Batch v1 directory conversion:

```bash
moon run cli -- batch --with-metadata <input_dir> <output_dir>
```

Batch v1 writes one isolated document root per top-level input file:

```text
out/
  001-demo/
    demo.md
    assets/
    metadata/demo.metadata.json
```

Notes:

* `ocr` is a separate path, not the default mainflow
* `batch` is non-recursive in v1; it scans only the top-level files in
  `<input_dir>`
* stdout mode only prints Markdown; it does not write sidecar files
* if `[output]` looks like a directory, the tool writes `<output>/<input_stem>.md`

## Support Summary

Current supported input families:

* OOXML: DOCX / PPTX / XLSX
* PDF
* HTML / HTM
* Structured data: CSV / TSV / JSON / YAML / YML / XML
* Text-like: Markdown / MD / MARKDOWN / TXT
* Container: ZIP
* Ebook: EPUB

Important boundaries:

* TXT is plain-text paragraph conversion; it does not infer Markdown semantics
* XML is source-preserving fenced `xml` code-block conversion; it is not a
  semantic XHTML / RSS / OPF / SVG converter

For the full per-format support contract and limits, see
[docs/support-and-limits.md](./docs/support-and-limits.md).

## Regression And Benchmark

Regression is split into three chains:

* `samples/main_process`
* `samples/metadata`
* `samples/assets`

Useful commands:

```bash
./samples/check_samples.sh
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
```

Internal smoke benchmark:

```bash
./samples/bench_smoke.sh --kind smoke
```

Overlap-only comparison benchmark:

```bash
./samples/bench_compare_markitdown.sh --help
```

The comparison benchmark uses a user-managed external `markitdown` command. It
does not create a repository-local Python virtual environment.

## Project Positioning

This repository is not aimed at pixel-perfect layout reproduction. The current
engineering priorities are:

* conservative structural recovery
* auditable provenance and debug surfaces
* stable, explainable degradation
* regression-verifiable behavior
* reusable content-processing infrastructure

OCR, cloud services, LLM-style understanding, and complex visual reasoning are
not part of the default `normal` mainflow contract.

## Documentation

* [Support and Limits](./docs/support-and-limits.md)
* [Full-format Hardening Milestone](./docs/full-format-hardening-milestone.md)
* [Architecture](./docs/architecture.md)
* [Development Guide](./docs/development.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Progress Summary](./docs/progress.md)
* [Benchmark Baseline](./docs/benchmark-baseline.md)
* [Benchmark Comparison](./docs/benchmark-comparison.md)
* [Benchmark Comparison Baseline](./docs/benchmark-comparison-baseline.md)
* [Sample Coverage](./docs/sample-coverage.md)
