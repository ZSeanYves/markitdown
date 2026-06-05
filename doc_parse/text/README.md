# doc_parse/text

Purpose:

* plain-text structural parser/model/inspect foundation
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a literal-Markdown policy layer

Current status:

* plain-text parser foundation candidate
* stable as an in-tree text-structure/error/inspect surface
* not a standalone MoonBit module split yet

Stable candidate API:

* `open_text_document`
* `parse_text_document`
* `inspect_text_document`
* `classify_text_error`

Current public API:

* `open_text_document`
* `parse_text_document`
* `parse_text_document_from_normalized_text`
* `profile_text_document`
* `profile_text_document_from_normalized_text`
* `inspect_text_document`
* `classify_text_error`

Advanced helper surface:

* `parse_text_document_from_normalized_text`
  specialized entry for callers that already own upstream normalization and do
  not want the normal byte/string seam repeated
* `profile_text_document`
* `profile_text_document_from_normalized_text`
  benchmark-oriented helpers for internal hotspot attribution and regression
  investigation
* these helpers remain public today, but they are not the main stable semantic
  contract for external consumers

Minimal examples:

```moonbit
let doc = @text.parse_text_document("alpha\n\nbeta\n")
let report = @text.inspect_text_document(doc)

println("lines=" + report.line_count.to_string())
println("paragraphs=" + report.paragraph_count.to_string())
```

```moonbit
let bytes = "hello\r\nworld\r\n".to_bytes()
let doc = @text.open_text_document(bytes)
println(doc.newline_style.to_string())
```

Build on top:

* text chunkers, newline/BOM auditors, and custom literal-text preprocessors
  can reuse `TextDocument` directly without invoking `convert/txt`

Debug / inspect API:

* `inspect_text_document`

Current model:

* `TextDocument`
* `TextLine`
* `TextParagraph`
* `TextNewlineStyle`

Compatibility surface:

* `TextDocument`
* `TextLine`
* `TextParagraph`
* `TextInspectReport`

Internal exposed surface:

* newline detection, line splitting, and paragraph grouping helpers remain
  implementation details rather than a separate helper contract

Current inspect surface:

* `byte_count`
* `char_count`
* `line_count`
* `paragraph_count`
* `empty_line_count`
* `newline_style`
* `is_empty`
* `is_low_signal`

Current parser boundary:

* UTF-8 byte open helper
* BOM handling
* newline normalization / style detection
* line splitting
* paragraph grouping as a structural, not Markdown-semantic, operation

Non-goals:

* `txt_literal_markdown`
* `@core.Document`
* Markdown escaping
* final paragraph rendering policy

Relationship to `convert/txt`:

* `doc_parse/text` owns structural text parsing and inspect
* `convert/txt` still owns cleanup profile choice, literal Markdown policy,
  origin metadata, and IR lowering

Known limits:

* low-signal detection is heuristic and inspect-only
* parser entry does not own final normalization/output policy

Performance note:

* direct string/bytes parsing is intended to be lightweight for small text
  inputs
* CLI timings should still be read separately from direct package timings

Versioning note:

* future release-policy work may still revisit byte-open helpers, low-signal
  heuristics, or field-level visibility, but Markdown/product policy will stay
  in `convert/txt`

Testing:

* lower-layer tests live in `doc_parse/text/tests`
* converter behavior is regression-guarded separately under `convert/txt/test`
