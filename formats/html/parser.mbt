///|
fn html_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    true,
    @parser.StreamingGranularity::HtmlTokenStructure,
    false,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
pub fn html_lite_parser() -> @parser.Parser {
  @parser.make_parser(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    html_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_html_document_result(source, context)
    },
  )
}

///|
pub fn html_document_to_ir(
  source : @input.InputSource,
  text : String,
) -> Result[(@core.DocumentIR, @core.Diagnostics), String] {
  let diagnostics = @light_common.empty_parser_diagnostics(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "html",
  )
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "dom_ast_model")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @light_common.apply_readiness_metrics(diagnostics, "html", "near_ready")

  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) => {
      let inspect = @dhtml.inspect_html_document(doc)
      let validation = @dhtml.validate_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_report = @dhtml.inspect_html_semantic_document(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_report,
        text,
        0,
        false,
        document.assets.length(),
      )
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      let with_diagnostics = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok((with_diagnostics, diagnostics))
    }
    Err(err) => Err(err)
  }
}

///|
fn parse_html_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }

  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Err(err) => {
      let diagnostics = @light_common.empty_parser_diagnostics(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "html",
      )
      return Ok(malformed_html_parse_result(source, text, diagnostics, err))
    }
    Ok(doc) => {
      let diagnostics = @light_common.empty_parser_diagnostics(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "html",
      )
      diagnostics.metrics.set("parser_name", "html_parser")
      diagnostics.metrics.set("parser_mode", "dom_ast_model")
      diagnostics.metrics.set(
        "input_kind",
        @light_common.input_kind_name(source.kind),
      )
      diagnostics.metrics.set("detected_format", "html")
      diagnostics.metrics.set(
        "requested_mode",
        @light_common.requested_mode_name(context),
      )
      diagnostics.metrics.set("ir_input_kind", "document")
      @light_common.apply_readiness_metrics(diagnostics, "html", "near_ready")

      let inspect = @dhtml.inspect_html_document(doc)
      let validation = @dhtml.validate_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_report = @dhtml.inspect_html_semantic_document(semantic)
      if html_dom_limit_reached(context, inspect, semantic_report) {
        let document = lower_html_document(doc, semantic, source)
        let lowered = @pipeline.blocks_to_event_stream(document.blocks)
        html_fill_common_metrics(
          diagnostics,
          inspect,
          validation,
          semantic_report,
          text,
          lowered.length(),
          true,
          document.assets.length(),
        )
        diagnostics.metrics.set("parser_mode", "streaming_event")
        diagnostics.metrics.set("effective_mode", "streaming_event")
        diagnostics.metrics.set("ir_input_kind", "event_stream")
        diagnostics.metrics.set("streaming_fallback", "true")
        diagnostics.metrics.set("resource_limit_hit", "true")
        diagnostics.metrics.set("dom_limit_reached", "true")
        diagnostics.metrics.set("event_granularity", "html_token_structure")
        diagnostics.metrics.set(
          "event_semantics", "html_token_structure_event_stream",
        )
        diagnostics.metrics.set(
          "block_count",
          document.blocks.length().to_string(),
        )
        diagnostics.pass_trace.push("parse:html_parser")
        return Ok(
          @parser.parse_result_with_events_capability(
            "html_parser",
            @parser.ParserMode::StreamingEvent,
            lowered,
            diagnostics,
            html_parser_capability(),
          ),
        )
      }

      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_report,
        text,
        0,
        false,
        document.assets.length(),
      )
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
      diagnostics.metrics.set("streaming_fallback", "false")
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("dom_limit_reached", "false")
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      diagnostics.metrics.set("event_granularity", "none")
      diagnostics.metrics.set("event_semantics", "dom_ast_model")
      diagnostics.pass_trace.push("parse:html_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "html_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          html_parser_capability(),
        ),
      )
    }
  }
}

///|
fn html_dom_limit_reached(
  context : @parser.ParseContext,
  inspect : @dhtml.HtmlInspectReport,
  semantic_report : @dhtml.HtmlSemanticInspectReport,
) -> Bool {
  let node_limit = context.max_cells.unwrap_or(10000)
  let depth_limit = context.max_rows.unwrap_or(200)
  inspect.node_count > node_limit ||
  semantic_report.inline_count > node_limit ||
  semantic_report.block_count > node_limit ||
  inspect.max_depth > depth_limit
}

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
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set(
    "resource_limit_hit",
    @light_common.bool_string(large_mode),
  )
  diagnostics.metrics.set(
    "has_doctype",
    @light_common.bool_string(inspect.has_doctype),
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
  let document = @core.empty_document_ir()
  let dom_index = html_dom_lowering_index(doc)
  let top_blocks = html_collect_top_level_blocks(semantic, dom_index.nav_spans)

  for block in top_blocks {
    html_append_flattened_blocks(
      document.blocks,
      html_blocks_for_block(
        document,
        semantic,
        source,
        block,
        dom_index.block_elements,
      ),
    )
  }

  match html_primary_title(semantic) {
    Some(title) =>
      if title.trim() != "" {
        document.metadata.set("title", @core.JsonValue::String(title))
      }
    None => ()
  }

  document
}

