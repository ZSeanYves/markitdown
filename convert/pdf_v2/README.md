# PDF v2 Convert Scaffold

`convert/pdf_v2` is an experimental convert package for the PDF v2 architecture
contract. It consumes `@pdfv2.PdfV2DocumentModel` from `doc_parse/pdf_v2`.

Boundaries for this scaffold:

- Convert does not read PDF paths, bytes, streams, or vendor objects.
- Convert does not rescan raw PDF input.
- Convert does not mutate the parser-owned model.
- Parser facts flow forward; Markdown and product policy stay in convert.
- `text_block_classifier` is represented as a convert-layer hint consumer.
- Deterministic rules, model hints, feature support, and risks cooperate
  through explicit gates.
- Low confidence behavior fails closed by abstaining or keeping text uncertain.
- No Python runtime, model file, DocLayNet data, `features.tsv`, `model.pkl`,
  quality-lab artifact, or old PDF fallback is used.

This phase intentionally provides contract-fast scaffolding only. Later phases
can lower to core IR once parser facts and policy gates stabilize.

## Phase 14 Fact-Only Lowering Smoke Status

Phase 14 adds a minimal fact-only lowerer:

```text
PdfV2DocumentModel
  + optional PdfV2FeatureSet
  -> PdfV2FactLoweringResult
```

Current status:

- `pdf_v2_lower_fact_model` consumes only parser model facts and optional
  feature rows.
- Output is limited to plain text fragments, optional page breaks, optional
  low-confidence notes, and optional unsupported-object notes.
- Text lowering follows page/block/line source order. Block text is used when
  present; empty block text may be conservatively assembled from lines with a
  reason tag.
- Unsupported, partial, capped, metadata-only, not-attempted, failed, or
  unknown object facts do not emit Markdown by default. When object placeholders
  are enabled, they emit conservative notes only.
- Low-confidence and missing-geometry notes are disabled by default and stay
  diagnostic when enabled.
- Output caps for blocks, lines, and chars produce warnings, risks, and capped
  summaries.
- The result records `one_pass` and `no_fallback` from parser facts/features.

This is not semantic classification, model gating, heading/list/caption/table
lowering, Markdown image/link/table lowering, dispatcher integration, raw PDF
reading, mbtpdf access, old PDF runtime fallback, external data/model loading,
or core IR adoption.

## Phase 15 No-Model Gate Readiness Status

Phase 15 adds a no-model block decision gate:

```text
PdfV2FeatureSet
  -> pdf_v2_run_no_model_block_gate
  -> PdfV2GateResult
```

Current status:

- The gate consumes only `PdfV2FeatureSet`.
- It is a decision shell for future classifier readiness, not classifier
  inference.
- Decision kinds are limited to `PlainTextCandidate`, `Abstain`, and `Unknown`.
- Decision sources are limited to no-model and guard sources:
  `NoModelGate`, `RuleGuard`, `RiskGuard`, `CapGuard`, and
  `UnsupportedGuard`.
- Unsupported/partial object context, capped context, missing geometry, low
  signal, warnings, and risks contribute to conservative risk scoring or
  fail-closed abstain behavior.
- Plain text candidate confidence is capped at a medium-level value; abstain
  and unknown decisions do not claim high confidence.

This is not heading/list/caption/table classification, model loading, model
training, external `features.tsv`/`model.pkl` reading, Markdown semantic
lowering, dispatcher integration, raw PDF reading, mbtpdf access, or fallback.

## Phase 16 Gate-Aware Fact-Only Lowering Status

Phase 16 lets the fact-only lowerer optionally consume the Phase 15 gate:

```text
PdfV2DocumentModel
  + optional PdfV2FeatureSet
  + optional PdfV2GateResult
  -> PdfV2FactLoweringResult
```

Current status:

- No gate result preserves the Phase 14 fact-only lowering path.
- `PlainTextCandidate` blocks lower to plain text only, preserving source refs
  and reason tags.
- `Abstain` blocks fail closed by default and skip plain text. Optional abstain
  notes use the existing low-confidence note fragment; explicitly allowing
  abstain plain text also records a conservative risk.
- `Unknown` blocks are option-controlled. The default keeps Phase 14 plain text
  behavior, while stricter options can skip text and emit diagnostic notes.
- Missing gate decisions are treated as `Unknown` with a
  `missing_gate_decision` reason tag.
- Gate counts, skipped text counts, missing decisions, and gate notes are
  reflected in the lowering summary.
- Object placeholders remain separately option-gated, and output caps still
  produce warnings, risks, and capped summaries.

This remains fact-only lowering. It does not introduce semantic Markdown,
heading/list/caption/table/image/link/form lowering, model loading, dispatcher
integration, raw PDF reading, mbtpdf access, external data/model reads, or
fallback.

## Phase 17 Experimental Convert Pipeline Status

Phase 17 adds a v2-only experimental path entry point:

```text
PDF path
  -> parse_pdf_v2_model_from_path
  -> pdf_v2_layout_facts_from_model
  -> pdf_v2_features_from_model_and_layout
  -> optional pdf_v2_run_no_model_block_gate
  -> pdf_v2_lower_fact_model
```

Current status:

- `convert_pdf_v2_experimental_from_path` accepts a path only as a thin
  experiment over the parser v2 public path API.
- The lowerer still consumes only the parser model, feature set, and optional
  gate result; it does not read paths or raw PDF bytes.
- Pipeline options expose parser, gate, and lowering options plus `run_gate`.
  The default runs the no-model gate and leaves lowerer gate respect enabled.
- Successful results expose source, model, layout, feature, optional gate, and
  lowering summaries together with fragments, warnings, risks, `one_pass`, and
  `no_fallback`.
- Parser-stage failures return a fail-closed error result with diagnostics and
  no fragments.
- Gate-disabled mode preserves the Phase 14 fact-only lowering path.

This is not dispatcher integration, old PDF runtime replacement, semantic
Markdown, heading/list/caption/table/image/link/form lowering, model loading,
layout recovery, external data/model reading, mbtpdf access from convert, or
fallback.

## Phase 18 Structured Pipeline Diagnostics Status

Phase 18 adds stable diagnostics over the experimental pipeline result:

```text
PdfV2ConvertPipelineResult
  -> PdfV2PipelineDiagnostics
  -> stable diagnostic text
```

Current status:

- Diagnostics consume only `PdfV2ConvertPipelineResult`.
- `PdfV2DiagnosticRow` records section, key, value, optional severity, source
  ref count, and reason tags.
- Fixed sections include pipeline/stages, summary, gate, lowering, caps,
  fragments, warnings, and risks.
- The text renderer starts with `PDF_V2_PIPELINE_DIAGNOSTICS` and emits stable
  key/value rows suitable for future golden, quality, performance, and adoption
  gate tests.
- Ok results render stage summaries, gate/lowering/cap counts, fragments, and
  diagnostics. Err results render error status, failure stage/message,
  diagnostics, and no product fragments.
- Fragment rows include kind, page, char count, and source-ref count rather
  than raw source internals or filesystem paths.

These diagnostics are not product Markdown and are not dispatcher output. They
do not read raw PDFs, call parser path APIs, call mbtpdf, read external
model/data files, introduce fallback, or add semantic Markdown lowering.
