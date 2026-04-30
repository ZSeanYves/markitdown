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
- CSV
- TSV
- JSON
- YAML (`.yaml` / `.yml`)
- Markdown (`.md` / `.markdown`)

Inputs outside the above extensions are rejected by the dispatcher.

## 3) Current Format Expansion Stages

The currently landed text-format expansion stages are:

- F1: CSV / TSV
- F2: JSON
- F3: Markdown passthrough
- F4: YAML

Their positioning is intentionally different:

- CSV / TSV are delimited table text converted into unified IR `Table`
- JSON and YAML are structured inputs converted into unified IR `Table` /
  `List` / `CodeBlock` semantics conservatively
- Markdown is a low-loss passthrough input: the main body is preserved as
  source Markdown rather than rebuilt from an AST

## 4) Current Mainflow Capability

A unified mainflow has already been established:

**multi-format input -> unified IR -> Markdown output**

And can optionally include:

- `assets/` resource export
- `metadata/*.metadata.json` sidecar output (enabled via `--with-metadata`)

## 5) Roles and Value of the Three Validation Chains

The complete regression system is split into three independent validation chains:

- `samples/main_process`: mainflow structural recovery (Markdown main body)
- `samples/metadata`: origin / image-context / caption / nearby-caption
- `samples/assets`: resource export and Markdown asset-reference validity

Why this split matters:

1. **Failure-surface decoupling**: structural issues, metadata issues, and resource issues can be diagnosed independently.
2. **Acceptance explainability**: it becomes possible to answer separately whether structure is recovered, provenance is usable, and resources are exportable.
3. **Engineering stability**: it avoids excessive noise in a single monolithic regression script.

## 6) Positioning of `samples/test` (Acceptance Demo)

`samples/test` currently includes demo outputs for five formats:

- `golden.md` (DOCX demo)
- `html_figure_figcaption_basic.md`
- `pdf_image_single_caption_like.md`
- `pptx_image_single_caption_like.md`
- `xlsx_builtin_datetime_22.md`

It also includes corresponding metadata and asset demo files.

> This directory is a **compact acceptance-oriented demo set**, meant to quickly demonstrate the combined effect of “main output + metadata + assets”;  
> it is **not equivalent to the full regression set**. Full regression is defined by `samples/main_process`, `samples/metadata`, and `samples/assets`.

## 7) Positioning of the Metadata Sidecar

The metadata sidecar is an **engineering artifact**, intended for:

- provenance / auditing
- indexing and ingestion
- RAG / chunk preprocessing

It is not part of the Markdown main body and is not intended to replace the main reading output.

Current G2 Origin / Source Location scope is complete at the current stage:

- additive origin schema extension
- sparse additive-field emission
- OOXML origin refinement
- structured/text origin refinement
- HTML image `source_path` refinement

Current sidecar origin field surface:

- `blocks[].origin`: `source_name`, `format`, `page`, `slide`, `sheet`,
  `block_index`, `heading_path`, `line_start`, `line_end`, `row_index`,
  `column_index`, `object_ref`, `relationship_id`, `key_path`
- `assets[].origin`: `source_name`, `format`, `page`, `slide`, `sheet`,
  `origin_id`, `object_ref`, `relationship_id`, `source_path`, `row_index`,
  `column_index`, `key_path`, `nearby_caption`

Current verifiable fill ranges:

- PDF assets: `object_ref`
- PPTX assets: `relationship_id` / `source_path`
- DOCX assets: `relationship_id` / `source_path`
- XLSX blocks: source row/column span plus `relationship_id`
- CSV / TSV blocks: physical `line_start` / `line_end` plus
  `row_index` / `column_index`
- JSON / YAML blocks: root `key_path = "$"`
- Markdown blocks: conservative `line_start` / `line_end`
- HTML image assets: `source_path` from normalized `<img src>`

The metadata schema is unchanged; G2 only refines population inside the
existing contract.

## 8) Current Per-format Support Scope and Boundaries

### 7.0 Shared Low-level Parsing Foundations

The repository now also has a usable low-level parsing substrate beneath the
format-specific recovery logic.

Current OOXML infrastructure includes:

- package query APIs for part listing, part reads, and content-type lookup
- typed relationships with internal/external target handling
- package-level media asset indexing
- lightweight `docProps/core.xml` and `docProps/app.xml` reading
- read-only debug dump APIs for inspection