///|
priv struct HtmlDomLoweringIndex {
  block_elements : Map[String, @dhtml.HtmlElement]
  nav_spans : Array[@dhtml.HtmlSourceSpan]
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
fn html_collect_top_level_blocks(
  semantic : @dhtml.HtmlSemanticDocument,
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Array[@dhtml.HtmlBlockFact] {
  let out : Array[@dhtml.HtmlBlockFact] = []
  let scope_root = html_selected_scope_root_key(semantic)
  let skipped : Map[String, Bool] = Map([])
  for unsupported in semantic.unsupported {
    skipped.set(unsupported.source_key, true)
  }
  html_mark_noise_subtrees(semantic, skipped)
  for block in semantic.blocks {
    if html_block_should_skip(semantic, skipped, block, nav_spans) {
      continue
    }
    if scope_root == Some(block.source_key) {
      continue
    }
    let is_top = match scope_root {
      Some(root_key) => block.parent_source_key == Some(root_key)
      None => block.parent_source_key is None
    }
    if is_top {
      out.push(block)
    }
  }
  out.sort_by(fn(a, b) { a.source_order.compare(b.source_order) })
  out
}

///|
fn html_block_should_skip(
  semantic : @dhtml.HtmlSemanticDocument,
  skipped : Map[String, Bool],
  block : @dhtml.HtmlBlockFact,
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Bool {
  if skipped.contains(block.source_key) {
    return true
  }
  if html_block_span_in_nav_span(block.span, nav_spans) {
    return true
  }
  if html_block_has_ancestor_tag(semantic, block.source_key, "nav") {
    return true
  }
  for noise in semantic.noise_candidates {
    if !html_noise_should_skip(noise) {
      continue
    }
    if html_block_matches_noise_candidate(semantic, block, noise) {
      return true
    }
  }
  false
}

///|
fn html_block_span_in_nav_span(
  span : @dhtml.HtmlSourceSpan,
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Bool {
  for nav_span in nav_spans {
    if span.line_start >= nav_span.line_start &&
      span.line_end <= nav_span.line_end {
      return true
    }
  }
  false
}

///|
fn html_selected_scope_root_key(
  semantic : @dhtml.HtmlSemanticDocument,
) -> String? {
  for scope in semantic.scope {
    if scope.selected_content_root_key is Some(_) {
      return scope.selected_content_root_key
    }
  }
  None
}

///|
fn html_mark_noise_subtrees(
  semantic : @dhtml.HtmlSemanticDocument,
  skipped : Map[String, Bool],
) -> Unit {
  for noise in semantic.noise_candidates {
    match noise.block_source_key {
      Some(key) =>
        if html_noise_should_skip(noise) {
          skipped.set(key, true)
          html_mark_block_subtree(semantic, key, skipped)
        }
      None => ()
    }
  }
}

///|
fn html_noise_should_skip(noise : @dhtml.HtmlNoiseCandidateFact) -> Bool {
  if noise.tag_name == "nav" {
    return true
  }
  for reason in noise.reasons {
    match reason {
      @dhtml.HtmlNoiseCandidateReason::NavLike
      | @dhtml.HtmlNoiseCandidateReason::FooterLike
      | @dhtml.HtmlNoiseCandidateReason::Hiddenish
      | @dhtml.HtmlNoiseCandidateReason::ScriptStyleTemplate => return true
      _ => ()
    }
  }
  false
}

///|
fn html_mark_block_subtree(
  semantic : @dhtml.HtmlSemanticDocument,
  root_key : String,
  skipped : Map[String, Bool],
) -> Unit {
  for block in semantic.blocks {
    if block.parent_source_key == Some(root_key) {
      skipped.set(block.source_key, true)
      html_mark_block_subtree(semantic, block.source_key, skipped)
    }
  }
}

///|
fn html_block_matches_noise_candidate(
  semantic : @dhtml.HtmlSemanticDocument,
  block : @dhtml.HtmlBlockFact,
  noise : @dhtml.HtmlNoiseCandidateFact,
) -> Bool {
  if noise.block_source_key == Some(block.source_key) ||
    noise.source_key == block.source_key {
    return true
  }
  html_block_has_ancestor_key(semantic, block.source_key, noise.source_key) ||
  noise.block_source_key
  .map(fn(key) { html_block_has_ancestor_key(semantic, block.source_key, key) })
  .unwrap_or(false)
}

///|
fn html_block_has_ancestor_tag(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
  tag_name : String,
) -> Bool {
  let mut current = html_parent_source_key_for_block(semantic, block_source_key)
  while current is Some(_) {
    match current {
      Some(key) =>
        match html_block_by_key(semantic, key) {
          Some(block) =>
            if block.tag_name == tag_name {
              return true
            } else {
              current = block.parent_source_key
            }
          None => return false
        }
      None => ()
    }
  }
  false
}

///|
fn html_block_has_ancestor_key(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
  ancestor_key : String,
) -> Bool {
  let mut current = html_parent_source_key_for_block(semantic, block_source_key)
  while current is Some(_) {
    match current {
      Some(key) =>
        if key == ancestor_key {
          return true
        } else {
          current = html_parent_source_key_for_block(semantic, key)
        }
      None => ()
    }
  }
  false
}

///|
fn html_parent_source_key_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> String? {
  match html_block_by_key(semantic, block_source_key) {
    Some(block) => block.parent_source_key
    None => None
  }
}

///|
fn html_blocks_for_block(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  match block.kind {
    @dhtml.HtmlBlockKind::Heading(level) =>
      html_heading_blocks(document, semantic, source, block, level)
    @dhtml.HtmlBlockKind::Paragraph =>
      html_paragraph_blocks_for_block(document, semantic, source, block)
    @dhtml.HtmlBlockKind::List(_) =>
      html_list_container_blocks(document, semantic, source, block, dom_blocks)
    @dhtml.HtmlBlockKind::ListItem =>
      html_list_item_blocks(document, semantic, source, block, dom_blocks)
    @dhtml.HtmlBlockKind::Table =>
      html_table_blocks(document, semantic, source, block)
    @dhtml.HtmlBlockKind::BlockQuote =>
      html_blockquote_blocks(document, semantic, source, block, dom_blocks)
    @dhtml.HtmlBlockKind::Pre => html_code_blocks(semantic, source, block)
    @dhtml.HtmlBlockKind::CodeBlock => html_code_blocks(semantic, source, block)
    @dhtml.HtmlBlockKind::Figure =>
      html_figure_blocks(document, semantic, source, block)
    @dhtml.HtmlBlockKind::HorizontalRule =>
      [html_horizontal_rule_block(source, block)]
    @dhtml.HtmlBlockKind::UnknownBlock =>
      html_unknown_container_blocks(
        document, semantic, source, block, dom_blocks,
      )
    @dhtml.HtmlBlockKind::FigCaption
    | @dhtml.HtmlBlockKind::TableRow
    | @dhtml.HtmlBlockKind::TableCell(_)
    | @dhtml.HtmlBlockKind::UnsupportedBlock => []
  }
}

///|
fn html_heading_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  level : Int,
) -> Array[@core.CoreBlock] {
  let inlines = html_inlines_for_block(
    document,
    semantic,
    source,
    block.source_key,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    return []
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    text,
    source_ref=html_block_source_ref(source, block),
  )
  heading.attrs.set("level", @light_common.clamp_int(level, 1, 6).to_string())
  heading.attrs.set("literal", "true")
  heading.attrs.set("render_inline_escape_mode", "minimal")
  [@core.block_with_rich_inlines(heading, Some(inlines))]
}

///|
fn html_paragraph_blocks_for_block(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> Array[@core.CoreBlock] {
  let inlines = html_inlines_for_paragraph(
    document,
    semantic,
    source,
    block.source_key,
  )
  html_paragraph_inlines_to_blocks(
    inlines,
    html_block_source_ref(source, block),
  )
}

///|
fn html_list_container_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=html_block_source_ref(source, block),
  )
  match html_list_for_block(semantic, block.source_key) {
    Some(fact) =>
      list.attrs.set(
        "ordered",
        @light_common.bool_string(fact.kind == @dhtml.HtmlListKind::Ordered),
      )
    None => ()
  }
  let trailing_blocks : Array[@core.CoreBlock] = []
  for child_key in block.children {
    match html_block_by_key(semantic, child_key) {
      Some(child) =>
        if child.kind == @dhtml.HtmlBlockKind::ListItem {
          let item_blocks = html_list_item_blocks(
            document, semantic, source, child, dom_blocks,
          )
          if item_blocks.length() > 0 &&
            item_blocks[0].kind == @core.BlockKind::ListItem {
            list.children.push(item_blocks[0])
            if item_blocks.length() > 1 {
              for extra in item_blocks[1:] {
                trailing_blocks.push(extra)
              }
            }
          }
        }
      None => ()
    }
  }
  if list.children.length() == 0 {
    []
  } else {
    let out : Array[@core.CoreBlock] = [list]
    out.append(trailing_blocks[:])
    out
  }
}

///|
fn html_list_item_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  match dom_blocks.get(block.source_key) {
    Some(element) =>
      return html_list_item_blocks_from_dom(
        document, semantic, source, block, element, dom_blocks,
      )
    None => ()
  }
  let source_ref = html_block_source_ref(source, block)
  let ordered = html_list_item_is_ordered(semantic, block.source_key)
  let child_blocks = html_child_blocks_sorted(semantic, block.children)
  let inline_segments = html_core_inline_segments_for_block(
    document,
    semantic,
    source,
    block.source_key,
    child_blocks,
  )
  let primary_child_index = if inline_segments[0].length() > 0 {
    None
  } else {
    html_list_item_primary_child_index(child_blocks)
  }
  let primary_inlines = if inline_segments[0].length() > 0 {
    inline_segments[0]
  } else {
    match primary_child_index {
      Some(index) =>
        html_trim_core_inlines_edges(
          html_inlines_for_paragraph(
            document,
            semantic,
            source,
            child_blocks[index].source_key,
          ),
        )
      None => []
    }
  }
  let text = html_render_plain_inlines(primary_inlines).trim().to_owned()
  let item = @core.make_block(@core.BlockKind::ListItem, text, source_ref~)
  item.attrs.set("ordered", @light_common.bool_string(ordered))
  if ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = item
  if primary_inlines.length() > 0 {
    root = @core.block_with_rich_inlines(root, Some(primary_inlines))
  }
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  for index in 0..<child_blocks.length() {
    let child = child_blocks[index]
    if primary_child_index != Some(index) {
      match child.kind {
        @dhtml.HtmlBlockKind::List(_) =>
          html_append_flattened_blocks(
            nested_lists,
            html_blocks_for_block(document, semantic, source, child, dom_blocks),
          )
        @dhtml.HtmlBlockKind::BlockQuote =>
          html_append_flattened_blocks(
            extras,
            html_blockquote_body_blocks(
              document, semantic, source, child, dom_blocks,
            ),
          )
        _ =>
          html_append_flattened_blocks(
            extras,
            html_blocks_for_block(document, semantic, source, child, dom_blocks),
          )
      }
    }
    if index + 1 < inline_segments.length() &&
      inline_segments[index + 1].length() > 0 {
      html_append_flattened_blocks(
        extras,
        html_core_inline_segment_to_blocks(
          inline_segments[index + 1],
          source_ref,
        ),
      )
    }
  }
  if nested_lists.length() > 0 {
    root = @core.block_with_children(root, nested_lists)
  }
  if text == "" && nested_lists.length() == 0 && extras.length() == 0 {
    return []
  }
  let out : Array[@core.CoreBlock] = [root]
  out.append(extras[:])
  out
}

///|
fn html_list_item_blocks_from_dom(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  element : @dhtml.HtmlElement,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  let ordered = html_list_item_is_ordered(semantic, block.source_key)
  let source_ref = html_block_source_ref(source, block)
  let pieces = html_container_child_blocks_from_dom(
    document,
    semantic,
    source,
    block,
    element,
    dom_blocks,
    flatten_blockquotes=true,
  )
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  let mut root_piece_index : Int? = None
  for index in 0..<pieces.length() {
    let piece = pieces[index]
    if piece.kind == @core.BlockKind::List {
      nested_lists.push(piece)
    } else if root_piece_index is None &&
      piece.kind == @core.BlockKind::Paragraph {
      root_piece_index = Some(index)
    } else {
      extras.push(piece)
    }
  }
  let root_text = match root_piece_index {
    Some(index) => pieces[index].text
    None => ""
  }
  let item = @core.make_block(@core.BlockKind::ListItem, root_text, source_ref~)
  item.attrs.set("ordered", @light_common.bool_string(ordered))
  if ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = item
  match root_piece_index {
    Some(index) =>
      match pieces[index].rich_inlines {
        Some(inlines) if inlines.length() > 0 =>
          root = @core.block_with_rich_inlines(root, Some(inlines))
        _ => ()
      }
    None => ()
  }
  if nested_lists.length() > 0 {
    root = @core.block_with_children(root, nested_lists)
  }
  if root_text == "" && nested_lists.length() == 0 && extras.length() == 0 {
    return []
  }
  let out : Array[@core.CoreBlock] = [root]
  out.append(extras[:])
  out
}

///|
fn html_list_item_primary_child_index(
  child_blocks : Array[@dhtml.HtmlBlockFact],
) -> Int? {
  for index in 0..<child_blocks.length() {
    if child_blocks[index].kind == @dhtml.HtmlBlockKind::Paragraph {
      return Some(index)
    }
  }
  None
}

///|
fn html_table_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> Array[@core.CoreBlock] {
  match html_table_to_block(document, semantic, source, block.source_key) {
    Some(table) => [table]
    None =>
      if block.text_preview.trim() == "" {
        []
      } else {
        [
          @core.make_block(
            @core.BlockKind::Paragraph,
            block.text_preview.trim().to_owned(),
            source_ref=html_block_source_ref(source, block),
          ),
        ]
      }
  }
}

///|
fn html_blockquote_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  let body_blocks = html_blockquote_body_blocks(
    document, semantic, source, block, dom_blocks,
  )
  if body_blocks.length() == 0 {
    let fallback = html_paragraph_blocks_for_block(
      document, semantic, source, block,
    )
    let lines = html_quote_lines_from_blocks(fallback)
    if lines.length() == 0 {
      []
    } else {
      [
        @core.make_block(
          @core.BlockKind::BlockQuote,
          lines.join("\n"),
          source_ref=html_block_source_ref(source, block),
        ),
      ]
    }
  } else {
    let quote = @core.make_block(
      @core.BlockKind::BlockQuote,
      html_quote_lines_from_blocks(body_blocks).join("\n"),
      source_ref=html_block_source_ref(source, block),
    )
    [@core.block_with_children(quote, body_blocks)]
  }
}

