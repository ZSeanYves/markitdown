# PDF v2 Parser Fact Alignment

## 1. Scope

- current commit: `95deabe pdf-v2: add rule-based semantic blocks`
- inspected v1 files:
  - `doc_parse/pdf/README.md`
  - `doc_parse/pdf/api/pdf_api.mbt`
  - `doc_parse/pdf/model/pdf_page_model.mbt`
  - `doc_parse/pdf/model/pdf_text_model.mbt`
  - `doc_parse/pdf/text/pdf_text_blocks.mbt`
  - `doc_parse/pdf/text/pdf_text_lines.mbt`
  - `doc_parse/pdf/text/pdf_text_rules.mbt`
  - `convert/pdf/pdf_lines.mbt`
  - `convert/pdf/pdf_blocks.mbt`
  - `convert/pdf/pdf_classify.mbt`
  - `convert/pdf/pdf_heading_decision.mbt`
  - `convert/pdf/pdf_ir_heading_rules.mbt`
  - `convert/pdf/pdf_ir_text_rules.mbt`
  - `convert/pdf/pdf_ir_title_signals.mbt`
  - `convert/pdf/pdf_layout_gate.mbt`
  - `convert/pdf/pdf_layout_gate_support.mbt`
  - `convert/pdf/pdf_layout_text_signals.mbt`
  - `convert/pdf/pdf_layout_lexical_signals.mbt`
  - `convert/pdf/pdf_layout_feature_signals.mbt`
  - `convert/pdf/pdf_layout_object_signals.mbt`
  - `convert/pdf/pdf_merge.mbt`
  - `convert/pdf/pdf_merge_decision.mbt`
  - `convert/pdf/pdf_merge_boundary_signals.mbt`
  - `convert/pdf/pdf_noise.mbt`
  - `convert/pdf/pdf_noise_decision.mbt`
  - `convert/pdf/pdf_to_ir.mbt`
- inspected v2 files:
  - `doc_parse/pdf_v2/README.md`
  - `doc_parse/pdf_v2/pdf_v2_types.mbt`
  - `doc_parse/pdf_v2/pdf_v2_text_model.mbt`
  - `doc_parse/pdf_v2/pdf_v2_line_reconstruction.mbt`
  - `doc_parse/pdf_v2/pdf_v2_block_reconstruction.mbt`
  - `doc_parse/pdf_v2/pdf_v2_model_assembly.mbt`
  - `doc_parse/pdf_v2/pdf_v2_layout_model.mbt`
  - `doc_parse/pdf_v2/pdf_v2_layout_facts.mbt`
  - `doc_parse/pdf_v2/pdf_v2_object_model.mbt`
  - `doc_parse/pdf_v2/pdf_v2_features.mbt`
  - `doc_parse/pdf_v2/pdf_v2_feature_extraction.mbt`
  - `convert/pdf_v2/pdf_v2_fact_lowering.mbt`
  - `convert/pdf_v2/pdf_v2_text_flow.mbt`
  - `convert/pdf_v2/pdf_v2_semantic_model.mbt`
  - `convert/pdf_v2/pdf_v2_semantic_rules.mbt`
  - `convert/pdf_v2/pdf_v2_semantic_arbitration.mbt`
  - `convert/pdf_v2/pdf_v2_product_bridge.mbt`
- non-goals:
  - no implementation changes in this reset.
  - no sample expected updates.
  - no v1 PDF deletion or fallback to v1.
  - no model loading, model training, or external training/data reads.
  - no OCR, table/image/link/form lowering, or large layout recovery.
  - no mbtpdf vendor runtime change.
  - no quality-lab integration.

## 2. v1 Rule Intent Audit

| category | v1 observed behavior | useful intent | v1 pitfall to avoid | evidence file/function |
|---|---|---|---|---|
| Text line staging | Converts parser text blocks into normalized line units while carrying source block kind, bbox, font, indent, gap, wrap, page-number, header/footer, artifact, caption, and table-cell candidates. | Preserve factual evidence before semantic classification. | Do not let convert become the only owner of facts that parser can provide deterministically. | `convert/pdf/pdf_lines.mbt:build_convert_segments_from_core_line` |
| Block grouping | Groups lines by source block and local geometry, then derives block text, line range, bbox, dominant font, first/last indent, line gaps, and continuation flags. | Semantic rules need stable block-local first/last line facts and boundary evidence. | Avoid baking final heading/list policy into grouping. | `convert/pdf/pdf_blocks.mbt:make_block_from_lines` |
| Heading classification | Collects heading evidence from text shape, line count, page lead, section prefixes, CJK/English title shape, gap before, font size delta, next body/list context, and layout candidates. | Heading should be a decision over combined text, layout, and neighborhood facts. | v1 spreads guards and promotions across nested convert decisions. | `convert/pdf/pdf_heading_decision.mbt:collect_heading_evidence` |
| Heading guards | Blocks headings for page labels, bullets, list item sentences, colon labels, side markers, intro phrases, captions, noise tails, numbered body sentences, body-like punctuation, excessive length, and adjacent heading hazards. | Negative evidence is as important as positive title shape. | Do not copy the full patch forest; expose negative facts and centralize rule arbitration. | `convert/pdf/pdf_heading_decision.mbt:has_blocking_heading_guard` |
| IR heading repair | Final IR still decides document-title role, section depth, and run-in numbered heading splits. | Some heading/body splits require a parser candidate boundary, not just final string surgery. | Avoid final-IR special cases as the primary recovery mechanism. | `convert/pdf/pdf_ir_heading_rules.mbt:decide_heading_role_and_depth_for_ir`, `convert/pdf/pdf_ir_text_rules.mbt:try_split_run_in_numbered_heading_for_ir` |
| List lowering | Parses unordered bullets and lowers them to core list items after convert block classification. | Marker detection should produce marker/body splits while preserving source refs. | Do not keep list parsing as a late product-bridge string patch. | `convert/pdf/pdf_ir_text_rules.mbt:try_parse_bullet_list_item_for_ir`, `convert/pdf/pdf_to_ir.mbt` |
| Layout gate | Uses repeated text, page zones, page labels, font ratio, sentence signals, technical literals, caption/table/link constraints, and list support to demote risky headings or suppress risky list items. | Rule arbitration needs hard constraints and override reasons. | Avoid a parallel gate that competes with semantic rules. | `convert/pdf/pdf_layout_gate.mbt:decide_pdf_layout_list_gate`, `convert/pdf/pdf_layout_gate_support.mbt:layout_gate_feature_values` |
| Text shape features | Computes currency/date/time/address/separator/page-number/bullet/url/email/terminal punctuation/clause punctuation and related lexical flags. | Parser can expose neutral line text signals without claiming final semantic labels. | Avoid duplicating the same string tests in parser, text flow, and product bridge. | `convert/pdf/pdf_layout_text_signals.mbt`, `convert/pdf/pdf_layout_lexical_signals.mbt` |
| Cross-page merge | Merges paragraph boundaries only when body-to-body, sentence continuation, indent, width, gap, wrap, same column band, and core continuation support agree; guards headings, lists, tables, images, captions, noise, page numbers, and column shifts. | Boundary facts should be explicit and explainable. | Do not hide paragraph continuation behind final Markdown normalization. | `convert/pdf/pdf_merge_decision.mbt:collect_page_boundary_merge_evidence` |
| Page artifacts | Builds repeated edge indexes and drops short repeated headers/footers/page numbers near page edges while preserving body-like lines, captions, links, and two-column edge content. | Repeated header/footer/page-number candidates need page-level aggregation. | Avoid ad hoc heading/list guards that rediscover repeated artifact facts one block at a time. | `convert/pdf/pdf_noise_decision.mbt:build_repeated_edge_noise_index`, `convert/pdf/pdf_noise_decision.mbt:collect_edge_noise_evidence` |

