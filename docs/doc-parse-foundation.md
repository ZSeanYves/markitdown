# doc_parse Foundation

This document is the source of truth for the current in-tree `doc_parse/*`
foundation line inside `ZSeanYves/markitdown`.

For user-facing package overview, examples, and lower-layer entrypoints, use
[doc_parse/README.md](../doc_parse/README.md).

Current audit scope for this contract:

* `doc_parse/ooxml`
* `doc_parse/pdf`
* `doc_parse/epub`
* `doc_parse/zip`
* `doc_parse/xlsx`
* `doc_parse/csv`
* `doc_parse/tsv`
* `doc_parse/json`
* `doc_parse/yaml`
* `doc_parse/text`
* `doc_parse/xml`
* `doc_parse/html`
* `doc_parse/markdown`
* `doc_parse/docx`
* `doc_parse/pptx`

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
* introducing a new parser, scanner, or semantic foundation does not
  automatically mean the normal `convert/*` path has switched to it

## API Stability Levels

Use the current `doc_parse/*` surface with four buckets:

* Stable candidate API:
  the normal package-facing facade for external use; usually `open_*`,
  `parse_*`, `scan_*`, `read_*`, `list_*`, `inspect_*`, `validate_*`, and
  `classify_*`
* Compatibility surface:
  public model fields and helper-shaped entrypoints that remain exposed because
  current `convert/*`, CLI, and lower-layer tests still depend on them
* Diagnostic / profile helpers:
  profiling, benchmark, dump, and troubleshooting surfaces such as
  `profile_*`, textual debug dumps, and direct benchmark harness helpers; keep
  them documented, but do not treat them as the main stable semantic contract
* Internal exposed surface:
  lower-level tokenizer, walker, parser, or adapter-shaped surface that is
  visible today but should not be the recommended external dependency line

Package READMEs own the precise per-package classification details.

## Current Status Matrix

| Package | Status | Stable surface | Scope | Non-goals | Conversion integration status |
| --- | --- | --- | --- | --- | --- |
| `doc_parse/zip` | external-decoder-backed ZIP foundation candidate | archive open/read/list, path normalization, inventory, inspect, validation, classifier | ZIP archive/container primitive | full ZIP spec, password recovery, recursive archive policy | existing lower-layer integration consumed by `doc_parse/ooxml`, `doc_parse/epub`, and `convert/zip` |
| `doc_parse/ooxml` | OOXML package foundation candidate | open/read/list/query/inspect/strict-validation facade | OOXML package / parts / relationships / content types / media / docProps | Office semantic conversion | existing lower-layer integration consumed by `convert/docx`, `convert/pptx`, and `convert/xlsx` |
| `doc_parse/epub` | EPUB package/spine/nav foundation candidate | package/rootfile/manifest/spine/nav/cover/inspect/validation facade | EPUB container / OPF / manifest / spine / nav / NCX / cover / metadata | reading-system rendering, DRM, CSS/JS | existing lower-layer integration consumed by `convert/epub` |
| `doc_parse/pdf` | native text-PDF foundation candidate | `doc_parse/pdf/api` facade, structured inspect/report, typed issue starter | native text-PDF model / page geometry / text / image / annotation raw signal | OCR default, scanned PDF, full layout engine | existing lower-layer integration consumed by `convert/pdf` |
| `doc_parse/csv` | simple-format parser foundation candidate | parse/options/inspect/validation/classifier | comma-delimited table parser/model | Markdown table / `RichTable` policy | `convert/csv` already consumes the parser/model for CSV normal conversion |
| `doc_parse/tsv` | simple-format parser foundation candidate | TSV facade over CSV core | tab-delimited table parser/model | Markdown table / `RichTable` policy | `convert/csv` already consumes the TSV facade for TSV normal conversion |
| `doc_parse/json` | simple-format parser foundation candidate | parse/AST/inspect/classifier | JSON parser / AST / malformed-input classification | JSON-to-table/list/code-block policy | `convert/json` already consumes the parser/model for JSON normal conversion |
| `doc_parse/yaml` | YAML-subset parser foundation candidate | parse/AST/inspect/classifier | current YAML subset parser / AST | full YAML spec, YAML-to-Markdown policy | `convert/yaml` already consumes the parser/model for YAML normal conversion |
| `doc_parse/text` | plain-text parser foundation candidate | bytes-open/string-parse/inspect/classifier | BOM/newline/line/paragraph structural text model | literal Markdown policy / final rendering | `convert/txt` already consumes the parser/model for TXT normal conversion |
| `doc_parse/xml` | XML parser foundation candidate | tokenize/parse/inspect/validation/classifier facade | safe XML tokenizer / parser / model / inspect / validation | full XML spec, DTD support, namespace semantics, XML-to-Markdown policy | not switched intentionally: `convert/xml` remains source-preserving and the normal XML converter path is not switched |
| `doc_parse/html` | HTML DOM-ish parser foundation candidate | tokenize/parse/inspect/validation/classifier facade | tolerant DOM-ish HTML tokenizer / parser / raw node model / inspect / safety boundary | browser parser, CSS/JS rendering, final HTML-to-Markdown policy | not switched intentionally: `convert/html` still owns the current source/product conversion path |
| `doc_parse/markdown` | Markdown lightweight scanner foundation candidate | scan/inspect/validation facade | lightweight Markdown source scanner / raw block inventory / frontmatter / fenced code detection | Markdown renderer / output normalization / CommonMark full parser | not switched intentionally: `convert/markdown` still owns the passthrough/product path |
| `doc_parse/xlsx` | OOXML semantic foundation candidate | open-workbook / parse-from-package / inspect / validation / classifier facade | SpreadsheetML workbook / sheet / cell / shared strings / styles / merged ranges / conservative formula trace model | full Excel engine, RichTable/Markdown/product output policy | integrated: `convert/xlsx` now consumes the semantic workbook/model while still owning RichTable / IR / Markdown / product policy |
| `doc_parse/docx` | OOXML semantic foundation candidate | open-document / parse-from-package / inspect / validation / classifier facade | WordprocessingML body / inline / table / relationship / style / numbering / notes semantic model | full WordprocessingML support, IR/Markdown/product output policy | not switched intentionally: `convert/docx` remains the current normal conversion path |
| `doc_parse/pptx` | OOXML semantic foundation candidate | open-presentation / parse-from-package / inspect / validation / classifier facade | PresentationML presentation / slide / raw shape / text / table / notes / media / hyperlink semantic model | reading order, layout grouping, caption/image export/product output policy, full PresentationML support | not switched intentionally: `convert/pptx` remains the current normal conversion path |

