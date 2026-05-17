# PDF Layout-Assist Model Plan

This document records the current lightweight PDF layout-assist direction.

The goal is not to replace the rule-driven PDF converter.
The goal is to add a tiny, explainable, offline-trained scorer that helps us
rank ambiguous native-text layout cases such as:

* heading vs paragraph
* separator/noise vs list item
* form-row vs paragraph
* caption vs heading
* weak table-like text vs ordinary prose

Normal-path guardrails:

* no OCR or page-raster model in `normal`
* no Python dependency in runtime
* no ONNX / Torch / TensorFlow / Paddle runtime in runtime
* no large model artifact in the product build
* offline model output stays report-only unless a smaller distilled
  normal-path rule has already been justified from held-out evidence
* deterministic decoding/link/table facts remain higher priority than model

## Dataset Audit

We want real licensed document-layout data for offline training or calibration,
not synthetic-only examples.

| Dataset | Official source | License status | Raw PDF availability | Annotation format / labels | Fit for markitdown-mb |
| --- | --- | --- | --- | --- | --- |
| DocLayNet | IBM Research paper and dataset card: https://research.ibm.com/publications/doclaynet-a-large-human-annotated-dataset-for-document-layout-segmentation and https://huggingface.co/datasets/ds4sd/DocLayNet/blob/main/README.md | `CDLA-Permissive-2.0` on the published dataset card | Yes, the dataset card exposes `pdf` plus page image / text-cell artifacts | COCO-style page layout with 11 detailed classes across business, scientific, patent, law, gov, finance, manuals | Best primary general-purpose training/calibration source for block classes such as heading/text/list/table/caption/header/footer/noise-like regions |
| PubLayNet | Official repo and license: https://github.com/ibm-aur-nlp/PubLayNet and https://github.com/ibm-aur-nlp/PubLayNet/blob/master/LICENSE.md ; paper abstract: https://arxiv.org/abs/1908.07836 | Annotations are under `CDLA-Permissive-1.0`; images come from PMC Open Access content, and the repo says the released subset is from the commercial-use collection | Page PDFs are explicitly released by the official repo | COCO-style layout annotations for scientific pages; paper reports more than 360k page images | Strong secondary training/calibration source for heading/text/list/table/figure in scientific PDFs, but domain is narrower than DocLayNet |
| PubTables-1M | Official repo: https://github.com/microsoft/table-transformer ; dataset card mirror: https://huggingface.co/datasets/bsmock/pubtables-1m/blob/main/README.md | Code repo is MIT; dataset card reports `CDLA-Permissive-2.0` for the published dataset mirror | Source corpus is paper/PMC-derived; use as local-only until the exact dataset-distribution terms are reconfirmed from the chosen download path | Table detection + table structure + word/alignment metadata on hundreds of thousands of pages | Best table/form-row specialist source; useful for `table_like` / `form_row` subtask, not as the only general layout source |
| IIIT-AR-13K | Official project page: https://cvit.iiit.ac.in/usodi/iiitar13k.php | License is not clearly published on the dataset page; the site footer is copyright-only | Dataset page clearly exposes annotated page-image content, but default raw-PDF reuse terms are unclear | Annual-report page images with table / figure / natural image / logo / signature style labels | Useful domain signal for annual reports, but reject for default training intake until explicit reuse/commercial terms are documented |
| TableBank | Official repo: https://github.com/doc-analysis/TableBank | Repo is marked Apache-2.0, but the README also says “For research purpose only” | Source documents and derived data are distributed from internet-collected Word/LaTeX material | Table detection/structure dataset from Word + LaTeX documents | Good stress/eval idea, but license/reuse boundary is ambiguous; keep local-only unless legal review resolves the contradiction |

Recommended near-term mix:

* `DocLayNet` as the primary general block-layout source
* `PubLayNet` as a large secondary scientific-domain source
* `PubTables-1M` as the specialized table/form calibration source
* project-local `samples/quality_corpus` PDF rows as held-out evaluation seeds
* `IIIT-AR-13K` and `TableBank` stay audit-noted but not defaulted into the
  training path

## Local-Only Sample Intake

Do not auto-download full datasets by default.

Recommended workflow:

1. Keep fetch scripts under `tools/pdf_layout_classifier/` or
   `tools/pdf_layout_model/`.
2. Download only small license-verified subsets into
   `.external/layout_model/...`.
3. Record:
   * source URL
   * sha256
   * byte size
   * split purpose: train / calibration / heldout
