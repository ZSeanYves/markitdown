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
* post-pruning PDF support subtree:
  `doc_parse/pdf/vendor/mbtpdf` is now maintained as a trimmed local support
  subtree rather than a full upstream mirror; stale residue, command/example
  packages, unused side packages, the old text facade, and the remaining e2e
  surface have been pruned while runtime-critical support and attribution
  remain
* product closure:
  `cli mbtpdf count = 0`, `zip mbtpdf count = 0`, and
  `pdf mbtpdf count = 23339`; recent CSV `cp932/mskanji` fallback hardening
  stays out of the lightweight `cli` / delegated `zip` closure
* quality-lab-backed quality gate:
  `samples/quality_corpus/` is now operational as a signal-level gate over the
  checked-in public baseline plus lab-managed external/full local rows, with
  real external rows already used to validate fixes for PDF word
  boundaries, PDF non-link annotation appendix lowering, ZIP Level 1 data
  descriptors, YAML single-document markers, PPTX cached chart data, PPTX
  comments, HTML content-root selection, XLSX worksheet comments, DOCX
  note/comment hyperlink-anchor preservation, and PPTX chart-title/date-category
  lowering
* checked local cross-format quality baseline:
  `330` rows / `1` skipped / `0 expected_fail`, with focused rows at
  `PDF 101`, public-only checked-in `PDF 24`, `DOCX 60`, `PPTX 55`,
  `XLSX 51`, `EPUB 16`, `ZIP 15`, `XML 9`, `CSV 15`, and `HTML 5`
* current quality evidence remains external-fixture-driven and local:
  `markitdown-quality-lab/` is not a release artifact,
  `0 expected_fail` is not a universal-support claim, and OCR/scanned behavior
  remains explicit-only

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
* lightweight release-note summaries for major pruning / quality / closure
  phases
* release checklist hygiene so docs-only snapshots stay consistent with the
  checked local validation chain

### 4. Performance follow-ups

* PDF direct library attribution
* batch / embedded / warm-runner startup amortization guidance
* release packaging or runtime-level cold-start follow-up if process-per-file
  usage remains a priority
* heavier rich-format corpora
* optional regression guard
* no longer prioritize source-level cold CLI micro-optimization for the
  current checked `noop`/`--help`/minimal-TXT path

### 5. PDF layout/model follow-up

* keep the current quality-lab `pdf_layout_classifier` work scoped as a
  training spike
* keep the broader offline/training/eval loop in `docs/pdf-layout-model.md`,
  while treating the new tiny gated-normal v1 as a separate distilled
  implementation rather than “the model now runs in normal”
* the first normal-path gate is now intentionally tiny:
  weak heading demotion plus separator/list suppression only, with hard
  constraints, debug reasons, and a disable switch
* widen the gated-normal path only after a fresh residual audit shows a clear
  low-risk win
* keep table/layout/heading/list work split into explicit risk buckets rather
  than broad “layout quality” language
* keep benchmark/build guardrails and disable-switch behavior in scope for any
  future widening
* expand local labels only if the text-layer classifier shows useful signal
* keep plugin/backend/OCR/visual-model integration optional and outside the
  default fast main path

### 6. Quality-lab quality intake

* keep `samples/quality_corpus/` as the runner for a repo-owned public baseline
  plus quality-lab-managed external/full local rows rather than repopulating
  it with repository regression samples
* keep the checked public manifest small and manually curated around stable
  repo-tracked rows; the current checked-in public baseline is PDF-focused and
  should only grow when a new row adds clear signal
* treat `markitdown-quality-lab/quality_rows/source_catalog.tsv` as the
  external source catalog
* treat `markitdown-quality-lab/quality_rows/manifest.tsv` as the tracked full
  external/local quality-row manifest
* keep any legacy `external_manifest.local.tsv` fallback local-only and
  migration-window only
* prioritize MarkItDown/Pandoc fixture intake before large layout datasets
* require license review before vendoring any external dataset or tool fixture
* legacy synthetic `samples/real_world` has been removed and is no longer
  current release quality evidence
* continue turning real external `known_bad` rows into passing `reference`
  rows only when the converter behavior is actually verified locally

Legacy-fallback exit criteria:

