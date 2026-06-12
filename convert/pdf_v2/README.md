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

The product bridge maps semantic text blocks to core paragraphs, headings, list
items, blank lines, safe URI links, materialized image assets when bytes are
available, and conservative text tables. Metadata-only image candidates are
suppressed from visible Markdown. It does not lower captions, forms, OCR, or v1
PDF fallback behavior.

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

## Reset 9C Repeated Header Footer Variants

Reset 9C strengthens page-artifact suppression without changing image, link,
table, caption, or form lowering.

- Product semantic mode now treats parser-attached `PageArtifactCandidate`
  evidence as actionable, so repeated header/footer/page-number facts can
  suppress output through the same semantic noise guard as other text decisions.
- Parser-backed repeated artifacts suppress only at high confidence (`>= 0.90`)
  and still preserve body-band repeats, normal repeated titles, `第一章`-style
  chapter titles, and mixed numeric content.
- Fragment fallback suppression recognizes repeated short running-header/footer
  variants and standalone page labels such as `p. 7`, fractions, dash-wrapped
  numbers, and CJK page labels.
- Page-number suppression remains controlled by `suppress_page_number_like_noise`;
  repeated artifact suppression remains controlled by
  `suppress_repeated_page_artifact_noise`.
- No image, table, caption/figure, form, OCR, v1 fallback, or model hook was
  added.

## Reset 9D Images And Assets

Reset 9D consumes existing parser image facts through the core image convention
without adding byte export or OCR.

- `PdfV2ConvertPipelineOutput` now carries `image_candidates` and
  `inline_image_candidates` from `PdfV2DocumentModel.pages[]`.
- The product bridge emits canonical `@core.Block::ImageBlock(ImageData)`
  entries for image and inline-image facts.
- Because PDF v2 does not yet decode/export image bytes, emitted paths are
  stable metadata-only placeholders such as
  `assets/pdf-v2-image-001.metadata` and
  `assets/pdf-v2-inline-image-001.metadata`.
- Every emitted image placeholder is indexed in `Document.asset_origins` with
  source name, one-based page number, object ref when present, origin id, and a
  `pdf_v2.*.metadata` key path.
- Unsupported or heavy filters remain non-fatal and are represented in the
  image title/metadata instead of triggering fallback.
- The bridge does not create fake image bytes, infer captions, run OCR, recover
  image tables, or fall back to v1 PDF.
- Model hooks remain absent at runtime; image parity is deterministic
  parser-fact consumption.

## Reset 9E Table Parity

Reset 9E adds conservative text-table lowering in the product bridge.

- The product bridge emits canonical `@core.Block::RichTable(TableData)` for
  clear pipe tables and reliable simple aligned text tables.
- Table rules are gated by normalized semantic output and the new
  `enable_table_rules` option.
- Pipe tables require coherent row width and support a standard Markdown
  separator row as the header signal.
- Aligned tables require at least two rows, at least two stable columns, and
  numeric or short-label evidence; ordinary sentences, captions, lists, and
  malformed rows stay paragraphs.
- Parser text-flow candidate mode is guarded against duplicate raw-fragment
  table emission.
- This reset does not do arbitrary visual table detection, merged cells,
  multi-column reading-order repair, image-table OCR, caption inference, v1
  fallback, or model loading.

## Reset 9F Product Parity Sweep Summary

Reset 9F reran the product parity sweep after 9B-9E.

- Validation passed: `moon info && moon fmt`,
  `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf`,
  `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test
  doc_parse/pdf_v2/tests`, `moon test convert/pdf_v2`, and
  `git diff --check`.
- Explicit prebuilt PDF sample run:
  `.tmp/check/runs/pdf-20260612-071917-15495`.
  Main Markdown failures: 24, compared with 23 in the Reset 8/9A comparable
  baseline.
- Metadata-only run:
  `.tmp/check/runs/pdf-20260612-071917-15527`.
  Failures: 15, compared with 13 in the comparable baseline.
- Assets-only run:
  `.tmp/check/runs/pdf-20260612-071917-15591`.
  Failures: 13, compared with 7 in the comparable baseline.
