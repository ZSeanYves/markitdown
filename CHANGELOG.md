# Changelog

## Unreleased

* Summarize the current post-pruning / cross-format baseline:
  vendored `mbtpdf` is now maintained as a trimmed local PDF support subtree
  rather than as a full upstream mirror; stale residue, command/example
  packages, unused side packages, the old text facade, and the remaining e2e
  surface have been pruned, while runtime-critical parser/text/image/layout
  support plus local attribution files remain in place.
* Record the current product-closure boundary explicitly:
  `cli mbtpdf count = 0`, `zip mbtpdf count = 0`, and `pdf mbtpdf count =
  23339`; recent CSV `cp932/mskanji` fallback hardening stays sealed behind a
  CSV-local helper and does not pull PDF closure back into lightweight `cli`
  or delegated product `zip`.
* Freeze the current checked local quality snapshot as the post-pruning
  cross-format baseline:
  `330` rows / `1` skipped / `0 expected_fail`, with focused rows at
  `PDF 101`, public-only checked-in `PDF 24`, `DOCX 60`, `PPTX 55`,
  `XLSX 51`, `EPUB 16`, `ZIP 15`, `XML 9`, `CSV 15`, and `HTML 5`.
  This remains an external-fixture-driven local validation state rather than a
  release artifact; `.external/quality_corpus` and
  `samples/quality_corpus/external_manifest.local.tsv` stay local-only.
* Capture the current quality-strengthening scope without widening claims:
  checked-in repo-tracked PDF guards now cover text, layout,
  paragraph/noise, links, and images; local-only external PDF guards cover
  CJK/`/ToUnicode`, annotations, forms, links, and images; second-cycle
  local-only guards also now cover XLSX/DOCX/PPTX plus EPUB/ZIP/XML/CSV tail
  cases.
* Keep the boundary language conservative:
  `0 expected_fail` is not a universal-support claim, OCR/scanned content
  remains explicit-only, and benchmark/compare numbers remain local and
  sample-scoped rather than release-grade guarantees.

* Rename the split native packages to their current product/tool names:
  `cli_debug -> debug`, `cli_bench -> bench`, `cli_ocr -> ocr`,
  `cli_pdf -> pdf`, and `cli_zip -> zip`, while keeping `cli` as the
  unified user-facing product entrypoint.
* Split the native CLI surface into lightweight `cli` plus explicit
  `pdf`, `zip`, `debug`, `ocr`, and `bench` binaries,
  move heavy PDF and ZIP normal-path conversion out of the lightweight binary,
  and update helper scripts so normal validation/bench flows reuse `cli`
  while PDF/ZIP/debug/OCR/hidden benchmark routes build their own binaries
  only on demand; the local audit reduced normal `cli.c` from about
  `37M / 824k` lines to about `17M / 380k` lines, removed vendored `mbtpdf`
  from normal `cli` entirely, and reduced one measured full native rebuild
  from about `476-500s` to about `265s`, while leaving normal Markdown output
  unchanged, keeping the heavy PDF native-text closure behind `pdf`, and
  making `zip` delegate embedded PDF entries so ZIP no longer embeds
  vendored `mbtpdf`.
* Refine the split product CLI into a product-grade launcher/component shape:
  shared runtime and component discovery now live in `cli_common`, `pdf` no
  longer pulls OOXML/EPUB metadata helpers through `cli_support`, `cli ocr`
  delegates transparently to `ocr` as part of the product entry, and the
  current Ubuntu audit runner now measures one recent cold native build at
  about `16s` for `cli`, `16s` for `pdf`, `15s` for `zip`, and `10s`
  for `ocr`.
* Reintegrate PDF and ZIP into the user-visible product CLI surface without
  blowing up the main binary: `cli` now supports bare `<input>`, `help`,
  `version`, and normal PDF/ZIP entrypoints again, while a guardrail audit
  keeps the heavy PDF/container closures behind transparently discovered
  bundled `pdf` / `zip` components after a direct in-process attempt
  pushed `cli` up to about `30M / 653k` generated-C lines and about `24.6s`
  cold rebuild time on the current Ubuntu runner.
