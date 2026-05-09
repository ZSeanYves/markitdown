///|
fn read_docx_paragraph_style_id(p_xml : String) -> String? {
  match read_attr_value(p_xml, "<w:pStyle w:val=\"") {
    Some(v) => Some(v)
    None => read_attr_value(p_xml, "<w:pStyle w:val='")
  }
}

///|
fn read_docx_run_style_id(r_xml : String) -> String? {
  match read_attr_value(r_xml, "<w:rStyle w:val=\"") {
    Some(v) => Some(v)
    None => read_attr_value(r_xml, "<w:rStyle w:val='")
  }
}

///|
fn first_docx_image_attr(p_xml : String, attr_name : String) -> String? {
  string_opt_or(
    read_attr_value_in_first_tag(p_xml, "<wp:docPr", attr_name),
    read_attr_value_in_first_tag(p_xml, "<pic:cNvPr", attr_name),
  )
}

///|
fn read_attr_value_in_first_tag(
  block : String,
  tag_prefix : String,
  attr_name : String,
) -> String? {
  let chars = block.to_array()
  let start = find_sub(chars, 0, tag_prefix)
  if start < 0 {
    return None
  }
  let end_ = find_sub(chars, start, ">")
  if end_ < 0 {
    return None
  }
  let tag = @cor.slice_to_string(chars, start, end_ + 1)
  normalize_optional_docx_attr(read_attr_value_in_tag(tag, attr_name))
}

///|
fn normalize_optional_docx_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = @cor.trim_string(raw)
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn string_opt_or(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(_) => primary
    None => fallback
  }
}

///|
fn content_type_for_docx_target(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> String? {
  try @ox.lookup_content_type(pkg, part_name) catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn docx_media_ref_from_relationship(
  ctx : DocxPartParseContext,
  relationship_id : String,
  source_xml : String,
) -> DocxMediaRef {
  let media_resolution_started = match ctx.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let media_total = match ctx.profile_totals {
    Some(totals) => Some(totals.media_resolution_elapsed_ms)
    None => None
  }
  let media = match lookup_docx_part_target_opt(ctx.rels, relationship_id) {
    Some(target_part) => {
      if !@ox.has_part(ctx.pkg, target_part) {
        ctx.issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingMediaPart,
            DocxValidationSeverity::Warning,
            Some(ctx.source_part),
            Some(relationship_id),
            None,
            None,
            "media part is missing: " + target_part,
          ),
        )
      }
      {
        relationship_id: Some(relationship_id),
        target_part: Some(target_part),
        content_type: content_type_for_docx_target(ctx.pkg, target_part),
        alt_text: string_opt_or(
          first_docx_image_attr(source_xml, "descr"),
          None,
        ),
        title: first_docx_image_attr(source_xml, "title"),
        source_part: Some(ctx.source_part),
      }
    }
    None => {
      ctx.issues.push(
        docx_issue(
          DocxValidationIssueKind::MissingRelationshipTarget,
          DocxValidationSeverity::Warning,
          Some(ctx.source_part),
          Some(relationship_id),
          None,
          None,
          "relationship target is missing for drawing ref: " + relationship_id,
        ),
      )
      {
        relationship_id: Some(relationship_id),
        target_part: None,
        content_type: None,
        alt_text: string_opt_or(
          first_docx_image_attr(source_xml, "descr"),
          None,
        ),
        title: first_docx_image_attr(source_xml, "title"),
        source_part: Some(ctx.source_part),
      }
    }
  }
  docx_parse_profile_add_elapsed(media_total, media_resolution_started)
  media
}

///|
fn parse_docx_hyperlink_inline(
  block : String,
  ctx : DocxPartParseContext,
  open_tag : String,
) -> DocxHyperlink {
  let hyperlink_resolution_started = match ctx.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let hyperlink_total = match ctx.profile_totals {
    Some(totals) => Some(totals.hyperlink_resolution_elapsed_ms)
    None => None
  }
  let relationship_id = read_attr_value_in_tag(open_tag, "r:id")
  let anchor = read_attr_value_in_tag(open_tag, "w:anchor")
  let text = text_from_docx_range(block.to_array(), 0, block.length())
  let target = match relationship_id {
    Some(rid) => {
      let resolved = lookup_docx_hyperlink_target(ctx.rels, rid)
      let trimmed_resolved = resolved.trim()
      if trimmed_resolved == "" {
        ctx.issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingRelationshipTarget,
            DocxValidationSeverity::Warning,
            Some(ctx.source_part),
            Some(rid),
            None,
            None,
            "hyperlink relationship target is missing: " + rid,
          ),
        )
        None
      } else {
        Some(trimmed_resolved.to_owned())
      }
    }
    None => None
  }
  let hyperlink = {
    relationship_id,
    anchor,
    target,
    text: @cor.trim_string(text),
    is_external: target is Some(_),
  }
  docx_parse_profile_add_elapsed(hyperlink_total, hyperlink_resolution_started)
  hyperlink
}

