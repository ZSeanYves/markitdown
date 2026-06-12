# PDF v2 Dataset Export Contract

Reset: `PDF v2 Productization Reset 16A`.

Status: contract and audit only. No product output path, runtime model,
training script, external data, or quality-lab file is modified by this
contract.

## 1. Scope

This document defines the main-repo PDF v2 export contract that can feed the
external `markitdown-quality-lab/pdf_model_training` stack later.

Main goals:

- export parser-owned facts, rule decisions, weak labels, source refs, and
  risk tags without changing Markdown or metadata sidecars.
- align with the existing external `text_block_classifier` and
  `layout_recovery` split.
- preserve DocLayNet labels as layout-region labels unless a reviewed adapter
  maps them to convert-layer text-block labels.
- keep all training, model artifacts, prediction dumps, and raw DocLayNet data
  outside the main repo.

Non-goals:

- no training.
- no runtime inference.
- no model arbitration.
- no default convert hook.
- no quality-lab invocation from the main repo.

## 2. External Training Stack Audit

Observed external path:

```text
markitdown-quality-lab/
```

Observed status:

- git status: clean.
- latest commit observed: `b30f0fc text-block: audit classifier feature gaps`.
- relevant root: `markitdown-quality-lab/pdf_model_training/`.

Current split:

| route | owner | purpose | status |
| --- | --- | --- | --- |
| `text_block_classifier` | convert layer | text block semantic hints | active local-only DocLayNet teacher line exists |
| `layout_recovery` | parser/layout layer | region, order, boundary, column, artifact layout hints | scaffolded; active manifest is header-only |
| shared contracts | both | feature contracts, label provenance, review guidelines | tracked docs only |

Important external entrypoints:

| file | role | input |
| --- | --- | --- |
| `text_block_classifier/adapters/doclaynet_adapter.py` | local DocLayNet COCO + text cells to adapter TSV | DocLayNet local annotations and optional text cells |
| `text_block_classifier/scripts/build_doclaynet_baseline_features.py` | adapter TSV to numeric/text features | adapter fields listed below |
| `text_block_classifier/scripts/train_doclaynet_baseline.py` | local-only sklearn teacher training/eval | feature TSV |
| `text_block_classifier/scripts/export_hgb_distilled_hints.py` | offline fail-closed hint export | feature TSV and local model |
| `layout_recovery/manifests/label_mapping.tsv` | DocLayNet layout label mapping | region labels |

Existing DocLayNet text-block adapter TSV fields:

```text
sample_id
source_dataset
source_page_id
source_region_id
page_no
bbox
source_label
target_label
target_task
text
confidence
split
notes
```

Existing text-block feature TSV keeps these metadata columns out of model
features:

```text
sample_id
source_dataset
source_page_id
source_region_id
page_no
feature_set
source_label
target_label
split
text
notes
```

Observed local DocLayNet status from external docs:

- full local zip cache exists under
  `pdf_model_training/text_block_classifier/local_only/datasets/doclaynet/cache/`.
- observed payload names: `DocLayNet_core.zip`, `DocLayNet_extra.zip`.
- cache is local-only and must not be moved or committed by main-repo work.
- current strongest text-block subset is `doclaynet_pilot3000_v1` with
  `82373` rows and split counts `60447 / 10803 / 11123`.
- current best local teacher line is `pilot3000_v1_hgb_baseline_v3`, heldout
  macro F1 `0.8097`.

## 3. Main Repo Signal Inventory

The main repo can export these current PDF v2 signal groups:

| group | current source | export value | current gap |
| --- | --- | --- | --- |
| line text features | `PdfV2LineTextSignal` | normalized text, counts, marker/page/caption/title/noise booleans, decode confidence, reason tags | no font/style deltas |
| block boundary features | `PdfV2BlockBoundarySignal` | heading/list/continuation/artifact scores, indent profile, boundary confidence, reason tags | vertical gaps and font relation are placeholders |
| text-flow candidates | `PdfV2TextFlowCandidate` | page/block/flow ids, line ids, original/normalized lines, line signals, boundary signal, artifacts, source refs | no stable export row ids yet |
| page artifacts | `PdfV2PageArtifactCandidate` | artifact kind, normalized text, page indices, repeat count, position band, confidence, refs | variant/fuzzy artifacts remain weak |
| tables | `PdfV2TableCandidate` | rows, cells, header evidence, source refs, confidence, table kind | no merged cells or visual ruling graph |
| objects/adjacency | image, inline image, link, annotation, form, outline, resource candidates | placement, bbox, caption candidates, nesting, source refs, warnings, risks | no reviewed caption adjacency labels |
| semantic decisions | `PdfV2RuleDecision`, `PdfV2SemanticBlock` | kind, confidence, rule id, reason/negative/risk tags, source refs | model hints intentionally unused |
| pipeline summaries | `PdfV2ConvertPipelineOutput` | source/model/layout/feature/gate summaries and lowered facts | not a dataset schema by itself |

