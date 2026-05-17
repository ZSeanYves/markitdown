# Layout-Assist Provider Design

This document describes a conservative provider route for optional
layout-assist signals.

Current boundary:

* rule/heuristic conversion remains the primary chain
* optional layout assistance must not replace the main chain by default
* current lightweight classifier work is still a local training spike
* default output should not depend on external models or heavy runtimes
* heavy document-analysis systems such as PaddleOCR / PP-Structure remain
  future audit/design topics rather than current runtime dependencies
* the fuller dataset/license audit plus the current feature/label/arbiter plan
  now live in `docs/pdf-layout-model.md`

## Goals

* expose optional advisory signals for debug/report workflows
* keep model-backed assistance explainable
* allow future provider experiments without changing the default contract
* keep normal-path latency and startup stable

## Non-goals

* replacing the heuristic main chain
* loading heavy model runtimes during `normal`
* making low-quality held-out results decide user-facing output

## Current state

The repository already contains:

* text-layer feature export
* a small local label corpus
* lightweight local training/evaluation scripts
* deterministic JSON model loading and inference helpers

But:

* held-out quality is still limited
* current results are useful for experiments, not for default output control
* the repository now carries a light provider skeleton, but it stays
  report-only and does not load model files by default

## Provider interface

Suggested interface:

```text
LayoutAssistProvider
  name() -> String
  version() -> String?
  available() -> Bool
  mode() -> report_only | advisory | gated_normal
  predict_block_features(features) -> Result[LayoutAssistPrediction, LayoutAssistError]
  predict_page(features) -> Result[Array[LayoutAssistPrediction], LayoutAssistError]
```

Current implementation status:

* `noop-layout-assist` exists as a stable always-available skeleton provider
* `heuristic-layout-assist` exists as a conservative report-only wrapper
* both providers stay inside the existing rule/feature world
* no external model runtime or model file is loaded by default
* debug-only provider listing can surface these providers without enabling
  predictions in the normal conversion path
* PDF debug/inspect can now surface advisory `layout_assist` provider summaries
  plus conservative report-only predictions without changing normal Markdown
  output
* a debug-only evaluation surface can now summarize advisory prediction
  coverage, label distribution, and top reasons across the local
  `samples/pdf_layout_classifier` manifest without claiming production-quality
  accuracy
* report-only predictions can now also carry `rule_label_hint`,
  `disagreement`, `blocked_by_constraints`, and a conservative
  `would_change_output` estimate for future gated-normal ablation
* local-only subset intake plus external-corpus ablation tooling now lives in
  `tools/pdf_layout_classifier/fetch_tiny_subsets.py`,
  `tools/pdf_layout_classifier/export_manifest_features.py`, and
  `tools/pdf_layout_classifier/local_eval.py`
* the local-only ablation loop now includes a harder doc-style `epubcheck` /
  `BookReporter` held-out split in addition to the earlier seed rows
* the current best result is still report-only:
  the named `gated_conservative_v1` preset now reaches `0.9846` micro F1 on
  the current harder `223 / 195` expanded held-out split, beats the stronger
  `rules_only` floor of `0.9641`, keeps held-out regressions at `0`, and
  keeps `link_text`, `caption`, `list_item`, `footer_header_noise`, and
  `form_row` stable on the checked split, while model-only remains too weak
  for normal-path control
* a later overfit round also proved the value of the held-out loop:
  simply adding more `keep_as_text` train rows made the gate worse again, so
  the arbiter must stay evidence-driven rather than “more labels at all costs”
* the later real-support expansion plus cheap link/caption feature pass raised
  held-out `link_text` / `caption` support to `9` / `8`, then used
  link-coverage, partial-link, TOC-anchor, page-number-link, and
  caption-lead-in features to recover the harder held-out slice without
  changing the normal path
