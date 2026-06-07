# PPTX Architecture v2

Status: design contract draft

PPTX v2 is the target architecture for replacing the current PPTX runtime. The current PPTX implementation has already proven many useful product behaviors, but its parser/converter boundary is not clean enough for a mature long-term conversion product. PPTX v2 adopts a clearer pipeline:

```text
OOXML package
 -> PPTX part graph
 -> PPTX source facts
 -> normalized presentation model
 -> bounded layout / reading-order hints
 -> convert lowering
 -> core Document / Markdown / assets / metadata
```

The central rule is: **parse presentation package data once, build a PPTX-native typed source/model, then lower that model to core IR without runtime legacy fallback or convert-layer raw XML scanning.**

PPTX differs from DOCX because it is a canvas-oriented format. Its runtime architecture must account for slide geometry, placeholder inheritance, slide layout/master relationships, grouped shapes, reading order, notes, comments, media, and layout-sensitive heuristics. PPTX v2 therefore requires not only source/model/lowering separation, but also a first-class resolved layout/placeholder/reading-order hint layer inside the normalized model.

---

## Problem Statement

The current PPTX path has several architecture risks:

* `convert/pptx` directly reads and scans raw OOXML XML such as `ppt/presentation.xml`, slide XML, notes XML, comments XML, relationships, tables, text, media, and shapes.
* `doc_parse/pptx` and `convert/pptx` duplicate some parsing work. A presentation can be parsed once for inventory/chart bridge and then scanned again by the converter for normal output.
* Converter helpers repeatedly scan the same slide XML for text, images, tables, hyperlinks, reading order, shape collection, and asset export.
* Product policy, XML parsing, shape classification, asset export, reading-order heuristics, fallback behavior, and metadata/origin construction are mixed in the normal conversion path.
* Layout/master inheritance is not represented as a stable model fact. Placeholder and style behavior are mostly direct-shape or heuristic based.
* Unsupported objects such as SmartArt, OLE, connectors, unknown graphic frames, decorative shapes, or complex media can be silently dropped or represented inconsistently.
* Fallback and legacy collector names appear in normal PPTX runtime code paths. Even when useful during migration, they should not remain architecture primitives.
* Performance risk grows with slide count, shape count, group depth, table density, and repeated relationship/media lookup.

PPTX v2 should remove these risks by making source/model boundaries carry the facts that the converter currently tries to rediscover.

---

## Lessons Learned From DOCX v2

Keep:

* OOXML package cache for part-local bytes/text reuse.
* Relationship indexes keyed by source part.
* Content-type and part inventory as format-neutral package metadata.
* Source order as a first-class contract.
* Typed source/model facts for hyperlinks, media, tables, notes, comments, placeholders, fields, unknown constructs, and unsupported structures.
* Explicit warnings instead of hidden fallback.
* Bounded guards for pathological inputs.
* Legacy/oracle/parity comparison only as test or migration evidence, never runtime behavior.
* Output policies such as heading/list/table/image/appendix behavior in convert lowering, not parser/source.

Avoid:

* Runtime legacy oracle or fallback.
* Duplicated source parsing in parser and converter.
* Convert-owned raw XML scans.
* Counters or fallback signals as architecture.
* Parser-emitted Markdown, core IR, asset paths, origins, appendix placement, or RichTable policy.
* Silent drop of meaningful unsupported PPTX structures.
* Full PowerPoint renderer ambitions in a lightweight Markdown converter.

---

## Architecture Layers

### A. `doc_parse/ooxml` Package Layer

Responsibilities:

* Open and own OOXML ZIP package lifecycle.
* Normalize package part paths.
* Read package part bytes/text with per-package cache.
* Parse content types.
* Parse and index relationships.
* Expose document properties and part inventory.
* Serve reusable package queries for DOCX, PPTX, XLSX, and future OOXML formats.

Non-responsibilities:

* PresentationML semantics.
* Slide, shape, placeholder, layout, media, or notes interpretation.
* Markdown, core IR, asset export, or origin policy.

Inputs:

* PPTX bytes or an already-open ZIP/package abstraction.

Outputs:

* `OoxmlPackage`.
* Relationship queries.
* Content-type lookup.
* Part bytes/text.
* Package inventory and document properties.

Example APIs:

```moonbit
pub struct OoxmlPackage
pub struct OoxmlRelationship
pub struct OoxmlPartInfo
pub struct OoxmlContentTypeInfo

pub fn open_ooxml_package(bytes : Bytes) -> OoxmlPackage raise OoxmlError
pub fn read_part_text(pkg : OoxmlPackage, part : String) -> String raise OoxmlError
pub fn read_part_bytes(pkg : OoxmlPackage, part : String) -> Bytes raise OoxmlError
pub fn find_relationship_by_id(
  pkg : OoxmlPackage,
  source_part : String,
  rel_id : String,
) -> OoxmlRelationship? raise OoxmlError
pub fn list_part_infos(pkg : OoxmlPackage) -> Array[OoxmlPartInfo]
```

---

### B. `doc_parse/pptx/source` Source Layer

Responsibilities:

* Parse PresentationML parts into typed source records.
* Parse each relevant OOXML part at most once.
* Preserve source part path, source order, stable source key, and source span/key for every represented node.
* Build a typed PPTX part graph.
* Preserve slide order from `presentation.xml` / `sldIdLst`.
* Represent slides, shapes, groups, text boxes, paragraphs, runs, tables, pictures, graphic frames, notes, comments, charts, connectors, placeholders, geometry, hyperlinks, and unknown structures as typed source facts.
* Preserve raw tag/kind metadata when useful, without exposing unstable raw XML everywhere.
* Preserve unknown or unsupported PresentationML as typed unsupported/source-preserved nodes.
* Emit source diagnostics for malformed XML, broken relationships, missing parts, excessive depth, excessive shape count, unsupported media, and unsupported object types.

Non-responsibilities:

* Markdown or core IR.
* Asset export or asset path naming.
* Reading-order product policy.
* Heading/list/table rendering.
* Notes/comments placement.
* Layout/master inheritance resolution policy.
* Full PowerPoint rendering.
* Fallback decisions.
* Legacy oracle comparisons.

Inputs:

* `OoxmlPackage`.
* Part graph roots such as `ppt/presentation.xml`.
* Relationship and content-type queries from the package layer.

Outputs:

* `PptxSourceDocument`.
* `PptxPartGraph`.
* Typed source parts and source nodes.
* Source diagnostics.

Example types/APIs:

```moonbit
pub struct PptxSourceDocument
pub struct PptxSourcePart
pub struct PptxPartGraph
pub enum PptxSourceNode
pub struct PptxSourceSpan
pub struct PptxSourceKey

pub fn parse_pptx_source(
  pkg : @ooxml.OoxmlPackage
) -> PptxSourceDocument raise PptxError

pub fn list_pptx_source_parts(
  doc : PptxSourceDocument
) -> Array[PptxSourcePart]

pub fn pptx_source_slides(
  doc : PptxSourceDocument
) -> Array[PptxSourceSlide]
```

---

### C. `doc_parse/pptx/model` Normalized Model Layer

Responsibilities:

* Build a PPTX semantic input model for conversion.
* Normalize source facts into slides, shapes, groups, paragraphs, runs, inlines, tables, pictures, media refs, notes, comments, charts, and unsupported objects.
* Resolve relationships, content types, media targets, slide refs, notes-slide ownership, comment ownership, layout refs, master refs, and theme refs into stable model facts.
* Resolve direct placeholder information.
* Resolve layout/master placeholder inheritance where available.
* Produce bounded reading-order and layout hints.
* Produce geometry, grouping, and region hints.
* Preserve source spans and source keys so convert can attach origins without scanning XML.
* Preserve unsupported features as structured warnings.
* Represent broken rels, missing targets, unsupported media, SmartArt, OLE, unknown graphic frames, and skipped structures explicitly.

Non-responsibilities:

