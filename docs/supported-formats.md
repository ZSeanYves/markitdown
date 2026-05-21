# Supported Formats

This page is the current support and limits contract for the normal product
path.

It describes what the shipped runtime is meant to do, what it explicitly does
not do, and how to read support claims conservatively.

## Scope

Current goals:

* recover useful Markdown structure from common document formats
* emit assets and metadata sidecars where explicitly supported
* degrade conservatively on ambiguous behavior
* fail closed on unsupported or unsafe inputs

Current non-goals for the default path:

* browser-grade rendering
* hidden OCR fallback
* visual page reconstruction
* remote fetch
* DRM handling
* model-backed runtime classification

## Format Matrix

| Format | Current support | Important limits |
| --- | --- | --- |
| DOCX | headings, paragraphs, links, notes, comments, images, tables, text boxes | not a Word layout engine |
| PPTX | titles, bullets, links, notes, tables, grouped content, images | not a PowerPoint visual layout engine |
| XLSX | workbook/sheet/cell lowering, typed cells, conservative formula handling | no full spreadsheet recalculation engine |
| PDF | native text-PDF extraction, links, images, annotations, narrow layout cleanup | OCR explicit-only; no page-raster/runtime model path |
| ZIP | supported-entry dispatch, assets, metadata, origin tracking | no recursive archive explosion |
| EPUB | OPF/spine/nav/NCX/XHTML chapter lowering | unsupported media stays explicit |
| HTML / HTM | safe tolerant parsing and structural lowering | no JS, CSS layout, or browser engine |
| CSV / TSV | conservative table lowering and dialect handling | not an arbitrary spreadsheet model |
| JSON / YAML | source-preserving or conservative structured lowering | malformed input fails closed |
| XML | conservative source-preserving and structure-aware lowering | no schema-driven semantic reconstruction |
| TXT / Markdown | literal or conservative structural handling | no speculative semantic upgrade |

## Cross-Cutting Rules

Across the normal product path:

* Markdown is the primary reading output
* assets and metadata are companion engineering outputs
* `--with-metadata` is opt-in
* stdout mode emits Markdown only
* ambiguous features should degrade conservatively

## PDF And OCR Limits

Current PDF/OCR rules:

* the normal path targets native text PDFs
* OCR remains explicit-only
* encrypted PDFs fail closed
* image/scanned PDFs are not silently upgraded into OCR
* default layout cleanup stays narrow and deterministic

Still out of scope for the normal path:

* page-raster inference
* provider-backed runtime model loading
* broad offline-model-driven heading or receipt classification
* hidden OCR promotion

See [pdf.md](./pdf.md) for the detailed PDF text/layout/OCR boundary.

## Quality-Lab Relation

The main repo remains self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh --manifest-only`
* public-only quality validation

The optional repo-root quality-lab is used for:

* full quality rows
* external corpus payloads
* offline PDF layout training/eval/model/report assets

## How To Read Support Claims

Support claims in this repository are:

* local validation-backed
* sample-scoped
* format-scoped
* boundary-aware

They are not:

* blanket compatibility guarantees
* universal completeness percentages
* claims that every edge case is covered

For validation workflow, use [quality-and-release.md](./quality-and-release.md).
For sample-scoped performance interpretation, use [performance.md](./performance.md).
