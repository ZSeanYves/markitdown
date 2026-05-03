# PDF Core Annotation/Link Pass

This document records the PDF P1.1 `pdf_core` annotation/link signal pass.

Scope for this round:

* keep annotation/link raw model visible and auditable
* improve inspect/debug visibility for annotations and internal destinations
* make outline/bookmark gap explicit
* keep PDF Markdown output unchanged

Non-goals for this round:

* no `convert/pdf` link emission changes
* no Markdown expected changes
* no OCR or vision changes
* no full outline/bookmark reconstruction
* no full PDF action system

## Current Annotation/Link Data Flow

```text
PDF raw objects / page Annots
-> pdf_core annotation extraction
-> RawAnnotationInfo
-> PdfAnnotationObject / model
-> PdfPageModel.annotations
-> inspect/debug
-> convert/pdf current behavior (debug-only today)
```

## Current Signal Surface

| Signal | Current status | Notes |
| --- | --- | --- |
| `/Link` subtype | present | extracted from raw page annotations |
| URI action | present | `URI` action resolved into annotation `uri` |
| internal destination | present | `Dest` / `D` captured as raw/model string |
| bbox | present | annotation rectangle is preserved |
| page index | present | page-local annotation ownership exists |
| object ref | present | raw/model object ref is preserved |
| source refs | present | model exposes source refs; raw source refs are still empty |
| quadpoints | gap | not exposed yet |
| outline/bookmark model | gap/placeholder | `PdfDocumentModel.outlines` exists but remains empty |
| Markdown link emission | absent | converter does not emit annotation links yet |

## Next Consumer Policy

See [PDF Link Emission Policy](./pdf-link-emission-policy.md) for the staged
convert-side policy that will decide when a PDF link annotation may become
`Inline::Link` and when it must remain debug-only.

## Debug / Inspect

Current public debug/inspect surfaces now expose:

* annotation count per page
* annotation subtype
* URI / dest / target-page / object-ref / bbox
* annotation source-ref preview
* document outline count placeholder

This is enough to tell whether a future link emission bug is caused by core
extraction or converter policy.

## Remaining Gaps

* raw annotation source refs are still empty
* quadpoints are not exposed
* outlines/bookmarks are still not populated
* no action-system generalization beyond URI/internal-dest basics

## Next Implementation Sequence

1. Keep annotation/link raw surface visible in inspect/debug.
2. If convert/pdf later wants emission, define conservative policy from this
   model instead of re-parsing PDF objects.
3. Populate outlines/bookmarks only when a safe, low-risk lower-layer model is
   available.