4. Keep local subset manifests untracked.
5. Do not commit dataset payloads unless the license and repository policy are
   explicitly reviewed.

Current first-round local-only intake status:

* `DocLayNet`
  * fetched: `README.md` and `DocLayNet.py`
  * status: metadata/loader only this round
  * blocker: a direct, tiny, license-clear raw-PDF/page subset was not exposed
    cleanly enough from the public dataset surface to automate here without
    pulling much more than we want
* `PubLayNet`
  * fetched: `examples/samples.json` plus 3 official example page images
  * status: useful for label-shape audit and subset-fetch plumbing
* `PubTables-1M`
  * fetched: `datasets-server` `first-rows` train JSON
  * status: useful for table/form metadata audit

All of the above land only in `.external/layout_model/datasets/...` and stay
local-only.

## Recommended Task Split

Runtime task:

* score ambiguous native-text PDF layout candidates using existing extracted
  text/geometry/style features
* produce report-only label suggestions plus confidence and reasons

Out of scope for runtime:

* OCR text recovery
* image-CNN layout detection
* page raster inference
* large tree ensembles or neural nets

Recommended label families:

Block labels:

* `paragraph`
* `heading`
* `table_like`
* `form_row`
* `list_item`
* `caption`
* `footer_header_noise`
* `separator`
* `link_text`
* `keep_as_text`

Boundary / grouping labels:

* `cross_page_merge`
* `cross_page_keep_split`
* `column_boundary`
* `paragraph_continuation`

Legacy training-spike labels such as `BodyText`, `Heading`, `Noise`,
`HeaderFooter`, and `TableLike` still work, but the preferred direction is to
move new labels toward the block/boundary families above.

## Feature Schema

The layout-assist scorer should stay inside cheap native-text features.

Current feature groups in the export path now include:

* text length / word count / digit / punctuation / uppercase / CJK / Latin /
  symbol ratios
* normalized page geometry and block box geometry
* font-size hint, relative font size, bold hint, alignment hint
* block/page counts and page median font-size context
* image/annotation proximity
* repeated-edge text score
* current rule-derived candidate booleans:
  heading, page-number-like, header/footer-like, artifact-like, caption-like,
  table-cell-like, current heading/noise kind
* continuation / wrapping / boundary evidence for cross-page grouping
* cheap semantic text flags:
  currency, time, date, address-like, separator-like, page-number-like,
  bullet-like, URL/email, raw hyphen, terminal punctuation, colon-ended
  key-value-like signals

This feature family is intentionally:

* numeric
* cheap to compute
* deterministic
* explainable in debug reports
* independent from OCR or page raster models

## Report-Only Arbiter Shape

The current report-only surface should expose, for each candidate:

* `rule_label_hint`
* `suggested_label`
* `confidence`
* `reasons`
* `disagreement`
* `blocked_by_constraints`
* `would_change_output`

The conservative meaning of `would_change_output` is:

* true only when rule and model disagree
* confidence is high enough
* no deterministic constraint blocks the change

Example deterministic constraints:

* explicit table geometry already present
* caption geometry already present
* explicit rich-inline payload already attached
* header/footer/artifact candidates that the current rule chain already trusts

This arbiter stays report-only for offline evaluation and debug-first analysis.

## Training / Evaluation Pipeline

Recommended loop:

1. Export features from native PDF text/layout artifacts.
2. Align them with manual or public-dataset labels.
3. Train a tiny linear or similarly compact scorer offline.
4. Export compact JSON weights.
5. Run report-only inference.
6. Compare:
   * rules only
   * model only
   * conservative gated candidate deltas
7. Promote only after held-out evidence and contract checks stay green.

Accepted offline model families:

* logistic regression
* linear one-vs-rest scorer
* shallow calibrated linear baselines

Avoid in runtime:

* neural nets
* large boosted forests
* heavy inference engines

## First Gated-Normal V1

The current checked-in normal-path integration is intentionally much narrower
than the offline report-only pipeline.

It does not load Python, JSON weights, model files, or `.external` assets at
runtime.
Instead it uses a tiny pure-MoonBit gate distilled from the report-only
feature/held-out loop.

Current enabled scope:

* weak `heading` demotion only
* separator / false-bullet suppression only

Current out of scope for normal-path gating:

* table promotion/demotion
* form-row promotion
* `link_text` / `caption` rewrites
* annotation or link-target decisions
* text-decoding fallback behavior
* scan-only / OCR-needed behavior

