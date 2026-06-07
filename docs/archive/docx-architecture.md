# DOCX Architecture v2

Status: adopted runtime architecture

DOCX is the normal DOCX runtime. It uses a clearer pipeline boundary:
parse package data once, build a DOCX-native source and normalized model, then
lower that model to core IR without runtime legacy scanner fallback.

## Runtime Adoption Record

DOCX became the normal DOCX runtime in commit `8ed4a3b`
(`docx: permanently switch DOCX runtime to v2, delete old v1 runtime, update
package deps/tests/docs`). The old `doc_parse/docx` and `convert/docx`
runtime directories were removed, and dispatcher, CLI, ZIP, bench, metadata
tests, and docs now route DOCX through `convert/docx`.

Replacement validation at adoption:

* `moon check`: pass.
* `moon test`: 1866 / 1866 pass.
* `bash samples/check.sh`: 448 / 448 markdown, 85 / 85 metadata, 90 / 90
  assets.
* `bash samples/check.sh --format docx`: 61 / 61 markdown, 10 / 10 metadata,
  9 / 9 assets.
* `bash samples/check_quality.sh`: 306 rows, 0 failed, 1 skipped.
* `bash samples/check_quality.sh --format docx`: 60 rows, 0 failed, 0
  skipped, 0 expected_fail.

Post-removal guard tests keep the normal runtime from reintroducing
`doc_parse/docx`, `convert/docx`, or package routes to the old converter.

## Problem Statement

The old DOCX path proved many useful ideas, but it had mixed responsibilities:

* `doc_parse/docx` was a mixed layer: source facts, partial semantic model, and
  OOXML-backed wrapper usage live together.
* `convert/docx` directly scanned WordprocessingML XML while also owning
  output policy, assets, origins, profile reporting, and compatibility quirks.
* Runtime conversion contained legacy oracle / fallback / counter glue. Parser
  candidates were compared against legacy scanner output during normal
  conversion.
* Parser facts have started to chase legacy quirks, which means every feature
  tends to add its own facts, oracle comparison, fallback branches, and debt
  counters.
* Profile and debug logic can leak into the normal conversion path unless each
  feature is carefully guarded.

DOCX removes the need for runtime double-scanning and makes model boundaries
do the work that counters and fallback signals previously tried to do.

## Lessons Learned from DOCX-3

Keep:

* `OoxmlPackage` cache for package-local bytes/text reuse.
* Relationship indexes keyed by package root or source part.
* Content-type and part inventory as format-neutral package metadata.
* Style, numbering, and media query context as reusable model services.
* Source order / body block stream as a first-class contract.
* Typed inline inventory for hyperlinks, note refs, media, fields, math,
  bookmarks, breaks, symbols, tracked changes, and unknown constructs.
* Deep-table guard and bounded source summaries.
* Codeblock regression lesson: paragraph style and text heuristics are output
  policy and need explicit tests.
* Oracle comparison as a test-only migration tool.

Avoid:

* Runtime legacy oracle in normal conversion.
* Duplicated source parsing in parser and converter.
* Convert-owned raw XML scans for WordprocessingML structure.
* Counters as architecture or as a substitute for a clear model.
* `fallback_signal` as a broad public parser API.
* Parser-emitted product policy such as Markdown, asset paths, origin policy,
  appendix placement, or RichTable rendering choices.

## Architecture Layers

### A. `doc_parse/ooxml` Package Layer

Responsibilities:

* Open and own OOXML ZIP package lifecycle.
* Normalize package part paths.
* Read package part bytes/text with per-package cache.
* Parse content types.
* Parse and index relationships.
* Expose document properties and part inventory.

Non-responsibilities:

* WordprocessingML semantics.
* DOCX paragraph/table/header/note interpretation.
* Markdown, core IR, asset export, or origin policy.

Inputs:

* DOCX bytes or an already-open ZIP archive abstraction.

Outputs:

