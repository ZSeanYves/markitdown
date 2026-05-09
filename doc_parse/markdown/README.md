# doc_parse/markdown

Purpose:

* lightweight source scanner / raw block inventory foundation for Markdown
* reusable in-tree lower-layer package inside `ZSeanYves/markitdown`
* not a Markdown renderer or passthrough output-policy layer

Current status:

* active foundation hardening Pass 1
* current scope is source scanning / raw block inventory / inspect /
  validation
* `convert/markdown` still owns passthrough output and product normalization

Current public API:

* `scan_markdown_document`
* `inspect_markdown_document`
* `collect_markdown_validation_issues`
* `validate_markdown_document`

Compatibility surface:

* `MarkdownDocument`
* `MarkdownBlock`
* `MarkdownBlockKind`
* `MarkdownFrontmatter`
* `MarkdownFrontmatterKind`
* `MarkdownFencedCodeInfo`
* `MarkdownValidationIssue`
* `MarkdownValidationIssueKind`
* `MarkdownValidationSeverity`
* `MarkdownValidationReport`
* `MarkdownInspectReport`

Internal exposed surface:

* line scanner helpers
* frontmatter and fence detectors
* paragraph grouping helpers
* raw block classification helpers
* these remain implementation details rather than a second public facade

Current model:

* `MarkdownDocument`
* `MarkdownBlock`
* `MarkdownFrontmatter`
* `MarkdownFencedCodeInfo`

Current validation surface:

* `MarkdownValidationIssue`
* `MarkdownValidationReport`
* current issues are intentionally light:
  * `UnclosedFrontmatter`
  * `UnclosedFence`

Current inspect surface:

* line count
* block count
* blank-line count
* heading count
* fenced-code count
* list-item count
* blockquote count
* table-like-row count
* thematic-break count
* html-block-candidate count
* frontmatter count
* issue / warning / error counts

Scanner boundary:

* LF / CRLF / CR normalization
* UTF-8 BOM stripping at the source-string seam
* YAML-style frontmatter detection with `---`
* TOML-style frontmatter detection with `+++`
* fenced-code detection for backtick and tilde fences
* ATX heading raw detection
* Setext heading raw detection with simple underline heuristics
* raw list-marker detection
* raw blockquote detection
* table-like row detection by literal pipe presence only
* thematic-break detection with a simple repeated-marker rule
* HTML-in-Markdown is only a raw candidate signal; it is not parsed as HTML

Non-goals:

* CommonMark full parsing
* Markdown renderer
* Markdown -> IR conversion
* passthrough output policy
* output normalization / cleanup policy
* inline emphasis / link parsing
* table semantics
* MDX / footnotes / extension parsing

Relationship to `convert/markdown`:

* `doc_parse/markdown` owns lightweight source scanning, raw block inventory,
  inspect, and validation
* `convert/markdown` still owns passthrough output, conservative block-to-IR
  wiring, and final product normalization behavior
* this pass does not switch the normal Markdown converter onto the scanner
  foundation

Known limits:

* this is a lightweight scanner, not a full CommonMark parser
* scanner output is string-based and line-oriented rather than a full Markdown
  AST
* frontmatter detection is only recognized at document start
* table-like rows are raw candidates only; no full table parsing is claimed
* HTML block candidates are counted only as raw source signal and are not
  parsed
* scanner findings do not mutate passthrough output or converter policy

Testing:

* lower-layer tests live in `doc_parse/markdown/tests`
* converter regression remains guarded under `convert/markdown/test`

Versioning note:

* this package is an in-tree hardening line, not a candidate closure yet
* current scanner intentionally always succeeds and therefore does not expose a
  hard parse-error classifier in Pass 1
* future work may widen scanner coverage or add more structured warnings
  without changing `convert/markdown` ownership
