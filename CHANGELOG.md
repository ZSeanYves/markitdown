# Changelog

## Unreleased

* Strengthen vendored PDF native text extraction with Level 1 `/ToUnicode`
  CMap support, including `codespacerange`, `bfchar`, conservative
  `bfrange`, greedy multi-byte source-code matching, and UTF-16BE
  destination decoding, while leaving no-`/ToUnicode` CJK fallback,
  embedded-font `cmap`, and full predefined-CMap coverage out of scope.
* Document the current PDF native text-extraction support matrix across the
  README/support/package/quality docs, including retained no-`/ToUnicode`
  external boundaries for simple raw-GBK fonts and `Type0 / Identity-H`
  `CIDFontType2` samples, while keeping OCR, embedded-font `cmap`, and broad
  CJK fallback claims out of scope.
* Document the scan-only/OCR PDF boundary strategy: the default native path
  stays text-first and image-asset-preserving, scan-only rows can remain
  `reference` in the native quality gate, and OCR remains explicit rather than
  a hidden normal-path fallback.
* Add report-only PDF text-signal/OCR-candidate diagnostics to inspect/debug,
  expand `samples/quality_corpus` into a richer local dashboard with
  by-format/source/tier rollups plus retained-boundary lists, and document the
  explicit OCR-provider and advisory layout-assist provider routes without
  changing default Markdown output.
* Add lightweight OCR and layout-assist provider skeletons with lazy
  descriptor/probe/report wiring, stable `noop` baselines, and explicit
  non-goals around bundled runtimes/models or normal-path decision changes.
* Add a debug-only provider listing/probe surface so OCR/layout-assist
  skeletons can be inspected explicitly without changing the normal path or
  implying that OCR has run.
* Implement an explicit optional `tesseract-cli` OCR provider for lazy
  availability probing and page-image text recognition, while keeping OCR
  out of the default normal path and leaving PDF-level OCR/provider routing
  broader than single-page images for later work.
* Document the current external-corpus hardening state across README/support/
  roadmap/quality-corpus docs: local signal-level intake is now operational,
  real external rows have already driven fixes for PDF word-boundary repair,
  ZIP Level 1 data descriptors, YAML single-document markers, PPTX cached
  chart data, and PPTX comments, and the active local `known_bad` boundary
  remains `pandoc_biblio_yaml` because true multi-document YAML streams are
  still unsupported.
* Extract Level 1 PPTX comments from `ppt/comments/*.xml` plus
  `ppt/commentAuthors.xml`, preserving minimal author/text semantics in
  `doc_parse/pptx` and lowering them in `convert/pptx` to a conservative
  per-slide `Comments` appendix, while leaving bubble rendering, position
  recovery, threaded replies, and modern comments extensions out of scope.
* Extract Level 1 cached PPTX chart data from PresentationML chart parts,
  preserving minimal series/category/value semantics from chart XML cache in
  `doc_parse/pptx` and lowering aligned cache data to `RichTable` with a
  conservative text fallback in `convert/pptx`, while leaving full chart
  rendering, embedded-workbook fallback, and style/axis/legend/layout support
  out of scope.
* Accept a narrow Level 1 ZIP data-descriptor case when central-directory
  sizes/CRC/offsets are known, so OOXML packages can open entries written with
  bit-3 data descriptors while ZIP64/encrypted/multi-disk/full streaming
  descriptor support remains unsupported.
* Expand local `samples/quality_corpus` diagnostics and `known_bad` reporting
  so real external boundary rows stay visible as `expected_fail` /
  `unexpected_pass` signals without changing the default conversion output.

* Remove the legacy checked `samples/real_world` corpus because it was
  synthetic/regression-like rather than reliable real-world quality evidence,
  and reset `samples/quality_corpus` into an external/private intake skeleton
  with an intentionally empty public manifest, optional private-local support,
  and manual external-source registry only.