* remove `external_manifest.local.tsv`, sibling quality-lab lookup, and
  `.external/...` path fallbacks only after:
  * repo-root quality-lab full quality keeps passing `330 / 1 / 0`
  * public-only keeps passing `24 / 0 / 0`
  * `moon test` plus `./samples/check.sh` pass in the same cycle
  * no non-doc runtime/product reference depends on `.external/...`
  * no active maintainer workflow still depends on local
    `external_manifest.local.tsv`
  * quality-lab keeps tracked `quality_rows/manifest.tsv` and `corpus/MANIFEST.tsv`
  * at least one full post-migration cycle has completed

Legacy-fallback removal phases:

* Phase 1: stop recommending legacy paths in docs and helper examples; keep
  only lifecycle notes plus explicit migration-window wording
* Phase 2: remove optional sibling `../markitdown-quality-lab` lookup from
  runner/helper/debug code after repo-root `markitdown-quality-lab/` has stayed
  stable for at least one full cycle
* Phase 3: remove `samples/quality_corpus/external_manifest.local.tsv` as a
  runner fallback once no active maintainer workflow still depends on the local
  private/external split and `--lab-manifest` / tracked lab rows cover the same
  workflow
* Phase 4: remove legacy `.external/quality_corpus/...` row-path resolution
  from runner/helper code once full quality has been exercised from
  `markitdown-quality-lab/corpus` for at least one full cycle without fallback
* Phase 5: remove legacy `.external/layout_model/...` mapping from
  debug/layout-assist eval once repo-root quality-lab layout scripts and the
  repo-tracked `doc_parse/pdf/layout_model_tool` entrypoint have remained
  stable for at least one full cycle
* Phase 6: already satisfied once docs, scripts, and maintainer workflow no
  longer reference a local `pdf_layout_classifier` sample directory directly

### 7. Format follow-up after the baseline snapshot

* Office next-pass work should stay evidence-led:
  prioritize real failures around XLSX formulas / hidden sheets / hyperlinks,
  PPTX media / charts / comments, and DOCX links / text boxes / notes / images
  before adding broader corpus breadth
* PDF next-pass work should stay narrow:
  continue table/layout/heading/list residual audits before any normal-path
  widening, keep scan-only rows as explicit boundary evidence, and do not
  widen claims around OCR or broad CJK fallback without new sample-backed wins
* Horizontal follow-up should be tail-only:
  revisit EPUB/ZIP/XML/CSV mainly when a real failure or clear signal gap
  appears, rather than treating them as open-ended corpus-expansion lanes
* keep true multi-document YAML support as optional future work rather than a
  release blocker

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
* keep provider-backed layout assistance advisory/report-only first; only
  consider broader normal-path use after benchmark and corpus evidence
* keep wider layout-assist rollout on report-only skeletons before any
  broader model-backed normal-path experiment
* prefer surfacing advisory layout-assist predictions in debug/inspect before
  widening the current tiny weak-heading/list normal-path gate
* use debug-only layout-assist evaluation to measure coverage, label
  distribution, and suspicious no-prediction / many-prediction cases before
  discussing any stronger integration
* require explicit dataset/license review and held-out ablation before
  widening the layout-assist label set or gating any output changes
* keep collecting more unique-source real labels for `link_text`, `caption`,
  and short-title `heading` boundaries before proposing any later widening of
  the normal-path gate; the latest held-out expansion finally raised
  `link_text` / `caption` support to `9` / `8`, but long annotated anchors
  are still not robust enough
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
  regressions at `0`, and shows that the broader blocker set has shifted away
  from `link_text` / `caption` support to a much smaller set of `Summary`,
  visible-URL, and receipt/body boundary residuals
* keep the first checked gated-normal v1 frozen at weak heading demotion plus
  separator/list suppression only until those remaining residuals and wider
  benchmark/build questions are re-audited
* if the local quality manifest keeps reporting `unexpected_pass` rows, prefer
  curating the manifest semantics explicitly rather than collapsing that state
  into a vague product-quality percentage claim
* add more pinned mainstream compare runs before making any broader README
  quality-percentage or speed-multiple claims

### 9. Release pipeline follow-up

* automate release-note summary assembly from the checked local snapshot rather
  than rewriting the same phase summary by hand
* add a lightweight release checklist pass for docs / quality / contracts /
  smoke-bench consistency
* keep artifact-build scripting explicit and reproducible without turning local
  corpus state or benchmark caches into release artifacts

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
* manually curated quality-lab corpus growth
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
