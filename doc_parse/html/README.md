# doc_parse/html

Purpose:

* tolerant DOM-ish tokenizer/parser/model foundation for HTML lower-layer work
* reusable in-tree parsing substrate inside `ZSeanYves/markitdown`
* not an HTML-to-Markdown policy layer

Current status:

* active foundation hardening Pass 1
* current scope is tokenizer/parser/model/error/inspect/validation/safety
  boundary
* `convert/html` still owns normal HTML conversion policy and source-preserving
  product behavior

Current public API:

* `tokenize_html_document`
* `parse_html_document`
* `inspect_html_document`
* `collect_html_validation_issues`
* `validate_html_document`
* `classify_html_error`

Compatibility surface:

* `HtmlDocument`
* `HtmlNode`
* `HtmlElement`
* `HtmlAttribute`
* `HtmlText`
* `HtmlComment`
* `HtmlDoctype`
* `HtmlSourceSpan`
* `HtmlToken`
* `HtmlErrorInfo`
* `HtmlValidationIssue`
* `HtmlValidationReport`
* `HtmlInspectReport`

Internal exposed surface:

* tokenizer scanning helpers
* tolerant stack-repair helpers for end-tag mismatch handling
* limited HTML entity decoding helpers
* these are implementation details, not a second public facade

Current model:

* `HtmlDocument`
* `HtmlNode`
* `HtmlElement`
* `HtmlAttribute`
* `HtmlText`
* `HtmlComment`
* `HtmlDoctype`

Current error / validation surface:

* `HtmlError`
* `HtmlErrorInfo`
* `HtmlValidationIssue`
* `HtmlValidationReport`

Current inspect surface:

* node / element / attribute / text counts
* comment / doctype counts
* link / image / heading / table / list / form counts
* script / style / pre / code counts
* max depth
* issue / warning / error counts

Safety boundary:

* no remote fetch
* no script execution
* no CSS or JS rendering
* `href` / `src` / related URL-like attributes are preserved as raw attribute
  values only
* obvious unsafe URL schemes are surfaced as validation issues rather than
  rewritten
* a limited entity decoder is implemented for:
  * `&amp;`
  * `&lt;`
  * `&gt;`
  * `&quot;`
  * `&apos;`
  * `&nbsp;`
  * numeric entities such as `&#169;` and `&#x1F600;`
* unknown named entities are preserved literally

Current parser boundary:

* start / end / self-closing tags
* a documented void-element set
* attributes with double quotes, single quotes, or unquoted values
* text nodes
* comments
* doctype recognition
* tolerant multiple-top-level-node handling
* conservative repair for unexpected closing tags / unclosed elements
* raw script/style/textarea/title content preserved as text

Non-goals:

* Markdown rendering
* IR construction
* image asset writing
* caption or nearby-text inference
* final heading/list/table/code/link/image Markdown policy
* CSS/JS rendering
* remote fetch
* full browser HTML parser behavior
* full HTML5 tree-construction conformance
* XML parser semantics

Relationship to `convert/html`:

* `doc_parse/html` owns tokenizer/parser/model/error/inspect/validation/safety
  boundary
* `convert/html` still owns HTML model -> IR / Markdown / assets / metadata /
  product output policy
* this pass does not switch the normal HTML converter onto the parser
  foundation

Known limits:

* this is a tolerant DOM-ish parser foundation, not a browser engine
* tag and attribute names are normalized to lowercase for the current raw model
* the entity decoder is intentionally partial; unsupported named entities stay
  literal
* whitespace-only inter-tag text nodes are currently dropped to keep inspect
  and inventory surfaces stable during Pass 1
* current raw-text handling focuses on `script` / `style` / `textarea` /
  `title`, not full HTML tokenizer states
* namespaces, CSS cascade/layout, script execution, and remote resources are
  out of scope

Testing:

* lower-layer tests live in `doc_parse/html/tests`
* converter regression tests remain under `convert/html/test`

Versioning note:

* this package is still in active in-tree hardening rather than candidate
  closure
* future work may expand validation, provenance/span fidelity, and tokenizer
  coverage before candidate review
