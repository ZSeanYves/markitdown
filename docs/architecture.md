# Architecture

This page describes the current shipping structure of `markitdown-mb`.
It focuses on stable package, binary, and repository boundaries rather than the
migration history that produced them.

## Pipeline

Current flow:

**input -> dispatcher -> format converter / parser -> unified IR -> Markdown / assets / metadata**

The design target is conservative, explainable extraction rather than visual
reconstruction.

## Repository Boundaries

Current repository split:

* the main repo carries runtime code, tests, checked samples,
  external-quality entrypoints, and benchmark/release entrypoints
* `markitdown-quality-lab/` is an optional repo-local external repository for
  full quality rows, external corpus payloads, and offline PDF layout work
* normal runtime, `moon test`, and `bash samples/check.sh`
  remain self-contained in the main repo

## Product Surfaces

| Binary / package | Role | User-facing | Depends on quality-lab |
| --- | --- | --- | --- |
| `cli` | normal product entrypoint | yes | no |
| `pdf` | bundled PDF runtime component | indirectly | no |
| `zip` | bundled ZIP runtime component | indirectly | no |
| `debug` | inspect/report tool | developer | optional |
| `bench` | benchmark tool | developer | no |
| `doc_parse/pdf/layout_model_tool` | PDF layout export/infer tool | developer | optional |

Current product contract:

* users stay on `cli`
* `.pdf` inputs route through bundled `pdf`
* `.zip` inputs route through bundled `zip`
* `debug` and `bench` stay explicit developer tools
* image OCR is available through the main CLI
* PDF OCR is not wired in the shipped product path

## Package Responsibilities

| Package family | Current responsibility |
| --- | --- |
| `core` | document model, metadata model, emitters, pure helpers |
| `cli_common` | runtime/path/process/component-discovery helpers |
| `cli_support` | product-path parser/help/version/routing glue |
| `convert/*` | conversion policy from source formats into unified IR |
| `doc_parse/*` | lower-layer parser/model/inspect foundations |
| `doc_parse/pdf/vendor/mbtpdf` | trimmed runtime-critical PDF support subtree |

Current rules:

* `core` stays CLI-free
* `cli` remains the primary product surface
* `convert/*` owns format-to-IR policy
* `doc_parse/*` owns parser/model/inspect foundations
* quality-lab stays developer infrastructure, not runtime dependency

## Unified IR Notes

Current shared IR now includes note semantics in addition to basic blocks and
inlines:

* inline note references use `Inline::NoteRef(NoteRef)` rather than
  format-private Markdown string patches
* note bodies use document-level `Document.note_definitions`, with each body
  represented as a shared `NoteDefinition`
* `NoteDefinition` carries the note id, marker, kind, placement, source kind,
  body status, and body blocks
* Markdown emission supports two safe modes:
  * full footnote emission when a reference and a resolved definition are both
    present
  * marker-only fallback when only the reference marker is known
* metadata sidecars reflect inline `NoteRef` markers as part of block text and
  serialize document-level `note_definitions` when resolved note bodies are
  present

Current intent:

* structured sources with reliable body stores should prefer full
  `NoteRef` + `NoteDefinition` output
* visual or weak sources should fail closed to marker-only output rather than
  dangling Markdown footnotes
* PDF can attach superscript markers through shared `NoteRef` without claiming
  full footnote-body recovery
* DOCX now lowers structured footnote/endnote references and bodies through the
  shared note IR and emits full Markdown footnotes when the body is available
* Markdown native footnotes lower through the same `NoteRef` and
  `NoteDefinition` path while preserving passthrough behavior for ordinary
  Markdown
* EPUB note support is structure-led rather than based on bare superscript
  text:
  * explicit same-document references with `epub:type="noteref"` or
    `role="doc-noteref"` lower to shared `NoteRef` when their target body is
    resolved
  * resolved body targets such as `<aside>`, `<section>`, `<li>`, or `<div>`
    with footnote-like `epub:type`, `role`, `class`, or id lower to document
    `NoteDefinition`
  * EPUB spine merging namespaces document-local note ids with the spine entry
    id and carries `NoteDefinition` records into the merged EPUB document
* HTML uses the same explicit same-document noteref/body machinery where the
  markup already provides strong noteref semantics, but broader conservative
  inference for common HTML footnote patterns remains future work
* for HTML and EPUB alike:
  * ordinary `<sup>1</sup>`, `<sup>TM</sup>`, math exponents, and orphan
    anchors should remain plain text or normal links until a body can be
    resolved safely
  * broad conservative HTML inference, including `<sup><a href="#id">...</a></sup>`
    without explicit noteref semantics, remains future work

## PDF Text-Flow And Annotation Links

Native PDF conversion remains rule-driven and bounded. Current normal-path
cleanup covers:

* paragraph soft merge for high-confidence same-flow fragments
* numbered heading split/promotion when the text signal is strong
* superscript-style marker attachment through shared `NoteRef` marker fallback
* two-column guards that avoid merging nearby lines across separate x-bands
* high-confidence URI annotation links when the visible label is unique inside
  the extracted text block

The annotation-link policy is intentionally conservative:

* visible text plus an aligned URI annotation can emit `[text](url)`
* invisible annotation internals are not dumped as body text
* duplicate-label or ambiguous matches stay plain text
* popup/text annotations keep using the annotation appendix policy

These rules do not add runtime models, OCR, or PDF footnote body association.

## PDF, ZIP, And OCR Boundaries

Current PDF split:

* `pdf`: bundled PDF runtime component
* `convert/pdf`: normal-path PDF conversion logic
* `convert/pdf_layout`: feature and gate logic for report/debug/dev surfaces
* `convert/pdf_debug`: explainability/debug-oriented PDF surface
* `doc_parse/pdf/layout_model_tool`: developer export/infer tool

Current ZIP split:

* `zip`: ZIP library and bundled product component
* `convert/zip_core`: shared traversal / remap / metadata / origin logic
* `convert/zip_worker`: lightweight delegated product path

Current OCR rule:

* normal document conversion remains no-OCR
* future product OCR will re-enter through the main CLI only
* `convert/vision` remains the sole OCR/Vision implementation path

Current path split:

* normal conversion path: dispatcher -> format converter -> unified IR ->
  Markdown / assets / metadata
* shipped image OCR path: dispatcher -> `convert/vision` -> unified IR ->
  Markdown
* future PDF OCR path should remain an explicit side path that rejoins the
  shared IR/Markdown flow only after explicit OCR selection
* native PDF extraction must remain unchanged unless that explicit PDF OCR path
  is selected

Important current facts:

* normal runtime does not read model JSON
* normal runtime does not read quality-lab assets
* PDF layout behavior in the normal path is distilled into MoonBit rules/gates
* delegated product `zip` stays outside the heavy vendored PDF closure

## Build Guardrails

Current guardrail intent:

* `cli` should remain `mbtpdf=0`
* heavy native PDF closure stays behind bundled `pdf`
* delegated product `zip` should remain `mbtpdf=0`
* normal runtime should not grow Python/model-loader dependencies

Current checked closure snapshot:

* `cli mbtpdf count`: `0`
* `zip mbtpdf count`: `0`
* `pdf mbtpdf count`: `23339`

## User Entry Points

Current user entrypoints:

* `samples/check.sh`
* `samples/check_quality.sh`
* `samples/bench.sh`

Recommended copy-paste-safe commands:

* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/bench.sh`

See also:

* [supported-formats.md](./supported-formats.md)
* [quality-and-release.md](./quality-and-release.md)
* [pdf.md](./pdf.md)
* [performance.md](./performance.md)