* Trim the heavy native PDF component further without changing converter
  semantics: the product path now imports a parse-only `pdfopsread` subset
  instead of the broader graphics facade, large vendored Shift-JIS and glyph
  lookup payloads now compile from compact blobs instead of thousands of
  source literals, encrypted PDFs still fail closed, and a recent cold native
  `pdf` build on the current Ubuntu runner dropped from about
  `109s / 454k` generated-C lines to about `16s / 381k` lines while
  `moon test`, `./samples/check.sh`, PDF contracts, and the quality corpus
  stayed green.
* Refresh README and the main `docs/` authority pages so they match the current
  package/component architecture, bundled PDF/ZIP product routing, OCR
  explicit-only boundary, build guardrails, and quality-corpus hygiene rules.
* Tighten HTML content-root selection against real external documentation pages:
  prefer explicit `id="content"` / `role="main"` roots before fuzzier
  `post/article/content` matches, reject obvious footer/sidebar noise from the
  strong-content heuristic, and keep large static HTML pages like MDN from
  collapsing to empty output.
* Stop leaking commented HTML/XHTML markup into normal Markdown output:
  comment blocks now stay non-content in the shared HTML scanner, so EPUB/XHTML
  samples with commented-out optional sections no longer surface stray
  commented headings, links, or trailing `-->` text.
* Broaden conservative XML source-preserving intake under external-corpus
  pressure: `.xml` conversion now honors BOM- or declaration-driven UTF-16
  and ISO-8859-1 inputs instead of hard-failing all non-UTF-8 sources, while
  broad legacy-charset guessing remains out of scope.
* Harden EPUB package-open robustness under external-corpus pressure:
  remote/scheme manifest sidecars no longer abort otherwise-local books, and
  commented-out OPF manifest markup is now ignored instead of being mistaken
  for duplicate live entries.
* Preserve richer DOCX note/comment semantics under external-corpus pressure:
  bookmark-only hyperlinks now lower to internal fragment links, OOXML
  address-plus-anchor hyperlinks keep their fragment target instead of dropping
  the anchor, and comment/footnote/endnote appendices now preserve
  conservative Markdown links plus exported image refs when the note part
  carries its own hyperlink/media relationships.
* Improve PPTX cached-chart lowering under external-corpus pressure:
  explicit chart titles from PresentationML chart parts now reach normal
  Markdown output instead of being dropped, and cached Excel date-serial
  categories now lower to stable readable ISO-style dates rather than raw
  `37261.0`-style floats.
* Lower stable non-link PDF annotations conservatively into a trailing
  `Annotations` appendix: `/Text`, `/Highlight`, and `/FileAttachment`
  samples from pdf.js now preserve visible subject/content payload instead of
  silently dropping everything except the page text, while ambiguous or
  non-user-visible annotation cases remain out of the normal-path contract.
* Lower stable PDF internal destinations conservatively under external-corpus
  pressure: visible `/GoTo` link annotations now preserve resolved target-page
  notes in the `Annotations` appendix, and outline-only PDFs can emit a
  readable trailing `Bookmarks` appendix instead of collapsing to empty
  output.
* Harden the PDF annotation appendix further against real pdf.js fixtures:
  stable `/FreeText`, `/Line`, `/Square`, `/Circle`, `/Underline`,
  `/StrikeOut`, and printable `/Ink` payloads now have external-corpus
  coverage, while degenerate subject-only shell annotations are filtered out
  instead of surfacing redundant low-value appendix lines.
