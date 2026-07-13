///|
priv struct HtmlSemanticCollectCtx {
  blocks : Array[HtmlBlockFact]
  block_by_source_key : Map[String, HtmlBlockFact]
  first_block_source_key_by_tag_name : Map[String, String]
  child_block_source_keys_by_parent_source_key : Map[String, Array[String]]
  descendant_block_source_keys_by_ancestor_source_key : Map[
    String,
    Array[String],
  ]
  descendant_table_row_block_source_keys_by_table_source_key : Map[
    String,
    Array[String],
  ]
  direct_table_cell_block_source_keys_by_row_source_key : Map[
    String,
    Array[String],
  ]
  parent_source_key_by_block_source_key : Map[String, String]
  list_depth_by_block_source_key : Map[String, Int]
  quote_depth_by_block_source_key : Map[String, Int]
  nearest_list_source_key_by_block_source_key : Map[String, String]
  nearest_list_item_source_key_by_block_source_key : Map[String, String]
  nearest_quote_source_key_by_block_source_key : Map[String, String]
  nearest_table_ancestor_source_key_by_block_source_key : Map[String, String]
  paragraphs : Array[HtmlParagraphFact]
  inlines : Array[HtmlInlineFact]
  inline_by_source_key : Map[String, HtmlInlineFact]
  top_level_inline_keys_by_block_source_key : Map[String, Array[String]]
  links : Array[HtmlLinkFact]
  link_source_key_by_inline_source_key : Map[String, String]
  link_source_keys_by_block_source_key : Map[String, Array[String]]
  images : Array[HtmlImageFact]
  image_index_by_source_key : Map[String, Int]
  image_source_key_by_inline_source_key : Map[String, String]
  image_source_keys_by_block_source_key : Map[String, Array[String]]
  image_source_keys_by_parent_inline_source_key : Map[String, Array[String]]
  tables : Array[HtmlTableFact]
  table_sections : Array[HtmlTableSectionFact]
  table_rows : Array[HtmlTableRowFact]
  table_row_by_source_key : Map[String, HtmlTableRowFact]
  table_cells : Array[HtmlTableCellFact]
  table_cell_by_source_key : Map[String, HtmlTableCellFact]
  lists : Array[HtmlListFact]
  list_source_key_by_block_source_key : Map[String, String]
  list_items : Array[HtmlListItemFact]
  list_item_source_key_by_block_source_key : Map[String, String]
  blockquotes : Array[HtmlBlockQuoteFact]
  code_blocks : Array[HtmlCodeBlockFact]
  figures : Array[HtmlFigureFact]
  note_refs : Array[HtmlNoteRefFact]
  note_bodies : Array[HtmlNoteBodyFact]
  note_body_by_id : Map[String, HtmlNoteBodyFact]
  notes : Array[HtmlNoteFact]
  scope : Array[HtmlDocumentScopeFact]
  noise_candidates : Array[HtmlNoiseCandidateFact]
  unsupported : Array[HtmlUnsupportedFact]
  warnings : Array[HtmlSemanticWarning]
  mut next_order : Int
  mut next_inline_order : Int
  mut next_link_order : Int
  mut next_image_order : Int
  mut next_table_order : Int
  mut next_table_section_order : Int
  mut next_table_row_order : Int
  mut next_table_cell_order : Int
  mut next_code_block_order : Int
  mut next_figure_order : Int
  mut next_note_ref_order : Int
  mut next_note_body_order : Int
  mut next_note_order : Int
  mut next_noise_order : Int
  mut next_unsupported_order : Int
  mut max_depth : Int
}

///|
fn collect_html_semantic_node(
  node : HtmlNode,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_source_key : String?,
) -> String? {
  match node {
    HtmlNode::Element(element) =>
      collect_html_semantic_element(element, ctx, depth, parent_source_key)
    _ => None
  }
}