Reset 15B risk tags and TODO comments identify temporary bridge rules whose
output must be exported as weak evidence, not gold labels.

## 4. Export Row Families

All row families are newline-delimited JSON objects or TSV rows with identical
logical fields. JSONL is preferred for nested arrays such as source refs and
signals; TSV adapters can flatten selected fields for external scripts.

Common fields:

```text
schema_version
row_family
doc_id
source_path optional
source_name optional
source_refs
reason_tags
risk_tags
weak_label
gold_label
label_source
split
notes optional
```

`schema_version` starts at `pdf_v2_dataset_export_v1`.

### 4.1 TextFlowRow

Purpose: one row per `PdfV2TextFlowCandidate` or semantic text-flow unit.

Fields:

```text
schema_version
row_family = "TextFlowRow"
doc_id
page_index
candidate_id
candidate_text
normalized_text
source_refs
line_signals
block_signals
page_artifacts
object_adjacency
current_rule_decision
current_rule_confidence
weak_label
gold_label
label_source
doclaynet_label optional
bbox optional
risk_tags
split
```

Primary consumers:

- external `text_block_classifier` adapter.
- block-kind classifier.
- artifact classifier.
- expected-Markdown weak-label alignment.

Adapter note:

- `candidate_id` should map to external `source_region_id` when converted to
  DocLayNet-like TSV.
- `candidate_text` maps to `text`.
- `weak_label` can map to `target_label` only when `label_source` is weak or
  reviewed according to the label policy.

### 4.2 BoundaryRow

Purpose: one row per adjacent text-flow or line-pair transition.

Fields:

```text
schema_version
row_family = "BoundaryRow"
doc_id
row_id
prev_candidate_id
next_candidate_id
prev_text
next_text
same_page
cross_page
prev_page_index
next_page_index
gap_features
artifact_between
current_rule_decision
weak_label
gold_label
label_source
risk_tags
split
```

Expected labels:

- `same_paragraph`
- `new_paragraph`
- `heading_body_split`
- `list_item_split`
- `cross_page_merge`
- `cross_page_no_merge`
- `forced_break`
- `uncertain`

DocLayNet does not directly provide these labels.

### 4.3 ArtifactRow

Purpose: one row per artifact candidate or artifact-like text-flow candidate.

Fields:

```text
schema_version
row_family = "ArtifactRow"
doc_id
page_index
candidate_id
text
normalized_text
position_band
repeat_count
page_indices
current_rule_decision
weak_label
gold_label
label_source
risk_tags
split
```

Expected labels:

- `header_like`
- `footer_like`
- `page_number_like`
- `repeated_line_like`
- `caption_like`
- `body_text`
- `uncertain`

DocLayNet `Page-header` and `Page-footer` can provide layout-region gold for
edge regions. They are not automatic gold for product suppression until
parser/source alignment is reviewed.

### 4.4 AdjacencyRow

Purpose: one row per candidate relationship between a text-flow candidate and
an image, table, link, annotation, form, or other object fact.

Fields:

```text
schema_version
row_family = "AdjacencyRow"
doc_id
page_index
object_kind
object_ref
asset_ref
candidate_id
nearby_text
source_order_delta
bbox_distance
relation
current_rule_decision
weak_label
gold_label
label_source
risk_tags
split
```

Expected labels:

- `caption_for_image`
- `caption_for_table`
- `heading_for_object`
- `nearby_body`
- `unrelated`
- `link_text`
- `form_row`
- `uncertain`

DocLayNet `Caption`, `Table`, and `Picture` help layout-region learning, but
caption/object relations require PDF-specific adjacency rows.

### 4.5 LayoutRegionRow