* Expand `samples/quality_corpus` into an external intake v1 skeleton with a
  source catalog, local external manifest convention, local cache guidance,
  non-downloading helper scripts, and explicit license/file skip gates while
  keeping default conversion output unchanged and leaving external datasets and
  tool fixtures unvendored.
* Add a local-only PDF layout classifier training spike with feature export,
  manual label manifests, a lightweight Python trainer, MoonBit JSON model
  loading plus deterministic inference, and evaluation/docs coverage, while
  keeping default PDF conversion output unchanged and leaving OCR/visual model
  integration optional and out of the main path.
* Expand the local-only PDF layout classifier spike with split-aware
  train/held-out manifests, additional manual labels, and held-out confusion /
  error reporting, while keeping the work scoped to training-time tooling and
  leaving default PDF conversion output unchanged.
* Mark `doc_parse/ooxml`, `doc_parse/epub`, and native text-PDF
  `doc_parse/pdf` as foundation candidates after the recent inspect,
  validation, classifier, and lower-layer contract hardening passes.
* Migrate simple-format parser foundations internally into `doc_parse/csv`,
  `doc_parse/tsv`, `doc_parse/json`, `doc_parse/yaml`, and `doc_parse/text`
  while keeping `convert/*` responsible for IR/Markdown/product semantics.
* Harden the internal simple-format foundations with package-level README
  boundaries, stronger inspect reporting, and lower-layer parser tests while
  keeping conversion outputs unchanged.
* Close `doc_parse/csv`, `doc_parse/tsv`, `doc_parse/json`, `doc_parse/yaml`,
  and `doc_parse/text` as in-tree parser foundation candidates with documented
  stable surfaces, compatibility boundaries, and known limits.
* Close `doc_parse/xml` as an in-tree XML parser foundation candidate with
  safe tokenizer/parser/model/error/inspect/validation boundaries while
  keeping `convert/xml` source-preserving.
* Sync overall `doc_parse` foundation status after the simple-format and XML
  parser candidate closures, and clarify the `doc_parse` vs `convert`
  ownership boundary without changing runtime behavior.
* Close `doc_parse/html` as an in-tree HTML DOM-ish parser foundation
  candidate with tolerant tokenizer/parser/model/inspect/validation
  boundaries while keeping `convert/html` on the current normal conversion
  path.
* Close `doc_parse/markdown` as an in-tree lightweight Markdown scanner
  foundation candidate with raw block inventory, frontmatter, fenced code,
  and inspect/validation boundaries while keeping `convert/markdown` on the
  current passthrough/product path.
* Sync `doc_parse` foundation status after the HTML and Markdown candidate
  closures, and clarify that `convert/html` and `convert/markdown` still own
  their current normal product paths.
* Add `doc_parse/xlsx` as an active SpreadsheetML semantic foundation Pass 1,
  route `convert/xlsx` through that semantic workbook model, and keep
  RichTable / IR / Markdown / product policy in the converter layer without
  changing output behavior.
* Close `doc_parse/xlsx` as an in-tree XLSX semantic foundation candidate
  with workbook/sheet/cell/sharedStrings/styles/formula/merged-range
  boundaries documented and lower-layer tests tightened, while keeping
  `convert/xlsx` zero-drift and product-policy-owned.
* Add `doc_parse/docx` as an active WordprocessingML semantic foundation
  Pass 1 with source-native body/inline/table/relationship/style/numbering/
  note parsing, inspect/validation/classifier surface, and lower-layer tests
  while keeping `convert/docx` on the current zero-drift normal conversion
  path.
* Close `doc_parse/docx` as an in-tree DOCX semantic foundation candidate
  with source-native body/inline/table/relationship/style/numbering/notes/
  media boundaries documented and lower-layer tests tightened, while keeping
  `convert/docx` on the current zero-drift normal conversion path.
* Add `doc_parse/pptx` as an active PresentationML semantic foundation
  Pass 1 with source-native presentation/slide/shape/text/table/notes/media/
  hyperlink parsing, inspect/validation/classifier surface, and lower-layer
  tests while keeping `convert/pptx` on the current zero-drift normal
  conversion path.
