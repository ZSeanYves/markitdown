# PDF Link Emission Policy

This document records the conservative PDF P2 annotation/link emission policy.

## Current PDF Signal

`doc_parse/pdf` now exposes:

* annotation subtype
* URI
* internal destination / GoTo target string
* bbox
* page index
* source refs
* debug/inspect visibility

`convert/pdf` now emits a very narrow subset of PDF annotation links into
Markdown:

* single-line, high-confidence URI annotations
* safe schemes only: `http`, `https`, `mailto`

All other PDF annotation cases remain debug-only.

## Why PDF Links Are Not Generic HTML/OOXML Links

PDF link annotations are geometry-driven objects, not semantic inline runs.
Unlike DOCX/HTML/PPTX hyperlinks, the text that should become the visible link
label is not always explicit. A conservative policy must therefore match
annotation geometry to visible text before emission.

## URI Link Emission Policy

Emit `Inline::Link` only when all of the following are true:

* annotation subtype is `/Link`
* URI is present and non-empty
* URI scheme is safe to preserve (`http`, `https`, `mailto`, or a clearly
  relative/opaque string that we keep without fetching)
* annotation bbox or quadpoints overlap one clearly visible line/span cluster
* matched text is non-empty
* matched text stays within one local block or one tight, continuous text run
* the link does not overlap another already-emitted link
* the matched text is not an image caption / artifact / repeated edge noise

If the match is uncertain, keep the annotation in debug/metadata only and do not
emit Markdown link text.

## Internal Dest / GoTo Policy

Internal destinations are currently debug-only.

* do not emit Markdown links for internal Dest / GoTo yet
* keep the signal in `doc_parse/pdf` inspect/debug
* revisit after a future anchor model exists

## Unsafe Scheme Policy

Safe to preserve:

* `http`
* `https`
* `mailto`

Debug-only or reject for emission:

* `javascript:`
* empty URI
* unsupported action kinds
* malformed URI

No remote fetch is ever performed.

## Minimal Future Implementation Shape

Stage A:

* build a link-matching helper from page text geometry + annotations
* keep output debug-only
* current helper status in this round:
  * URI scheme filter is implemented for `http` / `https` / `mailto`
  * single-line bbox matching is implemented
  * ambiguous / dest-only / unsupported / too-large / no-visible-text cases are
    debug-only

Stage B:

* emit `Inline::Link` for high-confidence single-line URI cases
* current landed scope:
  * single matched line only
  * no internal Dest / GoTo
  * no multiline links
  * no overlapping / ambiguous / too-large / no-visible-text cases
  * no image-area link emission

Stage C:

* add provenance in metadata if the schema already has a suitable slot

Stage D:

* handle multi-line, overlapping, image-area, and internal-destination cases

## Sample / Test Plan

* `pdf_link_uri_single_line`
* `pdf_link_uri_multiple_words`
* `pdf_link_uri_multiline_current_behavior`
* `pdf_link_internal_dest_current_behavior`
* `pdf_link_overlapping_current_behavior`
* `pdf_link_image_area_current_behavior`
* `pdf_link_unsupported_scheme_current_behavior`
* `pdf_link_no_visible_text_current_behavior`

## Non-goals

* no default PDF Markdown output change in this round
* no full action system
* no internal-anchor emission yet
* no OCR / vision / LLM path