- Quality run:
  `.tmp/quality/runs/pdf-20260612-071917-15754`.
  Rows: 78, checked: 70, skipped: 8, failed: 57.
- Fixed product categories in focused tests: safe URI inline links,
  high-confidence repeated page artifacts, metadata-only image placeholders
  with asset origins, and conservative text tables.
- Sample regressions are expected-diff churn from new visible image metadata
  placeholders and missing `.metadata` files in assets-only checks; real image
  byte export/materialization remains the next asset blocker.
- No expected samples were updated.

## Reset 10 Real Image Asset Materialization

Reset 10 wires parser asset candidates through convert and the PDF CLI writer
path using the existing core/v1 asset convention.

- Pipeline/product path:
  - `PdfV2ConvertPipelineOptions.asset_output_dir` carries the CLI output root.
  - supported candidates are written under `assets/imageNN.ext` with
    `@core.next_image_asset_rel_path_unique`.
  - raw encoded JPEG/JP2/JBIG2 candidates are written unchanged.
  - decoded inline RGB/Gray pixels are wrapped as BMP bytes before writing.
  - materialized pipeline candidates keep `rel_path` and `byte_count` and clear
    in-memory `bytes`.
- Visible ImageBlock policy:
  - emit `ImageBlock(ImageData)` only when `asset.rel_path` is present and
    non-empty.
  - suppress metadata-only or unsupported candidates from Markdown so output
    never contains a broken image reference.
  - alt/title/caption stay empty for materialized PDF v2 images; no diagnostics
    text is written into product Markdown.
- `asset_origins`:
  - keyed by the emitted relative path.
  - include source name, one-based page, object ref when known, and origin id.
  - keep `key_path: None`, matching v1 PDF asset sidecar behavior.
- Sample signal:
  - Reset 9F assets-only had 13 failures from visible placeholders and missing
    `.metadata` assets.
  - Reset 10 assets-only run
    `.tmp/check/runs/pdf-20260612-151859-35645` has 7 failures.
  - fixed cases include `pdf_image_xobject` writing `assets/image01.jpg`,
    ReportLab inline image writing `assets/image01.bmp`, and metadata image
    samples no longer emitting missing `.metadata` references.
- Remaining limitations:
  - Form XObject nested images remain missing.
  - residual sample diffs are mostly text structure/heading parity and
    non-Reset-10 image placement/caption gaps.
  - no v1 fallback, OCR, table-from-image, fake bytes, model loading/training,
    external data access, sample expected updates, or vendor runtime changes
    were introduced.

## Reset 11 Form XObject Images And Caption Facts

Reset 11 consumes the new parser image facts without adding a fallback path or
visual inference.

- Materialized images are interleaved into Markdown by parser source order
  instead of being appended after all text.
- Parser caption facts lower into `ImageBlock.caption`; the same text is
  mirrored into `asset_origins.nearby_caption`.
- The bridge suppresses only the exact caption text whose source refs match the
  consumed parser caption fact, avoiding broad caption inference.
- Nested Form XObject resource paths are copied to asset origin `source_path`
  when available. The image object ref remains `object_ref`; `key_path` remains
  `None` for v1-style PDF asset parity.
- Product output still emits `ImageBlock` only for candidates with real
  materialized asset paths and does not create fake bytes, OCR text,
  table-from-image output, diagnostics Markdown, v1 fallback, or model hooks.

## Reset 12 Table Structure And Sidecar Parity

Reset 12 consumes parser-side table candidates and lowers only high-confidence
text-backed tables to the shared core table block.

- Pipeline:
  - `PdfV2ConvertPipelineOutput` now carries parser `table_candidates`.
  - page-local model tables are flattened into the product bridge input.
- Product bridge:
  - parser-backed candidates with confidence below 0.80 are ignored and their
    text follows the paragraph fallback path.
  - high-confidence parser-backed candidates lower to
    `@core.Block::RichTable({ rows, header_rows, hints: None })`.
  - PDF v2 does not add private table hints, so sidecars avoid extra
    PDF-specific `format` fields.
  - origins use parser page/source refs and table line range; parser-backed
    table origins intentionally omit the text-object `object_ref` so they match
    the existing PDF table sidecar convention.
  - emitted parser-backed tables mark overlapping source refs and matching
    block-index fragments as consumed, preventing split cell text-flow
    duplicates.
