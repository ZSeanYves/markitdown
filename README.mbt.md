# markitdown-mb

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown tool.
It is inspired by Microsoft MarkItDown’s product direction, but it is not a
Python wrapper or Python-port clone. The project focuses on conservative,
auditable conversion, stable degradation, and reusable parsing infrastructure.

Dispatcher coverage now spans all primary repository format families, but
support maturity differs by format. The project is past its initial
full-format H2 sweep, yet that should be read as "documented main-path support
contracts" rather than "final done" for every format.

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

PDF lower-layer note:

* the native PDF path uses `doc_parse/pdf` plus a repository-local maintained
  vendored backend under `vendor/mbtpdf`
* `vendor/mbtpdf` is maintained in-repo for markitdown-specific PDF parser
  needs; it is not treated as a path-only external dependency during publish

## Support Status

The repository is past the initial H2 sweep across the main input set:

* `H2 main-path quality`: TXT, Markdown, CSV / TSV, JSON
* `H2 partial`: PDF
* `H2++ complete, H3++ evidence-backed on checked-in native overlap corpus`: XLSX,
  HTML / HTM, DOCX, PPTX
* `H2++ complete, H3++ evidence-backed on checked-in native corpus`: ZIP
* `subset-H2`: YAML / YML
* `source-preserving H1/H2 partial`: XML
* `H2++ complete, H3++ evidence-backed on checked-in native EPUB corpus`: EPUB

These labels are support-contract shorthand, not final-completion claims. H3
performance conclusions also require benchmark evidence and should not be
inferred from status labels alone.

For second-round per-format excellence sprints, use
[docs/format-excellence-roadmap.md](./docs/format-excellence-roadmap.md).

## Format Matrix

| Format | Status | Highlights | Known limitations |
| --- | --- | --- | --- |
| TXT | H2 main-path quality | literal-safe text conversion, metadata | UTF-8-only conservative policy, no heading/list/table inference |
| Markdown | H2 main-path quality | source-preserving passthrough, metadata | not a Markdown AST semantic converter |
| CSV / TSV | H2 main-path quality | stable table lowering, `RichTable` metadata | no streaming or huge-table H3 tuning yet |
| JSON | H2 main-path quality | conservative structured-data lowering, metadata | no streaming/materialization optimization yet |
| YAML / YML | subset-H2 | fail-closed conservative subset, structured-data lowering | not full YAML 1.2 coverage |
| XML | source-preserving H1/H2 partial | fenced `xml` output, safe tokenizer base | not a semantic XML-family converter |
| HTML / HTM | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | lightweight safe semantic parsing, tables/links/images, `RichTable` metadata, local-asset export, provenance hints, unsafe-link fail-closed policy | not browser-grade, no CSS layout or JS, no remote fetch, no rowspan/colspan visual reconstruction |
| XLSX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | workbook/sheet/cell lower layer, datetime handling, metadata, cached-first formula policy with lightweight missing-cache evaluation v1, merged/state/type policy evidence | no charts/comments/pivots, no merged-cell visual reconstruction, no full Excel formula compatibility |
| ZIP | H2++ complete, H3++ evidence-backed on checked-in native corpus | safe archive traversal, inspect surface, nested dispatch, warning/degrade policy, nested asset remap, container provenance | no recursive nested archive conversion, no ZIP64/data-descriptor/encrypted support, no blanket overlap-performance claim |
| EPUB | H2++ complete, H3++ evidence-backed on checked-in native EPUB corpus | safe OPF/spine/nav/NCX/cover/assets pipeline, warning/degrade policy, metadata/origin | no DRM/CSS/JS/remote fetch, NCX minimal subset only, not a reading-system renderer |
| DOCX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | lists, multiline/merged-boundary tables, notes/comments, headers/footers, text boxes, local image assets, metadata | not a Word layout engine, no full tracked-change UI, no full run-level style fidelity, no complex visual table reconstruction |
| PPTX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | slide order, bullets, grouped shapes, explicit tables, notes, hidden slides, images | no charts/SmartArt/OLE/action links/animations, no full merged-table visual reconstruction |
| PDF | H2++ complete for native text-PDF scope, H3++ evidence-backed on checked-in native text-PDF corpus | headings/noise/merge, URI links, simple tables, captions, provenance | default strength is text PDF, not scanned/OCR or full complex-layout recovery |

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

## Native CLI

Recommended product-path build:

```bash
moon build --target native
```

Repository scripts prefer a discovered prebuilt native CLI binary. Use
`MARKITDOWN_CLI=/abs/path/to/cli` to pin an explicit binary. If no working
prebuilt binary is found, scripts fall back to `moon run` and print a warning;
that fallback is for development convenience, not H3++ native-performance
evidence.

## Quick Start

Recommended product-path command form:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

Development fallback:

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
* `ocr` should be treated as optional/experimental relative to the native PDF
  path; it is not the repository's default support contract
* `batch` is non-recursive in v1; it scans only the top-level files in
  `<input_dir>`