Current PDF Core infrastructure includes:

- vendored native backend wiring
- source-aware operator parsing
- page geometry support including media box, inherited crop box, rotation, raw
  page refs, and raw content stream refs
- raw image extraction
- raw annotation / link extraction
- read-only debug inspect output for document/page/image/annotation statistics

These capabilities are parsing infrastructure. They support recovery,
inspection, and metadata, but do not by themselves guarantee rich final
document semantics.

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
- external `w:hyperlink r:id` relationship preservation as Markdown links
  through `Inline::Link(text, href)`
- lightweight block-level origin metadata
- lightweight asset-origin metadata for exported image resources

Current boundaries:

- hyperlinks with missing `r:id`, missing relationships, empty targets, or
  internal anchors/bookmarks are currently downgraded to plain text
- footnote and endnote hyperlinks are not currently recovered
- quote-like / code-like detection for multilingual or non-standard style names remains conservative
- some style generalization still relies mainly on heuristic naming rules

### 7.2 PDF

The current PDF mainflow is:

**native structural recovery**

The normal PDF path has already been taken over by the repository’s native recovery chain rather than an external text-first pipeline.

Currently supported:

- native character / span / line / block recovery
- line-seed converter staging by default: `pdf_core` text block lines are
  flattened and converted as one `PdfConvertBlock` per line
- text normalization and fragmented English word recovery
- page geometry exposure through `pdf_core` including media box, crop box, and
  rotation
- page-noise cleanup
- repeated header / footer cleanup using repeated edge text plus page box
  top/bottom zones
- heading / short-sentence boundary recovery
- paragraph / block recovery
- basic bullet / list-item recovery
- cross-page paragraph merging using hard blockers, text-continuation evidence,
  layout compatibility, and core-derived continuation signals
- hardwrap recovery
- conservative pseudo two-column negative protection
- lightweight page-level block origin metadata
- lightweight image asset-origin metadata
- raw page refs, content stream refs, images, and annotation/link data available
  to debug inspect helpers
- convert-stage pipeline debug retention for image provenance fields and
  page-level annotation records
- source core block provenance and block-level flags retained in
  `PdfConvertBlock` for debug and future enhancement work
- conservative nearby-caption attachment in single-image-page +
  single surviving caption-like cases, with bbox geometry gating based on
  above/below placement, nearby vertical gap, and horizontal alignment/overlap
- retention of page-level asset origin for exported PDF image assets
- debug inspect output for document version/page count, per-page geometry,
  counts, images, and annotations

Current boundaries:

- OCR is still not the default `normal` path
- OCR currently exists as a plugin-style path driven by external tooling
- PDF conversion remains conservative structure recovery; it is not equivalent
  to visual page reflow or full layout recreation
- core block seeding is not enabled by default; the normal path still uses
  line-seed block staging
- annotations and link records currently enter the `pdf_core` model/debug
  substrate and convert-stage debug, but they are not emitted as Markdown
  links by default
- multi-image caption pairing is not enabled; the current caption path remains
  a conservative single-image-page strategy
- more complex multi-column, heavy graphic-text mixing, and extreme anomaly cases are still under active improvement
- some complex layouts still rely on heuristic rules rather than full layout-semantic reconstruction
- Markdown output is still a conservative structural recovery result; it is not
  intended to be a full visual reproduction of the original PDF page

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
- run-level `a:hlinkClick r:id` external hyperlink recovery
- basic shape-level hyperlink fallback when one clear external shape link is present
- conservative caption-like attachment for single-image slides
- conservative nearby-text attachment for single-image slides when there is exactly one clear nearby candidate
- ambiguous multi-image / multi-caption cases intentionally remain unmatched
- lightweight slide-level block origin metadata
- lightweight slide-level asset origin metadata

Current boundaries:

- hyperlinks with missing `r:id`, missing relationships, empty targets, internal
  anchors/bookmarks, actions, macros, or media link targets are currently
  downgraded to plain text
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
- inline `<a href>` hyperlink recovery in paragraph / heading / list-item / blockquote contexts
- lightweight document-level block origin metadata
- lightweight image / figure asset-origin metadata
- image-context retention for `<img alt>`, `<img title>`, `<figure>`, and `<figcaption>`
- `<img alt>` -> `ImageData.alt_text`
- `<img title>` -> `ImageData.title`
- `<figcaption>` -> `ImageData.caption`
- local image export behavior remains unchanged; remote / unsupported sources are handled conservatively

