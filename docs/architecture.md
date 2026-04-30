# Architecture Overview

## 1) Overview

The current repository follows a layered unified pipeline:

**CLI -> Dispatcher -> Upper-level Structural Recovery Layer (`convert/*`) -> Lower-level Parsing Infrastructure (`doc_parse/*`) -> Unified IR -> Markdown Emitter / Metadata Emitter / Asset Export**

In this structure:

- `convert/*` is responsible for structure recovery and semantic mapping for specific formats
- `doc_parse/*` provides low-level parsing capabilities (such as ZIP / OOXML / native PDF parsing infrastructure)
- `core/*` is responsible for the unified IR and output contracts

The design goal is not merely “to make a single conversion run”, but to ensure that:

- results are regression-verifiable
- the processing flow is explainable
- the produced artifacts are suitable for engineering consumption

## 2) Layered Responsibilities and Boundaries

### 2.1 CLI Layer (`cli/`)

Responsibilities:

- Parse `normal / ocr / debug` and `--with-metadata`
- Handle output paths (file vs. directory semantics)
- Coordinate whether Markdown and sidecar outputs should be written

Boundaries:

- Does not perform format-level structural analysis
- Does not perform format-level semantic recovery

### 2.2 Dispatcher Layer (`convert/convert/dispatcher.mbt`)

Responsibilities:

- Route inputs to the corresponding parser based on file extension (`docx/pdf/xlsx/pptx/html/csv/tsv/json/yaml/yml/md/markdown`)

Boundaries:

- Only performs dispatch
- Does not contain format-specific strategy

### 2.3 Upper-level Structural Recovery Layer (`convert/*`)

Responsibilities:

- Perform structural recovery and semantic mapping for specific input formats
- Build unified IR based on lower-level parsing results
- Attach additional semantics such as `origin` and `image-context` within the current capability boundary

Current format-expansion stages in this layer:

- F1: CSV / TSV
- F2: JSON
- F3: Markdown passthrough
- F4: YAML

Current converter split:

- Delimited-text converters such as CSV / TSV map source text into unified IR
  `Table` semantics
- Structured-data converters such as JSON / YAML map source content into
  unified IR `Table` / `List` / `CodeBlock` semantics conservatively
- Markdown uses a low-loss passthrough path: it reads UTF-8 source text,
  preserves the original Markdown body, and only builds conservative block
  slices for metadata summary and origin reporting

Boundaries:

- Does not reimplement low-level container parsing or raw format decoding
- Does not directly define the sidecar schema
- Does not directly handle CLI filesystem policy

Current PDF recovery chain (`convert/pdf`):

- `pdf_core` provides the lower-level PDF model consumed by the converter:
  page geometry, text spans/lines/blocks, image records, annotation/link records,
  layout hints, and source provenance.
- The default PDF converter still uses a line-seed strategy. `pdf_core`
  `PdfTextBlock.lines` are flattened into `PdfConvertLine`, and the default
  block staging creates one `PdfConvertBlock` per line.
- `PdfConvertBlock` retains source core block provenance and block-level flags
  such as source block index, source block kind, source block bbox, source block
  line count, core dominant font hints, caption/table flags, language, and
  writing direction. These are currently used for debug and future recovery
  improvements; they do not switch the default converter to core-block seeding.
- Convert-stage page staging also retains image provenance details and page-level
  annotation records for pipeline debug. These are inspect/debug data, not a
  promise of Markdown link emission.
- `classify` is the final converter layer for deciding whether a text block is
  heading, paragraph, or noise. Downstream stages should treat that decision as
  the semantic boundary for heading promotion/demotion.
- `noise` handles repeated edge cleanup. It uses repeated head/tail text
  detection together with page boxes and top/bottom edge zones so body content
  is not removed merely because it is short.
- `merge` handles cross-page paragraph merging. Its decision is layered through
  hard blockers, positive text-continuation evidence, layout compatibility, and
  core-derived continuation support.
- `to_ir` maps already classified converter blocks and images into unified IR.
  It may assign heading role/depth for IR emission, but it does not re-open the
  heading/noise/paragraph classification decision. Nearby image-caption pairing
  remains conservative: it is only attempted on single-image pages, still uses
  the existing caption-like text helper, and now requires a bbox geometry gate
  based on above/below placement, nearby vertical gap, and horizontal
  overlap/alignment. Multi-image caption pairing remains disabled.

### 2.4 Lower-level Parsing Infrastructure (`doc_parse/*`)

Responsibilities:

- Provide low-level parsing infrastructure for document formats
- Support ZIP / OOXML parsing foundations
- Support native PDF parsing foundations
- Provide reusable low-level data inputs for upper-level structural recovery

