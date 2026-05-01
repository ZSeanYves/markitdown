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

Current G3 image-context consolidation at the current stage includes:

- unified `ImageBlock` / `ImageData` semantics
- DOCX source-native image `descr/title`
- PPTX source-native picture `descr/title`
- stable sidecar reuse of `ImageBlock` image context on the asset side

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

Current shared image-context contract:

- `ImageBlock` / `ImageData` carries `path`, `alt_text`, `title`, `caption`,
  and `origin`
- `blocks[].image` serializes `path`, `alt_text`, `title`, and `caption`
- `assets[].alt_text`, `assets[].title`, and `assets[].caption` are filled by
  joining exported asset `path` back to the corresponding `ImageBlock`
- `nearby_caption` is the asset-origin mirror of the primary caption value, not
  an independent caption-inference slot

## 8) Current Per-format Support Scope and Boundaries

### 8.0 Shared Low-level Parsing Foundations

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
inspection, metadata, and graceful degradation, but they do not by themselves
guarantee rich final document semantics.

### 8.1 DOCX

Currently supported:

- heading recovery
- ordered / unordered / nested list recovery
- table parsing
- image export and Markdown references
- unified `ImageBlock` emission for DOCX images
- source-native OOXML drawing `descr -> alt_text`
- source-native OOXML drawing `title -> title`
- block quote detection
- code-like paragraph recovery
- line-break handling in paragraphs and table cells
- numbering / styles driven paragraph recovery

Partially supported:

- quote-like / code-like detection for multilingual or non-standard style names
  remains conservative
- some style generalization still relies mainly on heuristic naming rules
- table cells are still emitted as text cells rather than richer cell-level
  structure

Graceful degradation:

- hyperlinks with missing `r:id`, missing relationships, empty targets, or
  internal anchors/bookmarks are downgraded to plain text rather than forced
  into Markdown link syntax

Metadata / assets / origin:

- lightweight block-level origin metadata is available
- exported image assets can populate `relationship_id` and `source_path`

Link support:

- paragraph / heading / list contexts can preserve external
  `w:hyperlink r:id` relationships through `Inline::Link(text, href)`

Image context:

- DOCX images use unified `ImageBlock`
- source-native drawing `descr` maps to `alt_text`
- source-native drawing `title` maps to `title`
- image caption inference is intentionally not performed from OOXML `name` or
  surrounding document text

Explicitly unsupported / out of scope:

- footnote and endnote hyperlink recovery
- revisions / track changes semantics
- comments
- textbox-specific recovery semantics

### 8.2 PDF

The current PDF mainflow is:

**native structural recovery**

The normal PDF path has already been taken over by the repository’s native
recovery chain rather than an external text-first pipeline.

Currently supported:

- native character / span / line / block recovery
- line-seed converter staging by default
- text normalization and fragmented English word recovery
- page geometry exposure through `pdf_core`
- page-noise cleanup
- repeated header / footer cleanup
- heading / short-sentence boundary recovery
- paragraph / block recovery
- basic bullet / list-item recovery
- cross-page paragraph merging
- hardwrap recovery
- lightweight page-level block origin metadata
- lightweight image asset-origin metadata
- raw page refs, content stream refs, images, and annotation/link data available
  to debug inspect helpers
- convert-stage debug retention for image provenance and annotation records
- unified `ImageBlock` emission for exported PDF images
- conservative single-image bbox-gated caption attachment

Partially supported:

- multi-column, graphic-heavy, and extreme abnormal pages still rely on
  conservative heuristics rather than full layout-semantic reconstruction
- OCR exists as an explicit alternative path, not as part of the default
  `normal` conversion contract
- Markdown output is a conservative structural recovery result, not visual page
  reflow

Graceful degradation:

- annotation/link records remain available in `pdf_core` and convert debug/model
  paths even when they are not emitted as Markdown links
- ambiguous image-caption cases are left unmatched rather than forcing
  low-confidence pairings
- multi-image caption pairing is not enabled, so image/text blocks remain
  separate in ambiguous scenes

Metadata / assets / origin:

- lightweight page-level block origin metadata is available
- exported image assets can populate `object_ref`
- convert-stage debug can retain richer image/source information than the
  default sidecar contract exposes

Link support:

- raw annotation/link extraction exists in `pdf_core` and convert debug/model
  layers
- default Markdown output does not emit PDF annotation links

Image context:

- exported PDF images use unified `ImageBlock`
- image assets can populate `object_ref`
- caption attachment is conservative and only attempted for single-image pages
  with one surviving bbox-gated caption-like candidate

Explicitly unsupported / out of scope:

- true table IR recovery
- default PDF annotation-link Markdown emission
- multi-image caption pairing
- default sidecar emission of full PDF `source_refs`
- default sidecar emission of bbox
- full recovery of complex multi-column or strong graphic-text mixed layouts

### 8.3 XLSX

Currently supported:

- multi-sheet output
- sheet heading plus table emission
- handling of shared string / inline string / bool / error / number cells
- sparse table trimming
- sparse-edge bounding-box tightening
- built-in and custom datetime formatting
- table-width normalization