## 3. v2 Current Fact Coverage

| fact/signal | current status | evidence | limitation |
|---|---|---|---|
| Source references | present | `PdfV2SourceRef`, `PdfV2LineCandidate.source_refs`, `PdfV2BlockCandidate.source_refs`, `PdfV2TextFlowUnit.source_refs` | Present and useful; future split candidates must preserve subranges, not just block-wide refs. |
| Decode confidence | present | `PdfV2LineCandidate.decode_confidence`, `PdfV2BlockCandidate.decode_confidence`, `PdfV2BlockFeatureRow.avg_decode_confidence` | Good parser-owned fact, but semantic rules currently do not consume it. |
| Geometry confidence | present | `PdfV2LineCandidate.geometry_confidence`, `PdfV2BlockCandidate.geometry_confidence`, `PdfV2BlockFeatureRow.geometry_confidence` | Coverage can be unknown because baselines are often absent. |
| BBox and baseline | partial | `PdfV2LineCandidate.bbox`, `baseline`, `PdfV2BlockCandidate.bbox`; line reconstruction sets `baseline` to `None` | BBox exists when source geometry survives; baseline/line-height/page-relative summaries are not stable semantic facts yet. |
| Line/block gaps | partial | `PdfV2Line.line_gap_before/after`, candidate reason tags | Model type has optional gaps, but candidate reconstruction does not yet compute reliable paragraph/heading gap facts. |
| Indent | partial | `PdfV2Line.indent`, `PdfV2GeometryFeatures.indent`; Reset 7 text flow guesses indent from raw text | Parser does not expose reliable first/last indent, indent delta, or list depth confidence. |
| Font/style facts | partial | `PdfV2Span.font_name/font_size/style_flags`, `PdfV2TextBlock.font_size/style_flags` | No line/block dominant font summary, page median font, relative font score, bold ratio, or neighbor delta fact for semantic rules. |
| Text shape features | partial | `PdfV2TextShapeFeatures.has_list_marker`, `heading_shape_score`, `body_density_guard_score` | Type exists, but current assembly largely leaves these as empty/default and not line-level. |
| Block kind hint | partial | `PdfV2BlockKindHint::{TextLike, Unknown, LowSignal}` | Intentionally weak; not enough for heading/list/artifact boundaries. |
| Page layout facts | scaffold | `PdfV2PageLayoutFacts`, `PdfV2LayoutFactSet`, `recover_pdf_v2_layout_noop` | Counts and coverage only; no true regions, page edge bands, reading-order rows, repeated artifact candidates, or column facts. |
| Feature rows | partial | `PdfV2BlockFeatureRow` | Good for no-model readiness/risk, but lacks semantic text-shape, marker/body split, boundary, page artifact, and font-relative signals. |
| Text flow units | convert-only | `convert/pdf_v2/pdf_v2_text_flow.mbt:pdf_v2_text_flow_signals` | Reset 7 duplicates string-shape logic in convert because parser facts are missing. |
| Heading/list semantic rules | convert-only | `convert/pdf_v2/pdf_v2_semantic_rules.mbt:pdf_v2_semantic_rule_decision` | Centralized and testable, but currently depends on convert-built text-flow guesses rather than parser-owned facts. |
| Repeated header/footer candidates | missing | No v2 parser repeated edge index | Reset 7 only has page-number string guard, not repeated artifact evidence. |
| Page number/artifact shape | missing/convert-only | `pdf_v2_text_flow_signals.looks_like_page_number` | Parser does not expose page-number/page-label candidates or edge support. |
| List marker body split | convert-only | `PdfV2TextFlowMarker` in convert | Parser does not preserve marker range/body range/source refs as facts. |
| Heading/body split candidates | missing | Sample failures still show merged heading/body fragments | Parser does not emit proposed split points for run-in headings or CJK heading/body merges. |
| Block boundary confidence | missing | `PdfV2BlockCandidate.merge_reason_tags/break_reason_tags` exist | Tags exist, but no scored `BlockBoundarySignal` with continuation/new-block evidence. |
| Page artifact aggregation | missing | No v2 analog of v1 repeated edge index | Needed before repeated headers/footers can be guarded without string patches. |

## 4. Gap Matrix

| needed fact/signal | why needed | v1 intent source | current v2 gap | should live in parser/model/convert | priority |
|---|---|---|---|---|---|
| Normalized line text shape | Heading/list/noise rules need stable casing, punctuation, word counts, CJK ratios, numeric ratios, sentence endings, and title-shape flags. | `pdf_layout_text_signals.mbt`, `pdf_heading_decision.mbt` | Mostly convert-only in Reset 7 text flow and semantic rules. | parser/model | P0 |
| Marker candidate with body split | Lists and markdown-like headings need start-of-line marker/body ranges and source refs. | `try_parse_bullet_list_item_for_ir`, `looks_like_list_start` | Convert parses marker text after paragraph shaping, losing source-range precision. | parser/model | P0 |
| Page number/page label candidate | Page labels must be guarded before heading/list decisions. | `is_page_label_like`, `looks_like_page_number_signal`, `collect_edge_noise_evidence` | Only a convert string guard exists. | parser/model | P0 |
| Caption-like prefix candidate | Heading rules need hard negatives for figure/table captions, even if caption lowering is out of scope. | `looks_like_figure_or_table_caption`, layout gate caption constraints | No parser-owned caption-like text signal. | parser/model | P1 |
| First/last line layout summary | Heading and continuation rules need line count, first/last gap, first/last indent, and first/last bbox. | `make_block_from_lines`, `collect_heading_evidence`, `collect_page_boundary_merge_evidence` | Candidate fields exist but no block summary or confidence. | parser/model | P0 |
| Font relative evidence | Heading confidence needs dominant font, page median, neighbor delta, bold/monospace hints. | `is_visually_larger_than_neighbors`, `page_median_font_size`, layout gate features | Span style exists; no page/block summaries. | parser/model | P1 |
| Block boundary signal | Hardwrap vs new paragraph vs new heading/list needs scored evidence and negative guards. | `collect_page_boundary_merge_evidence`, `pdf_blocks.mbt` grouping | `merge_reason_tags` and `break_reason_tags` are unscored and not semantic-ready. | parser/model | P0 |
| Continuation candidate | Product bridge should not infer hardwrap solely from joined text. | `first_is_wrapped_candidate`, `is_same_paragraph_with_prev_candidate` | v2 candidate tags exist, but no explicit continuation score/reason object. | parser/model | P0 |
| Repeated edge artifact index | Repeated headers/footers should not become headings or list items. | `build_repeated_edge_noise_index` | No v2 page-level aggregation. | parser/model | P1 |
| Page edge/body band signal | Page number and header/footer guards need top/bottom/inside-body facts. | `collect_edge_noise_evidence`, layout gate support | Layout facts are source-order/coverage scaffold only. | parser/model | P1 |
| TextFlowCandidate | Convert semantic engine needs a stable parser-produced flow unit instead of rebuilding flow from plain fragments. | v1 line/block staging plus Reset 7 text flow | Current `PdfV2TextFlowUnit` is convert-only. | parser/model with convert mapping | P0 |
| Rule evidence provenance | Debugging expected diffs requires explicit positive/negative reason tags flowing into semantic decisions. | v1 decision summaries and reason tags | v2 has reason tags but lacks structured parser fact categories. | parser/model + convert | P1 |

## 5. Proposed Parser Fact Model Extensions

These extensions are proposed facts/candidates, not final Markdown or core IR
roles. They should be produced by `doc_parse/pdf_v2` and consumed by
`convert/pdf_v2` semantic rules in later resets.

### 5.1 LineTextSignal