///|
fn collect_html_semantic_element(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_source_key : String?,
) -> String? {
  let kind = if element.tag_name == "code" &&
    !html_semantic_parent_block_is_tag(ctx, parent_source_key, "pre") {
    None
  } else {
    html_semantic_block_kind(element.tag_name)
  }
  let mut effective_depth = depth
  let local_warnings : Array[HtmlSemanticWarning] = []

  if depth > HTML_SEMANTIC_MAX_DEPTH {
    effective_depth = HTML_SEMANTIC_MAX_DEPTH
  }
  if effective_depth > ctx.max_depth {
    ctx.max_depth = effective_depth
  }

  match kind {
    None => {
      for child in element.children {
        ignore(
          collect_html_semantic_node(
            child,
            ctx,
            effective_depth + 1,
            parent_source_key,
          ),
        )
      }
      None
    }
    Some(block_kind) => {
      ctx.next_order += 1
      let source_order = ctx.next_order
      let source_key = html_semantic_source_key(element.tag_name, source_order)

      if depth > HTML_SEMANTIC_MAX_DEPTH {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::DepthLimitExceeded,
          source_key,
          element.tag_name,
          "html semantic depth limit exceeded at <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      if is_html_semantic_unsupported_tag(element.tag_name) {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsupportedElement,
          source_key,
          element.tag_name,
          "unsupported html block element: <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      let (attrs, attr_warnings) = html_semantic_attribute_summary(
        element, source_key,
      )
      for warning in attr_warnings {
        local_warnings.push(warning)
      }

      let (text_preview, text_truncated) = html_semantic_text_preview(
        element.children,
      )
      if text_truncated {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::TextPreviewTruncated,
          source_key,
          element.tag_name,
          "html semantic text preview truncated for <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      for warning in local_warnings {
        ctx.warnings.push(warning)
      }

      match html_semantic_unsupported_kind_for_tag(element.tag_name) {
        Some(unsupported_kind) =>
          ignore(
            push_html_semantic_unsupported_fact(
              ctx,
              unsupported_kind,
              HtmlWarningSeverity::Warning,
              Some(source_key),
              element.tag_name,
              source_order,
              effective_depth,
              parent_source_key,
              text_preview,
              attrs,
              None,
              element.span,
              "unsupported html element: <" + element.tag_name + ">",
            ),
          )
        None => ()
      }
      push_html_semantic_guard_unsupported_facts(
        ctx,
        local_warnings,
        source_key,
        element.tag_name,
        source_order,
        effective_depth,
        parent_source_key,
        text_preview,
        attrs,
        element.span,
      )
      collect_html_semantic_noise_candidate_fact(
        element,
        ctx,
        Some(source_key),
        parent_source_key,
        source_order,
        effective_depth,
        attrs,
        text_preview,
      )

      let children : Array[String] = []
      let block : HtmlBlockFact = {
        kind: block_kind,
        source_key,
        tag_name: element.tag_name,
        source_order,
        depth: effective_depth,
        parent_source_key,
        text_preview,
        attributes: attrs,
        span: element.span,
        children,
        warnings: local_warnings,
      }
      ctx.blocks.push(block)
      ctx.block_by_source_key.set(source_key, block)
      if !ctx.first_block_source_key_by_tag_name.contains(element.tag_name) {
        ctx.first_block_source_key_by_tag_name.set(element.tag_name, source_key)
      }
      html_semantic_index_block_ancestry(
        ctx, source_key, block_kind, source_order, parent_source_key,
      )
      match parent_source_key {
        Some(parent_key) =>
          html_semantic_map_push_string(
            ctx.child_block_source_keys_by_parent_source_key,
            parent_key,
            source_key,
          )
        None => ()
      }
      ignore(
        collect_html_semantic_inlines_from_children(
          element.children,
          ctx,
          effective_depth + 1,
          Some(source_key),
          None,
        ),
      )
      for child in element.children {
        match
          collect_html_semantic_node(
            child,
            ctx,
            effective_depth + 1,
            Some(source_key),
          ) {
          Some(child_key) => children.push(child_key)
          None => ()
        }
      }
      if block_kind == HtmlBlockKind::Table {
        collect_html_semantic_table_fact(
          element, ctx, source_key, source_order, effective_depth, parent_source_key,
          attrs, text_preview, local_warnings,
        )
      } else {
        collect_html_semantic_note_body_fact(
          element, ctx, source_key, source_order, effective_depth, parent_source_key,
          attrs, text_preview, local_warnings,
        )
        collect_html_semantic_polished_block_fact(
          element, ctx, block_kind, source_key, source_order, effective_depth, parent_source_key,
          children, attrs, text_preview, local_warnings,
        )
      }
      Some(source_key)
    }
  }
}

///|
fn collect_html_semantic_inlines_from_children(
  children : Array[HtmlNode],
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<children.length() {
    let child = children[i]
    match
      collect_html_semantic_inline_node(
        child,
        ctx,
        depth,
        parent_block_source_key,
        parent_inline_source_key,
        html_semantic_child_has_adjacent_text(children, i),
      ) {
      Some(source_key) => out.push(source_key)
      None => ()
    }
  }
  out
}

///|
fn collect_html_semantic_inline_node(
  node : HtmlNode,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  has_surrounding_text : Bool,
) -> String? {
  match node {
    HtmlNode::Text(text) =>
      collect_html_semantic_text_inline(
        text, ctx, depth, parent_block_source_key, parent_inline_source_key,
      )
    HtmlNode::Element(element) =>
      collect_html_semantic_inline_element(
        element, ctx, depth, parent_block_source_key, parent_inline_source_key, has_surrounding_text,
      )
    _ => None
  }
}