Typical current components include:

- `doc_parse/zip`: ZIP container handling
- `doc_parse/ooxml`: shared OOXML parsing infrastructure
- `doc_parse/pdf_core`: native PDF parsing foundations

Current `doc_parse/ooxml` capabilities:

- Package query API: open an OOXML ZIP package, list parts, check part
  existence, read part bytes, and query content types by part, prefix, or
  content type.
- Typed relationships: read package-level and part-level `.rels`, preserve
  `Internal` / `External` target mode, resolve internal relationship targets,
  and look up relationships by id or type suffix.
- Media asset index: list `word/media`, `ppt/media`, and `xl/media` assets with
  part name, content type, extension, size, and relationship references pointing
  back to the asset.
- Document properties: read lightweight `docProps/core.xml` and
  `docProps/app.xml` fields for document-level metadata. The metadata sidecar
  uses this for the top-level `document` field on OOXML inputs.
- Debug dump API: render read-only human-readable summaries for package
  structure, relationships, media assets, and properties. This is for diagnosis
  and inspection, not for conversion output.

Current `doc_parse/pdf_core` capabilities:

- Vendored backend integration: `pdf_core` currently runs on a vendored
  `mbtpdf` backend hidden behind `pdf_core/api`, so upper layers do not depend
  on backend-specific types.
- Source-aware raw parsing: operator parsing retains low-level source references
  that can later be surfaced through debug/inspection output.
- Page geometry and provenance: per-page media box, inherited crop box,
  rotation, raw page refs, and raw content stream refs are available to the raw
  layer and inspect helpers.
- Raw images and annotations: page/image extraction and annotation/link raw
  extraction are already present in the parsing substrate.
- Debug inspect API: read-only summaries expose document flags, page geometry,
  content stream refs, text block/line/span counts, image summaries, and
  annotation summaries for diagnosis. Upper `convert/pdf` pipeline debug can
  further surface convert-stage image provenance and page annotations without
  changing normal Markdown output.

Role:

- This layer serves as the parsing substrate beneath the upper-level recovery logic
- It allows the project to distinguish between “raw format parsing problems” and “structure recovery / semantic reconstruction problems”

Boundaries:

- Does not directly define final Markdown semantics
- Does not directly serve as the user-facing conversion layer
- Its outputs are mainly consumed by upper-level `convert/*` modules

### 2.5 Unified IR Layer (`core/ir.mbt`)

Responsibilities:

- Abstract `Document / Block / Inline`
- Maintain `block_origins / asset_origins / ImageData`
- Carry optional `passthrough_markdown` for formats whose final Markdown should
  remain source-preserving rather than emitter-reconstructed
- Represent preserved inline hyperlinks as `Inline::Link(text, href)` across
  supported converters

Role:

- Serves as the unified “explanatory intermediate layer” across formats
- Separates “parsing problems” from “output problems” for easier diagnosis
- Provides a unified input contract for Markdown, metadata sidecars, and future engineering-oriented outputs

Current link preservation contract:

- HTML `<a href>` links, DOCX external `w:hyperlink r:id` relationships, PPTX
  run-level `a:hlinkClick r:id` relationships, and PPTX basic shape-level
  hyperlink fallback all converge on `Inline::Link(text, href)`.
- Missing `href`, missing `r:id`, missing relationship targets, empty targets,
  internal anchors/bookmarks, actions, macros, and media links are not promoted
  to link IR. They remain plain text when text is available.
- DOCX document relationships are cached per document parse; PPTX slide
  relationships are cached per slide. Converters must not re-read `.rels` per
  hyperlink node.
- PDF annotation/link records exist in `pdf_core` and convert debug surfaces,
  but default PDF Markdown output does not emit annotation links until a
  separate bbox/text matching design is accepted.

### 2.6 Markdown Emitter (`core/emitter_markdown.mbt`)

Responsibilities:

- Render IR into stable Markdown main output (for reading)
- Render `Inline::Link(text, href)` as Markdown `[text](href)`
- Prefer `passthrough_markdown` when present, then normalize the tail to
  exactly one trailing newline

Boundaries:

- Does not rewrite parsing strategy
- Does not perform provenance rule decisions
- Does not parse Markdown AST for passthrough inputs
- Does not rewrite Markdown link / image / table / code / frontmatter
  semantics when passthrough mode is active

### 2.7 Metadata Emitter (`core/metadata.mbt`)

Responsibilities:

- Serialize IR + origin / asset information into `*.metadata.json` (for engineering consumption)

Boundaries:

- Does not rewrite the Markdown main body
- Does not participate in upstream structural recovery strategy

### 2.8 Asset Export (parser output + CLI output directory coordination)

