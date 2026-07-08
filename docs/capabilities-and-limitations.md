# Capability Boundaries and Limitations

`markitdown-mb` now runs on a unified product path:

```text
input -> parser -> pipeline -> render
```

That unified path gives the project a few important product properties:

- All formal formats go through one main chain instead of several historical branches.
- Output is not only Markdown. We also preserve richer semantics, diagnostics, source refs, and provenance facts.
- Benchmarks, main regression, and quality regression all measure the same product path.
- Unsupported capabilities fail closed instead of hiding boundaries behind silent fallback.

This document answers two practical questions:

1. Which formats are formally supported today.
2. Which capabilities are formally available, which are limited, and which are intentionally not promised.

For system packages, external tools, and regression dependencies, see [environment-dependencies.md](./environment-dependencies.md).

## 1. Product Boundary

The project is inspired by Microsoft's `MarkItDown`: convert common document formats into stable, consumable Markdown.

This implementation is not a line-by-line clone. It is a MoonBit-first, engineering-oriented implementation that prioritizes:

- one formal product path
- richer intermediate semantics
- stronger provenance, route fidelity, and benchmark trust gates
- a clearer support matrix and clearer fail-closed boundaries

This project is not trying to be:

- a full editor-grade semantic restoration stack for every format
- a layout-intelligence-heavy AI platform by default
- a collection of per-format shortcuts optimized for a few nice-looking samples

It is trying to be:

- a maintainable long-term open-source conversion project
- strong under complex formats and engineering-scale workloads
- traceable and honest about route selection and capability boundaries

## 2. Formally Supported Main CLI Inputs

The main CLI currently supports these input families:

| Format family | Extensions / entry | Formal status |
| --- | --- | --- |
| Plain text | `txt` | formally supported |
| Subtitle text | `srt`, `vtt` | formally supported |
| Delimited text | `csv`, `tsv` | formally supported |
| Structured text | `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `yml`, `toml` | formally supported |
| Web and markup | `html`, `htm`, `markdown`, `md`, `rst`, `adoc`, `asciidoc`, `tex`, `latex` | formally supported |
| Mail | `eml`, `msg` | formally supported |
| Containers | `zip`, `epub` | formally supported |
| Office | `odt`, `ods`, `odp`, `docx`, `xlsx`, `pptx` | formally supported |
| PDF | `pdf` | formally supported; default is native-text, `--pdf-ocr explicit|auto-scanned` enables balanced PDF OCR, `--accurate` defaults to `auto-scanned` and can enter accurate PDF OCR on scanned-like pages |
| Audio | `wav`, `mp3`, `m4a` | formally supported through an optional local transcript backend; current path is a narrow transcript-only media pipeline |
| Direct image OCR | `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff` | formally supported |

These inputs are not part of the default formal matrix:

- scanned or image-based PDF when neither `--pdf-ocr` nor `--accurate` is enabled
- `mp4`, video, streaming audio, subtitle sidecars as primary input, recursive audio dispatch inside containers
- any format not listed above

## 3. Capability Overview

| Format | Current main path | Formally supported today | Current limitation or non-goal |
| --- | --- | --- | --- |
| `txt` | `streaming_event` | paragraph output, basic text output, RAG, debug, benchmark | naturally limited semantics |
| `srt` / `vtt` | `streaming_event` | cue time ranges, multiline captions, first-class `SourceRef.time_start/time_end`, controlled WebVTT degrade, RAG, debug | no player-grade style or layout execution |
| `csv` / `tsv` | `streaming_event` | table-style output, RAG, debug, benchmark | no workbook-grade formula or style semantics |
| `json` | `dom_ast_model`, or `streaming_event` when large or explicitly streamed | structured output for small and medium inputs, streaming for large inputs, RAG, debug | not a full JSON editor semantic model |
| `jsonl` / `ndjson` | `streaming_event` | line-delimited record output, RAG, debug | no full document-tree semantics |
| `ipynb` | `dom_ast_model`, or `block_streaming` when large or explicitly streamed | markdown/code/raw cells, typed outputs, multi-MIME selection, RAG, debug, assets, source refs | no notebook execution or widget runtime recovery |
| `toml` | `dom_ast_model` | tables, key-values, array-of-tables, RAG, debug | no comment-preserving or editor-grade round-trip promise |
| `xml` | `dom_ast_model`, or `streaming_event` when large | structured output, streaming path, RAG, debug | no full schema-aware semantics |
| `yaml` | `dom_ast_model`, or `streaming_event` when large | mapping/list/table-like output, RAG, debug | no promise to cover every YAML dialect |
| `markdown` | `dom_ast_model`, or `block_streaming` when large or explicitly streamed | Markdown read path, frontmatter passthrough, debug, RAG | not a full Markdown editor or AST toolkit |
| `rst` / `asciidoc` / `tex` | `dom_ast_model` | typed semantic inventory, heading/paragraph/list/code/common table/common link/common boundary handling, RAG, debug | no full dialect execution or full editor semantics |
| `html` | `dom_ast_model`, or `block_streaming(HtmlTokenStructure)` when large or explicitly streamed | content-root selection, boilerplate suppression, headings, paragraphs, lists, tables, images, links, RAG, assets | no browser-grade visual layout restoration |
| `eml` | `block_streaming(Message)` | header summary, body selection, controlled `text/html`, nested message support, typed attachment dispatch, inline image assets, RAG, debug | no unbounded recursive attachment expansion or full mail-client behavior restoration |
| `zip` | `container_recursive` | container scan, path safety, child document dispatch, assets | no arbitrary binary interpretation |
| `epub` | `package_single_pass`, or `container_recursive` when explicitly streamed | OPF/spine order, chapter dispatch, local resource materialization, RAG | no remote fetch, no reader-grade runtime semantics |
| `odt` | `package_single_pass`, or `block_streaming` when explicitly streamed | main content, tables, images, hyperlinks, footnotes/endnotes, comment appendix, RAG, debug source refs, assets | no full ODF style round-trip, revision recovery, or macro execution |
| `ods` | `package_single_pass`, or `block_streaming` when explicitly streamed | sheet reading, table-like output, RAG, debug source refs, hidden-sheet visibility metrics | no formula execution, no full style or embedded-object recovery |
| `odp` | `package_single_pass`, or `block_streaming` when explicitly streamed | slide order, text blocks, tables, images, notes, RAG, debug source refs, assets | no full visual layout reconstruction, animation execution, or style round-trip |
| `docx` | `package_single_pass` | main Office blocks, links, images, debug source refs, RAG | not a full Word advanced-layout semantic stack |
| `xlsx` | `package_single_pass`, or `block_streaming` when large or explicitly streamed | sheet reading, table-like output, hidden-sheet policy, cached formula values, debug | no Excel calculation engine |
| `pptx` | `package_single_pass` | slide order, lists, images, speaker notes, hidden-slide policy, debug | no full slide-layout reconstruction |
| `pdf` | `page_single_pass` or `layout_two_stage` | native-text extraction, balanced PDF OCR, accurate PDF OCR, cleanup hooks, optional table signals, RAG, debug | OCR routes do not currently promise deep layout intelligence or complex-table reconstruction |
| direct image OCR | `layout_two_stage` or image OCR parser route | text extraction, OCR diagnostics, provenance, provider-aware fallback from accurate to balanced when accurate dependencies are missing | quality depends heavily on the OCR provider and image complexity |
| `wav` / `mp3` / `m4a` | `media_pipeline` | transcript output, timestamps, Markdown, RAG, debug, provenance through a local optional backend | no diarization, no speaker separation promise, no dedicated accurate enhancement line, and compressed-audio support may require local normalization |

## 3.1 Current Maturity Audit

We currently use four maturity levels:

- `usable`: product path is available, but semantics, quality confidence, or coverage depth are still limited
- `mature`: canonical path is stable and regression coverage is strong enough for long-term maintenance
- `strong mature`: mature plus stronger route, accurate, or stress confidence for complex formats
- `experimental`: not yet part of the formal long-term product promise

There is no formally supported input family that is publicly labeled `experimental`. Experimental status today applies mainly to some scoped `pdf --accurate` enhancements; the audio line is now intentionally narrow and optional rather than broad and experimental.

| Format | Current level | Summary |
| --- | --- | --- |
| `txt` | `mature` | stable lightweight `streaming_event` path |
| `srt` / `vtt` | `mature` | stable cue timing and source refs |
| `csv` / `tsv` | `mature` | stable table-style streaming path |
| `json` | `strong mature` | stable DOM and streaming routes with strong provenance confidence |
| `jsonl` / `ndjson` | `mature` | clear line-delimited record path |
| `ipynb` | `mature` | typed cells, outputs, assets, and source refs are stable |
| `toml` | `mature` | stable canonical DOM path and malformed-input degrade behavior |
| `xml` | `mature` | stable DOM and streaming paths |
| `yaml` | `mature` | stable mapping/list/table-like output path |
| `markdown` | `mature` | stable read path, frontmatter, debug, RAG, and stream fallback |
| `rst` / `asciidoc` / `tex` | `mature` | shared canonical text-markup path with dedicated contract coverage |
| `html` | `strong mature` | strong content-root selection, boilerplate suppression, assets, and quality regression confidence |
| `eml` | `mature` | stable message/body/attachment path |
| `zip` | `mature` | stable container recursion and path safety |
| `epub` | `mature` | stable package and spine path |
| `odt` | `mature` | stable package path with notes/comments appendix and source refs |
| `ods` | `mature` | stable main path for sheet visibility and large-table handling |
| `odp` | `mature` | stable slide-local organization and notes appendix path |
| `docx` | `strong mature` | strong package path, accurate enhancements, and regression confidence |
| `xlsx` | `strong mature` | strong large-sheet, hidden-sheet, sparse-table, and accurate semantics |
| `pptx` | `strong mature` | strong slide/notes handling and readable-order-like semantics |
| `pdf` | `strong mature` | stable native-text path plus clear balanced versus accurate PDF OCR split |
| direct image OCR | `usable` | formally available, but highly dependent on OCR provider quality |
| `wav` / `mp3` / `m4a` | `usable` | formal main-path integration exists through a stable optional local backend, but the current product contract is intentionally narrow |

The most important update from this audit is that `rst`, `asciidoc`, and `tex` should now be considered mature canonical formats, not provisional semantic inventory experiments.

## 4. Per-Format Notes

### 4.1 TXT

Current status:

- formally supported
- lightweight canonical text path
- supports Markdown, RAG, and debug output

Current non-goals:

- rich layout recovery
- external metadata inference

### 4.2 SRT / VTT

Current status:

- formally supported
- always runs through `streaming_event`
- explicit `--stream` stays on the same canonical route

Verified today:

- cue time range output
- stable `time_start` and `time_end` source refs
- multiline captions
- controlled degrade for WebVTT `NOTE`, `STYLE`, and `REGION`
- RAG, diagnostics, and line-range source refs
- malformed input fails closed inside the subtitle route

Current non-goals:

- CSS or region positioning execution
- full subtitle styling systems
- media playback semantics

### 4.3 CSV / TSV

Current status:

- formally supported
- canonical streaming path

Verified today:

- table-style Markdown output
- repo-local regression coverage
- RAG output
- benchmark coverage

Current non-goals:

- spreadsheet formula execution
- workbook-grade style or chart semantics

### 4.4 JSON / JSONL / NDJSON

Current status:

- formally supported
- route chosen between `dom_ast_model` and `streaming_event` based on input shape

Verified today:

- richer structure for small and medium JSON
- stable streaming route for large JSON
- strong conversion success on representative high-pressure JSON samples

Current non-goals:

- a general JSON query engine
- full schema-specific semantic reconstruction for every JSON family

### 4.5 IPYNB

Current status:

- formally supported
- default route is `dom_ast_model`
- explicit `--stream` or oversized inputs fall back to `block_streaming`

Verified today:

- notebook summary tables
- markdown, code, and raw cell boundaries
- typed output lowering for `stream`, `display_data`, `execute_result`, and `error`
- explicit degrade for JavaScript MIME outputs
- structured JSON lowering for `application/json` and `application/*+json`
- asset materialization for images and markdown attachments
- RAG, debug, source refs, and diagnostics

Current non-goals:

- notebook execution
- kernel-state reconstruction
- widget or browser runtime restoration

### 4.6 XML

Current status:

- formally supported
- default route is `dom_ast_model`
- oversized inputs can switch to `streaming_event`

Verified today:

- structural XML-to-Markdown conversion
- large-XML benchmark coverage
- main regression and diagnostic coverage

Current non-goals:

- deep schema-aware semantics
- domain-specific business reconstruction for every XML standard

### 4.7 YAML / YML

Current status:

- formally supported
- default route is `dom_ast_model`
- oversized inputs can switch to `streaming_event`

Verified today:

- mapping and nested mapping output
- flow collections
- metadata-like output
- RAG output

Current non-goals:

- every YAML edge syntax or dialect
- strong product promises around complex anchor or alias expansion

### 4.8 TOML

Current status:

- formally supported
- canonical `dom_ast_model` path

Verified today:

- top-level key-values, named tables, dotted keys
- arrays, array-of-tables, inline tables
- multiline strings, RAG output, and debug diagnostics
- malformed input degrades to raw fenced TOML with explicit warning signals

Current non-goals:

- editor-grade comment preservation
- wide TOML dialect promises beyond the current regression scope

### 4.9 Markdown

Current status:

- formally supported
- default route is `dom_ast_model`
- explicit `--stream` or oversized inputs can switch to `block_streaming`

Verified today:

- headings, paragraphs, and list structure
- frontmatter passthrough
- debug diagnostics
- RAG output

Current non-goals:

- acting as a full Markdown editor
- covering every Markdown dialect extension

### 4.10 RST / AsciiDoc / TEX

Current status:

- formally supported
- current formal level is mature canonical format
- default route is `dom_ast_model`
- explicit `--stream` warns honestly and falls back to the canonical route

Verified today:

- shared `text_markup` canonical path
- typed lowering for headings, paragraphs, lists, code, common tables, and common links
- stable semantic inventory for representative RST, AsciiDoc, and TEX structures
- observable semantic attrs, boundaries, source refs, and diagnostics across Markdown, RAG, and debug output
- dedicated contract tests and dedicated main-regression fixtures

Current non-goals:

- full dialect editor behavior
- complex directive, include, macro, or environment execution
- layout-intelligence-style accurate recovery
- full cross-reference and every table dialect

### 4.11 HTML

Current status:

- formally supported
- default route is `dom_ast_model`
- explicit `--stream` or oversized inputs can switch to `block_streaming`

Verified today:

- content-root selection from `main`, `article`, `body`, and fragments
- suppression for nav/footer/hidden/script/style/template/repeated boilerplate
- headings, paragraphs, lists, basic tables, links, and images
- RAG output
- asset materialization

Current non-goals:

- browser-grade CSS layout reconstruction
- full visual reading-order recovery
- JavaScript-executed page semantics

### 4.12 ODT

Current status:

- formally supported
- default route is `package_single_pass`
- explicit `--stream` switches to `block_streaming`

Verified today:

- `content.xml` main-block scan
- headings, paragraphs, lists, tables, and images
- hyperlinks, footnotes, endnotes, and comment appendix
- asset materialization
- RAG, debug diagnostics, and source refs

Current non-goals:

- full ODF style, revision, and macro semantics
- complete parity with every advanced `docx` feature

### 4.13 ODS

Current status:

- formally supported
- default route is `package_single_pass`
- explicit `--stream` switches to `block_streaming`

Verified today:

- `content.xml` sheet scan
- visible-sheet headings and table-like output
- row-level block streaming
- RAG, debug diagnostics, and sheet source refs

Current non-goals:

- formula execution or recalculation
- full ODF style, comment, and embedded-object recovery
- complete parity with every advanced `xlsx` feature

### 4.14 ODP

Current status:

- formally supported
- default route is `package_single_pass`
- explicit `--stream` switches to `block_streaming`

Verified today:

- slide-order scan through `content.xml`
- headings, paragraphs, lists, tables, images, and notes
- local image asset materialization
- RAG, debug diagnostics, and slide source refs

Current non-goals:

- full visual layout, animation, or transition recovery
- macro or script execution
- complete parity with every advanced `pptx` feature

### 4.15 ZIP

Current status:

- formally supported
- canonical route is `container_recursive`

Verified today:

- entry enumeration
- path normalization and safety boundaries
- dispatch back into the unified main path for supported child formats
- resource materialization

Current non-goals:

- smart interpretation for arbitrary binary members
- remote fetch or execution of external references

### 4.16 EPUB

Current status:

- formally supported
- default route is `package_single_pass`
- explicit `--stream` switches to `container_recursive`

Verified today:

- OPF and spine ordering
- chapter-level HTML dispatch
- local resource materialization
- remote/data image no-fetch and no-persist behavior
- debug JSON exposure for spine and missing-item diagnostics

Current non-goals:

- full reader-grade interaction semantics
- remote resource download
- arbitrary script or linked-content execution

### 4.17 DOCX

Current status:

- formally supported
- canonical route is `package_single_pass`

Verified today:

- main Office document blocks
- links
- images and assets
- debug JSON exposure for `relationship_id`, `part_name`, and `paragraph_index`
- stable RAG and asset-lane regression coverage

Current non-goals:

- full Word advanced-layout semantics

### 4.18 XLSX

Current status:

- formally supported
- default route is `package_single_pass`
- oversized or explicit streaming requests can switch to `block_streaming`

Verified today:

- workbook and worksheet scanning
- table-like output
- hidden-sheet policy
- cached formula value preservation
- debug output

Current non-goals:

- formula execution
- an Excel calculation engine

### 4.19 PPTX

Current status:

- formally supported
- canonical route is `package_single_pass`

Verified today:

- slide order
- text blocks and lists
- images
- speaker notes
- hidden-slide policy
- debug output

Current non-goals:

- full presentation-layout reconstruction

### 4.20 PDF

Current status:

- formally supported
- default product path is native-text first
- balanced and accurate PDF OCR are both integrated into the unified planner

Verified today:

- native-text extraction
- balanced PDF OCR through explicit or scanned-like policy
- accurate PDF OCR for `--accurate`
- route fidelity and provenance
- cleanup and optional table signals
- RAG and debug output
- provider fallback from accurate PDF OCR to balanced OCR with an explicit warning when accurate dependencies are missing

Current non-goals:

- deep layout intelligence as a balanced default
- full complex-table or full visual layout reconstruction guarantees on OCR routes

## 5. OCR Status

Current formal OCR behavior is intentionally narrow and explicit:

- Direct image OCR is formally supported.
- Balanced direct image OCR and balanced PDF OCR are the stable default OCR paths.
- Accurate direct image OCR and accurate PDF OCR both require the accurate OCR dependency path.
- When accurate direct image OCR or accurate PDF OCR is requested but accurate OCR dependencies are missing, the product now emits an explicit warning and falls back to the balanced OCR provider.
- Route fallback and provider fallback are both recorded in diagnostics and provenance.

Current non-goals:

- silent OCR provider switching
- layout-intelligence promises for every OCR case
- automatic OCR of embedded PDF figures just because page OCR is enabled

## 6. What the Unified Architecture Already Buys Us

Moving to the unified architecture already gives the project several long-term benefits:

- one planner and one provenance contract across formats
- one renderer contract across Markdown, RAG, and debug views
- one benchmark story tied to the real product path
- clearer failure behavior for unsupported stream or accurate requests
- stronger regression coverage across route selection and capability boundaries

## 7. Performance and Stress-Sample Positioning

Representative benchmark results should still be refreshed by rerunning the bench suite before a formal release. The current long-term positioning is:

- The project shows clear advantages on more complex formats and more stressful input shapes.
- The engine is better suited for engineering-scale workloads where route honesty and traceability matter.
- The project behaves more predictably under oversized or borderline inputs because unsupported capabilities fail closed and supported capabilities keep provenance.
- In some representative high-pressure cases, the MoonBit path continues to produce successful output where the external baseline fails to form a comparable result set.

For formal benchmark commands and benchmark architecture, see [bench/README.md](../bench/README.md) and [benchmark-architecture.md](./architecture/benchmark-architecture.md).

## 8. Capabilities We Do Not Currently Promise

The project does not currently promise:

- full editor-grade round-trip semantics for every input family
- full browser-grade, Office-grade, or PDF-viewer-grade layout reconstruction
- formula execution, macro execution, or script execution
- automatic accurate upgrades for formats that do not formally support them
- audio accurate mode as a real separate product line today
- stable production guarantees for dependency-heavy `pdf --accurate` and the current optional audio backend line

Important note:

- `pdf --accurate` is still the more dependency-heavy path today
- audio is available through an optional local backend with a narrow transcript-only contract, not as a broad fully managed media product line

## 9. Recommended Validation Entry Points

For normal local validation:

```bash
moon test
```

For full repository validation:

```bash
moon clean
moon build
moon test
```

For main regression and quality regression, first fetch the external corpus repository:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Then run:

```bash
moon build cli --target native
bash samples/check_balance.sh
bash samples/check_balance_quality.sh
```

For a representative external comparison benchmark run:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe run --preset official-compare
```

If the baseline `markitdown` CLI is not already on `PATH`, set `MARKITDOWN_BIN` or pass `--markitdown-path /absolute/path/to/markitdown`.
