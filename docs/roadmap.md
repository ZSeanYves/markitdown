# Roadmap

This page is the current roadmap source of truth for the repository.

## Current Status

* `doc_parse` foundation in-tree complete
* container/package foundations:
  `zip / ooxml / epub / pdf`
* simple/markup/scanner foundations:
  `csv / tsv / json / yaml / text / xml / html / markdown`
* OOXML semantic sublayers:
  `xlsx / docx / pptx`
* performance:
  library and same-process product first-pass corpus have no obvious `>10ms`
  rows, and cold-start attribution now shows main-internal CLI work is
  sub-millisecond while process/runtime cost dominates the remaining
  process-per-file path
* benchmark:
  unified entrypoint through `./samples/bench.sh`, including the focused
  cold-start CLI suite with external vs main-internal startup attribution
* external/private quality gate:
  `samples/quality_corpus/` is now operational as a local signal-level intake
  path, with real external rows already used to validate fixes for PDF word
  boundaries, PDF non-link annotation appendix lowering, ZIP Level 1 data
  descriptors, YAML single-document markers, PPTX cached chart data, PPTX
  comments, HTML content-root selection, XLSX worksheet comments, DOCX
  note/comment hyperlink-anchor preservation, and PPTX chart-title/date-category
  lowering

## Near-term Release Work

### 1. API stability review

* stable candidate APIs
* benchmark/profile helpers are not stable product APIs
* compatibility surfaces
* package README final check

### 2. `doc_parse` independent module extraction readiness audit

* import graph
* `moon.mod.json` strategy
* package boundaries
* version / changelog / release policy
* `markitdown` integration plan

### 3. Documentation release polish

* `README`
* package README
* examples
* support/limits
* performance caveats

### 4. Performance follow-ups

* PDF direct library attribution
* batch / embedded / warm-runner startup amortization guidance
* release packaging or runtime-level cold-start follow-up if process-per-file
  usage remains a priority
* heavier rich-format corpora
* optional regression guard
* no longer prioritize source-level cold CLI micro-optimization for the
  current checked `noop`/`--help`/minimal-TXT path

### 5. PDF layout classifier follow-up

* keep the current `samples/pdf_layout_classifier` work scoped as a training
  spike
* evolve that spike toward the audited lightweight layout-assist plan in
  `docs/pdf-layout-model.md`, starting with report-only feature/schema/
  disagreement reporting rather than normal-path control
* expand local labels only if the text-layer classifier shows useful signal
* keep plugin/backend/OCR/visual-model integration optional and outside the
  default fast main path

### 6. External/private quality intake

* keep `samples/quality_corpus/` as an external/public-dataset/private-local
  intake framework rather than repopulating it with repository regression
  samples
* keep the checked public manifest intentionally empty until rows are manually
  curated
* treat private local real documents as the first-class intake path
* treat `external_sources.tsv` as a source catalog rather than an integrated
  corpus
* keep `external_manifest.local.tsv` local-only and license-gated
* prioritize MarkItDown/Pandoc fixture intake before large layout datasets
* require license review before vendoring any external dataset or tool fixture
* legacy synthetic `samples/real_world` has been removed and is no longer
  current release quality evidence
* continue turning real external `known_bad` rows into passing `reference`
  rows only when the converter behavior is actually verified locally

### 7. External hardening follow-ups

* find more PDF table/layout samples with small, stable external signals
* add more CJK / `/ToUnicode` positive PDF samples so the native text matrix is
  not anchored on only one non-ASCII positive path
* find a small `Type0 + predefined CMap + no /ToUnicode` PDF sample before
  considering a predefined-CMap implementation pass
* keep scan-only/image-only PDF rows on report-only detection first by
  reusing existing inspect/debug signal rather than turning the native suite
  into an OCR expectation
* add more XLSX external rows around hyperlink/comment appendix stability,
  formula cache, and merged-cell boundaries
* add heavier PDF/PPTX external rows around PDF link annotations,
  multi-column reading order, PPTX grouped-shape layout, and richer
  speaker-notes/comment combinations
* keep expanding EPUB external rows around OPF/package robustness, especially
  commented-out manifest markup and remote/scheme sidecar resources that
  should not abort local spine conversion
* add more XML external rows around non-UTF-8 declaration handling and keep
  broad legacy-charset guessing out of scope unless real samples justify it
* keep true multi-document YAML support as optional future work rather than
  a release blocker
* keep scan-only PDF rows as boundary evidence rather than claiming OCR-first
  default support

### 8. Report-only diagnostics and explicit provider routes

* keep PDF scan/image-only detection report-first by reusing current
  inspect/debug signal rather than changing Markdown output
* make the local quality corpus more dashboard-like with by-format/source/tier
  rollups and retained-boundary lists
* refine explicit OCR around provider contracts and lazy availability probing
* keep OCR provider rollout on lightweight skeletons first: descriptors, lazy
  probe APIs, and report wiring before any real engine integration
* keep the first real provider narrow: explicit `tesseract-cli` page-image OCR
  before any broader PDF-wrapper or model-backed OCR route
