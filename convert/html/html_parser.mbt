///|
const HTML_PARSER_VALIDATION_MAX_BYTES : Int = 2 * 1024 * 1024

///|
pub(all) struct HtmlParserIssueSummary {
  issue_count : Int
  warning_count : Int
  error_count : Int
  script_count : Int
  style_count : Int
  unsafe_url_count : Int
  duplicate_attribute_count : Int
  unexpected_closing_count : Int
  unclosed_element_count : Int
}

///|
priv struct HtmlParserSourceAnalysis {
  text : String
  events : Array[@dphtml.HtmlTokenEvent]
  summary : HtmlParserIssueSummary?
}

///|
priv struct HtmlSourceRange {
  start : Int
  end_ : Int
}

///|
priv struct HtmlByteRange {
  start : Int
  end_ : Int
}

///|
priv struct HtmlScopedContent {
  bytes : Bytes
  skip_ranges : Array[HtmlByteRange]
  scope_from_events : Bool
  scope_fallback_reason : String
}

///|
priv struct HtmlProfileBlockCounts {
  table_count : Int
  image_count : Int
  link_count : Int
  note_ref_count : Int
}

///|
/// HTML converter entrypoint.
///
/// Model boundary:
/// - uses a lightweight DOM-like semantic scan (not browser layout engine)
/// - focuses on robust structural blocks for markdown + metadata sidecar
/// - keeps provenance lightweight at block/asset level
pub fn parse_html(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let profile = if html_profile_enabled() {
    Some(new_html_profile_report(input_path))
  } else {
    None
  }

  let read_started = html_profile_start_tick(profile)
  let raw_bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }
  html_profile_add_stage(
    profile,
    "html_file_read",
    html_profile_elapsed_since(read_started),
    match profile {
      Some(_) => Some("bytes=" + raw_bs.length().to_string())
      None => None
    },
  )

  let normalize_started = html_profile_start_tick(profile)
  let bs = normalize_html_input_bytes(raw_bs)
  let parser_analysis = maybe_analyze_html_source(
    bs,
    profile,
  )
  let scoped_content = narrow_html_content_scope(bs, parser_analysis)
  let scoped_bs = scoped_content.bytes
  html_profile_set_scope_observability(
    profile,
    scoped_content.scope_from_events,
    scoped_content.skip_ranges.length(),
    scoped_content.scope_fallback_reason,
  )
  html_profile_add_stage(
    profile,
    "html_normalize_bytes",
    html_profile_elapsed_since(normalize_started),
    match profile {
      Some(_) =>
        Some(
          "bytes=" +
          bs.length().to_string() +
          " scoped_bytes=" +
          scoped_bs.length().to_string(),
        )
      None => None
    },
  )

  let doc = @cor.new_document()
  let note_definitions = scan_html_notes(scoped_bs)

  html_profile_set_active(profile)
  defer html_profile_set_active(None)

  let scan_started = html_profile_start_tick(profile)
  let nodes = scan_html_nodes_with_skip_ranges(
    scoped_bs,
    scoped_content.skip_ranges,
  )
  html_profile_add_stage(
    profile,
    "html_dom_scan",
    html_profile_elapsed_since(scan_started),
    match profile {
      Some(_) => Some("nodes=" + nodes.length().to_string())
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_parser_validation",
    0,
    match profile {
      Some(_) =>
        match parser_analysis {
          Some(analysis) =>
            analysis.summary.map(render_html_parser_issue_summary_detail)
          None => render_html_parser_analysis_fallback_detail(bs)
        }
      None => None
    },
  )

  let lowering_started = html_profile_start_tick(profile)
  let html_blocks = nodes_to_blocks(nodes, max_heading, input_path, out_dir)
  html_profile_add_stage(
    profile,
    "html_block_lowering",
    html_profile_elapsed_since(lowering_started),
    match profile {
      Some(rep) =>
        Some(
          render_html_block_lowering_profile_detail(
            html_blocks.blocks,
            note_definitions.length(),
            rep,
          ),
        )
      None => None
    },
  )
  let blocks = html_blocks.blocks
  let src = @cor.basename(input_path)
  let mut asset_idx = 0

  for i in 0..<blocks.length() {
    match blocks[i] {
      @cor.Block::Image(_alt, path) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: None,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      @cor.Block::ImageBlock(img) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, img.path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: img.caption,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(img.path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      _ => ()
    }

    @cor.push_with_origin(
      doc,
      blocks[i],
      html_block_origin_with_index(
        html_blocks.block_origins[i],
        src,
        doc.blocks.val.length(),
      ),
    )
  }

  for note in note_definitions {
    @cor.push_note_definition(doc, note)
  }

  html_profile_add_stage(
    profile,
    "html_asset_discovery",
    match profile {
      Some(rep) => rep.asset_discovery_elapsed_ms.val
      None => 0
    },
    match profile {
      Some(rep) =>
        Some(
          "local_asset_count=" +
          rep.local_asset_count.val.to_string() +
          " remote_asset_count=" +
          rep.remote_asset_count.val.to_string() +
          " unresolved_local_asset_count=" +
          rep.unresolved_local_asset_count.val.to_string(),
        )
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_asset_export",
    match profile {
      Some(rep) => rep.asset_export_elapsed_ms.val
      None => 0
    },
    match profile {
      Some(rep) =>
        Some(
          "local_asset_count=" +
          rep.local_asset_count.val.to_string() +
          " cached_asset_count=" +
          rep.cached_asset_count.val.to_string(),
        )
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_document_build",
    0,
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )

  maybe_write_html_profile_log(profile)
  doc
}

///|
fn maybe_analyze_html_source(
  bs : Bytes,
  profile : HtmlProfileReport?,
) -> HtmlParserSourceAnalysis? {
  html_profile_mark_parser_analysis_attempted(profile)
  if bs.length() > HTML_PARSER_VALIDATION_MAX_BYTES {
    html_profile_mark_parser_skipped_large_input(profile)
    return None
  }

  let text = @utf8.decode(bs, ignore_bom=false) catch {
    _ => {
      html_profile_mark_parser_fallback(profile)
      return None
    }
  }

  let analyzed = try? @dphtml.analyze_html_source(text)
  match analyzed {
    Ok(analysis) => {
      let summary = match profile {
        Some(_) => {
          let validation = @dphtml.validate_html_document(analysis.document)
          let summary = summarize_html_parser_validation(validation)
          html_profile_set_parser_issue_summary(profile, summary)
          Some(summary)
        }
        None => None
      }
      html_profile_mark_parser_analysis_used(profile)
      Some({
        text,
        events: analysis.events,
        summary,
      })
    }
    Err(_) => {
      html_profile_mark_parser_fallback(profile)
      None
    }
  }
}

///|
fn render_html_parser_analysis_fallback_detail(bs : Bytes) -> String? {
  if bs.length() > HTML_PARSER_VALIDATION_MAX_BYTES {
    Some("status=skipped_large_input bytes=" + bs.length().to_string())
  } else {
    Some("status=fallback_parse_error")
  }
}

///|
pub fn summarize_html_parser_validation(
  validation : @dphtml.HtmlValidationReport,
) -> HtmlParserIssueSummary {
  let mut script_count = 0
  let mut style_count = 0
  let mut unsafe_url_count = 0
  let mut duplicate_attribute_count = 0
  let mut unexpected_closing_count = 0
  let mut unclosed_element_count = 0

  for issue in validation.issues {
    match issue.kind {
      @dphtml.HtmlValidationIssueKind::ScriptElement => script_count += 1
      @dphtml.HtmlValidationIssueKind::StyleElement => style_count += 1
      @dphtml.HtmlValidationIssueKind::UnsafeUrl => unsafe_url_count += 1
      @dphtml.HtmlValidationIssueKind::DuplicateAttribute =>
        duplicate_attribute_count += 1
      @dphtml.HtmlValidationIssueKind::UnexpectedClosingTag =>
        unexpected_closing_count += 1
      @dphtml.HtmlValidationIssueKind::UnclosedElement =>
        unclosed_element_count += 1
      _ => ()
    }
  }

  {
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
    script_count,
    style_count,
    unsafe_url_count,
    duplicate_attribute_count,
    unexpected_closing_count,
    unclosed_element_count,
  }
}

///|
pub fn collect_html_parser_issue_summary_from_text(
  text : String,
) -> HtmlParserIssueSummary? {
  let parsed = try? @dphtml.parse_html_document(text)
  match parsed {
    Ok(doc) => Some(summarize_html_parser_validation(@dphtml.validate_html_document(doc)))
    Err(_) => None
  }
}

///|
fn render_html_block_lowering_profile_detail(
  blocks : Array[@cor.Block],
  note_definition_count : Int,
  report : HtmlProfileReport,
) -> String {
  let counts = count_html_profile_blocks(blocks)
  "blocks=" +
  blocks.length().to_string() +
  " table_count=" +
  counts.table_count.to_string() +
  " image_count=" +
  counts.image_count.to_string() +
  " link_count=" +
  counts.link_count.to_string() +
  " note_definition_count=" +
  note_definition_count.to_string() +
  " note_ref_count=" +
  counts.note_ref_count.to_string() +
  " local_asset_count=" +
  report.local_asset_count.val.to_string() +
  " remote_asset_count=" +
  report.remote_asset_count.val.to_string() +
  " unresolved_local_asset_count=" +
  report.unresolved_local_asset_count.val.to_string() +
  " cached_asset_count=" +
  report.cached_asset_count.val.to_string()
}

///|
fn count_html_profile_blocks(blocks : Array[@cor.Block]) -> HtmlProfileBlockCounts {
  let mut table_count = 0
  let mut image_count = 0
  let mut link_count = 0
  let mut note_ref_count = 0

  for block in blocks {
    match block {
      @cor.Block::RichHeading(_, inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichParagraph(inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichListItem(_, _, inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichBlockQuote(inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::Table(_) | @cor.Block::RichTable(_) => table_count += 1
      @cor.Block::Image(_, _) | @cor.Block::ImageBlock(_) => image_count += 1
      _ => ()
    }
  }

  { table_count, image_count, link_count, note_ref_count }
}

///|
fn count_html_profile_inlines(inlines : Array[@cor.Inline]) -> (Int, Int) {
  let mut link_count = 0
  let mut note_ref_count = 0
  for inline in inlines {
    match inline {
      @cor.Inline::Link(_, _) => link_count += 1
      @cor.Inline::NoteRef(_) => note_ref_count += 1
      _ => ()
    }
  }
  (link_count, note_ref_count)
}

///|
fn render_html_parser_issue_summary_detail(
  summary : HtmlParserIssueSummary,
) -> String {
  "issue_count=" +
  summary.issue_count.to_string() +
  " warning_count=" +
  summary.warning_count.to_string() +
  " error_count=" +
  summary.error_count.to_string() +
  " script_count=" +
  summary.script_count.to_string() +
  " style_count=" +
  summary.style_count.to_string() +
  " unsafe_url_count=" +
  summary.unsafe_url_count.to_string() +
  " duplicate_attribute_count=" +
  summary.duplicate_attribute_count.to_string() +
  " unexpected_closing_count=" +
  summary.unexpected_closing_count.to_string() +
  " unclosed_element_count=" +
  summary.unclosed_element_count.to_string()
}

///|
fn normalize_html_input_bytes(bs : Bytes) -> Bytes {
  let n = bs.length()
  let mut start = 0
  if n >= 3 && bs[0] == 0xEF && bs[1] == 0xBB && bs[2] == 0xBF {
    start = 3
  }

  let out : Array[Byte] = []
  let mut i = start
  while i < n {
    let b = bs[i]
    if b == '\r'.to_int().to_byte() {
      out.push('\n'.to_int().to_byte())
      if i + 1 < n && bs[i + 1] == '\n'.to_int().to_byte() {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(b)
      i = i + 1
    }
  }

  Bytes::from_array(out)
}

///|
fn narrow_html_content_scope(
  bs : Bytes,
  parser_analysis : HtmlParserSourceAnalysis?,
) -> HtmlScopedContent {
  match parser_analysis {
    Some(analysis) => {
      let mut scope_from_events = true
      let mut fallback_reason = ""
      let range = match find_html_content_scope_range_from_events(analysis.events) {
        Some(range) => range
        None =>
          match find_html_tag_block_range_from_events(analysis.events, "body") {
            Some(range) => range
            None => {
              scope_from_events = false
              fallback_reason = "no_event_scope"
              { start: 0, end_: analysis.text.length() }
            }
          }
      }
      {
        bytes: html_source_range_to_bytes(analysis.text, range),
        skip_ranges: html_skip_ranges_for_content(
          analysis.text,
          analysis.events,
          range,
        ),
        scope_from_events,
        scope_fallback_reason: fallback_reason,
      }
    }
    None => {
      bytes: narrow_html_content_scope_fallback(bs),
      skip_ranges: [],
      scope_from_events: false,
      scope_fallback_reason: "no_parser_analysis",
    }
  }
}

///|
fn html_source_range_to_bytes(text : String, range : HtmlSourceRange) -> Bytes {
  if range.start < 0 || range.end_ < range.start || range.end_ > text.length() {
    return @utf8.encode("")
  }
  @utf8.encode(text[range.start:range.end_].to_owned())
}

///|
fn html_skip_ranges_for_content(
  text : String,
  events : Array[@dphtml.HtmlTokenEvent],
  content_range : HtmlSourceRange,
) -> Array[HtmlByteRange] {
  let ranges = @dphtml.html_tokens_collect_element_ranges(
    events,
    ["script", "style", "head", "noscript"],
  )
  let out : Array[HtmlByteRange] = []
  for range in ranges {
    let start = max_int(range.source_start, content_range.start)
    let end_ = min_int(range.source_end, content_range.end_)
    if end_ > start {
      out.push({
        start: html_source_offset_to_relative_byte(
          text,
          content_range.start,
          start,
        ),
        end_: html_source_offset_to_relative_byte(
          text,
          content_range.start,
          end_,
        ),
      })
    }
  }
  out
}

///|
fn html_source_offset_to_relative_byte(
  text : String,
  base : Int,
  offset : Int,
) -> Int {
  if offset <= base {
    0
  } else {
    @utf8.encode(text[base:offset].to_owned()).length()
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b { a } else { b }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b { a } else { b }
}

///|
fn find_html_content_scope_range_from_events(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  match find_html_scope_range_with_exact_root_token(events) {
    Some(range) => Some(range)
    None =>
      match find_html_scope_range_with_exact_content_id(events) {
        Some(range) => Some(range)
        None =>
          match find_html_scope_range_with_role_main(events) {
            Some(range) => Some(range)
            None =>
              match find_html_scope_range_with_strong_content_attr(events) {
                Some(range) => Some(range)
                None =>
                  match find_html_tag_block_range_from_events(events, "article") {
                    Some(range) => Some(range)
                    None => find_html_tag_block_range_from_events(events, "main")
                  }
              }
          }
      }
  }
}

///|
fn find_html_scope_range_with_exact_root_token(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    (
      html_scope_event_attr_contains_exact_root_token(event, "id") ||
      html_scope_event_attr_contains_exact_root_token(event, "class")
    )
  })
}

///|
fn find_html_scope_range_with_strong_content_attr(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    !html_scope_event_attr_value_has_noise_token(event, "id") &&
    !html_scope_event_attr_value_has_noise_token(event, "class") &&
    (
      html_scope_event_attr_is_strong_content_root(event, "id") ||
      html_scope_event_attr_is_strong_content_root(event, "class")
    )
  })
}

///|
fn find_html_scope_range_with_exact_content_id(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    html_scope_event_attr_is_exact_content_id(event, "id")
  })
}

///|
fn find_html_scope_range_with_role_main(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    html_scope_event_role_is_main(event)
  })
}

///|
fn find_html_tag_block_range_from_events(
  events : Array[@dphtml.HtmlTokenEvent],
  tag_name : String,
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    event.tag_name == tag_name
  })
}