Purpose: bridge DocLayNet-style layout regions and PDF v2 parser facts.

Fields:

```text
schema_version
row_family = "LayoutRegionRow"
doc_id
page_index
region_id
bbox
text
source_refs
pdf_v2_candidate_refs
doclaynet_label
pdf_v2_weak_label
gold_label
label_source
risk_tags
split
```

Expected consumers:

- external `layout_recovery`.
- external `text_block_classifier` only through a reviewed adapter.

DocLayNet labels are gold for region class when the upstream data source is
trusted. They are not automatic gold for Markdown semantics.

### 4.6 ReadingOrderRow

Purpose: one row per pairwise or graph edge ordering decision.

Fields:

```text
schema_version
row_family = "ReadingOrderRow"
doc_id
page_index
candidate_a
candidate_b
order_a_before_b
source_order_delta
bbox_order_delta
column_features
current_rule_decision
weak_label
gold_label
label_source
risk_tags
split
```

Expected labels:

- `a_before_b`
- `b_before_a`
- `same_region`
- `different_column`
- `uncertain`

DocLayNet can help with regions, but it does not directly label true reading
order or cross-page order.

## 5. Label Policy

Allowed label provenance values:

| label source | meaning | can be gold? | notes |
| --- | --- | --- | --- |
| `RuleDecisionWeakLabel` | current PDF v2 rule or normalizer decision | no | use for weak supervision and audits only |
| `DocLayNetLayoutLabel` | upstream DocLayNet region label | yes, for layout region class only | not automatically Markdown semantic gold |
| `ManualGoldLabel` | manually reviewed row | yes | must include reviewer/version notes |
| `ExpectedMarkdownWeakLabel` | derived from expected Markdown alignment | no by default | can become gold only after manual review |
| `MetadataSidecarWeakLabel` | derived from sidecar/origin metadata | no by default | useful for object/link/image/table alignment |

Rules:

- `gold_label` must be blank unless `label_source` is `ManualGoldLabel` or a
  trusted dataset label scoped to its own task, such as
  `DocLayNetLayoutLabel` for `LayoutRegionRow`.
- `weak_label` may contain rule decisions, expected-output alignment, sidecar
  alignment, or reviewed-but-not-gold adapter output.
- `doclaynet_label` preserves upstream names exactly.
- `risk_tags` must include Reset 15B temporary bridge indicators when a row
  depends on known patch-shaped rules.
- rows with model predictions must not feed back as features for another
  training row unless explicitly marked report-only and excluded from training.

## 6. DocLayNet Mapping Audit

Mapping is based on the observed external files:

- `text_block_classifier/adapters/doclaynet_mapping.tsv`
- `layout_recovery/manifests/label_mapping.tsv`
- `text_block_classifier/labels/label_schema.md`
- `layout_recovery/labels/label_schema.md`

| DocLayNet label | PDF v2 semantic kind | core block kind | parser fact needed | current support status | gap |
| --- | --- | --- | --- | --- | --- |
| `Title` | `Heading` weak semantic target | heading block | text-flow candidate, line title signal, boundary heading score, bbox/style | supported as text-block `heading` and layout `title_region` | needs font/body-density guards before runtime |
| `Section-header` | `Heading` weak semantic target | heading block | text-flow candidate, line title signal, boundary heading score | supported as text-block `heading` and layout `section_header_region` | section vs title distinction hidden in coarse label |
| `Text` | `Paragraph` | paragraph block | text-flow candidate, line/block signals | supported as text-block `paragraph` and layout `text_region` | hardwrap/boundary labels remain PDF-specific |
| `List-item` | `OrderedListItem`/`UnorderedListItem` or paragraph continuation | list item block | marker signals, indent, line grouping, boundary score | supported as text-block `list_item`; layout maps to `text_region` | wrapped list continuation needs parser features |
| `Caption` | paragraph/caption hint, not a current semantic enum | paragraph near object or future caption block | caption marker, object adjacency, bbox distance | supported as text-block `caption` and layout `caption_region` | object association is weak without adjacency rows |
| `Page-header` | artifact/no-output weak target | suppressed artifact or paragraph if not repeated | page artifact candidate, position band, repeat evidence | supported as `footer_header_noise` and layout `header_footer_region` | product suppression needs repeated/source evidence |
| `Page-footer` | artifact/no-output weak target | suppressed artifact or paragraph if not repeated | page artifact candidate, position band, repeat evidence | supported as `footer_header_noise` and layout `header_footer_region` | page number vs footer split needs artifact rows |
| `Table` | table-like exclusion from text semantic flow | `RichTable` when parser table candidate exists | table candidate, cells, rows, bbox/line refs | supported as `table_like` and layout `table_region` | table text vs visual table relation needs adapter |
| `Footnote` | keep-as-text weak target | paragraph or note-like text | position, small text, source refs, neighborhood | maps to `keep_as_text` for text-block; layout maps to `text_region` | footnote body/marker relation not modeled |
| `Formula` | `Unknown`/uncertain | paragraph fallback or unsupported object | region bbox, text availability, formula policy | text-block maps to `uncertain`; layout maps to `low_signal` | no formula runtime policy |
| `Picture` | object adjacency/layout only | `ImageBlock` only when parser image fact exists | image placement, bbox, asset ref, caption relation | text-block maps to `uncertain`; layout maps to `figure_region` | not a text-flow semantic label |

