# doc_parse Foundation Contract

This document defines what the repository expects from publishable-quality
`doc_parse/*` packages.

Current audit scope for this contract:

* `doc_parse/ooxml`
* `doc_parse/pdf`
* `doc_parse/epub`

Explicitly out of scope for this round:

* `doc_parse/zip`

`doc_parse/zip` remains the shared container primitive for OOXML and EPUB, but
it is intentionally excluded from this hardening pass so the work can stay
focused on reusable document-parsing substrates rather than on a full
container-stack rewrite.

## Purpose

`doc_parse/*` packages are MoonBit parsing substrates.

They exist to:

* parse source container or document primitives
* expose structured lower-layer models
* preserve provenance and source references where available
* expose inspect/debug-friendly summaries
* fail closed on malformed or unsupported input
* provide stable, reusable public APIs for MoonBit consumers

They do not exist to be thin aliases over `convert/*`.

Converters are important consumers, but they are not the design center of the
lower-layer packages.

## Responsibilities

`doc_parse/*` packages are responsible for:

* opening and validating source containers/documents
* exposing package/document/page/part/spine/object inventories
* exposing source-native relationships, refs, and lower-layer metadata
* exposing raw or conservative structural signal for higher consumers
* surfacing structured errors instead of silently corrupting output
* exposing inspect/debug summaries that do not depend on Markdown conversion

## Non-goals

`doc_parse/*` packages do not own:

* Markdown rendering
* unified IR shaping
* metadata sidecar policy
* final heading/list/table/caption semantics
* PDF heading/noise/merge/table/caption final policy
* DOCX/PPTX/XLSX final semantic conversion behavior
* EPUB final Markdown aggregation policy beyond lower-layer package/spine/nav
  signal
* OCR
* browser/Word/PowerPoint/PDF/reading-system layout-engine behavior

## Maturity Standard

### API

Commercial-grade `doc_parse` packages should keep:

* clear public entrypoints such as `open_*`, `read_*`, `list_*`, `inspect_*`
* public package-facing types with stable responsibilities
* internal helpers private unless there is a real cross-package consumer
* additive evolution preferred over churn or converter-specific hacks
* naming that reflects package/document primitives rather than converter output

### Error Model

Commercial-grade `doc_parse` packages should:

* distinguish malformed input from unsupported features where practical
* fail closed on unsafe paths, malformed XML, broken containers, and invalid
  references
* avoid panic or silent truncation on bad input
* make errors specific enough for audit/debug use

### Model Completeness

Commercial-grade `doc_parse` packages should preserve enough signal for higher
consumers, such as:

* relationship ids and target mode for OOXML
* part/path/media/docProps inventory for OOXML
* page geometry, text/image/annotation/source refs for PDF
* rootfile/manifest/spine/nav/cover metadata for EPUB
* archive/package/path provenance where lower layers can expose it safely

The lower layer should preserve raw signal and conservative structure, not
final semantic interpretation.

### Safety

Commercial-grade `doc_parse` packages should:

* reject unsafe path traversal where relevant
* avoid external fetch
* avoid entity expansion or equivalent unsafe XML behavior
* keep malformed structures bounded and fail closed
* treat encryption/DRM/unsupported feature markers explicitly where detectable

### Tests

Commercial-grade `doc_parse` packages should have lower-layer tests that cover:

* positive fixtures
* malformed fixtures
* boundary fixtures
* provenance/source-ref checks
* regression checks for known lower-layer bugs
* debug/inspect smoke checks

These tests should not rely only on final Markdown output.

### Docs

Each `doc_parse` package should have a README that covers:

* purpose
* public API
* supported lower-layer features
* safety boundaries
* known limits
* relationship to `convert/*`
* testing guidance

### Performance

Commercial-grade `doc_parse` packages should:

* avoid unnecessary copies where easy to do so
* prefer bounded scans and deterministic traversal
* avoid obvious quadratic common-path behavior
* keep enough smoke-fixture coverage that regressions are visible

## Current Package Position

### `doc_parse/ooxml`

Current role:

* shared OOXML package/part/relationship/media/docProps substrate for
  `convert/docx`, `convert/pptx`, and `convert/xlsx`

