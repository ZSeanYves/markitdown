# PDF v2 Model Readiness Review

## 1. Scope

- Current HEAD audited: `c29b1c1 pdf-v2: reduce remaining markdown parity gaps`.
- Commits audited:
  - `75c13a5 pdf-v2: improve text structure parity` (Reset 14).
  - `c29b1c1 pdf-v2: reduce remaining markdown parity gaps` (Reset 15A).
- This is a documentation-only review. It does not chase sample failure counts
  and does not change parser, bridge, normalizer, semantic rules, tests, or
  expected sample output.
- Non-goals: sample expected updates, product output changes, new
  normalizer/semantic string patches, v1 fallback or deletion, real model
  training/loading, external data access, mbtpdf vendor runtime changes,
  quality-lab integration, and runtime model arbitration.

## 2. Anti-Patch Audit

| commit | file/function | rule/change | location layer | smell category | evidence available | risk | recommendation |
|---|---|---|---|---|---|---|---|
| `75c13a5` | `pdf_v2_product_bridge_has_actionable_text_flow_candidates` | Requires list-marker evidence and rejects decimal section labels. | product bridge | Bridge performs structural gating. | Parser marker candidates and boundary scores. | Medium | Keep temporarily; move ownership toward `PdfV2TextFlowCandidate` and `PdfV2BlockBoundarySignal`. |
| `75c13a5` | `PdfV2TextOutputLine` page/block context | Carries page and block indices through normalization. | normalizer | Acceptable provenance bridge. | Fragment page/block refs. | Low | Keep; feed future decisions from parser-owned flow facts. |
| `75c13a5` | `pdf_v2_candidate_strip_heading_tail_body` / `pdf_v2_candidate_heading_tail_split_index` | Splits heading tail from following body in normalized text. | normalizer | Semantic boundary decision in string cleanup. | Text shape only. | High | Move to parser proposed splits or a boundary classifier; avoid expanding. |
| `75c13a5` | `pdf_v2_split_heading_tail_from_body` and numbered-section tail helpers | Absorbs short CJK/decimal heading tails. | normalizer | Narrow heading-tail heuristic. | Page/block context plus text shape. | High | Keep as temporary bridge; future owner is parser boundary signal/model boundary classifier. |
| `75c13a5` | repeated artifact paragraph filter | Filters repeated artifact paragraphs after text joining. | normalizer | Artifact suppression after product assembly. | Repeated text counts, page context, page-artifact facts. | Medium | Keep while parity depends on it; move to `PdfV2PageArtifactCandidate` plus artifact classifier. |
| `75c13a5` | `pdf_v2_english_noise_merge_body_signal` | Joins English body-like sentence fragments using lexical cues. | normalizer | Sample-shaped textual keywords. | Text only. | High | Replace with parser boundary features and labeled boundary classifier. |
| `c29b1c1` | `pdf_v2_normalize_paragraph_text` | Exact repair from `di ff erent` to `different`. | normalizer | Exact string patch. | Only observed token shape. | High | Remove or generalize through glyph/font reconstruction; do not train it as gold. |
| `c29b1c1` | CJK punctuation-to-CJK hardwrap continuation | Joins CJK continuation punctuation to following CJK line. | normalizer | General text-flow heuristic. | Text shape. | Medium | Keep with false-positive tests; export as weak feature, not label. |
| `c29b1c1` | mixed CJK and short uppercase ASCII term continuation | Joins short uppercase ASCII terms around CJK text. | normalizer | Narrow domain/string-shape heuristic. | Text shape and page/block context. | Medium-high | Move to boundary classifier features; add broader negative coverage. |
| `c29b1c1` | cross-page unfinished continuation | Ignores a cross-page blank only when both sides look unfinished. | normalizer | Layout decision in text cleanup. | Page indices and punctuation only. | High | Move to explicit cross-page boundary facts and boundary classifier. |
| `c29b1c1` | common section label before intro/body phrase | Promotes labels such as `Method` before body-like intro text. | semantic rules | Narrow semantic phrase rule. | Text-flow order and semantic unit signals. | Medium | Prefer parser-backed heading score plus neighborhood features; keep until model hints can arbitrate. |
| `c29b1c1` | inline CJK body-marker guard | Rejects inline CJK label/body text from heading promotion. | semantic rules | Text-shape hard negative. | Text only. | Medium | Keep as hard negative; expose as feature/reason tag in export. |

