# Changelog

## Unreleased

### Current baseline

* main-repo runtime, `moon test`, and `./samples/check.sh` remain self-contained
* optional external quality now runs through `bash ./samples/check_quality.sh`
* repo-root `markitdown-quality-lab/` is the primary home for:
  * external corpus payloads
  * tracked local/full quality rows
  * PDF layout classifier training/eval/model/report assets
  * generator scripts that do not belong in runtime

### Validation snapshot

* `moon test`: `1579 passed`
* `./samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`
* full quality: external-corpus scoped; row counts depend on the checked-out
  `markitdown-quality-lab` manifest
* focused PDF quality: `79 rows / 0 failed / 1 skipped / 0 expected_fail`

### Product/runtime boundary

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* current PDF layout behavior in the normal path remains distilled into narrow MoonBit rules/gates
* OCR remains explicit-only
* `cli mbtpdf count = 0`
* `zip mbtpdf count = 0`
* `pdf mbtpdf count = 23339`

### Recent structural changes

* PDF native text-flow recovery has been tightened for:
  * paragraph soft merge across nearby fragments
  * superscript-style note marker attachment through shared note refs
  * numbered heading split/promotion when the text signal is strong
  * two-column negative guards that prevent cross-column paragraph merge
* PDF annotation-link handling now upgrades a high-confidence URI annotation to
  Markdown link syntax when the visible label is a unique substring inside a
  merged text block, while duplicate-label or invisible-only annotations stay
  conservative
* shared note IR support now covers:
  * `Inline::NoteRef` for inline references
  * document-level `Document.note_definitions` for resolved note bodies
  * metadata sidecar `note_definitions` plus `summary.note_definition_count`
    for resolved note bodies
  * DOCX structured footnotes and endnotes as full Markdown footnotes
  * Markdown native footnote passthrough and normalization as full Markdown
    footnotes when bodies exist
  * EPUB explicit strong noterefs as full Markdown footnotes
  * PDF marker-only fallback when the marker is known but body association is
    not reliable
* quality-lab migration completed for:
  * external corpus payloads
  * tracked full/local quality rows
  * PDF layout classifier training/eval scripts and reports
  * encoding generator scripts
* repo-tracked PDF fixtures required by `moon test` were kept in the main repo
* the PDF layout dev/export/infer MoonBit entrypoint now lives under
  `doc_parse/pdf/layout_model_tool`
* `samples/pdf_layout_classifier/` has been removed from the main repo
* `samples/check_quality.sh` is now the preferred optional full-quality entrypoint
* `samples/check.sh` now defaults to full repo-local validation instead of light manifest checks
* `samples/bench.sh` now defaults to the recommended smoke suite and writes summaries under `.tmp/bench/`
* CLI batch v1 orchestration now lives in same-package
  `cli_support/cli_batch.mbt`, and explicit main-CLI OCR policy/image OCR
  execution now lives in same-package `cli_support/cli_ocr.mbt`; optional CLI
  profile env gates/stage logging now live in same-package
  `cli_support/cli_profile.mbt`; bundled PDF/ZIP component delegation now lives
  in same-package `cli_support/cli_components.mbt`, keeping normal conversion
  routing in `cli_support/cli_app.mbt`; stable output/path/document-property
  helpers now live in same-package `cli_support/cli_output.mbt`
* README entry points were cleaned for faster first-read onboarding
* top-level docs navigation and archive/current-doc boundaries were polished
* doc-parse and archived benchmark navigation now avoid stale current-doc links
* stale OCR archive notes and legacy TSV-signal helper references were pruned
* current image OCR and PDF OCR boundaries were clarified across docs
* split media-focused origin metadata regressions out of the large all-format
  `convert/convert/test/origin_metadata_test.mbt` into same-package
  `origin_metadata_media_test.mbt`
* split structured-text block-origin regressions out of the large all-format
  `convert/convert/test/origin_metadata_test.mbt` into same-package
  `origin_metadata_structured_text_test.mbt`
* split shared origin metadata regression helpers out of
  `convert/convert/test/origin_metadata_test.mbt` into same-package
  `origin_metadata_helpers_test.mbt`
