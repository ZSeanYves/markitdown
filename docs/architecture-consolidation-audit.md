# Architecture Consolidation Audit

Date: 2026-05-31

## Scope

This audit is the first phase of the architecture/package/rule-system
consolidation goal. It records the current state before runtime-affecting
refactors.

Boundaries for this phase:

* no OCR provider implementation
* no runtime model integration
* no model training
* no converter output semantic change
* no expected-output churn
* no package moves before the package graph is documented

## Repository State

Starting status:

* main repo: clean
* `markitdown-quality-lab`: clean
* no `moon.mod.json` diff
* quality-lab local-only assets are ignored

Recent quality-lab blocker commits:

* `3136d4b training: record overnight PDF model goal report`
* `9eefaf8 training: document PDF model runtime blockers`

## Package Map

Module:

* `moon.mod.json`: `ZSeanYves/markitdown`, version `0.3.6`
* module deps:
  * `moonbitlang/x`
  * `TheWaWaR/clap`
  * `moonbitlang/async`
  * `bikallem/compress`
  * `tonyfettes/unicode`

Filtered current package count:

* non-vendor main-repo packages: `82`
* vendored `doc_parse/pdf/vendor/mbtpdf` packages: present and intentionally
  isolated behind PDF lower layers

Package families:

| family | package count | role | current boundary read |
| --- | ---: | --- | --- |
| `core` | 2 | shared IR, metadata, Markdown emitter, pure helpers, tests | mostly clean; metadata sidecar lags newer note IR |
| `cli` | 1 | user-facing product entrypoint | clean, delegates to `cli_support` and `cli_common` |
| `cli_common` | 1 | runtime/path/process/component helpers | clean; must remain format-light |
| `cli_support` | 2 | product parser/help/routing and tests | intentionally imports many format converters; file size needs split planning |
| `convert/*` | 34 | format-to-IR policy and package tests | expected heavy policy layer; PDF and ZIP are consolidation hotspots |
| `doc_parse/*` | 38 | lower-layer parser/model/inspect foundations and tests | broad but directionally clean; docs links drifted |
| `pdf` | 1 | bundled PDF runtime component | clean product component boundary |
| `zip` | 1 | bundled ZIP runtime component | clean delegated ZIP component boundary |
| `debug` | 1 | developer/debug tool | intentionally broad; still carries legacy fallback surfaces |
| `bench` | 1 | developer benchmark tool | intentionally broad; not product runtime |

High-level dependency read:

* `core` does not depend on format converters or CLI packages.
* `cli` depends on `cli_common` and `cli_support`, not on heavy PDF internals
  directly.
* `cli_support` owns normal product routing and imports all normal converters.
* `pdf` depends on `convert/pdf`; this keeps native PDF closure behind the
  bundled component.
* `zip` depends on `convert/zip_worker`, keeping delegated ZIP outside the
  vendored PDF closure.
* `convert/pdf_debug` and `convert/pdf_layout` depend on `convert/pdf`, but
  normal `convert/pdf` does not depend back on them.
* `doc_parse/pdf/layout_model_tool` depends on `convert/pdf_layout`, so it is a
  developer export/infer tool rather than a lower-layer parser package.

## Package Boundary Findings

Keep:

* `core` as the shared IR/metadata/emitter layer.
* `cli` as the product entrypoint.
* `cli_common` as lightweight runtime/delegation support.
* `pdf` and `zip` as bundled product components.
* `convert/*` as the owner of final Markdown/IR policy.
* `doc_parse/*` as parser/model/inspect foundations.
* `markitdown-quality-lab` as external validation and offline model work.

Clarify now:

* `doc_parse/README.md` now points current readers at the architecture audit,
  performance page, and archived package/benchmark notes instead of missing
  current-doc paths.
* `docs/pdf.md` and `CHANGELOG.md` had stale focused PDF quality counts; this
  pass updates them to `79` rows / `0` failed / `1` skipped.

Split later:

