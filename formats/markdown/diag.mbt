///|
fn markdown_parse_result_from_scanned(
  source : @input.InputSource,
  context : @parser.ParseContext,
  scanned : @dmd.MarkdownDocument,
  inspect : @dmd.MarkdownInspectReport,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "markdown_parser",
    DomAstModel,
    source,
    "markdown",
  )
  diagnostics.metrics.set("parser_name", "markdown_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "markdown")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  let requested_blocks = context.requested_mode == Some(BlockStreaming)
  markdown_set_route_metrics(diagnostics, requested_blocks)
  diagnostics.metrics.set("event_granularity", "markdown_block")
  diagnostics.metrics.set(
    "event_semantics",
    if requested_blocks {
      "markdown_block_stream"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("block_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "markdown")
  markdown_apply_scan_metrics(diagnostics, inspect)
  markdown_apply_validation_issues(diagnostics, scanned.issues)
  let blocks = markdown_lowered_blocks_for_mode(
    scanned, source, diagnostics, requested_blocks,
  )
  if requested_blocks {
    markdown_block_stream_parse_result(blocks, diagnostics)
  } else {
    markdown_document_parse_result(blocks, diagnostics)
  }
}

///|
fn markdown_set_route_metrics(
  diagnostics : @core.Diagnostics,
  requested_blocks : Bool,
) -> Unit {
  diagnostics.metrics.set(
    "effective_mode",
    if requested_blocks {
      "block_streaming"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set(
    "ir_input_kind",
    if requested_blocks {
      "block_stream"
    } else {
      "document"
    },
  )
}

///|
fn markdown_apply_block_report_metrics(
  diagnostics : @core.Diagnostics,
  report : MarkdownBlockReport,
  block_count : Int,
) -> Unit {
  diagnostics.metrics.set("block_count", block_count.to_string())
  diagnostics.metrics.set("paragraph_count", report.paragraph_count.to_string())
  diagnostics.metrics.set("list_count", report.list_count.to_string())
  diagnostics.metrics.set("table_count", report.table_count.to_string())
  diagnostics.metrics.set(
    "code_block_count",
    report.code_block_count.to_string(),
  )
  diagnostics.metrics.set(
    "blockquote_count",
    report.blockquote_count.to_string(),
  )
  diagnostics.metrics.set("link_count", report.link_count.to_string())
  diagnostics.metrics.set("image_count", report.image_count.to_string())
  diagnostics.metrics.set("raw_html_count", report.raw_html_count.to_string())
  diagnostics.metrics.set(
    "unsafe_link_count",
    report.unsafe_link_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_html_count",
    report.unsafe_html_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_list_depth_observed",
    report.max_list_depth.to_string(),
  )
  diagnostics.metrics.set("asset_count", report.asset_count.to_string())
  diagnostics.metrics.set(
    "footnote_definition_count",
    report.footnote_definition_count.to_string(),
  )
  diagnostics.metrics.set(
    "footnote_reference_count",
    report.footnote_reference_count.to_string(),
  )
}

///|
fn markdown_block_stream_parse_result(
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
) -> @parser.ParseResult {
  diagnostics.metrics.set("event_count", "0")
  diagnostics.pass_trace.push("parse:markdown_parser")
  @parser.parse_result_with_blocks_capability(
    "markdown_parser",
    BlockStreaming,
    blocks,
    diagnostics,
    markdown_parser_capability(),
  )
}

///|
fn markdown_document_parse_result(
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
) -> @parser.ParseResult {
  diagnostics.metrics.set("event_count", "0")
  diagnostics.pass_trace.push("parse:markdown_parser")
  let document = @core.document_from_blocks(blocks)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "markdown_parser",
    DomAstModel,
    final_document,
    diagnostics,
    markdown_parser_capability(),
  )
}

///|
fn markdown_block_kind_name(kind : @dmd.MarkdownBlockKind) -> String {
  match kind {
    ParagraphLike => "paragraph"
    HeadingAtx => "heading_atx"
    HeadingSetext => "heading_setext"
    FencedCode => "fenced_code"
    ListItem => "list_item"
    BlockQuote => "blockquote"
    TableLikeRow => "table_like_row"
    ThematicBreak => "thematic_break"
    HtmlBlockCandidate => "html_block_candidate"
    BlankLine => "blank"
    Other => "other"
  }
}

///|
priv struct MarkdownBlockReport {
  paragraph_count : Int
  list_count : Int
  table_count : Int
  code_block_count : Int
  blockquote_count : Int
  link_count : Int
  image_count : Int
  raw_html_count : Int
  unsafe_link_count : Int
  unsafe_html_count : Int
  asset_count : Int
  max_list_depth : Int
  footnote_definition_count : Int
  footnote_reference_count : Int
}

///|
fn markdown_apply_scan_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dmd.MarkdownInspectReport,
) -> Unit {
  diagnostics.metrics.set("line_count", inspect.line_count.to_string())
  diagnostics.metrics.set(
    "block_inventory_count",
    inspect.block_count.to_string(),
  )
  diagnostics.metrics.set(
    "blank_line_count",
    inspect.blank_line_count.to_string(),
  )
  diagnostics.metrics.set("heading_count", inspect.heading_count.to_string())
  diagnostics.metrics.set(
    "fenced_code_count",
    inspect.fenced_code_count.to_string(),
  )
  diagnostics.metrics.set(
    "unclosed_fence_count",
    inspect.unclosed_fence_count.to_string(),
  )
  diagnostics.metrics.set(
    "list_item_count",
    inspect.list_item_count.to_string(),
  )
  diagnostics.metrics.set(
    "blockquote_count",
    inspect.blockquote_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_like_row_count",
    inspect.table_like_row_count.to_string(),
  )
  diagnostics.metrics.set(
    "thematic_break_count",
    inspect.thematic_break_count.to_string(),
  )
  diagnostics.metrics.set(
    "html_block_candidate_count",
    inspect.html_block_candidate_count.to_string(),
  )
  diagnostics.metrics.set(
    "frontmatter_count",
    inspect.frontmatter_count.to_string(),
  )
  diagnostics.metrics.set(
    "frontmatter_seen",
    @fshared.bool_string(inspect.has_frontmatter),
  )
  diagnostics.metrics.set(
    "has_frontmatter",
    @fshared.bool_string(inspect.has_frontmatter),
  )
  diagnostics.metrics.set("is_empty", @fshared.bool_string(inspect.is_empty))
}

///|
fn markdown_apply_validation_issues(
  diagnostics : @core.Diagnostics,
  issues : Array[@dmd.MarkdownValidationIssue],
) -> Unit {
  let mut warning_count = 0
  let mut error_count = 0
  for validation_issue in issues {
    diagnostics.warnings.push(validation_issue.message)
    diagnostics.fallback_trace.push(
      markdown_validation_issue_trace(validation_issue),
    )
    diagnostics.degraded_features.push(
      markdown_validation_issue_feature(validation_issue),
    )
    match validation_issue.severity {
      Warning => warning_count += 1
      Error => error_count += 1
    }
  }
  diagnostics.metrics.set("warning_count", warning_count.to_string())
  diagnostics.metrics.set("error_count", error_count.to_string())
  diagnostics.metrics.set(
    "issue_count",
    (warning_count + error_count).to_string(),
  )
}

///|
priv struct MarkdownBlockReportAccumulator {
  paragraph_count : Ref[Int]
  list_count : Ref[Int]
  table_count : Ref[Int]
  code_block_count : Ref[Int]
  blockquote_count : Ref[Int]
  link_count : Ref[Int]
  image_count : Ref[Int]
  raw_html_count : Ref[Int]
  unsafe_link_count : Ref[Int]
  unsafe_html_count : Ref[Int]
  asset_count : Ref[Int]
  max_list_depth : Ref[Int]
  footnote_definition_count : Ref[Int]
  footnote_reference_count : Ref[Int]
}

///|
fn markdown_new_block_report_accumulator() -> MarkdownBlockReportAccumulator {
  {
    paragraph_count: { val: 0 },
    list_count: { val: 0 },
    table_count: { val: 0 },
    code_block_count: { val: 0 },
    blockquote_count: { val: 0 },
    link_count: { val: 0 },
    image_count: { val: 0 },
    raw_html_count: { val: 0 },
    unsafe_link_count: { val: 0 },
    unsafe_html_count: { val: 0 },
    asset_count: { val: 0 },
    max_list_depth: { val: 0 },
    footnote_definition_count: { val: 0 },
    footnote_reference_count: { val: 0 },
  }
}

///|
fn markdown_block_report_from_accumulator(
  report : MarkdownBlockReportAccumulator,
) -> MarkdownBlockReport {
  {
    paragraph_count: report.paragraph_count.val,
    list_count: report.list_count.val,
    table_count: report.table_count.val,
    code_block_count: report.code_block_count.val,
    blockquote_count: report.blockquote_count.val,
    link_count: report.link_count.val,
    image_count: report.image_count.val,
    raw_html_count: report.raw_html_count.val,
    unsafe_link_count: report.unsafe_link_count.val,
    unsafe_html_count: report.unsafe_html_count.val,
    asset_count: report.asset_count.val,
    max_list_depth: report.max_list_depth.val,
    footnote_definition_count: report.footnote_definition_count.val,
    footnote_reference_count: report.footnote_reference_count.val,
  }
}

///|
fn markdown_accumulate_single_block_report(
  block : @core.CoreBlock,
  report : MarkdownBlockReportAccumulator,
  list_depth : Int,
) -> Unit {
  match block.kind {
    Paragraph => report.paragraph_count.val += 1
    List => {
      report.list_count.val += 1
      if list_depth + 1 > report.max_list_depth.val {
        report.max_list_depth.val = list_depth + 1
      }
    }
    Table => report.table_count.val += 1
    Code => report.code_block_count.val += 1
    BlockQuote => report.blockquote_count.val += 1
    Image => {
      report.image_count.val += 1
      report.asset_count.val += 1
    }
    Raw =>
      if block.attrs.get("raw_kind") == Some("markdown_html_literal") {
        report.raw_html_count.val += 1
        if block.attrs.get("unsafe_html") == Some("true") {
          report.unsafe_html_count.val += 1
        }
      } else if block.attrs.get("raw_kind") ==
        Some("markdown_footnote_definition") {
        report.footnote_definition_count.val += 1
      }
    _ => ()
  }
  match block.rich_inlines {
    Some(inlines) =>
      for inline in inlines {
        match inline.kind {
          Link => report.link_count.val += 1
          Image => {
            report.image_count.val += 1
            report.asset_count.val += 1
          }
          Text =>
            if inline.attrs.get("annotation_kind") == Some("footnote") &&
              inline.attrs.get("annotation_role") == Some("note_ref") {
              report.footnote_reference_count.val += 1
            }
          _ => ()
        }
      }
    None => ()
  }
  match block.attrs.get("unsafe_link_count") {
    Some("1") => report.unsafe_link_count.val += 1
    Some("2") => report.unsafe_link_count.val += 2
    Some("3") => report.unsafe_link_count.val += 3
    Some("4") => report.unsafe_link_count.val += 4
    Some("5") => report.unsafe_link_count.val += 5
    _ => ()
  }
}

///|
fn markdown_validation_issue_feature(
  issue : @dmd.MarkdownValidationIssue,
) -> String {
  match issue.kind {
    UnclosedFence => "markdown_unclosed_fence"
    UnclosedFrontmatter => "markdown_unclosed_frontmatter"
    UnknownFrontmatterKind => "markdown_unknown_frontmatter_kind"
    SuspiciousTableRow => "markdown_table_like_raw_fallback"
  }
}

///|
fn markdown_validation_issue_trace(
  issue : @dmd.MarkdownValidationIssue,
) -> String {
  match issue.kind {
    UnclosedFence => "markdown unclosed fence -> code fallback"
    UnclosedFrontmatter => "markdown unclosed frontmatter -> raw metadata block"
    UnknownFrontmatterKind =>
      "markdown unknown frontmatter kind -> raw metadata block"
    SuspiciousTableRow => "markdown suspicious table row -> raw block"
  }
}