* `batch` is serial in v1; it does not yet run files in parallel
* stdout mode only prints Markdown; it does not write sidecar files
* if `[output]` looks like a directory, the tool writes `<output>/<input_stem>.md`
* `--with-metadata` writes `<markdown_dir>/metadata/<stem>.metadata.json`
* emitted image assets are written under `assets/` beside the Markdown output;
  archive and nested-document formats may namespace assets conservatively under
  `assets/archive/...`

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

* TXT is a literal-safe text path; it does not infer heading/list/table
  semantics
* Markdown is passthrough; it is not a Markdown AST semantic converter
* PDF is strongest on text-oriented PDFs; scanned/OCR and cloud-style document
  understanding paths are separate from the default local mainflow
* HTML is a lightweight safe parser, not a browser-grade engine; no JS, no CSS
  layout, no remote fetch, and unsafe `javascript:` / `data:` / `vbscript:`
  links fail closed
* YAML is a conservative supported subset, not full YAML 1.2
* XML is source-preserving fenced `xml` code-block conversion; it is not a
  semantic XHTML / RSS / OPF / SVG converter
* ZIP is container dispatch with explicit security/feature limits; not all ZIP
  features are supported
* EPUB is a safe OPF/spine/nav/NCX/local-asset main path, not DRM/CSS/full-render
  support
* XLSX uses cached values first and only evaluates a conservative local subset
  of missing-cache formulas; it is not a full Excel formula engine
* PPTX is a lightweight presentation converter, not a PowerPoint layout engine;
  no animations/transitions, no SmartArt/chart/OLE rendering, and reading
  order remains heuristic rather than visual-layout exact

For the full per-format support contract and limits, see
[docs/support-and-limits.md](./docs/support-and-limits.md).

## Regression And Benchmark

Regression is split into three chains:

* `samples/main_process`
* `samples/metadata`
* `samples/assets`

Useful commands:

```bash
./samples/check.sh
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_cli_contract.sh
./samples/scripts/check_batch_contract.sh
```

Internal smoke benchmark:

```bash
./samples/scripts/bench_smoke.sh --kind smoke
```

Overlap-only comparison benchmark:

```bash
./samples/scripts/bench_compare_markitdown.sh --help
```

The comparison benchmark uses a user-managed external `markitdown` command. It
does not create a repository-local Python virtual environment.

Benchmark interpretation:

* current harnesses include selected overlap cases where the measured
  native-preferred repository runner is faster on the same machine
* these are **selected** overlaps, not blanket semantic- or performance-parity
  claims for every document shape
* broader "speed lead" language still requires benchmark evidence per
  runner/mode/corpus and must keep native CLI, `moon run`, and OCR/cloud paths
  separate
* when a benchmark falls back to `moon run`, measured time includes wrapper
  overhead; prebuilt native CLI runs are the stronger performance reference

Current H3 phase:

* H3 phase 1 performance work is summarized in
  [docs/h3-phase-1-summary.md](./docs/h3-phase-1-summary.md)
* H3 phase 2 now focuses on benchmark governance and broader corpus policy via
  [docs/h3-phase-2-benchmark-governance.md](./docs/h3-phase-2-benchmark-governance.md)
* current runner/corpus/comparability rules are summarized in
  [docs/benchmark-governance.md](./docs/benchmark-governance.md)
* seed Markdown-quality comparison records now live in
  [docs/quality-comparisons/README.md](./docs/quality-comparisons/README.md)
  and should be read as sample-scoped quality evidence, not blanket parity
  claims

## Project Positioning

This repository is not aimed at pixel-perfect layout reproduction. The current
engineering priorities are:

* conservative structural recovery
* auditable provenance and debug surfaces
* stable, explainable degradation
* regression-verifiable behavior
* reusable content-processing infrastructure

OCR, cloud services, Document Intelligence-style paths, LLM-style
understanding, and complex visual reasoning are not part of the default
`normal` mainflow contract.

## Documentation

* [Support and Limits](./docs/support-and-limits.md)
* [Full-format H2 Completion](./docs/full-format-h2-completion.md)
* [H3 Phase-1 Performance Summary](./docs/h3-phase-1-summary.md)
* [H3 Phase-2 Benchmark Governance](./docs/h3-phase-2-benchmark-governance.md)
* [Benchmark Governance](./docs/benchmark-governance.md)
* [Architecture](./docs/architecture.md)
* [Development Guide](./docs/development.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Progress Summary](./docs/progress.md)
* [Benchmark Baseline](./docs/benchmark-baseline.md)
* [Benchmark Comparison](./docs/benchmark-comparison.md)
* [Benchmark Comparison Baseline](./docs/benchmark-comparison-baseline.md)
* [Benchmark Batch Design](./docs/benchmark-batch-design.md)
* [Benchmark Batch Profiling](./docs/benchmark-batch-profiling.md)
* [Benchmark H3 Plan](./docs/benchmark-h3-plan.md)
* [Benchmark Corpus Policy](./samples/benchmark/README.md)
* [Sample Coverage](./docs/sample-coverage.md)
* [Acceptance Checklist](./docs/acceptance-checklist.md)
* [Changelog](./CHANGELOG.md)
