///|
fn html_fill_common_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dhtml.HtmlInspectReport,
  validation : @dhtml.HtmlValidationReport,
  semantic_report : @dhtml.HtmlSemanticInspectReport,
  text : String,
  event_count : Int,
  large_mode : Bool,
  asset_count : Int,
) -> Unit {
  diagnostics.metrics.set("node_count", inspect.node_count.to_string())
  diagnostics.metrics.set("element_count", inspect.element_count.to_string())
  diagnostics.metrics.set(
    "text_node_count",
    inspect.text_node_count.to_string(),
  )
  diagnostics.metrics.set("doctype_count", inspect.doctype_count.to_string())
  diagnostics.metrics.set("comment_count", inspect.comment_count.to_string())
  diagnostics.metrics.set(
    "attribute_count",
    inspect.attribute_count.to_string(),
  )
  diagnostics.metrics.set(
    "script_count",
    inspect.script_element_count.to_string(),
  )
  diagnostics.metrics.set(
    "style_count",
    inspect.style_element_count.to_string(),
  )
  diagnostics.metrics.set("link_count", semantic_report.link_count.to_string())
  diagnostics.metrics.set(
    "image_count",
    semantic_report.image_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_count",
    semantic_report.table_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    semantic_report.max_depth.to_string(),
  )
  diagnostics.metrics.set(
    "validation_issue_count",
    validation.issue_count.to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    (validation.warning_count + semantic_report.warning_count).to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    (validation.error_count + semantic_report.warning_error_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_node_count",
    (semantic_report.unsupported_script_count +
    semantic_report.unsupported_style_count +
    semantic_report.unsupported_iframe_count +
    semantic_report.unsupported_embed_count +
    semantic_report.unsupported_object_count +
    semantic_report.unsupported_remote_image_count +
    semantic_report.unsupported_data_image_count +
    semantic_report.unsupported_unsafe_url_count).to_string(),
  )
  diagnostics.metrics.set(
    "dropped_node_count",
    (semantic_report.unsupported_fact_count + validation.issue_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_feature_count",
    semantic_report.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @parser_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set(
    "resource_limit_hit",
    @parser_common.bool_string(large_mode),
  )
  diagnostics.metrics.set(
    "has_doctype",
    @parser_common.bool_string(inspect.has_doctype),
  )

  for issue in validation.issues {
    diagnostics.warnings.push("html validation: " + issue.message)
  }
  if inspect.script_element_count > 0 {
    diagnostics.degraded_features.push("html_script_dropped")
  }
  if inspect.style_element_count > 0 {
    diagnostics.degraded_features.push("html_style_dropped")
  }
  if semantic_report.unsupported_iframe_count > 0 {
    diagnostics.degraded_features.push("html_iframe_dropped")
  }
  if semantic_report.unsupported_embed_count > 0 {
    diagnostics.degraded_features.push("html_embed_dropped")
  }
  if semantic_report.unsupported_object_count > 0 {
    diagnostics.degraded_features.push("html_object_dropped")
  }
  if semantic_report.unsupported_remote_image_count > 0 {
    diagnostics.degraded_features.push("html_remote_image_reference_only")
  }
  if semantic_report.unsupported_data_image_count > 0 {
    diagnostics.degraded_features.push("html_data_image_reference_only")
  }
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
}

///|
fn lower_html_document(
  doc : @dhtml.HtmlDocument,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
) -> @core.DocumentIR {
  let dom_index = html_dom_lowering_index(doc)
  let lowering_index = html_lowering_index(semantic, dom_index.nav_spans)
  let top_blocks = html_collect_top_level_blocks(semantic, lowering_index)
  let lowered = lower_html_document_from_prepared(
    semantic,
    source,
    dom_index.block_elements,
    lowering_index,
    top_blocks,
  )
  @core.document_with_assets(
    @core.document_with_metadata(
      @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
      lowered.metadata,
    ),
    lowered.assets,
  )
}

///|
priv struct HtmlLoweringResult {
  blocks : Array[@core.CoreBlock]
  metadata : @core.DocumentMetadata
  assets : Array[@core.AssetRef]
}

///|
priv struct HtmlLoweringState {
  assets : Array[@core.AssetRef]
}

///|
priv struct HtmlScopePlan {
  source_start : Int
  source_end : Int
  label : String
}

///|
fn html_lower_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let scope_plans = html_block_scope_plans(text)
  html_lower_block_stream_document_with_scope_plans(
    source, text, diagnostics, scope_plans,
  )
}

///|
fn html_lower_block_stream_document_from_events(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
) -> HtmlLoweringResult {
  let scope_plans = html_block_scope_plans_from_events(text, events)
  html_lower_block_stream_document_with_scope_plans(
    source, text, diagnostics, scope_plans,
  )
}

///|
fn html_lower_block_stream_document_with_scope_plans(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  scope_plans : Array[HtmlScopePlan],
) -> HtmlLoweringResult {
  let metadata : @core.DocumentMetadata = Map([])
  let blocks : Array[@core.CoreBlock] = []
  let state = { assets: [] }
  diagnostics.metrics.set("scope_plan_count", scope_plans.length().to_string())

  for plan in scope_plans {
    let scope_text = html_scope_slice(text, plan)
    if scope_text.trim() == "" {
      continue
    }
    let parsed = try @dhtml.parse_html_document(scope_text) |> Ok catch {
      _ => Err(())
    }
    match parsed {
      Ok(doc) => {
        let semantic = @dhtml.collect_html_semantic_document(doc)
        let dom_index = html_dom_lowering_index(doc)
        let lowering_index = html_lowering_index(semantic, dom_index.nav_spans)
        let top_blocks = html_collect_top_level_blocks(semantic, lowering_index)
        let scoped_source = @input.input_from_text_with_format(
          scope_text,
          source.source_name,
          Some(@input.DetectedFormat::Html),
        )
        let lowered = html_lower_blocks_from_prepared(
          state,
          semantic,
          scoped_source,
          dom_index.block_elements,
          lowering_index,
          top_blocks,
        )
        blocks.append(lowered[:])
        match html_primary_title(semantic) {
          Some(title) =>
            if title.trim() != "" && metadata.get("title") is None {
              metadata.set("title", @core.JsonValue::String(title))
            }
          None => ()
        }
      }
      Err(_) => {
        diagnostics.warnings.push(
          "html scope parse skipped during block stream: " + plan.label,
        )
        diagnostics.degraded_features.push("html_scope_parse_skipped")
        diagnostics.same_mode_degradation.push(
          "html_scope_parse_skipped:" + plan.label,
        )
      }
    }
  }

  { blocks, metadata, assets: state.assets }
}

///|
fn lower_html_document_from_prepared(
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  lowering_index : HtmlLoweringIndex,
  top_blocks : Array[@dhtml.HtmlBlockFact],
) -> HtmlLoweringResult {
  let state = { assets: [] }
  let blocks = html_lower_blocks_from_prepared(
    state, semantic, source, dom_blocks, lowering_index, top_blocks,
  )
  let metadata : @core.DocumentMetadata = Map([])
  match html_primary_title(semantic) {
    Some(title) =>
      if title.trim() != "" {
        metadata.set("title", @core.JsonValue::String(title))
      }
    None => ()
  }
  { blocks, metadata, assets: state.assets }
}

///|
fn html_lower_blocks_from_prepared(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  lowering_index : HtmlLoweringIndex,
  top_blocks : Array[@dhtml.HtmlBlockFact],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for block in top_blocks {
    html_append_flattened_blocks(
      blocks,
      html_blocks_for_block(
        state, semantic, source, block, dom_blocks, lowering_index,
      ),
    )
  }
  blocks
}

///|
priv struct HtmlDomLoweringIndex {
  block_elements : Map[String, @dhtml.HtmlElement]
  nav_spans : Array[@dhtml.HtmlSourceSpan]
}

///|
priv struct HtmlLoweringIndex {
  block_by_key : Map[String, @dhtml.HtmlBlockFact]
  paragraph_by_block_key : Map[String, @dhtml.HtmlParagraphFact]
  list_by_block_key : Map[String, @dhtml.HtmlListFact]
  list_by_source_key : Map[String, @dhtml.HtmlListFact]
  list_item_by_block_key : Map[String, @dhtml.HtmlListItemFact]
  blockquote_by_block_key : Map[String, @dhtml.HtmlBlockQuoteFact]
  code_block_by_block_key : Map[String, @dhtml.HtmlCodeBlockFact]
  figure_by_block_key : Map[String, @dhtml.HtmlFigureFact]
  table_by_block_key : Map[String, @dhtml.HtmlTableFact]
  table_row_by_key : Map[String, @dhtml.HtmlTableRowFact]
  table_cell_by_key : Map[String, @dhtml.HtmlTableCellFact]
  table_section_by_key : Map[String, @dhtml.HtmlTableSectionFact]
  inline_by_key : Map[String, @dhtml.HtmlInlineFact]
  link_by_inline_key : Map[String, @dhtml.HtmlLinkFact]
  image_by_inline_key : Map[String, @dhtml.HtmlImageFact]
  image_by_key : Map[String, @dhtml.HtmlImageFact]
  top_level_inline_facts_by_block_key : Map[
    String,
    Array[@dhtml.HtmlInlineFact],
  ]
  skipped_block_keys : Map[String, Bool]
}

///|
fn html_dom_lowering_index(doc : @dhtml.HtmlDocument) -> HtmlDomLoweringIndex {
  let block_elements : Map[String, @dhtml.HtmlElement] = Map([])
  let nav_spans : Array[@dhtml.HtmlSourceSpan] = []
  let order : Ref[Int] = { val: 0 }
  html_dom_collect_index(doc.nodes, false, order, block_elements, nav_spans)
  { block_elements, nav_spans }
}

///|
fn html_dom_collect_index(
  nodes : Array[@dhtml.HtmlNode],
  parent_pre : Bool,
  order : Ref[Int],
  block_elements : Map[String, @dhtml.HtmlElement],
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Unit {
  for node in nodes {
    match node {
      @dhtml.HtmlNode::Element(element) => {
        if html_dom_nav_like(element) {
          nav_spans.push(element.span)
        }
        let counts_as_block = html_dom_counts_as_block(
          element.tag_name,
          parent_pre,
        )
        let next_parent_pre = parent_pre || element.tag_name == "pre"
        if counts_as_block {
          order.val += 1
          let key = "html:block:" +
            element.tag_name +
            ":" +
            order.val.to_string()
          block_elements.set(key, element)
        }
        html_dom_collect_index(
          element.children,
          next_parent_pre,
          order,
          block_elements,
          nav_spans,
        )
      }
      _ => ()
    }
  }
}

///|
fn html_dom_counts_as_block(tag_name : String, parent_pre : Bool) -> Bool {
  match tag_name {
    "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "p"
    | "ul"
    | "ol"
    | "li"
    | "table"
    | "tr"
    | "th"
    | "td"
    | "blockquote"
    | "pre"
    | "figure"
    | "figcaption"
    | "hr"
    | "body"
    | "main"
    | "article"
    | "section"
    | "div"
    | "details"
    | "summary"
    | "header"
    | "footer"
    | "nav"
    | "aside"
    | "thead"
    | "tbody"
    | "tfoot" => true
    "code" => !parent_pre
    "script"
    | "noscript"
    | "style"
    | "iframe"
    | "embed"
    | "object"
    | "svg"
    | "math"
    | "template"
    | "form"
    | "input"
    | "select"
    | "textarea"
    | "button"
    | "video"
    | "audio"
    | "source"
    | "canvas" => true
    _ => false
  }
}

///|
fn html_dom_nav_like(element : @dhtml.HtmlElement) -> Bool {
  element.tag_name == "nav" ||
  html_dom_attr_token_contains(element.attributes, "role", "navigation") ||
  html_dom_attr_token_contains(element.attributes, "role", "menu") ||
  html_dom_attr_token_contains(element.attributes, "class", "nav") ||
  html_dom_attr_token_contains(element.attributes, "class", "menu")
}

///|
fn html_dom_attr_token_contains(
  attrs : Array[@dhtml.HtmlAttribute],
  name : String,
  token : String,
) -> Bool {
  let token_lower = token.to_lower()
  for attr in attrs {
    if attr.name.to_lower() == name {
      let lowered = attr.value.to_lower()
      for part in lowered.split(" ") {
        if part.trim() == token_lower {
          return true
        }
      }
    }
  }
  false
}

///|
fn html_block_scope_plans(text : String) -> Array[HtmlScopePlan] {
  let events = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match events {
    Ok(stream) => html_block_scope_plans_from_events(text, stream)
    Err(_) =>
      [{ source_start: 0, source_end: text.length(), label: "document" }]
  }
}

///|
fn html_block_scope_plans_from_events(
  text : String,
  events : Array[@dhtml.HtmlTokenEvent],
) -> Array[HtmlScopePlan] {
  let roots = html_scope_plan_ranges(
    @dhtml.html_tokens_collect_element_ranges(events, ["main", "article"]),
    "semantic_root_",
  )
  if roots.length() > 0 {
    return roots
  }
  let sections = html_scope_plan_ranges(
    @dhtml.html_tokens_collect_element_ranges(events, ["section"]),
    "section_",
  )
  if sections.length() > 0 {
    return sections
  }
  let subtrees = html_heading_subtree_scope_plans(events)
  if subtrees.length() > 0 {
    return subtrees
  }
  [{ source_start: 0, source_end: text.length(), label: "document" }]
}

///|
fn html_heading_subtree_scope_plans(
  events : Array[@dhtml.HtmlTokenEvent],
) -> Array[HtmlScopePlan] {
  let raw_plans : Array[HtmlScopePlan] = []
  let heading_stack : Array[(Int, Int)] = []
  let mut index = 0
  for i in 0..<events.length() {
    let event = events[i]
    if event.kind != @dhtml.HtmlTokenEventKind::StartTag {
      continue
    }
    let level = html_heading_level(event.tag_name)
    if level <= 0 {
      continue
    }
    if html_scope_event_should_skip(event) {
      continue
    }
    while heading_stack.length() > 0 &&
          heading_stack[heading_stack.length() - 1].0 >= level {
      let closed = heading_stack.pop().unwrap()
      raw_plans.push({
        source_start: events[closed.1].source_start,
        source_end: event.source_start,
        label: "subtree_" + (index + 1).to_string(),
      })
      index += 1
    }
    heading_stack.push((level, i))
  }
  while heading_stack.length() > 0 {
    let closed = heading_stack.pop().unwrap()
    raw_plans.push({
      source_start: events[closed.1].source_start,
      source_end: events[events.length() - 1].source_end,
      label: "subtree_" + (index + 1).to_string(),
    })
    index += 1
  }
  html_scope_plan_dedup(raw_plans)
}

///|
fn html_scope_plan_ranges(
  ranges : Array[@dhtml.HtmlTokenSourceRange],
  label_prefix : String,
) -> Array[HtmlScopePlan] {
  let raw_plans : Array[HtmlScopePlan] = []
  let mut index = 0
  for range in ranges {
    index += 1
    raw_plans.push({
      source_start: range.source_start,
      source_end: range.source_end,
      label: label_prefix + index.to_string(),
    })
  }
  html_scope_plan_dedup(raw_plans)
}

///|
fn html_scope_plan_dedup(plans : Array[HtmlScopePlan]) -> Array[HtmlScopePlan] {
  if plans.length() <= 1 {
    return plans
  }
  let sorted : Array[HtmlScopePlan] = []
  sorted.append(plans[:])
  let mut i = 0
  while i < sorted.length() {
    let mut best = i
    let mut j = i + 1
    while j < sorted.length() {
      if html_scope_plan_order(sorted[j], sorted[best]) < 0 {
        best = j
      }
      j += 1
    }
    if best != i {
      let current = sorted[i]
      sorted[i] = sorted[best]
      sorted[best] = current
    }
    i += 1
  }
  let out : Array[HtmlScopePlan] = []
  let mut current_end = -1
  for plan in sorted {
    if plan.source_end <= plan.source_start {
      continue
    }
    if plan.source_start < current_end {
      continue
    }
    out.push(plan)
    current_end = plan.source_end
  }
  if out.length() == 0 {
    plans
  } else {
    out
  }
}

///|
fn html_scope_plan_order(left : HtmlScopePlan, right : HtmlScopePlan) -> Int {
  if left.source_start != right.source_start {
    left.source_start - right.source_start
  } else {
    let left_width = left.source_end - left.source_start
    let right_width = right.source_end - right.source_start
    right_width - left_width
  }
}

///|
fn html_heading_level(tag_name : String) -> Int {
  if tag_name.length() == 2 &&
    tag_name[0] == 'h' &&
    tag_name[1] >= '1' &&
    tag_name[1] <= '6' {
    tag_name[1].to_int() - '0'.to_int()
  } else {
    0
  }
}

///|
fn html_scope_event_should_skip(event : @dhtml.HtmlTokenEvent) -> Bool {
  if event.tag_name == "nav" ||
    event.tag_name == "footer" ||
    event.tag_name == "script" ||
    event.tag_name == "style" ||
    event.tag_name == "template" {
    return true
  }
  if @dhtml.html_token_event_attr_value(event, "hidden") is Some(_) {
    return true
  }
  let class_name = @dhtml.html_token_event_attr_value(event, "class")
    .unwrap_or("")
    .to_lower()
  let role_name = @dhtml.html_token_event_attr_value(event, "role")
    .unwrap_or("")
    .to_lower()
  class_name.contains("toc") ||
  class_name.contains("nav") ||
  class_name.contains("menu") ||
  role_name.contains("navigation")
}

///|
fn html_scope_slice(text : String, plan : HtmlScopePlan) -> String {
  let start = if plan.source_start < 0 { 0 } else { plan.source_start }
  let end0 = if plan.source_end > text.length() {
    text.length()
  } else {
    plan.source_end
  }
  if end0 <= start {
    ""
  } else {
    text[start:end0].to_owned()
  }
}

///|
fn html_lowering_index(
  semantic : @dhtml.HtmlSemanticDocument,
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> HtmlLoweringIndex {
  let block_by_key : Map[String, @dhtml.HtmlBlockFact] = Map([])
  let paragraph_by_block_key : Map[String, @dhtml.HtmlParagraphFact] = Map([])
  let list_by_block_key : Map[String, @dhtml.HtmlListFact] = Map([])
  let list_by_source_key : Map[String, @dhtml.HtmlListFact] = Map([])
  let list_item_by_block_key : Map[String, @dhtml.HtmlListItemFact] = Map([])
  let blockquote_by_block_key : Map[String, @dhtml.HtmlBlockQuoteFact] = Map([])
  let code_block_by_block_key : Map[String, @dhtml.HtmlCodeBlockFact] = Map([])
  let figure_by_block_key : Map[String, @dhtml.HtmlFigureFact] = Map([])
  let table_by_block_key : Map[String, @dhtml.HtmlTableFact] = Map([])
  let table_row_by_key : Map[String, @dhtml.HtmlTableRowFact] = Map([])
  let table_cell_by_key : Map[String, @dhtml.HtmlTableCellFact] = Map([])
  let table_section_by_key : Map[String, @dhtml.HtmlTableSectionFact] = Map([])
  let inline_by_key : Map[String, @dhtml.HtmlInlineFact] = Map([])
  let link_by_inline_key : Map[String, @dhtml.HtmlLinkFact] = Map([])
  let image_by_inline_key : Map[String, @dhtml.HtmlImageFact] = Map([])
  let image_by_key : Map[String, @dhtml.HtmlImageFact] = Map([])
  let top_level_inline_facts_by_block_key : Map[
    String,
    Array[@dhtml.HtmlInlineFact],
  ] = Map([])
  let skipped_block_keys : Map[String, Bool] = Map([])

  for block in semantic.blocks {
    block_by_key.set(block.source_key, block)
  }
  for paragraph in semantic.paragraphs {
    paragraph_by_block_key.set(paragraph.block_source_key, paragraph)
  }
  for list in semantic.lists {
    list_by_block_key.set(list.block_source_key, list)
    list_by_source_key.set(list.source_key, list)
  }
  for item in semantic.list_items {
    list_item_by_block_key.set(item.block_source_key, item)
  }
  for quote in semantic.blockquotes {
    blockquote_by_block_key.set(quote.block_source_key, quote)
  }
  for code in semantic.code_blocks {
    code_block_by_block_key.set(code.block_source_key, code)
    match code.code_block_source_key {
      Some(key) => code_block_by_block_key.set(key, code)
      None => ()
    }
  }
  for figure in semantic.figures {
    figure_by_block_key.set(figure.block_source_key, figure)
  }
  for table in semantic.tables {
    table_by_block_key.set(table.block_source_key, table)
  }
  for row in semantic.table_rows {
    table_row_by_key.set(row.source_key, row)
  }
  for cell in semantic.table_cells {
    table_cell_by_key.set(cell.source_key, cell)
  }
  for section in semantic.table_sections {
    table_section_by_key.set(section.source_key, section)
  }
  for inline in semantic.inlines {
    inline_by_key.set(inline.source_key, inline)
    if inline.parent_block_source_key is Some(_) &&
      inline.parent_inline_source_key is None {
      match inline.parent_block_source_key {
        Some(block_key) =>
          html_lowering_map_push_inline_fact(
            top_level_inline_facts_by_block_key, block_key, inline,
          )
        None => ()
      }
    }
  }
  for link in semantic.links {
    link_by_inline_key.set(link.inline_source_key, link)
  }
  for image in semantic.images {
    image_by_inline_key.set(image.inline_source_key, image)
    image_by_key.set(image.source_key, image)
  }
  html_mark_skipped_blocks(
    semantic, block_by_key, skipped_block_keys, nav_spans,
  )
  {
    block_by_key,
    paragraph_by_block_key,
    list_by_block_key,
    list_by_source_key,
    list_item_by_block_key,
    blockquote_by_block_key,
    code_block_by_block_key,
    figure_by_block_key,
    table_by_block_key,
    table_row_by_key,
    table_cell_by_key,
    table_section_by_key,
    inline_by_key,
    link_by_inline_key,
    image_by_inline_key,
    image_by_key,
    top_level_inline_facts_by_block_key,
    skipped_block_keys,
  }
}