* `OoxmlPackage`, part reads, relationship queries, content-type lookup,
  inventory and property records.

Example types/APIs:

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

### B. `doc_parse/docx` Source Layer

Responsibilities:

* Parse WordprocessingML parts into source tree/events/records.
* Preserve source order within body, table cells, notes, comments, headers,
  footers, and textboxes.
* Preserve source part path and source span/key for every represented node.
* Represent paragraphs, runs, tables, rows, cells, notes, comments, headers,
  footers, textboxes, drawings, fields, math, bookmarks, tracked changes, and
  unknown nodes as typed source nodes.
* Preserve unknown WordprocessingML as typed unknown/source-preserved nodes.

Non-responsibilities:

* Markdown or core IR.
* Asset export or asset path naming.
* Heading/list/code/blockquote policy.
* Fallback decisions.
* Compatibility oracle comparisons.

Inputs:

* `OoxmlPackage`.
* Part graph roots such as `word/document.xml`.
* Relationship queries from the package layer.

Outputs:

* `DocxSourceDocument` containing source parts and source nodes.
* Source diagnostics for malformed or unsupported source constructs.

Example types/APIs:

```moonbit
pub struct DocxSourceDocument
pub struct DocxSourcePart
pub enum DocxSourceNode
pub struct DocxSourceSpan

pub fn parse_docx_source(pkg : @ooxml.OoxmlPackage) -> DocxSourceDocument raise DocxError
pub fn list_docx_source_parts(doc : DocxSourceDocument) -> Array[DocxSourcePart]
pub fn docx_source_body_nodes(doc : DocxSourceDocument) -> Array[DocxSourceNode]
```

### C. `doc_parse/docx` Normalized Model Layer

Responsibilities:

* Build a DOCX semantic input model for conversion.
* Normalize source nodes into blocks, paragraphs, runs, inlines, tables, notes,
  comments, headers, footers, textboxes, and media references.
* Resolve relationships and may resolve style, numbering, and media references
  into stable model metadata.
* Preserve source spans and origin ids so convert can attach origins without
  scanning XML.
* Preserve unsupported features as structured warnings.

Non-responsibilities:

* Markdown-facing rendering choices.
* Asset export paths or file copies.
* Header/footer/textbox placement policy.
* Codeblock, heading, list, blockquote, or RichTable heuristics.
* Legacy fallback.

Inputs:

* `DocxSourceDocument`.
* Style, numbering, relationship, media, and content-type query services.

Outputs:

* `DocxDocument`.
* `Array[DocxWarning]`.

Example types/APIs:

```moonbit
pub struct DocxDocument
pub enum DocxBlock
pub struct DocxParagraph
pub enum DocxInline
pub struct DocxTable
pub struct DocxMediaRef
pub struct DocxWarning

pub fn normalize_docx_source(
  source : DocxSourceDocument,
  queries : DocxModelQueries,
) -> DocxDocument
pub fn parse_docx_document_from_package(pkg : @ooxml.OoxmlPackage) -> DocxDocument raise DocxError
```

### D. `convert/docx` Lowering Layer

Responsibilities:

* Lower `DocxDocument` to core IR.
* Own Markdown-facing policy.
* Own heading, list, codeblock, and blockquote heuristics.
* Own RichTable/table Markdown behavior.
* Own note, comment, header, footer, and textbox placement.
* Own asset export, path naming, metadata, and origins.
* Surface unsupported feature warnings in product-facing form.
* Make quality-driven product decisions.

Non-responsibilities:

* Directly scanning raw WordprocessingML XML at runtime.
* Calling legacy scanner fallback at runtime.
* Parsing relationships, styles, numbering, or media XML.
* Rebuilding parser source facts.

Inputs:

* `DocxDocument`.
* Conversion options and output directory.

Outputs:

* Core `Document`.
* Exported assets, origins, and warnings.

Example types/APIs:

```moonbit
pub fn parse_docx(
  path : String,
  out_root : String,
  max_heading : Int,
) -> @core.Document raise

fn lower_docx_document_v2(
  doc : @docx_model.DocxDocument,
  options : DocxLoweringOptions,
) -> @core.Document raise
```

### E. Historical Oracle And Migration Evidence

Responsibilities:

* Preserve migration notes, historical diffs, and quality triage records in
  docs or archives.
* Explain why runtime oracle/fallback behavior is forbidden in the current
  architecture.

Non-responsibilities:

* Normal conversion.
* Runtime fallback.
* Production profile counters.
* New feature implementation.

The old v1 runtime has been deleted. Historical references may remain in
archive docs, changelog notes, and migration reports, but no normal package may
depend on `doc_parse/docx` or `convert/docx`.

## Package Layer Details

The package layer owns ZIP open/read behavior and package-level indexing. It
must be reusable by DOCX, PPTX, XLSX, and any other OOXML format. It should
continue to expose:

* ZIP/package lifecycle.
* Content types.
* Part bytes/text cache.
* Relationships and relationship indexes.
* Document properties.
* Part inventory.

It must not know about WordprocessingML tags, paragraph semantics, Markdown,
IR, asset exports, or output origins.

## Source Layer Details

The source layer parses DOCX-specific WordprocessingML parts into a stable
source representation. It should support main document body parts first and
then add related parts through the part graph.

Source nodes should preserve:

* Source part path.
* Source order.
* Source span or stable source key.
* Raw tag/node kind where useful.
* Typed known nodes and typed unknown nodes.

Represented source nodes include:

* Paragraphs, runs, text, tabs, and breaks.
* Tables, rows, and cells.
* Footnotes, endnotes, and comments.
* Headers, footers, and textboxes.
* Drawings and media references.
* Fields, math, bookmarks, symbols, soft hyphens, and tracked changes.
* Unknown or unsupported WordprocessingML constructs.

The source layer does not make fallback decisions. Unsupported and unknown
source is still source; it becomes a warning only after normalization decides
what semantic support exists.

## Normalized Model Layer Details

`DocxDocument` is the DOCX semantic input for conversion. It is not Markdown
and it is not core IR. It may resolve references to give convert a stable,
structured view of styles, numbering, hyperlinks, media, comments, and related
parts, but it does not choose product rendering.

The model should include:

* Document metadata and source info.
* Part graph.
* Body blocks.
* Paragraphs.
* Runs and inlines.
* Tables, rows, and cells.
* Notes and comments.
* Headers, footers, and textboxes.
* Media/drawing refs.
* Style and numbering refs plus resolved hints.
* Fields, math, bookmarks, tracked changes, and unknown inline nodes.
* Warnings / unsupported features.
* Source spans and origin ids.

Warnings are explicit model records. They replace hidden fallback as the way
the parser/model says "this source exists but v2 does not fully support it."

## Convert Lowering Layer Details

`convert/docx` consumes only the normalized model and conversion options.
It owns all product-facing choices:

* Lowering normalized DOCX blocks to core IR.
* Markdown-facing text and structure policy.
* Heading/list/code/blockquote heuristics.
* RichTable and table Markdown behavior.
* Note/comment/header/footer/textbox placement.
* Asset export, path naming, origin attachment, and metadata.
* Unsupported feature warning presentation.
* Quality-driven decisions where exact Word behavior is neither available nor
  desirable.

The convert runtime must not directly scan raw XML, call legacy scanner
fallback, or parse relationship/style/numbering XML. If lowering needs a fact,
that fact belongs in `DocxDocument` or a narrower model service.

## Historical Oracle Details

The legacy scanner was useful during migration, but it is not part of the
implemented runtime. Compatibility is now guarded by checked samples,
quality-lab rows, v2 parser/lowering tests, and post-removal route tests. New
DOCX behavior should be added by extending `doc_parse/docx` typed source /
model coverage and `convert/docx` lowering, not by restoring an oracle or
fallback path.