///|
fn html_blockquote_body_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  match dom_blocks.get(block.source_key) {
    Some(element) =>
      return html_container_child_blocks_from_dom(
        document,
        semantic,
        source,
        block,
        element,
        dom_blocks,
        flatten_blockquotes=true,
      )
    None => ()
  }
  let child_blocks = match
    html_blockquote_for_block(semantic, block.source_key) {
    Some(quote) =>
      html_child_blocks_sorted(semantic, quote.child_block_source_keys)
    None => html_child_blocks_sorted(semantic, block.children)
  }
  let inline_segments = html_core_inline_segments_for_block(
    document,
    semantic,
    source,
    block.source_key,
    child_blocks,
  )
  if child_blocks.length() == 0 {
    return html_core_inline_segment_to_blocks(
      inline_segments[0],
      html_block_source_ref(source, block),
    )
  }
  let out : Array[@core.CoreBlock] = []
  for index in 0..<child_blocks.length() {
    if inline_segments[index].length() > 0 {
      html_append_flattened_blocks(
        out,
        html_core_inline_segment_to_blocks(
          inline_segments[index],
          html_block_source_ref(source, block),
        ),
      )
    }
    html_append_flattened_blocks(
      out,
      html_blocks_for_block(
        document,
        semantic,
        source,
        child_blocks[index],
        dom_blocks,
      ),
    )
  }
  if inline_segments[child_blocks.length()].length() > 0 {
    html_append_flattened_blocks(
      out,
      html_core_inline_segment_to_blocks(
        inline_segments[child_blocks.length()],
        html_block_source_ref(source, block),
      ),
    )
  }
  out
}

///|
fn html_container_child_blocks_from_dom(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  element : @dhtml.HtmlElement,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  flatten_blockquotes? : Bool = false,
) -> Array[@core.CoreBlock] {
  let child_blocks = html_child_blocks_sorted(semantic, block.children)
  let top_level_inline_facts = html_top_level_inline_facts_for_block(
    semantic,
    block.source_key,
  )
  let current_inline_facts : Array[@dhtml.HtmlInlineFact] = []
  let out : Array[@core.CoreBlock] = []
  let mut inline_index = 0
  let mut child_index = 0

  fn flush_current_inline_facts(
    out : Array[@core.CoreBlock],
    current_inline_facts : Array[@dhtml.HtmlInlineFact],
    document : @core.DocumentIR,
    semantic : @dhtml.HtmlSemanticDocument,
    source : @input.InputSource,
    block : @dhtml.HtmlBlockFact,
  ) -> Unit {
    if current_inline_facts.length() == 0 {
      return
    }
    html_append_flattened_blocks(
      out,
      html_inline_segment_to_blocks(
        document,
        semantic,
        source,
        current_inline_facts,
        html_block_source_ref(source, block),
      ),
    )
    current_inline_facts.clear()
  }

  for child in element.children {
    match child {
      @dhtml.HtmlNode::Element(child_element) =>
        if html_dom_nav_like(child_element) {
          flush_current_inline_facts(
            out, current_inline_facts, document, semantic, source, block,
          )
        } else if html_dom_counts_as_block(child_element.tag_name, false) {
          flush_current_inline_facts(
            out, current_inline_facts, document, semantic, source, block,
          )
          match
            html_find_matching_child_block(
              child_blocks, child_index, child_element,
            ) {
            Some((index, child_block)) => {
              child_index = index + 1
              let lowered = if flatten_blockquotes &&
                child_block.kind == @dhtml.HtmlBlockKind::BlockQuote {
                html_blockquote_body_blocks(
                  document, semantic, source, child_block, dom_blocks,
                )
              } else {
                html_blocks_for_block(
                  document, semantic, source, child_block, dom_blocks,
                )
              }
              html_append_flattened_blocks(out, lowered)
            }
            None => ()
          }
        } else {
          inline_index = html_dom_consume_inline_facts_from_node(
            child, top_level_inline_facts, inline_index, current_inline_facts, false,
          )
        }
      _ =>
        inline_index = html_dom_consume_inline_facts_from_node(
          child, top_level_inline_facts, inline_index, current_inline_facts, false,
        )
    }
  }

  while inline_index < top_level_inline_facts.length() {
    current_inline_facts.push(top_level_inline_facts[inline_index])
    inline_index += 1
  }
  flush_current_inline_facts(
    out, current_inline_facts, document, semantic, source, block,
  )
  out
}

