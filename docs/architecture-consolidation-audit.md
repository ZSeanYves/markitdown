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

* `doc_parse/README.md` references two current-doc paths that do not exist:
  `docs/doc-parse-foundation.md` and `docs/package-publishing-strategy.md`.
  The package strategy document currently lives under
  `docs/archive/reference/package-publishing-strategy.md`, and there is no
  current `doc-parse-foundation.md`.
* `docs/pdf.md` and `CHANGELOG.md` had stale focused PDF quality counts; this
  pass updates them to `79` rows / `0` failed / `1` skipped.

Split later:

* `cli_support/cli_app.mbt` is `1535` lines and mixes routing, OCR policy,
  batch/metadata behavior, and component invocation. A later split should
  preserve package deps while moving cohesive command handlers into smaller
  files.
* `convert/pdf/pdf_to_ir.mbt` is `1923` lines and currently mixes final IR
  emission with heading/list role rules and table/image-caption orchestration.
* `convert/pdf/pdf_layout_features.mbt` is `2798` lines and contains a broad
  report/debug feature vocabulary for both block semantics and boundary
  signals.
* `convert/zip_core/zip_to_ir_core.mbt` is `1917` lines and owns nested
  dispatch, asset remap, metadata/origin policy, and container traversal.

Do not move yet:

* `convert/pdf_layout`: the file names are broad, but existing comments already
  mark them as legacy-compatible and split Task A/Task B by caller policy.
* `doc_parse/pdf/vendor/mbtpdf`: this is a vendored runtime-critical subtree;
  consolidation should avoid cosmetic churn there.
* `debug` legacy PDF entrypoints: keep until fallback exit criteria are proven
  over a full validation cycle.

## File-Size Hotspots

Non-vendor files at or above about 1000 lines:

| file | lines | read |
| --- | ---: | --- |
| `convert/convert/test/origin_metadata_test.mbt` | 3391 | large but test-only; candidate for split by format |
| `convert/pdf/pdf_layout_features.mbt` | 2798 | feature vocabulary hotspot |
| `debug/debug_app.mbt` | 2609 | broad debug command surface |
| `convert/html/html_dom.mbt` | 2330 | HTML parser/model hotspot |
| `convert/docx/docx_xml.mbt` | 2257 | DOCX XML helper hotspot |
| `doc_parse/bench/main.mbt` | 2214 | benchmark harness hotspot |
| `convert/pdf/pdf_to_ir.mbt` | 1923 | PDF final lowering and rule hotspot |
| `convert/zip_core/zip_to_ir_core.mbt` | 1917 | archive/nested dispatch hotspot |
| `doc_parse/pdf/text/rule.mbt` | 1804 | lower-layer text-flow rule hotspot |
| `core/text_normalization.mbt` | 1684 | shared normalization hotspot |
| `doc_parse/epub/epub_package.mbt` | 1648 | EPUB package/spine hotspot |
| `cli_support/cli_app.mbt` | 1535 | product routing hotspot |

## PDF Rule System Map

Current PDF code volume:

| area | files | tests | lines |
| --- | ---: | ---: | ---: |
| `convert/pdf` | 35 | 12 | 21287 |
| `doc_parse/pdf` including vendor | 280 | 120 | 70944 |
| `convert/pdf_debug` | 3 | 1 | 1812 |
| `convert/pdf_layout` | 5 | 1 | 1774 |

Layer map:

