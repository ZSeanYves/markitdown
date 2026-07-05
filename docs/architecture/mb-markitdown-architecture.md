# The mb-markitdown Architecture Guide

> Recommended path: `docs/architecture/mb-markitdown-architecture.md`  
> Project scope: `mb-markitdown`, a MoonBit implementation inspired by MarkItDown  
> Document type: normative architecture guide, not tied to one parser library or one temporary implementation stage

Document split:

1. This document defines the unified main chain and the global parser, pipeline, IR, and renderer boundaries.
2. [format-mode-and-execution-profile-architecture.md](./format-mode-and-execution-profile-architecture.md) defines the stable contracts for mode, route, planner, and profile.
3. [ocr-and-pdf-ocr-architecture.md](./ocr-and-pdf-ocr-architecture.md) defines OCR, PDF OCR, layout-provider integration, and trigger rules.
4. [../capabilities-and-limitations.md](../capabilities-and-limitations.md) defines the current public support matrix and maturity conclusions.

---

## 0. Architecture Goal

The core goal of `mb-markitdown` is straightforward:

1. Convert many document and media inputs into Markdown, debug JSON, RAG chunks, and debug-oriented IR views.
2. Offer explicit trade-offs across speed, memory, structural fidelity, and recovery depth.
3. Avoid forcing every format into the same parser shape when their natural structures are different.
4. Converge all parser outputs into one product contract so that all formal entry points stay on one long-term main chain.
5. Preserve source maps, diagnostics, assets, and metadata so the result is traceable, debuggable, and benchmarkable.

This project should be understood as:

- a maintainable long-term open-source conversion project
- strong on complex formats and engineering-grade workloads
- explicit about route fidelity, provenance, and fail-closed boundaries

This project is not trying to become:

1. a full editor-grade semantic model for every format
2. a layout-intelligence-heavy AI platform by default
3. a loose collection of per-format Markdown shortcuts

Instead, the architecture aims to keep these long-term properties stable:

1. most formal formats enter one unified main chain
2. common high-value structure becomes typed canonical data
3. route, profile, and render decisions remain explainable over time
4. new formats and new semantics can evolve inside one planner and one renderer contract

The product should be read as:

```text
Source Format
  -> Parser Native Signals
  -> ParseResult / IRInput
  -> IR Passes
  -> RenderInput
  -> Renderer
  -> Markdown / Debug JSON / Chunks / Debug Output
```

Core principles:

```text
Parsers can be polymorphic.
Core IR must stay unified.
Renderer must stay unified.
SourceMap must stay unified.
Diagnostics must stay unified.
Markdown is an output, not the intermediate representation.
```

Legacy anchor notes that remain intentionally stable:

```text
ContainerRecursive remains a stable container-boundary concept.
page-single-pass remains valid shorthand for source-single-pass parser expectations.
```

---

## 1. Global Layering

### 1.1 End-to-End Pipeline

```text
InputSource
  -> FormatDetector
  -> ParserRegistry
  -> Parser
  -> ParseResult
  -> CoreIRBuilder
  -> IR Pass Pipeline
  -> DocumentAssembler
  -> Renderer
  -> ConvertResult
```

### 1.2 Layer Responsibility

| Layer | Primary responsibility | What it should not do |
| --- | --- | --- |
| `InputSource` | abstract file, bytes, stream, URL, local path, or container entry | not responsible for format semantics |
| `FormatDetector` | detect extension, MIME, magic bytes, and container-internal format | not responsible for full parsing |
| `ParserRegistry` | choose the parser based on format, mode, route, and capability policy | not responsible for parsing content itself |
| `Parser` | read source format and produce facts, blocks, signals, metadata, assets, source refs, and diagnostics | should not directly emit final Markdown or finalize high-level layout conclusions |
| `ParseResult` | unify parser output into one product boundary | should not carry renderer decisions |
| `CoreIRBuilder` | normalize parser-native output into unified core structures | should not read source files directly |
| `IR Pass Pipeline` | do cross-format normalization such as heading, list, table, reading order, and cleanup passes | should not depend on format-specific file libraries |
| `DocumentAssembler` | assemble sections, reading order, table continuation, notes, and captions | should not perform source-format I/O |
| `Renderer` | project the unified representation into Markdown, debug JSON, and chunk views | should not parse source formats or change planner decisions |
| `ConvertResult` | return final content, metadata, diagnostics, assets, and source maps | should not mutate structure again |

