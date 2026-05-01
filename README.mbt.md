# markitdown-mb

A **MoonBit-based multi-format content processing infrastructure project**, originally inspired by Microsoft **markitdown**.

It is no longer best described as just a “document-to-Markdown converter”. Instead, it is gradually evolving into a reusable foundation for content engineering, including:

* multi-format content parsing
* structural recovery and unified representation
* unified IR (intermediate representation) modeling
* asset export and indexing
* lightweight provenance tracking
* downstream integration for knowledge bases, RAG, auditing, and content processing workflows

The project currently supports **DOCX / PDF / XLSX / PPTX / HTML / CSV / TSV / JSON / Markdown / YAML / ZIP**, and can produce structured Markdown, extracted assets, and metadata sidecars when needed.

Currently supported platforms:

* macOS
* Linux

The project is built around the following unified processing pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

This means the repository should not be understood only as a “format converter”, but as an infrastructure project for content engineering workflows.

## Current Status

Current major capabilities include:

* **DOCX**: heading, list, table, image, block quote, and code-like paragraph recovery, plus hyperlink recovery inside paragraphs, headings, and list items; DOCX images now use unified `ImageBlock` with source-native `descr -> alt_text` and `title -> title` when present
* **PDF**: the default mainflow has been switched to a native structural recovery pipeline, rebuilding text-based PDF structure through event / span / line / block / IR reconstruction; it also supports unified `ImageBlock`, lightweight page-level image provenance, and conservative caption attachment in single caption-like cases
* **XLSX**: worksheet-to-table output, datetime formatting, sparse-region trimming, and multi-sheet output
* **PPTX**: reading-order recovery, title/body separation, list recovery, handling of table-like / caption-like / callout-like regions, conservative caption / nearby-text attachment for single-image slides, basic run-level and shape-level hyperlink recovery, and source-native picture `descr/title` mapping with synthetic alt only as fallback
* **HTML**: lightweight DOM-semantic parsing with support for list / table / block quote / code block / local-container structure recovery, explicit table-header semantics when `<th>` or `<thead>` is present, inline hyperlink recovery, image-context retention for `<img alt>`, `<img title>`, `<figure>`, and `<figcaption>`, and normalized local image `source_path`
* **CSV / TSV**: delimiter-based table conversion with quoted fields, escaped quotes, empty cells, and ragged-row padding
* **JSON**: conservative structured-data conversion for objects, arrays, scalars, and nested values; synthetic object and array-of-objects tables carry explicit header semantics
* **Markdown**: source-preserving passthrough for `.md` / `.markdown`, using `passthrough_markdown` for final output and only normalizing the final trailing newline
* **YAML**: conservative simple-subset structured-data conversion for `.yaml` / `.yml`, mapping common mappings/sequences into table / list / code-block IR, with synthetic mapping tables carrying explicit header semantics
* **ZIP**: safe container conversion for supported text / structured / static HTML entries, with sorted archive paths and blockquote warnings for unsupported, nested, failed, or asset-producing entries

### Short Support Matrix