## Candidate Definitions

* `package/container foundation candidate`
  package-facing reusable lower-layer with stable candidate API, inspect/error/
  validation surfaces, docs, and lower-layer tests for archive/container or
  package-level ownership
* `native text-PDF foundation candidate`
  reusable lower-layer candidate scoped to native text-PDF parsing/model/
  inspect boundaries rather than OCR or scanned-PDF claims
* `parser foundation candidate`
  reusable parser/model/error/inspect foundation with stable candidate API and
  no IR/Markdown/product semantics
* `subset parser foundation candidate`
  parser foundation candidate whose subset boundary is explicit and
  intentionally documented
* `DOM-ish parser foundation candidate`
  tolerant parser/model/inspect candidate that intentionally preserves raw
  structural signal without claiming browser-grade or full semantic
  reconstruction
* `scanner foundation candidate`
  lightweight source-scanner foundation with stable candidate API and raw
  block inventory / inspect / validation surface, but without renderer or
  output-mutation ownership
* `OOXML semantic foundation candidate`
  source-native semantic-model foundation above a lower package substrate,
  with stable candidate API, inspect/error/validation surface, and no
  RichTable/IR/Markdown/product semantics
* `in-tree foundation candidate`
  current repository delivery form for a candidate package that is stable for
  internal reuse under `ZSeanYves/markitdown`, but not yet split into its own
  module
* `future standalone module extraction`
  later release work that may extract one umbrella `ZSeanYves/doc_parse`
  module or narrower packages only after candidate surfaces, dependency
  strategy, and conversion behavior are stable
## Current Packaging Strategy

* these foundations are delivered today as importable subpackages under
  `ZSeanYves/markitdown`
* they are not yet split into independent MoonBit modules
* `convert/*` consumes them, but they are documented as reusable parsing
  foundations rather than as converter-only helpers
* simple-format, markup-parser, lightweight scanner, and OOXML semantic
  foundations are being stabilized in-tree before any future standalone-module
  split is attempted

See also [docs/package-publishing-strategy.md](./package-publishing-strategy.md).

## Scope Of This Document

This page is architecture-facing. It tracks:

* the current `doc_parse/*` contract and status matrix
* `convert/*` vs `doc_parse/*` boundaries
* candidate-surface and maturity expectations
* current in-tree packaging strategy and future split direction