---

## 2. Hard Architecture Boundaries

### 2.1 Parser Does Not Generate Markdown

This is the wrong design:

```text
DOCX Parser -> Markdown
PDF Parser  -> Markdown
HTML Parser -> Markdown
```

This is the correct design:

```text
Parser -> ParseResult -> IRInput -> Pipeline -> RenderInput -> Renderer -> Markdown
```

Why this matters:

1. Markdown cannot carry enough information for layout, confidence, bbox, source refs, or asset relationships.
2. Formats like PDF, PPTX, and XLSX need structure evidence before a renderer should decide how to express them.
3. RAG and debug views should not have to reconstruct truth by reparsing Markdown.
4. Direct Markdown concatenation makes later optimization and route reasoning much harder.

### 2.2 Parser Produces Facts and Candidate Signals, Not Final Product Truth

A parser should produce things like:

```text
facts: text, style, bbox, page, row, cell, relationship, xpath
candidates: heading_candidate, list_candidate, table_candidate, caption_candidate
resources: image, attachment, chart, media
provenance: SourceRef
diagnostics: Diagnostics
```

A parser should not prematurely decide:

```text
this must be a level-2 heading
this must be body text
this must not be a header
this table must be rendered as a Markdown table
```

Those decisions belong to IR passes and the renderer.

### 2.3 Source Single-Pass Does Not Mean Whole-Process Single-Pass

Recommended definition:

```text
The source structure should ideally be scanned once.
Core IR may go through multiple passes.
The renderer stays unified at the end.
```

In short:

```text
No repeated source traversal.
Multiple IR passes are allowed.
```

For PDF, DOCX, PPTX, XLSX, HTML, and other richer formats, the parser can stay source-single-pass while the core IR still runs multiple lightweight passes such as:

```text
NormalizeWhitespacePass
MergeTextLinePass
ResolveReadingOrderPass
ResolveHeadingPass
ResolveListPass
ResolveTablePass
RemoveHeaderFooterPass
AssembleSectionTreePass
```

---

## 3. Convert Mode

The user-facing strategy surface should stay small and stable:

```moonbit
pub enum ConvertMode {
  Balanced
  Accurate
  Stream
}
```

### 3.1 Balanced

`Balanced` is the default product mode.

Its contract:

1. prefer mature, stable, cost-controlled canonical routes
2. allow strong semantic recovery when it is supported by structure signals
3. avoid implicit OCR, implicit heavy models, or implicit deep layout upgrades
4. allow same-mode route and profile switching when the format policy supports it

`Balanced` is not:

- a low-end mode
- a degraded mode
- a hidden alias for "cheap parsing only"

### 3.2 Accurate

`Accurate` is the quality-priority mode.

Its contract:

1. it may trigger route-level upgrades such as OCR or layout-oriented routes
2. it may also stay on the same route and enable stronger semantic recovery there
3. enhancements must remain explainable, typed, testable, and regression-friendly
4. it does not promise speculative layout intelligence, macro execution, or unverifiable reconstruction

### 3.3 Stream

`Stream` is the low-peak-resource mode.

Its contract:

1. prefer lower-peak routes, profiles, and flushing behavior where supported
2. keep the same product semantics surface, but with more resource-aware execution
3. not every format is required to have a separate stream-native route
4. unsupported stream requests must fail closed or fall back honestly with a clear warning

### 3.4 RAG and Debug Are Output Views, Not Modes

`RagJson` and `DebugJson` are output projections.

They should not be treated as separate strategy modes.

That means:

1. mode chooses the conversion philosophy
2. route and profile choose the runtime path
3. output view chooses how the result is projected

---

## 4. Parser Modes

The system can internally use several parser shapes as long as they still converge back into the same product contract.

### 4.1 `streaming_event`

Best for naturally sequential formats such as:

- `txt`
- `srt`
- `vtt`
- `csv`
- `tsv`
- large `jsonl` / `ndjson`

Typical traits:

- low peak memory
- naturally ordered event production
- easy chunk-friendly projection

### 4.2 `block_streaming`

Best for formats where the parser can produce stable block units without building a full in-memory document model.

Typical use:

- explicit stream paths for some markup inputs
- large worksheet-like or notebook-like formats
- formats with natural section or row windows

### 4.3 `package_single_pass`

Best for package-based formats such as:

- `docx`
- `xlsx`
- `pptx`
- `odt`
- `ods`
- `odp`
- `epub`

Typical traits:

- scan relevant package parts once
- collect typed facts and source refs
- avoid format-specific Markdown emitters

### 4.4 `page_single_pass`

Best for born-digital PDF or other page-oriented formats where page-level source scanning remains the formal main path.

### 4.5 `dom_ast_model`

Best for formats that benefit from a stable tree model:

- `json`
- `xml`
- `yaml`
- `toml`
- `markdown`
- `html`
- `ipynb`
- text-markup families such as `rst`, `asciidoc`, and `tex`

### 4.6 `layout_two_stage`

Reserved for OCR- or layout-heavy routes, especially:

- accurate PDF OCR
- direct image OCR
- page-level OCR and layout recovery

### 4.7 `media_pipeline`

Reserved for media transcript flows such as:

- `wav`
- `mp3`
- `m4a`

Audio-specific architecture is defined in [audio-media-pipeline-architecture.md](./audio-media-pipeline-architecture.md).

### 4.8 `container_recursive`

Best for containers that dispatch supported child inputs back into the unified main chain:

- `zip`
- explicit stream-style `epub`

---

## 5. Default Format Strategy

The formal product should keep one strategy table, not many entry-specific shortcuts.

At a high level:

- text, subtitle, and delimited formats prefer `streaming_event`
- tree-shaped structured text prefers `dom_ast_model`
- package formats prefer `package_single_pass`
- born-digital PDF prefers `page_single_pass`
- OCR-heavy routes prefer `layout_two_stage`
- audio prefers `media_pipeline`
- recursive containers prefer `container_recursive`

Large-file adaptation is allowed, but only through the planner and only inside the same mode unless the format policy explicitly allows a route-level accurate upgrade.

---

## 6. Core IR Design

The internal representation should allow multiple parser shapes to converge into one stable downstream contract.

Recommended conceptual layers:

1. event-like data for streaming parsers
2. block-like data for block-oriented lowering
3. a document-level assembled representation for rendering and chunk projection

That does not mean every format must always build the heaviest document model up front. It means the renderer and provenance system should still be able to consume a unified shape.

---

## 7. Key Type Families

At the architecture level, the most important type families are:

- `SourceId`, `BlockId`, `AssetId`
- `ParseResult`
- `DocumentIR`
- `CoreBlock`
- `CoreSignal`
- `SourceRef`
- `LayoutBox`
- `StyleRef`
- `AssetRef`
- `Diagnostics`

The exact field layout can continue evolving, but the product-level responsibilities should stay stable:

1. represent structure
2. preserve provenance
3. record diagnostics
4. expose enough typed data for Markdown, debug, and RAG projections

---

## 8. Parser Interface

Every parser should feel format-native internally, but conform to the same outward boundary.

The parser contract should make room for:

- parser capability declaration
- parse context
- resource limits
- prepared source reuse from probe
- diagnostics and provenance

The parser should never silently change the high-level route chosen by the planner.

---

## 9. CoreIRBuilder

`CoreIRBuilder` exists so that parser-specific output can converge into one cross-format representation.

It should:

1. normalize parser-native facts into shared structures
2. preserve source refs and diagnostics
3. expose enough typed detail for IR passes

It should not:

1. reopen the source input
2. redo parser-owned format detection
3. replace planner decisions with hidden policy logic

---

## 10. IR Pass Pipeline

The IR pass layer is where cross-format normalization happens.

Recommended pass families include:

- text normalization
- whitespace normalization
- line merge
- reading-order resolution
- header/footer suppression
- heading resolution
- list resolution
- table resolution
- caption resolution
- asset binding
- section-tree assembly
- RAG chunk projection

Not every format needs every pass, but the architecture should keep one pass vocabulary instead of many per-format render shortcuts.

---

## 11. Renderer Design

The renderer remains the final owner of Markdown output.

That means:

1. parsers do not directly generate final Markdown
2. the pipeline does not directly generate final Markdown
3. the renderer consumes unified structures and stable hints

At minimum the renderer family should cover:

- `MarkdownRenderer`
- `DebugJsonRenderer`
- `RagRenderer`