- Core sidecar:
  - table metadata is supplied by existing core `RichTable` handling:
    `block_type: "table"`, flat table text, `table.rows`, and
    `table.header_rows`.
  - no new sidecar schema is introduced.
- Sample signal:
  - main Markdown failures improved from Reset 11's 20 to 18.
  - metadata-only failures improved from 9 to 8.
  - assets-only stayed 3.
  - `pdf_simple_table_like` and `metadata/pdf_metadata_table_like` now render
    the expected Markdown table; the remaining table-like metadata sidecar diff
    is document-property parity.
- Boundaries:
  - no OCR, image-table recovery, arbitrary visual table recovery, merged-cell
    reconstruction, fake cells, diagnostics Markdown, v1 fallback, model
    loading/training, or external data access.

## Reset 13 Metadata Sidecar Key Parity

Reset 13 narrows the PDF v2 public metadata sidecar to the current core/v1 PDF
shape.

- `parse_pdf_v2_with_metadata` returns `document_properties: None` for the PDF
  sidecar path, so core emits `document: null`.
- Product bridge block origins keep source name, one-based page, block index,
  and other shared origin fields, but no longer expose PDF object refs.
- Image asset origins still keep the image object ref, but the public origin id
  is v1-style `xobj-image-<object-number>` instead of a PDF v2 private id.
- Nested Form/resource provenance remains parser facts; the asset sidecar now
  omits `source_path` to match existing PDF expected metadata.
- Inline image ids use the v1-style `inline-image-N` prefix.
- Metadata-only sample failures improved from 8 to 4. The remaining two failing
  metadata samples each fail on visible text/block structure first, producing
  `blocks` and `summary` sidecar differences.
- Main Markdown stayed 18 failures and assets-only stayed 3 failures, so this
  reset does not expand visible output or asset materialization behavior.
- No sample expected files, v1 PDF path, diagnostics output, fallback,
  OCR/image-table recovery, full layout recovery, model loading/training, or
  external data access were introduced.

## Reset 14 Text Structure And Noise Merge Parity

Reset 14 narrows PDF v2 visible text/block structure differences for the two
remaining metadata-only text samples.

- Text output lines now retain page and block context through normalization.
- Repeated page-artifact suppression runs after fragment joining, so split
  artifact words such as `Con` + `fi` + `dential` normalize before removal.
- Paragraph joining handles target hardwrap/ligature body text without merging
  repeated headers or footers into body paragraphs.
- CJK chapter headings and decimal-section headings can absorb short split
  heading tails such as `目标`; following body text remains a paragraph.
- Parser text-flow candidate mode now requires actionable list-marker evidence
  and avoids treating decimal section labels such as `1.1` as list candidates.
- Regression coverage was added for the noise-merge body/footer case and the
  split CJK decimal heading-tail case.
- Sample signal:
  - metadata-only improved from Reset 13's 4 failures to 0 in
    `.tmp/check/runs/pdf-20260612-191228-66529`.
  - main Markdown improved from 18 to 15 failures in
    `.tmp/check/runs/pdf-20260612-191248-66777`.
  - assets-only stayed 3 failures in
    `.tmp/check/runs/pdf-20260612-191248-66837`.
- No sample expected files, v1 PDF path, diagnostics output, fallback,
  OCR/image-table recovery, full layout recovery, model loading/training, or
  external data access were introduced.

## Reset 15A Main Markdown Failure Taxonomy And Low-Risk Fixes

Reset 15A keeps the work in convert/productization and narrows only
evidence-backed text/layout patterns from the 15 remaining main Markdown
failures.

- Starting taxonomy:
  - Reset 14 main Markdown had 15 failures in
    `.tmp/check/runs/pdf-20260612-191248-66777`.
  - Buckets were image heading/placement, CJK/ASCII hardwrap, cross-page
    merge/non-merge, repeated header/footer variants, heading/list negatives,
    and two-column paragraph ordering.
