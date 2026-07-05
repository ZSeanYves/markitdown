# OCR and PDF OCR / Layout Architecture Guide

> Path: `docs/architecture/ocr-and-pdf-ocr-architecture.md`
>
> This document complements [mb-markitdown-architecture.md](./mb-markitdown-architecture.md)
> and [format-mode-and-execution-profile-architecture.md](./format-mode-and-execution-profile-architecture.md)
> with focused rules for OCR, PDF OCR, layout providers, provider selection, and trigger conditions.

Recommended reading order:

1. Read the main architecture guide first.
2. Then read the mode and profile guide.
3. Finally read this document for OCR, PDF OCR, layout-provider, and trigger rules.

---

## 0. Document Scope

This document answers a narrow set of questions:

1. What OCR means in this project.
2. How OCR relates to `Balanced`, `Accurate`, and `Stream`.
3. When PDF is allowed to enter OCR or layout-oriented routes.
4. How page OCR differs from embedded-image OCR inside PDF.
5. How providers such as Tesseract and PaddleOCR enter the unified product chain.
6. How batch, zip, or container handling should trigger scanned-PDF OCR without damaging normal PDF behavior.

This is a normative architecture document. If the implementation temporarily differs, that difference should be treated as convergence debt.

---

## 1. Design Goal

OCR-related design must satisfy all of the following:

1. The default product path stays lightweight.
2. Mode semantics stay stable and do not collapse into provider names.
3. Users can trigger OCR explicitly or in controlled batch flows.
4. Normal born-digital PDF should not be accidentally treated as image-only input.
5. Providers must be swappable without changing the product contract.
6. Every OCR decision must stay explainable in diagnostics and provenance.

---

## 2. Core Conclusion

If only five rules are remembered, they should be:

1. `mode` and `OCR policy` must stay decoupled.
2. PDF OCR must not be triggered merely because a file is large or in batch mode.
3. Automatic PDF OCR must be based on scanned-like probe evidence.
4. PDF OCR means page OCR by default, not automatic OCR of every embedded figure.
5. Provider choice is part of plan execution, not part of mode meaning.

---

## 3. OCR Capability Boundary

In this project, OCR is a constrained capability layer.

Its formal responsibilities include:

1. recovering text from images or rasterized pages
2. producing OCR structure with bounding boxes and confidence
3. optionally providing layout regions, reading-order hints, or table signals where the route supports them

It does not directly promise:

1. speculative reading-order recovery without evidence
2. speculative figure understanding
3. direct OCR-to-final-Markdown shortcuts
4. replacing the born-digital PDF native-text path by default

OCR should therefore sit inside the architecture like this:

```text
OCR provider
  -> OcrPageModel / LayoutRegion / TableSignal / confidence
  -> parser-owned facts
  -> IR passes
  -> renderer
```

Not like this:

```text
OCR provider -> final Markdown
```

---

## 4. Relationship Between Mode and OCR

### 4.1 Mode Is Not a Provider Name

`Balanced`, `Accurate`, and `Stream` are product strategies, not provider labels.

These mappings must not become architecture truth:

1. `Balanced = Tesseract`
2. `Accurate = PaddleOCR`
3. `Accurate = OCR is always required`

The correct relationship is:

1. `Balanced`: prefer lightweight canonical behavior; if OCR is allowed, prefer the balanced OCR default
2. `Accurate`: allow stronger OCR or layout routes where formally supported; if OCR is allowed, prefer the accurate OCR default
3. `Stream`: changes resource posture, not the meaning of OCR itself

### 4.2 Mode and OCR Policy Must Stay Decoupled

OCR policy is a feature-control layer.

Mode is a product-strategy layer.

This separation matters because:

1. not every accurate route needs OCR
2. some balanced routes do need OCR when the user opts in
3. stream support should not invent OCR behavior by itself

---

## 5. OCR Policy Design

### 5.1 Generic OCR Policy

A generic OCR policy surface should distinguish:

- no OCR
- explicit OCR
- scanned-like auto OCR where the format supports it
- route-specific variants such as `redo`

### 5.2 PDF OCR Policy

For PDF, OCR policy needs extra discipline because PDF has both native-text and scanned-like cases.

The formal policy family should continue separating:

- no PDF OCR
- explicit PDF OCR
- auto-scanned PDF OCR
- accurate-specific stronger PDF OCR variants where formally supported

---

## 6. PDF OCR Trigger Rules

### 6.1 Trigger Styles That Are Not Allowed

These must not become formal trigger rules:

1. "the file is large, so use OCR"
2. "the user is in batch mode, so OCR all PDFs"
3. "the file contains images, so OCR everything"

