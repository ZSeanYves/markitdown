# mb-markitdown Optional Enhancement Chain Architecture

> Path: `docs/architecture/optional-enhancement-architecture.md`  
> Purpose: Defines direct image OCR, the PDF accurate high-fidelity chain, and the audio media chain  
> Document type: Normative architecture document; the formal basis for enhancement design, implementation convergence, and review

This document absorbs and replaces the two earlier focused documents:

1. `ocr-and-pdf-ocr-architecture.md`
2. `audio-media-pipeline-architecture.md`

Companion reading:

1. Read [mb-markitdown-architecture.md](./mb-markitdown-architecture.md) first.
2. Then read this document.
3. For benchmark topics, see [benchmark-architecture.md](./benchmark-architecture.md).
4. For the public support boundary, see [../capabilities-and-limitations.md](../capabilities-and-limitations.md).

---

## 0. Document Status and Scope

This document is the formal architecture guide for the optional enhancement chains.

It follows these principles:

1. The architecture documents take precedence over local implementation details and serve as the target surface for enhancement-chain convergence.
2. Optional enhancement chains are controlled extensions within one product main chain, not independent product stacks.
3. The audio section defines both formal boundaries and forward expansion goals, so that target-state design is not misrepresented as current reality and already-productized capability is not reduced to a mere concept.

This document covers only three enhancement areas:

1. direct image OCR
2. the PDF accurate / high-fidelity route
3. audio `media_pipeline`

---

## 1. Design Principles

All optional enhancement chains must satisfy the following:

1. They must still return to the unified main chain and must not create an independent product stack.
2. Route, provider, fallback, and dependency state must remain explainable.
3. fail-closed behavior takes priority over silent best-effort behavior.
4. mode semantics must not collapse into provider names.
5. enhancement is a controlled extension inside the main chain, not a hidden second CLI.

Unified constraint:

```text
enhancement route
  -> ParseResult
  -> unified pipeline
  -> renderer
  -> provenance
```

---

## 2. Enhancement Chain Categories

The optional enhancement chains fall into three groups:

1. direct image OCR
2. the PDF accurate high-fidelity route
3. the audio media pipeline

What they have in common:

1. They all enter planner vocabulary.
2. They all preserve unified diagnostics / provenance boundaries.
3. They do not allow the renderer to redefine the route.

How they differ:

1. OCR focuses on recovering text from images or pages.
2. PDF accurate focuses on high-fidelity page-level hybrid / OCR / layout behavior.
3. audio focuses on transcript-first media transcription.

---

## 3. Direct Image OCR

### 3.1 Formal product boundary

direct image OCR formally covers:

1. `png`
2. `jpg`
3. `jpeg`
4. `bmp`
5. `webp`
6. `tif`
7. `tiff`

It belongs to the formal product surface and is not a debug-only capability.

### 3.2 Route contract

For direct image input:

1. the planner selects `layout_two_stage`
2. the parser mode is `LayoutTwoStage`
3. the result returns to the unified `ParseResult -> pipeline -> render` flow

This route denotes a product route category, not a provider name.

### 3.3 Provider strategy

The formal target strategy for direct image OCR is:

1. balanced -> `Tesseract`
2. accurate -> `PaddleOCR`

At the same time, the following controlled fallback principles remain in force:

1. the direct-image accurate target may fall back from `PaddleOCR` to `Tesseract` according to target policy
2. any fallback must be explicitly recorded in diagnostics / provenance
3. provider fallback does not change the route family and still belongs to the direct image OCR route

### 3.4 Failure and boundaries

direct image OCR should continue to enforce:

1. explicit dependency diagnostics when dependencies are missing
2. fail-closed behavior when the user explicitly disables OCR
3. no pretending that an image is a normal text format just to force it through the chain

---

## 4. PDF Accurate High-fidelity Chain

### 4.1 Route contract

The formal route contract for PDF is:

1. `Balanced` selects `page_single_pass`
2. `Accurate` selects `layout_two_stage`

Therefore, the formal semantics of PDF accurate are:

```text
PDF accurate
  -> planner selects layout_two_stage
  -> the route internally decides native / hybrid / ocr execution shape from page-level evidence
```

This contract defines the product route. It does not require "whether the PDF is scanned-like" to first determine whether the accurate route exists.

### 4.2 Probe responsibilities

The formal responsibilities of probe for PDF are:

1. provide `page_count`
2. provide `native_text_page_count`
3. provide `scanned_page_count`
4. reuse native PDF artifacts
5. provide explainable evidence for diagnostics / provenance

Probe does not take on the following responsibilities:

1. it is not the sole gate that decides whether the PDF accurate route exists
2. it is not a hidden trigger that upgrades balanced into accurate

### 4.3 Page-level execution model

The accurate PDF route uses a page-level hybrid model internally.

Its page-level execution shapes include:

1. `native_text_page`
2. `hybrid_region_page`
3. `ocr_page`

This means:

1. native-text pages may remain on native output inside the accurate route
2. low-confidence text plus image regions may trigger `hybrid_region_page`
3. pages with empty text layers, or pages that clearly require OCR, may use `ocr_page`
4. one PDF may mix all three page-level result forms

Therefore, the following distinction must stay explicit:

1. the planner freezes the `accurate layout route`
2. page-level native / hybrid / ocr partitioning is an internal execution strategy of that route
3. scanned-like evidence mainly affects page-level execution and diagnostics, not the existence of the accurate route itself

### 4.4 Diagnostics semantics

