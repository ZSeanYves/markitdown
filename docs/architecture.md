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

- Route inputs to the corresponding parser based on file extension (`docx/pdf/xlsx/pptx/html`)

Boundaries:

- Only performs dispatch
- Does not contain format-specific strategy

### 2.3 Upper-level Structural Recovery Layer (`convert/*`)

Responsibilities:

- Perform structural recovery and semantic mapping for specific input formats
- Build unified IR based on lower-level parsing results
- Attach additional semantics such as `origin` and `image-context` within the current capability boundary

Boundaries:

- Does not reimplement low-level container parsing or raw format decoding
- Does not directly define the sidecar schema
- Does not directly handle CLI filesystem policy

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
  annotation summaries for diagnosis.

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

Role:

- Serves as the unified “explanatory intermediate layer” across formats
- Separates “parsing problems” from “output problems” for easier diagnosis
- Provides a unified input contract for Markdown, metadata sidecars, and future engineering-oriented outputs

### 2.6 Markdown Emitter (`core/emitter_markdown.mbt`)

Responsibilities:

- Render IR into stable Markdown main output (for reading)

Boundaries:

- Does not rewrite parsing strategy
- Does not perform provenance rule decisions

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
  * first-pass consolidation of shared OOXML and native PDF parsing
    infrastructure
* Still being consolidated:

  * complex PDF layouts
  * ambiguous multi-image / multi-caption scenarios
  * richer cross-format metadata consistency
* Future stage:

  * deeper advanced OOXML semantics
  * fine-grained anchoring such as bbox / char-range / object-id
  * semantic reconstruction for more complex layouts

```
