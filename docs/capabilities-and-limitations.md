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
- `accurate` does not introduce a separate core route family; for core formats without accurate features it falls back explicitly to `balanced`

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

Notable limitations:

- ZIP recursion does not currently recurse into nested archives such as `zip`, `jar`, or `epub`
- ZIP recursion does not currently productize `pdf`, audio, or direct-image OCR as first-class recursive inner documents
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
- `accurate` therefore falls back explicitly to `balanced` for `wav`, `mp3`, and `m4a`

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

Current `accurate` behavior falls into three groups:

1. Dedicated accurate route family:
   `pdf`, direct image OCR
2. Same-route accurate semantic enhancements:
   `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`
3. Explicit fallback to balanced:
   `txt`, `csv`, `tsv`, `srt`, `vtt`, `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `toml`, `html`, `markdown`, `tex`, `rst`, `asciidoc`, `eml`, `zip`, `epub`, `wav`, `mp3`, `m4a`

Current explicit `stream` productization is present for:

- `txt`, `csv`, `tsv`
- `srt`, `vtt`
- `json`, `jsonl`, `ndjson`
- `ipynb`
- `xml`, `yaml`
- `html`, `markdown`
- `eml`
- `zip`, `epub`
- `xlsx`, `odt`, `ods`, `odp`

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

## 5. Regression Coverage Boundary

### 5.1 Checked-in repo-local fixtures

Checked-in contract fixture directories currently exist under `samples/fixtures/contracts/` for:

- core and markup: `txt`, `csv`, `tsv`, `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `toml`, `html`, `markdown`, `tex`, `rst`, `asciidoc`
- office: `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`
- containers: `zip`, `epub`
- PDF / OCR / media: `pdf`, `ocr`, `audio`

Checked-in fixture directories do not currently exist there for:

- `eml`
- `srt`
- `vtt`

### 5.2 Where checked-in goldens are strongest

The strongest checked-in Markdown / asset-style golden coverage is currently around:

- `txt`, `csv`, `tsv`
- `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `toml`
- `html`, `markdown`
- `docx`, `xlsx`, `pptx`
- `zip`, `epub`
- native-text `pdf`
- tiny direct-image OCR samples across all supported image extensions

Notable details:

- `docx`, `pptx`, `epub`, and `zip` also include checked-in asset/result fixtures
- `pdf` includes checked-in native-text goldens plus OCR-oriented sample inputs such as `pdf_ocr_single_page.pdf` and `pdf_ocr_two_page.pdf`
- `ocr` includes checked-in tiny-format goldens for `png/jpg/jpeg/bmp/webp/tif/tiff`, plus larger image inputs without repo-local Markdown goldens

### 5.3 Thinner checked-in sample coverage

The following areas are source-supported, but their checked-in repo-local sample coverage is thinner than the strongest groups above:

- `odt`, `ods`, `odp` currently have checked-in input fixtures but no checked-in Markdown goldens in `samples/fixtures/contracts/`
- `tex`, `rst`, and `asciidoc` currently have checked-in input fixtures but no checked-in Markdown goldens there
- `audio` currently has checked-in input fixtures, while most runtime confidence comes from MoonBit runtime tests rather than checked-in Markdown golden outputs
- `srt` and `vtt` are parser-tested, but do not currently have checked-in `samples/fixtures/contracts/srt|vtt/` directories
- `eml` is registry-wired and integrated into the recursive parsing surface, but does not currently have a checked-in `samples/fixtures/contracts/eml/` directory

### 5.4 Boundary / malformed fixtures

Checked-in malformed and fail-closed boundary fixtures under `samples/fixtures/boundaries/` are currently concentrated in:

- `epub`

### 5.5 External regression entry points

The repository also ships external regression entry points under [samples/README.md](../samples/README.md), but the formal corpora are not vendored here and live in `markitdown-quality-lab/`.

The external main-regression runner is currently wired for:

- `csv`, `tsv`, `txt`
- `srt`, `vtt`
- `json`, `jsonl`, `ndjson`, `ipynb`
- `xml`, `yaml`, `toml`
- `html`, `markdown`, `eml`
- `tex`, `rst`, `asciidoc`
- `zip`, `epub`
- `odt`, `ods`, `odp`
- `docx`, `xlsx`, `pptx`
- `pdf`
- `wav`, `mp3`, `m4a`
- `ocr`

Because those corpora are external, checked-in repo-local fixtures remain the most reliable indicator of what this repository itself currently carries as sample coverage.

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