## MVP Scope

This section is historical design context. The adopted runtime has moved past
the original MVP through RESET-16/17/18/21 typed model completion and v1
removal.

V2 MVP includes:

* Open package once.
* Main document body source order.
* Paragraphs and runs.
* Text, tab, and line break inlines.
* Simple hyperlinks.
* Basic style and numbering resolution.
* Simple tables.
* Note/comment references as inline refs.
* Unsupported warnings.
* Source spans and origin ids.
* No runtime legacy fallback.

V2 MVP does not include:

* Complete OMML conversion.
* Field evaluation.
* Full tracked-change semantics.
* Browser-like or Word-like layout.
* Complex table layout fidelity.
* OLE/chart/smartart/video/audio rendering.

## Capability Roadmap

* V2-M0: package/source skeleton.
* V2-M1: normalized body paragraphs.
* V2-M2: styles, numbering, and hyperlinks.
* V2-M3: simple tables.
* V2-M4: notes and comments.
* V2-M5: headers, footers, and textboxes.
* V2-M6: media/drawing refs and asset export.
* V2-M7: fields, math, bookmarks, and tracked changes as conservative nodes.
* V2-M8: complex tables and layout-sensitive warnings.

## API Sketch

This is pseudo MoonBit. It is a contract sketch, not compile-ready code.

```moonbit
pub struct DocxSourceSpan {
  part_name : String
  node_key : String
  start_offset : Int?
  end_offset : Int?
}

pub struct DocxSourceDocument {
  package_id : String?
  main_part : String
  parts : Array[DocxSourcePart]
  warnings : Array[DocxWarning]
}

pub struct DocxSourcePart {
  part_name : String
  relationships : Array[DocxSourceRelationship]
  nodes : Array[DocxSourceNode]
  span : DocxSourceSpan
}

pub enum DocxSourceNode {
  Paragraph(DocxSourceParagraph)
  Run(DocxSourceRun)
  Text(String, DocxSourceSpan)
  Table(DocxSourceTable)
  TableRow(DocxSourceTableRow)
  TableCell(DocxSourceTableCell)
  Note(DocxSourceNote)
  Comment(DocxSourceComment)
  Header(DocxSourcePartRef)
  Footer(DocxSourcePartRef)
  TextBox(DocxSourceTextBox)
  Drawing(DocxSourceDrawing)
  Field(DocxSourceField)
  Math(DocxSourceMath)
  Bookmark(DocxSourceBookmark)
  Symbol(DocxSourceSymbol)
  Break(DocxSourceBreak)
  Hyphen(DocxSourceHyphen)
  TrackedChange(DocxSourceTrackedChange)
  UnknownInline(DocxSourceUnsupportedInline)
  Unknown(DocxUnknownSourceNode)
}

pub struct DocxDocument {
  source_info : DocxDocumentSourceInfo
  metadata : DocxDocumentMetadata
  part_graph : DocxPartGraph
  body : Array[DocxBlock]
  notes : Array[DocxNote]
  comments : Array[DocxComment]
  headers : Array[DocxHeaderFooter]
  footers : Array[DocxHeaderFooter]
  textboxes : Array[DocxTextBox]
  warnings : Array[DocxWarning]
}

pub enum DocxBlock {
  Paragraph(DocxParagraph)
  Table(DocxTable)
  Unsupported(DocxUnsupportedBlock)
}

pub struct DocxParagraph {
  style_id : String?
  numbering : DocxNumberingRef?
  runs : Array[DocxRun]
  source_span : DocxSourceSpan
  origin_id : String
}

pub struct DocxRun {
  style_id : String?
  inlines : Array[DocxInline]
  source_span : DocxSourceSpan
}

pub enum DocxInline {
  Text(String, DocxSourceSpan)
  Tab(DocxSourceSpan)
  LineBreak(DocxSourceSpan)
  Break(DocxBreak)
  Hyperlink(DocxHyperlink)
  FootnoteRef(Int, DocxSourceSpan)
  EndnoteRef(Int, DocxSourceSpan)
  CommentRef(Int, DocxSourceSpan)
  Media(DocxMediaRef)
  FieldUnsupported(DocxField)
  Math(DocxMath)
  Bookmark(DocxBookmark)
  TrackedChange(DocxTrackedChange)
  Symbol(DocxSymbol)
  Hyphen(DocxHyphen)
  UnsupportedInline(DocxUnsupportedInline)
  Unsupported(String)
}

pub struct DocxTable {
  rows : Array[DocxTableRow]
  source_span : DocxSourceSpan
  origin_id : String
}

pub struct DocxTableRow {
  cells : Array[DocxTableCell]
  source_span : DocxSourceSpan
}

pub struct DocxTableCell {
  blocks : Array[DocxBlock]
  grid_span : Int?
  vertical_merge : DocxVerticalMerge?
  source_span : DocxSourceSpan
}

pub struct DocxMediaRef {
  relationship_id : String?
  source_part : String
  target : String?
  resolved_target : String?
  target_mode : DocxTargetMode?
  content_type : String?
  alt_text : String?
  title : String?
  source_span : DocxSourceSpan
}

pub struct DocxWarning {
  kind : DocxWarningKind
  severity : DocxWarningSeverity
  message : String
  source_span : DocxSourceSpan?
}
```

