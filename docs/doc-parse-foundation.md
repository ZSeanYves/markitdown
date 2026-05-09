# doc_parse Foundation

This document is the source of truth for the current in-tree `doc_parse/*`
foundation line inside `ZSeanYves/markitdown`.

Current audit scope for this contract:

* `doc_parse/ooxml`
* `doc_parse/pdf`
* `doc_parse/epub`
* `doc_parse/zip`
* `doc_parse/csv`
* `doc_parse/tsv`
* `doc_parse/json`
* `doc_parse/yaml`
* `doc_parse/text`
* `doc_parse/xml`
* `doc_parse/html`
* `doc_parse/markdown`

## Contract

Core ownership split:

* `doc_parse/*` owns parser / model / error / inspect / validation /
  provenance where available / safety boundary
* `convert/*` owns `doc_parse` model -> IR / Markdown / assets / metadata /
  product semantics

Shared contract:

* inspect / validation are explicit surfaces, not default hard failures unless
  safety-critical parser behavior already fails closed
* no remote fetch belongs in the lower-layer package contract
* none of the current packages claim full format-spec support unless a package
  README explicitly says so

## Current Status Matrix

| Package | Status | Stable surface | Scope | Non-goals | Conversion integration status |
| --- | --- | --- | --- | --- | --- |
| `doc_parse/zip` | external-decoder-backed publishable foundation candidate | archive open/read/list, path normalization, inventory, inspect, validation, classifier | ZIP archive/container primitive | full ZIP spec, password recovery, recursive archive policy | consumed by `doc_parse/ooxml`, `doc_parse/epub`, and `convert/zip` |
| `doc_parse/ooxml` | publishable foundation candidate | open/read/list/query/inspect/strict-validation facade | OOXML package / parts / relationships / content types / media / docProps | Office semantic conversion | consumed by `convert/docx`, `convert/pptx`, `convert/xlsx` |
| `doc_parse/epub` | publishable foundation candidate | package/rootfile/manifest/spine/nav/cover/inspect/validation facade | EPUB container / OPF / manifest / spine / nav / NCX / cover / metadata | reading-system rendering, DRM, CSS/JS | consumed by `convert/epub` |
| `doc_parse/pdf` | native text-PDF publishable foundation candidate | `doc_parse/pdf/api` facade, structured inspect/report, typed issue starter | native text-PDF model / page geometry / text / image / annotation raw signal | OCR default, scanned PDF, full layout engine | consumed by `convert/pdf` |
| `doc_parse/csv` | simple-format parser foundation candidate | parse/options/inspect/validation/classifier | comma-delimited table parser/model | Markdown table / `RichTable` policy | consumed by `convert/csv` |
| `doc_parse/tsv` | simple-format parser foundation candidate | TSV facade over CSV core | tab-delimited table parser/model | Markdown table / `RichTable` policy | consumed by `convert/csv` |
| `doc_parse/json` | simple-format parser foundation candidate | parse/AST/inspect/classifier | JSON parser / AST / malformed-input classification | JSON-to-table/list/code-block policy | consumed by `convert/json` |
| `doc_parse/yaml` | YAML-subset parser foundation candidate | parse/AST/inspect/classifier | current YAML subset parser / AST | full YAML spec, YAML-to-Markdown policy | consumed by `convert/yaml` |
| `doc_parse/text` | plain-text parser foundation candidate | bytes-open/string-parse/inspect/classifier | BOM/newline/line/paragraph structural text model | literal Markdown policy / final rendering | consumed by `convert/txt` |
| `doc_parse/xml` | XML parser foundation candidate | tokenize/parse/inspect/validation/classifier facade | safe XML tokenizer / parser / model / inspect / validation | full XML spec, DTD support, namespace semantics, XML-to-Markdown policy | `convert/xml` remains source-preserving and is not yet parser-driven |
| `doc_parse/html` | HTML DOM-ish parser foundation candidate | tokenize/parse/inspect/validation/classifier facade | tolerant DOM-ish HTML tokenizer / parser / raw node model / inspect / safety boundary | browser parser, CSS/JS rendering, final HTML-to-Markdown policy | `convert/html` still owns the current normal parser + conversion line |
| `doc_parse/markdown` | Markdown lightweight scanner foundation candidate | scan/inspect/validation facade | lightweight Markdown source scanner / raw block inventory / frontmatter / fenced code detection | Markdown renderer / output normalization / CommonMark full parser | `convert/markdown` still owns passthrough product policy |
| `docx/pptx/xlsx` semantic sublayers | deferred | n/a | possible future semantic parser split above OOXML package layer | full semantic converter split this round | semantic ownership remains in `convert/docx`, `convert/pptx`, `convert/xlsx` |