| Format | Structure | Links | Images | Metadata / Origin | Major Limits |
| --- | --- | --- | --- | --- | --- |
| DOCX | Headings, lists, tables, block quotes, code-like paragraphs, and images are recovered. | External `w:hyperlink r:id` links are preserved in paragraph, heading, and list contexts. | Images use unified `ImageBlock` with source-native `descr/title` when present. | Block origin plus image asset `relationship_id/source_path` are populated. | Footnote/endnote links, revisions, comments, and textboxes are out of scope. |
| PPTX | Slide order, title/body, lists, and layout-aware reading order are recovered conservatively. | Run-level links and one-clear-shape external links are preserved when relationships resolve cleanly. | Images use unified `ImageBlock` with source-native `p:cNvPr descr/title` and conservative single-image caption pairing. | Slide-level block/asset origin plus image `relationship_id/source_path` are populated. | Semantic Table IR, macro/action/media links, and multi-image caption pairing are not enabled. |
| XLSX | Multi-sheet worksheet content is emitted as sheet headings plus tables. | No hyperlink extraction path is currently implemented. | No image conversion path is currently implemented. | Sheet/table origin includes sheet name, source row/column span, and sheet `relationship_id`. | Formula evaluation, merged-cell reconstruction, charts, comments, pivots, and images are out of scope. |
| PDF | Text-oriented structural recovery rebuilds headings, paragraphs, lists, and exported images conservatively. | Annotation/link data exists in debug/model layers but is not emitted as Markdown links by default. | Exported images use unified `ImageBlock` with conservative single-image bbox-gated caption pairing. | Page block origin and image asset `object_ref` are populated on a lightweight basis. | Semantic Table IR, default annotation-link emission, and full complex-layout recovery are not enabled. |
| HTML | Lightweight semantic scanning recovers headings, lists, block quotes, code blocks, and tables; `<th>` / `<thead>` tables use explicit header semantics. | Inline `<a href>` links are preserved in supported rich-inline contexts. | Local images preserve `alt/title`, `figure/figcaption`, and normalized `source_path`. | Block origin is lightweight and local image assets can populate `source_path`. | No browser DOM/CSS/JS rendering, remote fetch, DOM path, block line-range anchoring, or rowspan/colspan reconstruction. |
| CSV / TSV | Delimited text is emitted as one unified `Table` with quoted-newline and ragged-row handling. | No link model is applied. | No image model is applied. | Block origin carries physical line range plus `row_index = 1` and `column_index = 1`. | No streaming, dialect sniffing, schema detection, comments, or type inference. |
| JSON | Objects, regular object arrays, scalar arrays, and ambiguous nested values map conservatively into table / list / code-block IR; object tables use explicit header semantics. | No link model is applied. | No image model is applied. | Root block origin can populate `key_path = "$"`. | No JSON Schema, JSON Lines, streaming, nested provenance, or cell-level metadata. |
| YAML | A simple YAML subset maps conservatively into table / list / code-block IR; mapping tables use explicit header semantics. | No link model is applied. | No image model is applied. | Root block origin can populate `key_path = "$"`. | No anchors, aliases, tags, block scalars, flow style, multi-doc input, nested provenance, or cell-level metadata. |
| Markdown | Source Markdown is preserved as the main output and only conservatively sliced for metadata. | Existing Markdown links are preserved because the original body is passed through. | Existing Markdown image syntax is preserved because the original body is passed through. | Conservative block `line_start/line_end` metadata is available without changing the body. | No Markdown AST parse, rewrite, validation, or remote asset parsing. |
| ZIP | Supported archive entries are converted and concatenated under `# archive/path.ext` headings in normalized path order. | Link support depends on the nested supported entry converter. | ZIP asset namespacing is not enabled yet; entries that produce assets are skipped with a warning. | Entry blocks use the ZIP filename as `source_name` and normalized entry path as `key_path`. | No Office/PDF entries, nested archive recursion, binary preview, streaming, or asset remap. |

Across the current formats, document-style converters prefer readable partial
recovery and conservative downgrade, while syntax-driven structured parsers such
as CSV / JSON / YAML fail closed on invalid syntax instead of guessing.

Current hyperlink preservation status:

* **HTML**: preserves external `<a href>` links in supported rich-inline contexts
* **DOCX**: preserves external `w:hyperlink r:id` links through document relationships
* **PPTX**: preserves run-level `a:hlinkClick r:id` links, with a basic shape-level hyperlink fallback when the whole shape has one clear external link
* All preserved links use the unified `Inline::Link(text, href)` IR and are emitted as Markdown `[text](href)`
* Missing `href`, missing `r:id`, missing relationship, empty targets, internal anchors/bookmarks, actions, macros, and media links are not promoted to Markdown links; they are left as plain text where text is available
* PDF annotation/link records are available in `pdf_core` and convert debug/inspection paths, but the default PDF Markdown output does not emit annotation links yet. Enabling that requires a separate bbox/text matching pass.

Current text-format expansion stages:

* **F1 CSV / TSV**: delimited table text -> unified IR `Table`
* **F2 JSON**: structured data -> unified IR table / `List` / `CodeBlock`, with object tables using explicit header semantics
* **F3 Markdown passthrough**: original Markdown body preserved through `passthrough_markdown`
* **F4 YAML**: simple-subset structured data -> unified IR table / `List` / `CodeBlock`, with mapping tables using explicit header semantics
* **Z1.1a ZIP**: archive container -> sorted supported text / structured / static HTML entry conversion, with warnings for unsupported entries