* split metadata sidecar snapshot regressions out of
  `convert/convert/test/origin_metadata_test.mbt` into same-package
  `origin_metadata_snapshots_test.mbt`, reducing the mixed origin metadata
  suite below the 1000-line threshold
* split ZIP HTML local-image reference scanning helpers out of
  `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_html_refs.mbt`
* split ZIP normalized path, entry id, extension classification, and path sort
  helpers out of `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_entry_paths.mbt`
* split ZIP archive inspection, entry action planning, normalized collision
  detection, and dispatch-format tagging out of
  `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_inspect_plan.mbt`
* split ZIP subdocument asset remapping, archive asset path namespacing, asset
  file copy, and remapped asset-origin policy out of
  `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_asset_remap.mbt`
* split ZIP converted-entry aggregation, warning emission, block origin
  rewriting, and markdown trimming out of
  `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_entry_aggregate.mbt`
* split ZIP entry output-dir policy, flat staging policy, safe archive
  materialization, temporary run-dir lifecycle, and filesystem path helpers out
  of `convert/zip_core/zip_to_ir_core.mbt` into same-package
  `convert/zip_core/zip_entry_staging.mbt`
* split EPUB safe archive materialization, temporary run-dir lifecycle,
  extracted-entry path normalization, and entry id/path helpers out of
  `convert/epub/epub_parser.mbt` into same-package
  `convert/epub/epub_entry_staging.mbt`
* split EPUB converted-entry aggregation, warning emission, block origin
  rewriting, note-definition source marking, and markdown trimming out of
  `convert/epub/epub_parser.mbt` into same-package
  `convert/epub/epub_entry_aggregate.mbt`
* split EPUB subdocument asset remapping, asset file copy, note-body asset path
  remapping, and remapped asset-origin policy out of
  `convert/epub/epub_parser.mbt` into same-package
  `convert/epub/epub_asset_remap.mbt`
* split EPUB note-ref id namespacing and note-ref source-kind marking out of
  `convert/epub/epub_parser.mbt` into same-package
  `convert/epub/epub_note_refs.mbt`
* split lower-layer EPUB archive/path safety, cover discovery, and nav/NCX
  parsing helpers out of `doc_parse/epub/epub_package.mbt` into same-package
  focused helper files
* split DOCX note/comment body parsing, inline note/comment marker rules,
  header/footer page-field rules, and text-box/deleted-revision helpers out of
  `convert/docx/docx_xml.mbt` into same-package focused helper files
* split HTML note-plan, strong noteref detection, footnote-body detection, and
  note-definition rendering helpers out of `convert/html/html_dom.mbt` into
  same-package `convert/html/html_notes.mbt`
* split HTML navigation/noise subtree rules and shared tag/attribute helpers
  out of `convert/html/html_dom.mbt` into same-package
  `convert/html/html_noise_rules.mbt` and `convert/html/html_tag_attrs.mbt`
* split HTML table type/row normalization, header detection, and
  rowspan/colspan lowering helpers out of `convert/html/html_dom.mbt` into
  same-package `convert/html/html_table.mbt`
* split HTML inline scanning/rendering, figure image/caption helpers, and href
  sanitization/redirect unwrapping out of `convert/html/html_dom.mbt` into
  same-package `convert/html/html_inlines.mbt`
* split HTML block-like detection, `<pre>` text extraction, and paragraph
  flush/blank/trim helpers out of `convert/html/html_dom.mbt` into
  same-package `convert/html/html_block_helpers.mbt`, reducing the main DOM
  scanner below the 1000-line hotspot threshold

### PDF rule organization

* split lower-layer PDF span text artifact repair, citation/ligature compact
  token repair, and hyphenated word-wrap merge helpers out of
  `doc_parse/pdf/text/normalize_texts.mbt` into same-package
  `doc_parse/pdf/text/pdf_text_span_artifact_rules.mbt`, reducing the main
  normalizer below the 1000-line hotspot threshold
