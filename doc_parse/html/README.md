# doc_parse/html

Purpose:

* tolerant DOM-ish tokenizer/parser/model foundation for HTML lower-layer work
* reusable in-tree parsing substrate inside `ZSeanYves/markitdown`
* not an HTML-to-Markdown policy layer

Current status:

* HTML DOM-ish parser foundation candidate
* current scope is tokenizer/parser/model/error/inspect/validation/safety
  boundary
* `convert/html` still owns normal HTML conversion policy and source-preserving
  product behavior

Stable candidate API:

* `tokenize_html_document`
* `parse_html_document`
* `inspect_html_document`
* `collect_html_validation_issues`
* `validate_html_document`
* `classify_html_error`

Minimal examples:

```moonbit
let doc = @html.parse_html_document("<h1>Hello</h1><p>world</p>")
let report = @html.inspect_html_document(doc)

println("elements=" + report.element_count.to_string())
println("headings=" + report.heading_element_count.to_string())
```

```moonbit
let doc = @html.parse_html_document("<a href=\"javascript:alert(1)\">x</a>")
for issue in @html.collect_html_validation_issues(doc) {
  println(issue.message)
}
```

```moonbit
let _ = @html.parse_html_document("<div") catch {
  err => {
    let info = @html.classify_html_error(err)
    println(info.kind.to_string())
    println(info.detail)
    @html.parse_html_document("<fallback></fallback>")
  }
}
```

Build on top:

* DOM-ish structure inspectors, unsafe-link scanners, and custom
  HTML-to-private-IR converters can sit directly on this model

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
* `HtmlAttributeQuoteStyle`
* `HtmlError`
* `HtmlErrorKind`
* `HtmlErrorInfo`
* `HtmlValidationIssueKind`
* `HtmlValidationSeverity`
* `HtmlValidationIssue`
* `HtmlValidationReport`
* `HtmlInspectReport`

Internal exposed surface:

* tokenizer scanning helpers
* tolerant stack-repair helpers for end-tag mismatch handling
* limited HTML entity decoding helpers
* URL safety classification helpers
* raw inventory traversal helpers
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

Tolerant repair policy:

* multiple top-level nodes are allowed
* documented void elements are treated as self-closing in the raw model
* explicit self-closing syntax is preserved in the raw model
* unexpected closing tags are surfaced as validation issues
* unclosed elements are repaired conservatively and surfaced as validation
  issues
* duplicate attributes are surfaced as validation issues
* raw `script` / `style` contents are preserved as text and never executed or
  rendered

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
  and inventory surfaces stable
* current raw-text handling focuses on `script` / `style` / `textarea` /
  `title`, not full HTML tokenizer states
* namespaces, CSS cascade/layout, script execution, and remote resources are
  out of scope
* no full HTML5 tree-construction or browser-correction claim is made

Performance note:

* small tokenizer/parser paths are intended to be cheap, but tolerant repair
  and validation still remain enabled
* browser-grade timing comparisons are out of scope for this package

Testing:

* lower-layer tests live in `doc_parse/html/tests`
* converter regression tests remain under `convert/html/test`

Versioning note:

* this package is a current in-tree candidate surface, not a separately
  published MoonBit module
* compatibility fields remain intentionally visible while future release-policy
  decisions are still in-tree
* future work may expand validation, provenance/span fidelity, and tokenizer
  coverage without changing the current no-fetch / no-execution boundary