///|
fn find_html_container_range_matching_events(
  events : Array[@dphtml.HtmlTokenEvent],
  matcher : (@dphtml.HtmlTokenEvent) -> Bool,
) -> HtmlSourceRange? {
  for i in 0..<events.length() {
    let event = events[i]
    if event.kind == @dphtml.HtmlTokenEventKind::StartTag && matcher(event) {
      match @dphtml.html_tokens_find_matching_close(events, i) {
        Some(close_i) =>
          return Some({
            start: event.source_end,
            end_: events[close_i].source_start,
          })
        None => ()
      }
    }
  }
  None
}

///|
fn html_scope_event_attr_contains_exact_root_token(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower()
      lower.contains("mw-content-text") || lower.contains("bodycontent")
    }
  }
}

///|
fn html_scope_event_attr_is_strong_content_root(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => {
      let words = html_scope_attr_words(value)
      let has_body = html_scope_words_contain(words, "body")
      let has_content = html_scope_words_contain(words, "content")
      (has_body && has_content) ||
      (html_scope_words_contain(words, "article") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "post") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "entry") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "story") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "chapter") && (has_body || has_content))
    }
  }
}

///|
fn html_scope_event_attr_is_exact_content_id(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower().trim().to_owned()
      lower == "content" || lower == "maincontent"
    }
  }
}