* Close `doc_parse/pptx` as an in-tree PPTX semantic foundation candidate
  with source-native slide/shape/text/table/notes/media boundaries documented
  and lower-layer tests tightened, while keeping `convert/pptx` on the
  current zero-drift normal conversion path.
* Sync `doc_parse` foundation status after the OOXML semantic closure:
  `doc_parse/xlsx`, `doc_parse/docx`, and `doc_parse/pptx` are now in-tree
  OOXML semantic foundation candidates; the `doc_parse` vs `convert`
  ownership boundary is clarified; and normal-path integration status is
  explicitly documented without changing runtime behavior.
* Clarify the current package publishing strategy: `doc_parse/*` remains
  importable subpackages under `ZSeanYves/markitdown`, not separately split
  MoonBit modules yet.
* Prepare `doc_parse` for future release by documenting release-facing usage,
  examples, API comments, and parser-vs-converter boundaries without changing
  runtime behavior.
* Add `doc_parse` performance strategy, measured baseline, and optimization
  roadmap notes while keeping benchmark claims scoped to the current native
  CLI harness and checked local corpus.
* Add a direct `doc_parse/*` library benchmark harness with a checked manifest,
  per-stage `open/parse/scan` + `inspect` + `validate` timing, and summary
  artifacts under `.tmp/bench/doc_parse/` without changing runtime behavior.
* Record the first direct `doc_parse/*` library baseline and hotspot
  attribution, and clarify how it differs from the existing CLI/product-path
  benchmark results.
* Add XLSX-specific doc_parse benchmark stage profiling and reduce the checked
  `xlsx_formula_heavy_missing_cache` library parse row from `14.367 ms` to
  about `2.9 ms` by removing repeated per-formula sheet-context rebuilds,
  without changing XLSX conversion output or formula-trace semantics.
* Add DOCX-specific doc_parse benchmark stage profiling and reduce the checked
  `docx_link_heavy` library parse row from `8.735 ms` to about `5.0 ms` by
  removing repeated body-scan and no-op text-box scanning work, without
  changing DOCX conversion output or semantic boundaries.
* Add YAML-specific doc_parse benchmark stage profiling and reduce the checked
  `yaml_large` library parse row from about `6.9 ms` to about `5.9 ms` by
  reducing raw line preparation and repeated trim/copy work, without changing
  YAML subset semantics or `convert/yaml` output behavior.
* Add text/JSON/Markdown-specific doc_parse benchmark stage profiling and
  reduce the checked large-input rows from about `5.0 ms -> 2.0 ms`
  (`txt_large`), `4.2 ms -> 2.8 ms` (`json_large`), and
  `3.4 ms -> 2.2 ms` (`markdown_large`) by removing repeated scans and
  duplicate trim/classification work, without changing parsing semantics or
  converter output behavior.
* Sync the post-optimization `doc_parse` performance baseline, clarify that
  the remaining major work is now product-path attribution rather than parser
  hot-path cleanup, and add a planning-only `bench_product_path_helper.sh` skeleton
  that emits stage/sample plan artifacts without changing runtime behavior.
* Add a first-pass product-path attribution benchmark with hidden
  benchmark-only CLI entrypoints, a checked manifest for
  `txt/json/yaml/csv/xlsx/html/docx/pptx`, stage summaries under
  `.tmp/bench/product_path/`, and documented caveats where `parse`,
  `convert`, and `assets` are still combined in the current normal path.
* Refine the product-path attribution benchmark so `txt/json/yaml/csv/xlsx`
  now report separate `parse` vs `convert` timing, while `html/docx/pptx`
  keep explicit combined-path reasons and refined asset-discovery/export
  notes without changing conversion output or parser/converter semantics.
* Refine rich-format product-path attribution so `html` now reports staged
  `parse/convert/assets` timing with `html_dom_scan`, `html_block_lowering`,
  `html_asset_discovery`, and `html_asset_export`, while `docx/pptx` now
  expose staged package/body/grouping/media rows and keep only the remaining
  necessary combined seams without changing conversion output, asset naming,
  or metadata shape.