## Candidate Definitions

* `publishable foundation candidate`
  package-facing reusable lower-layer with stable candidate API, inspect/error/
  validation surfaces, docs, and lower-layer tests
* `parser foundation candidate`
  reusable parser/model/error/inspect foundation with stable candidate API and
  no IR/Markdown/product semantics
* `subset parser foundation candidate`
  parser foundation candidate whose subset boundary is explicit and
  intentionally documented
* `scanner foundation candidate`
  lightweight source-scanner foundation with stable candidate API and raw
  block inventory / inspect / validation surface, but without renderer or
  output-mutation ownership
* `active hardening`
  package boundary exists and a reusable scanner/model/inspect surface is in
  place, but candidate closure and release-policy narrowing are not complete
* `deferred`
  not yet split into a reusable lower-layer package contract
## Current Packaging Strategy

* these foundations are delivered today as importable subpackages under
  `ZSeanYves/markitdown`
* they are not yet split into independent MoonBit modules
* `convert/*` consumes them, but they are documented as reusable parsing
  foundations rather than as converter-only helpers
* simple-format parser foundations have now been migrated into `doc_parse/*`
  internally and are being stabilized there before any future standalone-module
  split is attempted

See also [docs/package-publishing-strategy.md](./package-publishing-strategy.md).

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

## Package Summaries

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

Future release-policy items:

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

Future release-policy items:

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

### Simple-format parser foundations

Current role:

* simple-format parser foundations now living in `doc_parse/*` and consumed by
  `convert/*`

Current packages:

* `doc_parse/csv`: comma-delimited table parser/model/inspect/validation
* `doc_parse/tsv`: tab-delimited facade over the CSV parser core
* `doc_parse/json`: JSON parser/AST/inspect
* `doc_parse/yaml`: current YAML-subset parser/AST/inspect
* `doc_parse/text`: plain-text structure/paragraph/inspect model
* `doc_parse/xml`: XML tokenizer/parser/model/inspect/safety boundary starter

Current boundary:

* these packages own parser/model/error/inspect logic
* package-local README files now document public API, current boundaries, known
  limits, and relationship to `convert/*`
* `convert/csv`, `convert/json`, `convert/yaml`, and `convert/txt` still own
  IR shaping, Markdown output policy, metadata wiring, and product-facing
  origin semantics
* `convert/xml` still owns source-preserving fenced-XML product semantics even
  though `doc_parse/xml` now provides the tokenizer/parser/model foundation
* `doc_parse/html` now provides a tolerant DOM-ish parser/model/inspect/
  validation candidate surface, but `convert/html` still owns the current HTML
  parser + IR/Markdown/product policy path
* `doc_parse/markdown` now provides a lightweight source scanner/model/inspect
  candidate surface, but `convert/markdown` still owns passthrough product policy

Current maturity:

* `doc_parse/csv`: simple-format parser foundation candidate with parse
  options, inspect, validation, and classifier-friendly error metadata
* `doc_parse/tsv`: simple-format parser foundation candidate as a thin
  tab-delimited facade over the CSV parser core
* `doc_parse/json`: simple-format parser foundation candidate with JSON
  normalization, AST, inspect, and malformed-input classification
* `doc_parse/yaml`: YAML-subset parser foundation candidate with explicit
  unsupported-feature boundaries and inspect reporting
* `doc_parse/text`: plain-text parser foundation candidate with byte-open,
  newline-style detection, paragraph structure, and inspect reporting
