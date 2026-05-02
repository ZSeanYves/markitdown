# PPTX H2 Layout Quality Review

This document records the current PPTX H2 layout-quality review status for
`markitdown-mb`.

It is an audit and planning document. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/pptx/pptx_parser.mbt`
* package open + slide-order resolution: `convert/pptx/pptx_package.mbt`
* shape collection and paragraph extraction: `convert/pptx/pptx_shape_collect.mbt`,
  `convert/pptx/pptx_slide.mbt`, `convert/pptx/pptx_text.mbt`,
  `convert/pptx/pptx_paragraph_meta.mbt`
* reading-order and grouping heuristics: `convert/pptx/pptx_reading_order.mbt`,
  `convert/pptx/pptx_layout_base.mbt`, `convert/pptx/pptx_grouping.mbt`,
  `convert/pptx/pptx_group_candidates.mbt`, `convert/pptx/pptx_table_like.mbt`,
  `convert/pptx/pptx_geom.mbt`, `convert/pptx/pptx_noise.mbt`
* image export: `convert/pptx/pptx_image_assets.mbt`
* relationship helpers: `convert/pptx/pptx_rels.mbt`
* shared OOXML substrate: `doc_parse/ooxml/*`

### Dispatch and container wiring

* `.pptx` is routed through the shared dispatcher
* ZIP entry conversion also routes self-contained `.pptx` entries through the
  same parser path

### Metadata / provenance

* metadata format is `pptx`
* `source_name` and `slide` are populated on emitted blocks and assets
* image asset origins keep `relationship_id` and normalized OOXML media
  `source_path`
* OOXML document properties are available through the CLI metadata sidecar path
* block origins are still lightweight: slide index and block index exist, but
  there is no shape/run-level OOXML anchor model
* notes/comment/hidden-slide provenance is not currently surfaced

## Current H2 status

### Current strengths

* presentation order comes from `ppt/presentation.xml` relationship order, with
  a conservative slide-part fallback
* title/body/list separation is already connected to placeholder-like and
  geometry-aware signals
* paragraph-level bullet kind and nesting level are preserved in the current
  list lowering path
* run-level external hyperlinks and basic whole-shape external hyperlink
  fallback are already present
* embedded images are exported with stable asset names plus OOXML
  `descr`/`title` metadata where available
* current layout recovery already distinguishes plain body text from
  caption-like, callout-like, and table-like regions conservatively
* slide/caption/image metadata regression already exists in the current test
  suite

### Current policy fixed by regression

* slide traversal follows presentation order rather than lexicographic part
  order
* each slide emits a synthetic `## Slide N` boundary heading
* high-confidence slide titles become a deeper heading inside the slide body
  instead of replacing the synthetic slide boundary
* title-shape multi-paragraph text is merged into one heading line
* `<a:br>` becomes inline line breaks, while separate `<a:p>` paragraphs remain
  separate slide paragraphs
* paragraph bullet properties drive list recovery first; bullet-like literal
  text is only a fallback
* whole-shape hyperlink promotion only happens when the shape contains exactly
  one external hyperlink target and no run-level link is already present
* missing or broken hyperlink relationships degrade to plain text instead of
  aborting slide conversion
* images only come from embedded OOXML media relationships; there is no remote
  fetch path
* speaker-note-like text drawn on the slide canvas stays as ordinary slide body
  text; actual notes pages are not traversed
* current "table" recovery is geometry/text-shape heuristics, not explicit
  `a:tbl` table-XML lowering
* hidden-slide state is not preserved today, so resolved slides are emitted with
  no hidden annotation/filtering

### Known H2 limits

* no notes-page output
* no comments output
* no internal-link / action / media-hover hyperlink promotion
* no explicit hidden-slide policy or annotation
* no typed layout/master/placeholder model beyond current heuristics
* no explicit `graphicFrame` / `a:tbl` table object model
* no SmartArt / chart / OLE / embedded-media semantics
* no real group-shape tree semantics beyond current geometry-based flattening
* no shape/run/link provenance beyond slide-level block indexing

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| Slide order and boundaries | Presentation order is stable and each slide gets a synthetic boundary heading | Stable per-slide segmentation plus cleaner parity with other tools' slide markers | Small | No | Keep current slide-boundary policy stable and benchmark more decks |
| Title/body separation | Placeholder-like and geometry heuristics recover many titles well | Better parity on messy real-world masters/placeholders | Moderate | Yes | Preserve richer placeholder/layout/master signals before more converter guessing |
| Reading order | Conservative geometry/group heuristics recover many simple slides | Better dense-layout and two-column fidelity | Large | Yes | Improve lower-layer shape graph and debug surfaces before more heuristics |
| Placeholder/layout/master signals | Current path uses lightweight title/body hints only | Stronger semantic use of title/body/subtitle/content placeholders | Moderate | Yes | Add typed placeholder/layout/master model |
| Grouped shapes | Flattened heuristically | Better preservation of grouped cards/callouts | Large | Yes | Model group-shape nesting explicitly |
| Bullets/numbering/nested lists | Simple bullets/numbering work; nesting depends on paragraph level | Better parity on mixed and complex list layouts | Moderate | Partly | Add real-world list decks and only then adjust converter heuristics |
| Real table XML | Current path does not lower explicit `a:tbl` separately | Stable table semantics when slide authoring used real PowerPoint tables | Large | Yes | Parse `graphicFrame`/`a:tbl` before more table heuristics |
| Table-like vs card-like/timeline-like boundary | Heuristics already avoid many false positives, but remain layout-sensitive | Better precision on dashboards/cards/timelines | Large | Partly | Expand coverage and tighten heuristics only after lower-layer table signals improve |
| Images alt/title/descr/caption | Image export is stable; single-image caption-like pairing exists | Better multi-image caption association and figure semantics | Moderate | Partly | Add more real-world image/caption corpora before semantic expansion |
| Hyperlinks | Run-level and simple shape-level external links work | Better parity for internal links, action links, and non-text shapes | Moderate | Yes | Expose richer relationship/action surfaces first |
| Speaker notes | Not surfaced | Mainstream ingestion often exposes notes or optional note text | Large | Yes | Traverse notes relationships and define default note policy |
| Comments | Not surfaced | Optional comment recovery or clear non-goal | Moderate | Yes | Expose comments parts first |
| Charts | Not surfaced | At least explicit downgrade or artifact awareness | Moderate | Yes | Detect chart parts and decide warning/fallback policy |
| SmartArt | Not surfaced | Better readable fallback on SmartArt-heavy decks | Large | Yes | Expose SmartArt/drawing text surfaces before converter work |
| Embedded media/OLE | Not surfaced | Clear unsupported handling | Moderate | Yes | Detect media/OLE parts and keep no-fetch/no-render policy |
| Hidden slides | Not preserved | Clear include/exclude/annotate policy | Moderate | Yes | Preserve hidden-slide metadata in presentation model |
| Document properties | Available in metadata sidecar path | Keep this stable and regression-covered | Small | No | Maintain current OOXML docProps coverage |
| Slide/asset origin metadata | Slide-level and image relationship provenance exist | Richer shape/link/table origins | Moderate | Yes | Extend lower-layer anchors before schema-free converter patching |
| Large deck performance | Only light smoke/comparison coverage existed before this pass | Separate text-only, image-heavy, layout-dense, and many-slide baselines | Moderate | Partly | Expand smoke/comparison tiers and profile grouping-heavy slides |

## PPTX lower-layer gaps

The PPTX path already reuses a meaningful shared OOXML substrate, which is a
strong base for H2. The main blockers now come from slide-object depth and
layout signal quality, not from package-open basics.

### Stable enough today

* OOXML package open/read path is shared and reusable
* presentation relationship traversal can recover slide order
* slide relationships are available for external hyperlinks and media
* picture metadata can already read `descr` / `title`
* paragraph text, line breaks, and list-level signals are accessible
* OOXML document properties are available through the shared substrate

### Lower-layer gaps that likely gate H2 quality

* no typed slide layout/master/placeholder model
* shape collection is text-shape-centric and does not expose a richer object
  graph for `graphicFrame`, real tables, charts, or SmartArt
* no explicit group-shape tree model
* no notes-page traversal model
* no comments-part traversal model
* no hidden-slide metadata surface
* hyperlink modeling is limited to external click relationships; internal links,
  hover/action links, and richer shape actions are not surfaced
* origin/provenance does not yet anchor blocks and assets back to shape/run/link
  structures cleanly
* debug/dump surfaces for real-world slide object graphs are still lighter than
  what deeper H2 triage will likely need

### Recommendation

If PPTX H2 work stalls, strengthen the OOXML/PPTX lower layer first:

* preserve slide layout/master/placeholder signals explicitly
* model group shapes and richer slide object graphs
* expose `graphicFrame` / table / chart / SmartArt surfaces
* expose notes/comments/hidden-slide metadata before converter policy work
* extend relationship modeling for internal/action/media link surfaces
* improve debug/dump tools for real-world PPTX triage

Do not try to close these gaps only by piling more layout regex/geometry hacks
into the converter.

## Suggested next actions

* add more real-world dense-layout and image-caption PPTX corpora
* benchmark text-only, table-like, image-heavy, and many-slide decks separately
* add notes/hidden-slide/current-behavior fixtures once the lower layer can hold
  those signals safely
* parse explicit PowerPoint table objects before further table-like heuristic
  tuning
* keep animation/media/slideshow semantics out of scope for now