* `cli_support/cli_app.mbt` has been reduced below the 1000-line hotspot
  threshold and now focuses on normal conversion routing and metadata emission.
  Batch v1 orchestration lives in
  same-package `cli_support/cli_batch.mbt`; explicit main-CLI OCR policy and
  image OCR execution live in same-package `cli_support/cli_ocr.mbt`; optional
  CLI profile env gates/stage logging live in same-package
  `cli_support/cli_profile.mbt`; bundled PDF/ZIP component delegation lives in
  same-package `cli_support/cli_components.mbt`; stable output/path and
  document-property helpers live in same-package `cli_support/cli_output.mbt`.
  Future splits should preserve package deps and keep parse dispatch
  compatibility-gated.
* `convert/pdf/pdf_to_ir.mbt` has been reduced to final emission and
  origin/table/image orchestration; final IR list/text-shape helpers now live
  in `pdf_ir_text_rules.mbt`, heading role/depth/normalization helpers live in
  `pdf_ir_heading_rules.mbt`, and document-title shape signals live in
  `pdf_ir_title_signals.mbt`.
* `convert/pdf/pdf_layout_features.mbt` has been reduced to exported builders
  and feature-key assembly; package-local link/geometry helpers live in
  `pdf_layout_feature_signals.mbt`, while text/content signals live in
  `pdf_layout_text_signals.mbt`, caption/object/link/code text signals live in
  `pdf_layout_object_signals.mbt`, and lexical/token helpers live in
  `pdf_layout_lexical_signals.mbt`.
* `convert/pdf/pdf_layout_gate.mbt` has been reduced to public gate entrypoints
  and stage decision flow; package-local evidence, repeated-text context,
  feature extraction, and decision plumbing live in
  `pdf_layout_gate_support.mbt`.
* `convert/pdf/pdf_merge.mbt` has been reduced to merge orchestration and
  page-local text-flow repair; package-local cross-page boundary and
  continuation signals live in `pdf_merge_boundary_signals.mbt`.
* `doc_parse/pdf/text/rule.mbt` has started separating lower-layer cleanup
  rules; page-number/page-label and page-noise helpers now live in
  same-package `doc_parse/pdf/text/pdf_text_page_rules.mbt`, and span
  source-order/visual-boundary helpers now live in same-package
  `doc_parse/pdf/text/pdf_text_visual_rules.mbt`; line geometry and paragraph
  continuation helpers now live in same-package
  `doc_parse/pdf/text/pdf_text_line_rules.mbt`; shared text-level signals and
  public caption/intro guards now live in same-package
  `doc_parse/pdf/text/pdf_text_signal_rules.mbt`.
* `doc_parse/pdf/text/normalize_texts.mbt` is `950` lines; lower-layer span
  text artifact repair, compact citation/ligature token repair, and hyphenated
  word-wrap merge helpers now live in same-package
  `doc_parse/pdf/text/pdf_text_span_artifact_rules.mbt`, while line/span
  normalization orchestration and span glue stay in the main normalizer file.
* `convert/convert/test/origin_metadata_test.mbt` has started splitting by
  regression family; media-focused PDF/PPTX origin metadata tests now live in
  same-package `origin_metadata_media_test.mbt`, and structured-text
  block-origin tests now live in same-package
  `origin_metadata_structured_text_test.mbt`; shared test helpers now live in
  same-package `origin_metadata_helpers_test.mbt` so split test files remain in
  the MoonBit test import context; metadata sidecar snapshot regressions now
  live in same-package `origin_metadata_snapshots_test.mbt`.
* `convert/zip_core/zip_to_ir_core.mbt` is `583` lines; HTML local-image
  reference scanning now lives in same-package `zip_html_refs.mbt`, and
  normalized path, entry id, extension classification, and path sort helpers
  live in same-package `zip_entry_paths.mbt`; archive inspection, entry action
  planning, normalized collision checks, and dispatch-format tagging now live
  in same-package `zip_inspect_plan.mbt`; ZIP subdocument asset remapping,
  archive asset path namespacing, asset file copy, and remapped asset-origin
  policy live in same-package `zip_asset_remap.mbt`; converted-entry
  aggregation, warning emission, block origin rewriting, and markdown trimming
  live in same-package `zip_entry_aggregate.mbt`; entry output-dir policy, flat
  staging policy, safe archive materialization, temporary run-dir lifecycle, and
  filesystem path helpers live in same-package `zip_entry_staging.mbt`, while
  nested dispatch and top-level container traversal remain in the main core
  file.