* Refine DOCX product-path attribution further so the benchmark now exposes
  staged `docx_relationships`, `docx_styles`, `docx_numbering`,
  `docx_notes`, `docx_headers_footers`, `docx_text_boxes`,
  `docx_asset_map_build`, `docx_media_export`, `docx_asset_origin_attach`,
  `docx_body_xml_scan`, `docx_paragraph_scan`, `docx_table_scan`,
  `docx_inline_scan`, `docx_final_block_build`, and `docx_appended_sections`
  rows while keeping the remaining paragraph-policy / final-IR seam explicitly
  marked as a partial split and leaving DOCX output unchanged.
* Refine PPTX product-path attribution further so the benchmark now exposes
  staged `pptx_presentation_rels`, `pptx_slide_relationships`,
  `pptx_shape_collect`, `pptx_text_extract`, `pptx_table_extract`,
  `pptx_reading_order`, `pptx_grouping`, `pptx_classification`,
  `pptx_image_inventory`, `pptx_image_export`, `pptx_asset_origin_attach`,
  `pptx_notes_parse`, and `pptx_final_block_build` rows while keeping the
  remaining slide-loop document-build / policy seam explicitly marked as a
  partial split and leaving PPTX output unchanged.
* Optimize the TXT product path without changing output semantics by removing
  redundant shared cleanup and normalized-text copying on large clean inputs,
  refining TXT benchmark attribution into parse/literal-wrap/emit-write
  substages, and reducing the checked `txt_large` same-process product total
  from about `10.7 ms` to about `7.6 ms`.
* Sync the post-TXT-optimization performance baseline so the documented
  library and same-process product-path snapshots, startup caveat, completed
  optimization passes, and remaining hotspot list all match the latest
  checked local benchmark results without changing runtime behavior.
* Finalize the performance narrative after product-path attribution by
  documenting the three-layer view (`doc_parse` library path, same-process
  product path, and cold CLI startup), refreshing the latest TXT/DOCX/PPTX/
  HTML/XLSX baseline notes, and clarifying that product-path PDF attribution
  is now first-pass covered for the native text-PDF path while direct
  `doc_parse/pdf` library attribution remains deferred.
* Add first-pass native text-PDF product-path attribution for
  `pdf_metadata_uri_link`, including staged `pdf_backend_select`,
  `pdf_extract_model`, `pdf_line_build`, `pdf_block_build`,
  `pdf_block_classify`, `pdf_noise_filter`, `pdf_merge`,
  `pdf_annotation_handling`, and `pdf_final_block_build` rows, without
  changing PDF conversion output, OCR behavior, or fallback policy.
* Document compatibility surfaces, non-goals, and candidate boundaries for the
  OOXML, EPUB, and PDF parsing foundations without expanding their functional
  scope.
* Sync current documentation after the rule-driven text-normalization rollout
  and PDF span-glue fallback tightening.
* Clarify that shared text normalization is a conversion-quality substrate, not
  a standalone product surface.
* Clarify that canonical normalization remains explicit-only and is still not
  part of default converter behavior.
* Mark older roadmap/progress/audit documents as historical where current
  source-of-truth pages already supersede them.
* Add a focused cold CLI startup benchmark suite, document the split between
  same-process `startup_probe` and full process-per-file timing, and reduce
  avoidable `_bench-noop` CLI front-end work without changing conversion
  output or normal command behavior.
* Close cold CLI startup attribution with a hidden main-internal startup
  profile, `cold_start/startup_profile.*` artifacts, and documentation showing
  that the remaining checked native process-per-file cost is now dominated by
  process/runtime startup rather than by CLI main-path work.
* Add explicit cold-start attribution rows for checked `noop`, `--help`, and
  minimal TXT conversion, while keeping same-process product totals separate
  from full process-per-file startup.

## v0.3.4 - Text normalization rollout and release-readiness documentation draft

This draft release note captures the repository state after the shared
document-cleanup rollout widened across the main text-bearing formats while
keeping converter defaults stable.