* Extract Level 1 XLSX worksheet comments from `comments*.xml` parts and lower
  them conservatively after each owning sheet table as a `Comments` appendix,
  while leaving inline note rendering, floating comment placement, and broader
  workbook annotation semantics out of scope.
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
* Add local-only PDF layout-assist dataset intake and ablation tooling:
  `fetch_tiny_subsets.py`, `export_manifest_features.py`, and
  `local_eval.py`, plus first-round documentation for report-only
  rules-vs-model ablations and conservative gated rollout criteria.
* Expand the local-only PDF layout-assist eval loop with richer footer/link/
  code-like features, extra doc-style `epubcheck` / `BookReporter` weak-label
  samples, and multi-round ablation notes showing a best-so-far report-only
  gated configuration plus an overfit round that correctly failed held-out
  checks.
* Freeze the current report-only PDF layout-assist baseline as the named
  `gated_conservative_v1` preset, add cheap caption-marker and short
  annotation-anchor features/guards, expand held-out controls for caption/link/
  repeated-header cases, and keep the work strictly local-only/report-only
  after the expanded held-out loop reached a newer best gated score without
  held-out regressions.
* Expand the report-only PDF layout-assist loop with receipt / BookReporter /
  repeated-shell hard negatives, stronger local heading/list precision guards,
  and a larger `206 / 161` train/held-out split; the current
  `gated_conservative_v1` run now reaches `0.9130` held-out micro F1 with
  `0` held-out regressions while normal PDF output still stays unchanged.
* Extend the report-only PDF layout-assist loop again with more CJK
  short-sentence negatives, command/help-text `keep_as_text` rows, and
  annotation-adjacent link controls; the current `gated_conservative_v1` run
  now reaches `0.9231` held-out micro F1 on a `217 / 169` split with
  `0` held-out regressions, higher `heading` precision, and no normal-path
  output change or runtime model dependency.
* Correct standalone-bullet hard negatives in the local-only `epubcheck`
  training slice, add a new `annotation-freetext` held-out negative, and keep
  the PDF layout-assist work strictly report-only/eval-only; the current
  `gated_conservative_v1` run now reaches `0.9667` held-out micro F1 on a
  `220 / 180` split with `0` held-out regressions, while `link_text` and
  `caption` positive support still remain too small for any normal-path
  proposal.
* Expand the real held-out PDF layout-assist support set with Apache / NIST /
  IETF fixtures for `link_text` and `caption`, keep the work strictly
  report-only/eval-only, and confirm that `gated_conservative_v1` still beats
  rules-only on the harder `195`-row held-out slice with `0` regressions;
  real held-out support now reaches `link_text = 9` and `caption = 8`, but
  long TOC / page-number-like / paragraph-with-URL anchors still block any
  later normal-path proposal.
* Add a cheap deterministic link/caption feature pass for the report-only PDF
  layout-assist loop: export link coverage / target-kind / partial-link /
  page-number-link / TOC-anchor / visible-URL and caption lead-in /
  object-proximity signals, then tighten the local-only arbiter so long
  named/internal paragraph anchors stop forcing `link_text`; the harder
  `223 / 195` held-out run now reaches `0.9487` for
  `gated_conservative_v1` vs `0.9231` for `rules_only`, keeps held-out
  regressions at `0`, and still does not change the normal PDF path.
* Add a later residual feature pass for the report-only PDF layout-assist
  loop: export technical-literal, receipt/payment, cleanup-shell, and URL
  boundary features; tighten the local-only arbiter around `keep_as_text` and
  `form_row`; and raise the same harder `223 / 195` held-out run again to
  `0.9744` for `gated_conservative_v1` vs `0.9538` for `rules_only`, while
  still keeping held-out regressions at `0`, keeping normal output unchanged,
  and leaving the remaining blocker set at `Summary` plus a few
  `paragraph`/`keep_as_text` boundary rows.