///|
fn html_find_matching_child_block(
  child_blocks : Array[@dhtml.HtmlBlockFact],
  start : Int,
  element : @dhtml.HtmlElement,
) -> (Int, @dhtml.HtmlBlockFact)? {
  for index in start..<child_blocks.length() {
    let block = child_blocks[index]
    if block.tag_name == element.tag_name &&
      block.span.line_start == element.span.line_start &&
      block.span.line_end == element.span.line_end {
      return Some((index, block))
    }
  }
  for index in start..<child_blocks.length() {
    let block = child_blocks[index]
    if block.tag_name == element.tag_name {
      return Some((index, block))
    }
  }
  None
}

///|
fn html_dom_consume_inline_facts_from_node(
  node : @dhtml.HtmlNode,
  facts : Array[@dhtml.HtmlInlineFact],
  start : Int,
  out : Array[@dhtml.HtmlInlineFact],
  parent_pre : Bool,
) -> Int {
  match node {
    @dhtml.HtmlNode::Text(_) =>
      if start < facts.length() &&
        facts[start].kind == @dhtml.HtmlInlineKind::Text {
        out.push(facts[start])
        start + 1
      } else {
        start
      }
    @dhtml.HtmlNode::Element(element) =>
      if html_dom_counts_as_block(element.tag_name, parent_pre) {
        start
      } else if html_dom_element_has_top_level_inline_fact(
          element.tag_name,
          parent_pre,
        ) {
        if start < facts.length() {
          out.push(facts[start])
          start + 1
        } else {
          start
        }
      } else {
        let mut next = start
        for child in element.children {
          next = html_dom_consume_inline_facts_from_node(
            child,
            facts,
            next,
            out,
            parent_pre || element.tag_name == "pre",
          )
        }
        next
      }
    _ => start
  }
}

///|
fn html_dom_element_has_top_level_inline_fact(
  tag_name : String,
  parent_pre : Bool,
) -> Bool {
  match tag_name {
    "a"
    | "img"
    | "em"
    | "i"
    | "strong"
    | "b"
    | "br"
    | "span"
    | "small"
    | "mark"
    | "sub"
    | "sup" => true
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
fn html_code_blocks(
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> Array[@core.CoreBlock] {
  match html_code_block_for_block(semantic, block.source_key) {
    Some(code) =>
      if code.code_text.trim() == "" {
        []
      } else {
        let out = @core.make_block(
          @core.BlockKind::Code,
          code.code_text,
          source_ref=html_block_source_ref(source, block),
        )
        match code.language_hint {
          Some(language) if language.trim() != "" =>
            out.attrs.set("info", language.trim().to_owned())
          None => ()
          _ => ()
        }
        [out]
      }
    None => []
  }
}

///|
fn html_figure_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> Array[@core.CoreBlock] {
  match html_figure_for_block(semantic, block.source_key) {
    Some(figure) =>
      if figure.image_source_keys.length() == 0 {
        []
      } else {
        match html_image_by_key(semantic, figure.image_source_keys[0]) {
          Some(image) =>
            match html_image_to_asset(document, source, image) {
              Some(asset) => {
                let image_block = html_image_block_from_asset(
                  asset.0,
                  asset.1,
                  image.alt.unwrap_or("image").trim().to_owned(),
                  image.title,
                  figure.caption_text_preview,
                )
                [
                  @core.make_block(
                    @core.BlockKind::Image,
                    image_block.text,
                    source_ref=html_block_source_ref(source, block),
                  )
                  |> with_html_image_attrs(image_block),
                ]
              }
              None =>
                if image.kind == @dhtml.HtmlImageKind::Remote {
                  []
                } else {
                  let label = html_image_placeholder_text(
                    image.kind,
                    image.alt.unwrap_or("image").trim().to_owned(),
                  )
                  let out : Array[@core.CoreBlock] = [
                    @core.make_block(
                      @core.BlockKind::Paragraph,
                      label,
                      source_ref=html_block_source_ref(source, block),
                    ),
                  ]
                  match figure.caption_text_preview {
                    Some(caption) if caption.trim() != "" =>
                      out.push(
                        @core.make_block(
                          @core.BlockKind::Paragraph,
                          caption.trim().to_owned(),
                          source_ref=html_block_source_ref(source, block),
                        ),
                      )
                    None => ()
                    _ => ()
                  }
                  out
                }
            }
          None => []
        }
      }
    None => []
  }
}

///|
fn html_horizontal_rule_block(
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> @core.CoreBlock {
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "---",
    source_ref=html_block_source_ref(source, block),
  )
  raw.attrs.set("raw_kind", "thematic_break")
  raw
}

///|
fn html_unknown_container_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  if block.tag_name == "summary" {
    let summary = html_top_level_inline_facts_for_block(
      semantic,
      block.source_key,
    )
    if summary.length() > 0 {
      return html_inline_segment_to_blocks(
        document,
        semantic,
        source,
        summary,
        html_inline_source_ref(source, summary[0]),
      )
    }
    if block.text_preview.trim() != "" {
      return [
        @core.make_block(
          @core.BlockKind::Paragraph,
          block.text_preview.trim().to_owned(),
          source_ref=html_block_source_ref(source, block),
        ),
      ]
    }
  }
  html_blocks_for_child_keys(
    document,
    semantic,
    source,
    block.children,
    dom_blocks,
  )
}

///|
fn html_blocks_for_child_keys(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  keys : Array[String],
  dom_blocks : Map[String, @dhtml.HtmlElement],
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for key in keys {
    match html_block_by_key(semantic, key) {
      Some(child) =>
        if !html_block_should_skip_descendant(semantic, child) {
          html_append_flattened_blocks(
            out,
            html_blocks_for_block(document, semantic, source, child, dom_blocks),
          )
        }
      None => ()
    }
  }
  out
}

///|
fn html_block_should_skip_descendant(
  semantic : @dhtml.HtmlSemanticDocument,
  block : @dhtml.HtmlBlockFact,
) -> Bool {
  if block.tag_name == "nav" ||
    html_block_has_ancestor_tag(semantic, block.source_key, "nav") {
    return true
  }
  for noise in semantic.noise_candidates {
    if html_noise_should_skip(noise) &&
      html_block_matches_descendant_noise_candidate(semantic, block, noise) {
      return true
    }
  }
  false
}

///|
fn html_block_matches_descendant_noise_candidate(
  semantic : @dhtml.HtmlSemanticDocument,
  block : @dhtml.HtmlBlockFact,
  noise : @dhtml.HtmlNoiseCandidateFact,
) -> Bool {
  if noise.block_source_key == Some(block.source_key) {
    return true
  }
  noise.block_source_key
  .map(fn(key) { html_block_has_ancestor_key(semantic, block.source_key, key) })
  .unwrap_or(false)
}

///|
fn html_append_flattened_blocks(
  out : Array[@core.CoreBlock],
  blocks : Array[@core.CoreBlock],
) -> Unit {
  for block in blocks {
    out.push(block)
  }
}

///|
fn html_inlines_for_block(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
) -> Array[@core.CoreInline] {
  html_inline_keys_to_core_inlines(
    document,
    semantic,
    source,
    html_top_level_inline_keys_for_block(semantic, block_source_key),
    true,
  )
}

///|
fn html_inlines_for_paragraph(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
) -> Array[@core.CoreInline] {
  match html_paragraph_for_block(semantic, block_source_key) {
    Some(paragraph) =>
      html_inline_keys_to_core_inlines(
        document,
        semantic,
        source,
        paragraph.inline_child_keys,
        true,
      )
    None => html_inlines_for_block(document, semantic, source, block_source_key)
  }
}

///|
fn html_paragraph_inlines_to_blocks(
  inlines : Array[@core.CoreInline],
  source_ref : @core.SourceRef,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let current : Array[@core.CoreInline] = []

  fn flush_paragraph(
    blocks : Array[@core.CoreBlock],
    current : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    let snapshot = html_trim_core_inlines_edges(current)
    let text = html_render_plain_inlines(snapshot).trim().to_owned()
    if text == "" {
      current.clear()
      return
    }
    let block = @core.make_block(@core.BlockKind::Paragraph, text, source_ref~)
    block.attrs.set("literal", "true")
    block.attrs.set("render_inline_escape_mode", "minimal")
    blocks.push(@core.block_with_rich_inlines(block, Some(snapshot)))
    current.clear()
  }

  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Image => {
        flush_paragraph(blocks, current, source_ref)
        let image = @core.make_block(
          @core.BlockKind::Image,
          "",
          source_ref=inline.source_ref.unwrap_or(source_ref),
        )
        image.attrs.set("literal", "true")
        image.attrs.set("render_inline_escape_mode", "minimal")
        image.attrs.set("alt", inline.text.trim().to_owned())
        image.attrs.set("path", inline.href.unwrap_or("#"))
        match inline.title {
          Some(title) if title.trim() != "" =>
            image.attrs.set("title", title.trim().to_owned())
          None => ()
          _ => ()
        }
        blocks.push(image)
      }
      _ => current.push(inline)
    }
  }
  flush_paragraph(blocks, current, source_ref)
  blocks
}

