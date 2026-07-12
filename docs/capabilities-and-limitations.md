# Capability Boundaries and Limitations

`markitdown-mb` ships as one main binary with one formal product path:

```text
input -> detect -> probe -> planner -> parse -> pipeline -> render
```

The public support surface is grouped by internal capability layer:

- `Core`
- `Office`
- `Containers`
- `Media`
- `PdfOcr`

This document is the public support boundary. It distinguishes three things:

- what is wired into the current source tree and registry
- what is productized at the mode / route level
- what is backed by checked-in regression fixtures versus external regression entry points

Internal implementation details may evolve, but capability grouping, fail-closed behavior, and route-mode boundaries should stay aligned with the code and the regression surface.

## 1. Product Boundary

This implementation prioritizes:

- one formal product path
- explicit detection, probing, and route selection
- typed diagnostics and provenance
- fail-closed behavior instead of silent fallback

This project is not trying to be:

- a browser-grade layout engine
- an editor-grade round-trip restoration stack
- a hidden multi-product CLI with per-format side entrances

## 2. Capability Groups

### 2.1 Core

Source-wired formats:

- plain text: `txt`
- subtitles: `srt`, `vtt`
- delimited text: `csv`, `tsv`
- structured text: `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `yml`, `toml`
- web and markup: `html`, `htm`, `markdown`, `md`, `rst`, `adoc`, `asciidoc`, `tex`, `latex`
- mail: `eml`

Important notes:

- `txt`, `csv`, `tsv`, `srt`, `vtt`, `jsonl`, and `ndjson` are canonical `streaming_event` formats.
- `json`, `ipynb`, `xml`, `yaml`, `toml`, `html`, `markdown`, `tex`, `rst`, and `asciidoc` stay on the typed structured-text path and still converge back to the unified pipeline.
- `eml` is productized as a MIME-part-oriented `block_streaming` format with recursive child dispatch guarded by the root registry.
- The user-facing label `msg` is currently accepted as an alias to the mail parser. It should not be read as a distinct native Outlook `.msg` binary stack.

Mode boundary:

- explicit `stream` is productized for `txt`, `csv`, `tsv`, `srt`, `vtt`, `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `html`, `markdown`, and `eml`
- `toml`, `tex`, `rst`, and `asciidoc` currently stay on canonical structured routes and do not expose a distinct explicit stream route
- core formats without declared accurate features reject `accurate` instead of falling back to `balanced`

### 2.2 Office

Source-wired formats:

- OOXML: `docx`, `xlsx`, `pptx`
- ODF: `odt`, `ods`, `odp`

Current product behavior:

- all office formats are package-based and probe-first
- parser execution is expected to reuse typed probe artifacts
- missing or mismatched heavy-format artifacts fail closed

Mode boundary:

- `xlsx`, `odt`, `ods`, and `odp` expose productized explicit stream / large-route block forms
- `docx` and `pptx` remain canonical `package_single_pass` routes without a distinct explicit stream route
- `accurate` is productized here as same-route semantic enhancement rather than a new route family

Current accurate semantic surface includes:

- `docx`: textbox lowering, alternate-content restore, notes appendix
- `xlsx`: hidden sheets, hidden rows, merged spans
- `pptx`: reading order, group summary, hidden-slide semantics, notes appendix
- `odt`: richer notes and comments appendix
- `ods`: hidden sheets, hidden rows, covered-cell spans
- `odp`: notes appendix and slide summary

### 2.3 Containers

Source-wired formats:

- `zip`
- `epub`

Current product behavior:

- both stay on the canonical product path
- `zip` is productized as `container_recursive`
- `epub` has a canonical `package_single_pass` route and an explicit container-recursive stream route
- local assets may be materialized only at the output boundary
- remote fetch is a non-goal

Current ZIP recursive inner-document scope is intentionally limited. It currently covers:

- `txt`, `csv`, `tsv`
- `srt`, `vtt`
- `json`, `jsonl`, `ndjson`, `ipynb`
- `xml`, `yaml`, `toml`
- `html`, `markdown`
- `tex`, `rst`, `asciidoc`
- `eml`
- `docx`, `xlsx`, `pptx`
- `odt`, `ods`, `odp`
- native balanced `pdf`
- `wav`, `mp3`, `m4a`
- standalone `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

Notable limitations:

- ZIP recursion does not currently recurse into nested archives such as `zip`, `jar`, or `epub`
- document-referenced images remain assets and are not OCR inputs
- unreferenced standalone OCR-capable images use the same balance Tesseract
  provider as top-level image input and always preserve the original asset
- standalone GIF/SVG-like assets may be exported without OCR
- container parsing remains bounded and guarded by root-registry dispatch, resource limits, and output-path safety rules

### 2.4 Media

Source-wired formats:

- `wav`
- `mp3`
- `m4a`

Current product behavior:

- media support is intentionally narrow and transcript-first
- the canonical route is `media_pipeline`
- the current runtime contract is local-backend oriented: Vosk-based transcription plus `ffmpeg` normalization when compressed audio requires it
- missing runtime pieces fail closed and are surfaced explicitly in diagnostics

Mode boundary:

- there is no separate media-specific `accurate` route family today
- there is no productized explicit `stream` route for audio today
- `accurate` is rejected for `wav`, `mp3`, and `m4a`

### 2.5 PdfOcr

Source-wired formats:

- `pdf`
- direct image OCR: `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

