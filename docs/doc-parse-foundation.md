# doc_parse Foundation Contract

This document defines what the repository expects from publishable-quality
`doc_parse/*` packages.

Current audit scope for this contract:

* `doc_parse/ooxml`
* `doc_parse/pdf`
* `doc_parse/epub`
* `doc_parse/zip`

## Current Status

Current candidate line:

* `doc_parse/ooxml`: publishable foundation candidate
* `doc_parse/epub`: publishable foundation candidate
* `doc_parse/pdf`: text-PDF publishable foundation candidate
* `doc_parse/zip`: external-decoder-backed publishable foundation candidate as
  the shared container primitive

Current packaging strategy:

* these foundations are delivered today as importable subpackages under
  `ZSeanYves/markitdown`
* they are not yet split into independent MoonBit modules
* `convert/*` consumes them, but they are documented as reusable parsing
  foundations rather than as converter-only helpers

See also [docs/package-publishing-strategy.md](./package-publishing-strategy.md).

## Unified Contract

Across the current candidate line:

* `doc_parse/*` owns parsing, lower-layer models, inspect/debug signal, and
  provenance where available
* `convert/*` owns Markdown/IR semantic conversion and final output policy
* no remote fetch is part of the lower-layer foundation contract
* lower layers should fail closed where safety matters
* shared container layers such as `doc_parse/zip` may keep compatibility-
  oriented open/read behavior while surfacing stricter validation and inspect
  reports explicitly
* explicit validation or inspect issues do not automatically become default
  hard failures in normal conversion paths
* compatibility-oriented default open/read behavior may coexist with explicit
  strict validation or inspect reporting
* none of the current candidates claim full spec support

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

* now a publishable foundation candidate within current repository scope
* should evolve toward a reusable OOXML package parser, not a document-format
  semantic converter
* should expose structured inventory/inspect and classifier-friendly errors,
  while keeping converter-facing compatibility stable during hardening
* now keeps default package opening compatibility-oriented, with explicit strict
  validation reserved for publishable-package hygiene checks

Current maturity:

* stable candidate package-facing API is centered on open/read/list/query
  facade functions
* structured inventory and inspect reports exist for parts, relationships,
  content types, media assets, and docProps
* classifier-friendly error metadata exists without breaking the top-level
  `OoxmlError` surface
* explicit strict validation exists for package hygiene findings while default
  open remains compatibility-oriented
* compatibility surfaces remain documented for `OoxmlPackage` fields that
  in-repo consumers still touch directly

Known limits:

* not a DOCX/PPTX/XLSX semantic converter
* no external relationship fetch
* no macro/VBA semantic support
* no full OOXML spec coverage claim

Remaining closure items:

* evaluate whether any currently public helper-shaped surface should be hidden in
  a future versioned package release, without breaking current converter users
* decide whether duplicate relationship-id compatibility should stay as-is or
  whether future release policy should tighten only the strict-validation story,
  not the default open path
* clarify whether lightweight XML text decoding should remain package-local or
  later gain an explicit "XML/text part reader" naming split in a release pass

### `doc_parse/zip`

Current role:

* shared ZIP archive/container primitive for `doc_parse/ooxml`,
  `doc_parse/epub`, and `convert/zip`

Current foundation direction:

* now an external-decoder-backed publishable foundation candidate within
  current repository scope
* should expose a reusable archive open/read/list facade plus structured
  inventory, path-safety helpers, validation issues, and classifier-friendly
  errors
* should keep archive/container responsibilities separate from OOXML/EPUB
  package semantics and from ZIP-converter dispatch policy
* currently uses an external-backed compression-decode dependency while keeping
  the `doc_parse/zip` facade as the stable project boundary

Current maturity:

* stable candidate facade is centered on `open_zip`, `list_entries`,
  `has_entry`, `read_entry`, `normalize_entry_path`, and structured
  inventory/inspect/validation helpers
* structured entry inventory and archive inspect reports now exist for entry
  counts, directory/file shape, normalized-path safety, duplicate normalized
  paths, unsupported compression markers, and deterministic ordering
* classifier-friendly error metadata now exists without breaking the top-level
  `ZipError` surface
* explicit validation reports now surface unsafe paths, duplicate normalized
  paths, directory entries, empty entries, unsupported compression, and nested-
  archive candidates

Known limits:

* not a Markdown converter
* not an OOXML or EPUB semantic layer
* no password or encrypted-ZIP recovery
* no multi-disk or ZIP64 support
* no full compression-method matrix
* no full ZIP-spec coverage claim
* no recursive archive conversion policy

Remaining closure items:

* decide whether the bytes-level entry-read contract should later gain a stable
  text-decoding helper or stay explicitly bytes-only
* continue narrowing which currently public raw archive fields are true long-
  term compatibility surface versus future encapsulation candidates
* clarify whether unsupported-feature classification should remain partly
  message-based until deeper backend/source mapping exists
* decide whether future release policy should tighten the legacy
  `inspect_zip(bytes)` compatibility helper or keep it as a permanent
  convenience surface

### `doc_parse/pdf`

Current role:

* native text-PDF extraction/model substrate with raw, text, model, and API
  layers

Current foundation direction:

* now a publishable foundation candidate within current repository scope for
  native text-PDF lower-layer use
* keep parser/model/debug boundaries strong while extending structured
  inspect/report, document/page inventory, and typed issue/classifier surfaces
* do not collapse `convert/pdf` semantic policy into the lower layer
* prioritize auditability, debug signal, and structured failure over broad
  semantic ambition

Current maturity:

* stable candidate facade now centers on `doc_parse/pdf/api`
* structured inspect/report and debug convenience surfaces are both available,
  with the structured report as the preferred machine-readable contract
* package-facing structured inspect/report contract exists alongside the legacy
  debug dump surface
* `PdfError` now has a classifier-friendly structured companion for audit use
* document/page inspect reports now expose additive inventory counts for text,
  image, annotation, link-like annotation, source-ref, and page-quality signal
* classifier output now distinguishes direct top-level variant mapping, typed
  inspect-issue mapping, and best-effort message-based detail mapping
* raw/model issue plumbing now exists as an inspect/report-only starter:
  encrypted-document markers, malformed-annotation warnings, missing-image-
  payload warnings, and model-derived empty/low-signal/partial-page findings
  are exposed as typed audit signal without changing converter semantics
* default parse/model behavior remains compatibility-oriented and unchanged
* clear compatibility surfaces remain documented for `PdfDocumentModel`, raw
  extract structs, and debug-oriented lower-layer access without tightening
  current repository consumers
* the remaining work is to keep refining the lower-layer contract without
  absorbing convert/pdf semantic policy

Known limits:

* text-PDF lower-layer candidate only
* no scanned-PDF default support
* no OCR default fallback
* no full visual layout engine
* no tagged-PDF semantic extraction claim
* no full PDF spec support claim

Remaining PDF closure items after candidate closure:

* deeper raw/model source mapping for unsupported features and malformed content
  paths, so fewer `PdfErrorKind` values rely on best-effort message inference
* real raw detection for object streams, unsupported filters, malformed content
  streams, missing font encodings, and bad ToUnicode paths instead of
  classifier-only best-effort mapping
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

Known limits:

* not a reading-system renderer
* no DRM/encryption support claim
* no CSS/JS rendering
* no remote fetch
* no full EPUB spec or full XHTML semantic conversion claim

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