The renderer may use format-aware hints. It must not secretly re-plan the route.

---

## 12. Format Parser Guidance

This section is intentionally high-level. Detailed per-format behavior belongs in package code, package README files, focused architecture notes, and capability documents.

Still, the project should continue following these stable expectations:

- text-like sequential formats stay cheap and stream-friendly
- structured text formats preserve typed structure when it is cheap and stable to do so
- package formats preserve package-native source refs and assets
- PDF preserves page-level provenance and route honesty
- OCR routes preserve provider, dependency, and fallback diagnostics
- audio routes preserve transcript timing and backend provenance

More detailed OCR and audio rules live in:

- [ocr-and-pdf-ocr-architecture.md](./ocr-and-pdf-ocr-architecture.md)
- [audio-media-pipeline-architecture.md](./audio-media-pipeline-architecture.md)

---

## 13. Format Detection

`FormatDetector` should stay lightweight and deterministic.

It is responsible for:

1. extension- and MIME-based detection
2. magic-byte checks where needed
3. distinguishing package families such as OOXML and EPUB
4. recognizing explicit format families like `ipynb` and `toml` when the policy allows it

It is not responsible for deep semantic parsing.

---

## 14. ParserRegistry and RoutePlanner

`ParserRegistry` and the planner should stay separate:

- registry maps route and format to parser implementation
- planner chooses route, profile, and render-path intent

This separation matters because:

1. registry is runtime wiring
2. planner is product policy
3. provenance should describe policy decisions, not just implementation calls

---

## 15. ConvertOptions

Public options can continue evolving, but they should keep one stable intent surface:

- output format
- mode
- stream request
- PDF OCR policy
- cleanup and table hints
- RAG options
- resource and dependency-related toggles where explicitly supported

The system should continue normalizing them into one internal `ExecutionIntent`.

---

## 16. ConvertResult

`ConvertResult` should remain the single user-facing result boundary.

It should expose:

- rendered content
- metadata
- diagnostics
- assets
- provenance and source-map-facing information

RAG chunk output should be treated as a first-class projection, not as an afterthought.

---

## 17. Error Handling

The project should keep a fail-closed bias.

That means:

1. unsupported capabilities should not silently pretend to succeed
2. missing external dependencies should become explicit diagnostics
3. planner fallback should be honest and explainable
4. OCR/provider fallback should stay explicit and provenance-visible

Recoverable errors can degrade into controlled output. Unsupported or unsafe behavior should remain closed by default.

---

## 18. Resource and Safety Policy

The architecture should continue protecting:

- memory ceilings
- oversized input behavior
- container path safety
- HTML safety boundaries
- OCR and image-processing safety boundaries

These are product concerns, not optional extras.

---

## 19. Module and Ownership Direction

The repository should continue preferring:

- per-format package ownership
- runtime registry wiring
- one renderer stack
- one pipeline stack
- one documented architecture source of truth

The codebase should avoid rebuilding historical root-level facades once a package already has clear ownership.

---

## 20. Testing Strategy

Formal validation should keep covering:

1. unit tests
2. fixture-based regression
3. snapshot or golden output tests where appropriate
4. planner and provenance contract tests
5. benchmark and quality-regression entry points

Document contracts matter too. Architecture docs are part of the long-term maintenance surface, not decoration.

---

## 21. Recommended Delivery Path

The long-term delivery order still makes sense as:

1. core skeleton and contracts
2. main format integration
3. stronger IR passes
4. stable RAG and debug projections
5. constrained high-fidelity capabilities such as accurate OCR and better structured recovery

The important part is not the exact phase names. The important part is keeping one architecture language while the implementation grows.

---

## 22. Final Constraint Checklist

The architecture should keep these constraints stable:

1. Parsers can be polymorphic.
2. Core IR must stay unified.
3. Renderer must stay unified.
4. Markdown is an output, not the intermediate representation.
5. All formal entry points should reuse the same planner-driven main chain.
6. Provenance and diagnostics should explain route and capability behavior.
7. Unsupported behavior should fail closed or fall back honestly with explicit warnings.

---

## 23. One-Sentence Summary

`mb-markitdown` is most successful when it behaves like a single long-term product path with many format-native parsers, one unified core model, one renderer contract, and one honest provenance story.