Current text-format boundaries:

* **CSV / TSV**: no streaming path, dialect sniffing, or schema inference
* **JSON**: no JSON Schema, JSON Lines, or streaming parser path
* **Markdown**: no AST parse and no rewriting of link / image / table / code / frontmatter semantics
* **YAML**: only a simple subset is supported; anchors / aliases / tags / block scalar / flow style / multi-document input are out of scope
* **ZIP**: only `.md` / `.markdown`, `.csv` / `.tsv`, `.json`, `.yaml` / `.yml`, and static `.html` / `.htm` entries are converted; Office/PDF entries, nested archives, binary preview, and asset-producing entries are skipped with warnings

Current table IR status:

* Legacy `Block::Table(Array[Array[String]])` remains supported and keeps its
  historical Markdown behavior: the first row is emitted as the Markdown table
  header.
* `Block::RichTable(TableData)` carries `rows` plus `header_rows` for converters
  that have explicit header semantics.
* For `RichTable`, `header_rows >= 1` uses the first row as the Markdown header;
  `header_rows = 0` emits synthetic `Column N` headers and treats every source
  row as body content.
* If `header_rows > 1`, only the first header row is used as the Markdown header
  today; additional header rows are emitted as body rows.
* HTML only uses `RichTable(header_rows = 1)` when `<th>` or `<thead>` is
  explicitly present. JSON / YAML synthetic object tables use
  `RichTable(header_rows = 1)`.
* CSV / TSV / XLSX / DOCX intentionally continue to emit legacy `Table` for now
  to avoid changing output for sources without explicit header semantics.
* PDF / PPTX heuristic table-like regions are not promoted to semantic Table IR.
* Metadata sidecar version remains `1`; `RichTable` blocks expose additive
  `table: { rows, header_rows }` data while legacy `Table` stays flat-text only.
* Table cell-level metadata, alignment, rowspan/colspan, merged-cell
  reconstruction, and table cell origin are not supported.

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

## Lightweight Provenance and Image Context

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

The current G3 Image context phase has landed the key DOCX / PPTX
consolidation work without changing the metadata schema or Markdown emitter
contract. It includes:

* unified `ImageBlock` / `ImageData` semantics for image-first converters
* DOCX `ImageBlock` upgrade plus source-native `descr/title`
* PPTX source-native picture `descr/title` with synthetic alt fallback

Current unified `ImageBlock` / `ImageData` semantics:

* `path`: emitted asset path
* `alt_text`: source-native image hint when available
* `title`: source-native title-like hint when available
* `caption`: primary semantic caption when confidence is high enough
* `origin`: optional IR-side image origin

Current metadata sidecar image behavior:

* `blocks[].image` serializes `path / alt_text / title / caption`
* `assets[].alt_text / title / caption` are populated by joining the exported
  asset path back to the corresponding `ImageBlock`
* `nearby_caption` remains the asset-origin mirror of the primary caption value,
  not a separate caption-inference slot

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

Current image-context coverage includes:

* HTML: `<img alt>`, `<img title>`, `<figure>`, `<figcaption>`, and local image
  `source_path`
* DOCX: `ImageBlock`, OOXML drawing `descr -> alt_text`, `title -> title`,
  asset-origin `relationship_id / source_path`
* PPTX: `ImageBlock`, `p:cNvPr descr -> alt_text`, `p:cNvPr title -> title`,
  synthetic alt only as fallback, asset-origin `relationship_id / source_path`
* PDF: `ImageBlock`, image provenance via `object_ref`, and conservative
  single-image caption attachment
* XLSX: no image conversion path yet

Its current scope is **lightweight provenance**, rather than a fine-grained anchoring system.

It does **not yet** include:

* default sidecar emission of full PDF `source_refs`
* default sidecar emission of bbox
* HTML DOM path or HTML block line-range anchoring
* table cell-level provenance
* JSON / YAML nested key-path anchoring
* default PDF annotation-link Markdown emission
* PDF / PPTX multi-image caption pairing
* treating OOXML `name` as caption or title
* default PDF bbox / full `source_refs` sidecar emission
* XLSX image support
* remote HTML image fetch

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