* `convert/epub/epub_parser.mbt` is `521` lines; safe archive
  materialization, temporary run-dir lifecycle, extracted-entry path
  normalization, and entry id/path helpers now live in same-package
  `epub_entry_staging.mbt`; converted-entry aggregation, warning emission,
  block origin rewriting, note-definition source marking, and markdown trimming
  now live in same-package `epub_entry_aggregate.mbt`; subdocument asset
  remapping, asset file copy, note-body asset path remapping, and remapped
  asset-origin policy now live in same-package `epub_asset_remap.mbt`; EPUB
  note-ref id namespacing and note-ref source-kind marking now live in
  same-package `epub_note_refs.mbt`, while cover/nav emission and spine lowering
  remain in the main parser file.
* `doc_parse/epub/epub_package.mbt` is `950` lines; archive read/path-safety,
  href normalization, normalized collision detection, and hidden metadata
  filtering now live in same-package `epub_archive_paths.mbt`; cover discovery,
  guide-cover handling, candidate sorting, and candidate dedupe now live in
  same-package `epub_cover.mbt`; EPUB3 nav and NCX nav-point parsing now live in
  same-package `epub_nav.mbt`, while public open/inspect/validation entrypoints
  and OPF metadata/manifest/spine orchestration remain in the main package file.
* `convert/docx/docx_xml.mbt` is `976` lines; inline note/comment marker id,
  display-text, whitespace, and punctuation spacing rules now live in
  same-package `docx_inline_markers.mbt`; header/footer reference extraction,
  rendered header/footer text, page-field stripping, and page-number-only
  filtering now live in same-package `docx_header_footer.mbt`; deleted-revision
  stripping, text-box content filtering, and text-box block extraction now live
  in same-package `docx_text_boxes.mbt`; footnote/endnote/comment body parsing
  and Markdown rendering now live in same-package `docx_note_bodies.mbt`, while
  paragraph/table/inline XML scan orchestration remains in the main XML file.
* `convert/html/html_dom.mbt` is `972` lines; HTML inline scanning/rendering,
  figure image/caption helpers, and href sanitization/redirect unwrapping now
  live in same-package `html_inlines.mbt`; HTML note-plan construction,
  strong noteref detection, footnote-body detection, note-ref signatures, and
  note-definition rendering now live in same-package `html_notes.mbt`; shared
  open-tag/attribute helpers live in same-package `html_tag_attrs.mbt`; and
  navigation/noise subtree filtering rules live in same-package
  `html_noise_rules.mbt`; table types, row normalization, header detection,
  and rowspan/colspan lowering live in same-package `html_table.mbt`; block-like
  detection, `<pre>` text extraction, and paragraph flush/blank/trim helpers
  live in same-package `html_block_helpers.mbt`, while block/container DOM
  scanning remains in the main DOM file below the 1000-line hotspot threshold.
* `doc_parse/pdf/model/pdf_text_model.mbt` is `380` lines; span adjacency glue,
  punctuation/ASCII/script classifiers, English fragment repair,
  hyphen/ligature wrap signals, and span spacing/source-ref adjacency helpers
  now live in same-package `pdf_text_glue_rules.mbt`, while public PDF text
  model structs and text/bbox/count/source-ref APIs remain in the main model
  file.
* `doc_parse/pdf/raw/mbtpdf_text_adapter.mbt` is `860` lines; conservative PDF
  `TJ` array word-spacing extraction, punctuation/script classifiers, decimal
  and hyphen join guards, and explicit-space boundary checks now live in
  same-package `mbtpdf_tj_spacing_rules.mbt`, while raw operator traversal,
  glyph decoding, font lookup, and page assembly remain in the adapter.

Do not move yet:

* `convert/pdf_layout`: the file names are broad, but existing comments already
  mark them as legacy-compatible and split Task A/Task B by caller policy.
* `doc_parse/pdf/vendor/mbtpdf`: this is a vendored runtime-critical subtree;
  consolidation should avoid cosmetic churn there.
* `debug` legacy PDF entrypoints: keep until fallback exit criteria are proven
  over a full validation cycle.

## File-Size Hotspots

Selected non-vendor files at or above about 1000 lines:

| file | lines | read |
| --- | ---: | --- |
| `debug/debug_app.mbt` | 2609 | broad debug command surface |
| `doc_parse/bench/main.mbt` | 2214 | benchmark harness hotspot |
| `core/text_normalization.mbt` | 1684 | shared normalization hotspot |
| `doc_parse/xlsx/xlsx_formula_eval.mbt` | 1608 | large but self-contained formula evaluator |
| `convert/vision/layout_recovery.mbt` | 1450 | offline/dev layout recovery model candidate code |
| `core/metadata.mbt` | 1364 | shared metadata emission hotspot |

## PDF Rule System Map

Current PDF code volume:

| area | files | tests | lines |
| --- | ---: | ---: | ---: |
| `convert/pdf` | 44 | 12 | 21294 |
| `doc_parse/pdf` including vendor | 287 | 120 | 70950 |
| `convert/pdf_debug` | 3 | 1 | 1812 |
| `convert/pdf_layout` | 5 | 1 | 1774 |

Layer map:

| rule area | active files | status | coverage evidence |
| --- | --- | --- | --- |
| text extraction and glyph/Unicode cleanup | `doc_parse/pdf/raw/*`, `doc_parse/pdf/raw/mbtpdf_tj_spacing_rules.mbt`, `doc_parse/pdf/text/normalize_texts.mbt`, `core/text_normalization*.mbt` | active lower-layer | `doc_parse/pdf/raw/mbtpdf_text_adapter_wbtest.mbt`, `doc_parse/pdf/test/pdf_text_normalization_test.mbt`, `doc_parse/pdf/text/normalize_texts_wbtest.mbt`, `convert/pdf/pdf_text_normalization_wbtest.mbt` |
| span/line/block construction | `doc_parse/pdf/model/pdf_text_model.mbt`, `doc_parse/pdf/model/pdf_text_glue_rules.mbt`, `doc_parse/pdf/text/rule.mbt`, `doc_parse/pdf/text/pdf_text_*`, `convert/pdf/pdf_lines.mbt`, `convert/pdf/pdf_blocks.mbt` | active | `pdf_text_model_test.mbt`, `pdf_text_spans_wbtest.mbt`, `pdf_text_lines_wbtest.mbt`, `pdf_lines_wbtest.mbt`, `pdf_blocks_wbtest.mbt` |
| paragraph and soft line merge | `convert/pdf/pdf_merge.mbt`, `pdf_merge_boundary_signals.mbt`, `convert/pdf/pdf_merge_decision.mbt` | active | `pdf_merge_decision_wbtest.mbt`, sample PDF parse tests |
| heading/list/table/caption decisions | `convert/pdf/pdf_classify.mbt`, `pdf_heading_decision.mbt`, `pdf_layout_gate.mbt`, `pdf_layout_gate_support.mbt`, `pdf_table_detect.mbt`, `pdf_image_caption.mbt`, `pdf_to_ir.mbt`, `pdf_ir_text_rules.mbt`, `pdf_ir_heading_rules.mbt`, `pdf_ir_title_signals.mbt` | active | heading/layout gate/table-caption/to-IR wbtests and PDF parse tests |
| noise/header/footer | `convert/pdf/pdf_noise.mbt`, `pdf_noise_decision.mbt`, repeated-edge geometry helpers in `pdf_layout_feature_signals.mbt`, text signals in `pdf_layout_text_signals.mbt`, object/caption/link/code signals in `pdf_layout_object_signals.mbt`, lexical helpers in `pdf_layout_lexical_signals.mbt` | active | `pdf_noise_decision_wbtest.mbt`, external-quality PDF guard rows |
| annotation and link matching | `doc_parse/pdf/raw/mbtpdf_annotation_adapter.mbt`, `convert/pdf/pdf_link_match.mbt`, `pdf_annotation_emit.mbt`, `pdf_form_emit.mbt` | active | `pdf_link_match_wbtest.mbt`, `pdf_to_ir_wbtest.mbt`, PDF parse tests on pdfjs annotation samples |
| note/superscript marker | `convert/pdf/pdf_merge.mbt`, `pdf_to_ir.mbt`, shared `core/ir.mbt`, `core/emitter_markdown.mbt` | active marker-only | `pdf_merge_decision_wbtest.mbt`, PDF parse tests, core note emitter tests |
| reading order and two-column guard | `doc_parse/pdf/text/rule.mbt`, `convert/pdf/pdf_merge_decision.mbt`, `convert/pdf/pdf_merge.mbt`, `convert/pdf/pdf_layout_gate.mbt` | active conservative guards | two-column negative sample, merge decision wbtests |
| cross-page merge/split | `convert/pdf/pdf_merge_decision.mbt`, `convert/pdf/pdf_merge_boundary_signals.mbt`, `convert/pdf/pdf_merge.mbt` | active deterministic rule path | merge decision wbtests and parse tests |
| debug/model-assist legacy | `convert/pdf_layout/*`, `convert/pdf_debug/*`, `doc_parse/pdf/layout_model_tool`, `debug/testdata/layout_assist_eval/*` | report/dev only | layout model/gate/debug wbtests and split debug manifests |
| metadata/origin output | `convert/pdf/pdf_to_ir.mbt`, `core/metadata.mbt`, PDF metadata expected samples | active but incomplete for new note IR | metadata samples and origin metadata tests |