///|
fn html_scope_event_role_is_main(event : @dphtml.HtmlTokenEvent) -> Bool {
  @dphtml.html_token_event_attr_value(event, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_scope_event_attr_value_has_noise_token(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => html_contains_noise_token(value.to_lower())
  }
}

///|
fn narrow_html_content_scope_fallback(bs : Bytes) -> Bytes {
  match find_html_content_scope_inner(bs) {
    Some(inner) => inner
    None =>
      match find_tag_block_inner(bs, "body") {
        Some(inner) => inner
        None => bs
      }
  }
}

///|
fn find_html_content_scope_inner(bs : Bytes) -> Bytes? {
  match find_html_scope_inner_with_exact_root_token(bs) {
    Some(inner) => Some(inner)
    None =>
      match find_html_scope_inner_with_exact_content_id(bs) {
        Some(inner) => Some(inner)
        None =>
          match find_html_scope_inner_with_role_main(bs) {
            Some(inner) => Some(inner)
            None =>
              match find_html_scope_inner_with_strong_content_attr(bs) {
                Some(inner) => Some(inner)
                None =>
                  match find_tag_block_inner(bs, "article") {
                    Some(inner) => Some(inner)
                    None => find_tag_block_inner(bs, "main")
                  }
              }
          }
      }
  }
}

///|
fn find_html_scope_inner_with_exact_root_token(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    (
      html_scope_attr_contains_exact_root_token(tag, "id") ||
      html_scope_attr_contains_exact_root_token(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_strong_content_attr(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    !html_attr_value_has_noise_token(tag, "id") &&
    !html_attr_value_has_noise_token(tag, "class") &&
    (
      html_scope_attr_is_strong_content_root(tag, "id") ||
      html_scope_attr_is_strong_content_root(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_exact_content_id(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    html_scope_attr_is_exact_content_id(tag, "id")
  })
}

///|
fn find_html_scope_inner_with_role_main(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) && html_scope_role_is_main(tag)
  })
}

///|
fn find_html_container_block_inner_matching(
  bs : Bytes,
  matcher : (String, String) -> Bool,
) -> Bytes? {
  let lt = pat("<")
  let gt = pat(">")
  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes(bs, lt, pos)
    match open0 {
      None => return None
      Some(open_idx) =>
        match find_bytes(bs, gt, open_idx) {
          None => return None
          Some(gt_idx) => {
            let tag_bs = bs[open_idx:gt_idx + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()
            match html_scope_open_tag_name(tag) {
              Some(tag_name) =>
                if matcher(tag_name, tag) {
                  let inner_start = gt_idx + 1
                  match find_matching_tag_end(bs, open_idx, tag_name) {
                    Some(close_idx) =>
                      return Some(bs[inner_start:close_idx].to_owned())
                    None => ()
                  }
                }
              None => ()
            }
            pos = gt_idx + 1
          }
        }
    }
  }

  None
}

///|
fn html_scope_open_tag_name(tag : String) -> String? {
  let lower = tag.to_lower()
  if !lower.has_prefix("<") ||
    lower.has_prefix("</") ||
    lower.has_prefix("<!") ||
    lower.has_prefix("<?") {
    return None
  }

  let n = lower.length()
  let mut i = 1
  while i < n && (lower[i] == ' ' || lower[i] == '\n' || lower[i] == '\t') {
    i += 1
  }
  let start = i
  while i < n {
    let ch = lower[i]
    if ch == ' ' || ch == '\n' || ch == '\t' || ch == '>' || ch == '/' {
      break
    }
    i += 1
  }

  if i > start {
    Some(lower[start:i].to_owned())
  } else {
    None
  }
}

///|
fn html_scope_is_candidate_tag(tag_name : String) -> Bool {
  tag_name == "div" ||
  tag_name == "section" ||
  tag_name == "article" ||
  tag_name == "main"
}

///|
fn html_scope_attr_contains_exact_root_token(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower()
      lower.contains("mw-content-text") || lower.contains("bodycontent")
    }
  }
}

