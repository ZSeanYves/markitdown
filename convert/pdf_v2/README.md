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

Current productization route:

- The immediate goal is main-chain capability parity with the shipped v1 PDF
  path.
- v2 should first close the v1 product-surface gaps in parser facts, object
  coverage, fact lowering, and the pipeline-to-product bridge.
- A narrow pipeline-to-product bridge now exists for plain text fragments and
  minimal block origins. It is not dispatcher registration and does not replace
  the shipped v1 PDF path.
- After that surface is close enough, the next runtime step is preparing for
  controlled dispatcher registration so expected diffs can drive the remaining
  fixes.
- Model integration is deferred until parser text/object/layout signals are
  stable enough to extract a training set.
- The diagnostics renderer, diagnostics goldens, and adoption scaffold have
  been stopped and removed; they are not the current route.

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
- Parser-stage failures return a fail-closed error result with warnings/risks and
  no fragments.
- Gate-disabled mode preserves the Phase 14 fact-only lowering path.

This is not dispatcher integration, old PDF runtime replacement, semantic
Markdown, heading/list/caption/table/image/link/form lowering, model loading,
layout recovery, external data/model reading, mbtpdf access from convert, or
fallback.

## Phase 20 Product Bridge Status

Phase 20 adds a narrow product bridge:

```text
PdfV2ConvertPipelineResult
  -> @core.Document
```

Current status:

- `pdf_v2_pipeline_result_to_document` converts successful pipeline results into
  a core document.
- Default output now routes `PlainText` fragments through the rule-based
  semantic block system. The current semantic scope is intentionally text-only:
  paragraphs, headings, ordered/unordered list items, continuation paragraphs,
  and plain/unknown fallback to paragraphs.
- Semantic lowering is centralized behind text flow, rule decisions, and
  arbitration. Product bridge options expose `enable_semantic_rules`,
  `enable_heading_rules`, `enable_list_rules`, and `enable_noise_guards`; the
  default enables the rule path for main-chain parity.
- `PageBreak` fragments are ignored by default, matching the v1 product path
  audit where page provenance exists but no dedicated visible page-break block
  was found. Opt-in page breaks and preserved explicit empty-page boundaries use
  core blank-line blocks.
- Low-confidence and unsupported-object notes are disabled by default. When
  explicitly enabled, they emit plain paragraph text only.
- Pipeline failures map to `Result[@core.Document, @core.AppError]` and fail
  closed without old PDF fallback or fake content.
- Product bridge options expose `emit_page_breaks`,
  `emit_low_confidence_notes`, `emit_unsupported_object_notes`,
  `preserve_empty_pages`, semantic rule switches, and `max_output_chars`; the
  default keeps page breaks and notes hidden.
- The bridge preserves minimal block origins where available: source name, page,
  block index, and first object reference. `@core.Document` has no document-level
  format/parser/page-count property slot, so those remain pipeline summaries, not
  document metadata fields.
- A future model-hint/arbitration interface exists for semantic kind hints, but
  the runtime does not load, train, or read model/data files. Rule hard
  constraints take precedence over any future model hint.

Reset 8A records that the semantic rule engine should increasingly consume
parser-owned facts instead of growing convert-only string guesses. The intended
next inputs are line text signals, line layout signals, block boundary signals,
page artifact candidates, and parser-owned text flow candidates. Product bridge
scope remains core block mapping only.

This is not old PDF runtime fallback, caption/table/image/link/form lowering,
model loading, layout recovery, external data/model reading, mbtpdf access from
convert, or fallback.

## Reset 8B-F Parser Fact Consumption Status

Reset 8B-F wires parser-owned facts into the existing Reset 7 semantic rule
engine:

```text
PdfV2FactLoweringResult.text_flow_candidates
  -> PdfV2TextFlowUnit(parser_fact_backed=true)
  -> PdfV2RuleDecision
  -> PdfV2SemanticBlock
  -> @core.Document
```

Current status:

- Fact lowering carries parser `PdfV2TextFlowCandidate[]` alongside fragments,
  and appends candidates only for blocks that pass gate/cap plain-text lowering.
- Product bridge consumes parser-owned candidates when they carry currently
  actionable semantic evidence. The Reset 7 fragment text-flow path remains
  available for normalized paragraph behavior, constructed outputs, and
  semantic-disabled tests.
- Heading rules consume parser title-line and boundary heading scores.
- List rules consume parser marker signals and list boundary scores.
- Continuation rules consume parser continuation boundary scores.
- Noise rules consume parser page-artifact scores and preserve existing product
  switches for page-number and repeated artifact suppression.
- Split page-label sequences such as `第` / `页` / `3/1` are suppressed in the
  centralized semantic noise guard, not as bridge-local string patches.
- `PdfV2ModelHint` and semantic arbitration remain present, but model hints are
  absent at runtime and no model/data file is loaded or trained.

The product bridge still only maps semantic text blocks to core paragraphs,
headings, list items, and blank lines. It does not lower captions, tables,
images, links, forms, OCR, or v1 PDF fallback behavior.

## Reset 9A Metadata Sidecars And Origin

Reset 9A adds metadata sidecar plumbing without changing Markdown block
semantics:

```text
PdfV2DocumentModel.metadata
  -> pdf_v2_metadata_document_properties
  -> parse_pdf_v2_with_metadata
  -> cli_common.write_document_output_with_document_properties
```

- `parse_pdf_v2(...)` remains the dispatcher-compatible document API.
- `parse_pdf_v2_with_metadata(...)` is used by the bundled `pdf` component so
  `--with-metadata` can pass document properties to the existing core sidecar
  writer.
- PDF `/Producer` maps to core `application`; `/Creator` maps to core
  `creator`; `/Author` is used as creator only when `/Creator` is absent.
- Product output does not emit metadata diagnostics into Markdown.
- Link/image/table sidecar parity remains tied to later core block lowering and
  is not added in this reset.

## Reset 9B URI Link Parity

Reset 9B consumes parser-owned URI link facts in the pipeline/product bridge
without broadening the non-text product surface.

- `PdfV2ConvertPipelineOutput` now carries `link_candidates` from
  `PdfV2DocumentModel.pages[].links`.
- The product bridge can emit `RichParagraph`, `RichHeading`, and
  `RichListItem` inline links when semantic URI link rules are enabled.
- Link association is deliberately safe and page-local: accepted candidates must
  be `/Link` annotations with a rect and a safe `http`, `https`, or `mailto`
  URI.
- Exact URI text in the emitted block is preferred and linked only when the URI
  appears exactly once in that block.
- Whole-block fallback is allowed only when the page has exactly one safe URI
  annotation and exactly one emitted text block.
- Ambiguous pages, unsafe or malformed URI candidates, and destination-only
  links stay plain text; the bridge does not invent fake link labels and does
  not fall back to v1 PDF.
- Image, table, caption/figure, and form lowering remain out of scope.
- Model hooks remain absent at runtime; this is a rule/fact bridge only.