Current boundaries:

- links with missing `href`, empty targets, or internal anchors are currently
  downgraded to plain text
- the current model is lightweight and DOM-like rather than browser-grade HTML semantics
- more complex containers and deeply nested cases are still handled conservatively
- table-cell hyperlink handling still remains on the string-render path (not yet promoted into rich-inline IR)
- remote / unsupported image sources are not force-exported as local assets

### 8.6 CSV / TSV

Currently supported:

- `.csv` and `.tsv` extension routing
- comma delimiter for CSV and tab delimiter for TSV
- quoted fields, including delimiters inside quotes
- escaped quote handling using `""`
- quoted newline handling inside fields
- empty cells
- ragged rows, padded to the widest row before Markdown table emission
- table output through the unified IR `Table` block
- block origin with physical `line_start` / `line_end` and
  `row_index = 1` / `column_index = 1`
- standard metadata sidecar summary fields

Current boundaries:

- UTF-8 text input is expected
- no type inference, formula handling, dialect sniffing, comments, or schema detection
- no large-file streaming path; files are read into memory as text
- CSV / TSV output is a single Markdown table, not a multi-table workbook model

### 8.7 JSON

Currently supported:

- `.json` extension routing
- UTF-8 JSON files read into memory
- JSON object, array, string, number, boolean, and null values
- top-level objects emitted as key-value Markdown tables
- arrays of objects with consistent keys emitted as Markdown tables
- arrays of scalar values emitted as bullet lists
- mixed arrays and ambiguous nested structures emitted as fenced JSON blocks
- nested object / array values inside table cells compact-stringified as JSON
- root-level block `key_path = "$"`
- standard metadata sidecar summary fields

Current boundaries:

- no JSON Schema support
- no JSON Lines support
- no streaming parser path
- no type inference beyond JSON primitive values
- nested structures remain conservative compact JSON values or fenced JSON blocks
- nested key-path anchoring is intentionally not populated

### 8.8 Markdown Passthrough

Currently supported:

- `.md` and `.markdown` extension routing
- UTF-8 Markdown files read into memory
- original Markdown body preserved for final output
- `passthrough_markdown` takes precedence in the Markdown emitter
- final output tail normalized to exactly one trailing newline
- conservative block slicing for metadata summary and block origins
- conservative block `line_start` / `line_end` on normalized physical lines
- standard metadata sidecar fields with `format = markdown`, `source_name`,
  `summary.block_count`, `summary.asset_count`, and `document = null`

Current boundaries:

- no Markdown AST parse
- no rewriting of heading / list / table / code / link / image / frontmatter
  semantics
- no remote asset parsing or export
- metadata schema remains unchanged
- block counts in metadata are conservative engineering summaries, not a
  promise of full Markdown semantic parsing

### 8.9 YAML

Currently supported:

- `.yaml` and `.yml` extension routing
- UTF-8 YAML files read into memory
- simple YAML subset including top-level mapping, indentation-based nested
  mapping, scalar sequences, and sequences of mappings
- scalar handling for strings, `true`, `false`, `null`, and `~`
- single-quoted and double-quoted strings
- full-line comments and conservative inline-comment stripping outside quoted
  strings
- top-level mappings emitted as key-value Markdown tables
- arrays of objects with consistent keys emitted as Markdown tables
- arrays of scalar values emitted as bullet lists
- nested / ambiguous mixed structures emitted as fenced YAML blocks or compact
  inline string values inside table cells
- root-level block `key_path = "$"`
- standard metadata sidecar summary fields

Current boundaries:

- only a simple subset is supported
- no anchors or aliases
- no tags
- no block scalar `|` / `>`
- no flow style `{}` / `[]`
- no complex keys
- no multi-document `---` / `...`
- no YAML schema inference
- no streaming parser path
- metadata schema remains unchanged
- nested key-path anchoring is intentionally not populated

## 9) Current Boundaries (Key Points)

### 9.1 PDF Boundary

