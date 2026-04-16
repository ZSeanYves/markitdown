# Architecture

## Overview

The current repository mainflow is:

**docx / pdf / xlsx / pptx / html -> IR -> Markdown**

Core flow:

* `convert/convert/dispatcher.mbt` dispatches files by extension
* `core/ir.mbt` defines the unified Intermediate Representation (IR)
* `core/emitter_markdown.mbt` emits Markdown from IR

For PDF, the `main` branch should no longer be described as using an external text-first path. The normal PDF path has already been **fully replaced by a native structural recovery pipeline**, while OCR is kept as a separate plugin-driven path.

## Repository Layout

### `cli/`

Command-line entry layer.

* `main.mbt`: CLI entry
* `cli_app.mbt`: command orchestration
* `cli_args.mbt`: argument normalization helpers

### `convert/convert/`

Format dispatch layer.

* `dispatcher.mbt`: unified cross-format entry

### `core/`

Shared infrastructure.

* `ir.mbt`: unified IR definitions
* `emitter_markdown.mbt`: Markdown emission
* `tool.mbt`: common helpers
* `errors.mbt`: shared errors

### `convert/docx/`

DOCX parsing and structure recovery.

Main modules include:

* `docx_parser.mbt`
* `docx_document.mbt`
* `docx_table.mbt`
* `docx_styles.mbt`
* `docx_numbering.mbt`
* `docx_package.mbt`
* `docx_rels.mbt`
* `docx_xml.mbt`
* `docx_types.mbt`

### `convert/pdf/`

PDF native mainflow.

The PDF path on `main` should now be described as a native structural recovery chain rather than an external text-first pipeline.

Main modules include:

* `pdf_parser.mbt`
* `pdf_to_ir.mbt`
* `pdf_noise.mbt`
* `pdf_classify.mbt`
* `pdf_convert_lines.mbt`
* `pdf_convert_blocks.mbt`
* `pdf_types.mbt`

If compatibility or auxiliary modules are still retained in the tree, they may also be listed where relevant:

* `pdf_extract.mbt`
* `pdf_select.mbt`
* `pdf_ocr.mbt`
* `pdf_enhance.mbt`

### `doc_parse/pdf_core/`

Low-level PDF parsing and recovery infrastructure.

This layer is worth documenting explicitly because it now matters directly to the normal PDF mainflow. Its responsibilities include:

* low-level character / span / line / block modeling
* text normalization
* visual-line recovery
* same-line / paragraph / edge-noise related rules
* providing higher-level structural inputs to `convert/pdf/`

### `convert/xlsx/`

XLSX parsing pipeline.

Main modules include:

* `xlsx_parser.mbt`
* `xlsx_sheet.mbt`
* `xlsx_styles.mbt`
* `xlsx_datetime.mbt`
* `xlsx_package.mbt`
* `xlsx_shared_strings.mbt`
* `xlsx_xml.mbt`

### `convert/pptx/`

PPTX parsing and layout recovery.

Main modules include:

* `pptx_parser.mbt`
* `pptx_reading_order.mbt`
* `pptx_table_like.mbt`
* `pptx_grouping.mbt`
* `pptx_group_candidates.mbt`
* `pptx_noise.mbt`
* `pptx_slide.mbt`
* `pptx_text.mbt`

Local layout-recovery modules include:

* `pptx_types.mbt`
* `pptx_geom.mbt`
* `pptx_shape_collect.mbt`
* `pptx_layout_base.mbt`
* `pptx_paragraph_meta.mbt`
* `pptx_classify.mbt`

### `convert/html/`

HTML parsing pipeline.

Main modules include:

* `html_parser.mbt`
* `html_dom.mbt`
* `html_to_ir.mbt`
* `html_bytes.mbt`

## IR and Markdown Emitter

The unified IR is the shared structural backbone of the project.

Current major block types include:

* `Heading`
* `Paragraph`
* `ListItem`
* `BlockQuote`
* `CodeBlock`
* `Table`
* `Image`
* `BlankLine`

The Markdown emitter converges final output behavior across formats.