## PDF Rule Findings

Strong boundaries:

* Normal PDF runtime stays deterministic and rule-driven.
* `convert/pdf` does not load model JSON and does not read quality-lab data.
* `convert/pdf_debug`, `convert/pdf_layout`, and
  `doc_parse/pdf/layout_model_tool` are debug/dev/report surfaces.
* PDF OCR remains outside the native PDF path.

Duplication and overlap:

* heading/title heuristics appear in `pdf_classify.mbt`,
  `pdf_heading_decision.mbt`, `pdf_layout_gate.mbt`, and final
  `pdf_ir_heading_rules.mbt` / `pdf_ir_title_signals.mbt`.
* text-flow heuristics are split across lower-layer `doc_parse/pdf/text/rule.mbt`,
  `normalize_texts.mbt`, `pdf_text_model.mbt` / `pdf_text_glue_rules.mbt`, and
  convert-layer merge/block rules. This is not automatically wrong, but the
  responsibility boundary should be documented before moving code.
* table/caption rejection signals overlap with block-feature text signal
  extraction in `pdf_layout_text_signals.mbt`.
* final lowering no longer carries most `for_ir` text helpers; the next rule
  cleanup should focus on documenting responsibility between classifier,
  layout gate, final IR heading/text rules, and lower-layer text-flow rules.

Recommended next split order:

1. Keep public API and feature key strings unchanged after same-package moves.
2. Run `moon check`, `moon test`, `bash samples/check.sh`, and external quality
   after each rule move.
3. Any future layout-feature helper split must preserve feature names because
   quality-lab scripts depend on them.
4. Keep `convert/pdf_layout` and Task A/Task B feature exports separated by
   manifest/policy, not by runtime hookup.

## Other Format Rule Audit

Current high-signal rule/heuristic areas outside PDF:

| format | active rule areas | current read |
| --- | --- | --- |
| DOCX | notes, comments, hyperlinks, tables, numbering, images, text boxes | note/comment body, inline marker, header/footer, and text-box/revision helpers split out; remaining XML scanner is below the 1000-line hotspot threshold |
| Markdown | footnotes, code fences, inline code, frontmatter, passthrough | stable; metadata line mapping is conservative |
| HTML | safe parser, links/images/tables, explicit noteref/body support | broad `<sup>` inference remains future work |
| EPUB | package/spine/nav/NCX/assets/explicit noteref merge | lower-layer archive/path, cover, and nav/NCX helpers split out; convert-layer staging/materialization, entry-aggregation, asset-remap, and note-ref helpers split out; rule behavior is documented and covered |
| XLSX | sheets, merged cells, formula policy, metadata hints | good package split; large formula evaluator is acceptable but should stay tested |
| PPTX | reading order, text boxes, notes, tables, images, grouping | many focused files already; reading-order file is the largest rule hotspot |
| ZIP | nested docs/assets, safe path, remap/origin policy | HTML-ref, path/id, inspect-plan, asset-remap, entry-aggregation, and staging/materialization helpers split out; `zip_core` should continue clarifying traversal vs lowering |
| OCR/Vision | line resegmentation, layout recovery, semantic hints | explicit path only; no PDF OCR hookup |

## Metadata Sidecar Audit

Current metadata sidecar:

* `version`
* source/format/markdown file
* document properties
* summary with `block_count` and `asset_count`
* block-oriented view
* asset-oriented view
* table metadata for `RichTable`
* image caption/origin alignment
* document-level `note_definitions` when resolved note bodies are present