## Implementation Record

The DOCX-3 work is now historical reference material. It contains valuable
test cases, performance lessons, source fact experiments, and compatibility
knowledge, but the normal runtime is the v2 source/model/lowering pipeline.

Reusable low-level pieces to extract or preserve:

* OOXML cache.
* Relationship index.
* Content-type helpers.
* Style, numbering, and media query logic.
* Tests and fixtures.
* Known bug lessons, especially codeblock, deep-table, image-in-table, and
  note/header/footer/textbox behavior.

Implemented packages:

* `doc_parse/docx` and `convert/docx`.

The dispatcher routes DOCX to `convert/docx` after coverage, quality, and
sample checks reached replacement readiness.

## Test Strategy

Use tests to guard the implemented runtime contract:

* Parser source snapshot tests.
* Normalized model snapshot tests.
* Lowering golden tests.
* Post-removal route/dependency guard tests.
* Fuzz and edge tests for deep nesting.
* Performance benchmarks for large documents and repeated package queries.
* Quality-lab integration.

Regression examples:

* Codeblock with no `pStyle`.
* Deep table 5000 nesting.
* Image in table.
* Notes, comments, headers, footers, and textboxes.
* Field, math, bookmark, and tracked-change preservation.

## Runtime Invariants

DOCX remains the runtime only while:

* Normal conversion has no runtime legacy fallback.
* All supported nodes are represented in the normalized model.
* Main samples have output parity or documented intentional changes.
* Quality rows pass.
* Performance is no worse on large documents.
* Unsupported cases produce warnings instead of hidden fallback.
* Documentation accurately states limits.

## Open Questions

* Source span granularity improvements beyond current stable source keys.
* How to represent unknown WordprocessingML without exposing unstable raw XML
  everywhere.
* Style cascade depth and which resolved style hints belong in the model.
* Numbering resolution rules and how much list rendering policy stays in
  convert.
* Origin mapping from source spans to core `Origin`.
* Asset naming stability across package order, relationship order, and content
  type changes.
* How much legacy behavior should be preserved versus intentionally improved.

## Next Steps

Keep v2 as the only normal DOCX runtime. Future work should focus on targeted
typed-model gaps, performance snapshots, and format-quality improvements
without restoring v1 fallback or dispatcher-side special cases.

## Historical Reset Notes

The following RESET notes record implementation milestones. Earlier notes may
describe temporary disconnected dispatcher states or v2-only harnesses that no
longer apply after commit `8ed4a3b`.

## RESET-9 Sample Harness Note