Purpose: expose deterministic, source-ref preserving text-shape facts for each
line candidate and optionally aggregate them to block candidates.

Fields:

- `normalized_text : String`
- `trimmed_text : String`
- `char_count : Int`
- `word_count : Int`
- `latin_ratio : Double`
- `cjk_ratio : Double`
- `digit_ratio : Double`
- `punctuation_ratio : Double`
- `uppercase_ratio : Double`
- `is_empty : Bool`
- `is_short : Bool`
- `is_single_token : Bool`
- `has_terminal_sentence_punctuation : Bool`
- `has_clause_punctuation : Bool`
- `ends_with_colon : Bool`
- `looks_like_sentence : Bool`
- `looks_like_title_shape : Bool`
- `looks_like_cjk_title_shape : Bool`
- `looks_like_numbered_section : Bool`
- `looks_like_intro_phrase : Bool`
- `looks_like_separator : Bool`
- `marker_candidate : TextMarkerCandidate?`
- `page_label_candidate : PageArtifactCandidate?`
- `caption_like_candidate : PageArtifactCandidate?`
- `source_refs : Array[PdfV2SourceRef]`
- `reason_tags : Array[String]`
- `confidence : Double`

`TextMarkerCandidate` should stay semantic-neutral:

- `kind : HeadingMarker | OrderedListMarker | UnorderedListMarker | UnknownMarker`
- `marker_text : String`
- `body_text : String`
- `marker_char_start : Int`
- `marker_char_end : Int`
- `body_char_start : Int`
- `body_char_end : Int`
- `indent_prefix_width : Double?`
- `source_refs : Array[PdfV2SourceRef]`
- `reason_tags : Array[String]`
- `confidence : Double`

### 5.2 LineLayoutSignal

Purpose: give semantic rules stable visual/context evidence without requiring
convert to infer layout from raw bbox fields.

Fields:

- `bbox : PdfV2BBox?`
- `baseline : Double?`
- `line_height : Double?`
- `width : Double?`
- `height : Double?`
- `page_x0_ratio : Double?`
- `page_y0_ratio : Double?`
- `page_width_ratio : Double?`
- `page_height_ratio : Double?`
- `top_band : Bool`
- `bottom_band : Bool`
- `left_edge_band : Bool`
- `right_edge_band : Bool`
- `inside_body_band : Bool?`
- `indent_left : Double?`
- `indent_right : Double?`
- `indent_level_hint : Int?`
- `alignment_hint : Left | Center | Right | Justified | Unknown`
- `dominant_font_name : String?`
- `dominant_font_size : Double?`
- `relative_font_size : Double?`
- `font_size_delta_prev : Double?`
- `font_size_delta_next : Double?`
- `style_flags : PdfV2TextStyleFlags`
- `writing_direction : PdfV2WritingDirection`
- `rotation_degrees : Double?`
- `geometry_confidence : PdfV2GeometryConfidence`
- `reason_tags : Array[String]`

### 5.3 BlockBoundarySignal

Purpose: represent line-to-line and block-to-block boundary evidence as
structured parser facts, so convert can decide paragraph/heading/list semantics
without rebuilding boundary logic.

Fields:

- `page_index : Int?`
- `left_block_index : Int?`
- `right_block_index : Int?`
- `left_line_index : Int?`
- `right_line_index : Int?`
- `boundary_kind_hint : SameParagraph | NewParagraph | NewBlock | PageBreak | Unknown`
- `continuation_score : Double`
- `new_paragraph_score : Double`
- `heading_boundary_score : Double`
- `list_boundary_score : Double`
- `geometry_compatible : Bool?`
- `same_column_band : Bool?`
- `indent_delta : Double?`
- `line_gap : Double?`
- `line_gap_ratio : Double?`
- `previous_ends_sentence : Bool`
- `next_starts_lowercase : Bool`
- `next_starts_marker : Bool`
- `next_starts_heading_shape : Bool`
- `hard_negative_tags : Array[String]`
- `reason_tags : Array[String]`
- `source_refs : Array[PdfV2SourceRef]`
- `confidence : Double`

### 5.4 PageArtifactCandidate

Purpose: provide page-number/header/footer/caption-like guards without doing
full non-text semantic lowering.

Fields:

- `kind : PageNumber | PageLabel | HeaderFooter | RepeatedEdgeText | CaptionLike | Unknown`
- `text : String`
- `normalized_key : String`
- `page_index : Int?`
- `block_index : Int?`
- `line_index : Int?`
- `edge : Top | Bottom | Left | Right | None | Unknown`
- `top_band : Bool`
- `bottom_band : Bool`
- `outside_body_band : Bool?`
- `short_text : Bool`
- `repeated_count : Int`
- `repeated_page_ratio : Double`
- `same_edge_repeated : Bool`
- `same_prefix_repeated : Bool`
- `page_number_shape : Bool`
- `page_count_shape : Bool`
- `caption_prefix_shape : Bool`
- `body_like_guard : Bool`
- `link_or_annotation_guard : Bool`
- `source_refs : Array[PdfV2SourceRef]`
- `reason_tags : Array[String]`
- `confidence : Double`

### 5.5 TextFlowCandidate

Purpose: give `convert/pdf_v2` a parser-owned text-flow unit that preserves the
Reset 7 semantic engine boundary while replacing convert-only reconstruction.

Fields:

- `page_index : Int?`
- `block_index : Int?`
- `flow_index : Int`
- `line_start : Int?`
- `line_end : Int?`
- `text : String`
- `normalized_text : String`
- `line_count : Int`
- `char_count : Int`
- `source_refs : Array[PdfV2SourceRef]`
- `line_text_signals : Array[LineTextSignal]`
- `line_layout_signals : Array[LineLayoutSignal]`
- `first_line_text_signal : LineTextSignal?`
- `last_line_text_signal : LineTextSignal?`
- `first_line_layout_signal : LineLayoutSignal?`
- `last_line_layout_signal : LineLayoutSignal?`
- `marker_candidate : TextMarkerCandidate?`
- `artifact_candidates : Array[PageArtifactCandidate]`
- `boundary_before : BlockBoundarySignal?`
- `boundary_after : BlockBoundarySignal?`
- `continuation_candidate : Bool`
- `heading_candidate_score : Double`
- `list_candidate_score : Double`
- `paragraph_candidate_score : Double`
- `artifact_candidate_score : Double`
- `risk_tags : Array[String]`
- `reason_tags : Array[String]`
- `confidence : Double`

## 6. Parser vs Convert Responsibility Boundary

- Parser/model owns facts:
  - source refs and source order.
  - normalized line/block text facts.
  - marker candidates and marker/body split ranges.
  - page label/page number/caption-like/page artifact candidates.
  - geometry, page-relative layout, font/style, first/last line summaries.
  - boundary candidates and confidence/reason tags.
  - low-signal, missing-geometry, unsupported, and ambiguity risks.
- Convert semantic rules own decisions:
  - final `Paragraph`, `Heading`, `OrderedListItem`,
    `UnorderedListItem`, `Continuation`, `PlainText`, and `Unknown`.
  - rule IDs, thresholds, hard negative rules, and arbitration.
  - mapping semantic blocks to `@core.Document`.
  - product options such as enabling/disabling heading/list/noise rules.
- Product bridge stays thin:
  - consume semantic blocks.
  - map to `@core.Block::Paragraph`, `@core.Block::Heading`, and
    `@core.Block::ListItem`.
  - preserve origins.
  - no string patch expansion.
- Future model hook stays in convert arbitration:
  - parser facts can be features.
  - model hint remains absent until a later model reset.
  - rule hard constraints still outrank model hints.
- Normalizer stays cleanup-only:
  - paragraph shaping and whitespace cleanup are acceptable.
  - recovering missing parser facts in the normalizer is not acceptable.