* the current harder `223 / 195` report-only held-out run now reaches
  `0.9846` micro F1 for `gated_conservative_v1` vs `0.9641` for `rules_only`,
  keeps held-out regressions at `0`, fixes the earlier BookReporter /
  receipt / cleanup-shell residuals, and also recovers the checked
  figure-reference sentence boundary with a very narrow report-only conflict
  exception, still without changing the normal path
* `gated_conservative_tuned` no longer regresses on the current split, but it
  still trails `v1` on the harder feature-augmented split, so the pinned
  report-only baseline remains `gated_conservative_v1`
* the work still remains report-only/eval-only:
  the remaining checked residuals are now `Summary` plus a few
  `paragraph` vs `keep_as_text` or receipt/body boundary rows, so there is
  still no case for any later normal-path discussion

Heavy-provider audit note:

* PaddleOCR / PP-Structure is better understood as a possible heavy
  document-analysis provider than as a lightweight replacement for the current
  rule/heuristic layout-assist chain
* any future use of its layout/table/caption-like output should start as
  advisory/report-only debug or evaluation data
* those outputs should not directly rewrite heading/table/caption/noise final
  classifications in the normal conversion path

Suggested prediction shape:

```text
LayoutAssistPrediction
  target_id
  page_index
  suggested_label
  confidence
  provider
  reasons?
  top_features?
  mode
```

## Modes

### `report_only`

* safest default for now
* visible in debug/report only
* does not change Markdown output

### `advisory`

* still non-authoritative
* may annotate debug or inspect output
* can be compared against heuristic decisions

### `gated_normal`

* only for future use
* should require:
  * very light runtime
  * measurable corpus win
  * clear benchmark evidence
  * a kill switch / explicit flag

Current recommendation:

* keep the default provider route at `report_only`
* do not wire provider predictions into normal conversion decisions yet
* keep debug/inspect output explicit that these are advisory predictions rather
  than final block classifications
* use evaluation output for coverage/distribution observation first; only
  consider any stronger rollout if the local corpus evidence materially improves

## Suggested providers

### HeuristicLayoutAssistProvider

* wraps current rule-driven or feature-derived signals
* zero external dependency
* useful as the baseline provider contract

### ModelBackedLayoutAssistProvider

* optional
* may use the current lightweight classifier outputs
* default disabled
* should remain advisory until evidence is strong

### HeavyDocumentAnalysisProvider

* future-only
* candidate examples include PaddleOCR / PP-Structure-style pipelines
* may emit OCR, layout, table, caption, formula, or KIE-like signals
* must remain explicit, external, and report-first
* should not be treated as a drop-in layout-assist replacement

## Reporting contract

Predictions should stay explainable:

* provider name
* current rule label hint
* suggested label
* confidence
* optional reasons / feature summary
* whether deterministic constraints blocked the suggestion
* whether a conservative gated-normal experiment would even consider changing
  output

This makes provider output auditable and keeps it from becoming a black-box
replacement for the main chain.

If a future heavy provider is used for advisory layout assistance, reports
should also record:

* provider runtime family
* model identifiers
* language hints
* device/CPU/GPU selection
* whether the signal came from OCR text, region layout, table parsing, or some
  other document-analysis stage

## Recommended rollout

Near term:

* surface a provider design and optionally a light skeleton
* keep layout assistance report-only
* use the skeleton for tests/debug/report wiring before any main-chain
  integration
* keep heavy-provider ideas such as PaddleOCR design-only until model/runtime,
  licensing, and reproducibility boundaries are documented

Mid term:

* compare heuristic vs optional provider suggestions in debug/report output
* expand labels only if held-out evidence improves
* if heavy providers are explored, start in debug/eval JSON rather than normal
  Markdown control

Long term:

* consider guarded normal-path integration only if:
  * the model is tiny
  * startup remains lazy
  * corpus and benchmark evidence show real value

## Explicit non-recommendations

Do not:

* load heavy layout models in `normal`
* let advisory output silently override heuristic output
* present current spike results as generalized model quality claims
* lower heavy-provider table/caption/layout output directly into normal
  heading/table/caption decisions without explicit provenance and benchmark
  evidence
