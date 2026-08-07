///|
/// Return Markdown scanner findings as explicit validation issues.
pub fn collect_markdown_validation_issues(
  doc : MarkdownDocument,
) -> Array[MarkdownValidationIssue] {
  doc.issues
}

///|
/// Aggregate Markdown validation counts and issues into a deterministic report.
pub fn validate_markdown_document(
  doc : MarkdownDocument,
) -> MarkdownValidationReport {
  let issues = collect_markdown_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0
  for issue in issues {
    match issue.severity {
      Warning => warning_count += 1
      Error => error_count += 1
    }
  }
  { issue_count: issues.length(), warning_count, error_count, issues }
}

///|
/// Summarize structure for a scanned Markdown document.
pub fn inspect_markdown_document(
  doc : MarkdownDocument,
) -> MarkdownInspectReport {
  let validation = validate_markdown_document(doc)
  let mut blank_line_count = 0
  let mut heading_count = 0
  let mut fenced_code_count = 0
  let mut unclosed_fence_count = 0
  let mut list_item_count = 0
  let mut blockquote_count = 0
  let mut table_like_row_count = 0
  let mut thematic_break_count = 0
  let mut html_block_candidate_count = 0

  for block in doc.blocks {
    match block.kind {
      BlankLine => blank_line_count += 1
      HeadingAtx | HeadingSetext => heading_count += 1
      FencedCode => {
        fenced_code_count += 1
        match block.fenced_code {
          Some(info) => if !info.closed { unclosed_fence_count += 1 }
          None => ()
        }
      }
      ListItem => list_item_count += 1
      BlockQuote => blockquote_count += 1
      TableLikeRow => table_like_row_count += 1
      ThematicBreak => thematic_break_count += 1
      HtmlBlockCandidate => html_block_candidate_count += 1
      _ => ()
    }
  }

  {
    line_count: doc.line_count,
    block_count: doc.blocks.length(),
    blank_line_count,
    heading_count,
    fenced_code_count,
    unclosed_fence_count,
    list_item_count,
    blockquote_count,
    table_like_row_count,
    thematic_break_count,
    html_block_candidate_count,
    frontmatter_count: if doc.frontmatter is Some(_) {
      1
    } else {
      0
    },
    has_frontmatter: doc.frontmatter is Some(_),
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
    is_empty: doc.frontmatter is None && doc.blocks.length() == 0,
  }
}