Current hard constraints that block the gate:

* `table_geometry`
* `caption_geometry`
* `link_payload`
* page-reference integrity checks such as page-number-like linked rows

Current normal-path decision shape:

```text
candidate
  -> hard constraints
  -> rule label
  -> compact gate score
  -> final normal label
```

Current allowed normal-path overrides:

* weak `heading -> paragraph`
* weak `heading -> keep_as_text`
* weak `heading -> form_row`
* weak `heading -> footer_header_noise`
* weak `list_item -> paragraph`
* weak `list_item -> keep_as_text`
* weak `list_item -> separator`

Current explainability/debug contract:

* `original_rule_label`
* `suggested_label`
* `final_label`
* `score`
* `confidence`
* `hard_constraints_applied`
* `override_allowed`
* `override_reason`
* `override_blocked_reason`
* `reason_tags`

Current disable switch:

* `MARKITDOWN_PDF_LAYOUT_GATE=0`

Current default:

* on, because the checked gate is tiny, explainable, pure MoonBit, leaves
  hard facts above the gate, keeps report-only training/model artifacts out of
  runtime, and passed the full validation + sample/contract gate without
  needing expected-output updates

## Local-Only Eval Loop

The local-only external-corpus ablation loop now runs through:

* `python3 tools/pdf_layout_classifier/fetch_tiny_subsets.py`
* `python3 tools/pdf_layout_classifier/export_manifest_features.py ...`
* `python3 tools/pdf_layout_classifier/local_eval.py ...`

Current local-only eval set:

* round 1: `147` train / `86` held-out
* round 4 frozen baseline slice: `196` train / `136` held-out
* round 5 overfit check: `201` train / `136` held-out
* round 7 expanded held-out feature pass: `196` train / `150` held-out
* round 8 expanded held-out guard pass: `196` train / `150` held-out
* round 9 hard-negative guard pass: `206` train / `161` held-out
* round 10 CJK/help-text/link-control pass: `217` train / `169` held-out
* round 11 standalone-bullet / annotation-freetext guard pass: `220` train /
  `180` held-out
* round 12 real-support expansion: `220` train / `195` held-out, then a tiny
  `223` / `195` selected-train follow-up that did not move the held-out
  result
* local-only model artifacts stay tiny and local-only under
  `.external/layout_model/models/...`
* the current label surface is still strongest on:
  * `footer_header_noise`
  * `form_row`
  * `heading`
  * `paragraph`
  * `separator`
  * `table_like`

Round progression:

| Round | Best strategy | Held-out F1 | Notes |
| --- | --- | --- | --- |
| round 1 | rules + model gated conservative | `0.8605` | first proof that a conservative gate can beat rules-only on the small seed split |
| round 2 | rules + model gated conservative | `0.7542` | harder held-out mix exposed weak `footer_header_noise` / `link_text` / `list_item` coverage |
| round 3 | rules + model weighted | `0.7941` | richer link/footer/code-like features helped, but the original gate still blocked too much |
| round 4 | rules + model gated conservative | `0.8456` | frozen baseline slice before the later `epubcheck` train-label overfit experiment |
| round 5 | rules + model gated conservative | `0.8235` | adding more `epubcheck` keep-as-text train rows started to overfit and regressed a header/footer control |
| round 7 | rules + model gated conservative (`gated_conservative_v1`) | `0.8400` | expanded held-out controls plus cheap caption/link features kept `0` regressions and recovered new caption/link rows |
| round 8 | rules + model gated conservative (`gated_conservative_v1`) | `0.8533` | current best expanded held-out result after guarding short annotation anchors and keeping page-number/header-footer rows out of link promotion |
| round 9 | rules + model gated conservative (`gated_conservative_v1`) | `0.9130` | added receipt / BookReporter / repeated-shell hard negatives plus heading/list precision guards; held-out regressions stayed at `0` while heading precision rose to `0.8333` |
| round 10 | rules + model gated conservative (`gated_conservative_v1`) | `0.9231` | added more CJK short-sentence negatives, command/help-text `keep_as_text` rows, and annotation-adjacent held-out negatives; held-out regressions stayed at `0` while heading precision rose again to `0.9231` |
| round 11 | rules + model gated conservative (`gated_conservative_v1`) | `0.9667` | corrected standalone-bullet hard negatives in the `epubcheck` train slice, added a new annotation-freetext held-out negative, and kept held-out regressions at `0` while cleaning the checked `pdf_heading_vs_short_sentence` control |
| round 12 | rules + model gated conservative (`gated_conservative_v1`) | `0.9231` | expanded real held-out `link_text` / `caption` support to `9` / `8` labels with Apache/NIST/IETF fixtures, kept `0` held-out regressions, and exposed the current hard blocker: long internal-link / page-number-like / paragraph-with-URL anchors are still under-modeled |
| round 13 | rules + model gated conservative (`gated_conservative_v1`) | `0.9487` | kept the same harder `223 / 195` split, added cheap deterministic link/caption features plus stricter report-only anchor arbitration, fixed the checked long-anchor / page-number-link controls, and still kept held-out regressions at `0` |
| round 14 | rules + model gated conservative (`gated_conservative_v1`) | `0.9744` | kept the same harder `223 / 195` split, added cheap deterministic residual features for technical literal text, receipt/payment rows, cleanup-shell headings, and URL boundaries, recovered the checked BookReporter / receipt residuals, and still kept held-out regressions at `0` |
| round 15 | rules + model gated conservative (`gated_conservative_v1`) | `0.9846` | kept the same harder `223 / 195` split, added cheap deterministic figure/section-reference sentence guards in the Moon feature export, then kept a very narrow report-only figure-reference sentence exception that fixes one checked `keep_as_text` vs `paragraph` conflict without adding labels first or regressing held-out controls |

