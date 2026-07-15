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
