# markitdown-mb

A **MoonBit-based multi-format content processing infrastructure project**, originally inspired by Microsoft **markitdown**.

It is no longer best described as just a “document-to-Markdown converter”. Instead, it is gradually evolving into a reusable foundation for content engineering, including:

* multi-format content parsing
* structural recovery and unified representation
* unified IR (intermediate representation) modeling
* asset export and indexing
* lightweight provenance tracking
* downstream integration for knowledge bases, RAG, auditing, and content processing workflows

The project currently supports **DOCX / PDF / XLSX / PPTX / HTML / CSV / TSV / JSON / Markdown / YAML**, and can produce structured Markdown, extracted assets, and metadata sidecars when needed.

Currently supported platforms:

* macOS
* Linux

The project is built around the following unified processing pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

This means the repository should not be understood only as a “format converter”, but as an infrastructure project for content engineering workflows.

## Current Status

Current major capabilities include:

* **DOCX**: heading, list, table, image, block quote, and code-like paragraph recovery, plus hyperlink recovery inside paragraphs, headings, and list items
* **PDF**: the default mainflow has been switched to a native structural recovery pipeline, rebuilding text-based PDF structure through event / span / line / block / IR reconstruction; it also supports lightweight page-level image provenance and conservative caption attachment in single caption-like cases
* **XLSX**: worksheet-to-table output, datetime formatting, sparse-region trimming, and multi-sheet output
* **PPTX**: reading-order recovery, title/body separation, list recovery, handling of table-like / caption-like / callout-like regions, conservative caption / nearby-text attachment for single-image slides, and basic run-level and shape-level hyperlink recovery
* **HTML**: lightweight DOM-semantic parsing with support for list / table / block quote / code block / local-container structure recovery, inline hyperlink recovery, and image-context retention for `<img alt>`, `<img title>`, `<figure>`, and `<figcaption>`
* **CSV / TSV**: delimiter-based table conversion with quoted fields, escaped quotes, empty cells, and ragged-row padding
* **JSON**: conservative structured-data conversion for objects, arrays, scalars, and nested values
* **Markdown**: source-preserving passthrough for `.md` / `.markdown`, using `passthrough_markdown` for final output and only normalizing the final trailing newline
* **YAML**: conservative simple-subset structured-data conversion for `.yaml` / `.yml`, mapping common mappings/sequences into `Table` / `List` / `CodeBlock`

Current hyperlink preservation status:

* **HTML**: preserves external `<a href>` links in supported rich-inline contexts
* **DOCX**: preserves external `w:hyperlink r:id` links through document relationships
* **PPTX**: preserves run-level `a:hlinkClick r:id` links, with a basic shape-level hyperlink fallback when the whole shape has one clear external link
* All preserved links use the unified `Inline::Link(text, href)` IR and are emitted as Markdown `[text](href)`
* Missing `href`, missing `r:id`, missing relationship, empty targets, internal anchors/bookmarks, actions, macros, and media links are not promoted to Markdown links; they are left as plain text where text is available
* PDF annotation/link records are available in `pdf_core` and convert debug/inspection paths, but the default PDF Markdown output does not emit annotation links yet. Enabling that requires a separate bbox/text matching pass.

Current text-format expansion stages:

* **F1 CSV / TSV**: delimited table text -> unified IR `Table`
* **F2 JSON**: structured data -> unified IR `Table` / `List` / `CodeBlock`
* **F3 Markdown passthrough**: original Markdown body preserved through `passthrough_markdown`
* **F4 YAML**: simple-subset structured data -> unified IR `Table` / `List` / `CodeBlock`

Current text-format boundaries:

* **CSV / TSV**: no streaming path, dialect sniffing, or schema inference
* **JSON**: no JSON Schema, JSON Lines, or streaming parser path
* **Markdown**: no AST parse and no rewriting of link / image / table / code / frontmatter semantics
* **YAML**: only a simple subset is supported; anchors / aliases / tags / block scalar / flow style / multi-document input are out of scope

The repository has now formed a stable workflow:

**multi-format input -> unified IR -> Markdown output / asset export / regression validation**

### Low-level Parsing Infrastructure Status

The lower-level parsing substrate has also completed a first consolidation pass.

Current `doc_parse/ooxml` infrastructure includes:

* package query APIs for listing parts, reading bytes, and querying content types
* typed OOXML relationships with internal/external target handling
* package-level media asset indexing for `word/media`, `ppt/media`, and `xl/media`
* lightweight `docProps/core.xml` and `docProps/app.xml` reading
* read-only debug dump APIs for package inspection

Current `doc_parse/pdf_core` infrastructure includes:

* vendored `mbtpdf` backend integration
* source-aware operator parsing and raw adapter layering
* page geometry support including media box, inherited crop box, rotation, and raw page refs
* raw image and annotation/link extraction
* debug/inspect APIs that expose per-page geometry, refs, images, annotations, links, and text statistics

These lower-level packages are parsing and inspection infrastructure. They support the upper-level `convert/*` recovery layer, but they do not directly define the final Markdown semantics on their own.

## Lightweight Provenance (Origin Metadata)

The unified IR currently includes a lightweight provenance layer for tracing the source of both content blocks and exported assets:

* `Document.block_origins`: block-level provenance information
* `Document.asset_origins`: asset-level provenance information