///|
fn collect_html_semantic_text_inline(
  text : HtmlText,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
) -> String? {
  let is_whitespace_only = text.text.trim() == ""
  let normalized = if is_whitespace_only {
    " "
  } else {
    normalize_html_semantic_preview(text.text)
  }
  if normalized == "" {
    return None
  }
  let (raw_text_preview, raw_truncated) = bounded_html_semantic_preview(
    text.text,
    HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
  )
  let (text_preview, normalized_truncated) = bounded_html_semantic_preview(
    normalized,
    HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
  )
  let truncated = raw_truncated || normalized_truncated
  ctx.next_inline_order += 1
  let source_order = ctx.next_inline_order
  let source_key = html_semantic_inline_source_key("text", source_order)
  let warnings : Array[HtmlSemanticWarning] = []
  if truncated {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        "",
        "html semantic text inline preview truncated",
      ),
    )
  }
  push_html_semantic_warnings(ctx, warnings)
  push_html_semantic_guard_unsupported_facts(
    ctx,
    warnings,
    source_key,
    "",
    source_order,
    clamp_html_semantic_depth(depth),
    html_semantic_first_source_key(
      parent_inline_source_key, parent_block_source_key,
    ),
    text_preview,
    [],
    text.span,
  )
  let inline : HtmlInlineFact = {
    kind: HtmlInlineKind::Text,
    source_key,
    tag_name: "",
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_block_source_key,
    parent_inline_source_key,
    raw_text_preview,
    normalized_text_preview: text_preview,
    text_preview,
    has_leading_whitespace: html_semantic_has_leading_whitespace(text.text),
    has_trailing_whitespace: html_semantic_has_trailing_whitespace(text.text),
    contains_newline: html_semantic_contains_newline(text.text),
    contains_repeated_whitespace: html_semantic_contains_repeated_whitespace(
      text.text,
    ),
    is_whitespace_only,
    preserves_whitespace: false,
    has_surrounding_text: false,
    attributes: [],
    span: text.span,
    children: [],
    warnings,
  }
  ctx.inlines.push(inline)
  ctx.inline_by_source_key.set(source_key, inline)
  match (parent_block_source_key, parent_inline_source_key) {
    (Some(block_key), None) =>
      html_semantic_map_push_string(
        ctx.top_level_inline_keys_by_block_source_key,
        block_key,
        source_key,
      )
    _ => ()
  }
  Some(source_key)
}

///|
fn collect_html_semantic_inline_element(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  has_surrounding_text : Bool,
) -> String? {
  match html_semantic_inline_kind(element.tag_name) {
    None => {
      if html_semantic_block_kind(element.tag_name) is Some(_) {
        return None
      }
      ignore(
        collect_html_semantic_inlines_from_children(
          element.children,
          ctx,
          depth + 1,
          parent_block_source_key,
          parent_inline_source_key,
        ),
      )
      None
    }
    Some(kind) => {
      ctx.next_inline_order += 1
      let source_order = ctx.next_inline_order
      let source_key = html_semantic_inline_source_key(
        element.tag_name,
        source_order,
      )
      let local_warnings : Array[HtmlSemanticWarning] = []
      if depth > HTML_SEMANTIC_MAX_DEPTH {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::DepthLimitExceeded,
            source_key,
            element.tag_name,
            "html semantic inline depth limit exceeded at <" +
            element.tag_name +
            ">",
          ),
        )
      }
      if kind == HtmlInlineKind::UnsupportedInline {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::UnsupportedElement,
            source_key,
            element.tag_name,
            "unsupported html inline element: <" + element.tag_name + ">",
          ),
        )
      }
      let (attrs, attr_warnings) = html_semantic_attribute_summary(
        element, source_key,
      )
      for warning in attr_warnings {
        local_warnings.push(warning)
      }
      let raw_text_result = html_semantic_raw_text_preview(element.children)
      let (text_preview, text_truncated) = html_semantic_text_preview(
        element.children,
      )
      if text_truncated {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::TextPreviewTruncated,
            source_key,
            element.tag_name,
            "html semantic inline text preview truncated for <" +
            element.tag_name +
            ">",
          ),
        )
      }
      push_html_semantic_warnings(ctx, local_warnings)
      push_html_semantic_guard_unsupported_facts(
        ctx,
        local_warnings,
        source_key,
        element.tag_name,
        source_order,
        clamp_html_semantic_depth(depth),
        html_semantic_first_source_key(
          parent_inline_source_key, parent_block_source_key,
        ),
        text_preview,
        attrs,
        element.span,
      )

      let children : Array[String] = []
      let inline : HtmlInlineFact = {
        kind,
        source_key,
        tag_name: element.tag_name,
        source_order,
        depth: clamp_html_semantic_depth(depth),
        parent_block_source_key,
        parent_inline_source_key,
        raw_text_preview: raw_text_result.0,
        normalized_text_preview: text_preview,
        text_preview,
        has_leading_whitespace: html_semantic_has_leading_whitespace(
          raw_text_result.0,
        ),
        has_trailing_whitespace: html_semantic_has_trailing_whitespace(
          raw_text_result.0,
        ),
        contains_newline: html_semantic_contains_newline(raw_text_result.0),
        contains_repeated_whitespace: html_semantic_contains_repeated_whitespace(
          raw_text_result.0,
        ),
        is_whitespace_only: raw_text_result.0.trim() == "",
        preserves_whitespace: kind == HtmlInlineKind::Code,
        has_surrounding_text,
        attributes: attrs,
        span: element.span,
        children,
        warnings: local_warnings,
      }
      ctx.inlines.push(inline)
      ctx.inline_by_source_key.set(source_key, inline)
      match (parent_block_source_key, parent_inline_source_key) {
        (Some(block_key), None) =>
          html_semantic_map_push_string(
            ctx.top_level_inline_keys_by_block_source_key,
            block_key,
            source_key,
          )
        _ => ()
      }
      let child_keys = collect_html_semantic_inlines_from_children(
        element.children,
        ctx,
        depth + 1,
        parent_block_source_key,
        Some(source_key),
      )
      for child_key in child_keys {
        children.push(child_key)
      }
      if kind == HtmlInlineKind::Link {
        collect_html_semantic_link_fact(
          element, ctx, source_key, parent_block_source_key, depth, text_preview,
          child_keys, local_warnings,
        )
      } else if kind == HtmlInlineKind::Image {
        collect_html_semantic_image_fact(
          element, ctx, source_key, parent_block_source_key, parent_inline_source_key,
          depth, local_warnings,
        )
      }
      Some(source_key)
    }
  }
}

