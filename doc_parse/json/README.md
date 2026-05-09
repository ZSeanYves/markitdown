# doc_parse/json

Purpose:

* parser/AST/inspect foundation for JSON documents
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a JSON-to-Markdown policy layer

Current status:

* internal foundation hardening
* not yet labeled as a standalone publishable package candidate

Public API:

* `parse_json_document`
* `inspect_json_document`
* `classify_json_error`
* `json_value_kind`

Current model:

* `JsonDocument`
* `JsonValue`
* `JsonMember`

Current error surface:

* `JsonError`
* `JsonErrorInfo`
* classifier kinds for trailing content, malformed strings/escapes/unicode,
  malformed numbers, and expected-token failures

Current inspect surface:

* `node_count`
* `object_count`
* `array_count`
* `scalar_count`
* `member_count`
* `max_depth`
* `root_kind`

Current parser boundary:

* JSON lexer/parser behavior
* string escape decoding
* unicode escape / surrogate-pair decoding
* malformed input fail-closed behavior

Non-goals:

* JSON-to-table policy
* JSON-to-list policy
* fenced code fallback
* Markdown summary/rendering

Relationship to `convert/json`:

* `doc_parse/json` owns parsing and AST/inspect
* `convert/json` owns `JsonDocument -> IR -> Markdown` lowering policy

Known limits:

* parse entry is currently string-based; file I/O and converter-side UTF-8
  policy remain in `convert/json`
* this package does not claim permissive JSON5 / comments / trailing-comma
  support

Testing:

* lower-layer tests live in `doc_parse/json/tests`
* converter behavior is regression-guarded separately under `convert/json/test`

Versioning note:

* current hardening is in-tree first; future standalone extraction should
  happen only after internal validation remains stable
