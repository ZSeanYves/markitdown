///|
/// Raw block classes reported by the lightweight Markdown scanner.
pub(all) enum MarkdownBlockKind {
  ParagraphLike
  HeadingAtx
  HeadingSetext
  FencedCode
  ListItem
  BlockQuote
  TableLikeRow
  ThematicBreak
  HtmlBlockCandidate
  BlankLine
  Other
} derive(Eq)

///|
pub extend MarkdownBlockKind with Eq::{equal, not_equal}

///|
/// Frontmatter kinds recognized by the lightweight scanner.
pub(all) enum MarkdownFrontmatterKind {
  Yaml
  Toml
  Unknown
} derive(Eq)

///|
pub extend MarkdownFrontmatterKind with Eq::{equal, not_equal}

///|
/// Frontmatter captured from the top of a Markdown source file.
pub struct MarkdownFrontmatter {
  kind : MarkdownFrontmatterKind
  line_start : Int32
  line_end : Int32
  content : String
  closed : Bool
}

///|
/// Raw fenced-code details preserved by the scanner.
pub struct MarkdownFencedCodeInfo {
  fence_char : Char
  fence_length : Int32
  info_string : String?
  closed : Bool
}

///|
/// A raw Markdown block inventory entry.
pub struct MarkdownBlock {
  kind : MarkdownBlockKind
  line_start : Int32
  line_end : Int32
  raw_text : String
  fenced_code : MarkdownFencedCodeInfo?
}

///|
/// Scanner result for a Markdown source document.
pub struct MarkdownDocument {
  source_length : Int32
  line_count : Int32
  blocks : Array[MarkdownBlock]
  frontmatter : MarkdownFrontmatter?
  issues : Array[MarkdownValidationIssue]
}

///|
pub(all) enum MarkdownValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub extend MarkdownValidationSeverity with Eq::{equal, not_equal}

///|
pub(all) enum MarkdownValidationIssueKind {
  UnclosedFence
  UnclosedFrontmatter
  UnknownFrontmatterKind
  SuspiciousTableRow
} derive(Eq)

///|
pub extend MarkdownValidationIssueKind with Eq::{equal, not_equal}

///|
/// Validation issues surfaced by the scanner without turning scanning into a
/// hard parse failure.
pub struct MarkdownValidationIssue {
  kind : MarkdownValidationIssueKind
  severity : MarkdownValidationSeverity
  line_start : Int32?
  line_end : Int32?
  message : String
}

///|
/// Aggregated validation report for Markdown scanner issues.
pub struct MarkdownValidationReport {
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  issues : Array[MarkdownValidationIssue]
}

///|
/// Structural summary for a scanned Markdown document.
pub struct MarkdownInspectReport {
  line_count : Int32
  block_count : Int32
  blank_line_count : Int32
  heading_count : Int32
  fenced_code_count : Int32
  unclosed_fence_count : Int32
  list_item_count : Int32
  blockquote_count : Int32
  table_like_row_count : Int32
  thematic_break_count : Int32
  html_block_candidate_count : Int32
  frontmatter_count : Int32
  has_frontmatter : Bool
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  is_empty : Bool
}
