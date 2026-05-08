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
* should evolve toward a reusable OOXML package parser, not a document-format
  semantic converter

### `doc_parse/pdf`

Current role:

* native text-PDF extraction/model substrate with raw, text, model, and API
  layers

Current foundation direction:

* keep parser/model/debug boundaries strong
* do not collapse `convert/pdf` semantic policy into the lower layer
* prioritize auditability, debug signal, and structured failure over broad
  semantic ambition

### `doc_parse/epub`

Current role:

* EPUB package/container/OPF/spine/nav lower-layer parser

Current foundation direction:

* evolve toward a reusable EPUB package/spine/nav substrate
* keep reading-system rendering, CSS/JS, and final Markdown aggregation out of
  the lower layer

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