## 7. Implementation Plan

- Reset 8B: add parser-owned `LineTextSignal` and marker/page-label/caption-like
  candidates.
  - Keep facts deterministic.
  - Add synthetic parser/model tests.
  - Do not change sample expected files.
- Reset 8C: add `BlockBoundarySignal` and first/last line summaries.
  - Focus on hardwrap, paragraph boundaries, list starts, and heading/body
    split evidence.
  - Preserve source refs and reason tags across split candidates.
- Reset 8D: add page artifact aggregation.
  - Build repeated edge text/page-number/header-footer candidates.
  - Keep caption-like output as guard facts only; do not lower captions.
- Reset 8E: make `convert/pdf_v2` semantic rules consume parser facts.
  - Keep Reset 7 centralized semantic rule engine.
  - Remove duplicate convert-side string guesses as parser facts become
    available.
  - Keep model hints absent.
- Reset 8F: rerun PDF expected diff and tune thresholds only where parser facts
  provide explicit evidence.
  - Do not add sample-specific patches.
  - Record fixed cases, regressions, and remaining blockers.

## 8. Risks

- Fact explosion: adding many booleans can recreate v1 complexity unless each
  fact has a clear owner, source, reason tag, and test.
- Premature semantics in parser: parser facts should be candidates/scores, not
  final Markdown roles.
- Geometry sparsity: v2 may still lack reliable baseline/font/page bands on some
  PDFs; every layout signal needs confidence and missing-data behavior.
- Duplicate string rules: Reset 7 convert text-flow rules should be retired
  gradually as parser facts land, or parity behavior will become hard to reason
  about.
- Overfitting sample names: implementation should target fact classes such as
  marker/body split, repeated edge text, and sentence guards, not individual
  expected files.
- Model timing: adding a model before facts stabilize would train on unstable
  labels and make rule/model disagreements noisy.

## 9. Acceptance Criteria

- Parser emits deterministic line text signals with source refs, reason tags,
  and tests.
- Parser emits marker candidates for heading markers, unordered markers, and
  ordered markers without lowering them to core list/heading blocks.
- Parser emits page-number/page-label candidates and caption-like guard
  candidates without caption lowering.
- Parser emits block boundary facts for continuation vs new paragraph vs new
  block with confidence and negative guard tags.
- Parser emits repeated edge artifact candidates across pages before convert
  semantic rules decide final text/noise behavior.
- Convert semantic rules consume parser facts through the existing Reset 7
  semantic engine.
- Product bridge remains a mapper from semantic blocks to core blocks.
- No fallback, model loading, external data, OCR, table/image/link/form
  lowering, vendor runtime change, or sample expected update is introduced.

## Reset 8B-F Parser Facts To Semantic Consumption

- facts implemented:
  - `PdfV2LineTextSignal` records normalized text, char/word counts,
    sentence punctuation, ordered/unordered marker candidates, page-number and
    caption guards, title/noise shape, decode confidence, and reason tags.
  - `PdfV2BlockBoundarySignal` records first/last line text, line count,
    optional future layout/font fields, heading/list/continuation/artifact
    scores, boundary confidence, and reason tags.
  - `PdfV2PageArtifactCandidate` records page-number, caption-like, and
    repeated short-line candidates with page indices, repeat count, page band,
    confidence, source refs, and reason tags.
  - `PdfV2TextFlowCandidate` records parser-owned flow units with original and
    normalized lines, line indices, line signals, boundary signal, artifact
    refs, source refs, and reason tags.
- model integration:
  - `PdfV2LineCandidate` now embeds `text_signal`.
  - `PdfV2BlockCandidate` now embeds `boundary_signal`.
  - `pdf_v2_build_text_flow_candidates(model)` builds parser-owned flow
    candidates from page/block/line facts without adding final semantic roles
    to the parser model.
- semantic consumption path:
  - `convert/pdf_v2` lowering carries `text_flow_candidates` alongside plain
    fragments.
  - Reset 7 semantic rules consume parser-backed flow candidates when they
    carry currently actionable evidence, and keep fragment-derived text flow
    available for normalized paragraph behavior, tests, and constructed
    outputs.
  - Heading/list/continuation/noise rules consume parser scores and line
    signals, while final semantic decisions remain in convert.
- page artifact behavior:
  - standalone page numbers and page labels are parser facts and can be
    suppressed by the existing product noise option.
  - split page-label sequences such as `第` / `页` / `3/1` are suppressed by a
    centralized semantic noise guard.
  - repeated short-line artifacts are conservative: title-like, list-like,
    caption-like, and sentence-like body lines are excluded before semantic
    suppression.
  - caption-like candidates remain guard facts only; no caption lowering was
    added.
- expected diff result:
  - explicit built PDF sample run
    `.tmp/check/runs/pdf-20260611-152859-63255` reports 23 non-empty main
    Markdown diffs, matching the Reset 7/8A baseline.
- remaining blockers:
  - parser geometry/font bands remain sparse.
  - no full column detection or layout recovery was added.
  - image/link/table/form and metadata sidecar parity remain out of scope.
  - model hooks remain absent at runtime.

## Reset 9A Metadata Sidecars And Origin

Reset 9A promotes existing metadata candidates into document-level parser facts:

```text
PdfV2MetadataCandidate(Info)
  -> PdfV2DocumentMetadata
  -> @core.MetadataDocumentProperties
  -> metadata sidecar document section
```

Current status:

- `PdfV2DocumentMetadata` records title, author, subject, creator, producer,
  keywords, created, modified, and source refs.
- Model assembly maps Info dictionary keys (`/Title`, `/Author`, `/Subject`,
  `/Creator`, `/Producer`, `/Keywords`, `/CreationDate`, `/ModDate`) without
  parsing XMP or inventing missing values.
- Convert maps PDF v2 metadata to the existing core sidecar convention. Core has
  no separate author slot, so author is preserved in the v2 model and used as
  sidecar creator only when creator is absent.
- Page count is provided from the parser model page count.
- Block origins remain product-bridge origins and continue to carry page/source
  refs; no visible diagnostics are emitted into Markdown.

Still out of scope:

- XMP parsing beyond existing metadata object facts.
- Source path fields not supported by the current core document-properties
  shape.
- link/image/table metadata parity, which must come from core block lowering in
  later Reset 9 batches.

## Reset 9B URI Link Parity

Reset 9B consumes parser-owned link facts in convert without moving product
semantics into the parser:

```text
PdfV2LinkCandidate[]
  -> PdfV2ConvertPipelineOutput.link_candidates
  -> safe product bridge association
  -> @core.Inline::Link
```

Current status:

- Parser/object URI facts are carried forward from page `links` into pipeline
  `link_candidates`.
- Convert product policy accepts only safe `/Link` URI annotations with rects
  and `http`, `https`, or `mailto` schemes.
- Association stays page-local. Exact URI text match wins when the URI appears
  exactly once in the emitted block.
- Whole-block fallback is limited to exactly one safe URI annotation and exactly
  one emitted text block on the same page.
- Ambiguous same-page links, unsafe/malformed URI values, and destination-only
  or non-URI facts are ignored for visible link lowering and keep plain text
  behavior.
- Product bridge scope remains narrow: no image, table, caption/figure, or form
  lowering was added.
- The model hook remains absent at runtime; URI link parity is deterministic
  rule/fact consumption only.

## Reset 9C Repeated Header Footer Variants

Reset 9C improves parser-owned page artifact facts and keeps the convert
semantic boundary intact:

```text
PdfV2LineTextSignal
  -> PdfV2PageArtifactCandidate
  -> PdfV2TextFlowCandidate.artifact_refs
  -> convert semantic noise guard
```

Current status:

- Parser line signals recognize more page-number variants, including `p. N`,
  fraction labels, and spaced CJK page labels.
- Repeated artifact candidates track top/body/bottom bands and avoid
  high-confidence suppression facts when the repeated text appears in the body
  band.
- Top/bottom repeated lines can become high-confidence `HeaderLike` or
  `FooterLike` facts; normal repeated titles, `第一章` chapter labels, and mixed
  numeric body content remain ordinary text facts.
- Convert consumes attached page-artifact facts only through the semantic noise
  guard and requires high confidence for repeated non-page-number suppression.
- No image, link, table, caption, form, OCR, layout-model, v1 fallback, or
  runtime model hook was added.

## Reset 9D Images And Assets

Reset 9D consumes existing parser image facts without moving asset export or
semantic image policy into the parser:

```text
PdfV2ImageCandidate[] / PdfV2InlineImageCandidate[]
  -> PdfV2ConvertPipelineOutput.image_candidates
  -> metadata-only ImageBlock placeholders
  -> Document.asset_origins
```

Current status:

- Parser image facts remain factual candidates with page index, dimensions,
  filters, source refs, warnings, risks, reason tags, and decode status.
- The pipeline carries page image and inline-image facts forward; convert owns
  `ImageBlock` creation and asset-origin indexing.
- Current byte capability remains metadata-only. Unsupported filters are
  non-fatal facts/reports, not fallback triggers.
- Product output uses stable `.metadata` placeholder paths because no actual
  image bytes are exported yet.
- No fake image bytes, OCR, caption inference, table-from-image recovery,
  layout-model hook, v1 fallback, or model prediction was added.

## Reset 9E Table Parity

Reset 9E keeps table semantics in convert while consuming parser text facts:

```text
PdfV2FactFragment.text / PdfV2TextFlowCandidate guards
  -> conservative product bridge table detection
  -> @core.RichTable(TableData)
```

Current status:

- Parser text-flow facts remain evidence; they do not become final parser table
  roles.
- Convert lowers coherent pipe tables and reliable simple aligned text tables
  to `RichTable(TableData)` under `enable_table_rules`.
- Parser-backed candidate mode guards against duplicate table emission from the
  raw fragment when a parser text-flow candidate already represents that block.
- Malformed table-like text, ordinary paragraphs, captions, list-like rows, and
  image-only evidence remain plain text or image metadata placeholders.
- No image OCR, arbitrary visual table detection, merged-cell reconstruction,
  multi-column reading-order recovery, v1 fallback, external model/data file, or
  runtime model hook was added.

## Reset 9F Product Parity Sweep Summary

Reset 9F closes the 9A-9F resume batch with parser facts still separated from
product policy.

Current status:

- Parser facts consumed by product parity now include metadata, URI links,
  page artifacts, image/inline-image metadata, and text/table evidence.
- Convert remains responsible for safe association and final core block
  lowering.
- Final validation passed: `moon info && moon fmt`,
  `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf`, the
  requested test matrix, `moon test convert/pdf_v2`, and `git diff --check`.
- Sample checks with explicit prebuilt CLIs remain red: main Markdown 24,
  metadata-only 15, assets-only 13, quality 57 failures out of 70 checked rows.
- URI sample failures are no longer present in the main Markdown failure list.
- New image placeholders intentionally avoid fake bytes, but assets-only now
  reports missing `.metadata` assets because no materialized asset export exists
  yet.

Remaining parser/fact work:

- stable geometry/font/table-region facts for richer table and block recovery.
- image byte/export capability if v2 should satisfy assets-only expectations.
- annotation, form, outline, internal destination, caption, and richer layout
  facts before broader product parity.
- no model/data file is loaded or trained until these factual boundaries are
  stable.

## Reset 10 Real Image Asset Materialization

Reset 10 keeps parser facts factual while adding a narrow byte-bearing image
asset candidate for cases where mbtpdf already exposes trustworthy bytes:

```text
PdfV2ImageCandidate.asset / PdfV2InlineImageCandidate.asset
  -> PdfV2ConvertPipelineOptions.asset_output_dir
  -> assets/imageNN.ext materialization
  -> ImageBlock + asset_origins
```

Current status:

- `PdfV2ImageAssetCandidate` records the materialization state:
  `RawEncoded`, `Decoded`, or `Unavailable`, plus MIME, extension, byte count,
  optional bytes, status, and reason tags.
- XObject images can expose raw encoded assets for signature-valid DCT/JPEG,
  JPX/JPEG2000, and JBIG2 payloads. Existing mbtpdf one-stage decoding is used
  only to peel wrapper filters such as ASCII85 before checking the final image
  container.
- Inline images can expose raw container bytes for supported single filters or
  decoded RGB pixel bytes through existing mbtpdf image decoding; decoded inline
  pixels are written later as BMP assets.
- Unsupported filters and unavailable bytes remain parser facts with
  metadata-only status. They do not imply product output and do not create fake
  bytes.
- Convert owns materialization and final `ImageBlock` policy. Visible image
  output is now gated on a real materialized asset path, and asset origins follow
  the core/v1 convention.
- No vendor runtime changes, OCR, image-table recovery, caption inference,
  v1 fallback, external model/data access, or runtime model hook was added.

Remaining parser/fact work:

- recurse Form XObject content if v2 product parity needs nested image facts.
- expose richer placement geometry for image ordering/caption association.
- decide whether Flate XObject pixel decoding should become a supported
  product asset path after careful memory and color-space review.

## Reset 11 Form XObject Images And Placement Facts

Reset 11 keeps image handling parser-fact-first while adding facts needed by
the product bridge to place and caption materialized images.

- Form XObject traversal:
  - page-level `Do` invocations now resolve XObject resources and create image
    facts only for drawn images.
  - Form XObject streams are parsed recursively for nested `Do` image
    invocations.
  - traversal carries the page CTM into the Form, applies the Form `/Matrix`
    when present, tracks resource paths such as `Fm1/Im1`, and records the
    parent Form object ref when known.
  - recursion is depth-capped and cycle-guarded; malformed/cyclic forms add
    parser warnings/risks and do not trigger fallback.
- Placement facts:
  - `PdfV2ImagePlacementFact` records source order, CTM, unit-image bbox,
    dimensions when available, confidence, and source refs.
  - inline images also receive placement facts from the current graphics state.
- Caption facts:
  - `PdfV2ImageCaptionCandidate` is attached during model assembly only for
    conservative same-page single-image/single-figure-caption cases.
  - table/chart/CJK table caption markers are intentionally rejected by the
    image caption rule.
  - parser facts do not delete text; convert may suppress an exact caption
    duplicate only after it lowers the caption into `ImageBlock.caption`.
- Boundaries:
  - no OCR, image-table extraction, full layout recovery, aggressive caption
    inference, v1 fallback, external model/data access, or vendor runtime
    change was added.

## Reset 12 Table Structure And Sidecar Parity

Reset 12 promotes table evidence into parser-owned facts while keeping final
product policy in convert:

```text
TextShow / block / line facts
  -> PdfV2TableCandidate
  -> pipeline table_candidates
  -> @core.RichTable(TableData)
  -> existing core metadata sidecar table payload
```

Current status:

- Parser now emits `PdfV2TableCandidate` values with page, block, line,
  source-ref, row, column, cell, confidence, kind, and header evidence.
- Pipe and whitespace-aligned candidates come from reconstructed block/line
  text when rows have stable width and reliable cell shapes.
- Coordinate-grid candidates come from text-show matrix positions, grouped by
  page, y row, and x column alignment. The rule requires at least three rows,
  at least two columns, stable x alignment, and sufficient x spread.
- Coordinate-grid candidates retain matching cell block indices and source refs
  so convert can consume multi-fragment cell output as one table.