Partially supported:

- formula cells use existing cell values or cached string results but do not run
  formula evaluation
- merged cells are not reconstructed into richer structure

Graceful degradation:

- `(no sheets found)` is emitted when the workbook has no discoverable sheets
- `(missing sheet xml: ...)` is emitted when workbook metadata points to a
  missing sheet part
- `(empty sheet)` is emitted when a sheet resolves but yields no table content

Metadata / assets / origin:

- lightweight sheet-level block origin metadata is available
- table blocks can populate source row/column span and sheet `relationship_id`

Link support:

- no hyperlink extraction path is currently implemented

Image context:

- no image conversion path is currently implemented

Explicitly unsupported / out of scope:

- formula evaluation
- merged-cell structural reconstruction
- charts
- images
- comments
- hyperlinks
- pivot-table or similar workbook-level semantic recovery

### 8.4 PPTX

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
- basic shape-level hyperlink fallback when one clear external shape link is
  present
- unified `ImageBlock` emission for PPTX images
- conservative caption-like attachment for single-image slides
- conservative nearby-text attachment for single-image slides when there is
  exactly one clear nearby candidate
- source-native `p:cNvPr descr -> alt_text`
- source-native `p:cNvPr title -> title`
- synthetic alt only as fallback when `descr` is absent

Partially supported:

- table-like / grid-like logic currently focuses on region / order stabilization
  rather than complete `Table` IR semantics
- some negative layouts may still be conservatively downgraded into readable
  ordered paragraphs

Graceful degradation:

- ambiguous multi-image / multi-caption cases intentionally remain unmatched
- hyperlinks with missing `r:id`, missing relationships, empty targets,
  internal anchors/bookmarks, actions, macros, or media link targets are
  downgraded to plain text

Metadata / assets / origin:

- lightweight slide-level block origin metadata is available
- lightweight slide-level asset origin metadata is available
- exported image assets can populate `relationship_id` and `source_path`

Link support:

- run-level external hyperlink recovery is supported
- one-clear-shape external hyperlink fallback is supported
- action / macro / media link promotion is not performed

Image context:

- PPTX images use unified `ImageBlock`
- source-native `p:cNvPr descr` maps to `alt_text`
- source-native `p:cNvPr title` maps to `title`
- single-image caption/nearby-text attachment remains conservative

Explicitly unsupported / out of scope:

- multi-image caption pairing
- treating OOXML `name` as caption or title
- complex media / action / macro link promotion
- true table IR reconstruction

### 8.5 HTML

Currently supported:

- lightweight semantic scanning of headings / paragraphs / list items
- ordered / unordered / nested lists
- block quotes
- pre / code blocks
- tables
- explicit `<br>` preservation
- inline `<a href>` hyperlink recovery in paragraph / heading / list-item /
  blockquote contexts
- image-context retention for `<img alt>`, `<img title>`, `<figure>`, and
  `<figcaption>`
- normalized local `<img src>` -> asset-origin `source_path`
- local image export when the source resolves conservatively as a local file

Partially supported:

- the current model is lightweight and DOM-like rather than browser-grade HTML
  semantics
- more complex containers and deeply nested cases are still handled
  conservatively
- table-cell hyperlink handling still remains on the string-render path rather
  than rich-inline IR

Graceful degradation:

- links with missing `href`, empty targets, or internal anchors are downgraded
  to plain text
- remote / `data:` / unsupported image sources are not exported as local assets
- paragraph-level image fallbacks degrade to a simple `[alt]` text placeholder
  when no local export path is available

Metadata / assets / origin:

- lightweight document-level block origin metadata is available
- local image / figure assets can populate `source_path`

Link support:

- inline external `<a href>` links are preserved in supported rich-inline
  contexts
- internal anchors are not promoted to structured link IR

Image context:

- `<img alt>` maps to `ImageData.alt_text`
- `<img title>` maps to `ImageData.title`
- `<figcaption>` maps to `ImageData.caption`
- local image assets can populate normalized `source_path`

Explicitly unsupported / out of scope:

- remote HTML image fetch
- DOM path anchoring
- block line-range anchoring
- browser DOM / CSS / JS rendering semantics

### 8.6 CSV / TSV

Currently supported:

- `.csv` and `.tsv` extension routing
- comma delimiter for CSV and tab delimiter for TSV
- quoted fields, including delimiters inside quotes
- escaped quote handling using `""`
- quoted newline handling inside fields
- empty cells
- ragged rows padded to the widest row before Markdown table emission
- table output through the unified IR `Table` block

Partially supported:

- the converter intentionally models the whole input as one table block rather
  than a richer workbook/schema system

Graceful degradation:

- ragged rows are padded rather than rejected when width is inconsistent

Metadata / assets / origin:

- block origin can populate physical `line_start` / `line_end`
- block origin can populate `row_index = 1` and `column_index = 1`
- no asset export path is involved

Link support:

- no link model is applied

Image context:

- no image model is applied

Explicitly unsupported / out of scope:

- streaming conversion
- dialect sniffing
- comments
- schema detection
- type inference
- lossy fallback for invalid CSV syntax such as unterminated quoted fields

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

Partially supported:

- nested structures remain conservative compact JSON values or fenced JSON
  blocks rather than deeper semantic provenance

Graceful degradation:

- irregular structures fall back to `CodeBlock` or compact cell-string output
  rather than forced table shaping

Metadata / assets / origin:

- root-level block origin can populate `key_path = "$"`
- no asset export path is involved

Link support:

- no link model is applied

Image context:

- no image model is applied

Explicitly unsupported / out of scope:

- JSON Schema support
- JSON Lines support
- streaming parser path
- nested provenance beyond the root-level `key_path`
- lossy fallback for invalid JSON syntax

### 8.8 Markdown Passthrough

Currently supported:

- `.md` and `.markdown` extension routing
- UTF-8 Markdown files read into memory
- original Markdown body preserved for final output
- `passthrough_markdown` takes precedence in the Markdown emitter
- final output tail normalized to exactly one trailing newline
- conservative block slicing for metadata summary and block origins
- conservative block `line_start` / `line_end` on normalized physical lines

Partially supported:

- metadata block counts are engineering summaries rather than a promise of full
  Markdown AST semantics

Graceful degradation:

- the converter does not attempt Markdown semantic interpretation and instead
  preserves the original body with only final trailing-newline normalization

Metadata / assets / origin:

- standard metadata sidecar fields remain available
- block origin can populate conservative `line_start` / `line_end`
- no additional asset export path is inferred from source Markdown

Link support:

- existing Markdown links are preserved because the original Markdown body is
  passed through unchanged

Image context:

- existing Markdown image syntax is preserved because the original Markdown body
  is passed through unchanged

Explicitly unsupported / out of scope:

- Markdown AST parse
- Markdown rewrite / normalization
- Markdown validation
- remote asset parsing or export

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

Partially supported:

- only a simple subset is supported and nested semantics stay conservative

Graceful degradation:

- semantically unclear or mixed structures fall back to fenced YAML blocks or
  compact cell strings rather than speculative reconstruction

Metadata / assets / origin:

- root-level block origin can populate `key_path = "$"`
- no asset export path is involved

Link support:

- no link model is applied

Image context:

- no image model is applied

Explicitly unsupported / out of scope:

- anchors / aliases
- tags
- block scalar `|` / `>`
- flow style `{}` / `[]`
- complex keys
- multi-document `---` / `...`
- streaming parser path
- nested provenance beyond the root-level `key_path`
- lossy fallback for unsupported YAML syntax

## 9) Cross-cutting Boundaries

### 9.1 Hard-fail Parsers vs Soft-degrade Converters

- CSV / TSV, JSON, and YAML are syntax-driven parsers and fail closed on invalid
  syntax rather than guessing a lossy fallback structure.
- DOCX, PPTX, PDF, and HTML are recovery-oriented converters and prefer readable
  partial output plus conservative downgrade instead of aggressive inference.
- Markdown passthrough is intentionally source-preserving: its degradation model
  is “do not reinterpret the source body”.

### 9.2 OCR Boundary

- OCR is an `ocr` subcommand path, not the default mainflow.
- OCR depends on external tooling and therefore requires separate environment
  verification.
- The default PDF support matrix should be read as native text-oriented
  structural recovery, not OCR-first conversion.

### 9.3 Provenance Granularity Boundary

- Sidecar origin is best-effort provenance for engineering traceability, not a
  full layout trace or anchoring system.
- Table cell-level provenance is not enabled across current formats.
- HTML DOM path anchoring is not enabled.
- JSON / YAML nested key-path anchoring is not enabled.
- Default sidecar emission of full PDF `source_refs` or bbox is not enabled.

### 9.4 Multi-image Caption Boundary

- PDF caption pairing remains conservative and is only attempted for
  single-image pages with one surviving bbox-gated caption candidate.
- PPTX caption / nearby-text attachment remains conservative and is only
  intended for single-image slides with one clear candidate.
- Multi-image caption pairing is not enabled in PDF or PPTX.

### 9.5 Remote Asset Boundary

- Remote HTML image fetch is not enabled.
- Remote / unsupported HTML image sources are not force-exported as local
  assets.
- Markdown passthrough does not parse or export remote assets from source
  Markdown.
- The current asset path focuses on package-embedded OOXML media, exported PDF
  images, and conservative local HTML image export.

### 9.6 Markdown Passthrough Boundary

- Markdown support is source-preserving passthrough, not a Markdown
  parser/rewriter.
- The emitter prefers `passthrough_markdown` and only normalizes the final
  trailing newline.
- Metadata uses conservative block slicing rather than full Markdown syntax
  analysis.

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
- OOXML `name` is not treated as image caption or title.
- XLSX image conversion is not enabled.
- Remote HTML image fetch is not enabled.
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