* Markdown-facing rendering choices.
* Final asset export paths.
* File copies.
* Notes/comments appendix policy.
* Slide separator policy.
* RichTable/table Markdown behavior.
* Product heading/list/caption heuristics.
* Legacy fallback.

Inputs:

* `PptxSourceDocument`.
* Package, relationship, content-type, media, layout, master, and theme query services.

Outputs:

* `PptxDocument`.
* `Array[PptxWarning]`.

Example types/APIs:

```moonbit
pub struct PptxDocument
pub struct PptxPresentation
pub struct PptxSlide
pub enum PptxObject
pub struct PptxShape
pub struct PptxParagraph
pub struct PptxRun
pub enum PptxInline
pub struct PptxMediaRef
pub struct PptxTable
pub struct PptxWarning

pub fn normalize_pptx_source(
  source : PptxSourceDocument,
  queries : PptxModelQueries,
) -> PptxDocument

pub fn parse_pptx_document_from_package(
  pkg : @ooxml.OoxmlPackage
) -> PptxDocument raise PptxError
```

---

### D. Resolved Layout / Placeholder / Reading-Order Hint Layer

This layer is part of the normalized model, not convert lowering.

PPTX is canvas-based, so source order alone is insufficient. PPTX v2 must represent layout-related interpretation as typed, bounded hints rather than ad-hoc converter heuristics.

Responsibilities:

* Resolve slide shape placeholders from direct slide facts.
* Resolve layout/master placeholder inheritance when available.
* Resolve limited text/list style hints needed for Markdown conversion.
* Compute bounded geometry hints for shapes and groups.
* Compute reading-order hints from placeholder priority, geometry, source order, grouping, and known object types.
* Compute layout region hints such as title, subtitle, body, two-column, table-like, grid-like, card-like, caption-like, note-like, footer-like, decorative, and unknown.
* Record confidence and reason for inferred layout facts.
* Record inheritance trace for placeholder/style decisions.
* Bound matching/clustering complexity.

Non-responsibilities:

* Full PowerPoint layout rendering.
* Animation/transition behavior.
* Pixel-perfect positioning.
* Text wrapping or font metrics.
* Full theme cascade fidelity.
* Markdown rendering.

Example types:

```moonbit
pub struct PptxResolvedPlaceholderHint {
  kind : PptxPlaceholderKind
  index : Int?
  source : PptxPlaceholderResolutionSource
  confidence : PptxConfidence
  trace : Array[PptxSourceKey]
}

pub struct PptxResolvedTextStyleHint {
  paragraph_style : String?
  run_style : String?
  level : Int?
  bullet : PptxBulletHint?
  numbering : PptxNumberingHint?
  source : PptxStyleResolutionSource
  confidence : PptxConfidence
}

pub struct PptxReadingOrderHint {
  bucket : PptxReadingBucket
  priority : Int
  order_key : String
  confidence : PptxConfidence
  reason : String
}

pub struct PptxGeometry {
  x : Int?
  y : Int?
  width : Int?
  height : Int?
  rotation : Int?
}

pub struct PptxLayoutRegionHint {
  kind : PptxLayoutRegionKind
  members : Array[PptxSourceKey]
  confidence : PptxConfidence
  reason : String
}
```

Resolution priority:

1. Direct slide placeholder facts.
2. Placeholder `(type, idx)` match against slide layout.
3. Placeholder `(type, idx)` match against slide master.
4. Placeholder type-only match.
5. Geometry/name inference with lower confidence.
6. Unknown placeholder with warning if needed.

Convert lowering consumes these hints. It does not re-run layout/master XML scans.

---

### E. `convert/pptx` Lowering Layer

Responsibilities:

* Lower `PptxDocument` to core IR.
* Own Markdown-facing product policy.
* Own slide separator policy.
* Own heading/title/subtitle/body lowering.
* Own list and bullet Markdown policy.
* Own table / RichTable behavior.
* Own image block / inline image behavior.
* Own notes/comments placement.
* Own caption-like / note-like / table-like lowering choices.
* Own asset export, deterministic asset path naming, metadata, and origins.
* Surface unsupported feature warnings in product-facing form.
* Make quality-driven product decisions where exact PowerPoint behavior is unavailable or not desirable.