Current foundation direction:

* strongest candidate for the first publishable-quality hardening pass
* now a near-publishable foundation candidate within current repository scope
* should evolve toward a reusable OOXML package parser, not a document-format
  semantic converter
* should expose structured inventory/inspect and classifier-friendly errors,
  while keeping converter-facing compatibility stable during hardening
* now keeps default package opening compatibility-oriented, with explicit strict
  validation reserved for publishable-package hygiene checks

Remaining closure items:

* evaluate whether any currently public helper-shaped surface should be hidden in
  a future versioned package release, without breaking current converter users
* decide whether duplicate relationship-id compatibility should stay as-is or
  whether future release policy should tighten only the strict-validation story,
  not the default open path
* clarify whether lightweight XML text decoding should remain package-local or
  later gain an explicit "XML/text part reader" naming split in a release pass

### `doc_parse/pdf`

Current role:

* native text-PDF extraction/model substrate with raw, text, model, and API
  layers

Current foundation direction:

* active foundation hardening pass 2: keep parser/model/debug boundaries strong
  while extending structured inspect/report, document/page inventory, and
  classifier surfaces
* do not collapse `convert/pdf` semantic policy into the lower layer
* prioritize auditability, debug signal, and structured failure over broad
  semantic ambition

Current maturity:

* package-facing structured inspect/report contract exists alongside the legacy
  debug dump surface
* `PdfError` now has a classifier-friendly structured companion for audit use
* document/page inspect reports now expose additive inventory counts for text,
  image, annotation, link-like annotation, source-ref, and page-quality signal
* classifier output now distinguishes direct top-level variant mapping from
  best-effort message-based detail mapping
* default parse/model behavior remains compatibility-oriented and unchanged
* the remaining closure work is to keep refining the lower-layer contract
  without absorbing convert/pdf semantic policy

Remaining PDF closure items after Pass 2:

* deeper raw/model source mapping for unsupported features and malformed content
  paths, so fewer `PdfErrorKind` values rely on best-effort message inference
* stronger package/document-level unsupported-feature taxonomy
* clearer partial-page failure signal if the raw/model pipeline later exposes
  page-local failure markers without changing converter semantics
* candidate-closure work on publishable-surface boundaries once the lower-level
  signal taxonomy is less message-driven

### `doc_parse/epub`

Current role:

* EPUB package/container/OPF/spine/nav lower-layer parser

Current foundation direction:

* now a publishable foundation candidate within current repository scope
* exposes a package-facing facade for rootfiles, manifest, spine, nav/NCX,
  cover candidates, and structured inventory/inspect reporting
* keeps default package opening compatibility-oriented while exposing explicit
  validation for package hygiene findings
* keeps reading-system rendering, CSS/JS, remote fetch, and final Markdown
  aggregation out of the lower layer

Current maturity after closure:

* package open/read/list APIs are in place
* rootfile/manifest/spine/nav/cover package signal is exposed as reusable
  lower-layer data
* structured inventory and inspect reports are available for tooling/debug use
* classifier-style error reporting is available without breaking the existing
  top-level `EpubError` surface
* explicit validation reporting exists for non-fatal package hygiene issues
* rootfile-selection, missing-navigation, duplicate-spine-idref, and
  unsupported-spine policy are now documented and covered by direct lower-layer
  tests

Remaining closure items:

* decide whether any currently public `EpubPackage` fields should remain long
  term public or be treated as compatibility-only surface
* decide whether additional validation modes or severity classes are needed in
  a future release-policy pass; current package scope does not require them
* continue expanding direct lower-layer malformed/edge-case tests without
  changing `convert/epub` semantics

## Current Round Strategy

This round intentionally focuses on:

1. audit and boundary clarity
2. README/API/doc improvements
3. lower-layer test guardrails
4. one low-risk concrete hardening slice

Preferred implementation priority:

1. `doc_parse/ooxml`
2. `doc_parse/epub`
3. `doc_parse/pdf`

The first substantial hardening slice should land in `doc_parse/ooxml`, because
it already sits under three sealed format families and has the clearest path to
reusable package-parser quality without changing converter semantics.