Round-11 expanded held-out micro results:

| Strategy | Precision | Recall | F1 | Notes |
| --- | --- | --- | --- | --- |
| rules only | `0.9500` | `0.9500` | `0.9500` | stronger after the standalone-bullet and annotation-freetext guard pass, but still leaves shell-heading and receipt/form-row mistakes |
| model only | `0.6278` | `0.6278` | `0.6278` | still too weak to use directly |
| rules + model naive | `0.8556` | `0.8556` | `0.8556` | still regresses multiple controls |
| rules + model weighted | `0.9056` | `0.9056` | `0.9056` | useful advisory signal, but still regresses strong controls |
| rules + model gated conservative (`gated_conservative_v1`) | `0.9667` | `0.9667` | `0.9667` | current best expanded report-only candidate with `0` held-out regressions |
| rules + model gated conservative (`gated_conservative_tuned`) | `0.9667` | `0.9667` | `0.9667` | ties `v1` again on this split, but still offers no reason to replace the pinned preset |

Current interpretation:

* the lightweight scorer is useful enough to keep investing in
* model-only is not accurate enough
* the best current configuration is the named report-only preset
  `gated_conservative_v1`, now backed by the harder `223 / 195` local split
  plus real-support `link_text` / `caption` rows, newer link/caption residual
  features, and the later technical-literal / receipt / cleanup-shell / URL
  boundary pass
* the best current arbiter is a weighted rule+model combination plus a
  conservative gate that uses evidence-aware thresholds, conflict policy,
  heading/list precision guards, caption-marker text features, and
  short-link-anchor guards
* on the expanded held-out split, the best gated report improves:
  * `md_receipt_small_pdf`
  * `md_test_pdf`
  * `pdf_metadata_text_structure`
  * while also keeping newer held-out controls such as
    `pdf_metadata_image_caption`, `pdf_metadata_uri_link`,
    `pdf_internal_dest_links_qpdf_link_annots`, `pdfjs_extract_link`,
    `pdfjs_annotation_text_without_popup`, and
    `pdfjs_annotation_fileattachment` green
* round 5 shows that simply adding more train rows is not always better; the
  held-out loop is catching real overfitting
* the round-11 pass materially improved key label metrics on the expanded
  held-out split:
  * `heading` precision: `0.8333 -> 0.9333`
  * `keep_as_text` F1: `0.8889 -> 0.9600`
  * `list_item` precision: `0.7000 -> 1.0000`
  * `footer_header_noise` recall: `1.0000 -> 1.0000`
* a later round-12 real-support expansion intentionally made the held-out mix
  harder instead of chasing a higher global score:
  * real held-out `link_text` support is now `9`
  * real held-out `caption` support is now `8`
  * `gated_conservative_v1` still beats rules-only on that harder split:
    `0.9231` vs `0.9077`
  * held-out regressions still stay at `0`
  * a tiny selected-train follow-up plus `gated_conservative_tuned` retest did
    not improve the round-12 held-out result