Non-responsibilities:

* Directly scanning raw PresentationML XML.
* Reading `ppt/slides/*.xml`, `ppt/presentation.xml`, notes XML, comments XML, layouts, masters, or rels at runtime.
* Parsing relationships, media, layout, master, or theme XML.
* Rebuilding parser source facts.
* Calling legacy scanner fallback.
* Running oracle comparison during normal conversion.
* Performing full PowerPoint rendering.

Inputs:

* `PptxDocument`.
* Conversion options and output directory.

Outputs:

* Core `Document`.
* Exported assets.
* Asset metadata.
* Block metadata.
* Origins.
* Product-facing warnings.

Example APIs:

```moonbit
pub fn parse_pptx(
  path : String,
  out_root : String,
  max_heading : Int,
) -> @core.Document raise

fn lower_pptx_document(
  doc : @pptx_model.PptxDocument,
  options : PptxLoweringOptions,
) -> @core.Document raise
```

---

### F. Historical Oracle / Migration Evidence Layer

Responsibilities:

* Preserve historical diffs, compatibility notes, quality triage, and migration evidence in docs or archives.
* Support test-only comparison during migration.
* Explain why runtime fallback is forbidden.

Non-responsibilities:

* Normal conversion.
* Runtime fallback.
* Production counters.
* New feature implementation.

Any legacy PPTX scanner, collector, or fallback behavior must either be deleted, moved behind test-only helpers, or re-expressed as source/model facts. No normal runtime path may depend on a legacy converter oracle.

---

## Package Layer Details

The OOXML package layer owns:

* ZIP/package lifecycle.
* Part path normalization.
* Part bytes/text cache.
* Content types.
* Relationships and relationship indexes.
* Document properties.
* Part inventory.

It must not know about PresentationML slide semantics, layout inheritance, shapes, text, tables, media export, Markdown, IR, origins, or reading-order policy.

---

## Source Layer Details

The source layer parses PPTX-specific PresentationML parts into stable source representation.

Source facts should preserve:

* Source part path.
* Source order.
* Stable source key.
* Source span or node key.
* Raw tag/node kind where useful.
* Relationship ids.
* Geometry raw values.
* Placeholder raw values.
* Typed known nodes.
* Typed unknown / unsupported nodes.

Represented source nodes include:

* Presentation.
* Slide reference.
* Slide.
* Slide layout.
* Slide master.
* Theme reference.
* Shape.
* Group shape.
* Text box.
* Shape text body.
* Paragraph.
* Run.
* Text.
* Break.
* Field.
* Bullet properties.
* Numbering properties.
* Hyperlink.
* Picture.
* Media reference.
* Table.
* Table row.
* Table cell.
* Graphic frame.
* Chart reference.
* SmartArt reference.
* OLE reference.
* Connector.
* Notes slide.
* Comment.
* Comment author.
* Unknown object.
* Unsupported object.

The source layer does not decide Markdown behavior. Unsupported and unknown PPTX source remains source. It becomes a warning only after normalization decides semantic support and product consequences.

---

## Normalized Model Details

`PptxDocument` is the semantic input for conversion. It is not Markdown and not core IR.

The model should include:

* Document source info.
* Document metadata.
* Part graph.
* Presentation info.
* Ordered slides.
* Slide part refs.
* Slide hidden status.
* Slide size.
* Slide relationships.
* Slide layout refs.
* Slide master refs.
* Theme refs.
* Shape tree.
* Group shapes.
* Text boxes.
* Paragraphs, runs, and inlines.
* Tables, rows, and cells.
* Pictures and media refs.
* Hyperlinks.
* Notes slides.
* Comments.
* Comment authors.
* Charts and cached chart refs.
* SmartArt refs.
* OLE refs.
* Connectors.
* Unsupported objects.
* Geometry facts.
* Placeholder facts.
* Resolved placeholder hints.
* Resolved text/list style hints.
* Reading-order hints.
* Layout-region hints.
* Warnings.
* Source spans / source keys / origin ids.

