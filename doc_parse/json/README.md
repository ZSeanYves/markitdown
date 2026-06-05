# doc_parse/json

Purpose:

* parser/AST/inspect foundation for JSON documents
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a JSON-to-Markdown policy layer

Current status:

* simple-format parser foundation candidate
* stable as an in-tree parser/AST/error/inspect surface
* not a standalone MoonBit module split yet

Stable candidate API:

* `parse_json_document`
* `inspect_json_document`
* `classify_json_error`
* `json_value_kind`

Current public API:

* `parse_json_document`
* `profile_json_document`
* `inspect_json_document`
* `classify_json_error`
* `json_value_kind`

Benchmark-oriented helper surface:

* `profile_json_document` exists for internal hotspot attribution and
  benchmark tooling
* it is not part of the main stable candidate API contract
* it does not change the JSON AST or `convert/json` behavior

Minimal examples:

```moonbit
let doc = @json.parse_json_document("{\"items\":[1,true,\"x\"]}")
let report = @json.inspect_json_document(doc)

println("root=" + report.root_kind)
println("nodes=" + report.node_count.to_string())
```

```moonbit
let _ = @json.parse_json_document("{bad}") catch {
  err => {
    let info = @json.classify_json_error(err)
    println(info.kind.to_string())
    println(info.detail)
    @json.parse_json_document("{}")
  }
}
```

Build on top:

* AST walkers, JSON structure checkers, and custom `JsonDocument -> private IR`
  lowering can reuse this package directly

Debug / inspect API:

* `inspect_json_document`

Compatibility surface:

* `JsonDocument`
* `JsonValue`
* `JsonMember`
* `JsonErrorInfo`
* exact enum/field layout remains a documented compatibility surface

Internal exposed surface:

* recursive-descent parser helpers stay internal; they are not a separate
  public contract

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
* exact numeric-value representation remains source-preserving string text,
  which is intentional for parser neutrality but still a release-policy choice

Performance note:

* JSON parsing here is string-based and intended for predictable lower-layer
  AST construction, not streaming ingestion
* benchmark product timings still include converter and emitter work above this
  layer

Testing:

* lower-layer tests live in `doc_parse/json/tests`
* converter behavior is regression-guarded separately under `convert/json/test`

Versioning note:

* current candidate closure is in-tree first
* future release-policy work may still add bytes-open helpers or narrow field
  visibility without changing converter ownership