Resolved in this consolidation pass:

* add metadata `note_definitions` array
* add `summary.note_definition_count`
* include:
  * `note_id`
  * `marker`
  * `kind`
  * `source_kind`
  * `body_status`
  * `placement`
  * `text_preview`
  * `block_count`

Defer:

* broad link-origin schema
* PDF popup/text annotation schema
* OCR provider/confidence/language/page bbox metadata until a product OCR
  provider path needs it

## OCR Boundary And Environment Requirements

Current shipped OCR facts:

* image OCR is supported through the main CLI
* image OCR depends on local `tesseract` and installed language data
* `--ocr-lang <LANG>` is image-only
* PDF OCR is not wired
* normal document conversion does not probe OCR providers
* quality-lab OCR validation remains separate from native PDF validation

Docs already explain much of this, but environment requirements should be made
more explicit in a single current-doc location:

* MoonBit / `moon` native toolchain
* POSIX-like shell with `bash` for sample helpers
* common coreutils used by helper scripts
* Python only for specific helper/quality scripts, not normal runtime
* optional `tesseract` plus tessdata for image OCR
* `markitdown-quality-lab/` placement for external quality

## Docs And Changelog Findings

Current docs are generally aligned with the runtime boundary, but first-pass
cleanup should include:

* keep `doc_parse/README.md` links aligned to current docs or archive docs
* update stale PDF quality row counts in `docs/pdf.md` and `CHANGELOG.md`
* add this audit to `docs/README.md`
* add a concise environment requirements section to `README.md` and
  `README.mbt.md`
* record the consolidation audit in `CHANGELOG.md`

## Validation Plan

For audit-only/doc-only changes:

* `moon check`
* `bash samples/check.sh --manifest-only`
* `bash samples/bench.sh --help`

Before any package move, rule move, or metadata schema change:

* `moon check`
* `moon test`
* `bash samples/check.sh --manifest-only`
* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`
* `bash samples/bench.sh --help`

If shell helpers are edited:

* `find samples -name "*.sh" -print -exec bash -n {} ;`

If quality-lab Python scripts are edited:

* `python -m py_compile` over the touched scripts

## Remaining Technical Debt

Package debt:

* large product routing/debug/benchmark files; CLI batch v1, explicit OCR
  policy/execution, optional profile helpers, bundled component delegation, and
  output/path/document-property helpers are now split from the normal conversion
  app surface
* test packages with very large all-format test files; media-focused origin
  metadata regressions have started moving into
  `convert/convert/test/origin_metadata_media_test.mbt`, and structured-text
  block-origin regressions now live in
  `convert/convert/test/origin_metadata_structured_text_test.mbt`; shared
  origin metadata helpers now live in
  `convert/convert/test/origin_metadata_helpers_test.mbt`; metadata sidecar
  snapshot regressions now live in
  `convert/convert/test/origin_metadata_snapshots_test.mbt`, bringing the
  mixed `origin_metadata_test.mbt` file below the 1000-line threshold

Rule debt:

* PDF heading/list/title rules are now clearer: final IR list/text-shape
  helpers live in `convert/pdf/pdf_ir_text_rules.mbt`, heading role/depth and
  heading normalization helpers live in
  `convert/pdf/pdf_ir_heading_rules.mbt`, document-title shape signals live in
  `convert/pdf/pdf_ir_title_signals.mbt`, and `pdf_to_ir.mbt` focuses on final
  emission and origin wiring.
* PDF layout feature builders are now clearer: feature-key assembly remains in
  `convert/pdf/pdf_layout_features.mbt`, package-local link/geometry helpers
  live in `convert/pdf/pdf_layout_feature_signals.mbt`, text/content signals
  live in `convert/pdf/pdf_layout_text_signals.mbt`, caption/object/link/code
  text signals live in `convert/pdf/pdf_layout_object_signals.mbt`, and
  lexical/token helpers live in `convert/pdf/pdf_layout_lexical_signals.mbt`.
* PDF layout gate flow is now clearer: public entrypoints and stage decision
  flow remain in `convert/pdf/pdf_layout_gate.mbt`, while evidence/context and
  decision-construction helpers live in
  `convert/pdf/pdf_layout_gate_support.mbt`.
* PDF merge flow is now clearer: merge orchestration and page-local text-flow
  repair remain in `convert/pdf/pdf_merge.mbt`, while shared cross-page
  boundary/continuation signals live in
  `convert/pdf/pdf_merge_boundary_signals.mbt`.
* lower-layer PDF text cleanup rules are being separated inside
  `doc_parse/pdf/text`: page-number/page-label cleanup now lives in
  `pdf_text_page_rules.mbt`, span source-order/visual-boundary helpers now live
  in `pdf_text_visual_rules.mbt`, and line geometry/paragraph-continuation
  helpers now live in `pdf_text_line_rules.mbt`; shared text-level signals and
  public caption/intro guards now live in `pdf_text_signal_rules.mbt`, while
  broader line-merge/heading/body rules still need a clearer written
  responsibility boundary
* lower-layer PDF model text glue is now separated inside
  `doc_parse/pdf/model`: public text model structs and aggregation APIs remain
  in `pdf_text_model.mbt`, while span adjacency glue, punctuation/script
  classifiers, English fragment repair, hyphen/ligature wrap signals, and span
  spacing/source-ref adjacency helpers live in `pdf_text_glue_rules.mbt`
* lower-layer PDF raw text extraction is now clearer: raw operator traversal,
  glyph decoding, font lookup, and page assembly remain in
  `mbtpdf_text_adapter.mbt`, while conservative `TJ` array word-spacing and
  punctuation/script/join-boundary guards live in `mbtpdf_tj_spacing_rules.mbt`
* near-term PDF rule hotspots have been reduced below the 1000-line threshold;
  future content-signal splits must preserve feature names
* debug legacy layout-assist fallbacks should remain on the documented fallback
  exit plan

Metadata debt:

* link and annotation origins are still text/block-oriented rather than
  structured as first-class metadata entries
* OCR metadata should wait for explicit provider/runtime support

## Next Phase Recommendation

Recommended commit sequence:

1. current audit/docs/env cleanup and metadata sidecar note-definition
   expansion with targeted tests
2. same-package PDF rule file organization: final-IR text-shape helpers have
   been extracted from `pdf_to_ir.mbt`, final-IR heading/title helpers now live
   in `convert/pdf/pdf_ir_heading_rules.mbt` and
   `convert/pdf/pdf_ir_title_signals.mbt`, layout feature helpers have been
   extracted from `pdf_layout_features.mbt`, layout text signals have been
   separated from link/geometry helpers, layout object/caption/link/code
   signals now live in `convert/pdf/pdf_layout_object_signals.mbt`, layout
   lexical/token helpers now live in
   `convert/pdf/pdf_layout_lexical_signals.mbt`, and layout gate support
   helpers now live in
   `convert/pdf/pdf_layout_gate_support.mbt`; merge boundary signals now live
   in `convert/pdf/pdf_merge_boundary_signals.mbt`; lower-layer
   page-number/page-label cleanup helpers now live in
   `doc_parse/pdf/text/pdf_text_page_rules.mbt`, and span visual-boundary
   helpers now live in
   `doc_parse/pdf/text/pdf_text_visual_rules.mbt`; line geometry and paragraph
   continuation helpers now live in
   `doc_parse/pdf/text/pdf_text_line_rules.mbt`; shared text signal guards now
   live in `doc_parse/pdf/text/pdf_text_signal_rules.mbt`;
   continue with compatibility-preserving splits only where responsibility
   boundaries are already clear
3. package docs/path cleanup for `doc_parse` current-vs-archive docs is in
   place; keep future doc moves link-checked
4. same-package CLI routing cleanup: batch v1 now lives in
   `cli_support/cli_batch.mbt`, and explicit OCR policy/execution now lives in
   `cli_support/cli_ocr.mbt`; optional profile helpers now live in
   `cli_support/cli_profile.mbt`; bundled component delegation now lives in
   `cli_support/cli_components.mbt`; stable output/path/document-property
   helpers now live in `cli_support/cli_output.mbt`; keep future parse-dispatch
   splits compatibility-preserving and validation-gated
5. broader package reshaping only after the above keeps all validation green

Keep PDF model blockers paused until:

* `footer_header_noise` manual review is complete
* Task B layout data readiness is solved
* a disabled-by-default runtime proposal has separate evidence