Warnings replace hidden fallback as the way the parser/model says: “this source exists, but PPTX v2 does not fully support it.”

---

## Convert Lowering Details

`convert/pptx` consumes only `PptxDocument` and conversion options.

It owns:

* Slide order output policy.
* Slide separator policy.
* Title/subtitle/body heading policy.
* Paragraph lowering.
* Bullet/list Markdown policy.
* RichTable/table lowering.
* ImageBlock / image placeholder policy.
* Caption-like / note-like / table-like region lowering.
* Speaker notes and comments placement.
* Chart fallback presentation.
* Unsupported warning presentation.
* Asset export and path naming.
* Metadata sidecars.
* Origin attachment.

It must not:

* Read raw XML.
* Parse relationships.
* Re-open package parts for structure.
* Re-scan slide XML.
* Call legacy collectors.
* Use runtime fallback or oracle comparison.

If lowering needs a fact, that fact belongs in `PptxDocument` or a narrower model service.

---

## Reading Order Policy

PPTX v2 does not promise pixel-perfect PowerPoint rendering. It promises stable, bounded, explainable reading order suitable for Markdown/IR conversion.

Reading order inputs:

* Slide source order.
* Shape source order.
* Z-order/source index.
* Placeholder kind.
* Placeholder inheritance.
* Shape geometry.
* Group hierarchy.
* Shape type.
* Text density.
* Image/table/caption proximity.
* Layout-region hints.
* Notes/comments association.

Reading order outputs:

* Stable object order.
* Confidence.
* Reason.
* Optional layout-region grouping.

Recommended bucket priority:

1. Slide title.
2. Subtitle.
3. Main body.
4. Explicit tables.
5. Images and captions.
6. Table-like / grid-like grouped regions.
7. Notes-like callouts.
8. Footer/date/slide number.
9. Decorative objects.
10. Unsupported/unknown objects with warnings.

This policy should be implemented through model hints, not convert-stage XML scanning.

---

## Layout / Master Inheritance Policy

PPTX v2 should support bounded placeholder/style inheritance sufficient for Markdown conversion.

Supported inheritance targets:

* Placeholder kind.
* Placeholder index.
* Title/subtitle/body/footer/date/slide-number classification.
* Basic text/list style hints.
* Basic geometry fallback.
* Layout/master relationship trace.

Non-goals:

* Full theme rendering.
* Exact font metrics.
* Exact text wrapping.
* Exact PowerPoint visual layout.
* Animation/transition semantics.

If inheritance is incomplete or ambiguous, the model should record a lower-confidence hint and warning where appropriate. Convert should use the hint conservatively.

---

## Media And Asset Policy

PPTX v2 media model should represent:

* Relationship id.
* Source part.
* Target part.
* Target mode.
* Content type.
* Original extension.
* Resolved extension.
* Alt text.
* Title.
* Geometry.
* Owning slide.
* Owning shape.
* Duplicate target identity.
* Alternate media, such as SVG plus raster fallback.
* External linked media status.
* Unsupported media status.

Convert owns final asset export.

Recommended current policy:

* Export internal raster media.
* Export SVG companion media when explicitly represented.
* Deduplicate deterministic asset paths where product policy requires it.
* Preserve external media as placeholder/warning unless fetching is explicitly supported.
* Preserve unsupported media such as WMF/EMF/PICT as warning/placeholder unless raw-export policy is adopted.
* Do not silently drop media relationships.

---

## Tables

PPTX v2 should support explicit `a:tbl` tables as typed tables.

Table model should include:

* Rows.
* Cells.
* Cell paragraphs.
* Cell text runs.
* Grid span / row span if available.
* Merge/empty-cell hints.
* Cell geometry if available.
* Table style hints.
* Source key.
* Owning slide/shape.

Convert owns Markdown/RichTable output.

Table-like shape clusters are not source tables. They should be represented as layout-region hints:

```text
PptxLayoutRegionHint::TableLike
```

Convert may choose to render them as paragraphs, lists, tables, or conservative grouped blocks based on confidence.

---

## Notes And Comments

PPTX v2 should represent:

* Notes slide ownership.
* Speaker notes text.
* Notes shape tree.
* Comments.
* Comment authors.
* Comment slide association.
* Comment anchor/position if available.
* Broken or missing comment author warnings.

Convert owns:

* Whether notes appear under each slide.
* Whether comments appear before or after speaker notes.
* Markdown section headings for notes/comments.
* Deduplication and ordering policy.

---

## Charts, SmartArt, OLE, And Unknown Graphic Frames

PPTX v2 should not silently drop graphic frames.

Represent:

* Chart refs.
* Cached chart data if available.
* Chart image fallback if available.
* SmartArt refs as unsupported typed objects.
* OLE refs as unsupported typed objects.
* Unknown graphic frames as unsupported typed objects.
* Warnings with source keys and owning slide.

Non-goals for MVP:

* Full chart rendering.
* Embedded workbook evaluation.
* SmartArt rendering.
* OLE extraction/rendering.
* Video/audio playback.

Convert may produce conservative placeholders and warnings.

---

## Shapes, Groups, And Connectors

PPTX v2 should preserve:

* Auto shapes with text.
* Text boxes.
* Pictures.
* Group shapes and child hierarchy.
* Connectors.
* Decorative shapes.
* Shape geometry.
* Shape name/id.
* Shape type.
* Hidden status if available.

Group traversal must be bounded. Grouped shapes may be flattened for output only after model-level reading-order hints preserve group source keys and geometry.

Decorative or connector shapes without meaningful text/media may be omitted from visible Markdown only if the model records enough facts to justify omission. Meaningful unknown shapes should emit warnings.

---

## Performance Guards

PPTX v2 must protect the normal runtime from pathological decks.

Suggested guards:

* Maximum slide count warning threshold.
* Maximum shapes per slide.
* Maximum group depth.
* Maximum child shapes per group.
* Maximum table cells.
* Maximum table text runs.
* Maximum notes/comments per slide.
* Maximum relationships per part.
* Maximum media exports per deck.
* Maximum layout/master matching candidates.
* Maximum geometry clustering comparisons.
* Maximum total source nodes.

Performance rules:

* Open package once.
* Parse each XML part once.
* Cache part bytes/text.
* Build relationship/content-type indexes.
* Resolve slide/layout/master relationships once.
* Resolve media refs once.
* Compute geometry and reading-order hints once.
* Avoid repeated string slicing in XML scanning.
* Avoid repeated full-tree traversal in metadata/origin construction.
* Convert must not rescan XML.

Pathological or over-budget content should produce bounded placeholders and explicit warnings, not timeouts or silent empty output.

---

## MVP Scope

PPTX v2 MVP includes:

* Open package once.
* Part graph.
* Presentation slide order.
* Slide source records.
* Shape tree.
* Text boxes.
* Paragraphs, runs, text, breaks.
* Basic bullets and levels.
* Direct placeholders.
* Limited layout/master placeholder inheritance.
* Geometry facts.
* Reading-order hints.
* Groups.
* Embedded raster images.
* External media warnings.
* Hyperlinks.
* Explicit tables.
* Speaker notes.
* Comments.
* Cached chart refs or chart placeholders.
* SmartArt/OLE/unknown graphic frame warnings.
* Source keys and source spans.
* Asset export through convert.
* Metadata/origin through convert.
* No runtime legacy fallback.

MVP does not include:

* Full PowerPoint renderer.
* Animation or transition lowering.
* Full theme cascade.
* Exact font metrics.
* Exact text wrapping.
* Embedded workbook evaluation.
* SmartArt rendering.
* OLE rendering.
* Remote media fetching.
* Video/audio playback.
* Pixel-perfect slide layout.

---

## Capability Roadmap