Responsibilities:

- Export asset files
- Produce valid references in Markdown
- Together with the metadata sidecar, form a complete output closure of “main text + resources + traceable information”

## 3) Why the Validation System Is Split into `main_process / metadata / assets`

These three validation chains correspond to three different quality dimensions:

- `main_process`: whether structural recovery is correct
- `metadata`: whether provenance and context are stable
- `assets`: whether asset export and references are usable

Benefits of this split:

- Failures can be diagnosed quickly without being masked by mixed failure modes
- Acceptance materials become more intuitive: completion, engineering quality, explainability, and user experience can be evidenced separately
- It helps treat “structural problems”, “metadata problems”, and “asset problems” as different failure surfaces, rather than collapsing them all into a vague “parsing failure”

## 4) Why Metadata Sidecar Is Not Embedded into Markdown Main Content

- The Markdown main body serves the **reading experience**, while the sidecar serves **engineering consumption**
- Mixing sidecar data into the main body would reduce readability and couple the data contract to rendering strategy
- A sidecar file can evolve independently (for example, by adding fields) without breaking the stability of the Markdown output

## 5) Why Metadata Logic Should Not Pollute Main Classification Logic

- The primary goal of the main classification logic is stable structural recovery (headings / paragraphs / lists / tables / image blocks)
- Metadata belongs to the explanation and provenance layer; it is auxiliary engineering information
- If the two are tightly coupled, classification becomes less stable and regression cost increases

## 6) Why a Separate `doc_parse/*` Layer Is Needed

Introducing a dedicated `doc_parse/*` layer is especially important for explainability:

- It allows the project to separate “low-level raw format parsing problems” from “upper-level structural recovery problems”
- When a conversion fails, it becomes much easier to determine:
  - whether the issue occurred in the ZIP / OOXML / PDF raw parsing stage
  - or whether it came from the recovery and semantic reconstruction rules in `convert/*`
- This avoids collapsing all failures into a vague and undifferentiated “parser problem”

In other words, `doc_parse/*` makes both issue diagnosis and architectural explanation much clearer.

## 7) Example of a Single Conversion Data Flow

Using the command:

```bash
moon run cli -- normal --with-metadata ./samples/metadata/pdf/pdf_image_single_caption_like.pdf ./out/demo.md
````

the data flow is as follows:

1. The CLI parses the command arguments and recognizes `normal` and `--with-metadata`
2. The Dispatcher routes `.pdf` input to the PDF parser
3. The upper-level PDF recovery module invokes lower-level capabilities such as `doc_parse/pdf_core` to obtain raw parsing results
4. `convert/*` performs structural recovery on top of those results and builds unified IR (including available origin / asset information)
5. The Markdown emitter writes `./out/demo.md`
6. The metadata emitter writes `./out/metadata/demo.metadata.json`
7. If assets are exported, they are written to `./out/assets/*`, and Markdown references that directory

## 8) Current Phase Boundaries (Architectural View)

* Completed:

  * unified IR
  * multi-format mainflow
  * three validation chains
  * engineering-oriented sidecar output
  * the layered structure between `doc_parse/*` and `convert/*`
  * format expansion F1: CSV / TSV
  * format expansion F2: JSON
  * format expansion F3: Markdown passthrough
  * format expansion F4: YAML
  * first-pass consolidation of shared OOXML and native PDF parsing
    infrastructure
* Still being consolidated:

  * complex PDF layouts
  * ambiguous multi-image / multi-caption scenarios
  * multi-image caption pairing beyond the current conservative single-image-page path
  * richer cross-format metadata consistency
* Future stage:

  * deeper advanced OOXML semantics
  * fine-grained anchoring such as bbox / char-range / object-id
  * semantic reconstruction for more complex layouts

Current text-format expansion boundaries:

- CSV / TSV remain delimited-text converters only: no streaming path, dialect
  sniffing, or schema inference is introduced at this layer
- JSON remains a conservative structured-data route: no JSON Schema, JSON
  Lines, or streaming parser path is introduced
- Markdown passthrough supports `.md` and `.markdown`, reads UTF-8 Markdown
  files, preserves the original Markdown body as the main output, uses
  `passthrough_markdown` as the emitter's preferred source when present, only
  normalizes the final tail to exactly one trailing newline, does not run
  Markdown AST parsing, and does not reinterpret or rewrite link / image /
  table / code / frontmatter
- YAML supports `.yaml` and `.yml` and maps a simple YAML subset into unified
  IR; anchors / aliases / tags / block scalar / flow style / multi-document
  input remain out of scope
- These format additions do not change the metadata sidecar schema; they remain
  on the existing shared `format / source_name / summary / document` contract

```
