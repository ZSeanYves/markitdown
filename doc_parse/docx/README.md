# doc_parse/docx

Purpose:

* WordprocessingML source-native semantic foundation inside
  `ZSeanYves/markitdown`
* reusable lower-layer package for DOCX body/inline/table relationships,
  styles, numbering, notes, headers/footers, and text-box discovery
* not a Markdown renderer, IR builder, or final product-output policy layer

Current status:

* DOCX semantic foundation candidate
* in-tree semantic/model/inspect/validation package, not a standalone MoonBit
  module split yet
* `convert/docx` still owns the current normal conversion path and its final
  heading/list/table/caption/code/image policy

Current public API:

* `open_docx_document`
* `parse_docx_document_from_package`
* `inspect_docx_document`
* `collect_docx_validation_issues`
* `validate_docx_document`
* `classify_docx_error`

Stable candidate API:

* `open_docx_document`
* `parse_docx_document_from_package`
* `inspect_docx_document`
* `collect_docx_validation_issues`
* `validate_docx_document`
* `classify_docx_error`

Inspect / validation API:

* `inspect_docx_document`
* `collect_docx_validation_issues`
* `validate_docx_document`

Compatibility surface:

* `DocxDocument`
* `DocxBodyBlock`
* `DocxParagraph`
* `DocxRun`
* `DocxInline`
* `DocxTable`
* `DocxTableRow`
* `DocxTableCell`
* `DocxRelationship`
* `DocxRelationshipIndex`
* `DocxStyles`
* `DocxStyle`
* `DocxNumbering`
* `DocxNumberingRef`
* `DocxNumberingLevel`
* `DocxHyperlink`
* `DocxMediaRef`
* `DocxNotes`
* `DocxFootnote`
* `DocxEndnote`
* `DocxComment`
* `DocxHeader`
* `DocxFooter`
* `DocxTextBox`
* `DocxError`
* `DocxErrorInfo`
* `DocxInspectReport`
* `DocxValidationIssue`
* `DocxValidationReport`

Current relationship / style / numbering / notes / media boundary:

* relationship ids, target parts, target mode, and resolved hyperlink/media
  targets are preserved as source-native lower-layer signal
* style id / name / type / based-on / raw heading-like signal are preserved
  where available, but no final heading decision is made here
* numbering refs preserve raw `numId` / `abstractNumId` / `ilvl`-driven signal
  without owning final list rendering
* notes/comments/headers/footers/text boxes are preserved as source-native
  structures without appended product-section naming or ordering policy
* media refs preserve raw relationship/media signal without asset export path
  or caption policy

Internal exposed surface:

* WordprocessingML XML scanning helpers remain package-internal
* body/inline/table scanners remain internal implementation details
* relationship-target resolution remains internal to this package plus
  `doc_parse/ooxml`
* text-box discovery, deleted-revision stripping, and header/footer reference
  scanning remain internal helpers rather than a second public utility layer

Current semantic boundary:

* main document body block model
* paragraphs, runs, text/tab/line-break inlines
* raw hyperlink references and raw media references
* table/row/cell source-native structure
* document relationships
* styles and numbering raw semantic signal
* note/comment/header/footer/text-box discovery
* inspect counts and explicit validation issue collection

Non-goals:

* `@cor.Document` / unified IR
* Markdown rendering
* final heading-level decision
* final list rendering
* final codeblock / blockquote heuristics
* Markdown table rendering
* image asset export path
* caption / nearby-caption final policy
* appended product sections such as `## Footnotes` or `## Headers`
* full WordprocessingML support
* full Office semantic support

Relationship to `convert/docx`:

* `doc_parse/docx` owns WordprocessingML source-native semantic parsing/model/
  inspect/validation
* `convert/docx` still owns semantic model -> IR / Markdown / assets /
  metadata / final product policy
* `convert/docx` normal path is intentionally not switched to this package in
  the current candidate closure

Known limits:

* this package does not claim full WordprocessingML coverage
* style and numbering handling preserve conservative semantic signal; they do
  not implement a full style cascade or full list-layout engine
* note/comment/header/footer/text-box support is source-native discovery, not
  final product ordering policy
* tracked changes are only handled through conservative deleted-revision
  stripping in this candidate package
* complex fields, equations, charts, SmartArt, and deep DrawingML semantics
  remain out of scope

Testing:

* lower-layer tests live in `doc_parse/docx/tests`
* converter regression remains separately guarded in `convert/docx/test`

Versioning note:

* this package is intentionally being stabilized in-tree first
* future work may still refine field-level compatibility surfaces, add more
  lower-layer validation taxonomy, or integrate more of `convert/docx` once
  zero-drift seams are demonstrated
* candidate status here means the source-native semantic API, inspect surface,
  validation surface, and current lower-layer tests are stable enough for
  internal reuse; it does not claim full WordprocessingML support or a
  switched `convert/docx` normal path