* PPTX-M0: package/part graph skeleton.
* PPTX-M1: presentation and slide order.
* PPTX-M2: slide source shape tree.
* PPTX-M3: text boxes, paragraphs, runs, inlines.
* PPTX-M4: direct placeholders and geometry facts.
* PPTX-M5: layout/master placeholder resolution hints.
* PPTX-M6: reading-order hints and bounded layout regions.
* PPTX-M7: bullets, numbering, and list hints.
* PPTX-M8: images/media refs and asset export.
* PPTX-M9: explicit tables.
* PPTX-M10: notes and comments.
* PPTX-M11: charts, SmartArt, OLE, and unsupported graphic frames.
* PPTX-M12: groups/connectors/decorative object policy.
* PPTX-M13: quality/bench replacement readiness.
* PPTX-M14: old runtime removal.

---

## API Sketch

This is pseudo MoonBit. It is a contract sketch, not compile-ready code.

```moonbit
pub struct PptxSourceKey {
  part_name : String
  node_key : String
}

pub struct PptxSourceSpan {
  part_name : String
  node_key : String
  start_offset : Int?
  end_offset : Int?
}

pub struct PptxSourceDocument {
  package_id : String?
  part_graph : PptxPartGraph
  presentation : PptxSourcePresentation
  slides : Array[PptxSourceSlide]
  layouts : Array[PptxSourceLayout]
  masters : Array[PptxSourceMaster]
  notes : Array[PptxSourceNotesSlide]
  comments : Array[PptxSourceComment]
  warnings : Array[PptxWarning]
}

pub struct PptxDocument {
  source_info : PptxDocumentSourceInfo
  metadata : PptxDocumentMetadata
  part_graph : PptxPartGraph
  presentation : PptxPresentation
  slides : Array[PptxSlide]
  notes : Array[PptxNotesSlide]
  comments : Array[PptxComment]
  media : Array[PptxMediaRef]
  warnings : Array[PptxWarning]
}

pub struct PptxSlide {
  slide_id : String
  slide_index : Int
  part_name : String
  layout_ref : PptxLayoutRef?
  master_ref : PptxMasterRef?
  hidden : Bool
  size : PptxSlideSize?
  objects : Array[PptxObject]
  reading_order : Array[PptxSourceKey]
  warnings : Array[PptxWarning]
  source_key : PptxSourceKey
}

pub enum PptxObject {
  Shape(PptxShape)
  Group(PptxGroupShape)
  Picture(PptxPicture)
  Table(PptxTable)
  Chart(PptxChartRef)
  SmartArt(PptxSmartArtRef)
  Ole(PptxOleRef)
  Connector(PptxConnector)
  Unsupported(PptxUnsupported)
}

pub struct PptxShape {
  shape_id : String?
  name : String?
  shape_type : String?
  geometry : PptxGeometry?
  placeholder : PptxResolvedPlaceholderHint?
  text_body : PptxTextBody?
  media : PptxMediaRef?
  hyperlinks : Array[PptxHyperlink]
  reading_order : PptxReadingOrderHint?
  source_key : PptxSourceKey
}

pub struct PptxTextBody {
  paragraphs : Array[PptxParagraph]
  source_key : PptxSourceKey
}

pub struct PptxParagraph {
  level : Int?
  list_hint : PptxResolvedListStyleHint?
  style_hint : PptxResolvedTextStyleHint?
  runs : Array[PptxRun]
  source_key : PptxSourceKey
}

pub struct PptxRun {
  inlines : Array[PptxInline]
  style_hint : PptxResolvedTextStyleHint?
  source_key : PptxSourceKey
}

pub enum PptxInline {
  Text(String, PptxSourceSpan)
  Break(PptxSourceSpan)
  Field(PptxField)
  Hyperlink(PptxHyperlink)
  Unsupported(PptxUnsupported)
}

pub struct PptxPicture {
  media : PptxMediaRef
  geometry : PptxGeometry?
  alt_text : String?
  title : String?
  reading_order : PptxReadingOrderHint?
  source_key : PptxSourceKey
}

pub struct PptxMediaRef {
  relationship_id : String?
  source_part : String
  target : String?
  resolved_target : String?
  target_mode : PptxTargetMode?
  content_type : String?
  original_extension : String?
  resolved_extension : String?
  alt_text : String?
  title : String?
  alternate_media : Array[PptxMediaRef]
  source_key : PptxSourceKey
}

pub struct PptxTable {
  rows : Array[PptxTableRow]
  geometry : PptxGeometry?
  source_key : PptxSourceKey
}

pub struct PptxTableCell {
  paragraphs : Array[PptxParagraph]
  grid_span : Int?
  row_span : Int?
  merge_hint : PptxTableMergeHint?
  source_key : PptxSourceKey
}

pub struct PptxWarning {
  kind : PptxWarningKind
  severity : PptxWarningSeverity
  message : String
  source_span : PptxSourceSpan?
}
```