- Product fixes:
  - CJK punctuation-to-CJK hardwrap and CJK/short-uppercase-ASCII term
    hardwrap continuations are joined conservatively.
  - Cross-page blank lines can be ignored only when both sides look like an
    unfinished continuation; sentence-ended page breaks still separate blocks.
  - Common section labels followed by intro/body phrases such as `Key points:`
    can promote as headings and infer subsection level after a document lead.
  - Inline CJK body markers such as `第一段：这是...` are guarded from heading
    promotion.
  - Observed ligature split repair includes `di ff erent`.
- Regression coverage:
  - hardwrap positives and unsafe lowercase/sentence-ended negatives.
  - cross-page continuation positive and sentence-ended negative.
  - section-label heading level, intro phrase safety, short body sentence
    safety, and inline CJK body-marker safety.
- Sample signal:
  - main Markdown improved to 10 failures in
    `.tmp/check/runs/pdf-20260612-194329-70975`.
  - metadata-only remained 0 failures in
    `.tmp/check/runs/pdf-20260612-194340-71480`.
  - assets-only remained 3 failures in
    `.tmp/check/runs/pdf-20260612-194340-71483`.
- Boundaries:
  - no sample expected updates, v1 fallback, diagnostics Markdown, metadata
    sidecar schema change, public `object_ref` reintroduction, OCR/image-table
    recovery, full layout recovery, model loading/training, or external data
    access.

## Reset 15R Anti-Patch Audit And Model Readiness

Reset 15R reviews the Reset 14 and Reset 15A productization rules without
changing convert behavior.

- Why it was needed:
  - convert has been carrying parity bridges while parser facts mature.
  - the normalizer is beginning to own boundary, artifact, heading-tail, and
    cross-page decisions that should become parser/model evidence.
- Patch smell findings:
  - exact `di ff erent` repair and English lexical body-merge cues are
    high-risk string patches.
  - CJK/decimal heading-tail splitting and cross-page continuation should be
    represented as boundary facts or model features.
  - repeated artifact suppression should be driven by parser page-artifact
    candidates rather than paragraph text after joining.
  - common section-label and inline CJK body-marker rules are better placed in
    semantic rules than the normalizer, but still need export visibility.
- Keep/move/revisit:
  - keep current Reset 14/15A behavior as temporary bridge behavior.
  - do not add more normalizer/semantic string patches before cleanup/export.
  - move boundary and artifact choices toward parser facts plus offline model
    rows.
- Model readiness conclusion:
  - convert has useful weak labels through semantic rule decisions, confidence,
    reason tags, risk tags, and output alignment.
  - there is no stable gold dataset, dev/test split, quality-lab gate, or real
    model hint path ready for runtime use.
- Next action:
  - prefer `Reset 15B-AuditCleanup`; then add a non-runtime dataset export
    scaffold with weak-label and risk-tag fields.

## Reset 15B Audit Cleanup And Anti-Patch Guardrails

Reset 15B is behavior-equivalent cleanup. It keeps the Reset 14/15A output
bridges in place, but marks their risk and adds tests so they do not grow into
sample-specific product patches.

- Helpers and ownership:
  - `pdf_v2_normalize_known_pdf_ligature_splits` is a closed compatibility
    helper, not a general spaced-letter merger.
  - `pdf_v2_should_suppress_repeated_artifact_paragraph` makes repeated
    evidence the artifact suppression boundary.
  - heading-tail, hardwrap, cross-page, lexical body-merge, repeated artifact,
    and semantic heading guards now carry owner/risk/TODO comments.
  - product bridge candidate mode is documented as parser-fact ownership; it
    does not classify headings, lists, or artifacts from raw text alone.
- Guard tests:
  - known ligature split repair still works; arbitrary spaced letters and
    normal spaces are preserved.
  - CJK/decimal heading-tail repair stays narrow; body colon lines are
    paragraphs.
  - unfinished cross-page continuation still joins, while sentence-ended and
    structural starts do not.
  - repeated artifact-like lines are suppressed only with repeated evidence;
    single occurrences and repeated section titles stay visible.
  - Method-like labels require boundary/body evidence before heading promotion.
  - bridge source guard blocks raw `candidate.normalized_text` classifier
    ownership.