- Convert lowers only high-confidence parser-backed candidates to
  `RichTable(TableData)` and leaves weak/malformed table-like content on the
  paragraph path.
- The product bridge suppresses later semantic/text-flow duplicates when their
  source refs overlap an already-emitted parser-backed table.
- Core sidecar behavior is reused as-is: table sidecars carry
  `block_type: "table"`, flat text, `rows`, `header_rows`, and origin line
  range. No PDF v2 private sidecar schema was added.
- Sample signal: main PDF failures improved from 20 to 18, metadata-only from 9
  to 8, and assets-only stayed 3. The simple table Markdown samples now match;
  the remaining metadata table-like sidecar diff is document-property parity.

Boundaries:

- no complete visual table recovery.
- no image-table OCR or table-from-image recovery.
- no merged-cell or full layout reconstruction.
- no fake cells, diagnostics Markdown, v1 fallback, external model/data access,
  or training hook.

## Reset 13 Metadata Sidecar Key Parity

Reset 13 is a product sidecar contract alignment, not a parser fact expansion.

- Parser facts remain unchanged:
  - PDF metadata facts, image object refs, Form XObject nesting, resource paths,
    source refs, and link/object candidates still stay available internally.
  - no parser-side annotation/form/outline expansion, text reconstruction,
    hardwrap repair, OCR, image-table recovery, full layout recovery, fallback,
    or model hook was added.
- Sidecar convention audited from core/v1:
  - PDF sidecars currently serialize `document: null` for existing PDF metadata
    fixtures.
  - PDF block origins omit PDF object refs; image asset origins retain the image
    object ref.
  - image asset origin ids use v1-style names such as `xobj-image-3`.
  - resource-path facts are parser provenance, but the current PDF asset
    sidecar convention does not emit `source_path`.
- Convert-side alignment:
  - public PDF v2 metadata parse results now pass `None` as document properties
    to the sidecar writer.
  - product bridge block origins no longer expose PDF object refs.
  - XObject image asset origins use `xobj-image-<object-number>` and omit
    `source_path`; inline image ids use `inline-image-N`.
- Sample signal:
  - metadata-only failures improved from Reset 12's 8 to 4 in
    `.tmp/check/runs/pdf-20260612-182554-59551`.
  - main Markdown stayed 18 and assets-only stayed 3, confirming the change is
    metadata-surface only.
- Remaining parser-facing blockers:
  - the two remaining metadata-only sidecar failures are driven by
    `pdf_metadata_noise_merge` and `pdf_metadata_text_structure` visible
    text/block structure mismatches.
  - future parser/model work should focus on block reconstruction, hardwrap and
    cross-page facts, repeated artifact/header-footer evidence, and later
    annotation/form/outline product facts.

## Reset 14 Text Structure And Noise Merge Parity

Reset 14 remains a convert/productization pass over existing parser facts.

- Parser facts remain unchanged:
  - text fragments, source refs, page artifacts, text-flow candidates, table
    candidates, and image metadata facts are still parser-owned inputs.
  - no OCR, image-table recovery, full layout recovery, annotation/form/outline
    expansion, vendor runtime change, fallback, model loading/training, or
    external data access was added.
- Convert-side text structure changes:
  - page/block context is preserved through the text-output line normalizer.
  - repeated artifact suppression runs after fragment joining so split footer
    words normalize before they are filtered.
  - CJK chapter headings and decimal-section headings can absorb short split
    tails, including `1.1 研究` + `目标`, while the following sentence remains
    body text.
  - actionable parser candidate mode now requires list-marker evidence and
    does not promote decimal section labels as list candidates.
- Sample signal:
  - metadata-only improved from Reset 13's 4 failures to 0 in
    `.tmp/check/runs/pdf-20260612-191228-66529`.
  - main Markdown improved from 18 to 15 failures.
  - assets-only stayed 3 failures.
- Remaining parser-facing blockers:
  - hardwrap, cross-page merge, heading/header-footer variants, image placement
    parity, and later annotation/form/outline product facts remain future work.

## Reset 15A Main Markdown Failure Taxonomy And Low-Risk Fixes

Reset 15A does not add parser capabilities. It records which Reset 14 main
Markdown failures were safe to reduce in convert and which still need stronger
parser/layout evidence.

- Convert-only reductions:
  - conservative CJK/ASCII hardwrap continuations.
  - unfinished cross-page continuation across an intervening blank.
  - section-label heading inference before intro/body phrases.
  - heading-negative guard for inline CJK body markers.
  - one observed ligature split repair for `di ff erent`.
- Parser facts unchanged:
  - text flow candidates, page artifacts, source refs, image facts, table
    candidates, links, forms, metadata, and object facts keep their Reset 14
    shape.
  - no parser-side OCR, image-table recovery, full layout recovery,
    annotation/form/outline expansion, fallback, vendor runtime change, model
    loading/training, or external data access was introduced.
- Remaining parser-facing blockers after the Reset 15A sample run:
  - image heading/placement needs stronger nearby text/caption/title evidence
    around XObject, inline image, and nested Form image placements.
  - cross-page merge/non-merge needs page-boundary facts that preserve both
    title/body boundaries and list/numbered-marker starts.
  - repeated header/footer variants need parser-backed artifact matching for
    lines with varying page labels and fused body starts.
  - `pdf_heading_false_positive_phase15` and the remaining
    `pdf_heading_vs_short_sentence` list-marker gap need more reliable
    paragraph/list boundary facts.
  - `pdf_two_column_negative_phase15` needs column-aware layout order recovery;
    it is intentionally outside this low-risk convert pass.
- Sample signal:
  - main Markdown: 15 -> 10 failures, final run
    `.tmp/check/runs/pdf-20260612-194329-70975`.
  - metadata-only: stayed 0 failures, final run
    `.tmp/check/runs/pdf-20260612-194340-71480`.
  - assets-only: stayed 3 failures, final run
    `.tmp/check/runs/pdf-20260612-194340-71483`.

## Reset 15R Anti-Patch Audit And Model Readiness

Reset 15R is a responsibility audit over the Reset 14 and Reset 15A
productization fixes. It adds no parser facts and changes no runtime behavior.

- Why it was needed:
  - recent parity improvements increasingly relied on normalizer and semantic
    string rules.
  - without an audit, future resets could turn sample-shaped fixes into an
    implicit training target.
- Patch smell findings:
  - the normalizer now owns too much boundary and artifact judgment: CJK/decimal
    heading-tail splits, repeated artifact suppression, English lexical
    body-merge cues, exact ligature repair, and cross-page continuation.
  - semantic rules are the better home for heading/list decisions, but common
    section-label and inline CJK body-marker rules still need parser-backed
    neighborhood facts before further expansion.
- Keep/move/revisit:
  - keep parser-owned line/block/text-flow/page-artifact/table/image facts as
    the source of evidence.
  - move future boundary decisions toward `PdfV2BlockBoundarySignal` and
    `PdfV2TextFlowCandidate`.
  - move repeated header/footer suppression toward
    `PdfV2PageArtifactCandidate` and an artifact classifier.
  - revisit exact string repairs before exporting weak labels.
- Current model readiness:
  - available signals include source refs, decode and geometry confidence,
    line text signals, block boundary scores, page artifact candidates, table
    candidates, image placement/nesting facts, feature rows, rule decisions,
    confidence values, and reason tags.
  - missing signals include stable gold labels, dev/test splits, complete
    geometry, vertical gaps, font-size relation, column/read-order ids, and
    quality-lab integration.
- Next recommended action:
  - prefer `Reset 15B-AuditCleanup`, followed by a non-runtime
    `Reset 16 Dataset Export Scaffold`.

## Reset 15B Audit Cleanup And Parser Fact Migration Targets