* the later round-13 feature pass showed that the next bottleneck was
  feature/arbiter expression rather than label count:
  * the same harder `223 / 195` split now reaches `0.9487` for
    `gated_conservative_v1` vs `0.9231` for `rules_only`
  * `link_text` on the harder split improves to `0.9000 / 1.0000 / 0.9474`
    with support `9`
  * `caption` stays stable at `1.0000 / 1.0000 / 1.0000` with support `8`
  * `gated_conservative_tuned` still does not beat `v1` on this split
* the later round-14 residual feature pass then improved the same harder split
  again without adding labels first:
  * `gated_conservative_v1` now reaches `0.9744` vs `0.9538` for
    `rules_only`
  * `link_text` stays at `1.0000 / 1.0000 / 1.0000` with support `9`
  * `caption` stays at `1.0000 / 1.0000 / 1.0000` with support `8`
  * `form_row` now reaches `1.0000 / 1.0000 / 1.0000`
  * `keep_as_text` improves to `0.7500 / 1.0000 / 0.8571`
  * `gated_conservative_tuned` still does not beat `v1`
* the later round-15 paragraph-boundary feature pass improved the same harder
  split again without adding labels or relaxing the gate:
  * `gated_conservative_v1` now reaches `0.9846` vs `0.9641` for
    `rules_only`
  * `keep_as_text` improves again to `0.9231 / 1.0000 / 0.9600`
  * `paragraph` now reaches `0.9855 / 0.9714 / 0.9784`
  * `link_text` stays at `1.0000 / 1.0000 / 1.0000` with support `9`
  * `caption` stays at `1.0000 / 1.0000 / 1.0000` with support `8`
  * the kept report-only refinement is intentionally narrow: it only lets a
    checked figure-reference sentence override `keep_as_text` when the row is
    already a strong natural sentence and already scores `weighted=paragraph`
* cheap feature/gate additions now cover:
  * clause punctuation inside short CJK body lines
  * option/help-text rows such as `- - timeout ...`
  * annotation-adjacent short non-link text that should stay
    `keep_as_text`
  * standalone bullet markers that should not become their own `list_item`
  * link overlap / text coverage, partial-link, target-kind, page-number-link,
    TOC-anchor, and visible-URL boundary signals
  * caption lead-in / reference-only / object-proximity / metadata-noise
    signals
* the remaining misses now cluster around:
  * mid-page short-title shell rows such as `Summary`
  * standalone visible-URL paragraph rows such as
    `www.techmart.example.com`
  * small receipt/body boundary rows such as
    `Next Reward: $50 gift card at 5,000 pts (1,753 to go)`
  * checked CJK controls are green again, but the real short-title support is
    still too thin to call that boundary closed
* broader model-backed expansion should still stay report-only; the new normal
  gate is intentionally much narrower than the offline report-only arbiter and
  does not make a case for wider model-backed activation yet

Current notable round-11 rule/model conflict counts on held-out rows:

* `footer_header_noise -> separator`: `8`
* `heading -> paragraph`: `7`
* `paragraph -> form_row`: `5`
* `footer_header_noise -> heading`: `7`
* `paragraph -> table_like`: `3`
* `paragraph -> keep_as_text`: `3`

These are exactly the types of conflicts we want the future arbiter to explain
instead of hiding.

## Evaluation Seeds

Current project-local PDF seeds that should remain held out:

* `md_receipt_small_pdf`
  * separator misfire
  * address / total / payment-method heading false positives
* `pdf_booking_layout_markitdown_movie`
  * form-row and summary-table promotions
* `md_test_pdf`
  * fragmented word-boundary recovery
* existing annotation/link rows
* CJK short-sentence / short-title controls such as
  `pdf_cjk_text_pdfjs_simfang_variant` and `hardwrap_zh_pdf`
* no-`/ToUnicode` GBK and Identity-H rescue rows
* scan-only boundary rows

These rows are more valuable as evaluation seeds than as training rows.

## Wider Rollout Gate

Do not widen the current gated-normal scope unless all of the following are
true:

* held-out and quality-corpus evidence improve
* PDF contracts stay green
* runtime latency remains negligible
* generated code size stays small
* model artifact stays tiny or the runtime still uses compact in-tree logic
* the chosen override policy is explainable in debug output
* hard constraints still outrank the gate
* disable/rollback switches remain available

Until a later widening pass is justified, the broader layout-assist model
pipeline remains:

* offline-trained
* report-only
* optional
* non-authoritative