Current product behavior:

- `pdf` in `balanced` uses the native-text `page_single_pass` route
- `pdf` in `accurate` uses the `layout_two_stage` high-fidelity route
- direct image inputs are productized on `layout_two_stage`
- OCR and rasterization dependencies are explicit and fail closed when unavailable

Important route boundary:

- scanned-like PDFs do not silently OCR on the default balanced route
- balanced scanned-like PDFs are expected to fail closed rather than pretend that native-text extraction succeeded
- PDF OCR remains part of the `accurate` PDF contract
- direct image OCR remains part of the formal main product surface rather than a debug-only side path

Provider/runtime notes:

- direct image OCR defaults to a Tesseract-targeted balanced path and a PaddleOCR-targeted accurate path
- PDF accurate uses the PDF-specific accurate OCR/runtime contract rather than the native PDF parser path

## 3. Probe Boundary

Unified probe templates are:

- `Exempt`
- `StructuredTextProbe`
- `PackageContainerProbe`
- `PagedMediaProbe`

Probe-exempt light formats are:

- `txt`
- `csv`
- `tsv`
- `jsonl`
- `ndjson`
- `srt`
- `vtt`

Structured-text probe formats currently include:

- `json`, `xml`, `yaml`, `toml`
- `markdown`, `html`, `ipynb`
- `tex`, `rst`, `asciidoc`
- `eml`
- `wav`, `mp3`, `m4a`

Package/container probe formats currently include:

- `docx`, `pptx`, `xlsx`
- `odt`, `ods`, `odp`
- `epub`, `zip`

Paged/media probe formats currently include:

- `pdf`
- `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

Typed probe artifact reuse is a checked contract for heavy-route parsing, especially for:

- `html`
- `ipynb`
- `docx`, `pptx`, `xlsx`
- `odt`, `ods`, `odp`
- `epub`, `zip`
- `pdf`

## 4. Mode and Route Boundary

Public product modes remain:

- `balanced`
- `accurate`
- `stream`

Support is intentionally non-universal.

Current `accurate` support falls into two groups:

1. Dedicated accurate route family:
   `pdf`, direct image OCR
2. Same-route accurate semantic enhancements:
   `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`

All other formats reject `accurate` with a non-zero exit status. Unsupported
mode requests never fall back to `balance`.

Current explicit `stream` productization is present for:

- `txt`, `csv`, `tsv`
- `srt`, `vtt`
- `json`, `jsonl`, `ndjson`
- `ipynb`
- `xml`, `yaml`
- `html`, `markdown`
- `eml`
- `epub`
- `xlsx`, `odt`, `ods`, `odp`

Formats outside this list reject `stream` with a non-zero exit status.

Formats that currently do not expose a distinct explicit `stream` route include:

- `toml`
- `tex`, `rst`, `asciidoc`
- `docx`, `pptx`
- `pdf`
- `wav`, `mp3`, `m4a`
- `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`

Across all groups:

- same-mode adaptation is allowed only when the planner records the reason explicitly
- heavy-format parser code must not privately choose a different route
- renderer selection (`Markdown`, `RagJson`, `DebugJson`) does not change route ownership

## 5. Regression Evidence Boundary

Evidence is intentionally split rather than summarized by fragile hard-coded
fixture counts:

1. MoonBit whitebox/blackbox tests cover parser branches, malformed inputs,
   resource limits, route policy, lowering, and rendering.
2. `samples/fixtures/contracts/` carries small deterministic repository-owned
   CLI and golden contracts, including asset-byte checks.
3. `markitdown-quality-lab/external_main_process/` carries the formal main
   balance corpus.
4. `external_quality/` carries larger real-world inputs with source catalogs,
   licenses, hashes, provenance, and semantic signals.
5. `external_accurate/` is a functional accurate gate only.
6. `external_bench/` and `performance_baselines/` carry benchmark rows and
   approved platform baselines.

The executable manifests and latest CI artifacts are the source of truth for
row counts. See [samples/README.md](../samples/README.md) and
[tools/regression/README.md](../tools/regression/README.md).

## 6. Current Non-goals and Limitations

- unknown formats fail closed
- there is no public browser-grade layout engine
- there is no editor-grade round-trip restoration contract
- there is no hidden alternate product path for unsupported formats
- there is no runtime plugin-style capability expansion
- ZIP recursion does not currently act as a generic wrapper around every supported top-level format
- balanced PDF does not silently upgrade scanned-like input into OCR
- audio remains local-backend oriented rather than a cloud-provider abstraction layer
- `msg` is not a distinct native Outlook-binary capability surface

## 7. Dependency Summary

For system tools and optional local runtimes, see [environment-dependencies.md](./environment-dependencies.md).

For external regression entry points and corpus layout, see [samples/README.md](../samples/README.md).