| rule area | active files | status | coverage evidence |
| --- | --- | --- | --- |
| text extraction and glyph/Unicode cleanup | `doc_parse/pdf/raw/*`, `doc_parse/pdf/text/normalize_texts.mbt`, `core/text_normalization*.mbt` | active lower-layer | `doc_parse/pdf/test/pdf_text_normalization_test.mbt`, `doc_parse/pdf/text/normalize_texts_wbtest.mbt`, `convert/pdf/pdf_text_normalization_wbtest.mbt` |
| span/line/block construction | `doc_parse/pdf/model/pdf_text_model.mbt`, `doc_parse/pdf/text/rule.mbt`, `doc_parse/pdf/text/pdf_text_*`, `convert/pdf/pdf_lines.mbt`, `convert/pdf/pdf_blocks.mbt` | active | `pdf_text_model_test.mbt`, `pdf_text_spans_wbtest.mbt`, `pdf_text_lines_wbtest.mbt`, `pdf_lines_wbtest.mbt`, `pdf_blocks_wbtest.mbt` |
| paragraph and soft line merge | `convert/pdf/pdf_merge.mbt`, `convert/pdf/pdf_merge_decision.mbt` | active | `pdf_merge_decision_wbtest.mbt`, sample PDF parse tests |
| heading/list/table/caption decisions | `convert/pdf/pdf_classify.mbt`, `pdf_heading_decision.mbt`, `pdf_layout_gate.mbt`, `pdf_table_detect.mbt`, `pdf_image_caption.mbt`, `pdf_to_ir.mbt` | active | heading/layout gate/table-caption/to-IR wbtests and PDF parse tests |
| noise/header/footer | `convert/pdf/pdf_noise.mbt`, `pdf_noise_decision.mbt`, repeated-edge parts of `pdf_layout_features.mbt` | active | `pdf_noise_decision_wbtest.mbt`, external-quality PDF guard rows |
| annotation and link matching | `doc_parse/pdf/raw/mbtpdf_annotation_adapter.mbt`, `convert/pdf/pdf_link_match.mbt`, `pdf_annotation_emit.mbt`, `pdf_form_emit.mbt` | active | `pdf_link_match_wbtest.mbt`, `pdf_to_ir_wbtest.mbt`, PDF parse tests on pdfjs annotation samples |
| note/superscript marker | `convert/pdf/pdf_merge.mbt`, `pdf_to_ir.mbt`, shared `core/ir.mbt`, `core/emitter_markdown.mbt` | active marker-only | `pdf_merge_decision_wbtest.mbt`, PDF parse tests, core note emitter tests |
| reading order and two-column guard | `doc_parse/pdf/text/rule.mbt`, `convert/pdf/pdf_merge_decision.mbt`, `convert/pdf/pdf_merge.mbt`, `convert/pdf/pdf_layout_gate.mbt` | active conservative guards | two-column negative sample, merge decision wbtests |
| cross-page merge/split | `convert/pdf/pdf_merge_decision.mbt`, `convert/pdf/pdf_merge.mbt` | active deterministic rule path | merge decision wbtests and parse tests |
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

* heading/title heuristics appear in `pdf_classify.mbt`, `pdf_heading_decision.mbt`,
  `pdf_layout_gate.mbt`, and final `pdf_to_ir.mbt`.
* text-flow heuristics are split across lower-layer `doc_parse/pdf/text/rule.mbt`,
  `normalize_texts.mbt`, `pdf_text_model.mbt`, and convert-layer merge/block
  rules. This is not automatically wrong, but the responsibility boundary
  should be documented before moving code.
* table/caption rejection signals overlap with block-feature extraction in
  `pdf_layout_features.mbt`.
* several `for_ir` helper names in `pdf_to_ir.mbt` show that final lowering is
  carrying rule logic that could later be isolated into a small
  `pdf_heading_rules` / `pdf_list_rules` file without changing public API.

Recommended next split order:

1. Extract naming-only or move-only helper groups from `pdf_to_ir.mbt` into
   focused files inside the same `convert/pdf` package.
2. Keep public API unchanged and run `moon check`, `moon test`, and
   `bash samples/check.sh` after each move.
3. Split `pdf_layout_features.mbt` only after a feature-header compatibility
   audit, because quality-lab scripts depend on feature names.
4. Keep `convert/pdf_layout` and Task A/Task B feature exports separated by
   manifest/policy, not by runtime hookup.

## Other Format Rule Audit

Current high-signal rule/heuristic areas outside PDF:

| format | active rule areas | current read |
| --- | --- | --- |
| DOCX | notes, comments, hyperlinks, tables, numbering, images, text boxes | mature enough to keep; `docx_xml.mbt` and tests are large split candidates |
| Markdown | footnotes, code fences, inline code, frontmatter, passthrough | stable; metadata line mapping is conservative |
| HTML | safe parser, links/images/tables, explicit noteref/body support | broad `<sup>` inference remains future work |
| EPUB | package/spine/nav/NCX/assets/explicit noteref merge | package file is large; rule behavior is documented and covered |
| XLSX | sheets, merged cells, formula policy, metadata hints | good package split; large formula evaluator is acceptable but should stay tested |
| PPTX | reading order, text boxes, notes, tables, images, grouping | many focused files already; reading-order file is the largest rule hotspot |
| ZIP | nested docs/assets, safe path, remap/origin policy | `zip_core` should be split later by traversal vs lowering vs asset remap |
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

* fix `doc_parse/README.md` links to current docs or archive docs
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

* large product routing/debug/benchmark files
* stale doc links from `doc_parse/README.md`
* test packages with very large all-format test files

Rule debt:

* PDF heading/list/title rules split across several files
* lower-layer and convert-layer text-flow rules need a clearer written
  responsibility boundary
* `pdf_layout_features.mbt` needs a compatibility-preserving split plan
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
2. same-package PDF rule file organization, starting with final-IR helper
   extraction from `pdf_to_ir.mbt`
3. package docs/path cleanup for `doc_parse` current-vs-archive docs
4. broader package reshaping only after the above keeps all validation green

Keep PDF model blockers paused until:

* `footer_header_noise` manual review is complete
* Task B layout data readiness is solved
* a disabled-by-default runtime proposal has separate evidence