///|
fn html_inline_segment_to_blocks(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  segment : Array[@dhtml.HtmlInlineFact],
  fallback_source_ref : @core.SourceRef,
) -> Array[@core.CoreBlock] {
  let inlines = html_inline_facts_to_core_inlines(
    document,
    semantic,
    source,
    segment,
    trim_edges=true,
  )
  let source_ref = if segment.length() > 0 {
    html_inline_source_ref(source, segment[0])
  } else {
    fallback_source_ref
  }
  html_paragraph_inlines_to_blocks(inlines, source_ref)
}

///|
fn html_core_inline_segment_to_blocks(
  inlines : Array[@core.CoreInline],
  fallback_source_ref : @core.SourceRef,
) -> Array[@core.CoreBlock] {
  let source_ref = if inlines.length() > 0 {
    inlines[0].source_ref.unwrap_or(fallback_source_ref)
  } else {
    fallback_source_ref
  }
  html_paragraph_inlines_to_blocks(inlines, source_ref)
}

///|
fn html_inline_facts_to_core_inlines(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  facts : Array[@dhtml.HtmlInlineFact],
  trim_edges? : Bool = false,
) -> Array[@core.CoreInline] {
  let keys = facts.map(inline => inline.source_key)
  let inlines = html_inline_keys_to_core_inlines(
    document, semantic, source, keys, true,
  )
  if trim_edges {
    html_trim_core_inlines_edges(inlines)
  } else {
    inlines
  }
}