* Add a later paragraph-boundary feature pass for the report-only PDF
  layout-assist loop: export figure/section-reference sentence guards in the
  Moon feature exporter, keep the work strictly local-only/report-only, and
  raise the same harder `223 / 195` held-out run again to `0.9846` for
  `gated_conservative_v1` vs `0.9641` for `rules_only`, while still keeping
  held-out regressions at `0`, keeping normal output unchanged, and shifting
  the remaining blocker set down to `Summary`, a standalone visible URL row,
  and one small receipt/body boundary row after a very narrow report-only
  figure-reference sentence exception safely fixed the checked
  `Figure 6 illustrates ...` residual.
* Implement an explicit optional `tesseract-cli` OCR provider for lazy
  availability probing and page-image text recognition, while keeping OCR
  out of the default normal path and leaving PDF-level OCR/provider routing
  broader than single-page images for later work.
* Wire the explicit `ocr` CLI subcommand to the `tesseract-cli` provider for
  supported image inputs, including explicit provider/lang selection and clear
  unavailable/unsupported errors, while keeping `normal` unchanged and leaving
  direct PDF OCR outside the `tesseract-cli` path.
* Add an OCR image sample/contract suite for the explicit `ocr` CLI path,
  covering unknown-provider, unsupported-input, unavailable-provider, and
  image-route boundary behavior in the default gate, plus an optional local
  `tesseract-cli` smoke that stays outside CI and does not claim OCR quality.
* Document the OCRmyPDF provider audit/design boundary for future explicit PDF
  OCR: OCRmyPDF remains external and unimplemented, image OCR through
  `tesseract-cli` remains the only shipped OCR execution path, and any future
  PDF OCR route must stay explicit, provenance-tagged, and outside the normal
  native-text conversion path.
* Document the PaddleOCR / PP-Structure heavy-provider boundary: PaddleOCR
  remains an external unimplemented future provider, model/runtime assets stay
  user-managed, any future OCR/layout/table route must remain explicit and
  provenance-tagged, and no heavy-provider output is allowed to bypass the
  normal text-first conversion path.
* Surface report-only `layout_assist` advisory predictions in PDF debug/inspect
  reports, using conservative heuristic-provider signals and provider summaries
  without changing normal Markdown output or enabling model-backed decisions.
* Add a debug-only layout-assist evaluation surface that summarizes advisory
  prediction coverage, label distribution, and top reasons across the local
  PDF layout-classifier manifest, without claiming accuracy improvements or
  changing default Markdown output.
* Extend the lightweight PDF layout-assist path toward a real report-only
  pipeline: the feature export now includes richer cheap native-text layout
  signals, debug/inspect predictions now expose `rule_label_hint`,
  `disagreement`, deterministic constraints, and a conservative
  `would_change_output` estimate, and the dataset/license audit plus the
  recommended offline-training/held-out rollout plan are now documented in
  `docs/pdf-layout-model.md` without changing normal PDF Markdown output.
* Add a first gated-normal PDF layout-assist v1 in pure MoonBit:
  normal PDF conversion now includes a tiny distilled arbiter for two
  low-risk cases only, weak heading demotion and separator/false-bullet
  suppression; the gate keeps text-decoding/link/table hard facts above the
  override path, exposes debug reasons and blocked-override traces, ships no
  model weights or Python runtime dependency, can be disabled with
  `MARKITDOWN_PDF_LAYOUT_GATE=0`, and passes the full validation/build gate
  without turning the broader provider/report-only pipeline into a general
  normal-path model rollout.
* Refresh the public docs/README quality and performance story around measured
  facts only: the local external corpus currently passes at `142` rows with
  `1` skipped row and `5` unexpected passes, clean native build guardrails
  are documented with the current local binary/line-count snapshot, and
  mainstream quality percentages or speed multiples are now only claimed when
  a pinned compare suite and metric definition are available.
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
* Clarify the text-normalization conformance surface: explicit
  `normalize_nfd/nfc/nfkd/nfkc` and `is_normalized_*` APIs already have
  curated always-on tests, shared cleanup remains separate from canonical
  normalization, and any future `NormalizationTest.txt` runner must remain
  manual-only, user-provided, and outside the default validation gate.

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
