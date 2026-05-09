# doc_parse/text

Purpose:

* plain-text structural parser/model/inspect foundation
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a literal-Markdown policy layer

Current status:

* internal foundation hardening
* not yet labeled as a standalone publishable package candidate

Public API:

* `open_text_document`
* `parse_text_document`
* `inspect_text_document`
* `classify_text_error`

Current model:

* `TextDocument`
* `TextLine`
* `TextParagraph`
* `TextNewlineStyle`

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

Testing:

* lower-layer tests live in `doc_parse/text/tests`
* converter behavior is regression-guarded separately under `convert/txt/test`