- Migration targets:
  - parser facts for glyph repair, text flow, block boundary, artifacts,
    captions/images, and read order.
  - offline classifiers for boundary, artifact, block kind,
    caption/adjacency, and column/read-order decisions.
- Boundaries:
  - no samples expected updates, fallback, v1 deletion, diagnostics text,
    metadata sidecar schema change, runtime model, external data, quality-lab
    dependency, or `.vscode` change.
  - next recommended task: `Reset 16 Dataset Export Scaffold`, non-runtime
    only.

## Reset 16A Training Stack Audit And Dataset Export Contract

Reset 16A keeps convert behavior unchanged. It defines how convert-side
semantic decisions and parser-produced flow facts should be exported later.

- External training stack:
  - `markitdown-quality-lab/` was present and clean during audit.
  - `text_block_classifier` is the existing convert-facing route.
  - current adapter rows use fields such as `sample_id`, `source_dataset`,
    `source_page_id`, `source_region_id`, `page_no`, `bbox`, `source_label`,
    `target_label`, `target_task`, `text`, `confidence`, `split`, and `notes`.
  - current training uses local-only DocLayNet adapter rows, `baseline_v3`
    features, and sklearn/HGB reports; no main-repo runtime hook exists.
- Convert export alignment:
  - semantic rule decisions and `PdfV2SemanticBlock` evidence map to
    `TextFlowRow.current_rule_decision`,
    `TextFlowRow.current_rule_confidence`, `weak_label`, and `risk_tags`.
  - repeated artifact/noise decisions map to `ArtifactRow`.
  - image/table/link/form adjacency decisions map to `AdjacencyRow`.
  - product output alignment and metadata sidecar alignment are weak labels,
    not gold labels.
- Contract:
  - `docs/archive/pdf-v2-dataset-export-contract.md`.
  - label sources distinguish rule weak labels, DocLayNet layout labels,
    manual gold labels, expected-Markdown weak labels, and metadata sidecar
    weak labels.
- Code scaffold decision:
  - Option A, docs-only.
  - no exporter code yet because row id stability and quality-lab adapter
    flattening need review first.
- Boundary:
  - no product Markdown, metadata sidecar, fallback, training, runtime model,
    model arbitration, external data, quality-lab invocation, or `.vscode`
    change.

## Reset 16B Dataset Exporter Adapter Scaffold

Reset 16B adds an explicit, opt-in dataset exporter scaffold. It is not called
by the default PDF v2 convert path and does not write files.

- API:
  - `pdf_v2_export_dataset_from_pipeline_output`.
  - `pdf_v2_export_dataset_from_fact_arrays`.
  - `pdf_v2_dataset_export_to_jsonl`.
  - `pdf_v2_dataset_export_to_tsv`.
- Row families implemented:
  - `TextFlowRow` from text-flow candidates plus semantic rule decisions.
  - `BoundaryRow` from adjacent text-flow candidates.
  - `ArtifactRow` from referenced page artifact candidates.
  - minimal `AdjacencyRow` from table, image, inline-image, and link facts.
- Stable ids:
  - row ids use `pdfv2:<task>:<safe_doc_id>:p<page>:<suffix>`.
  - callers supply `doc_id`; row ids sanitize it for identifier use.
- Serialization:
  - JSONL is one deterministic flat object per row.
  - TSV uses a fixed shared header and pipe-joined array fields.
  - missing values use `unknown`, `none`, `""`, and empty arrays as documented
    in the dataset contract.
- Labels and risk:
  - semantic rule decisions become weak labels for text-flow rows.
  - parser object/artifact facts stay evidence in family-specific fields and
    risk tags; they do not set `weak_label`.
  - `gold_label` is blank.
  - risk tags are emitted only from current facts, including weak rule labels,
    low geometry confidence, cross-page candidates, artifacts, image captions,
    tables, and links.
- Boundary:
  - no product Markdown, metadata sidecar, samples expected, fallback, runtime
    model, training, model arbitration, quality-lab call, or `.vscode` change.

## Reset 16C Exported Row Quality Audit And Schema Dry-run