///|
fn html_semantic_inline_kind(tag_name : String) -> HtmlInlineKind? {
  match tag_name {
    "a" => Some(HtmlInlineKind::Link)
    "img" => Some(HtmlInlineKind::Image)
    "em" | "i" => Some(HtmlInlineKind::Emphasis)
    "strong" | "b" => Some(HtmlInlineKind::Strong)
    "code" => Some(HtmlInlineKind::Code)
    "br" => Some(HtmlInlineKind::Break)
    "span" => Some(HtmlInlineKind::Span)
    "small" | "mark" | "sub" | "sup" => Some(HtmlInlineKind::InlineContainer)
    _ =>
      if is_html_semantic_unsupported_tag(tag_name) {
        Some(HtmlInlineKind::UnsupportedInline)
      } else {
        None
      }
  }
}

///|
fn collect_html_semantic_link_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  inline_source_key : String,
  parent_block_source_key : String?,
  depth : Int,
  text_preview : String,
  inline_child_keys : Array[String],
  inline_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_link_order += 1
  let source_key = "html:link:" + ctx.next_link_order.to_string()
  let href = html_semantic_attr_value(element.attributes, "href")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = classify_html_semantic_link_kind(href)
  let is_note_ref = html_semantic_anchor_is_note_ref(element)
  let is_back_reference = html_semantic_anchor_is_backref(element)
  let image_source_keys = html_semantic_image_keys_for_parent_inline(
    ctx, inline_source_key,
  )
  set_html_semantic_parent_link_source_key(ctx, inline_source_key, source_key)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in inline_warnings {
    warnings.push(warning)
  }
  let fact_warnings : Array[HtmlSemanticWarning] = []
  match kind {
    HtmlLinkKind::Unsafe | HtmlLinkKind::Data =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsafeUrl,
          source_key,
          element.tag_name,
          "html semantic link has unsafe href",
        ),
      )
    HtmlLinkKind::Empty =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::EmptyUrl,
          source_key,
          element.tag_name,
          "html semantic link has empty href",
        ),
      )
    _ => ()
  }
  for warning in fact_warnings {
    warnings.push(warning)
  }
  push_html_semantic_warnings(ctx, fact_warnings)
  match html_semantic_unsupported_kind_for_link(kind) {
    Some(unsupported_kind) => {
      let (attrs, _) = html_semantic_attribute_summary(element, source_key)
      ignore(
        push_html_semantic_unsupported_fact(
          ctx,
          unsupported_kind,
          html_semantic_unsupported_url_severity(unsupported_kind),
          Some(inline_source_key),
          element.tag_name,
          ctx.next_link_order,
          clamp_html_semantic_depth(depth),
          parent_block_source_key,
          text_preview,
          attrs,
          Some(html_semantic_url_fact_value(href, kind)),
          element.span,
          html_semantic_unsupported_url_message(unsupported_kind, "link"),
        ),
      )
    }
    None => ()
  }
  let link : HtmlLinkFact = {
    source_key,
    inline_source_key,
    parent_block_source_key,
    href: html_semantic_url_fact_value(href, kind),
    title: html_semantic_optional_bounded_attr(element.attributes, "title"),
    target: html_semantic_optional_bounded_attr(element.attributes, "target"),
    rel: html_semantic_optional_bounded_attr(element.attributes, "rel"),
    text_preview,
    inline_child_keys,
    image_source_keys,
    has_nested_inline: inline_child_keys.length() > 0,
    has_image: image_source_keys.length() > 0,
    is_note_ref,
    is_back_reference,
    kind,
    span: element.span,
    warnings,
  }
  ctx.links.push(link)
  ctx.link_source_key_by_inline_source_key.set(inline_source_key, source_key)
  match parent_block_source_key {
    Some(block_key) =>
      html_semantic_map_push_string(
        ctx.link_source_keys_by_block_source_key,
        block_key,
        source_key,
      )
    None => ()
  }
  if is_note_ref || is_back_reference {
    collect_html_semantic_note_ref_fact(
      element, ctx, source_key, inline_source_key, parent_block_source_key, href,
      text_preview, inline_child_keys, is_back_reference, warnings,
    )
  }
}