* keep OCR image-suite validation focused on explicit CLI/provider boundaries
  first, with optional local `tesseract-cli` smoke outside the default sample
  gate and without turning the suite into an OCR-quality claim
* keep direct PDF OCR in the explicit-provider/future-PDF-wrapper lane rather
  than forcing `tesseract-cli` image assumptions onto the normal converter
* treat OCRmyPDF as an audited future explicit PDF OCR provider only after
  sidecar/provenance semantics, temp-file cleanup, exit-code mapping, and
  explicit provider metadata are settled
* keep any future OCRmyPDF route external and user-installed rather than
  bundled, and avoid probing it from `normal` or from default CLI startup
* treat PaddleOCR / PP-Structure as a separate heavy-provider lane: useful for
  future explicit OCR/layout/table analysis, but only after runtime/model,
  licensing, provenance, and reproducibility boundaries are documented
* keep any future PaddleOCR route off the normal path and off the default
  sample/test gate, starting instead from explicit commands or debug/eval
  reporting
* keep layout assistance advisory/report-only first; only consider guarded
  normal-path use after benchmark and corpus evidence
* keep layout-assist rollout on report-only skeletons before any model-backed
  or normal-path experiment
* prefer surfacing advisory layout-assist predictions in debug/inspect before
  any normal-path integration attempt
* use debug-only layout-assist evaluation to measure coverage, label
  distribution, and suspicious no-prediction / many-prediction cases before
  discussing any stronger integration
* require explicit dataset/license review and held-out ablation before
  widening the layout-assist label set or gating any output changes
* keep collecting more unique-source real labels for `link_text`, `caption`,
  and short-title `heading` boundaries before proposing any later
  gated-normal PDF layout-assist trial; the latest held-out expansion finally
  raised `link_text` / `caption` support to `9` / `8`, but long annotated
  anchors are still not robust enough
* keep the current best report-only arbiter pinned to
  `gated_conservative_v1`, which now uses the `220 / 180` local split plus
  later heading/list precision guards, corrected standalone-bullet negatives,
  and CJK/help-text/annotation-negative features, still beats rules-only on
  the expanded held-out split, and still avoids held-out regressions
* keep the newer cheap deterministic link/caption feature pass in the
  report-only lane as well: a later residual feature pass on the same harder
  `223 / 195` split now reaches `0.9744` for `gated_conservative_v1` vs
  `0.9538` for `rules_only`, and the remaining blockers have shifted again to
  `Summary` plus a few `paragraph` vs `keep_as_text` boundary rows rather
  than missing `link_text` / `caption` support alone
* keep the newer paragraph-boundary feature pass in the report-only lane too:
  the same harder `223 / 195` split now reaches `0.9846` for
  `gated_conservative_v1` vs `0.9641` for `rules_only`, still keeps held-out
  regressions at `0`, and now shows that the blocker has shifted away from
  `link_text` / `caption` support to a much smaller set of `Summary`,
  visible-URL, and receipt/body boundary residuals

## Later Work

* optional split into standalone `ZSeanYves/doc_parse`
* remote dependency integration back into `markitdown`
* richer PDF fallback/OCR line
* refine the explicit `ocr` CLI path so OCR-enabled runs can report
  `ocr_used=true` and OCR-source metadata without changing the default native
  path contract
* optional simple-font GB18030 fallback for raw-GBK no-`/ToUnicode` PDFs if
  it is isolated to a well-evidenced boundary such as `SimFang-variant.pdf`
  or `XiaoBiaoSong.pdf`
* optional embedded-font `cmap` fallback only when a future sample shows:
  `FontFile2`, a usable `cmap`, and `CIDToGIDMap` identity or another safely
  resolvable mapping
* keep vendoring full Adobe predefined-CMap resources de-prioritized until a
  small external sample set clearly pressures that path
* keep broad mojibake heuristics de-prioritized in favor of evidence-driven,
  format/font-specific fallback work
* prefer plugin/external OCR provider interfaces over bundling OCR runtimes
  into the default fast native package
* keep layout-assist providers advisory by default; do not let model-backed
  assistance silently replace the rule-driven main chain
* deeper DOCX/PPTX normal-path integration if justified
* manually curated external/private quality corpus growth
* fuzz / malformed corpus
* more ecosystem adapters

## Non-goals For Current Release

* full Office engine
* full PDF engine
* scanned/OCR PDF default support
* full browser HTML engine
* full CommonMark renderer
* full ICU/UAX #15 canonical normalization
  * explicit facade APIs and curated tests exist, but full
    `NormalizationTest.txt` conformance should remain manual/opt-in unless a
    user-provided runner proves stable and governance is settled
* replacing Pandoc/Tika
* claiming cross-machine absolute benchmark guarantees

## Historical Records

Historical planning, audit, and milestone notes remain available at their
existing paths as archived stubs, with full historical bodies preserved under
`docs/archive/`:

* [Archived roadmap docs](./archive/roadmap/)
* [Archived benchmark docs](./archive/benchmark/)
* [Archived normalization docs](./archive/normalization/)
