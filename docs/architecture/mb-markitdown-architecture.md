# mb-markitdown Core Chain Architecture

> Path: `docs/architecture/mb-markitdown-architecture.md`  
> Purpose: Defines the core main chain, stable abstractions, planner vocabulary, and unified output boundaries  
> Document type: Normative architecture document; the formal basis for implementation convergence, review, and evolution

Document split:

1. This document defines the core chain `detect -> probe -> planner -> parse -> pipeline -> render`, together with the stable boundaries for mode, route, profile, and provenance.
2. [optional-enhancement-architecture.md](./optional-enhancement-architecture.md) defines the optional enhancement chains, including direct image OCR, the PDF accurate high-fidelity chain, and the audio media chain.
3. [benchmark-architecture.md](./benchmark-architecture.md) defines the benchmark system, the trust / gate model, and the formal measurement entry points.
4. [../capabilities-and-limitations.md](../capabilities-and-limitations.md) defines the formal support boundary and the public capability matrix.

---

## 0. Document Status and Scope

This document is the core chain architecture guide for `mb-markitdown`.

Current implementation checkpoint: the public CLI and library share this chain;
unsupported `accurate`/`stream` modes fail before parsing, batch uses the same
planner policy, and output-view selection does not create a route. Capability
documentation is maintained directly from source contracts and executable
tests; the retired standalone capability-document generator is not part of the
architecture.

It follows these principles:

1. The architecture documents take precedence over local implementation details and serve as the target surface for implementation convergence.
2. If the implementation diverges from this document, the preferred action is to drive the implementation toward the document; this document should change only when the architecture decision itself changes.
3. This document defines formal boundaries, formal responsibilities, and formal vocabulary. Temporary implementation details must not be elevated into architecture principles.

This document answers three questions:

1. What is the formal product main chain?
2. Which types and stages form stable long-term boundaries?
3. How should responsibilities be divided between the planner, parser, pipeline, and renderer?

---

## 1. Core Goals

The core goals of `mb-markitdown` are:

1. Project many kinds of document, container, and media inputs into Markdown, RAG JSON, and Debug JSON.
2. Preserve route, source map, diagnostics, assets, metadata, and provenance within one unified product chain.
3. Allow different formats to use different parser shapes, while still converging onto one planner-driven main chain.
4. Preserve fail-closed behavior, route honesty, and benchmark explainability.

Core principles:

```text
Markdown is an output, not an intermediate representation.
The planner is the source of truth for routes, not the parser.
Probe provides evidence; it does not directly freeze the product conclusion.
SourceRef / SourceMap / Diagnostics / Provenance must stay unified.
```

---

## 2. Formal Main Chain

The formal main chain of `mb-markitdown` is:

```text
InputSource
  -> FormatDetector
  -> Probe
  -> Planner / ResolvedExecutionPlan
  -> ParseContext + prepared_source + probe_artifacts
  -> Parser or route-specific parse helper
  -> ParseResult
  -> IRInput -> Unified Pipeline
     or controlled parser-pull stream
  -> RenderInput
  -> Renderer
  -> collected output or OutputSink
  -> ConvertResult + ConvertProvenance
```

The parser-pull branch is permitted only when the selected parser and Markdown
renderer can preserve the canonical output contract while avoiding a retained
source/event array. Its output bytes, diagnostics, metadata, assets, source
maps, route fidelity, and provenance must remain equivalent to the ordinary
`ParseResult -> pipeline -> renderer` path. Parser pull, incremental renderer
sink delivery, and the product-visible `stream` mode are three separate
concepts and must not be used as synonyms.

This main chain carries three formal constraints:

1. `detect`, `probe`, and `planner` must come before parse. A route must not be retroactively decided after parse.
2. Heavy formats may reuse probe artifacts, or use route-specific helpers to inject OCR providers, rasterizers, or prepared artifacts; however, they must still return a unified `ParseResult` and must not bypass the second half of the chain.
3. `plan_input` stops at `ResolvedExecutionPlan` / `RoutePlan`, while `convert_input_with_provenance` executes the full `parse -> pipeline -> render -> finalize` flow.