### Highlights

* Shared document cleanup is now reused by PDF, TXT, HTML, DOCX, and PPTX.
* The project facade now exposes explicit `normalize_nfd/nfc/nfkd/nfkc` and
  `is_normalized_*` APIs backed by `tonyfettes/unicode`.
* Canonical normalization remains explicit-only and is still not part of the
  repository's default converter behavior.
* Full `NormalizationTest.txt` conformance validation is still pending, so the
  repository does not claim complete ICU/UAX #15 equivalence.

### Rollout scope

* PDF shares only low-risk character cleanup through the core facade; layout
  and structure heuristics remain PDF-local.
* TXT routes low-risk document cleanup through the shared facade while keeping
  paragraph semantics local.
* HTML uses the shared cleanup only at the normal text-node seam and does not
  apply it to raw source, `pre/code`, or attribute paths.
* DOCX uses the shared cleanup only for `scan_docx_inline_text` `w:t`
  plain-text payloads.
* PPTX uses the shared cleanup only for `extract_text_runs` `<a:t>`
  plain-text payloads on the normal inline path; fallback accumulation,
  `<a:br>`, hyperlink assembly, shape-level link fallback, slide/text-layout
  heuristics, notes, tables, hidden slides, and image metadata remain local.

### Validation and documentation

* Repository documentation now consistently describes the facade-backed
  canonical normalization state and its conformance caveat.
* Current checked validation snapshot has been refreshed to the latest local
  verification totals used for release readiness.
* This release note draft does not record any converter/parser/emitter
  behavior change by default.

## v0.3.3 - Validation surface and complex real-world corpus release

This release finishes the repository's public validation-surface cleanup and
lands a checked-in complex-only `real_world` corpus for richer scenario
coverage.

### Highlights

* Public repository validation is now centered on `./samples/check.sh`.
* Public repository benchmark entry is now centered on `./samples/bench.sh`.
* GitHub Actions validation remains checked in for Ubuntu and macOS, while the
  smoke benchmark stays manual.
* The checked-in `samples/real_world` corpus now keeps only the longer complex
  scenario layer across DOCX, PPTX, XLSX, PDF, HTML, ZIP, and EPUB.
* Default `./samples/check.sh` includes the full checked-in real-world corpus
  because the current 11-row set is still lightweight enough for the standard
  validation path.

### Samples and validation

* `samples/main_process` remains the feature-focused regression corpus.
* `samples/real_world` now provides 11 checked long-form or stress-style
  scenario rows with expected Markdown for every row.
* Exact metadata fixtures are checked in for every real-world row.
* Asset-producing real-world rows keep `refs_exist` validation rather than
  binary asset diffing.
* `samples/fixtures` remains the lower-layer parser/core and fail-closed
  fixture tree.
* Python sample generator scripts and stale public wrapper scripts are no
  longer part of the normal validation story.

### Documentation and workflow

* README, samples docs, and development docs now describe the unified sample
  and benchmark entrypoints.
* Release documentation now reflects the complex-only real-world corpus shape
  and its place outside the benchmark evidence path.
* `moon publish` remains a manual release step.

### Scope note

* This release does not change converter, parser, or emitter semantics by
  itself; it primarily packages checked-in corpus, validation-surface, and
  release-documentation work.

## v0.3.1 - Second-round H2++/H3++ hardening release

This release closes the second-round hardening cycle for `markitdown-mb`, a
MoonBit-native document-to-Markdown converter inspired by Microsoft
MarkItDown.

### Format hardening

* XLSX: H2++ complete with lightweight formula evaluation, formula policy
  metadata, typed cells, merged-cell policy, sheet state, and benchmark
  evidence.
* HTML: H2++ complete with safe lightweight parsing, unsafe-link fail-closed
  behavior, table span hints, local image/figure asset handling, and
  provenance evidence.
* ZIP: H2++ complete as a safe container converter with nested supported entry
  dispatch, unsupported-entry warnings, path safety boundaries, and asset
  remapping.