///|
fn html_inline_keys_to_core_inlines(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  inline_keys : Array[String],
  allow_links : Bool,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for key in inline_keys {
    match html_inline_by_key(semantic, key) {
      Some(inline) =>
        html_append_inline(document, out, semantic, source, inline, allow_links)
      None => ()
    }
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_append_inline(
  document : @core.DocumentIR,
  out : Array[@core.CoreInline],
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  inline : @dhtml.HtmlInlineFact,
  allow_links : Bool,
) -> Unit {
  let source_ref = html_inline_source_ref(source, inline)
  match inline.kind {
    @dhtml.HtmlInlineKind::Text =>
      html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
    @dhtml.HtmlInlineKind::Break =>
      out.push(@core.make_inline_line_break(source_ref~))
    @dhtml.HtmlInlineKind::Image =>
      match html_image_for_inline(semantic, inline.source_key) {
        Some(image) =>
          match html_image_to_asset(document, source, image) {
            Some(asset) =>
              out.push(
                @core.make_inline_image(
                  image.alt.unwrap_or("image").trim().to_owned(),
                  asset.1.path.unwrap_or("#"),
                  title=image.title.map(v => v.trim().to_owned()),
                  source_ref~,
                ),
              )
            None => {
              let placeholder = html_image_placeholder_text(
                image.kind,
                image.alt.unwrap_or("image").trim().to_owned(),
              )
              html_push_text_if_non_empty(out, placeholder, source_ref)
            }
          }
        None => ()
      }
    @dhtml.HtmlInlineKind::Link => {
      if !allow_links {
        let children = html_inline_keys_to_core_inlines(
          document,
          semantic,
          source,
          inline.children,
          false,
        )
        if children.length() == 0 {
          html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
        } else {
          out.append(children[:])
        }
        return
      }
      match html_link_for_inline(semantic, inline.source_key) {
        Some(link) =>
          match html_product_href(link) {
            Some(href) => {
              let text = html_link_text(document, semantic, source, link)
                .trim()
                .to_owned()
              if text != "" {
                out.push(@core.make_inline_link(text, href, source_ref~))
              }
            }
            None =>
              html_push_text_if_non_empty(
                out,
                link.text_preview.trim().to_owned(),
                source_ref,
              )
          }
        None =>
          html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
      }
    }
    @dhtml.HtmlInlineKind::Emphasis
    | @dhtml.HtmlInlineKind::Strong
    | @dhtml.HtmlInlineKind::Code
    | @dhtml.HtmlInlineKind::Span
    | @dhtml.HtmlInlineKind::InlineContainer
    | @dhtml.HtmlInlineKind::UnknownInline => {
      let children = html_inline_keys_to_core_inlines(
        document,
        semantic,
        source,
        inline.children,
        allow_links,
      )
      if children.length() == 0 {
        html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
      } else {
        out.append(children[:])
      }
    }
    @dhtml.HtmlInlineKind::UnsupportedInline => ()
  }
}

///|
fn html_push_text_if_non_empty(
  out : Array[@core.CoreInline],
  text : String,
  source_ref : @core.SourceRef,
) -> Unit {
  if text != "" {
    out.push(@core.make_inline_text(text, source_ref~))
  }
}

///|
fn html_link_text(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  link : @dhtml.HtmlLinkFact,
) -> String {
  if link.inline_child_keys.length() == 0 {
    return link.text_preview
  }
  html_render_plain_inlines(
    html_inline_keys_to_core_inlines(
      document,
      semantic,
      source,
      link.inline_child_keys,
      false,
    ),
  )
}

///|
fn html_image_to_asset(
  document : @core.DocumentIR,
  source : @input.InputSource,
  image : @dhtml.HtmlImageFact,
) -> (String, @core.AssetRef)? {
  if image.kind != @dhtml.HtmlImageKind::Local {
    return None
  }
  let src = html_strip_query_and_hash(image.src.trim().to_owned())
  if !html_safe_local_image_src(src) {
    return None
  }
  for existing in document.assets {
    if existing.attrs.get("source_path") == Some(src) {
      return Some((existing.asset_id, existing))
    }
  }
  let asset_index = document.assets.length() + 1
  let asset_id = "html-image-" + asset_index.to_string()
  let rel_path = "assets/image" +
    html_two_digit(asset_index) +
    "." +
    html_image_ext_from_src(src)
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref=html_image_source_ref(source, image),
  )
  let next_asset = {
    ..asset,
    path: Some(rel_path),
    attrs: Map([
      ("source_path", src),
      ("alt", image.alt.unwrap_or("image").trim().to_owned()),
    ]),
  }
  document.assets.push(next_asset)
  Some((asset_id, next_asset))
}

///|
fn html_image_block_from_asset(
  asset_id : String,
  asset : @core.AssetRef,
  alt : String,
  title : String?,
  caption : String?,
) -> @core.CoreBlock {
  let image = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=asset.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  image.attrs.set("alt", alt)
  image.attrs.set("path", asset.path.unwrap_or("#"))
  image.attrs.set("asset_id", asset_id)
  match title {
    Some(value) if value.trim() != "" =>
      image.attrs.set("title", value.trim().to_owned())
    None => ()
    _ => ()
  }
  match caption {
    Some(value) if value.trim() != "" =>
      image.attrs.set("caption", value.trim().to_owned())
    None => ()
    _ => ()
  }
  image
}

///|
fn with_html_image_attrs(
  block : @core.CoreBlock,
  template : @core.CoreBlock,
) -> @core.CoreBlock {
  { ..block, attrs: template.attrs, source_ref: template.source_ref }
}

///|
fn html_image_placeholder_text(
  kind : @dhtml.HtmlImageKind,
  alt : String,
) -> String {
  let label = if alt == "" { "image" } else { alt }
  match kind {
    @dhtml.HtmlImageKind::Remote => "[remote]"
    @dhtml.HtmlImageKind::DataUri => "[inline data]"
    @dhtml.HtmlImageKind::Unsafe => "[" + label + "]"
    _ => "[" + label + "]"
  }
}

///|
fn html_table_to_block(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
) -> @core.CoreBlock? {
  match html_table_for_block(semantic, block_source_key) {
    Some(table) => {
      if table.row_count == 0 || table.cell_count == 0 {
        return None
      }
      let out = @core.make_block(
        @core.BlockKind::Table,
        "table",
        source_ref=html_block_source_ref_by_key(
          source, semantic, block_source_key,
        ),
      )
      out.attrs.set(
        "header_rows",
        html_table_header_rows(semantic, table).to_string(),
      )
      for row_key in table.rows {
        match html_table_row_by_key(semantic, row_key) {
          Some(row) => {
            let row_values : Array[String] = []
            for cell_key in row.cell_source_keys {
              match html_table_cell_by_key(semantic, cell_key) {
                Some(cell) => {
                  let value = html_table_cell_text(
                    document, semantic, source, cell,
                  )
                  row_values.push(value)
                }
                None => ()
              }
            }
            let row_block = @core.make_block(
              @core.BlockKind::TableRow,
              row_values.join(" | "),
              source_ref=html_table_row_source_ref(source, row),
            )
            row_block.attrs.set("literal", "true")
            for value_index in 0..<row_values.length() {
              let cell_ref = if value_index < row.cell_source_keys.length() {
                match
                  html_table_cell_by_key(
                    semantic,
                    row.cell_source_keys[value_index],
                  ) {
                  Some(cell) => html_table_cell_source_ref(source, cell)
                  None => html_table_row_source_ref(source, row)
                }
              } else {
                html_table_row_source_ref(source, row)
              }
              let mut cell_block = @core.make_block(
                @core.BlockKind::TableCell,
                row_values[value_index],
                source_ref=cell_ref,
              )
              cell_block.attrs.set("literal", "true")
              cell_block.attrs.set("render_inline_escape_mode", "minimal")
              if value_index < row.cell_source_keys.length() {
                match
                  html_table_cell_by_key(
                    semantic,
                    row.cell_source_keys[value_index],
                  ) {
                  Some(cell) => {
                    let inlines = html_table_cell_inlines(
                      document, semantic, source, cell,
                    )
                    if inlines.length() > 0 {
                      cell_block = @core.block_with_rich_inlines(
                        cell_block,
                        Some(inlines),
                      )
                    }
                  }
                  None => ()
                }
              }
              row_block.children.push(cell_block)
            }
            out.children.push(row_block)
          }
          None => ()
        }
      }
      Some(out)
    }
    None => None
  }
}

///|
fn html_table_cell_text(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
) -> String {
  let inlines = html_inline_keys_to_core_inlines(
    document,
    semantic,
    source,
    cell.inline_child_keys,
    true,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    cell.text_preview.trim().to_owned()
  } else {
    text
  }
}

///|
fn html_table_cell_inlines(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
) -> Array[@core.CoreInline] {
  html_inline_keys_to_core_inlines(
    document,
    semantic,
    source,
    cell.inline_child_keys,
    true,
  )
}

///|
fn malformed_html_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
) -> @parser.ParseResult {
  diagnostics.warnings.push("html parse warning: " + err)
  diagnostics.errors.push("html fail closed: malformed input is not converted")
  diagnostics.degraded_features.push("html_fail_closed")
  diagnostics.fallback_trace.push("html fail closed: " + err)
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "html_dom_ast_model_failed_closed")
  diagnostics.metrics.set("node_count", "0")
  diagnostics.metrics.set("element_count", "0")
  diagnostics.metrics.set("text_node_count", "0")
  diagnostics.metrics.set("script_count", "0")
  diagnostics.metrics.set("style_count", "0")
  diagnostics.metrics.set("link_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("unsafe_node_count", "0")
  diagnostics.metrics.set("dropped_node_count", "0")
  diagnostics.metrics.set("unsupported_feature_count", "0")
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("degraded_feature_count", "1")
  diagnostics.metrics.set("fallback_count", "1")
  diagnostics.pass_trace.push("parse:html_parser")
  let document = @core.empty_document_ir()
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    html_parser_capability(),
  )
}

///|
fn html_top_level_inline_keys_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Array[String] {
  html_top_level_inline_facts_for_block(semantic, block_source_key).map(inline => {
    inline.source_key
  })
}

///|
fn html_inline_text(inline : @dhtml.HtmlInlineFact) -> String {
  html_normalize_inline_text(inline.raw_text_preview)
}

///|
fn html_normalize_inline_text(text : String) -> String {
  let chars = text.to_array()
  let mut has_layout_whitespace = false
  for ch in chars {
    if ch == '\n' || ch == '\r' || ch == '\t' {
      has_layout_whitespace = true
      break
    }
  }
  if !has_layout_whitespace {
    return text
  }
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in chars {
    if ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ' {
      if !prev_space {
        out.write_char(' ')
      }
      prev_space = true
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }
  out.to_string()
}

///|
fn html_product_href(link : @dhtml.HtmlLinkFact) -> String? {
  let href = link.href.trim().to_owned()
  if href == "" {
    return None
  }
  let lower = href.to_lower()
  if lower.has_prefix("javascript:") ||
    lower.has_prefix("vbscript:") ||
    lower.has_prefix("data:") {
    return None
  }
  Some(href)
}

///|
fn html_render_plain_inlines(inlines : Array[@core.CoreInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text => out.write_string(inline.text)
      @core.InlineKind::LineBreak => out.write_string("<br>")
      @core.InlineKind::Link =>
        if inline.text.trim() != "" {
          out.write_string(inline.text)
        }
      @core.InlineKind::Image =>
        if inline.text.trim() != "" {
          out.write_string("[" + inline.text.trim().to_owned() + "]")
        } else {
          out.write_string("[image]")
        }
      @core.InlineKind::Code => out.write_string(inline.text)
    }
  }
  out.to_string()
}

///|
fn html_merge_adjacent_text_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text =>
        if inline.text != "" {
          match out.pop() {
            Some(prev) if prev.kind == @core.InlineKind::Text =>
              out.push(
                @core.make_inline_text(
                  prev.text + inline.text,
                  source_ref=prev.source_ref.unwrap_or(@core.empty_source_ref()),
                ),
              )
            Some(prev) => {
              out.push(prev)
              out.push(inline)
            }
            None => out.push(inline)
          }
        }
      _ => out.push(inline)
    }
  }
  out
}

///|
fn html_block_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlBlockFact? {
  for block in semantic.blocks {
    if block.source_key == source_key {
      return Some(block)
    }
  }
  None
}