Reset 15B adds no parser facts and changes no parser runtime behavior. It marks
which convert-side rules must eventually move to parser facts or offline
classifier rows before training.

- Temporary convert ownership:
  - split ligature text repair belongs in parser glyph/font reconstruction or
    weak text-repair export rows.
  - heading-tail/body splitting belongs in `PdfV2TextFlowCandidate` and
    `PdfV2BlockBoundarySignal` evidence.
  - hardwrap and cross-page joins belong in parser boundary/read-order facts.
  - repeated artifact suppression belongs in `PdfV2PageArtifactCandidate` and
    artifact-classifier rows.
  - common heading labels and inline body-marker negatives belong in
    block-kind classifier features backed by parser neighborhood signals.
- Guardrails added in convert:
  - owner/risk/TODO comments for each high-risk bridge.
  - helper boundaries for closed-list ligature repair and repeated-artifact
    suppression.
  - tests proving single artifact-like lines are not suppressed and bridge
    candidate mode does not classify raw strings.
- Parser/model migration targets for Reset 16 export:
  - parser fact rows: source refs, text-flow candidates, line text signals,
    block boundary scores, page artifacts, table/image/caption adjacency, and
    confidence/reason tags.
  - weak labels: rule decisions, suppress-output decisions, temporary bridge
    risk tags, and expected-output alignment markers.
  - known gaps: cross-page table/image boundaries, column/read-order ids,
    vertical gaps, font-size relation, stable gold labels, dev/test splits, and
    quality-lab gates.
- Model timing:
  - do not train or load a model yet. The next step is only a non-runtime
    `Reset 16 Dataset Export Scaffold`.

## Reset 16A Training Stack Audit And Dataset Export Contract

Reset 16A confirms that current parser facts can define a dataset export
contract, but should not yet be wired into training or runtime.

- Main repo exportable facts:
  - `PdfV2LineTextSignal` supplies normalized text, marker/page/caption/title
    signals, decode confidence, and reason tags.
  - `PdfV2BlockBoundarySignal` supplies heading/list/continuation/artifact
    scores, indent profile, boundary confidence, and parser-owned tags.
  - `PdfV2TextFlowCandidate` supplies page/block/flow ids, line ids,
    original/normalized lines, line signals, artifact refs, source refs, and
    text-flow reason tags.
  - `PdfV2PageArtifactCandidate` supplies artifact kind, repeat count, position
    band, confidence, page indices, and source refs.
  - table/image/link/form/object candidates supply adjacency and layout context.
  - semantic blocks supply rule ids, confidence, source refs, negative reasons,
    and Reset 15B risk tags.
- External alignment:
  - `text_block_classifier` can consume future `TextFlowRow`/`ArtifactRow`
    exports after an adapter flattens them into DocLayNet-like TSV fields.
  - `layout_recovery` should consume `LayoutRegionRow`, `BoundaryRow`, and
    `ReadingOrderRow`; it must stay separate from convert semantic labels.
  - DocLayNet `Title`, `Section-header`, `Text`, `List-item`, `Caption`,
    `Page-header`, `Page-footer`, `Table`, `Footnote`, `Formula`, and
    `Picture` mappings are documented in the export contract from observed
    quality-lab mapping files.
- Contract document:
  - `docs/archive/pdf-v2-dataset-export-contract.md`.
- Still missing before training:
  - stable row ids and adapter flattening.
  - complete vertical gap/font-size relation.
  - column/read-order ids.
  - reviewed caption/object adjacency labels.
  - reviewed cross-page boundary labels.
  - quality-lab heldout gate integration.
- Decision:
  - docs-only in Reset 16A; no parser output, product output, or metadata
    sidecar behavior changed.

## Reset 16B Dataset Exporter Adapter Scaffold

Reset 16B does not add parser facts. It consumes the parser facts already
available through `PdfV2ConvertPipelineOutput` and exposes them through an
explicit convert-side dataset exporter.

- Parser facts used:
  - `PdfV2TextFlowCandidate` for `TextFlowRow`.
  - `PdfV2BlockBoundarySignal` and line signal tags for weak text-flow and
    boundary features.
  - `PdfV2PageArtifactCandidate` for `ArtifactRow`.
  - `PdfV2TableCandidate`, `PdfV2ImageCandidate`,
    `PdfV2InlineImageCandidate`, and `PdfV2LinkCandidate` for minimal
    `AdjacencyRow`.
  - `PdfV2SourceRef` for provenance in both JSONL and TSV.
- Missing parser/model facts remain:
  - stable layout region rows.
  - reading-order and column ids.
  - reliable vertical gap and font-size relation.
  - reviewed caption/object adjacency labels.
  - reviewed cross-page boundary labels.
- Label policy:
  - semantic rule decisions are weak labels.
  - parser artifact/object facts are weak evidence.
  - no parser fact becomes `gold_label` in this scaffold.
- Runtime boundary:
  - no parser behavior, vendor runtime, product output, fallback, model
    loading, training, or quality-lab integration changed.

## Reset 16C Exported Row Quality Audit And Schema Dry-run

Reset 16C keeps parser facts unchanged and audits how the existing facts appear
in exported rows.

- Parser fact quality surfaced by audit:
  - source refs are present on the synthetic text-flow, boundary, artifact, and
    adjacency rows.
  - geometry unknowns remain visible through `unknown` page/object/bbox-distance
    fields rather than hidden defaults.
  - cross-page and heading-short-text risks are countable without product-path
    changes.
- Label boundary:
  - text-flow semantic rule decisions are weak labels.
  - artifact kind, table relation, image caption proximity, and link proximity
    are parser/object evidence, not gold labels.
- Adapter blockers:
  - text-flow rows need bbox/source-label and reviewed split assignment before
    external training.
  - boundary rows need reviewed boundary labels.
  - adjacency rows need reviewed object/text association labels.
  - layout/read-order rows still need parser/model facts before population.
- Privacy:
  - the parser does not derive a document id; callers must provide a stable
    synthetic `doc_id` to avoid leaking local paths.

## Reset 16D Quality-lab Adapter Mapping Dry-run

Reset 16D is docs-only for parser fact alignment. Quality-lab adapter
conventions were inspected read-only, and no parser/export code changed.

- Mapping ownership:
  - `TextFlowRow` can be adapted to text-block conventions only after an
    external adapter supplies bbox/source-label/reviewed-label policy.
  - `BoundaryRow`, future `LayoutRegionRow`, and future `ReadingOrderRow`
    belong to quality-lab layout-recovery tooling.
  - `ArtifactRow` and `AdjacencyRow` are parser-evidence/audit rows until
    reviewed labels and visual associations exist.
- Parser facts still blocking training:
  - true object/text bbox distance and visual proximity.
  - reliable vertical gaps and font-size/font-style deltas.
  - column ids, reading-order ids, and layout-region rows.
  - reviewed boundary and adjacency labels.
- Boundary:
  - no parser output, product output, model loading, training, quality-lab
    dependency, generated dataset, or DocLayNet-to-Markdown direct label
    mapping was introduced.

## Reset 17A Parser/Layout-backed Facts For Remaining Gaps

Reset 17A adds typed parser/model fact scaffolding for the remaining parity
gap families. The facts are opt-in through `pdf_v2_parity_facts_from_model` and
are not wired into product conversion.

