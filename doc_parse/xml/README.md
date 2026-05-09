# doc_parse/xml

Purpose:

* tokenizer/parser/model/inspect foundation for safe XML lower-layer handling
* reusable in-tree parsing substrate inside `ZSeanYves/markitdown`
* not an XML-to-Markdown policy layer

Current status:

* active foundation hardening Pass 1
* not a publishable foundation candidate yet
* converter output still remains source-preserving under `convert/xml`

Stable early API:

* `tokenize_xml_document`
* `parse_xml_document`
* `inspect_xml_document`
* `collect_xml_validation_issues`
* `validate_xml_document`
* `classify_xml_error`

Current model:

* `XmlDocument`
* `XmlNode`
* `XmlElement`
* `XmlAttribute`
* `XmlText`
* `XmlComment`
* `XmlProcessingInstruction`
* `XmlCData`

Current error / validation surface:

* `XmlError`
* `XmlErrorInfo`
* `XmlValidationIssue`
* `XmlValidationReport`

Current inspect surface:

* node / element / attribute / text counts
* comment / CDATA / processing-instruction counts
* max depth
* doctype presence and unsupported-doctype marker

Safety boundary:

* no external entity fetch
* no DTD or custom entity expansion
* `DOCTYPE` is recognized and surfaced as unsupported syntax
* only predefined XML entities are decoded:
  * `&amp;`
  * `&lt;`
  * `&gt;`
  * `&quot;`
  * `&apos;`
* unknown entities fail closed

Current parser boundary:

* start/end/self-closing tags
* attributes with double or single quotes
* text nodes
* comments
* CDATA
* processing instructions
* duplicate-attribute and mismatched-tag detection

Non-goals:

* Markdown rendering
* IR construction
* source-preserving product output
* external entity loading
* DTD/entity expansion support
* namespace semantic resolution
* schema validation
* XPath
* full XML spec support

Relationship to `convert/xml`:

* `doc_parse/xml` owns tokenizer/parser/model/error/inspect/safety boundary
* `convert/xml` still owns source-preserving fenced-XML converter behavior
* this pass does not switch normal XML conversion onto the parser layer

Known limits:

* current package is a safe minimal parser foundation, not a complete XML
  implementation
* `DOCTYPE` is surfaced as unsupported rather than semantically interpreted
* unknown/custom entity references fail closed
* namespace prefixes are preserved in raw names only

Testing:

* lower-layer tests live in `doc_parse/xml/tests`
* converter regression tests remain under `convert/xml/test`

Versioning note:

* this package is being stabilized in-tree before any future standalone-module
  split
* future work may enrich validation, typed unsupported-feature reporting, and
  namespace/source-span fidelity without changing the current parser/converter
  boundary
