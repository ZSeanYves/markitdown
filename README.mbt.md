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
* Delimited text: CSV / TSV
* Structured text: JSON / YAML / YML / XML
* Text-like: TXT / Markdown / MD / MARKDOWN
* Containers: ZIP
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
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

Notes:

* `ocr` is a separate path, not the default mainflow
* stdout mode only prints Markdown; it does not write sidecar files
* if `[output]` looks like a directory, the tool writes `<output>/<input_stem>.md`

## Support Matrix

| Family | Current behavior | Important limits |
| --- | --- | --- |
| DOCX | Headings, lists, tables, hyperlinks, images, block quotes, code-like paragraphs | No footnotes/endnotes/comments/textbox-special handling |
| PPTX | Reading order, title/body separation, lists, layout-aware blocks, images, hyperlinks | No full notes support, no advanced multi-image caption pairing |
| XLSX | Multi-sheet table output with datetime formatting and sparse trimming | No formula evaluation, merged-cell reconstruction, or image output |
| PDF | Conservative structural recovery with exported images and lightweight provenance | No default annotation-link emission, no complex-table recovery, no OCR-first default |
| HTML / HTM | Lightweight semantic recovery for headings/lists/tables/quotes/code/links/images | No browser/CSS/JS rendering or remote fetch |
| CSV / TSV | Conservative table conversion | No dialect sniffing or schema inference |
| TXT | Plain-text paragraph conversion with BOM/newline normalization | No Markdown semantics or assets |
| XML | Source-preserving fenced `xml` code-block conversion | No XML semantic recovery, DTD/entity expansion, or schema validation |
| JSON | Conservative table/list/code-block mapping | No JSON Lines / Schema / streaming |
| YAML / YML | Conservative simple-subset table/list/code-block mapping | No anchors / aliases / tags / block scalar / multi-doc |
| Markdown / MD / MARKDOWN | Source-preserving passthrough | No AST rewriting |
| ZIP | Safe entry traversal with supported nested-entry conversion and archive asset namespacing | No nested recursion, no binary preview, no remote HTML asset fetch |
| EPUB | `container.xml` + OPF manifest/spine driven conversion for XHTML/HTML spine items | No DRM, CSS rendering, nav/NCX semantic reconstruction, or advanced media fallback |

For full per-format support and limits, see [docs/support-and-limits.md](/home/zseanyves/markitdown/docs/support-and-limits.md).

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
* [Architecture](./docs/architecture.md)
* [Development Guide](./docs/development.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Progress Summary](./docs/progress.md)
* [Benchmark Baseline](./docs/benchmark-baseline.md)
* [Benchmark Comparison](./docs/benchmark-comparison.md)
* [Sample Coverage](./docs/sample-coverage.md)