### 6.2 Trigger Styles That Are Allowed

These are allowed:

1. the user explicitly requested PDF OCR
2. the user requested `pdf_ocr_policy = auto_scanned`
3. scanned-like probe evidence supports OCR for the whole document or some pages
4. the accurate PDF strategy explicitly defaults to `auto_scanned`

### 6.3 Scanned Batch Handling Under Balanced

`Balanced` must not silently turn into `Accurate`.

But `Balanced + pdf_ocr_policy=auto_scanned` is a valid formal design:

```text
Balanced + pdf_ocr_policy=auto_scanned
```

That combination keeps the balanced mode meaning intact while still allowing controlled scanned-PDF OCR.

---

## 7. Scanned-Like Probe

### 7.1 Goal

The scanned-like probe is the only acceptable evidence source for automatic PDF OCR.

It should provide structured signals, not freeze the final route by itself.

### 7.2 Typical Probe Signals

Useful signals include:

1. `pdf_page_count`
2. `pdf_native_text_span_count`
3. `pdf_native_text_coverage_ratio`
4. `pdf_empty_text_page_count`
5. `pdf_large_image_page_count`
6. `pdf_page_image_coverage_ratio`
7. `pdf_scanned_like_page_count`
8. `pdf_scanned_like_page_ratio`

If available, the system may also use:

1. `pdf_average_char_density`
2. `pdf_text_layer_quality_hint`
3. `pdf_vector_text_presence`
4. `pdf_background_image_dominant_page_count`

### 7.3 Decision Principle

The detection rule should stay conservative:

1. prefer finding pages with missing or very weak text layers
2. combine text coverage with image coverage and density clues
3. avoid false positives on mixed PDFs

### 7.4 Planner Ownership

Probe provides evidence.
Planner decides:

1. whether the document is scanned-like
2. whether OCR is page-selective
3. which route reason and strategy-switch records should be emitted

---

## 8. Page-Level Hybrid PDF OCR

### 8.1 Avoid Whole-Document Forced OCR

Mixed PDFs are common:

1. some pages are scanned, others are born-digital
2. appendices can be image-heavy
3. some text layers are broken while others are healthy

For these cases, whole-document forced OCR is often the wrong product choice.

### 8.2 Preferred Hybrid Model

The preferred route model is:

```text
pdf page route:
  native_text_page
  ocr_page
```

Assembly rule:

1. each page keeps its own provenance
2. native-text pages stay native-text
3. scanned-like pages can use OCR
4. one final document is assembled downstream

### 8.3 Redo Semantics

`redo` should mean:

1. keep strong native-text facts where they are trustworthy
2. rerun OCR on weak or broken pages
3. avoid clobbering healthy native-text pages with noisier OCR text

---

## 9. PDF Page OCR vs Embedded Image OCR

This is one of the most important boundaries in the project.

### 9.1 Page OCR

Page OCR means:

1. rasterize the page
2. send the whole page to OCR or a layout-aware provider

Use it for:

1. scanned PDF
2. image-based PDF
3. weak-text-layer PDF
4. accurate routes that need page-level OCR or layout recovery

### 9.2 Embedded Image OCR

Embedded image OCR means:

1. extract an image asset from inside the PDF
2. OCR that asset separately

Use it for:

1. screenshots or figures that contain text
2. image appendices
3. special image-search or RAG scenarios

### 9.3 Formal Rule

By default:

1. page OCR may be driven by `pdf_ocr_policy`
2. embedded image OCR must not be auto-enabled just because page OCR is enabled
3. embedded image OCR must remain a separate feature and policy decision

Otherwise the system risks:

1. OCRing normal illustrations by mistake
2. polluting body reading order with figure OCR text
3. duplicating content through both page OCR and image OCR

Diagnostics and provenance must therefore keep these separate:

1. `pdf_page_ocr_used`
2. `pdf_asset_image_ocr_used`

---

## 10. Provider Architecture

### 10.1 Provider Is a Backend, Not a Product Contract

The product contract should never be defined as:

1. "accurate PDF means PaddleOCR"
2. "image OCR means Tesseract"

Instead:

1. define provider kinds
2. record selected provider in the plan and provenance
3. let policy choose mode-aware defaults
4. keep missing-dependency behavior explicit

### 10.2 Provider Categories

The architecture should continue thinking in at least these semantic categories:

1. `TextOcrProvider`
2. `DocumentLayoutProvider`
3. `TableStructureProvider`
4. `PdfRasterProvider`

One backend may still implement several of them, but the product contract should keep the separation visible.

### 10.3 Recommended Provider Roles

For the current product line:

1. `Tesseract` is a lightweight, CLI-friendly OCR base
2. `PaddleOCR` / `PP-StructureV3` is a better fit for accurate OCR and layout-oriented paths
3. `pdftoppm` or similar tooling is a raster backend, not the OCR provider itself

### 10.4 Default Provider Policy

Recommended defaults:

1. direct image balanced OCR: `Tesseract`
2. direct image accurate OCR: `PaddleOCR`
3. balanced PDF OCR: `Tesseract`
4. accurate PDF OCR: `PaddleOCR`

These are defaults, not architecture lock-in.

### 10.5 Fail-Closed Provider Policy

The default product bias remains fail-closed.

At the same time, the current formal behavior allows one narrow, explicit provider fallback class:

1. `pdf --accurate` may fall back from the accurate OCR provider to the balanced OCR provider when accurate dependencies are missing
2. direct image `--accurate` may do the same

This is not silent degradation.

The required behavior is:

1. requested provider and effective provider must both be visible in diagnostics and provenance
2. missing dependencies must produce stable dependency diagnostics and install guidance
3. fallback must be explicit and warning-bearing
4. unsupported accurate behavior for formats without a formal accurate contract must not pretend to be real accurate support

### 10.6 Paddle Wrapper Runtime Contract

The current implementation uses an executable wrapper contract for `PaddleOCR`.

Runtime contract:

1. wrapper path comes from `MARKITDOWN_PADDLE_OCR_CMD`
2. invocation shape is:

```text
<wrapper_cmd> <image_path> [--lang <LANG>]
```

3. the wrapper writes one JSON object to `stdout`
4. non-zero exit maps to execution or availability diagnostics
5. invalid JSON maps to parse diagnostics
6. empty pages map to empty-result diagnostics

---

## 11. Route Design

### 11.1 PDF Canonical Route

For born-digital PDF, the canonical product path remains native-text first.

OCR and layout upgrades must be explicitly policy-driven or probe-supported.

### 11.2 Image Canonical Route

Direct image OCR is a formal OCR route, not a PDF route pretending to parse images.

### 11.3 Route Is Not Provider

Route answers "what product path are we taking".
Provider answers "which backend is used inside that path".

Those must stay separate.

---

## 12. ExecutionIntent, ProbeOutcome, and Plan Extensions

### 12.1 ExecutionIntent

Execution intent should keep OCR-related requests normalized:

- mode
- output view
- stream request
- direct image OCR intent
- PDF OCR policy
- language hints

### 12.2 ProbeOutcome

Probe outcome should expose scanned-like evidence and prepared source data without freezing route truth.

### 12.3 ResolvedExecutionPlan

The final plan should expose enough OCR-related truth for downstream use:

- route
- requested OCR posture
- selected provider
- effective provider
- fallback reasons
- page-level mixed-route facts when applicable

---

## 13. Diagnostics and Provenance

OCR behavior is only trustworthy when it is visible.

Diagnostics and provenance should make these questions answerable:

1. Was OCR requested?
2. Why did OCR run or not run?
3. Which provider was requested?
4. Which provider actually ran?
5. Did the system fall back?
6. Was the fallback route-level, provider-level, or both?
7. Which pages used native text versus OCR?

---

## 14. Batch, Zip, and Container Recursion

### 14.1 Batch Principle

Batch handling should stay product-honest:

1. batch mode must not weaken route fidelity
2. batch mode must not force OCR globally
3. batch mode may carry explicit OCR policy from the caller

### 14.2 Recommended Batch Semantics

For scanned-PDF handling in batch:

1. keep the requested mode stable
2. carry `pdf_ocr_policy=auto_scanned` if the caller wants batch scanned-PDF support
3. let probe and planner decide per document or per page

This keeps batch behavior scalable without turning it into silent overreach.

---

## 15. Convergence Guidance for the Current Design

The current implementation should keep converging toward these stable outcomes:

1. one OCR vocabulary across route, provider, diagnostics, and docs
2. explicit accurate-to-balanced OCR fallback for supported accurate OCR cases
3. no fake accurate support for formats that do not have it
4. clearer page-level provenance for mixed PDF

---

## 16. Things the Project Should Not Do

The project should not:

1. silently OCR every PDF in batch mode
2. silently OCR every embedded figure inside PDF
3. silently switch OCR providers without provenance
4. pretend that unsupported accurate behavior is still accurate
5. let providers redefine what mode means

---

## 17. Recommended Evolution Order

The most stable long-term order is:

1. keep balanced OCR paths reliable
2. keep accurate OCR paths explicit and diagnosable
3. improve page-level mixed-PDF assembly
4. expand typed layout and table signals only where regression coverage is strong enough