Summary:

- Reset 14 and Reset 15A should not be reverted wholesale. Several changes are
  useful parity bridges and some are reasonable hard-negative guards.
- The risky part is ownership drift: the normalizer is accumulating boundary,
  artifact, heading-tail, cross-page, and lexical semantic decisions.
- Further parity work should pause before adding more string patches.

## 3. Responsibility Realignment

| current logic | current layer | correct owner | action | priority |
|---|---|---|---|---|
| Page/block provenance in normalized lines. | normalizer | parser fragments/text-flow facts, consumed by bridge | Keep as bridge-only provenance. | Low |
| Decimal/CJK heading tail split. | normalizer | `PdfV2BlockBoundarySignal`, `PdfV2TextFlowCandidate`, boundary classifier | Move/retest after export; avoid word-list expansion. | High |
| Repeated header/footer paragraph suppression. | normalizer and semantic noise guard | `PdfV2PageArtifactCandidate`, artifact classifier | Move artifact confidence into parser/export; keep product suppression as consumer. | High |
| English body-fragment merge keywords. | normalizer | boundary classifier with line/block geometry and reason tags | Mark as weak legacy bridge; avoid more lexical terms. | High |
| Exact ligature token repair. | normalizer | glyph/font reconstruction or general text decode repair | Replace with general reconstruction; exclude from gold labels. | High |
| CJK punctuation and mixed CJK/ASCII continuation. | normalizer | boundary classifier plus line text signal features | Export as weak features; add negatives before more runtime changes. | Medium |
| Cross-page continuation around blank lines. | normalizer | cross-page boundary fact and boundary classifier | Move to parser/model boundary stage. | High |
| Section-label heading inference. | semantic rules | semantic rules with parser neighborhood facts, later model arbitration | Keep in semantic layer; expose rule id/evidence. | Medium |
| Inline body-marker heading negative. | semantic rules | semantic hard negative plus model feature | Keep as hard negative; add reason tag to export. | Medium |
| Table and image object facts. | parser | parser facts, product bridge lowers only supported public output | Keep current split. | Low |

## 4. Current Signal Inventory

| signal group | available fields | missing fields | confidence/reason_tags | model usefulness |
|---|---|---|---|---|
| Line text signal | normalized text, char/word counts, marker candidates, page-number/caption/title/noise booleans, decode confidence | font relation, neighbor gaps, column membership | reason tags and marker confidence exist | Good weak features for block kind, artifact, and boundary tasks. |
| Line reconstruction | page/line index, text, spans, source refs, bbox, baseline, writing direction, rotation, merge/break tags | stable geometry for all inputs; full font profile per line | decode and geometry confidence exist | Useful once missing-geometry rows are marked or filtered. |
| Block candidate | page/block index, text, lines, bbox, source refs, decode/geometry confidence, break/merge tags, kind hint | vertical gaps, font-size relation, column id, neighbor ids | boundary signal and reason tags exist | Good export unit; not enough alone for production model. |
| Block boundary signal | line count, first/last text, indent profile, heading/list/continuation/artifact scores | vertical gaps are `None`; font-size relation is `None` | `boundary_confidence` and parser-owned tags exist | Strong scaffold for a boundary classifier, but geometry gaps block reliable training. |
| Text flow candidate | page/block/flow indices, line indices, original/normalized lines, line signals, boundary signal, artifact refs, source refs | gold boundary labels, previous/next links, column/read-order ids | parser-owned text-flow tags exist | Best near-term export row for block and boundary labels. |
| Page artifact candidate | kind, normalized text, page indices, repeat count, position band, source refs | variant/fuzzy repeated artifacts, body-fused headers/footers | confidence and parser-owned tags exist | Good artifact classifier input; needs variant matching and gold labels. |
| Table candidate | rows, cells, columns, line/block indices, kind, header evidence, source refs | merged cells, ruling lines, image-table OCR, full layout grid | confidence and reason tags exist | Good table/non-table labels; also useful as text-boundary exclusion. |
| Image/object facts | dimensions, filters, nesting, placement, captions, assets, object facts | richer nearby text/caption association, OCR, image-table content | status, warnings, risks, reason tags exist | Useful context for image adjacency/caption tasks. |
| Feature rows | document/page/block/object aggregate rows, low-signal and missing-geometry flags | text-flow rows, label fields, split/dev/test id, expected-output alignment | reason tags and source refs exist | Good exporter base; needs task-specific rows. |
| Semantic decisions | rule id, confidence, negative reasons, risk tags, source refs, model hint placeholder | real model hints, gold label link, disagreement metrics | rule/arbitration tags exist | Ready for offline comparison; not ready for runtime model arbitration. |

