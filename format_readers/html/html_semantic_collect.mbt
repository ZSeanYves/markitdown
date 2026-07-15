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
