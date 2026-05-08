# Changelog

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
  * advanced helpers and benchmark tools under `./samples/scripts/`
* Validation now prefers a probe-validated native CLI when available and falls
  back to `moon run` only when needed.
* The PDF lower layer now lives under `doc_parse/pdf`, backed by a
  repository-local maintained fork under `vendor/mbtpdf`.
* Benchmark, batch-profiling, and regression-warning tools are available for
  H3 performance work.

### Notes

* H2 complete does not mean every advanced format-specific feature is fully
  implemented.
* Known limitations remain documented in
  `docs/support-and-limits.md`.