The G2 Origin / Source Location stage is now complete at the current
repository boundary. It includes:

* additive origin schema extension
* sparse sidecar emission for additive fields
* OOXML origin refinement
* structured/text origin refinement
* HTML image `source_path` refinement

Current sidecar `blocks[].origin` field surface:

* `source_name`
* `format`
* `page`
* `slide`
* `sheet`
* `block_index`
* `heading_path`
* `line_start` / `line_end`
* `row_index` / `column_index`
* `object_ref`
* `relationship_id`
* `key_path`

Current sidecar `assets[].origin` field surface:

* `source_name`
* `format`
* `page`
* `slide`
* `sheet`
* `origin_id`
* `object_ref`
* `relationship_id`
* `source_path`
* `row_index` / `column_index`
* `key_path`
* `nearby_caption`

Current verifiably populated ranges include:

* PDF assets: `object_ref`
* PPTX assets: `relationship_id` / `source_path`
* DOCX assets: `relationship_id` / `source_path`
* XLSX blocks: source row/column span plus `relationship_id`
* CSV / TSV blocks: physical `line_start` / `line_end` plus row/column origin
* JSON / YAML blocks: root `key_path = "$"`
* Markdown blocks: conservative `line_start` / `line_end`
* HTML image assets: `source_path` from normalized `<img src>`

Its current scope is **lightweight provenance**, rather than a fine-grained anchoring system.

It does **not yet** include:

* default sidecar emission of full PDF `source_refs`
* default sidecar emission of bbox
* HTML DOM path or HTML block line-range anchoring
* table cell-level provenance
* JSON / YAML nested key-path anchoring
* default PDF annotation-link Markdown emission

It also does not alter the reading behavior of the Markdown main output.

The metadata schema itself remains unchanged; G2 only extends and refines
field population within the existing sidecar contract.

## Project Goals

From an engineering perspective, `markitdown-mb` is gradually becoming suitable for the following scenarios:

* multi-format content ingestion
* structured Markdown generation
* asset extraction and management
* RAG / chunking preprocessing
* lightweight provenance-aware content pipelines
* future downstream outputs such as JSON / chunk / index / audit artifacts

In other words, the goal of the project is not pixel-perfect reproduction of original documents, but to become a **reusable, testable, explainable, and extensible** content processing infrastructure.

## Quick Links

* [Architecture](./docs/architecture.md)
* [Support and Limits](./docs/support-and-limits.md)
* [Metadata Sidecar](./docs/metadata-sidecar.md)
* [Acceptance Checklist (proposal-aligned)](./docs/acceptance-checklist.md)
* [Sample Coverage and Regression Layout](./docs/sample-coverage.md)
* [Development Guide](./docs/development.md)

## Environment Setup

### External Dependency

#### macOS (Homebrew)

```bash
brew install ocrmypdf
```

#### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y ocrmypdf
```

### Verify

```bash
ocrmypdf --version
```

## Usage

### Normal Conversion

```bash
moon run cli -- normal <input> [output]
```

### OCR Conversion

```bash
moon run cli -- ocr <input> [output]
```

### Debug Conversion

```bash
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

### Output metadata sidecar

All three subcommands support `--with-metadata`:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
moon run cli -- ocr --with-metadata <input> <output.md>
moon run cli -- debug --with-metadata <all|extract|raw|pipeline> <input> <output.md>
```

Current output behavior:

* the Markdown output path follows your `[output]` argument
* if `[output]` looks like a directory, the result will be written as `<output>/<input_stem>.md`
* the metadata sidecar is always written to: `<markdown_dir>/metadata/<markdown_stem>.metadata.json`
* if no output file is provided (stdout mode), the sidecar will not be written to disk

### Typical Output Layout

```text
out/
  demo.md
  assets/
    image01.png
    image02.jpg
  metadata/
    demo.metadata.json
```

Notes:

* `assets/` is created only when asset export is needed
* the metadata sidecar is intended for machine consumption (provenance / indexing / auditing), not as part of the Markdown main body

## Regression System and Demo Samples

### Full Regression System (engineering baseline)

The full regression system is currently split into three independent validation chains:

* `samples/main_process`: mainflow structure recovery
* `samples/metadata`: origin / image-context / caption / nearby-caption
* `samples/assets`: asset extraction and Markdown asset-reference validity

This split is intentional and is used to improve:

* issue localization efficiency
* explainability
* clarity of acceptance evidence
* regression noise control

### Acceptance Demo Samples (`samples/test`)

`samples/test` provides a compact demo set covering five formats, making it easy to showcase unified output during acceptance review:

* DOCX: `golden.md`
* HTML: `html_figure_figcaption_basic.md`
* PDF: `pdf_image_single_caption_like.md`
* PPTX: `pptx_image_single_caption_like.md`
* XLSX: `xlsx_builtin_datetime_22.md`

This directory also includes the corresponding metadata and asset demonstration outputs.

> Note: `samples/test` is an **acceptance demo sample set**, not a replacement for the full regression suites. Full regression still relies on `samples/main_process`, `samples/metadata`, and `samples/assets`.

## Regression Commands

### Check sample enrollment consistency

```bash
./samples/check_samples.sh
```

### Run full main regression

```bash
./samples/diff.sh
```

### Run metadata regression independently

```bash
./samples/check_metadata.sh
```

### Run assets regression independently

```bash
./samples/check_assets.sh
```