///|
fn collect_html_semantic_image_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  inline_source_key : String,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  depth : Int,
  inline_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_image_order += 1
  let source_key = "html:image:" + ctx.next_image_order.to_string()
  let src = html_semantic_attr_value(element.attributes, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = classify_html_semantic_image_kind(src)
  let parent_link_source_key = html_semantic_link_key_for_inline(
    ctx, parent_inline_source_key,
  )
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in inline_warnings {
    warnings.push(warning)
  }
  let fact_warnings : Array[HtmlSemanticWarning] = []
  match kind {
    HtmlImageKind::Remote =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::RemoteImage,
          source_key,
          element.tag_name,
          "html semantic image references remote source",
        ),
      )
    HtmlImageKind::DataUri =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::DataUriImage,
          source_key,
          element.tag_name,
          "html semantic image uses data uri source",
        ),
      )
    HtmlImageKind::Unsafe =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsafeUrl,
          source_key,
          element.tag_name,
          "html semantic image has unsafe source",
        ),
      )
    HtmlImageKind::Empty =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::EmptyImageSource,
          source_key,
          element.tag_name,
          "html semantic image has empty source",
        ),
      )
    _ => ()
  }
  for warning in fact_warnings {
    warnings.push(warning)
  }
  push_html_semantic_warnings(ctx, fact_warnings)
  match html_semantic_unsupported_kind_for_image(kind) {
    Some(unsupported_kind) => {
      let (attrs, _) = html_semantic_attribute_summary(element, source_key)
      ignore(
        push_html_semantic_unsupported_fact(
          ctx,
          unsupported_kind,
          html_semantic_unsupported_url_severity(unsupported_kind),
          Some(inline_source_key),
          element.tag_name,
          ctx.next_image_order,
          clamp_html_semantic_depth(depth),
          parent_block_source_key,
          "",
          attrs,
          Some(html_semantic_image_src_fact_value(src, kind)),
          element.span,
          html_semantic_unsupported_url_message(unsupported_kind, "image"),
        ),
      )
    }
    None => ()
  }
  let image : HtmlImageFact = {
    source_key,
    inline_source_key,
    parent_block_source_key,
    parent_inline_source_key,
    parent_link_source_key,
    src: html_semantic_image_src_fact_value(src, kind),
    srcset: html_semantic_optional_bounded_attr(element.attributes, "srcset"),
    alt: html_semantic_optional_bounded_attr(element.attributes, "alt"),
    title: html_semantic_optional_bounded_attr(element.attributes, "title"),
    width: html_semantic_optional_bounded_attr(element.attributes, "width"),
    height: html_semantic_optional_bounded_attr(element.attributes, "height"),
    loading: html_semantic_optional_bounded_attr(element.attributes, "loading"),
    decoding: html_semantic_optional_bounded_attr(
      element.attributes,
      "decoding",
    ),
    picture_source_keys: [],
    alt_complete: html_semantic_attr_preview_complete(element.attributes, "alt"),
    title_complete: html_semantic_attr_preview_complete(
      element.attributes,
      "title",
    ),
    kind,
    span: element.span,
    warnings,
  }
  ctx.images.push(image)
  ctx.image_index_by_source_key.set(source_key, ctx.images.length() - 1)
  ctx.image_source_key_by_inline_source_key.set(inline_source_key, source_key)
  match parent_block_source_key {
    Some(block_key) =>
      html_semantic_map_push_string(
        ctx.image_source_keys_by_block_source_key,
        block_key,
        source_key,
      )
    None => ()
  }
  match parent_inline_source_key {
    Some(parent_inline_key) =>
      html_semantic_map_push_string(
        ctx.image_source_keys_by_parent_inline_source_key,
        parent_inline_key,
        source_key,
      )
    None => ()
  }
}

///|
fn collect_html_semantic_polished_block_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_kind : HtmlBlockKind,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  if block_kind == HtmlBlockKind::Paragraph ||
    html_semantic_container_has_direct_text(element.children) {
    collect_html_semantic_paragraph_fact(
      element, ctx, block_kind, block_source_key, source_order, depth, parent_block_source_key,
      attributes, text_preview, block_warnings,
    )
  }
  match block_kind {
    HtmlBlockKind::List(ordered) =>
      collect_html_semantic_list_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        ordered, child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::ListItem =>
      collect_html_semantic_list_item_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::BlockQuote =>
      collect_html_semantic_blockquote_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::Pre | HtmlBlockKind::CodeBlock =>
      collect_html_semantic_code_block_fact(
        element, ctx, block_source_key, source_order, depth, attributes, text_preview,
        block_warnings,
      )
    HtmlBlockKind::Figure =>
      collect_html_semantic_figure_fact(
        element, ctx, block_source_key, source_order, depth, child_block_source_keys,
        attributes, text_preview, block_warnings,
      )
    _ => ()
  }
}

