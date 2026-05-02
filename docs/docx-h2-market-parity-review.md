# DOCX H2 Market-Parity Review

This document records the current DOCX H2 market-parity review status for
`markitdown-mb`.

It is an audit and planning document. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/docx/docx_parser.mbt`
* body traversal: `convert/docx/docx_document.mbt`
* package open / part reads: `convert/docx/docx_package.mbt`
* styles mapping: `convert/docx/docx_styles.mbt`
* numbering mapping: `convert/docx/docx_numbering.mbt`
* relationships / hyperlink / media lookup: `convert/docx/docx_rels.mbt`
* paragraph / table / image lowering: `convert/docx/docx_table.mbt`
* XML helpers and inline scan: `convert/docx/docx_xml.mbt`
* shared OOXML substrate: `doc_parse/ooxml/*`

### Dispatch and container wiring

* `.docx` is routed through the shared dispatcher
* ZIP entry conversion also routes self-contained `.docx` entries through the
  same parser path

### Metadata / provenance

* metadata format is `docx`
* `source_name` is populated on emitted blocks and assets
* block origins are lightweight and currently carry `block_index` but not
  paragraph/run-level OOXML anchors
* asset origins keep `relationship_id` and normalized media `source_path`
* OOXML document properties are available through the CLI metadata sidecar path

## Current H2 status

### Current strengths

* style-based heading recovery is already present
* ordered / unordered / nested lists are connected to `numbering.xml`
* external hyperlinks in paragraph / heading / list contexts are stable
* basic tables are readable and Markdown-safe
* exported images already preserve alt/title from OOXML drawing fields
* OOXML document-properties metadata is available through the product CLI path
* current hyperlink hot-path profiling already exists for performance triage

### Current policy fixed by regression

* headings are primarily style-driven, with legacy fallback when style mapping
  is missing
* line breaks are emitted as Markdown hard breaks and tabs are preserved as tab
  characters
* lists preserve nesting level when `numbering.xml` resolves successfully
* missing/broken hyperlink relationships degrade to plain text instead of
  failing conversion
* images are exported through OOXML media relationships and asset names are made
  unique under `assets/`
* image captions are not inferred; nearby captions remain out of scope in the
  current DOCX path

### Known H2 limits

* run-level formatting such as bold / italic / code-like spans is not preserved
* internal bookmarks / anchors are not promoted to Markdown links
* footnotes / endnotes are not recovered into reading output
* comments / tracked changes / headers / footers / text boxes are not surfaced
* tables remain legacy `Table` output with no merged-cell reconstruction
* nested tables are not modeled specially
* block provenance is lightweight and does not track OOXML paragraph/run/link
  anchors

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| Style-based headings | Heading recovery is mostly style-driven with heuristic fallback | Reliable heading levels on real-world styled documents | Moderate | Partly | Add messy style corpora and tighten style-model evidence before fallback tweaks |
| Run-level formatting | Text content is preserved, but bold/italic/code-like spans are flattened | Mainstream tools usually preserve common inline emphasis | Moderate | Yes | Expose run properties cleanly before converter-level inline formatting work |
| Hyperlinks | External hyperlinks are stable; broken rels degrade to text | Strong external-link fidelity plus safer internal-link handling | Small | Partly | Keep external path stable and add internal-link coverage before feature work |
| Bookmarks/internal links | Not promoted | Better anchor/bookmark preservation | Moderate | Yes | Surface bookmark/anchor model in lower layer first |
| Numbering and nested lists | Basic ordered/unordered/nested lists work | Better restart/mixed-numbering fidelity on real docs | Moderate | Yes | Strengthen numbering model and add real-world numbering corpora |
| Table merged cells | Simple tables work; merged semantics are flattened | Better merged-cell readability or explicit merged policy | Large | Yes | Parse merged-cell signals before converter reconstruction |
| Nested tables | Tolerated only as flattened cell text | Better explicit degradation or nested-table handling | Moderate | Yes | Expose nested table structure before converter policy changes |
| Images alt/title/descr/caption | Images export; alt/title preserved; caption is not inferred | Better caption association and richer image context | Moderate | Partly | Keep current export path and add explicit caption/non-caption corpora |
| Footnotes/endnotes | Not surfaced | Mainstream tools often recover note text or references | Large | Yes | Add part access and traversal model before Markdown semantics |
| Comments | Ignored | Some tools expose comments or warnings | Moderate | Yes | Expose comments part first; keep non-goal if still deferred |
| Tracked changes | Ignored | Stable include/ignore policy with documentation | Moderate | Yes | Detect revision markup explicitly before any policy work |
| Headers/footers | Ignored | Better optional recovery or explicit policy | Moderate | Yes | Expose header/footer parts before deciding converter semantics |
| Text boxes/drawing text | Ignored | Better fallback for visible drawing text | Large | Yes | Surface drawing/textbox text in lower layer first |
| Document properties | Available in CLI metadata sidecar path | Product-path metadata should stay regression-covered | Small | No | Keep sidecar coverage current and document that this is metadata-only |
| External relationships | External hyperlinks only; no remote fetch | No fetch, but stable unsupported policy for other external rels | Small | Partly | Keep no-fetch policy and document unsupported external object behavior |
| Large document performance | Only one smoke case and one extended link case existed before this pass | Small/medium/large plus list/table/image-heavy visibility | Moderate | Partly | Expand smoke corpus and refresh overlap comparison |
| Origin metadata | Block and asset provenance exist but are lightweight | Richer OOXML anchor provenance | Moderate | Yes | Extend origin model only after lower-layer anchor surfaces exist |

## DOCX lower-layer gaps

The DOCX path already reuses a meaningful shared OOXML substrate, which is a
good base for H2. Most remaining quality gaps now come from document-model
depth rather than from package-open basics.

### Stable enough today

* OOXML package open/read path is shared and reusable
* document order traversal is stable for top-level paragraphs and tables
* relationships are parsed once and reused for hyperlinks/media
* basic styles and numbering access are available
* media extraction is relationship-driven and provenance-aware
* OOXML core/app document properties are available

### Lower-layer gaps that likely gate H2 quality

* style model is still intentionally narrow
* numbering model does not yet cover richer restart/mixed-numbering semantics
* footnotes/endnotes parts are not traversed into reading output
* comments/revisions/header/footer/textbox surfaces are not modeled
* bookmark/internal-anchor model is not exposed
* merged-cell and richer table structure signals are not modeled
* run-property surfaces are not exposed in a form suitable for Markdown
  emphasis decisions
* provenance does not yet anchor blocks/runs/images back to richer OOXML
  structure
* lower-layer dump/debug surfaces are still lighter than what full DOCX H2
  triage will likely need

### Recommendation

If DOCX H2 work stalls, strengthen the OOXML/DOCX lower layer first:

* preserve richer style and numbering signals
* expose bookmark/internal-link anchors
* expose footnotes/endnotes/comments/header/footer/textbox parts
* model merged-cell and richer table structure
* expose run properties before attempting inline Markdown fidelity work
* improve debug/dump tools for real-world DOCX triage

Do not try to close these gaps only by piling converter-local string rules onto
the current paragraph/table scan.