* split lower-layer PDF model span adjacency glue, punctuation/script
  classifiers, English fragment repair, hyphen/ligature wrap signals, and span
  spacing/source-ref adjacency helpers out of
  `doc_parse/pdf/model/pdf_text_model.mbt` into same-package
  `doc_parse/pdf/model/pdf_text_glue_rules.mbt`, reducing the main model file
  below the 1000-line hotspot threshold
* split lower-layer PDF raw `TJ` array word-spacing extraction,
  punctuation/script classifiers, decimal and hyphen join guards, and
  explicit-space boundary checks out of
  `doc_parse/pdf/raw/mbtpdf_text_adapter.mbt` into same-package
  `doc_parse/pdf/raw/mbtpdf_tj_spacing_rules.mbt`, reducing the main raw text
  adapter below the 1000-line hotspot threshold
* split final PDF IR text-shape helpers out of `convert/pdf/pdf_to_ir.mbt`
  into same-package `convert/pdf/pdf_ir_text_rules.mbt`
* split final PDF IR heading role/depth/normalization helpers into
  same-package `convert/pdf/pdf_ir_heading_rules.mbt` and document-title shape
  signals into `convert/pdf/pdf_ir_title_signals.mbt`
* split PDF layout feature signal/geometry helpers out of
  `convert/pdf/pdf_layout_features.mbt` into same-package
  `convert/pdf/pdf_layout_feature_signals.mbt`, keeping exported builders and
  feature key strings in place
* split PDF layout gate evidence/context/decision helpers into same-package
  `convert/pdf/pdf_layout_gate_support.mbt`, keeping the public gate API and
  decision thresholds unchanged
* split PDF merge boundary/continuation signal helpers into same-package
  `convert/pdf/pdf_merge_boundary_signals.mbt`, preserving cross-page merge
  and paragraph continuation decisions
* split layout text/content signals into same-package
  `convert/pdf/pdf_layout_text_signals.mbt` so feature-key assembly,
  link/geometry helpers, and text signals have clearer boundaries
* split layout caption/object/link/code text signals into same-package
  `convert/pdf/pdf_layout_object_signals.mbt`, keeping feature key strings and
  quality-lab report names unchanged
* split layout lexical/token helpers into same-package
  `convert/pdf/pdf_layout_lexical_signals.mbt` while keeping feature signal
  names and runtime behavior unchanged
* split lower-layer PDF page-number/page-label cleanup rules out of
  `doc_parse/pdf/text/rule.mbt` into same-package
  `doc_parse/pdf/text/pdf_text_page_rules.mbt`
* split lower-layer PDF span source-order/visual-boundary helpers out of
  `doc_parse/pdf/text/rule.mbt` into same-package
  `doc_parse/pdf/text/pdf_text_visual_rules.mbt`
* split lower-layer PDF line geometry/paragraph-continuation helpers out of
  `doc_parse/pdf/text/rule.mbt` into same-package
  `doc_parse/pdf/text/pdf_text_line_rules.mbt`
* split shared lower-layer PDF text signals and public caption/intro guards out
  of `doc_parse/pdf/text/rule.mbt` into same-package
  `doc_parse/pdf/text/pdf_text_signal_rules.mbt`
* kept runtime behavior, model loading, OCR wiring, and converter Markdown
  semantics unchanged

### Current caution notes

* `0 expected_fail` is not a blanket format-completeness claim
* OCR/scanned behavior remains explicit-only
* PDF footnote body association is still future work; PDF note output remains
  marker-only unless a resolved body exists
* broader HTML conservative noteref inference remains future work beyond the
  explicit same-document noteref/body pairs already recognized
* runtime model/gate loading and OCR provider expansion remain out of the
  normal product path
* benchmark and compare numbers remain local and sample-scoped
* quality-lab is not a release artifact

### Architecture consolidation audit

* added a current-state architecture/package/rule-system consolidation audit
  covering package boundaries, PDF rule layers, metadata sidecar status, OCR
  boundary requirements, and the next safe refactor sequence
* fixed current-doc navigation for the doc-parse package notes
* expanded metadata sidecars to include document-level note definitions only
  when resolved note bodies are present
* no package move, runtime model hook, OCR provider implementation, or default
  converter Markdown semantic change is included in this pass