///|
fn collect_html_semantic_paragraph_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_kind : HtmlBlockKind,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let inline_child_keys = html_semantic_inline_keys_for_block(
    ctx, block_source_key,
  )
  let inline_summary = html_semantic_paragraph_inline_summary(
    ctx, inline_child_keys,
  )
  let raw_text = html_semantic_raw_text_preview(element.children).0
  let normalized_text = normalize_html_semantic_preview(raw_text)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  ctx.paragraphs.push({
    source_key: "html:paragraph:" + source_order.to_string(),
    block_source_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_block_source_key,
    inline_child_keys,
    raw_text_preview: bounded_html_semantic_preview(
      raw_text,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    normalized_text_preview: bounded_html_semantic_preview(
      normalized_text,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    has_meaningful_text: text_preview.trim() != "",
    has_links: inline_summary.has_links,
    has_images: inline_summary.has_images,
    has_code: inline_summary.has_code,
    has_emphasis: inline_summary.has_emphasis,
    has_strong: inline_summary.has_strong,
    has_breaks: inline_summary.has_breaks,
    has_repeated_whitespace: inline_summary.has_repeated_whitespace ||
    html_semantic_contains_repeated_whitespace(raw_text),
    has_newline: inline_summary.has_newline ||
    html_semantic_contains_newline(raw_text),
    is_candidate: block_kind != HtmlBlockKind::Paragraph,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
priv struct HtmlSemanticParagraphInlineSummary {
  has_links : Bool
  has_images : Bool
  has_code : Bool
  has_emphasis : Bool
  has_strong : Bool
  has_breaks : Bool
  has_repeated_whitespace : Bool
  has_newline : Bool
}

///|
fn html_semantic_paragraph_inline_summary(
  ctx : HtmlSemanticCollectCtx,
  inline_child_keys : Array[String],
) -> HtmlSemanticParagraphInlineSummary {
  let mut has_links = false
  let mut has_images = false
  let mut has_code = false
  let mut has_emphasis = false
  let mut has_strong = false
  let mut has_breaks = false
  let mut has_repeated_whitespace = false
  let mut has_newline = false
  for key in inline_child_keys {
    match html_semantic_inline_for_key(ctx, key) {
      Some(inline) => {
        match inline.kind {
          HtmlInlineKind::Link => has_links = true
          HtmlInlineKind::Image => has_images = true
          HtmlInlineKind::Code => has_code = true
          HtmlInlineKind::Emphasis => has_emphasis = true
          HtmlInlineKind::Strong => has_strong = true
          HtmlInlineKind::Break => has_breaks = true
          _ => ()
        }
        if inline.contains_repeated_whitespace {
          has_repeated_whitespace = true
        }
        if inline.contains_newline {
          has_newline = true
        }
      }
      None => ()
    }
  }
  {
    has_links,
    has_images,
    has_code,
    has_emphasis,
    has_strong,
    has_breaks,
    has_repeated_whitespace,
    has_newline,
  }
}

///|
fn collect_html_semantic_list_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  ordered : Bool,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_list_source_key(source_order)
  let item_keys : Array[String] = []
  for child_key in child_block_source_keys {
    if html_semantic_block_kind_for_key(ctx, child_key) ==
      Some(HtmlBlockKind::ListItem) {
      item_keys.push(child_key)
    }
  }
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let kind = if ordered {
    HtmlListKind::Ordered
  } else {
    HtmlListKind::Unordered
  }
  ctx.lists.push({
    source_key,
    block_source_key,
    kind,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    list_depth: html_semantic_list_depth(ctx, block_source_key),
    parent_list_source_key: html_semantic_parent_list_key(
      ctx, parent_block_source_key,
    ),
    parent_item_source_key: html_semantic_parent_item_key(
      ctx, parent_block_source_key,
    ),
    item_source_keys: item_keys,
    item_count: item_keys.length(),
    start: html_semantic_optional_bounded_attr(element.attributes, "start"),
    type_attr: html_semantic_optional_bounded_attr(element.attributes, "type"),
    reversed: html_semantic_has_attr(element.attributes, "reversed"),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
  ctx.list_source_key_by_block_source_key.set(block_source_key, source_key)
}

///|
fn collect_html_semantic_list_item_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_list_item_source_key(source_order)
  let child_list_source_keys : Array[String] = []
  for child_key in child_block_source_keys {
    match html_semantic_block_for_key(ctx, child_key) {
      Some(block) =>
        match block.kind {
          HtmlBlockKind::List(_) =>
            child_list_source_keys.push(
              html_semantic_list_source_key(block.source_order),
            )
          _ => ()
        }
      None => ()
    }
  }
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let parent_list_source_key = html_semantic_parent_list_key(
    ctx, parent_block_source_key,
  )
  ctx.list_items.push({
    source_key,
    block_source_key,
    list_source_key: parent_list_source_key,
    parent_item_source_key: html_semantic_parent_item_key(
      ctx, parent_block_source_key,
    ),
    source_order,
    depth: clamp_html_semantic_depth(depth),
    list_depth: html_semantic_list_depth(ctx, block_source_key),
    item_order: html_semantic_item_order_in_list(
      ctx.list_items,
      parent_list_source_key,
    ),
    child_list_source_keys,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
  ctx.list_item_source_key_by_block_source_key.set(block_source_key, source_key)
}

///|
fn collect_html_semantic_blockquote_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_blockquote_source_key(source_order)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  ctx.blockquotes.push({
    source_key,
    block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    quote_depth: html_semantic_quote_depth(ctx, block_source_key),
    parent_quote_source_key: html_semantic_parent_quote_key(
      ctx, parent_block_source_key,
    ),
    child_block_source_keys,
    cite: html_semantic_optional_bounded_attr(element.attributes, "cite"),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_code_block_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_code_block_order += 1
  let source_key = "html:code-block:" + ctx.next_code_block_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let own_class_hint = html_semantic_optional_bounded_attr(
    element.attributes,
    "class",
  )
  let child_code_class_hint = if element.tag_name == "pre" {
    match find_html_semantic_direct_child_element(element, "code") {
      Some(code_element) =>
        html_semantic_optional_bounded_attr(code_element.attributes, "class")
      None => None
    }
  } else {
    None
  }
  let class_hint = match own_class_hint {
    Some(value) => Some(value)
    None => child_code_class_hint
  }
  let language_hint = match class_hint {
    Some(value) => html_semantic_language_hint_from_class(value)
    None => None
  }
  let code_child_key = if element.tag_name == "pre" {
    find_html_semantic_child_block_key_by_tag(ctx, block_source_key, "code")
  } else {
    None
  }
  let code_text_result = html_semantic_code_text(element.children)
  ctx.code_blocks.push({
    source_key,
    block_source_key,
    code_block_source_key: code_child_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    language_hint,
    class_hint,
    code_text: code_text_result.0,
    code_text_complete: !code_text_result.1,
    whitespace_preview: html_semantic_whitespace_text_preview(element.children).0,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_figure_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_figure_order += 1
  let source_key = "html:figure:" + ctx.next_figure_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let caption_block_source_key = find_html_semantic_child_block_key_by_tag(
    ctx, block_source_key, "figcaption",
  )
  let caption_text_preview = match caption_block_source_key {
    Some(key) => html_semantic_block_text_preview_for_key(ctx, key)
    None => None
  }
  ctx.figures.push({
    source_key,
    block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    child_block_source_keys,
    caption_block_source_key,
    caption_text_preview,
    image_source_keys: html_semantic_image_keys_for_block(ctx, block_source_key),
    link_source_keys: html_semantic_link_keys_for_block(ctx, block_source_key),
    inline_child_keys: html_semantic_inline_keys_for_block(
      ctx, block_source_key,
    ),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_note_body_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  _depth : Int,
  parent_block_source_key : String?,
  _attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let kind = html_semantic_note_body_kind(element)
  if kind == HtmlNoteKind::Unknown {
    return
  }
  let note_id = html_semantic_note_body_id(element)
  let duplicate_target = match note_id {
    Some(id) => html_semantic_note_body_id_seen(ctx, id)
    None => false
  }
  ctx.next_note_body_order += 1
  let source_key = "html:note-body:" + ctx.next_note_body_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  if duplicate_target {
    let warning = new_html_semantic_warning(
      HtmlSemanticWarningKind::DuplicateNoteTarget,
      source_key,
      element.tag_name,
      "html semantic note body has duplicate target id",
    )
    warnings.push(warning)
    ctx.warnings.push(warning)
  }
  ctx.note_bodies.push({
    source_key,
    block_source_key,
    source_order,
    kind,
    note_id,
    marker: html_semantic_note_marker(element.children),
    body_text_preview: text_preview,
    inline_child_keys: html_semantic_inline_keys_for_block(
      ctx, block_source_key,
    ),
    owning_block_source_key: parent_block_source_key,
    ref_source_keys: [],
    duplicate_target,
    span: element.span,
    warnings,
  })
  match note_id {
    Some(id) =>
      if !duplicate_target {
        ctx.note_body_by_id.set(
          id,
          ctx.note_bodies[ctx.note_bodies.length() - 1],
        )
      }
    None => ()
  }
}

///|
fn collect_html_semantic_note_ref_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  link_source_key : String,
  inline_source_key : String,
  parent_block_source_key : String?,
  href : String,
  text_preview : String,
  inline_child_keys : Array[String],
  is_back_reference : Bool,
  link_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_note_ref_order += 1
  let source_key = "html:note-ref:" + ctx.next_note_ref_order.to_string()
  let target_id = html_semantic_fragment_id_from_href(href)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in link_warnings {
    warnings.push(warning)
  }
  let kind = if is_back_reference {
    HtmlNoteKind::BackReference
  } else if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "endnote",
    ) {
    HtmlNoteKind::EndnoteLike
  } else {
    HtmlNoteKind::Reference
  }
  let is_broken = target_id is None
  if is_broken {
    let warning = new_html_semantic_warning(
      HtmlSemanticWarningKind::BrokenNoteTarget,
      source_key,
      element.tag_name,
      "html semantic note reference has no same-document target",
    )
    warnings.push(warning)
    ctx.warnings.push(warning)
  }
  ctx.note_refs.push({
    source_key,
    inline_source_key,
    parent_block_source_key,
    href: bounded_html_semantic_url(href),
    target_id,
    ref_text_preview: text_preview,
    inline_child_keys,
    kind,
    source_order: ctx.next_note_ref_order,
    relation_confidence: if is_broken {
      HtmlNoteRelationConfidence::Broken
    } else {
      HtmlNoteRelationConfidence::Medium
    },
    is_broken,
    is_back_reference,
    span: element.span,
    warnings,
  })
  ignore(link_source_key)
}

///|
fn collect_html_semantic_note_relations(ctx : HtmlSemanticCollectCtx) -> Unit {
  for note_ref in ctx.note_refs {
    if note_ref.is_back_reference {
      ctx.next_note_order += 1
      ctx.notes.push({
        source_key: "html:note:" + ctx.next_note_order.to_string(),
        note_id: note_ref.target_id,
        kind: HtmlNoteKind::BackReference,
        ref_source_key: Some(note_ref.source_key),
        body_source_key: None,
        href: Some(note_ref.href),
        ref_text_preview: note_ref.ref_text_preview,
        body_text_preview: "",
        source_order: ctx.next_note_order,
        relation_confidence: note_ref.relation_confidence,
        warnings: note_ref.warnings,
      })
      continue
    }
    match note_ref.target_id {
      Some(target_id) =>
        match html_semantic_note_body_for_id(ctx, target_id) {
          Some(body) => {
            ctx.next_note_order += 1
            let warnings : Array[HtmlSemanticWarning] = []
            for warning in note_ref.warnings {
              warnings.push(warning)
            }
            for warning in body.warnings {
              warnings.push(warning)
            }
            ctx.notes.push({
              source_key: "html:note:" + ctx.next_note_order.to_string(),
              note_id: Some(target_id),
              kind: body.kind,
              ref_source_key: Some(note_ref.source_key),
              body_source_key: Some(body.source_key),
              href: Some(note_ref.href),
              ref_text_preview: note_ref.ref_text_preview,
              body_text_preview: body.body_text_preview,
              source_order: ctx.next_note_order,
              relation_confidence: if body.duplicate_target {
                HtmlNoteRelationConfidence::Low
              } else {
                HtmlNoteRelationConfidence::High
              },
              warnings,
            })
          }
          None => {
            let warning = new_html_semantic_warning(
              HtmlSemanticWarningKind::MissingNoteTarget,
              note_ref.source_key,
              "a",
              "html semantic note reference target is missing",
            )
            ctx.warnings.push(warning)
            ctx.next_note_order += 1
            let warnings : Array[HtmlSemanticWarning] = []
            for item in note_ref.warnings {
              warnings.push(item)
            }
            warnings.push(warning)
            ctx.notes.push({
              source_key: "html:note:" + ctx.next_note_order.to_string(),
              note_id: Some(target_id),
              kind: note_ref.kind,
              ref_source_key: Some(note_ref.source_key),
              body_source_key: None,
              href: Some(note_ref.href),
              ref_text_preview: note_ref.ref_text_preview,
              body_text_preview: "",
              source_order: ctx.next_note_order,
              relation_confidence: HtmlNoteRelationConfidence::Broken,
              warnings,
            })
          }
        }
      None => {
        ctx.next_note_order += 1
        ctx.notes.push({
          source_key: "html:note:" + ctx.next_note_order.to_string(),
          note_id: None,
          kind: note_ref.kind,
          ref_source_key: Some(note_ref.source_key),
          body_source_key: None,
          href: Some(note_ref.href),
          ref_text_preview: note_ref.ref_text_preview,
          body_text_preview: "",
          source_order: ctx.next_note_order,
          relation_confidence: HtmlNoteRelationConfidence::Broken,
          warnings: note_ref.warnings,
        })
      }
    }
  }
  for body in ctx.note_bodies {
    if body.duplicate_target {
      ctx.next_note_order += 1
      ctx.notes.push({
        source_key: "html:note:" + ctx.next_note_order.to_string(),
        note_id: body.note_id,
        kind: body.kind,
        ref_source_key: None,
        body_source_key: Some(body.source_key),
        href: None,
        ref_text_preview: "",
        body_text_preview: body.body_text_preview,
        source_order: ctx.next_note_order,
        relation_confidence: HtmlNoteRelationConfidence::Low,
        warnings: body.warnings,
      })
    }
  }
}

///|