DOCX-RESET-9 adds a v2-only real-sample smoke harness under
`convert/docx/test`. The harness opens selected existing
`samples/main_process/docx` files through `doc_parse/docx`, lowers them with
`convert/docx`, and asserts conservative structural properties rather than
old pipeline parity. The dispatcher remains disconnected, legacy conversion is
not used as fallback, and `samples/main_process/docx/expected` files remain
untouched.

## RESET-10 Notes And Comments Lowering Note

DOCX-RESET-10 resolves body references to v2 footnote, endnote, and comment
containers during `convert/docx` lowering. Inline body references remain
stable markers such as `[footnote:1]`; resolved containers are appended at the
end under deterministic `Footnotes`, `Endnotes`, and `Comments` sections in
first-reference order. Duplicate references produce one appendix entry, and
unreferenced containers are omitted. Missing references remain unresolved
markers and are reported as v2 warnings by the normalized model.

## RESET-11 Image Asset Export Note

DOCX-RESET-11 starts v2-owned image asset export in `convert/docx`. The
parser/model continue to expose source-only media facts such as relationship id,
target part, target mode, content type, alt text, and title; they do not store
final asset paths. The asset-enabled lowering entry reads internal media bytes
from the OOXML package, writes deterministic `assets/imageNN.ext` files, returns
a v2 exported-asset list, and emits core `ImageBlock` for standalone image
paragraphs. Table-cell images are exported when possible but still lower inside
tables as conservative `[image: ...]` text. External linked images and missing
parts remain stable placeholders with deterministic warnings. The dispatcher
remains disconnected and no legacy DOCX fallback is used.

## RESET-12 Mixed Image Paragraph Note

DOCX-RESET-12 improves the asset-enabled v2 lowerer for mixed text and image
paragraphs. When an internal media ref can be exported, `convert/docx` splits
the paragraph into deterministic text blocks and `ImageBlock` entries in source
order, including multiple images in one paragraph. Missing, external, or
unsupported media remain inline placeholders with warnings. Exported image
origins are attached through core block and asset origin metadata using the DOCX
source part, block index, media source key, relationship id, and target part.
Table-cell images remain conservative table text and are not embedded as
`ImageBlock` values inside `RichTable`.

## RESET-13 Expected Tier And Table Header Note

DOCX-RESET-13 introduces a v2-owned expected tier under `convert/docx/test`.
These expected Markdown strings are experimental v2 baselines and deliberately
do not reuse or modify `samples/main_process/docx/expected`. The tier records
current conservative v2 output, including explicit unsupported-node placeholders
where the v2 parser has not yet specialized a DOCX body node.

The table header policy is v2-owned: `doc_parse/docx` captures explicit
row-level `w:tblHeader`, paragraph alignment, and run bold style hints;
`convert/docx` sets `RichTable.header_rows` from explicit table-header
source facts or from the bounded styled-first-row inference policy. No legacy
fallback is used.

## RESET-14 Benign Structural Node Note

DOCX-RESET-14 classifies benign non-visible WordprocessingML control nodes as
structural markers instead of generic unknown content. Body-level section
properties, bookmark boundaries, proof markers, permission boundaries, comment
range boundaries, and move range boundaries are preserved as v2 source/model
facts and lower to no visible Markdown. Inline structural range markers are also
silent, while actual visible references such as `commentReference`,
`footnoteReference`, and `endnoteReference` keep their stable markers. Generic
unsupported placeholders remain reserved for meaningful unknown content.

## RESET-15 Tracked Change And Control Hardening Note

DOCX-RESET-15 keeps the RESET-14 boundary but tightens coverage around tracked
change range controls. Move range boundaries remain structural, and
`w:lastRenderedPageBreak` is classified as a non-visible structural marker so it
does not create visible unsupported text. Meaningful containers such as
`w:sdt`, smart tags, and other unknown content-bearing nodes remain explicit
unsupported placeholders until v2 has typed lowering for their contents.
