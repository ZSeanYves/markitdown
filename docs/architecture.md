# Architecture

This page describes the current shipping architecture of `markitdown-mb`.
It is a product-state map, not a migration log.

## Runtime Flow

The normal conversion path is:

```text
input -> dispatcher -> format converter -> unified IR -> Markdown / assets / metadata
```

The design favors conservative, explainable extraction over visual
reconstruction. Format converters lower source facts into a shared document IR;
the Markdown emitter and metadata sidecar then operate on that shared model.

## Repository Boundaries

The main repository contains:

* runtime packages
* MoonBit tests
* repo-local samples
* public validation, quality, benchmark, and release helper entrypoints

`markitdown-quality-lab/` is optional external infrastructure. It may contain
full quality rows, larger external payloads, OCR artifacts, and offline PDF
layout work. It is not a runtime dependency, and it must not be committed into
the main repository.

## Package Responsibilities

| Area | Responsibility |
| --- | --- |
| `core` | document IR, metadata model, Markdown emitter, shared pure helpers |
| `cli`, `cli_common`, `cli_support` | product entrypoint, argument parsing, component delegation, path/runtime glue |
| `convert/convert` | format dispatch into converter packages |
| `convert/*` | source-format to core-IR policy, assets, metadata, warnings, and conservative fallback behavior |
| `doc_parse/*` | source-native parser/model/inspect foundations |
| `convert/vision` | image OCR and OCR page/layout model implementation path |
| `convert/pdf_debug`, `convert/pdf_layout` | explicit debug/report/dev surfaces, not normal product entrypoints |
| `doc_parse/pdf/vendor/mbtpdf` | trimmed PDF support subtree needed by the current native PDF path |

Current rules:

* `core` stays CLI-free.
* Parser packages provide source facts.
* Converter packages own product policy and IR lowering.
* Debug, layout, and preview tools stay explicit developer surfaces.
* The normal runtime does not load quality-lab assets, model JSON, Python
  runners, or OCR providers.

## Unified IR

The shared IR is the contract between converters and emitters. It carries:

* block and inline structure
* links
* assets
* origin and metadata sidecar information
* document-level note definitions when a converter can resolve note bodies
* marker-only note references when a source exposes a reference but not a safe
  body association

Converters should lower reliable source semantics into the IR instead of
assembling format-specific Markdown strings. Ambiguous features should degrade
to plain text, marker-only output, warnings, or explicit unsupported boundaries.

## DOCX Runtime

DOCX now uses the v2 runtime architecture. The old v1 runtime scanner path has
been removed.

Current DOCX shape:

```text
OOXML package -> DOCX source -> DOCX normalized model -> convert/docx lowering -> core IR
```

The architecture contract is archived at
[docs/archive/docx-architecture.md](./archive/docx-architecture.md). That file
is kept as a contract for future Office model rewrites; it is not a separate
runtime path.

## Format Runtime Boundaries

Office formats share OOXML package helpers but keep format-specific semantics:

* DOCX uses the v2 source/model/lowering boundary.
* PPTX owns slide, note, chart, image, table, and reading-order policy.
* XLSX owns workbook/sheet/cell/formula policy without becoming a spreadsheet
  recalculation engine.

PDF remains a native text/assets/metadata extraction path with narrow
deterministic layout cleanup. Report-only scan diagnostics and layout tools do
not change normal PDF output.

ZIP and EPUB use archive/package traversal plus nested dispatch where supported,
while keeping path safety and asset remapping explicit.

## OCR Boundary

Current shipped OCR support is image OCR through the main CLI. It uses
`convert/vision` and depends on a local `tesseract` installation plus language
data.

Normal document conversion remains no-OCR. PDF OCR is not wired in the shipped
path. Scan diagnostics may report that OCR could be useful, but they do not run
OCR and do not change conversion output.

## Product And Developer Entry Points

Product-facing:

* `cli`
* bundled `pdf` component behind PDF conversion
* bundled `zip` component behind ZIP conversion

Developer/reporting:

* `debug`
* `bench`
* `doc_parse/pdf/layout_model_tool`
* `convert/vision/tsv_preview_tool`
* helper scripts under `samples/helpers/`

See also:

* [Supported formats](./supported-formats.md)
* [Quality and release](./quality-and-release.md)
* [Performance](./performance.md)
* [Roadmap](./roadmap.md)