---

## 3. Layer Responsibilities

| Layer | Formal responsibility | Must not be responsible for |
| --- | --- | --- |
| `InputSource` | Represents tagged path / text / bytes / reader inputs | Format-semantic judgment |
| `FormatDetector` | Detects format from explicit format, MIME, extension, and magic bytes | Route selection |
| `Probe` | Collects lightweight evidence, prepares reusable artifacts, and produces probe summaries | Directly deciding the final route |
| `Planner` | Normalizes intent, consults format policy, and freezes route / profile / parser-mode / provider target | Parsing the source format directly |
| `Parser` / parse helper | Reads the source format and produces `ParseResult` | Generating final Markdown directly or replanning the route |
| `ParseResult` | Serves as the unified parser exit for the product main chain | Carrying renderer-owned decisions |
| `Pipeline` | Performs cross-format normalization, assembly, and render-hint preparation on `IRInput` | Source-format I/O |
| `Renderer` | Projects the unified result into Markdown / RAG / Debug output | Replanning or reparsing the source format |
| `Finalize / Provenance` | Assembles final content, diagnostics, source maps, assets, route fidelity, and provenance | Rewriting structural semantics again |

---

## 4. Stable Abstractions

### 4.1 User-visible strategy surface

The formal user modes remain:

```moonbit
pub enum ConvertMode {
  Balanced
  Accurate
  Stream
}
```

These modes express product strategy philosophy. They do not express parser names or provider names.

The formal output views remain:

1. `Markdown`
2. `RagJson`
3. `DebugJson`

Output views do not change planner ownership of the route.

### 4.2 `ExecutionIntent`

`ExecutionIntent` is the standard input shape for the planner.

It unifies:

1. `mode`
2. `fidelity_mode`
3. `output_mode`
4. `stream_requested`
5. `ocr_options`
6. `audio_options`
7. `limits`
8. `rag_options`

It must not carry format-private route conclusions.

### 4.3 `ProbeOutcome`

`ProbeOutcome` is evidence, not product truth.

It carries:

1. `probe_signals`
2. `probe_failures`
3. `summary_format`
4. `summary_parts`
5. `prepared_source`
6. `probe_artifacts`

Probe may answer "what was observed", but it must not answer "which route is final" in place of the planner.

### 4.4 `FormatStrategyPolicy`

`FormatStrategyPolicy` is the formal strategy table for each format.

It organizes `ModeStrategyPolicy` by `balanced / accurate / stream`, and describes:

1. canonical route
2. explicit stream support
3. soft / hard thresholds
4. hard-limit route
5. lowering / render profile
6. accurate features

This table is planner vocabulary, not parser registry vocabulary.

### 4.5 `ResolvedExecutionPlan`

`ResolvedExecutionPlan` is the execution source of truth.

Once the planner freezes it, the parser, pipeline, renderer, finalize stage, diagnostics, and provenance all read from the same plan.

It should cover:

1. detected format
2. effective mode / fidelity / output mode
3. stream request state
4. selected route
5. execution / lowering / render profiles
6. requested parser mode
7. PDF runtime policies
8. same-mode strategy switches
9. OCR provider selection target / requested kind / resolved kind
10. audio backend metadata shell
11. probe signals / failures / summary / prepared source / probe artifacts

### 4.6 `ParseContext` and `ParseResult`

`ParseContext` is the parser input translated from the plan, carrying:

1. requested parser mode
2. fidelity / output / execution / lowering / render profiles
3. OCR / audio options
4. PDF parser policies
5. coarse resource limits
6. debug flag

`ParseResult` is the parser's only formal exit into the product main chain. Its public shapes are only:

1. `document`
2. `block_stream`
3. `event_stream`

For approved line/table formats the registry may instead expose a controlled
pull handle consumed directly by a matching renderer sink. The completed pull
stream still returns the same parse summary side channels and capability facts
that would have accompanied `ParseResult`.

