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