## 7. Training Task Alignment

| task | existing external script/dataset | expected input | current status | can consume PDF v2 export? | required adapter | priority |
| --- | --- | --- | --- | --- | --- | --- |
| block kind classifier | `text_block_classifier` DocLayNet adapter + baseline features + HGB training | DocLayNet-like adapter TSV and feature TSV | supported now for DocLayNet local-only rows | yes, from `TextFlowRow` after adapter | `TextFlowRow` to text-block adapter TSV, then feature builder | P0 |
| artifact classifier | `text_block_classifier` labels include `footer_header_noise`; DocLayNet page header/footer | adapter TSV/feature TSV | partially supported as text-block label | yes, from `ArtifactRow` plus `TextFlowRow` | artifact rows to footer/header/page-number training TSV | P0 |
| caption/adjacency classifier | text-block `caption` exists; feature report says true visual proximity requires parser export | adapter TSV plus visual proximity features | partially supported, association weak | yes, from `AdjacencyRow` and `LayoutRegionRow` | adjacency adapter with object/text bbox distances | P0 |
| boundary classifier | `layout_recovery` scope lists cross-page merge/no-merge; active manifest header-only | boundary-pair rows | missing mature data | yes, from `BoundaryRow` | boundary-pair adapter and manual/public labels | P1 |
| column/read-order classifier | `layout_recovery` scope lists reading order/column/multi-column risk | region/order rows | missing mature data | yes, from `ReadingOrderRow` | reading-order graph adapter with column features | P1 |
| layout region classifier | `layout_recovery` DocLayNet mapping | region rows with bbox/text/source labels | supported by schema, adapter still needed | yes, from `LayoutRegionRow` | DocLayNet/PDF-v2 region alignment adapter | P0 |

## 8. Split Policy

Default split vocabulary:

```text
train
dev
heldout
test
manual_review
unknown
```

Policy:

- preserve external DocLayNet split values when importing external rows.
- group by document/page source to avoid leakage across train/dev/heldout.
- keep weak-source rows out of gold heldout metrics.
- keep local-only raw data, feature matrices, model checkpoints, prediction
  dumps, and visual packs outside the main repo.
- main-repo exporter rows may include `split = unknown` until an adapter assigns
  grouped splits.

## 9. Code Scaffold Decision

Reset 16A chooses docs-only.

Reason:

- external `text_block_classifier` already has a concrete adapter TSV and
  feature TSV path.
- external `layout_recovery` is intentionally header-only for active manifests.
- a MoonBit exporter should not freeze row ids, flattening, or adapter behavior
  before the external adapter contract is reviewed.
- product path must remain untouched.

Next code step:

- add an opt-in, non-runtime exporter only after `TextFlowRow` and
  `LayoutRegionRow` adapter columns are reviewed against quality-lab scripts.

## 10. Runtime And Training Boundary

This contract does not authorize:

- training.
- loading a model.
- runtime model inference.
- semantic arbitration changes.
- default convert-path export.
- main repo calls into quality-lab.

Any future runtime proposal must be a separate reset with:

- a reviewed export implementation.
- source-separated heldout reports.
- per-label gate thresholds.
- hard-negative precedence.
- product regression gates.