Reset 16C adds an in-memory audit helper for the opt-in exporter:

```text
pdf_v2_dataset_export_audit(...)
```

- Counters include row totals, rows by family/task, empty gold labels, weak
  labels, label sources, splits, unknown key fields, source refs, geometry
  unknowns, and risk tag distribution.
- The exporter remains opt-in only; pipeline, product bridge, dispatcher, and
  PDF component runtime paths do not call it.
- Weak labels remain limited to text-flow semantic rule decisions. Artifact and
  adjacency rows carry parser/object evidence without setting `weak_label`.
- JSONL/TSV output is still deterministic and memory-only.
- `doc_id` is caller-provided and preserved; use stable synthetic ids rather
  than local paths or private filenames.
- Existing quality-lab TSV adapters require an intermediate adapter before
  training. `row_id`, `candidate_id`, page index, text, task, split, source
  refs, reason tags, and risk tags can be mapped, but reviewed labels, bbox
  policy, source labels, grouped splits, and feature exclusion still need
  adapter ownership.

## Reset 16D Quality-lab Adapter Mapping Dry-run

Reset 16D keeps the dry-run docs-only and leaves `convert/pdf_v2` runtime and
tests unchanged.

- Quality-lab was inspected read-only:
  - text-block adapter rows use a fixed TSV header ending in `notes`.
  - feature builders exclude ids, labels, provenance, split, text, and notes
    from model feature columns.
  - distilled hint export is downstream of local models, not a main-repo input.
- Mapping result:
  - `TextFlowRow` can become a quality-lab-side preview adapter row after bbox,
    source-label, reviewed-label, and grouped-split policy are supplied.
  - `BoundaryRow` belongs to layout recovery, not the current text-block TSV.
  - `ArtifactRow` and `AdjacencyRow` remain audit/review rows; their parser
    facts are not weak labels.
- Boundary:
  - no adapter helper, generated dataset, product Markdown, metadata sidecar,
    quality-lab dependency, training, runtime inference, or sample expectation
    changed.
  - future adapter code should live under quality-lab adapter/audit tooling so
    public `moon test` and conversion paths stay independent.

## Reset 17A Parser/Layout-backed Parity Facts

Reset 17A adds parser-side fact scaffolding only. `convert/pdf_v2` does not
consume the new facts by default.

- New parser API available for future opt-in callers:
  - `pdf_v2_parity_facts_from_model(model)`.
- Product boundary:
  - product bridge, pipeline, and fact lowerer have a static test guard against
    calling the new fact builder.
  - no Markdown output, metadata sidecar, samples expected, fallback, model
    loading, runtime inference, quality-lab dependency, or training changed.
- Future use:
  - cross-page facts can feed future `BoundaryRow` export and boundary
    arbitration.
  - image-text facts can feed future adjacency/caption rows.
  - header/footer variant and heading-boundary facts can feed audit rows before
    replacing bridge heuristics.
  - column layout facts can feed future reading-order/layout rows once geometry
    and review labels mature.

## Reset 17B Parity Facts Audit And Calibration

Reset 17B remains parser-side and opt-in. `convert/pdf_v2` still does not
consume parity facts.

- Audit helper:
  - `pdf_v2_parity_fact_audit(...)` summarizes fact counts, confidence
    buckets, reason tags, source-ref coverage, insufficient geometry, and
    audit-only versus future-arbitration candidate counts.
- Calibration:
  - weak image-nearby text without caption evidence is explicitly tagged
    `nearby_text_not_caption` and kept below arbitration confidence.
  - header/footer edge variants require repeated edge evidence.
  - heading-risk and two-column facts remain non-decisive signals.
- Product boundary:
  - static convert tests still guard bridge, pipeline, and fact lowerer from
    calling `pdf_v2_parity_facts_from_model`.
  - no product Markdown, metadata sidecar, samples expected, fallback,
    normalizer patch, semantic patch, model loading, runtime inference,
    quality-lab dependency, or training changed.

## Reset 17C Cross-page Fact-backed Arbitration