* `doc_parse/xml`: XML parser foundation candidate with safe tokenizer /
  parser / inspect / validation boundaries and explicit no-XXE / no-DTD-
  expansion behavior
* `doc_parse/html`: HTML DOM-ish parser foundation candidate with tokenizer /
  tolerant parser / raw node model / inspect / validation / no-fetch safety
  boundary
* `doc_parse/markdown`: Markdown lightweight scanner foundation candidate with
  raw block inventory, frontmatter and fenced-code detection, inspect /
  validation, and a no-renderer boundary

Known limits:

* JSON/YAML/CSV/TXT decoding compatibility and file-I/O seams may still be
  partially staged in `convert/*` while parser/model ownership is moved inward
* these candidate labels are lower-layer parser-foundation labels only; they
  are not claims of full format-family spec coverage or final product
  conversion ownership

### `doc_parse/html`

Current role:

* tolerant DOM-ish HTML tokenizer/parser/model/inspect/validation candidate
* explicit lower-layer safety boundary for no remote fetch, no script
  execution, and no CSS/JS rendering

Current surface:

* `tokenize_html_document`
* `parse_html_document`
* `inspect_html_document`
* `collect_html_validation_issues`
* `validate_html_document`
* `classify_html_error`

Current maturity:

* stable candidate API now covers tokenize/parse/inspect/validation/classifier
  access
* compatibility surface is centered on the raw DOM-ish model, inspect report,
  validation report, and classifier-friendly error metadata
* tolerant repair policy is explicit and test-locked:
  * multiple top-level nodes are allowed
  * documented void elements behave as self-closing in the raw model
  * explicit self-closing syntax is preserved
  * unexpected closing tags and unclosed elements are surfaced as validation
    issues rather than browser-style full tree correction
* raw script/style content is preserved as text and never executed or rendered
* URL safety remains a validation/report surface only; parsing does not fetch,
  rewrite, or block these nodes by default

Current boundary:

* `doc_parse/html` owns raw token/node inventory, validation issues, and
  inspect reporting
* `convert/html` still owns normal HTML -> IR / Markdown / assets / metadata /
  source-preserving product policy

Known limits:

* not a browser parser or HTML5 spec-complete tree-construction engine
* no remote fetch
* no script execution
* no CSS/layout rendering
* partial HTML entity decoding only; unsupported named entities stay literal
* no DOM mutation API, accessibility tree, or browser-correction semantics
* no final Markdown/link/image/caption policy ownership

### `doc_parse/markdown`

Current role:

* lightweight Markdown source scanner / raw block inventory / inspect /
  validation foundation line
* explicit lower-layer safety boundary for no renderer and no output mutation

Current surface:

* `scan_markdown_document`
* `inspect_markdown_document`
* `collect_markdown_validation_issues`
* `validate_markdown_document`

Current maturity:

* Markdown lightweight scanner foundation candidate
* scanner always succeeds and surfaces structural problems as validation
  issues instead of hard parse errors
* current scan is intentionally line-oriented and conservative

Current boundary:

* `doc_parse/markdown` owns raw source scanning, raw block inventory, and
  inspect/validation reporting
* `convert/markdown` still owns passthrough output and product normalization
  policy

Known limits:

* no CommonMark parser or renderer
* no Markdown -> IR conversion
* no output mutation or normalization policy
* inline emphasis/link parsing is not performed
* HTML-in-Markdown remains a raw candidate signal only

Future release-policy items:

* decide whether any current model fields should remain long-term stable versus
  compatibility-only
* evaluate future zero-drift integration opportunities with `convert/markdown`
* decide whether future release policy should expose bytes-open helpers or keep
  the current string-first scanner surface
* decide whether reserved issue kinds should remain compatibility-only or be
  widened into emitted warnings in a later release pass

Remaining work:

* decide which current model fields should remain long-term stable and which
  should later narrow to compatibility-only surfaces
* continue refining `doc_parse/xml` typed unsupported-feature taxonomy and
  future release-policy boundaries without changing source-preserving converter
  output
* revisit HTML/Markdown lower-layer extraction separately from final conversion
  policy

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
