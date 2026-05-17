# Performance

This page is the current performance source of truth for the repository.

For benchmark commands and artifact layout, use
[docs/benchmarking.md](./benchmarking.md).

## Performance Layers

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
* focused cold-start CLI cases are benchmarked separately from same-process
  product totals
* the cold-start suite records both external wall-clock timing and a hidden
  main-internal startup profile

## Latest Local Baseline

Current checked first-pass corpus shows no obvious `>10ms` rows in `doc_parse`
library path or same-process product path.

### `doc_parse` library path

* `yaml_large / parse`: `5.945 ms`
* `docx_link_heavy / parse`: `5.029 ms`
* `json_large / parse`: `2.797 ms`
* `xlsx_formula_heavy_missing_cache / parse`: `2.650 ms`
* `csv_large / parse`: `2.331 ms`
* `markdown_large / scan`: `2.187 ms`
* `txt_large / parse`: `1.841 ms`

### same-process product path

* `startup_probe`: `8.815 ms`
* `txt_large total`: `5.761 ms`
* `docx_image_alt_title_basic total`: `3.990 ms`
* `pptx_image_alt_title_basic total`: `2.547 ms`
* `html_figure_figcaption_basic total`: `1.605 ms`
* `pdf_metadata_uri_link total`: `1.105 ms`
* `xlsx_metadata_formula_or_merged_policy total`: `1.029 ms`

### cold CLI / process-per-file

* debug `noop`: external `8.894 ms avg`, `8.812 ms p50`, `9.324 ms p95`;
  main-internal `0.028 ms avg`; estimated process/runtime `8.866 ms`
* debug `--help`: external `8.800 ms avg`, `8.775 ms p50`, `9.111 ms p95`;
  main-internal `0.058 ms avg`; estimated process/runtime `8.742 ms`
* debug minimal TXT conversion: external `9.311 ms avg`, `9.359 ms p50`,
  `9.664 ms p95`; main-internal `0.267 ms avg`; estimated process/runtime
  `9.044 ms`
* release `noop`: external `9.029 ms avg`, `9.014 ms p50`, `9.415 ms p95`;
  main-internal `0.018 ms avg`; estimated process/runtime `9.011 ms`
* release `--help`: external `8.696 ms avg`, `8.697 ms p50`, `8.828 ms p95`;
  main-internal `0.039 ms avg`; estimated process/runtime `8.657 ms`
* release minimal TXT conversion: external `9.209 ms avg`, `9.212 ms p50`,
  `9.616 ms p95`; main-internal `0.234 ms avg`; estimated process/runtime
  `8.974 ms`
* `--version` is now a supported CLI contract, but the checked cold-start
  suite still focuses on `noop`, `--help`, and one minimal TXT conversion
  unless explicitly extended

Figures are local observations, not cross-machine guarantees.
Cold CLI startup is tracked separately.

## Current Native Build Guardrail

Current checked local clean-build snapshot:

* `cli build`: `62.73s`
* `pdf build`: `67.42s`
* `zip build`: `61.88s`
* `ocr build`: `53.14s`
* `cli.exe`: `3649640` bytes
* `pdf.exe`: `4278680` bytes
* `zip.exe`: `3442056` bytes
* `ocr.exe`: `1644328` bytes
* `cli.c`: `394425` lines
* `pdf.c`: `442901` lines
* `zip.c`: `370607` lines
* `ocr.c`: `154425` lines
* `cli mbtpdf count`: `0`

These numbers are a local clean native build snapshot, not a cross-machine
guarantee.

## Build Guardrail Snapshot

The repository also tracks build-size/build-time guardrails for the split
product surface.

Current interpretation:

* main `cli` stays out of vendored `mbtpdf` and should remain `mbtpdf=0`
* heavy native text-PDF cost stays behind bundled `pdf`
* `zip` uses `convert/zip_worker` and delegates embedded PDF entries to `pdf`
  so it does not directly absorb the full PDF closure
* a direct in-process PDF/ZIP reintegration experiment pushed `cli` to about
  `30M / 653k` generated-C lines and about `24.6s` cold rebuild time on the
  recent Ubuntu audit runner, so the repository keeps the bundled-component
  design as an explicit performance guardrail

## Current Overlap-Only Compare Timing

The repository can also run an overlap-only compare suite against Microsoft
MarkItDown when a pinned Python runner is available locally.

Current checked local run:

* date: `2026-05-17`
* machine: `macOS 15.3`, `arm64`
* competitor: `Microsoft MarkItDown 0.1.5`
* corpus: `samples/benchmark/compare_corpus.tsv`
* rows: `47` overlap samples per runner
* `markitdown-mb` average sample time: `11.064 ms`
* `markitdown-python` average sample time: `435.660 ms`
* observed ratio on this overlap corpus: Python runner about `39.4x` slower

Interpret this conservatively:

* this is timing only, not a blanket Markdown-quality score
* this excludes OCR, scanned-PDF, metadata semantics, and assets semantics
* this is sample-scoped and corpus-scoped, not a universal product multiple

## Cold CLI Startup Attribution Closure

Current local cold-start observations place `noop`, `--help`, and one minimal
TXT conversion in the same `~8.7-9.3 ms` external band, which means fixed
startup/front-end cost dominates over parser/converter work in the
process-per-file path.

Hidden main-internal startup profiling currently shows:

* `noop_return_ready`: about `0.018-0.028 ms`
* `help_render_ready`: about `0.039-0.058 ms`
* `minimal_dispatch_ready`: about `0.042 ms` release / `0.064 ms` debug
* full minimal TXT branch completion: about `0.234-0.267 ms`

That leaves roughly `8.7-9.0 ms` in estimated process/runtime cost for the
checked native CLI runs. The current attribution closure conclusion is:

* source-level main-path startup work now has limited remaining headroom
* same-process product-path totals still exclude `startup_probe`
* future cold-start improvement should focus on batch mode, embedded usage,
  warm runners, release packaging, or runtime-level work rather than parser
  semantics

## Attribution Coverage

* library harness:
  `text/csv/tsv/json/yaml/xml/html/markdown/zip/ooxml/epub/xlsx/docx/pptx`
* product path:
  `txt/json/yaml/csv/xlsx/html/docx/pptx/pdf`
* cold-start path:
  debug/release `noop`, `--help`, and one minimal TXT conversion, with hidden
  main-internal startup profiling recorded separately
* PDF direct library attribution is still deferred
* PDF caveat:
  native text-PDF product attribution only; direct async `doc_parse/pdf`
  library attribution deferred; OCR/scanned/fallback excluded by the default
  checked corpus
* PDF layout classifier training/evaluation scripts under
  `samples/pdf_layout_classifier` are developer tooling only and are not part
  of the default product-path performance contract

## Completed Optimization Passes

* XLSX formula-heavy context reuse
* DOCX body/text-box/inline scan cleanup
* YAML line preprocessing cleanup
* Text/JSON/Markdown large-input optimization
* TXT product-path normalized fast path / cleanup skip / emitter tail fast path
* rich-format product attribution
* PDF native text-PDF product attribution
* cold CLI startup attribution closure

## Remaining Performance Work

* `doc_parse/pdf` direct async library attribution
* PDF fallback/scanned/OCR attribution
* batch / embedded startup amortization reporting
* embedded or warm-runner strategy for startup-sensitive usage
* release packaging or runtime-level cold-start work if process-per-file usage
  becomes a higher priority
* heavier `docx/pptx/pdf` samples
* optional perf regression guard
* TXT literal wrap if large TXT becomes priority
* metadata/assets if they rise

## How To Run

See [docs/benchmarking.md](./benchmarking.md).