Reset 17C is the first narrow parser-fact-backed product behavior change. It
only consumes `PdfV2CrossPageBoundaryFact` through the dedicated
`pdf_v2_cross_page_boundary_facts_from_candidates(...)` API; it does not call
the full parity fact builder and does not consume image, header/footer,
heading-boundary, or column facts.

- Join gates:
  - confidence must be at least `0.60`.
  - source refs must be present and match both sides of the page boundary.
  - previous text must be open-ended.
  - the next page start must not be a marker/list, page artifact, page number,
    or heading/title-like blocker.
  - low-confidence, ambiguity, or audit-only tags block product arbitration.
- Fallback:
  - no qualifying fact preserves the existing product path.
  - explicit blockers keep the existing split behavior.
- Scope intentionally untouched:
  - metadata sidecars, assets, images/captions, header/footer suppression,
    heading classification, columns/reading order, samples expected,
    quality-lab, model loading, runtime inference, and training.

## Reset 17D Cross-page Arbitration Effectiveness Audit

Reset 17D adds opt-in in-memory audit helpers for the Reset 17C cross-page
arbitration gates:

```text
pdf_v2_cross_page_arbitration_audit(blocks, facts)
pdf_v2_cross_page_fragment_arbitration_audit(fragments, options, facts)
```

They report generated facts, product-candidate facts, confidence/source/open
ended/marker/tag gate pass counts, rejected low confidence, missing or
mismatched source refs, next marker/list/page-number blockers, next
heading/title-like blockers, no matching pair, actual join decisions, and
fallback-to-existing-behavior counts. The bridge, pipeline, and lowerer do not
call these helpers.

Repo-local validation on June 13, 2026 still reproduces the older
`10`-failure PDF Markdown parity state. A fresh `samples/check.sh --format pdf`
run reports the same 10 Markdown failures:

| bucket | samples |
| --- | --- |
| cross-page merge should happen | `pdf_cross_page_paragraph`, `pdf_cross_page_should_merge_phase15` |
| cross-page split/marker preservation | `pdf_cross_page_should_not_merge_phase15` |
| image placement/caption/nearby heading | `assets/pdf_image_form_xobject`, `assets/pdf_image_inline`, `assets/pdf_image_xobject` |
| header/footer variants | `pdf_header_footer_variants_phase15` |
| heading/list false positives or negatives | `pdf_heading_false_positive_phase15`, `pdf_heading_vs_short_sentence` |
| column/reading order | `pdf_two_column_negative_phase15` |

- Real-sample cross-page audit result:
  - `pdf_cross_page_paragraph` still shows a visible cross-page merge miss, but
    the same diff also includes a heading-level change from `## Next Section`
    to `# Next Section`.
  - `pdf_cross_page_should_merge_phase15` is dominated by title/body boundary
    collapse into one line, so the visible parity failure is not cleanly
    attributable to missing cross-page arbitration alone.
  - `pdf_cross_page_should_not_merge_phase15` preserves the paragraph split, but
    still fails visibly because the next-page heading and list structure
    collapse into plain text.
- Current Reset 17D conclusion:
  - Reset 17C cross-page behavior is retained as-is.
  - no narrow fix was applied in Reset 17D.
  - no threshold lowering, blocker removal, sample expected update, or other
    product-output change was needed in this checkout.
  - the helpers improve diagnosis, but they do not by themselves reduce visible
    parity failures when those samples are still mixed with heading/title/list
    structure differences.
  - the top-level sample wrapper may still print `rows=0` on failing runs
    because its summary parser does not read the current failure header; the
    `markdown-only.entrypoint.log` for the run is the authoritative failure
    record.
- Focused audit coverage:
  - targeted whitebox tests exercise one successful fact-backed join and one
    rejection each for `confidence_below_threshold`,
    `mismatched_source_refs`, `next_heading_title_like_blocker`, and
    `no_matching_fragment_or_semantic_pair`.
  - a no-fact case still preserves existing behavior.
- Next recommended action:
  - keep Reset 17C/17D gates unchanged.
  - add a repo-local PDF v2 sample diagnostic that exposes
    `PdfV2CrossPageBoundaryFact` candidates plus audit counters for the three
    cross-page samples before considering any fact-backed output update.