Use related source-of-truth pages for adjacent concerns:

* [doc_parse/README.md](../doc_parse/README.md)
  user-facing overview, package map, and examples
* [package-publishing-strategy.md](./package-publishing-strategy.md)
  module-split and release-policy details
* [performance.md](./performance.md)
  current performance interpretation and baseline
* [benchmarking.md](./benchmarking.md)
  benchmark commands, helper status, and artifact layout

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

* now an OOXML package foundation candidate within current repository scope
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

### `doc_parse/xlsx`

Current role:

* SpreadsheetML semantic foundation candidate above the shared OOXML package
  line
* workbook / sheet / cell / shared-string / styles / merged-range /
  conservative-formula-trace parser/model/inspect/validation package

Current surface:

* `open_xlsx_workbook`
* `parse_xlsx_workbook_from_package`
* `inspect_xlsx_workbook`
* `collect_xlsx_validation_issues`
* `validate_xlsx_workbook`
* `classify_xlsx_error`

Current maturity:

* semantic foundation candidate
* current source-native compatibility surface is centered on `XlsxWorkbook`,
  `XlsxSheet`, `XlsxCell`, `XlsxStyles`, `XlsxMergedRange`, and
  `XlsxFormulaTrace`
* current semantic scope includes workbook ordering, worksheet visibility,
  worksheet relationship targets, shared strings, style/number-format lookup,
  conservative datetime-like display formatting, raw formula text, and
  conservative missing-cache formula trace
* formula/style/date/merged-range boundaries are directly locked by
  lower-layer tests and package README notes

Current boundary:

* `doc_parse/xlsx` owns SpreadsheetML semantic parsing/model/inspect/
  validation/classifier work
* `convert/xlsx` now consumes that semantic workbook/model and still owns
  RichTable shaping, IR lowering, Markdown table policy, wording, hints, and
  product origin/metadata wiring

Known limits:

* not a full Excel engine
* not a full formula evaluator
* no chart / pivot / macro / external-link semantic support
* styles and number formats are conservative semantic formatting aids, not a
  full Excel style engine

### `doc_parse/docx`

Current role:

* WordprocessingML semantic foundation candidate above the shared OOXML
  package line
* source-native body / inline / table / relationship / style / numbering /
  notes semantic parser/model/inspect/validation package

Current surface:

* `open_docx_document`
* `parse_docx_document_from_package`
* `inspect_docx_document`
* `collect_docx_validation_issues`
* `validate_docx_document`
* `classify_docx_error`

Current maturity:

* semantic foundation candidate
* current source-native compatibility surface is centered on `DocxDocument`,
  `DocxBodyBlock`, `DocxParagraph`, `DocxRun`, `DocxInline`, `DocxTable`,
  `DocxRelationship`, `DocxStyles`, `DocxNumbering`, `DocxNotes`,
  `DocxHyperlink`, and `DocxMediaRef`
* current semantic scope includes main-document body blocks, paragraphs, runs,
  text/tab/line-break inlines, raw hyperlink and media refs, tables, styles,
  numbering, note/comment/header/footer discovery, and text-box discovery
* current lower-layer tests lock relationship/style/numbering/notes/media
  boundaries without claiming final heading/list/table/caption/code/image
  output policy

Current boundary:

* `doc_parse/docx` owns WordprocessingML source-native semantic parsing/model/
  inspect/validation/classifier work
* `convert/docx` still owns the current normal conversion path, final
  heading/list/codeblock/blockquote heuristics, Markdown table rendering,
  caption/image product policy, appended product sections, IR lowering, and
  metadata/origin wiring

Known limits:

* not full WordprocessingML support
* not full Office semantic support
* no final heading/list/table/caption/code/image output policy
* styles and numbering preserve conservative semantic signal rather than a
  full style cascade or full list-layout engine
* tracked changes are only handled through conservative deleted-revision
  stripping in this candidate package
* complex fields, equations, charts, SmartArt, and deeper DrawingML semantics
  remain out of scope

### `doc_parse/pptx`

Current role:

* PresentationML semantic foundation candidate above the shared OOXML package
  line
* source-native presentation / slide / raw shape tree / text / explicit table
  / notes / media / hyperlink parser/model/inspect/validation package

Current surface:

* `open_pptx_presentation`
* `parse_pptx_presentation_from_package`
* `inspect_pptx_presentation`
* `collect_pptx_validation_issues`
* `validate_pptx_presentation`
* `classify_pptx_error`

