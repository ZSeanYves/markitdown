# doc_parse/pptx

Purpose:

* PresentationML source-native semantic foundation inside
  `ZSeanYves/markitdown`
* reusable lower-layer package for presentation/slide order, raw shape tree,
  text paragraphs/runs, explicit tables, notes, media refs, and hyperlink refs
* not a reading-order engine, layout/grouping engine, Markdown renderer, IR
  builder, or final product-output policy layer

Current status:

* PPTX semantic foundation candidate
* in-tree semantic/model/inspect/validation package, not a standalone MoonBit
  module split yet
* `convert/pptx` still owns the current normal conversion path and its final
  reading-order/layout/grouping/caption/image/heading/list/IR policy

Current public API:

* `open_pptx_presentation`
* `parse_pptx_presentation_from_package`
* `inspect_pptx_presentation`
* `collect_pptx_validation_issues`
* `validate_pptx_presentation`
* `classify_pptx_error`

Stable candidate API:

* `open_pptx_presentation`
* `parse_pptx_presentation_from_package`
* `inspect_pptx_presentation`
* `collect_pptx_validation_issues`
* `validate_pptx_presentation`
* `classify_pptx_error`

Inspect / validation API:

* `inspect_pptx_presentation`
* `collect_pptx_validation_issues`
* `validate_pptx_presentation`

Compatibility surface:

* `PptxPresentation`
* `PptxSlide`
* `PptxShape`
* `PptxShapeKind`
* `PptxTextParagraph`
* `PptxTextRun`
* `PptxTable`
* `PptxTableRow`
* `PptxTableCell`
* `PptxNotes`
* `PptxRelationship`
* `PptxRelationshipIndex`
* `PptxMediaRef`
* `PptxHyperlink`
* `PptxInspectReport`
* `PptxValidationIssue`
* `PptxValidationReport`
* `PptxError`
* `PptxErrorInfo`

Internal exposed surface:

* PresentationML XML scanning helpers remain package-internal
* presentation/slide relationship parsing and shape-tree traversal remain
  internal implementation details
* text extraction, explicit table parsing, notes discovery, and media
  resolution helpers remain internal to this package plus `doc_parse/ooxml`
* no second public utility layer is exposed for reading order, layout
  recovery, grouping, or caption pairing

Current semantic boundary:

* presentation slide order and hidden-slide raw signal
* slide relationship context and notes discovery
* source-native shape tree with nested group traversal
* raw text paragraphs/runs/bullet-level signal
* explicit table rows/cells/paragraphs
* raw media refs and hyperlink refs
* inspect counts and explicit validation issue collection

Current slide / shape / text / table / notes / media boundary:

* slide order and hidden-slide signal are preserved as source-native lower-layer
  data, but no slide-to-Markdown ordering policy is decided here
* nested group traversal and raw shape kind/object-ref signal are preserved
  without owning layout grouping, card/callout grouping, or table-like
  grouping
* text paragraphs/runs and raw hyperlink targets are preserved without final
  heading/list/paragraph classification
* explicit `a:tbl` objects preserve raw rows/cells/paragraphs without Markdown
  table rendering
* notes preserve raw speaker-notes paragraphs without final section
  naming/order policy
* media refs preserve relationship id / target part / content type / alt/title
  signal without asset export path or caption policy

Non-goals:

* reading order recovery
* layout grouping / card / callout / table-like grouping
* title promotion / final heading/list classification
* noise filtering
* image caption inference
* image asset export path
* Speaker Notes final section naming/order policy
* `@cor.Document` / unified IR
* Markdown rendering
* full PresentationML support
* full Office semantic support

Relationship to `convert/pptx`:

* `doc_parse/pptx` owns PresentationML source-native semantic parsing/model/
  inspect/validation
* `convert/pptx` still owns semantic model -> IR / Markdown / assets /
  metadata / final product policy
* `convert/pptx` normal path is intentionally not switched to this package in
  the current candidate closure

Known limits:

* this package does not claim browser/layout-engine-style slide reconstruction
* reading order, grouping, and caption pairing remain converter-owned
* raw notes are preserved without final Speaker Notes section policy
* explicit tables are preserved as raw cell/paragraph structures, not Markdown
  table policy
* charts, SmartArt, animations, transitions, theme/master/layout inheritance,
  and deeper DrawingML semantics remain out of scope

Testing:

* lower-layer tests live in `doc_parse/pptx/tests`
* converter regression remains separately guarded in `convert/pptx/test`

Versioning note:

* this package is intentionally being stabilized in-tree first
* future work may still refine field-level compatibility surfaces, add more
  validation taxonomy, or integrate tiny zero-drift helper seams
* candidate status here means the source-native presentation/slide/shape/text/
  table/notes/media API, inspect surface, validation surface, and current
  lower-layer tests are stable enough for internal reuse; it does not claim
  full PresentationML support or a switched `convert/pptx` normal path