## 5. Model Task Boundaries

Block kind classifier:

- Input unit: `PdfV2TextFlowCandidate` or `PdfV2TextFlowUnit`.
- Candidate labels: heading, paragraph, ordered list item, unordered list item,
  continuation, artifact/no-output, table exclusion.
- Must respect hard negatives such as page labels, parser artifact facts, and
  explicit list markers.

Boundary classifier:

- Input unit: adjacent line or adjacent text-flow pair.
- Candidate labels: same paragraph, new paragraph, heading-body split,
  list-item split, cross-page continuation, forced break.
- Needs page/block refs, line text signals, break/merge tags, bbox/baseline
  when present, and future vertical gap/font facts.

Artifact classifier:

- Input unit: line, block, or text-flow candidate.
- Candidate labels: header-like, footer-like, page number, body text, caption.
- Must use repeat counts, position bands, page indices, page-number signals,
  and source refs. Variant repeated artifacts are a known gap.

Caption/adjacency classifier:

- Input unit: image/table object plus nearby text-flow candidates.
- Candidate labels: caption, title/heading, ordinary body text, unrelated.
- Needs placement, page index, source order, bbox proximity, caption markers,
  and single-object/single-caption constraints.

Column/read-order classifier:

- Input unit: page-level line/block graph.
- Candidate labels: reading-order edge, column id, region role, same visual
  group.
- Current facts are not sufficient for production. This needs reliable
  geometry, font/line metrics, and multi-column gold labels.

## 6. Dataset Readiness

- Available sources:
  - parser facts: line/block/text-flow candidates, page artifacts, table
    candidates, image placement/nesting/caption candidates, source refs,
    warnings, risks, and feature rows.
  - product facts: semantic rule decisions, normalizer decisions as current
    behavior, Markdown output, metadata sidecars, and sample failure taxonomy.
  - regression samples: Reset 14 and Reset 15A runs identify useful buckets,
    but they are not a balanced or stable dataset.
- Label quality:
  - expected Markdown can provide weak labels for visible output.
  - current rule decisions can provide weak labels and hard negatives.
  - sample diffs can identify failure buckets, but cannot safely become gold
    labels without manual review.
- Gaps:
  - no stable train/dev/test split.
  - no durable row-level gold labels.
  - incomplete geometry facts for vertical gap, font relation, and columns.
  - quality-lab is not integrated.
  - recent string patches should be weak features, not truth.
- Risks:
  - training on current product output would encode normalizer patch behavior.
  - training only on remaining sample failures would overfit fixture shape.
  - missing geometry can make a text-only model look good on simple samples but
    fail on layout-heavy PDFs.
  - `PdfV2ModelHint` exists, but arbitration intentionally ignores hints today.

## 7. Proposed Export Schema

Prefer JSONL for nested fields and TSV for flat audit slices. Both should be
offline artifacts only at first.

Text-flow JSONL row:

```json
{
  "schema_version": "pdf_v2_text_flow_v0",
  "doc_id": "sample-or-hash",
  "split": "unassigned",
  "page_index": 0,
  "block_index": 12,
  "flow_index": 34,
  "line_indices": [0, 1],
  "text": "raw text",
  "normalized_text": "normalized text",
  "line_count": 2,
  "char_count": 42,
  "line_signals": {
    "starts_with_ordered_marker": false,
    "starts_with_unordered_marker": false,
    "starts_with_caption_marker": false,
    "starts_with_page_number": false,
    "looks_like_title_line": false,
    "looks_like_noise_line": false,
    "ends_with_sentence_punctuation": true
  },
  "boundary_signal": {
    "heading_candidate_score": 0.0,
    "list_candidate_score": 0.0,
    "continuation_candidate_score": 0.5,
    "artifact_candidate_score": 0.0,
    "boundary_confidence": 0.45
  },
  "artifact_refs": [],
  "decode_confidence": "High",
  "geometry_confidence": "Unknown",
  "bbox": null,
  "source_refs": [],
  "reason_tags": ["parser_owned_text_flow_candidate"],
  "rule_decision": {
    "kind": "Paragraph",
    "rule_id": "paragraph.sentence_guard",
    "confidence": 0.76,
    "risk_tags": []
  },
  "weak_label": "Paragraph",
  "gold_label": null,
  "label_source": "expected_markdown_or_manual_review_pending"
}
```

Adjacent-boundary TSV columns:

```text
schema_version	doc_id	split	page_left	page_right	block_left	block_right	flow_left	flow_right	left_text	right_text	left_tags	right_tags	left_boundary_score	right_boundary_score	same_page	same_block	blank_between	left_sentence_end	right_marker_kind	parser_break_tags	weak_label	gold_label	label_source
```

Artifact JSONL row:

```json
{
  "schema_version": "pdf_v2_artifact_v0",
  "doc_id": "sample-or-hash",
  "page_index": 0,
  "candidate_text": "Page 1",
  "position_band": "Bottom",
  "repeat_count": 3,
  "artifact_kind": "PageNumberLike",
  "confidence": 0.98,
  "source_refs": [],
  "reason_tags": ["parser_owned_page_artifact_candidate"],
  "weak_label": "artifact",
  "gold_label": null
}
```

## 8. Model Integration Plan

Stage 0:

- Keep runtime rule-only.
- Document patch risks and freeze new normalizer string patches unless a reset
  explicitly authorizes cleanup.
- Define offline export schemas and do not train.

Stage 1:

- Add a non-runtime exporter for text-flow, boundary, artifact, and decision
  rows.
- Include rule decisions, parser signals, source refs, and weak labels.
- Do not load a model and do not affect product output.

Stage 2:

- Build a curated label set from expected Markdown alignment plus manual
  review.
- Create stable train/dev/test splits.
- Mark narrow string patches and exact token repairs as weak or excluded.

Stage 3:

- Train offline classifiers for block kind, boundary, and artifact tasks.
- Compare against rule-only output with per-bucket reports.
- Keep semantic arbitration in rule-only mode.

Stage 4:

- Introduce model hints only behind an explicit non-default experiment flag.
- Preserve hard-negative rule precedence.
- Promote to runtime only after quality-lab coverage and regression gates
  exist.

## 9. Do Not Train Yet Criteria

Training should not start yet because:

- insufficient gold labels.
- incomplete geometry facts for vertical gaps, font-size relation, columns, and
  reliable cross-page boundary context.
- quality-lab is not integrated.
- no stable dev/test split.
- potential sample overfitting from Reset 14 and Reset 15A patch-shaped fixes.
- current `PdfV2ModelHint` arbitration intentionally records that model hints
  are ignored.
- exact token repairs and lexical merge cues could pollute labels if exported
  without risk tags.

The current state is ready for an export design and possibly an offline export
scaffold. It is not ready for production training, runtime inference, or model
arbitration.

## 10. Recommended Next Reset

Recommended next reset: `Reset 15B-AuditCleanup`.

Rationale:

- Reset 15R found high-risk normalizer ownership drift in heading-tail splits,
  artifact suppression, English lexical body merging, exact ligature repair,
  and cross-page continuation.
- Cleaning or clearly tagging those bridges before export reduces the chance
  that a later dataset treats patches as gold behavior.
- After 15B, proceed to `Reset 16 Dataset Export Scaffold` as a non-runtime
  exporter with weak-label fields, explicit risk tags, and no product-output
  changes.
