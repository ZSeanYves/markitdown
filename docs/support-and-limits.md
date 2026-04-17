# Support Scope and Known Limits (Acceptance-Oriented)

> Scope statement: this document reflects only what is verifiably implemented in the current repository and does not promise capabilities that have not yet been landed.

## 1) Project Positioning

The current project is positioned as **structured content recovery plus engineering-consumable output**.

- Main output: Markdown (for reading)
- Companion outputs: `assets/` (resource export) + metadata sidecar (for engineering consumption)
- Non-goals: pixel-perfect page reproduction, browser-grade rendering semantics, or a full fine-grained anchoring system

## 2) Currently Supported Input Formats

The unified entry currently supports:

- DOCX
- PDF
- XLSX
- PPTX
- HTML/HTM

Inputs outside the above extensions are rejected by the dispatcher.

## 3) Current Mainflow Capability

A unified mainflow has already been established:

**multi-format input -> unified IR -> Markdown output**

And can optionally include:

- `assets/` resource export
- `metadata/*.metadata.json` sidecar output (enabled via `--with-metadata`)

## 4) Roles and Value of the Three Validation Chains

The complete regression system is split into three independent validation chains:

- `samples/main_process`: mainflow structural recovery (Markdown main body)
- `samples/metadata`: origin / image-context / caption / nearby-caption
- `samples/assets`: resource export and Markdown asset-reference validity

Why this split matters:

1. **Failure-surface decoupling**: structural issues, metadata issues, and resource issues can be diagnosed independently.
2. **Acceptance explainability**: it becomes possible to answer separately whether structure is recovered, provenance is usable, and resources are exportable.
3. **Engineering stability**: it avoids excessive noise in a single monolithic regression script.

## 5) Positioning of `samples/test` (Acceptance Demo)

`samples/test` currently includes demo outputs for five formats:

- `golden.md` (DOCX demo)
- `html_figure_figcaption_basic.md`
- `pdf_image_single_caption_like.md`
- `pptx_image_single_caption_like.md`
- `xlsx_builtin_datetime_22.md`

It also includes corresponding metadata and asset demo files.

> This directory is a **compact acceptance-oriented demo set**, meant to quickly demonstrate the combined effect of “main output + metadata + assets”;  
> it is **not equivalent to the full regression set**. Full regression is defined by `samples/main_process`, `samples/metadata`, and `samples/assets`.

## 6) Positioning of the Metadata Sidecar

The metadata sidecar is an **engineering artifact**, intended for:

- provenance / auditing
- indexing and ingestion
- RAG / chunk preprocessing

It is not part of the Markdown main body and is not intended to replace the main reading output.

## 7) Current Per-format Support Scope and Boundaries

### 7.1 DOCX

Currently supported:

- heading recovery
- ordered / unordered / nested list recovery
- table parsing
- image export and Markdown references
- block quote detection
- code-like paragraph recovery
- line-break handling in paragraphs and table cells
- hyperlink recovery in paragraph / heading / list contexts
- lightweight block-level origin metadata
- lightweight asset-origin metadata for exported image resources

Current boundaries:

- quote-like / code-like detection for multilingual or non-standard style names remains conservative
- some style generalization still relies mainly on heuristic naming rules

### 7.2 PDF

The current PDF mainflow is:

**native structural recovery**

The normal PDF path has already been taken over by the repository’s native recovery chain rather than an external text-first pipeline.

Currently supported:

- native character / span / line / block recovery
- text normalization and fragmented English word recovery
- page-noise cleanup
- repeated header / footer cleanup
- heading / short-sentence boundary recovery
- paragraph / block recovery
- basic bullet / list-item recovery
- cross-page paragraph merging
- hardwrap recovery
- conservative pseudo two-column negative protection
- lightweight page-level block origin metadata
- lightweight image asset-origin metadata
- conservative nearby-caption attachment in single-image + single high-confidence caption-like cases
- retention of page-level asset origin for exported PDF image assets

Current boundaries:

- OCR is still not the default `normal` path
- OCR currently exists as a plugin-style path driven by external tooling
- more complex multi-column, heavy graphic-text mixing, and extreme anomaly cases are still under active improvement
- some complex layouts still rely on heuristic rules rather than full layout-semantic reconstruction

### 7.3 XLSX

Currently supported:

- multi-sheet output
- handling of shared string / inline string / bool / error / number cells
- sparse table trimming
- sparse-edge bounding-box tightening
- built-in and custom datetime formatting
- table-width normalization
- lightweight sheet-level block origin metadata

Current boundaries:

- no formula evaluation
- merged cells have not yet been upgraded into richer structural recovery targets

### 7.4 PPTX

Currently supported:

- real slide-order recovery
- title / body separation
- bullet-property-first list recovery
- ordered / unordered / nested list recovery
- shape-aware reading order
- conservative two-column handling
- note-like / caption-like / callout-like grouping
- table-like / grid-like region detection and stabilization
- conservative filtering of page-number / corner-label noise
- run-level hyperlink recovery and basic shape-level hyperlink recovery
- conservative caption-like attachment for single-image slides
- conservative nearby-text attachment for single-image slides when there is exactly one clear nearby candidate
- ambiguous multi-image / multi-caption cases intentionally remain unmatched
- lightweight slide-level block origin metadata
- lightweight slide-level asset origin metadata

Current boundaries:

- some negative layouts may still be conservatively downgraded into readable ordered paragraphs
- table-like stabilization currently focuses more on region / order recovery than on full table-level IR semantics

### 7.5 HTML

Currently supported:

- headings / paragraphs / list items
- ordered / unordered / nested lists
- block quotes
- pre / code blocks
- tables
- explicit `<br>` preservation
- lightweight inline model
- local structure recovery inside list-item containers
- local structure recovery inside blockquote containers
- inline hyperlink recovery in paragraph / heading / list-item / blockquote contexts
- lightweight document-level block origin metadata
- lightweight image / figure asset-origin metadata
- image-context retention for `<img alt>`, `<img title>`, `<figure>`, and `<figcaption>`
- `<img alt>` -> `ImageData.alt_text`
- `<img title>` -> `ImageData.title`
- `<figcaption>` -> `ImageData.caption`
- local image export behavior remains unchanged; remote / unsupported sources are handled conservatively

Current boundaries:

- the current model is lightweight and DOM-like rather than browser-grade HTML semantics
- more complex containers and deeply nested cases are still handled conservatively
- table-cell hyperlink handling still remains on the string-render path (not yet promoted into rich-inline IR)
- remote / unsupported image sources are not force-exported as local assets

## 8) Current Boundaries (Key Points)

### 8.1 PDF Boundary

- The default `normal` path is already a text-oriented native structural recovery mainflow.
- Complex multi-column layouts, strong graphic-text mixing, and extreme abnormal pages remain enhancement targets.

### 8.2 OCR Boundary

- OCR is an `ocr` subcommand path, not the default mainflow.
- OCR depends on external tooling and therefore requires separate environment verification.

### 8.3 Advanced OOXML Boundary

- The current priority is “readable structure + regression stability + explainability”.
- Advanced OOXML features (complex style semantics, deeper layout/relationship logic, formula evaluation, etc.) are not yet fully covered.

## 9) Known Limits

- Provenance is lightweight traceability only, not bbox / char-range / source-object-id level fine-grained anchoring.
- HTML is parsed as lightweight semantics, not as a browser rendering model.
- XLSX does not evaluate formulas.
- Ambiguous multi-image / multi-caption scenes in PPTX follow a conservative matching strategy (non-matching is acceptable).
- If no Markdown output file is provided (stdout mode), `--with-metadata` will not write sidecar files to disk.

## 10) Suggested Acceptance Wording (Directly Reusable)

- “The project has completed a unified multi-format IR mainflow and established three regression-verifiable validation chains: main_process, metadata, and assets.”
- “At the current stage, the focus is on regression stability, explainability, and engineering-consumable outputs; complex PDF layouts, OCR quality refinement, and broader advanced OOXML coverage remain future consolidation work.”