### 4.7 `Diagnostics`, `SourceRef`, `SourceMap`, and `DocumentAssembly`

These are the core shared side channels across formats:

1. `Diagnostics` records warnings, fallback traces, same-mode switches, metrics, and dependency diagnostics.
2. `SourceRef` unifies provenance dimensions such as page, bbox, line / column, byte range, time range, and container path.
3. `SourceMap` is the shared mapping layer and does not depend on one format's private representation.
4. `DocumentAssembly` is the unified assembly product maintained inside the pipeline, carrying the section tree, reading order, and caption / asset / table-continuation bindings.

---

## 5. Route and ParserMode Vocabulary

The formal route families and parser-mode vocabulary include:

| Term | Formal meaning | Typical formats |
| --- | --- | --- |
| `streaming_event` | Sequential event stream | `txt` `csv` `tsv` `srt` `vtt` `jsonl` `ndjson` |
| `block_streaming` | Stable block stream or windowed block output | Large `html` / `markdown` / `ipynb` / `xlsx` on certain paths |
| `dom_ast_model` | Canonical route centered on a tree model | `json` `xml` `yaml` `toml` `markdown` `html` |
| `package_single_pass` | Single pass over a package format plus typed lowering | `docx` `pptx` `xlsx` `odt` `ods` `odp` `epub` |
| `page_single_pass` | Page-oriented born-digital canonical route | `pdf` balanced |
| `layout_two_stage` | High-fidelity OCR / layout / page-hybrid route | direct image OCR, PDF accurate |
| `media_pipeline` | Media-transcription main route | `wav` `mp3` `m4a` |
| `container_recursive` | Recursive container dispatch back into the unified main chain | `zip`, and some `epub` stream paths |

Route families and parser modes may correspond closely, but their semantics must remain distinct:

1. route is planner vocabulary
2. parser mode is parse-request shape
3. registry is responsible only for locating implementations by `detected_format + requested_mode`, not for product strategy

---

## 6. Planner Contract

### 6.1 Decision order

The planner should operate in this order:

1. detect format
2. normalize public options into `ExecutionIntent`
3. collect `ProbeOutcome`
4. consult `FormatStrategyPolicy`
5. select route
6. freeze execution / lowering / render profile
7. derive parser-mode intent, provider target, and PDF runtime policy
8. record route reason, probe summary, and same-mode strategy switches

### 6.2 same-mode adaptation

same-mode adaptation is allowed, but it must be explicit, explainable, and replayable.

Unsupported product modes fail closed before route selection. A format without
a declared `stream` or `accurate` route must return a non-zero error; it must not
silently select its balanced canonical route.

Formal same-mode adaptations include:

1. `soft_limit_threshold`
   Indicates that probe triggered the medium-adaptive profile.
2. `hard_limit_threshold`
   Indicates that probe triggered the large-adaptive profile or a hard-limit route.

CLI warnings, provenance, and benchmark trust all rely on these explicit records.

### 6.3 Key canonical rules

The following rules belong to the core architecture contract:

1. PDF `Balanced` selects `page_single_pass`.
2. PDF `Accurate` selects `layout_two_stage` as the canonical accurate route.
3. direct image input uses the `layout_two_stage` OCR route.
4. audio input uses `media_pipeline`.
5. Switching the output view to `RagJson` or `DebugJson` does not change the route family.

The page-level hybrid behavior of PDF accurate belongs to the optional enhancement chain. See [optional-enhancement-architecture.md](./optional-enhancement-architecture.md).

---

## 7. Registry, prepared artifact reuse, and route-specific parse helpers

### 7.1 Formal responsibility of `ParserRegistry`

`ParserRegistry` is responsible for runtime wiring:

1. locating the parser list by `detected_format`
2. preferring the parser whose mode matches `requested_mode`, when present
3. otherwise falling back to the canonical default registration

It is not the planner, and it is not the product strategy table.

### 7.2 Formal role of route-specific parse helpers

Route-specific parse helpers are allowed in the following cases:

1. direct image OCR needs OCR-provider injection
2. PDF accurate needs OCR-provider and rasterizer injection
3. probe has already prepared heavy artifacts and those prepared documents / packages / native PDFs should be reused to avoid redundant reads

This does not create a bypass product line, because these helpers must still satisfy:

```text
route-specific helper
  -> ParseResult
  -> IRInput
  -> unified pipeline
  -> renderer
  -> provenance
```

### 7.3 Boundary requirements

Therefore, the formal statement about registry is:

1. registry is the default parser-dispatch entry
2. planner is the product-strategy entry
3. prepared artifact reuse and runtime injection are controlled implementation boundaries in the convert layer, and do not change the unified main chain

---

## 8. Unified Pipeline, `CoreIRBuilder`, and assembly

### 8.1 Public IR entry

The unified pipeline accepts three `IRInput` shapes:

1. `Document`
2. `BlockStream`
3. `EventStream`

All three enter the same pass vocabulary.

### 8.2 Formal role of `CoreIRBuilder`

`CoreIRBuilder` should be understood as the unified IR normalization boundary, not as a subsystem that must be externalized into a standalone stage.

The formal constraints are:

1. `ParseResult` must first converge into `IRInput`
2. the default main path continues inside the unified pipeline
3. event / block shapes may further converge into `DocumentIR` when needed

### 8.3 Formal role of `DocumentAssembly`

`DocumentAssembly` is a unified side channel maintained inside the pipeline, used to carry structural assembly and reading-order state.

The default pass vocabulary includes:

1. `normalize_text`
2. `normalize_whitespace`
3. `merge_text_line`
4. `resolve_reading_order`
5. `remove_header_footer`
6. `resolve_heading`
7. `resolve_list`
8. `collect_asset_refs`
9. `resolve_table`
10. `resolve_caption`
11. `resolve_asset`
12. `assemble_section_tree`
13. `resolve_render_hints`
14. `debug_annotation`

This can be understood as:

```text
ParseResult
  -> IRInput
  -> unified pass pipeline
  -> DocumentAssembly side channel
  -> Renderer
```

---

## 9. Hard Boundaries

The following boundaries must remain stable:

1. parsers do not generate final Markdown directly
2. probe does not directly freeze the final route
3. renderer does not replan
4. Markdown is an output, not an intermediate representation
5. diagnostics / source map / provenance must stay unified across formats
6. CLI, in-process engine, and benchmark must all reuse the same planner-driven main chain

---

## 10. Canonical Strategy Overview

At a high level, format strategy can be grouped as:

1. sequential text / subtitle / delimited text: `streaming_event`
2. tree-shaped structured text: `dom_ast_model`
3. package documents: `package_single_pass`
4. containers: `container_recursive`
5. PDF: `page_single_pass` for balanced, `layout_two_stage` for accurate
6. direct image: `layout_two_stage`
7. audio: `media_pipeline`

This overview answers only main-chain ownership. It does not expand the provider, hybrid-page, or normalization details inside the enhancement chains.

---

## 11. Recommended Reading Order

New readers should approach the project in this order:

1. [README.md](../../README.md)
2. [../capabilities-and-limitations.md](../capabilities-and-limitations.md)
3. this document
4. [optional-enhancement-architecture.md](./optional-enhancement-architecture.md)
5. [benchmark-architecture.md](./benchmark-architecture.md)

---

## 12. Document Synchronization Rules

The following changes should update this document:

1. the boundary of the main chain changes from `detect -> probe -> planner -> parse`
2. a new route family is introduced
3. the product semantics of `ConvertMode` change
4. the source of truth for provenance / trust changes
5. a controlled route-specific helper is elevated into a new formal chain entry

The following changes usually do not require rewriting this document:

1. probe-threshold tuning
2. provider-command parsing details
3. extension of local metric keys for one format
4. heuristic refinement in one pass

---

## 13. One-sentence Principle

The core architecture of `mb-markitdown` is a formal main chain centered on `probe + planner + unified pipeline + provenance`; the implementation should keep converging toward that chain rather than returning to an older organization in which `detect` hands off directly to registry.