///|
fn html_paragraph_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlParagraphFact? {
  for paragraph in semantic.paragraphs {
    if paragraph.block_source_key == block_source_key {
      return Some(paragraph)
    }
  }
  None
}

///|
fn html_list_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlListFact? {
  for item in semantic.lists {
    if item.block_source_key == block_source_key {
      return Some(item)
    }
  }
  None
}

///|
fn html_list_item_is_ordered(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Bool {
  for item in semantic.list_items {
    if item.block_source_key == block_source_key {
      match item.list_source_key {
        Some(list_key) =>
          for list in semantic.lists {
            if list.source_key == list_key {
              return list.kind == @dhtml.HtmlListKind::Ordered
            }
          }
        None => ()
      }
    }
  }
  false
}

///|
fn html_blockquote_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlBlockQuoteFact? {
  for quote in semantic.blockquotes {
    if quote.block_source_key == block_source_key {
      return Some(quote)
    }
  }
  None
}

///|
fn html_code_block_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlCodeBlockFact? {
  for code in semantic.code_blocks {
    if code.block_source_key == block_source_key ||
      code.code_block_source_key == Some(block_source_key) {
      return Some(code)
    }
  }
  None
}

///|
fn html_figure_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlFigureFact? {
  for figure in semantic.figures {
    if figure.block_source_key == block_source_key {
      return Some(figure)
    }
  }
  None
}

///|
fn html_table_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @dhtml.HtmlTableFact? {
  for table in semantic.tables {
    if table.block_source_key == block_source_key {
      return Some(table)
    }
  }
  None
}

///|
fn html_table_row_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlTableRowFact? {
  for row in semantic.table_rows {
    if row.source_key == source_key {
      return Some(row)
    }
  }
  None
}

///|
fn html_table_cell_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlTableCellFact? {
  for cell in semantic.table_cells {
    if cell.source_key == source_key {
      return Some(cell)
    }
  }
  None
}

///|
fn html_table_section_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlTableSectionFact? {
  for section in semantic.table_sections {
    if section.source_key == source_key {
      return Some(section)
    }
  }
  None
}

///|
fn html_table_header_rows(
  semantic : @dhtml.HtmlSemanticDocument,
  table : @dhtml.HtmlTableFact,
) -> Int {
  let mut header_rows = 0
  for section_key in table.sections {
    match html_table_section_by_key(semantic, section_key) {
      Some(section) =>
        if section.kind == @dhtml.HtmlTableSectionKind::Head {
          header_rows += section.row_count
        }
      None => ()
    }
  }
  if header_rows > 0 {
    return header_rows
  }
  if table.rows.length() == 0 {
    return 0
  }
  match html_table_row_by_key(semantic, table.rows[0]) {
    Some(row) => {
      for cell_key in row.cell_source_keys {
        match html_table_cell_by_key(semantic, cell_key) {
          Some(cell) =>
            if cell.kind != @dhtml.HtmlTableCellKind::Header {
              return 0
            }
          None => ()
        }
      }
      1
    }
    None => 1
  }
}

///|
fn html_inline_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlInlineFact? {
  for inline in semantic.inlines {
    if inline.source_key == source_key {
      return Some(inline)
    }
  }
  None
}

///|
fn html_link_for_inline(
  semantic : @dhtml.HtmlSemanticDocument,
  inline_source_key : String,
) -> @dhtml.HtmlLinkFact? {
  for link in semantic.links {
    if link.inline_source_key == inline_source_key {
      return Some(link)
    }
  }
  None
}

///|
fn html_image_for_inline(
  semantic : @dhtml.HtmlSemanticDocument,
  inline_source_key : String,
) -> @dhtml.HtmlImageFact? {
  for image in semantic.images {
    if image.inline_source_key == inline_source_key {
      return Some(image)
    }
  }
  None
}

///|
fn html_image_by_key(
  semantic : @dhtml.HtmlSemanticDocument,
  source_key : String,
) -> @dhtml.HtmlImageFact? {
  for image in semantic.images {
    if image.source_key == source_key {
      return Some(image)
    }
  }
  None
}

///|
fn html_child_blocks_sorted(
  semantic : @dhtml.HtmlSemanticDocument,
  keys : Array[String],
) -> Array[@dhtml.HtmlBlockFact] {
  let out : Array[@dhtml.HtmlBlockFact] = []
  for key in keys {
    match html_block_by_key(semantic, key) {
      Some(block) => out.push(block)
      None => ()
    }
  }
  out.sort_by(fn(a, b) { a.source_order.compare(b.source_order) })
  out
}

///|
fn html_top_level_inline_segments_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
  child_blocks : Array[@dhtml.HtmlBlockFact],
) -> Array[Array[@dhtml.HtmlInlineFact]] {
  let segments : Array[Array[@dhtml.HtmlInlineFact]] = []
  let mut segment_count = child_blocks.length() + 1
  while segment_count > 0 {
    segments.push([])
    segment_count -= 1
  }
  let inlines = html_top_level_inline_facts_for_block(
    semantic, block_source_key,
  )
  for inline in inlines {
    let mut region = 0
    while region < child_blocks.length() &&
          inline.source_order > child_blocks[region].source_order {
      region += 1
    }
    segments[region].push(inline)
  }
  segments
}

///|
fn html_core_inline_segments_for_block(
  document : @core.DocumentIR,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
  child_blocks : Array[@dhtml.HtmlBlockFact],
) -> Array[Array[@core.CoreInline]] {
  let fact_segments = html_top_level_inline_segments_for_block(
    semantic, block_source_key, child_blocks,
  )
  let segments : Array[Array[@core.CoreInline]] = []
  for facts in fact_segments {
    segments.push(
      html_inline_facts_to_core_inlines(
        document,
        semantic,
        source,
        facts,
        trim_edges=true,
      ),
    )
  }
  if child_blocks.length() == 1 && segments.length() >= 2 {
    let child = child_blocks[0]
    if segments[0].length() > 0 && segments[1].length() == 0 {
      match html_split_text_only_inline_segment(segments[0]) {
        Some((left, right)) => {
          segments[0] = left
          segments[1] = right
        }
        None => ()
      }
    } else if segments[1].length() > 0 {
      match html_split_text_only_inline_segment(segments[1]) {
        Some((left, right)) =>
          match child.kind {
            @dhtml.HtmlBlockKind::List(_) =>
              if segments[0].length() > 0 {
                segments[0] = html_concat_core_inlines(segments[0], left)
                segments[1] = right
              }
            _ => ()
          }
        None => ()
      }
    }
  }
  segments
}

///|
fn html_split_text_only_inline_segment(
  inlines : Array[@core.CoreInline],
) -> (Array[@core.CoreInline], Array[@core.CoreInline])? {
  if inlines.length() == 0 {
    return None
  }
  for inline in inlines {
    if inline.kind != @core.InlineKind::Text {
      return None
    }
  }
  let text = html_render_plain_inlines(inlines)
  match html_split_once_double_space(text) {
    Some((left_text, right_text)) =>
      if left_text.trim() == "" || right_text.trim() == "" {
        None
      } else {
        let source_ref = inlines[0].source_ref.unwrap_or(
          @core.empty_source_ref(),
        )
        let left = [@core.make_inline_text(left_text, source_ref~)]
        let right = [@core.make_inline_text(right_text, source_ref~)]
        Some((left, right))
      }
    None => None
  }
}

///|
fn html_split_once_double_space(text : String) -> (String, String)? {
  let chars = text.to_array()
  let mut index = 0
  while index + 1 < chars.length() {
    if chars[index] == ' ' && chars[index + 1] == ' ' {
      let mut end = index + 2
      while end < chars.length() && chars[end] == ' ' {
        end += 1
      }
      let left = String::from_array(chars[:index].to_owned()).trim().to_owned()
      let right = String::from_array(chars[end:].to_owned()).trim().to_owned()
      if left != "" && right != "" {
        return Some((left, right))
      }
    }
    index += 1
  }
  None
}