---

## Test Strategy

Use tests to replace runtime fallback behavior:

* Source snapshot tests.
* Part graph tests.
* Slide order tests.
* Shape tree tests.
* Placeholder inheritance tests.
* Layout/master resolution tests.
* Reading-order hint tests.
* Geometry-region hint tests.
* Media relationship tests.
* Asset export tests.
* Notes/comments tests.
* Table tests.
* Unsupported graphic frame tests.
* Performance guard tests.
* Quality-lab integration.
* Test-only parity/migration comparisons where useful.

Regression examples:

* Slide order from `sldIdLst`.
* Missing slide relationship.
* Hidden slide.
* Title/subtitle placeholder.
* Layout/master placeholder inheritance.
* Grouped text boxes.
* Two-column layout.
* Image + caption layout.
* Explicit table.
* Table-like shape cluster.
* Speaker notes.
* Comments.
* Hyperlinks.
* Internal slide links.
* Broken relationship warnings.
* SVG/raster media.
* SmartArt placeholder.
* OLE placeholder.
* Deep group nesting.
* Large shape count.
* Duplicate media target.

---

## Acceptance Criteria

PPTX v2 can replace the current runtime only when:

* Normal conversion has no runtime legacy fallback.
* Convert does not scan raw PresentationML XML.
* Each supported source part is parsed once into typed source/model facts.
* All supported objects are represented in `PptxDocument`.
* Unsupported objects produce warnings instead of silent drops.
* Main PPTX samples pass or intentional changes are documented.
* PPTX quality rows pass or are deliberately updated for documented v2 policy.
* Performance is no worse on large/complex decks.
* Bench convert and CLI layers can run for PPTX.
* Asset export and metadata sidecars remain stable.
* Documentation accurately states limits.

---

## Open Questions

* How much layout/master placeholder inheritance should be resolved in MVP?
* How much theme/style cascade belongs in the model?
* Whether table-like shape clusters should ever become RichTable.
* Whether SVG companion media should be exported by default for PPTX.
* Whether WMF/EMF/PICT should be raw-exported, converted, or warning-only.
* How to represent chart cached data without implementing full chart rendering.
* Whether internal slide hyperlinks should become anchors, relative links, or warnings.
* How to represent animation/transition metadata, if at all.
* How to keep reading-order heuristics stable across complex layouts.
* Source span granularity for shape tree nodes.
* Asset naming stability across relationship order, media target reuse, and content type.

---

## Next Steps

PPTX-RESET-1 should create the v2 skeleton without changing dispatcher behavior.

Recommended first implementation slice:

1. Add `doc_parse/pptx_v2` or equivalent experimental package.
2. Implement part graph and presentation slide order.
3. Parse slides into typed source shape tree.
4. Preserve source keys, part names, rel ids, shape ids, geometry, placeholders, and warnings.
5. Add source/model tests.
6. Do not connect dispatcher.
7. Do not modify current PPTX expected files.
8. Do not delete current PPTX runtime.
9. Do not add fallback/oracle to normal conversion.
10. Do not let convert scan raw XML in the v2 path.

Implementation should proceed by bounded typed model slices, not by porting the old converter wholesale.
