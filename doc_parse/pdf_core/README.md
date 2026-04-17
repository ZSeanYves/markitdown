# pdf_core

`pdf_core` is the low-level PDF structural recovery package inside `markitdown-mb`.

Its responsibility is **not** to emit final Markdown directly. Instead, it parses, normalizes, and reconstructs PDF content into a stable structural document model that can be consumed by upper layers.

In practical terms, `pdf_core` solves the problem of:

> how to recover a PDF — a rendering-oriented and structurally unstable format — into a document-like, structured representation that is suitable for further conversion.

## Current Role in the Repository

On the current `main` branch, the normal PDF path has already been **fully replaced by a native structural recovery mainflow**.

That means:

* the normal PDF path is no longer described as an external text-first pipeline
* `pdf_core` is no longer just an experimental extraction layer
* `convert/pdf` now consumes the recovered native structural model
* OCR remains a **plugin-style path** driven by external tooling and is not the default normal flow

So the role of `pdf_core` today is:

* provide the native low-level recovery backbone for text-based PDFs
* expose stable page / block / line / span structures to upper layers
* support heading / paragraph / noise / layout-related recovery before Markdown emission

---

## What `pdf_core` Outputs

The primary outward-facing result is a structured PDF document model rather than flat extracted text.

Current output is centered around:

* `PdfDocumentModel`
* `PdfPageModel`
* `PdfTextBlock`
* `PdfTextLine`
* `PdfTextSpan`

and lower-layer provenance / geometry / font metadata that is preserved during recovery.

The main recovery chain is:

```text
raw -> chars -> spans -> lines -> blocks -> PdfDocumentModel
```

This is the key point:

* upper layers no longer need to consume only plain extracted text
* upper layers can consume recovered structural units
* heading candidates, paragraph-like blocks, and noise-related candidates are already surfaced in the native model

---

## Main Output Interface

### `PdfDocumentModel`

`PdfDocumentModel` is the primary output interface currently intended for higher-level consumers.

Its pages contain recovered text blocks rather than loose extraction placeholders.

Conceptually, upper layers receive:

* document-level pages
* page-level text blocks
* block-level lines
* line-level spans
* preserved geometry / font / source metadata where available

This makes `PdfDocumentModel` the native structural input for `convert/pdf`.

### Structural granularity currently exposed

The current outward model already provides usable structure at the following levels:

* page
* block
* line
* span

Lower layers still preserve provenance and source-order information where relevant.

Current block-level semantics already include candidate distinctions such as:

* heading-like block candidates
* normal text blocks
* page-number-like or removable-noise candidates

So `pdf_core` is already more than a text extraction package:
it now provides a practical **native structural recovery interface**.

---

## Recovery Pipeline

The native PDF recovery chain currently follows this general structure:

```text
MBTPDF adapter
-> raw
-> chars
-> spans
-> lines
-> blocks
-> PdfDocumentModel
```

### 1. Adapter layer

The current low-level adapter reads PDF content and extracts factual text-related information.

Its responsibilities include:

* iterating pages and content streams
* decoding glyph/text content
* extracting font and source information
* building the raw-layer containers

This layer tries to stay factual rather than semantic.

### 2. Raw layer

The raw layer provides a normalized low-level container for upstream recovery.

Typical responsibilities include:

* preserving decoded text/glyph results
* preserving source references
* preserving break signals
* preserving low-level PDF extraction traces

This layer still reflects the low-level nature of PDF, but in a structured internal form.

### 3. Character layer

The character layer maps raw glyph-level content into structured character records.

Typical fields include:

* decoded text
* unicode
* bbox / origin
* font name / font size
* ligature / compatibility-glyph hints
* decode confidence
* source references
* break-before / break-reason

This is where the package enters character-level structured representation.

### 4. Span layer

The span layer groups consecutive characters into `PdfTextSpan`.

This grouping is intentionally local and conservative. It mainly relies on:

* source continuity
* font consistency
* break propagation

The goal is not to infer final document semantics here, but to create workable text fragments.

### 5. Line layer

The line layer is one of the most important parts of `pdf_core`.

Its responsibilities include:

* recovering human-readable text lines from spans
* correcting common PDF fragmentation problems
* supporting hardwrap recovery
* distinguishing conservative heading/body boundaries
* carrying geometry and layout signals upward

Current line recovery already includes practical handling for:

* Chinese hardwrap
* English hardwrap
* fragmented English words
* compatibility glyph normalization
* same-line vs new-chunk decisions
* conservative page-number-like filtering

### 6. Block layer

The block layer lifts recovered lines into stable block units.

The current strategy remains intentionally conservative:

* heading candidate line -> standalone block
* page-number or removable-noise candidate -> standalone candidate block
* normal body line -> standalone paragraph-like block

This provides a stable baseline for upper layers and avoids amplifying errors too early.

### 7. Document model layer

The final native output is exposed as `PdfDocumentModel`.

This means `pdf_core` is now capable of providing a structured PDF text model to upper layers, rather than only acting as a raw extraction experiment.

---

## What Is Currently Supported

`pdf_core` currently focuses on **text-based PDF** recovery.

### Current supported scope

The native chain already provides useful, regression-backed support for:

* native text extraction into structured document models
* char / span / line / block reconstruction
* text normalization
* common CJK compatibility glyph normalization
* common ligature normalization
* fragmented English word recovery
* English and Chinese hardwrap recovery
* heading candidate surfacing
* paragraph-like block recovery
* page-noise and repeated-header/footer related support
* conservative pseudo two-column negative protection

### Typical sample-backed cases already covered

Current regression-backed behavior includes stable handling of:

* simple text PDFs
* English hardwrap recovery
* Chinese hardwrap recovery
* heading vs body boundary recovery
* repeated header/footer cleanup support
* heading false-positive negative cases
* pseudo two-column negative cases

In practice, `pdf_core` already supports stable structural recovery for simple and moderately complex text-oriented PDFs.

---

## What `pdf_core` Does Not Do Directly

`pdf_core` does not try to be:

* a final Markdown emitter
* a full semantic document engine
* a pixel-perfect visual reconstruction system
* a browser-style layout engine for PDF

Its role is to provide a strong native structural intermediate layer.

Final Markdown shaping still belongs to upper layers such as `convert/pdf` and the shared IR / emitter stack.

---

## OCR Position

OCR is **not** part of the normal native PDF mainflow.

Current OCR behavior should be understood as:

* a plugin-style path
* externally driven
* dependent on external tooling
* separate from the default normal PDF path

In the repository today:

* normal PDF conversion is fully native
* OCR remains optional and externally powered

---

## Current Limitations

Although the native mainflow is now in place, `pdf_core` still has clear boundaries.

### 1. Complex layout understanding is still limited

The package does not yet fully solve all difficult layout problems such as:

* full multi-column reading-order reconstruction
* floating text blocks
* advanced cross-column interaction
* complex page-layer ordering
* full table / caption / footnote semantic reconstruction

### 2. Layout semantics are still heuristic-heavy

The current system uses geometry, font, spacing, and source-order signals, but many decisions are still based on conservative heuristics rather than full layout-semantic reasoning.

### 3. Non-text object integration is still incomplete

The package may already preserve or prepare room for non-text objects such as:

* images
* vectors
* annotations
* forms
* outlines

But the current main focus remains the text recovery chain.

### 4. Some extreme PDFs may still lose information before later recovery stages

This is especially true for:

* extreme layout anomalies
* extractor-level decoding oddities
* difficult pseudo two-column cases
* heavily fragmented or semantically ambiguous content streams

---

## Design Principles

The current package follows a few core principles.

### 1. Layered recovery

Problems are solved at the most appropriate layer:

* raw: factual extraction
* chars: character structuring
* spans: local grouping
* lines: textual continuity recovery
* blocks: early semantic stabilization
* model: unified outward representation

### 2. Explainable heuristics

Rules are intentionally kept:

* understandable
* testable
* debuggable
* regression-friendly

### 3. Conservative before aggressive

In PDF recovery, aggressive rules can easily fuse unrelated structures.
The package prefers to establish a stable baseline first and expand from there.

### 4. Native structure first

The normal PDF path is now built on native structure recovery itself, not on a flat-text-first fallback description.

---

## Why `pdf_core` Matters Now

A short summary of the current stage:

> `pdf_core` is no longer just a low-level PDF text extraction experiment.
> It is now the native structural recovery backbone of the PDF normal path on `main`.

More concretely:

* it no longer merely “gets text out of a PDF”
* it now actively reconstructs structure
* it already outputs a usable document model for upper layers
* it serves as the native foundation for the current `convert/pdf` mainflow

That is the most important status change to reflect in this README.
