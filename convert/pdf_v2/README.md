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