* EPUB: H2++ complete with OPF package/spine handling, EPUB3 nav, minimal
  EPUB2 NCX support, guide cover fallback, cover/assets handling, and warning
  degradation.
* DOCX: H2++ complete with document structure, nested lists, links, tables,
  images, notes/comments, headers/footers, text boxes, docProps, and
  metadata/assets evidence.
* PPTX: H2++ complete with slide order, reading order, bullets, links, images,
  notes, hidden-slide policy, explicit tables, table-like/caption-like
  grouping, and metadata evidence.
* PDF: H2++ complete for native text-PDF scope with heading/noise/cross-page
  merge, URI links, simple table-like output, image captions, metadata
  fixtures, and benchmark evidence.

### CLI and workflow

* Hardened `normal`, `batch`, stdout, assets, and `--with-metadata` contracts.
* Added unified multi-format `debug` and `debug --json` inspect CLI.
* Consolidated legacy PDF debug behavior into the unified debug path.
* Added GitHub Actions validation for Ubuntu and macOS.
* Kept benchmark smoke as a manual workflow.

### Text and metadata infrastructure

* Added Text Normalization v2 with profile-driven and stage-driven
  normalization.
* Added PDF `PdfText` and `PdfCompareText` normalization paths.
* Protected literal/raw contexts from aggressive normalization.
* Improved metadata sidecar, asset provenance, and debug inspect summaries.
* Narrowed convert package public APIs around stable parse/inspect entry
  points.

### Evidence and benchmarks

* Added quality comparison records across core formats.
* Added benchmark governance and corpus-scoped performance reporting.
* Documented representative prebuilt-native speedups against Microsoft
  MarkItDown `0.1.5` on checked-in overlap corpora.
* Kept performance claims scoped to checked-in corpora and documented
  non-comparable cases.

### Known limits

* No full Word/PowerPoint/PDF visual layout engine.
* No default OCR or scanned-PDF claim.
* No browser-grade HTML engine, CSS layout, JavaScript, or remote fetch.
* No DRM support for EPUB.
* No nested archive recursion for ZIP.
* No full Excel formula engine.
* At the time of `v0.3.1`, Unicode NFC/NFKC canonical normalization remained a
  documented hook rather than a claimed ICU/UAX #15 implementation.
* Current repository note: explicit `NFD/NFC/NFKD/NFKC` facade APIs are now
  wired through `tonyfettes/unicode`, but default converter behavior still
  does not enable canonical normalization and full conformance remains
  incomplete.

## v0.3.0

This release closes the repository's first full-format H2 milestone.

### Highlights

* All primary formats now have H2-complete support contracts:
  * TXT
  * Markdown
  * CSV / TSV
  * JSON
  * YAML / YML
  * XML
  * HTML / HTM
  * XLSX
  * ZIP
  * EPUB
  * DOCX
  * PPTX
  * PDF
* Multi-format conversion, Markdown output, metadata sidecars, asset export,
  and origin/provenance wiring are now stable project-wide product surfaces.
* Batch conversion v1 is available for non-recursive directory conversion.
* Sample validation scripts were reorganized around:
  * `./samples/check.sh`
  * `./samples/check_main_process.sh`
  * `./samples/check_metadata.sh`
  * `./samples/check_assets.sh`
  * advanced helpers and benchmark tools under `./samples/helpers/`
* Validation now prefers a probe-validated native CLI when available and falls
  back to `moon run` only when needed.
* The PDF lower layer now lives under `doc_parse/pdf`, backed by a
  repository-local maintained fork under `doc_parse/pdf/vendor/mbtpdf`.
* Benchmark, batch-profiling, and regression-warning tools are available for
  H3 performance work.

### Notes

* H2 complete does not mean every advanced format-specific feature is fully
  implemented.
* Known limitations remain documented in
  `docs/support-and-limits.md`.
* Accept single-document YAML start/end markers (`---` / `...`) while keeping
  multi-document streams unsupported in the conservative YAML subset parser.