Current maturity:

* semantic foundation candidate
* current source-native compatibility surface is centered on
  `PptxPresentation`, `PptxSlide`, `PptxShape`, `PptxTextParagraph`,
  `PptxTextRun`, `PptxTable`, `PptxNotes`, `PptxRelationship`,
  `PptxMediaRef`, and `PptxHyperlink`
* current semantic scope includes presentation slide order, hidden-slide raw
  signal, slide relationship context, nested group traversal, raw text
  paragraphs/runs, hyperlink refs, explicit table objects, notes, and raw
  media refs
* current lower-layer tests lock slide order / hidden-slide / raw table /
  grouped shape / notes / relationship/media validation boundaries and
  deterministic issue ordering without claiming reading-order or
  layout-recovery ownership

Current boundary:

* `doc_parse/pptx` owns PresentationML source-native semantic parsing/model/
  inspect/validation/classifier work
* `convert/pptx` still owns the current normal conversion path, reading order,
  layout recovery, grouping, title/list/paragraph classification, image
  caption/export policy, Speaker Notes final product policy, IR lowering, and
  metadata/origin wiring

Known limits:

* not full PresentationML support
* not full Office semantic support
* no reading-order recovery or layout grouping in this package
* no final heading/list/paragraph/caption/image output policy
* no image asset export path
* notes remain source-native raw note paragraphs rather than final Speaker
  Notes section policy
* theme/master/layout inheritance, animations, transitions, charts,
  SmartArt, embedded objects, and deeper DrawingML semantics remain out of
  scope

### `doc_parse/zip`

Current role:

* shared ZIP archive/container primitive for `doc_parse/ooxml`,
  `doc_parse/epub`, and `convert/zip`

Current foundation direction:

* now an external-decoder-backed ZIP foundation candidate within current
  repository scope
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

* now a native text-PDF foundation candidate within current repository scope
  for lower-layer use
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

* now an EPUB package/spine/nav foundation candidate within current repository
  scope
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

### Simple-format and markup parser foundations

Current role:

* simple-format, markup-parser, and lightweight scanner foundations now live
  in `doc_parse/*` and are consumed by `convert/*` where already integrated

Current repository strategy:

* these packages own parser/model/error/inspect logic, with Markdown staying a
  scanner/inventory line rather than a renderer
* package-local README files document public API, current boundaries, known
  limits, and relationship to `convert/*`
* `convert/csv`, `convert/json`, `convert/yaml`, and `convert/txt` still own
  IR shaping, Markdown output policy, metadata wiring, and product-facing
  origin semantics
* `convert/xlsx` now consumes `doc_parse/xlsx` for workbook/sheet/cell
  semantic parsing while still owning RichTable / IR / Markdown / wording /
  product metadata policy
* `doc_parse/docx` and `doc_parse/pptx` provide source-native semantic
  packages, but `convert/docx` and `convert/pptx` still own the current normal
  converter paths
* `convert/xml`, `convert/html`, and `convert/markdown` still own their current
  normal product paths even though lower-layer parser/scanner candidates now
  exist under `doc_parse/*`
* these candidate labels are lower-layer foundation labels only; they are not
  claims of full format-family spec coverage or final product conversion
  ownership

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

### OOXML semantic candidate line

Current OOXML semantic line:

* all OOXML semantic sublayers now exist in-tree:
  * `doc_parse/xlsx`
  * `doc_parse/docx`
  * `doc_parse/pptx`
* current converter integration split across that line is:
  * `convert/xlsx` already consumes `doc_parse/xlsx`
  * `convert/docx` remains on the current normal conversion path
  * `convert/pptx` remains on the current normal conversion path

## Current Repository Strategy

Current repository strategy intentionally focuses on:

1. keeping `doc_parse/*` as in-tree reusable package foundations inside
   `ZSeanYves/markitdown`
2. keeping `convert/*` as the owner of IR / Markdown / assets / metadata /
   product semantics
3. documenting which lower-layer packages are already integrated into normal
   convert paths and which are not
4. deferring standalone module extraction while the OOXML semantic candidate
   line and its convert-boundary story continue to stabilize

Current non-goals for this stage:

* no claim that `convert/xml`, `convert/html`, or `convert/markdown` have
  switched their normal paths to the new parser/scanner foundations
* no standalone published `ZSeanYves/doc_parse` module claim yet
* no full-spec claim for XML / HTML / Markdown / YAML / PDF / EPUB / OOXML