///|
fn html_scope_attr_is_strong_content_root(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let words = html_scope_attr_words(value)
      let has_body = html_scope_words_contain(words, "body")
      let has_content = html_scope_words_contain(words, "content")
      (has_body && has_content) ||
      (html_scope_words_contain(words, "article") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "post") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "entry") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "story") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "chapter") && (has_body || has_content))
    }
  }
}

///|
fn html_scope_attr_is_exact_content_id(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower().trim().to_owned()
      lower == "content" || lower == "maincontent"
    }
  }
}

///|
fn html_scope_role_is_main(tag : String) -> Bool {
  read_html_attr_value(tag, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_scope_attr_words(value : String) -> Array[String] {
  let out : Array[String] = []
  let part : Array[Char] = []

  fn flush(out : Array[String], part : Array[Char]) -> Unit {
    if part.length() == 0 {
      return
    }
    out.push(String::from_array(part))
    part.clear()
  }

  for ch in value.to_lower() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      part.push(ch)
    } else {
      flush(out, part)
    }
  }
  flush(out, part)
  out
}

///|
fn html_scope_words_contain(words : Array[String], needle : String) -> Bool {
  for word in words {
    if word == needle {
      return true
    }
  }
  false
}

///|
fn html_block_origin_with_index(
  origin : @cor.Origin?,
  source_name : String,
  block_index : Int,
) -> @cor.Origin? {
  match origin {
    Some(v) =>
      Some({
        source_name: Some(source_name),
        page: v.page,
        slide: v.slide,
        sheet: v.sheet,
        block_index: Some(block_index),
        heading_path: v.heading_path,
        line_start: v.line_start,
        line_end: v.line_end,
        row_index: v.row_index,
        column_index: v.column_index,
        object_ref: v.object_ref,
        relationship_id: v.relationship_id,
        key_path: v.key_path,
      })
    None =>
      Some({
        source_name: Some(source_name),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(block_index),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      })
  }
}