- The default `normal` path is already a text-oriented native structural recovery mainflow.
- The default PDF path uses line-seed block staging, not core-block seed mode.
- `pdf_core` annotation/link extraction is available for model/debug
  inspection, and convert pipeline debug retains page annotations, but
  annotations are not converted into Markdown links by default. PDF annotation
  link emission requires a separate bbox/text matching design before it is
  enabled.
- default sidecar emission of full PDF `source_refs` is not enabled
- default sidecar emission of bbox is not enabled
- Image provenance is retained in convert pipeline debug for diagnosis, but it
  does not change the Markdown contract.
- PDF caption pairing remains conservative: it is only attempted for
  single-image pages, uses the existing caption-like text helper, and applies a
  bbox geometry gate rather than enabling broad layout-semantic matching.
- Multi-image caption pairing is still not enabled.
- Complex multi-column layouts, strong graphic-text mixing, and extreme abnormal pages remain enhancement targets.

### 9.2 OCR Boundary

- OCR is an `ocr` subcommand path, not the default mainflow.
- OCR depends on external tooling and therefore requires separate environment verification.

### 9.3 Advanced OOXML Boundary

- The current priority is “readable structure + regression stability + explainability”.
- Shared OOXML infrastructure for package, relationships, media, and document
  properties is now in place, but higher-level advanced OOXML semantics
  (complex style semantics, deeper layout logic, formula evaluation, etc.) are
  not yet fully covered.

### 9.4 Markdown Boundary

- Markdown support is currently source-preserving passthrough, not a Markdown
  parser/rewriter.
- The emitter prefers `passthrough_markdown` and only normalizes the final
  trailing newline.
- Metadata remains on the existing schema and uses conservative block slicing
  rather than full Markdown syntax analysis.

### 9.5 HTML Boundary

- HTML support is currently lightweight semantic scanning, not full DOM
  reconstruction.
- HTML image assets can populate `source_path` from normalized local
  `<img src>`.
- HTML block DOM path anchoring is not enabled.
- HTML block line-range anchoring is not enabled.

### 9.6 Structured-data Boundary

- Table cell-level provenance is not enabled across current formats.
- JSON / YAML nested key-path anchoring is not enabled.

### 9.7 YAML Boundary

- YAML support is currently a conservative simple-subset converter, not a full
  YAML-spec implementation.
- Unsupported YAML features are intentionally kept out of scope rather than
  partially guessed.
- Nested or ambiguous structures may fall back to compact string values or
  fenced YAML blocks instead of richer semantic reconstruction.

## 10) Known Limits

- Provenance is lightweight traceability only, not bbox / char-range / source-object-id level fine-grained anchoring.
- default sidecar emission of full PDF `source_refs` is not enabled.
- default sidecar emission of bbox is not enabled.
- HTML is parsed as lightweight semantics, not as a browser rendering model.
- HTML DOM path and HTML block line-range anchoring are not enabled.
- Table cell-level provenance is not enabled.
- JSON / YAML nested key-path anchoring is not enabled.
- XLSX does not evaluate formulas.
- Ambiguous multi-image / multi-caption scenes in PPTX follow a conservative matching strategy (non-matching is acceptable).
- If no Markdown output file is provided (stdout mode), `--with-metadata` will not write sidecar files to disk.
- Markdown passthrough does not validate, normalize, or semantically interpret
  Markdown syntax beyond ensuring a single trailing newline in the final output.
- YAML support does not attempt full-spec compatibility and intentionally
  excludes anchors / aliases / tags / block scalars / flow style / multi-doc
  features.
- PDF annotation links are not emitted into default Markdown output.

## 11) Suggested Acceptance Wording (Directly Reusable)

- “The project has completed a unified multi-format IR mainflow and established three regression-verifiable validation chains: main_process, metadata, and assets.”
- “The text-format expansion stages currently landed are F1 CSV / TSV, F2 JSON, F3 Markdown passthrough, and F4 YAML.”
- “CSV / TSV map delimited table text into IR `Table`, JSON and YAML conservatively map structured data into IR `Table` / `List` / `CodeBlock`, and Markdown follows a low-loss passthrough path that preserves the original Markdown body while keeping the metadata schema unchanged.”
- “At the current stage, the focus is on regression stability, explainability, and engineering-consumable outputs; complex PDF layouts, OCR quality refinement, and broader advanced OOXML coverage remain future consolidation work.”