///|
fn html_concat_core_inlines(
  left : Array[@core.CoreInline],
  right : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  out.append(left[:])
  out.append(right[:])
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_primary_title(semantic : @dhtml.HtmlSemanticDocument) -> String? {
  for scope in semantic.scope {
    match scope.title_text_preview {
      Some(title) =>
        if title.trim() != "" {
          return Some(title.trim().to_owned())
        }
      None => ()
    }
  }
  None
}

///|
fn html_quote_lines_from_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[String] {
  let lines : Array[String] = []

  fn append_quote_lines_with_blanks(
    lines : Array[String],
    rendered : Array[String],
  ) -> Unit {
    for index in 0..<rendered.length() {
      let line = rendered[index]
      lines.push(line)
      if index + 1 < rendered.length() {
        lines.push("")
      }
    }
  }

  for block in blocks {
    match block.kind {
      @core.BlockKind::Paragraph =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      @core.BlockKind::List =>
        append_quote_lines_with_blanks(
          lines,
          render_quote_lines_from_text(render_list_plain(block, 0)),
        )
      @core.BlockKind::ListItem =>
        append_quote_lines_with_blanks(
          lines,
          render_quote_lines_from_text(render_list_item_plain(block, 0)),
        )
      @core.BlockKind::BlockQuote =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      @core.BlockKind::Code =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      _ =>
        if block.text.trim() != "" {
          lines.append(render_quote_lines_from_text(block.text)[:])
        }
    }
    if lines.length() > 0 &&
      block.kind != @core.BlockKind::List &&
      block.kind != @core.BlockKind::ListItem {
      lines.push("")
    }
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  lines
}

///|
fn render_quote_lines_from_text(text : String) -> Array[String] {
  text.split("\n").to_array().map(line => line.to_owned())
}

///|
fn html_top_level_inline_facts_for_block(
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Array[@dhtml.HtmlInlineFact] {
  let out : Array[@dhtml.HtmlInlineFact] = []
  for inline in semantic.inlines {
    if inline.parent_block_source_key == Some(block_source_key) &&
      inline.parent_inline_source_key is None {
      out.push(inline)
    }
  }
  out.sort_by(fn(a, b) { a.source_order.compare(b.source_order) })
  out
}

///|
fn render_list_plain(block : @core.CoreBlock, depth : Int) -> String {
  let ordered = block.attrs.get("ordered").unwrap_or("false") == "true"
  let lines : Array[String] = []
  for index in 0..<block.children.length() {
    lines.push(
      render_list_item_plain(
        block.children[index],
        depth,
        ordered~,
        index=index + 1,
      ),
    )
  }
  lines.join("\n")
}

///|
fn render_list_item_plain(
  block : @core.CoreBlock,
  depth : Int,
  ordered? : Bool = false,
  index? : Int = 1,
) -> String {
  let marker = if ordered { index.to_string() + ". " } else { "- " }
  let indent = Array::make(depth * 2, " ").join("")
  let text = if rich_inlines_present_for_html(block) {
    html_render_plain_inlines(block.rich_inlines.unwrap_or([]))
  } else {
    block.text
  }
  let lines : Array[String] = [indent + marker + text.trim().to_owned()]
  for child in block.children {
    match child.kind {
      @core.BlockKind::List => lines.push(render_list_plain(child, depth + 1))
      _ =>
        if child.text.trim() != "" {
          lines.push(
            Array::make((depth + 1) * 2, " ").join("") +
            child.text.trim().to_owned(),
          )
        }
    }
  }
  lines.join("\n")
}

///|
fn rich_inlines_present_for_html(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn html_trim_core_inlines_edges(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let left_trimmed : Array[@core.CoreInline] = []
  let mut seen_content = false
  for inline in inlines {
    if !seen_content {
      match inline.kind {
        @core.InlineKind::Text => {
          let next_text = html_trim_leading_spaces(inline.text)
          if next_text != "" {
            left_trimmed.push({ ..inline, text: next_text })
            seen_content = true
          }
        }
        _ => {
          left_trimmed.push(inline)
          seen_content = true
        }
      }
    } else {
      left_trimmed.push(inline)
    }
  }
  let out_rev : Array[@core.CoreInline] = []
  let mut trimmed_right = false
  let mut index = left_trimmed.length()
  while index > 0 {
    index -= 1
    let inline = left_trimmed[index]
    if !trimmed_right {
      match inline.kind {
        @core.InlineKind::Text => {
          let next_text = html_trim_trailing_spaces(inline.text)
          if next_text != "" {
            out_rev.push({ ..inline, text: next_text })
            trimmed_right = true
          }
        }
        _ => {
          out_rev.push(inline)
          trimmed_right = true
        }
      }
    } else {
      out_rev.push(inline)
    }
  }
  let out : Array[@core.CoreInline] = []
  let mut rev_index = out_rev.length()
  while rev_index > 0 {
    rev_index -= 1
    out.push(out_rev[rev_index])
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_trim_leading_spaces(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  while start < chars.length() && html_ascii_space_like(chars[start]) {
    start += 1
  }
  String::from_array(chars[start:].to_owned())
}

///|
fn html_trim_trailing_spaces(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && html_ascii_space_like(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[:end].to_owned())
}

///|
fn html_ascii_space_like(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn html_block_source_ref(
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(block.span.line_start),
      Some(block.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/block/" + block.source_key),
  )
}

///|
fn html_block_source_ref_by_key(
  source : @input.InputSource,
  semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
) -> @core.SourceRef {
  match html_block_by_key(semantic, block_source_key) {
    Some(block) => html_block_source_ref(source, block)
    None =>
      @core.source_ref_with_html_path(
        @core.source_ref_with_lines(
          @core.empty_source_ref(),
          Some(source.source_name),
          Some("html"),
          Some(1),
          Some(1),
        ),
        Some(source.source_name),
        Some("html"),
        Some("/block/" + block_source_key),
      )
  }
}

///|
fn html_inline_source_ref(
  source : @input.InputSource,
  inline : @dhtml.HtmlInlineFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(inline.span.line_start),
      Some(inline.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/inline/" + inline.source_key),
  )
}

///|
fn html_image_source_ref(
  source : @input.InputSource,
  image : @dhtml.HtmlImageFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(image.span.line_start),
      Some(image.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/image/" + image.source_key),
  )
}

///|
fn html_table_row_source_ref(
  source : @input.InputSource,
  row : @dhtml.HtmlTableRowFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(row.span.line_start),
      Some(row.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/table-row/" + row.source_key),
  )
}

///|
fn html_table_cell_source_ref(
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(cell.span.line_start),
      Some(cell.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/table-cell/" + cell.source_key),
  )
}

///|
fn html_safe_local_image_src(src : String) -> Bool {
  if src == "" {
    return false
  }
  let lower = src.to_lower()
  !lower.has_prefix("http://") &&
  !lower.has_prefix("https://") &&
  !lower.has_prefix("data:") &&
  !lower.has_prefix("//") &&
  !lower.has_prefix("/") &&
  !src.contains("..")
}

///|
fn html_strip_query_and_hash(src : String) -> String {
  let chars = src.to_array()
  let mut end = chars.length()
  for i in 0..<chars.length() {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  src[:end].to_owned()
}

///|
fn html_image_ext_from_src(src : String) -> String {
  let lower = src.to_lower()
  if lower.has_suffix(".png") {
    return "png"
  }
  if lower.has_suffix(".jpg") {
    return "jpg"
  }
  if lower.has_suffix(".jpeg") {
    return "jpeg"
  }
  if lower.has_suffix(".gif") {
    return "gif"
  }
  if lower.has_suffix(".bmp") {
    return "bmp"
  }
  if lower.has_suffix(".webp") {
    return "webp"
  }
  if lower.has_suffix(".tif") || lower.has_suffix(".tiff") {
    return "tiff"
  }
  "img"
}

///|
fn html_two_digit(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
