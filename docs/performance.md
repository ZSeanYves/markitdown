# Performance

This page is the current performance source of truth for the repository.

For benchmark commands and artifact layout, use
[docs/benchmarking.md](./benchmarking.md).

## Overview

Current performance reporting uses three separate layers:

### 1. `doc_parse` library path

* direct package API
* no CLI startup
* no product emit / metadata / assets
* PDF direct library attribution deferred

### 2. same-process product path

* warm benchmark runner
* normal `markitdown` product path
* excludes `startup_probe`
* includes `dispatch / parse / convert / emit / metadata / assets`
* covers `txt/json/yaml/csv/xlsx/html/docx/pptx/pdf`

### 3. cold CLI / process-per-file

* includes process startup
* `startup_probe` is tracked separately
* batch / embedded mode amortizes it

## Current Baseline

Current checked first-pass corpus shows no obvious `>10ms` rows in `doc_parse`
library path or same-process product path.

### `doc_parse` library path

* `yaml_large / parse`: `5.879 ms`
* `docx_link_heavy / parse`: `4.984 ms`
* `json_large / parse`: `2.815 ms`
* `xlsx_formula_heavy_missing_cache / parse`: `2.690 ms`
* `markdown_large / scan`: `2.176 ms`
* `txt_large / parse`: `1.852 ms`

### same-process product path

* `startup_probe`: `9.085 ms`
* `txt_large total`: `5.727 ms`
* `docx_image_alt_title_basic total`: `3.637 ms`
* `pptx_image_alt_title_basic total`: `2.038 ms`
* `pdf_metadata_uri_link total`: `1.061 ms`
* `html_figure_figcaption_basic total`: `1.050 ms`
* `xlsx_metadata_formula_or_merged_policy total`: `1.023 ms`

Figures are local observations, not cross-machine guarantees.
Cold CLI startup is tracked separately.

## Attribution Coverage

* library harness:
  `text/csv/tsv/json/yaml/xml/html/markdown/zip/ooxml/epub/xlsx/docx/pptx`
* product path:
  `txt/json/yaml/csv/xlsx/html/docx/pptx/pdf`
* PDF direct library attribution is still deferred
* PDF caveat:
  native text-PDF only; OCR/scanned excluded; fallback path not exercised by
  the default corpus

## Completed Optimization Passes

* XLSX formula-heavy context reuse
* DOCX body/text-box/inline scan cleanup
* YAML line preprocessing cleanup
* Text/JSON/Markdown large-input optimization
* TXT product-path normalized fast path / cleanup skip / emitter tail fast path
* rich-format product attribution
* PDF native text-PDF product attribution

## Remaining Performance Work

* `doc_parse/pdf` direct async library attribution
* PDF fallback/scanned/OCR attribution
* cold-start / process-per-file strategy
* batch amortization reporting
* heavier `docx/pptx/pdf` samples
* optional perf regression guard
* TXT literal wrap if large TXT becomes priority
* metadata/assets if they rise

## How To Run

See [docs/benchmarking.md](./benchmarking.md).
