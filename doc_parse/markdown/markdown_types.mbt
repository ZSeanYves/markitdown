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
/// Frontmatter kinds recognized by the lightweight scanner.
pub(all) enum MarkdownFrontmatterKind {
  Yaml
  Toml
  Unknown
} derive(Eq)

///|
/// Frontmatter captured from the top of a Markdown source file.
pub struct MarkdownFrontmatter {
  kind : MarkdownFrontmatterKind
  line_start : Int
  line_end : Int
  content : String
  closed : Bool
}

///|
/// Raw fenced-code details preserved by the scanner.
pub struct MarkdownFencedCodeInfo {
  fence_char : Char
  fence_length : Int
  info_string : String?
  closed : Bool
}

///|
/// A raw Markdown block inventory entry.
pub struct MarkdownBlock {
  kind : MarkdownBlockKind
  line_start : Int
  line_end : Int
  raw_text : String
  fenced_code : MarkdownFencedCodeInfo?
}

///|
/// Scanner result for a Markdown source document.
pub struct MarkdownDocument {
  source_length : Int
  line_count : Int
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
pub(all) enum MarkdownValidationIssueKind {
  UnclosedFence
  UnclosedFrontmatter
  UnknownFrontmatterKind
  SuspiciousTableRow
} derive(Eq)

///|
/// Validation issues surfaced by the scanner without turning scanning into a
/// hard parse failure.
pub struct MarkdownValidationIssue {
  kind : MarkdownValidationIssueKind
  severity : MarkdownValidationSeverity
  line_start : Int?
  line_end : Int?
  message : String
}

///|
/// Aggregated validation report for Markdown scanner issues.
pub struct MarkdownValidationReport {
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[MarkdownValidationIssue]
}

///|
/// Structural summary for a scanned Markdown document.
pub struct MarkdownInspectReport {
  line_count : Int
  block_count : Int
  blank_line_count : Int
  heading_count : Int
  fenced_code_count : Int
  unclosed_fence_count : Int
  list_item_count : Int
  blockquote_count : Int
  table_like_row_count : Int
  thematic_break_count : Int
  html_block_candidate_count : Int
  frontmatter_count : Int
  has_frontmatter : Bool
  issue_count : Int
  warning_count : Int
  error_count : Int
  is_empty : Bool
}