///|
fn parse_docx_run_xml(block : String, ctx : DocxPartParseContext) -> DocxRun {
  let inline_scan_started = match ctx.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let inline_total = match ctx.profile_totals {
    Some(totals) => Some(totals.inline_scan_elapsed_ms)
    None => None
  }
  let style_id = read_docx_run_style_id(block)
  let chars = block.to_array()
  let out : Array[DocxInline] = []
  let mut i = 0

  while i < chars.length() {
    let lt = find_char_in_range(chars, i, chars.length(), '<')
    if lt < 0 || lt + 1 >= chars.length() {
      break
    }
    let gt = find_char_in_range(chars, lt + 1, chars.length(), '>')
    if gt < 0 {
      break
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), wt_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        wt_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }
      let text = xml_unescape(@cor.slice_to_string(chars, gt + 1, close))
      if text != "" {
        out.push(DocxInline::Text(text))
      }
      i = close + wt_close_tag_chars.length()
      continue
    }

    if chars[lt + 1] != '/' &&
      (
        tag_prefix_matches(chars, lt, chars.length(), br_open_tag_chars) ||
        tag_prefix_matches(chars, lt, chars.length(), cr_open_tag_chars)
      ) {
      out.push(DocxInline::LineBreak)
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), tab_open_tag_chars) {
      out.push(DocxInline::Tab)
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), footnote_ref_open_tag_chars) {
      let tag = @cor.slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            out.push(DocxInline::FootnoteRef(id))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), endnote_ref_open_tag_chars) {
      let tag = @cor.slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            out.push(DocxInline::EndnoteRef(id))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), comment_ref_open_tag_chars) {
      let tag = @cor.slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            out.push(DocxInline::CommentRef(id))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      (
        tag_prefix_matches(chars, lt, chars.length(), ablip_open_tag_chars) ||
        tag_prefix_matches(chars, lt, chars.length(), vimagedata_open_tag_chars)
      ) {
      let tag = @cor.slice_to_string(chars, lt, gt + 1)
      let rid = match read_attr_value_in_tag(tag, "r:embed") {
        Some(v) => Some(v)
        None => read_attr_value_in_tag(tag, "r:id")
      }
      match rid {
        Some(v) =>
          out.push(
            DocxInline::DrawingRef(
              docx_media_ref_from_relationship(ctx, v, block),
            ),
          )
        None => {
          ctx.issues.push(
            docx_issue(
              DocxValidationIssueKind::UnsupportedDrawing,
              DocxValidationSeverity::Warning,
              Some(ctx.source_part),
              None,
              None,
              None,
              "drawing element without supported relationship id",
            ),
          )
          out.push(DocxInline::Unsupported("drawing"))
        }
      }
      i = gt + 1
      continue
    }

    i = gt + 1
  }

  let run = { style_id, inlines: out }
  docx_parse_profile_add_elapsed(inline_total, inline_scan_started)
  run
}

///|
fn parse_docx_paragraph_visible(
  p_xml : String,
  ctx : DocxPartParseContext,
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> DocxParagraph {
  let style_id = read_docx_paragraph_style_id(p_xml)
  match style_id {
    Some(v) =>
      if !docx_style_exists(styles, v) && styles.styles.length() > 0 {
        ctx.issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingStyle,
            DocxValidationSeverity::Warning,
            Some(ctx.source_part),
            None,
            Some(v),
            None,
            "paragraph style is missing from styles.xml: " + v,
          ),
        )
      }
    None => ()
  }

  let numbering_ref = read_numbering_ref_from_xml(p_xml, numbering)
  match numbering_ref {
    Some(info) =>
      if !docx_numbering_instance_exists(numbering, info.num_id) &&
        numbering.numbering_instances.length() > 0 {
        ctx.issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingNumbering,
            DocxValidationSeverity::Warning,
            Some(ctx.source_part),
            None,
            None,
            Some(info.num_id),
            "paragraph numbering is missing from numbering.xml: " +
            info.num_id.to_string(),
          ),
        )
      }
    None => ()
  }

  let runs : Array[DocxRun] = []
  let hyperlink_refs : Array[DocxHyperlink] = []
  let media_refs : Array[DocxMediaRef] = []
  let chars = p_xml.to_array()
  let mut i = 0

  while i < chars.length() {
    let p_r = find_exact_open_tag(chars, i, wr_open_tag_chars)
    let p_h = find_exact_open_tag(chars, i, hyperlink_open_tag_chars)
    let next = if p_r >= 0 && p_h >= 0 {
      if p_r < p_h {
        p_r
      } else {
        p_h
      }
    } else if p_r >= 0 {
      p_r
    } else {
      p_h
    }

    if next < 0 {
      break
    }

    if p_h >= 0 && next == p_h {
      let open_end = find_sub(chars, p_h, ">")
      if open_end < 0 {
        break
      }
      let close = find_pattern_in_range(
        chars,
        open_end + 1,
        chars.length(),
        hyperlink_close_tag_chars,
      )
      if close < 0 {
        break
      }

      let open_tag = @cor.slice_to_string(chars, p_h, open_end + 1)
      let inner = @cor.slice_to_string(chars, open_end + 1, close)
      let hyperlink = parse_docx_hyperlink_inline(inner, ctx, open_tag)
      hyperlink_refs.push(hyperlink)
      runs.push({ style_id: None, inlines: [DocxInline::Hyperlink(hyperlink)] })
      i = close + hyperlink_close_tag_chars.length()
      continue
    }

    if p_r >= 0 && next == p_r {
      let open_end = find_sub(chars, p_r, ">")
      if open_end < 0 {
        break
      }
      if open_tag_is_self_closing(chars, p_r, open_end) {
        i = open_end + 1
        continue
      }
      let close = find_matching_docx_element_close(
        chars, p_r, wr_open_tag_chars, wr_close_tag_chars,
      )
      if close < 0 {
        break
      }
      let run_xml = @cor.slice_to_string(chars, open_end + 1, close)
      let run = parse_docx_run_xml(run_xml, ctx)
      for inline in run.inlines {
        match inline {
          DocxInline::DrawingRef(media) => media_refs.push(media)
          _ => ()
        }
      }
      runs.push(run)
      i = close + wr_close_tag_chars.length()
      continue
    }
  }

  { style_id, numbering_ref, runs, hyperlink_refs, media_refs }
}