The accurate PDF route should preserve a set of enhancement diagnostics such as:

1. `pdf_ocr_route_contract=accurate_layout_only`
2. `pdf_ocr_trigger=accurate_layout`
3. `pdf_page_route_summary`
4. `pdf_region_hybrid_used`
5. `pdf_ocr_used`

These facts serve as evidence for:

1. route honesty
2. page-level mixed execution
3. benchmark trust inputs

### 4.5 Provider and runtime boundaries

The formal runtime boundaries for PDF accurate are:

1. the OCR provider target is `PdfAccurate`
2. the default provider is `PaddleOCR`
3. the raster backend is `pdftoppm` / Poppler
4. unlike direct-image accurate, `PdfAccurate` does not require a general provider-fallback target policy

Therefore, PDF accurate is better understood as:

1. a high-fidelity route-level capability
2. a more constrained provider surface
3. a dependency surface that should fail closed or degrade explicitly

### 4.6 The boundary between page OCR and embedded image OCR

This boundary must remain explicit:

1. page OCR in PDF accurate performs OCR / layout processing on the page
2. embedded image OCR performs OCR on one asset image inside the PDF
3. enabling page OCR does not automatically enable embedded image OCR

Otherwise, the system risks:

1. incorrectly OCR-ing normal illustrations
2. allowing figure OCR text to pollute body reading order
3. duplicating work between page OCR and asset OCR

### 4.7 Batch and mode boundaries

The following principles must remain stable:

1. `Balanced` must not be implicitly upgraded to `Accurate` by batch behavior
2. batch processing only carries forward the mode already requested for each file
3. the planner decides the route; the parser must not privately change the mode

---

## 5. Audio Media Pipeline

### 5.1 Formal boundary

The formal product boundary for audio is:

1. prerecorded single-file audio input
2. support for `wav`, `mp3`, and `m4a`
3. canonical route `media_pipeline`
4. a parser that builds `DocumentIR` in a transcript-first manner
5. output that still flows into the unified Markdown / RAG / Debug renderer

The audio parser should preserve:

1. transcript segments
2. time-range source refs
3. backend metadata
4. segment-level speaker / channel / confidence / language metadata when the runtime provides it

### 5.2 Runtime and normalization contract

The runtime contract for audio is:

1. the primary backend is the local Vosk wrapper
2. compressed audio such as `m4a` is normalized through `ffmpeg` when needed
3. whether normalization occurred must be recorded in diagnostics
4. backend transport / name / version must enter metadata and provenance

### 5.3 Probe / planner contract

The planner contract for audio is:

1. the planner must freeze route, profile, and audio options
2. probe must at least provide a basic summary for route decisions and diagnostics
3. normalization-posture or backend-intent fields that have not been formally defined must not be presented as established architecture facts

In other words, audio already stands as a formal enhancement chain, while more fine-grained probe / planner structure may continue to evolve.

### 5.4 Output boundary

audio output still projects uniformly into:

1. Markdown: human-readable transcript
2. RagJson: chunked transcript plus time / source refs
3. DebugJson: structured output for diagnosis

audio does not bypass the renderer.

---

## 6. Forward Expansion Goals for Audio

Audio should continue converging in the following directions:

1. probe provides structured signals such as `duration`, `sample_rate`, `channel_count`, and `normalization_required`
2. the planner explicitly freezes normalization posture in the plan
3. the planner explicitly freezes backend intent in the plan
4. richer same-mode adaptation supports long audio, resource constraints, and multichannel input
5. diarization / multichannel remain optional enhancements rather than P0 prerequisites
6. the transcript model remains a stable middle layer so that raw vendor JSON does not leak into the renderer

This section defines explicit evolution direction. It must not be misread as already part of the formal boundary and therefore requiring one-shot delivery.

---

## 7. Shared Diagnostics / Provenance Contract for Enhancement Chains

Every enhancement chain should answer at least these questions:

1. which route was selected
2. why that route was selected
3. which provider / backend / rasterizer was used
4. whether fallback occurred
5. whether normalization occurred
6. whether any dependency was missing
7. whether the current result is still acceptable to benchmark trust

Important sources of truth for enhancement chains include:

1. `route_plan.selected_route`
2. `route_plan.route_reason`
3. `requested_parser_mode`
4. `effective_parser_mode`
5. `route_fidelity_status`
6. OCR provider selection / resolved kind
7. audio backend transport / name / version
8. page-level summaries or time-range source refs

---

## 8. Boundary with the Core Chain

The enhancement chains in this document do not change the following core facts:

1. `ConvertMode` still has only `Balanced / Accurate / Stream`
2. the renderer does not replan
3. the parser or provider runtime does not redefine the output view
4. the unified benchmark still reads the same provenance fields

Therefore, enhancement chains should be understood as:

```text
planner vocabulary inside one product
```

and not as:

```text
each enhancement has its own independent product
```

---

## 9. Document Synchronization Rules

The following changes should update this document:

1. the route contract for PDF accurate changes
2. the fallback policy for direct-image accurate changes
3. audio probe / planner gain new formal plan fields
4. the audio backend evolves from the existing formal boundary into a stronger formal product line
5. embedded image OCR becomes a productized automatic capability

---

## 10. One-sentence Principle

The optional enhancement chains are controlled extensions inside the formal `mb-markitdown` main chain: OCR and PDF accurate cover high-fidelity routes, while audio covers the transcript-first media chain; implementation should continue converging toward these formal boundaries rather than splitting enhancement capabilities into isolated product stacks.