| fact | current evidence | targeted remaining gaps | current blocker |
| --- | --- | --- | --- |
| `PdfV2CrossPageBoundaryFact` | adjacent text-flow candidates across page indices, source refs, punctuation/open-ended evidence, marker evidence, attached artifact refs | cross-page merge vs split | no reviewed boundary labels and limited vertical gap/font facts |
| `PdfV2ImageTextBoundaryFact` | image/inline-image refs, source order, optional bbox/placement, attached caption candidate, nearby text refs | image placement, caption, nearby heading | true distance remains `unknown` without bbox/placement and labels are unreviewed |
| `PdfV2HeaderFooterVariantFact` | page artifact candidates plus edge-line normalized-key grouping for numbered variants | header/footer variants | fuzzy variants and body-fused artifacts still need review |
| `PdfV2HeadingBoundaryFact` | text-flow boundary scores, line signals, short-text risk, sentence-like risk, marker evidence, continuation score | heading false positives and heading vs short sentence | no font/style deltas or reviewed heading labels |
| `PdfV2ColumnLayoutFact` | page block refs, optional bbox column assignment, source-order confidence, ambiguity flags | two-column ordering | full reading-order recovery, column ids, and layout-region rows remain missing |

Implementation boundary:

- no normalizer patch, semantic string-shape patch, Method/CJK/ligature
  special case, sample expected update, v1 fallback, model loading, runtime
  inference, training, or quality-lab modification.
- facts preserve source refs and stable reason tags.
- unknown or insufficient evidence remains explicit, for example
  `image_geometry_unknown`, `nearby_text_unknown`, and
  `column_geometry_unknown`.
- product bridge, pipeline, and fact lowerer do not call the new builder.

Future export/arbitration mapping:

- cross-page facts can enrich `BoundaryRow`.
- image-text facts can enrich `AdjacencyRow` and future caption rows.
- header/footer variant facts can enrich `ArtifactRow`.
- heading-boundary facts can enrich `TextFlowRow` risk tags and future
  semantic arbitration.
- column layout facts can feed future `ReadingOrderRow` once geometry and
  review labels mature.

## Reset 17B Parity Facts Audit And Confidence Calibration

Reset 17B audits the Reset 17A facts in memory and keeps them out of product
conversion.

New audit API:

```text
pdf_v2_parity_fact_audit(facts)
```

Audit counters:

- total facts and facts by type/page.
- confidence buckets: low, medium, candidate, and high.
- reason-tag distribution.
- cross-page, image-text, header/footer variant, heading-risk, and
  column-layout counts.
- unknown or low-confidence facts.
- source-ref coverage.
- insufficient-geometry facts.
- audit-only versus future-arbitration-candidate counts.

Calibration changes:

- image nearby text without caption evidence gets `nearby_text_not_caption`
  and confidence remains below candidate threshold.
- repeated edge header/footer variants get `repeated_edge_evidence`.
- sentence-like heading risks stay low confidence.
- column facts with unknown geometry stay audit-only and do not imply reorder.

Fact readiness matrix:

| fact | future arbitration candidate when | audit-only when |
| --- | --- | --- |
| `PdfV2CrossPageBoundaryFact` | open-ended previous text, no marker start on next page, source refs, confidence >= 0.60 | marker start, weak confidence, or missing source refs |
| `PdfV2ImageTextBoundaryFact` | caption evidence, source refs, no nearby-text-unknown tag, confidence >= 0.60 | nearby text lacks caption evidence, geometry/text unknown, or low confidence |
| `PdfV2HeaderFooterVariantFact` | repeated non-body edge evidence, source refs, confidence >= 0.70 | body/unknown band, single-page edge text, or low confidence |
| `PdfV2HeadingBoundaryFact` | strong heading evidence without sentence-like/body-continuation risks | short-text or sentence-like risk without review |
| `PdfV2ColumnLayoutFact` | currently only non-ambiguous single-column source-order facts | unknown geometry, two-column ambiguity, or reorder need |

Product boundary:

- product bridge, pipeline, and fact lowerer still do not call
  `pdf_v2_parity_facts_from_model`.
- no product Markdown, metadata sidecar, samples expected, v1 fallback,
  normalizer patch, semantic patch, model loading, runtime inference, training,
  quality-lab write, dataset export, or model artifact changed.

## Reset 17C Cross-page Boundary Fact-backed Product Arbitration

Reset 17C narrows product consumption to one parser-owned fact family.

New cross-page-only API:

```text
pdf_v2_cross_page_boundary_facts_from_candidates(candidates)
```

Alignment update:

| fact | Reset 17C product status | still audit-only |
| --- | --- | --- |
| `PdfV2CrossPageBoundaryFact` | consumed only for adjacent cross-page paragraph merge/split arbitration when confidence >= 0.60, source refs match both sides, previous text is open-ended, and the next side is not marker/list/heading-like | low confidence, missing refs, marker/list/heading-like next side, ambiguity/audit-only tags |
| `PdfV2ImageTextBoundaryFact` | not consumed | all image placement/caption/nearby-heading evidence |
| `PdfV2HeaderFooterVariantFact` | not consumed | all header/footer variant evidence |
| `PdfV2HeadingBoundaryFact` | not consumed | heading risk/demotion evidence |
| `PdfV2ColumnLayoutFact` | not consumed | column count and reading-order ambiguity evidence |

Product guard:

- `convert/pdf_v2` may call the cross-page-only candidate extractor.
- `convert/pdf_v2` still does not call `pdf_v2_parity_facts_from_model`.
- no quality-lab, training, runtime inference, generated dataset, metadata
  sidecar, assets, or sample expected output changed.

## Reset 17D Cross-page Arbitration Audit

Reset 17D adds convert-side audit helpers for the first product consumer of
`PdfV2CrossPageBoundaryFact` without changing parser fact generation:

```text
pdf_v2_cross_page_arbitration_audit(blocks, facts)
pdf_v2_cross_page_fragment_arbitration_audit(fragments, options, facts)
```

Alignment update:

| signal | audit status | product status |
| --- | --- | --- |
| high-confidence cross-page fact with matching refs | counted as product candidate and join decision when the semantic/fragment pair also passes blockers | still the only fact-backed product join |
| low confidence or blocking tags | counted as rejected | no product change |
| missing or mismatched source refs | counted separately | no product change |
| next marker/list/page-number or heading/title-like start | counted separately | existing split behavior preserved |
| no matching fragment or semantic pair | counted separately | existing behavior preserved |

At Reset 17D time, the visible PDF sample parity count remained 10 because the
cross-page failures were mixed with title/body or list-boundary issues, while
the other failures were image, header/footer, heading/list, and
column/read-order buckets. A fresh June 13, 2026 repo-local
`samples/check.sh --format pdf` run still reproduces that same 10-failure
state, and the cross-page-related diffs are still mixed with title/body or
list-boundary issues. The audit therefore still does not justify relaxing the
Reset 17C gates. Future work should first expose repo-local PDF v2 sample
candidate/fact counters for the three cross-page samples before deciding
whether a targeted fact-backed output update is warranted.

## Reset 17E Cross-page Structural Handoff Alignment

Reset 17E keeps parser facts unchanged and refines only the convert-side
consumer alignment.

Alignment update:

| signal | product use after 17E | still missing |
| --- | --- | --- |
| qualifying `PdfV2CrossPageBoundaryFact` + paragraph continuation pair | may still join as one paragraph | none for the 17C path |
| qualifying fact + next-page heading/list/title-body evidence | may activate structural-handoff preservation mode | stronger parser-backed structure in real failing samples |
| weak or low-confidence fact | no handoff activation; existing behavior stays | stronger parser evidence if future change is desired |
| repeated-artifact or weak heading-like boundary | explicitly blocked from structural-handoff activation | parser-side artifact/title disambiguation for real samples |

Actual June 13, 2026 outcome:

- The narrow bridge/threading bug is fixed and retained.
- No parser API or fact schema changed.
- No sample expected files changed.
- Repo-local PDF Markdown parity still remains at 10 failures because the real
  cross-page samples still lack clean parser-backed title/body or next-page
  heading/list separation.
- Reset 17E therefore aligns convert-side behavior more tightly with available
  parser facts, but it still does not justify threshold lowering or string
  patches.
