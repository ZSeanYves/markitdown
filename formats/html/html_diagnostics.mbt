///|

///|
priv struct HtmlSemanticMetricSummary {
  link_count : Int
  image_count : Int
  table_count : Int
  max_depth : Int
  noise_repeated_boilerplate_count : Int
  warning_count : Int
  warning_error_count : Int
  unsupported_fact_count : Int
  unsupported_script_count : Int
  unsupported_style_count : Int
  unsupported_iframe_count : Int
  unsupported_embed_count : Int
  unsupported_object_count : Int
  unsupported_remote_image_count : Int
  unsupported_data_image_count : Int
  unsupported_unsafe_url_count : Int
}

///|
fn html_semantic_metric_summary(
  semantic : @dhtml.HtmlSemanticDocument,
) -> HtmlSemanticMetricSummary {
  let mut noise_repeated_boilerplate_count = 0
  for noise in semantic.noise_candidates {
    for reason in noise.reasons {
      if reason == @dhtml.HtmlNoiseCandidateReason::RepeatedBoilerplate {
        noise_repeated_boilerplate_count += 1
      }
    }
  }

  let mut warning_count = 0
  let mut warning_error_count = 0
  for warning in semantic.warnings {
    warning_count += 1
    if warning.severity == @dhtml.HtmlWarningSeverity::Error {
      warning_error_count += 1
    }
  }

  let mut unsupported_script_count = 0
  let mut unsupported_style_count = 0
  let mut unsupported_iframe_count = 0
  let mut unsupported_embed_count = 0
  let mut unsupported_object_count = 0
  let mut unsupported_remote_image_count = 0
  let mut unsupported_data_image_count = 0
  let mut unsupported_unsafe_url_count = 0
  for unsupported in semantic.unsupported {
    match unsupported.kind {
      @dhtml.HtmlUnsupportedKind::Script => unsupported_script_count += 1
      @dhtml.HtmlUnsupportedKind::Style => unsupported_style_count += 1
      @dhtml.HtmlUnsupportedKind::Iframe => unsupported_iframe_count += 1
      @dhtml.HtmlUnsupportedKind::Embed => unsupported_embed_count += 1
      @dhtml.HtmlUnsupportedKind::Object => unsupported_object_count += 1
      @dhtml.HtmlUnsupportedKind::RemoteImage =>
        unsupported_remote_image_count += 1
      @dhtml.HtmlUnsupportedKind::DataImage => unsupported_data_image_count += 1
      @dhtml.HtmlUnsupportedKind::UnsafeUrl => unsupported_unsafe_url_count += 1
      _ => ()
    }
  }

  {
    link_count: semantic.links.length(),
    image_count: semantic.images.length(),
    table_count: semantic.tables.length(),
    max_depth: semantic.max_depth,
    noise_repeated_boilerplate_count,
    warning_count,
    warning_error_count,
    unsupported_fact_count: semantic.unsupported.length(),
    unsupported_script_count,
    unsupported_style_count,
    unsupported_iframe_count,
    unsupported_embed_count,
    unsupported_object_count,
    unsupported_remote_image_count,
    unsupported_data_image_count,
    unsupported_unsafe_url_count,
  }
}

///|
fn html_fill_common_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dhtml.HtmlInspectReport,
  validation : @dhtml.HtmlValidationReport,
  semantic_metrics : HtmlSemanticMetricSummary,
  semantic : @dhtml.HtmlSemanticDocument,
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
  diagnostics.metrics.set("link_count", semantic_metrics.link_count.to_string())
  diagnostics.metrics.set(
    "image_count",
    semantic_metrics.image_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_count",
    semantic_metrics.table_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    semantic_metrics.max_depth.to_string(),
  )
  diagnostics.metrics.set(
    "validation_issue_count",
    validation.issue_count.to_string(),
  )
  let scope_source = html_scope_source_metric(semantic)
  diagnostics.metrics.set("scope_source", scope_source)
  diagnostics.metrics.set(
    "selected_content_root",
    html_selected_content_root_metric(semantic),
  )
  diagnostics.metrics.set("readability_mode", "hybrid")
  diagnostics.metrics.set(
    "noise_repeated_boilerplate_count",
    semantic_metrics.noise_repeated_boilerplate_count.to_string(),
  )
  diagnostics.metrics.set(
    "boilerplate_skipped_block_count",
    html_boilerplate_skipped_block_count(semantic).to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    (validation.warning_count + semantic_metrics.warning_count).to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    (validation.error_count + semantic_metrics.warning_error_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_node_count",
    (semantic_metrics.unsupported_script_count +
    semantic_metrics.unsupported_style_count +
    semantic_metrics.unsupported_iframe_count +
    semantic_metrics.unsupported_embed_count +
    semantic_metrics.unsupported_object_count +
    semantic_metrics.unsupported_remote_image_count +
    semantic_metrics.unsupported_data_image_count +
    semantic_metrics.unsupported_unsafe_url_count).to_string(),
  )
  diagnostics.metrics.set(
    "dropped_node_count",
    (semantic_metrics.unsupported_fact_count + validation.issue_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_feature_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set(
    "resource_limit_hit",
    @fshared.bool_string(large_mode),
  )
  diagnostics.metrics.set(
    "has_doctype",
    @fshared.bool_string(inspect.has_doctype),
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
  if semantic_metrics.unsupported_iframe_count > 0 {
    diagnostics.degraded_features.push("html_iframe_dropped")
  }
  if semantic_metrics.unsupported_embed_count > 0 {
    diagnostics.degraded_features.push("html_embed_dropped")
  }
  if semantic_metrics.unsupported_object_count > 0 {
    diagnostics.degraded_features.push("html_object_dropped")
  }
  if semantic_metrics.unsupported_remote_image_count > 0 {
    diagnostics.degraded_features.push("html_remote_image_reference_only")
  }
  if semantic_metrics.unsupported_data_image_count > 0 {
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
fn html_fill_child_semantic_metrics(
  diagnostics : @core.Diagnostics,
  semantic_metrics : HtmlSemanticMetricSummary,
  semantic : @dhtml.HtmlSemanticDocument,
  text : String,
  asset_count : Int,
) -> Unit {
  diagnostics.metrics.set("link_count", semantic_metrics.link_count.to_string())
  diagnostics.metrics.set(
    "image_count",
    semantic_metrics.image_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_count",
    semantic_metrics.table_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    semantic_metrics.max_depth.to_string(),
  )
  diagnostics.metrics.set("scope_source", html_scope_source_metric(semantic))
  diagnostics.metrics.set(
    "selected_content_root",
    html_selected_content_root_metric(semantic),
  )
  diagnostics.metrics.set("readability_mode", "hybrid")
  diagnostics.metrics.set(
    "noise_repeated_boilerplate_count",
    semantic_metrics.noise_repeated_boilerplate_count.to_string(),
  )
  diagnostics.metrics.set(
    "boilerplate_skipped_block_count",
    html_boilerplate_skipped_block_count(semantic).to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    semantic_metrics.warning_count.to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    semantic_metrics.warning_error_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_node_count",
    (semantic_metrics.unsupported_script_count +
    semantic_metrics.unsupported_style_count +
    semantic_metrics.unsupported_iframe_count +
    semantic_metrics.unsupported_embed_count +
    semantic_metrics.unsupported_object_count +
    semantic_metrics.unsupported_remote_image_count +
    semantic_metrics.unsupported_data_image_count +
    semantic_metrics.unsupported_unsafe_url_count).to_string(),
  )
  diagnostics.metrics.set(
    "dropped_node_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_feature_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("validation_issue_count", "0")
  diagnostics.metrics.set("has_doctype", "false")

  for warning in semantic.warnings {
    diagnostics.warnings.push("html semantic: " + warning.message)
  }
  if semantic_metrics.unsupported_script_count > 0 {
    diagnostics.degraded_features.push("html_script_dropped")
  }
  if semantic_metrics.unsupported_style_count > 0 {
    diagnostics.degraded_features.push("html_style_dropped")
  }
  if semantic_metrics.unsupported_iframe_count > 0 {
    diagnostics.degraded_features.push("html_iframe_dropped")
  }
  if semantic_metrics.unsupported_embed_count > 0 {
    diagnostics.degraded_features.push("html_embed_dropped")
  }
  if semantic_metrics.unsupported_object_count > 0 {
    diagnostics.degraded_features.push("html_object_dropped")
  }
  if semantic_metrics.unsupported_remote_image_count > 0 {
    diagnostics.degraded_features.push("html_remote_image_reference_only")
  }
  if semantic_metrics.unsupported_data_image_count > 0 {
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
fn html_scope_source_metric(semantic : @dhtml.HtmlSemanticDocument) -> String {
  for scope in semantic.scope {
    return match scope.scope_source {
      @dhtml.HtmlDocumentScopeSource::Body => "body"
      @dhtml.HtmlDocumentScopeSource::Main => "main"
      @dhtml.HtmlDocumentScopeSource::Article => "article"
      @dhtml.HtmlDocumentScopeSource::DocumentRoot => "document_root"
      @dhtml.HtmlDocumentScopeSource::Fragment => "fragment"
      @dhtml.HtmlDocumentScopeSource::Heuristic => "heuristic"
    }
  }
  "none"
}

///|
fn html_selected_content_root_metric(
  semantic : @dhtml.HtmlSemanticDocument,
) -> String {
  for scope in semantic.scope {
    match scope.selected_scope_reason {
      "" => ()
      value => return value
    }
  }
  "none"
}

///|
fn html_boilerplate_skipped_block_count(
  semantic : @dhtml.HtmlSemanticDocument,
) -> Int {
  let skipped : Map[String, Bool] = Map([])
  for block in semantic.blocks {
    if block.tag_name == "nav" {
      skipped.set(block.source_key, true)
    }
  }
  for noise in semantic.noise_candidates {
    if !html_noise_should_skip(noise) {
      continue
    }
    match noise.block_source_key {
      Some(key) => if !skipped.contains(key) { skipped.set(key, true) }
      None => ()
    }
  }
  skipped.length()
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
priv struct HtmlTokenBlockState {
  blocks : Array[@core.CoreBlock]
  mut text : StringBuilder
  mut text_start_line : Int
  mut text_end_line : Int
  mut text_kind : @core.BlockKind
  mut heading_level : Int
  mut in_pre : Bool
  mut text_has_content : Bool
  mut skip_depth : Int
  mut list_depth : Int
  mut quote_depth : Int
}

///|
fn html_lower_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let events = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match events {
    Ok(stream) =>
      html_lower_block_stream_document_from_events(
        source, text, diagnostics, stream,
      )
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "unavailable")
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
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
    source, text, diagnostics, events, scope_plans,
  )
}

///|
fn html_lower_child_text_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let events = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match events {
    Ok(stream) =>
      if html_child_events_require_semantic_block_stream(stream) {
        html_lower_child_semantic_block_stream_document(
          source, text, diagnostics,
        )
      } else {
        html_lower_child_text_block_stream_document_from_events(
          source, text, diagnostics, stream,
        )
      }
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "true")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set("scope_plan_labels", "child_text_fast_failed")
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
}

///|
fn html_lower_child_text_block_stream_document_from_events(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
) -> HtmlLoweringResult {
  diagnostics.metrics.set("html_block_stream_reparse", "false")
  diagnostics.metrics.set("html_block_stream_token_path", "true")
  diagnostics.metrics.set("scope_plan_count", "0")
  diagnostics.metrics.set("scope_plan_labels", "child_text_fast")
  let normalized = @dhtml.normalize_html_token_source(text)
  let lowered = html_lower_child_text_blocks(
    source,
    normalized.to_array(),
    diagnostics,
    events,
    has_table=html_child_events_contain_tag(events, "table"),
  )
  { blocks: lowered.0, metadata: Map([]), assets: lowered.1 }
}

///|
fn html_child_events_require_semantic_block_stream(
  events : Array[@dhtml.HtmlTokenEvent],
) -> Bool {
  html_child_events_contain_tag(events, "figure") ||
  html_child_events_contain_tag(events, "details") ||
  html_child_events_contain_tag(events, "summary")
}

///|
fn html_child_events_contain_tag(
  events : Array[@dhtml.HtmlTokenEvent],
  tag_name : String,
) -> Bool {
  for event in events {
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag &&
      event.tag_name == tag_name {
      return true
    }
  }
  false
}

///|
fn html_lower_block_stream_document_with_scope_plans(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
  scope_plans : Array[HtmlScopePlan],
) -> HtmlLoweringResult {
  let metadata : @core.DocumentMetadata = Map([])
  let blocks : Array[@core.CoreBlock] = []
  diagnostics.metrics.set("scope_plan_count", scope_plans.length().to_string())
  diagnostics.metrics.set("html_block_stream_reparse", "false")
  diagnostics.metrics.set("html_block_stream_token_path", "true")
  let scope_labels : Array[String] = []
  let text_chars = text.to_array()
  let mut event_index = 0

  for plan in scope_plans {
    scope_labels.push(plan.label)
    let result = html_lower_scope_events_to_blocks(
      source, text_chars, events, plan, event_index,
    )
    blocks.append(result.0[:])
    event_index = result.1
  }
  diagnostics.metrics.set("scope_plan_labels", scope_labels.join(","))

  { blocks, metadata, assets: [] }
}

///|
fn html_lower_scope_events_to_blocks(
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  plan : HtmlScopePlan,
  start_index : Int,
) -> (Array[@core.CoreBlock], Int) {
  let state = {
    blocks: [],
    text: StringBuilder::new(),
    text_start_line: 0,
    text_end_line: 0,
    text_kind: @core.BlockKind::Paragraph,
    heading_level: 0,
    in_pre: false,
    text_has_content: false,
    skip_depth: 0,
    list_depth: 0,
    quote_depth: 0,
  }
  let mut i = start_index
  while i < events.length() && events[i].source_end <= plan.source_start {
    i += 1
  }
  while i < events.length() {
    let event = events[i]
    if event.source_start >= plan.source_end {
      break
    }
    if event.source_end <= plan.source_start ||
      event.source_start >= plan.source_end {
      i += 1
      continue
    }
    html_token_lower_event(state, source, text_chars, event)
    i += 1
  }
  html_token_flush_text_block(state, source)
  (state.blocks, i)
}

///|
priv struct HtmlChildInlineState {
  inlines : Array[@core.CoreInline]
  mut text : StringBuilder
  mut text_line_start : Int
  mut text_line_end : Int
  mut pending_space : Bool
  mut has_content : Bool
}

///|
priv struct HtmlChildBlockAccumulator {
  kind : @core.BlockKind
  level : Int
  info : String
  html_path : String
  line_start : Int
  mut line_end : Int
  inline_state : HtmlChildInlineState
}

///|
priv struct HtmlChildTextState {
  lowering_state : HtmlLoweringState
  diagnostics : @core.Diagnostics
  blocks : Array[@core.CoreBlock]
  close_index : Map[Int, Int]
  mut current : HtmlChildBlockAccumulator?
  mut skip_depth : Int
  mut block_order : Int
  mut inline_order : Int
  mut link_depth : Int
  mut link_text : StringBuilder
  mut link_href : String?
  mut link_line_start : Int
  mut link_line_end : Int
  mut link_pending_space : Bool
  mut link_has_content : Bool
  list_stack : Array[HtmlChildListFrame]
  list_item_stack : Array[HtmlChildListItemFrame]
}

///|
priv struct HtmlChildListFrame {
  ordered : Bool
  start_line : Int
  html_path : String
  items : Array[@core.CoreBlock]
}

///|
priv struct HtmlChildListItemFrame {
  ordered : Bool
  start_line : Int
  html_path : String
  body_blocks : Array[@core.CoreBlock]
}

///|
fn html_child_inline_state() -> HtmlChildInlineState {
  {
    inlines: [],
    text: StringBuilder::new(),
    text_line_start: 0,
    text_line_end: 0,
    pending_space: false,
    has_content: false,
  }
}

///|
fn html_child_inline_append_text(
  inline_state : HtmlChildInlineState,
  text : String,
  line_start : Int,
  line_end : Int,
) -> Unit {
  if text == "" {
    return
  }
  if inline_state.text_line_start == 0 {
    inline_state.text_line_start = line_start
  }
  inline_state.text_line_end = line_end
  inline_state.text.write_string(text)
  inline_state.has_content = true
  inline_state.pending_space = false
}

///|
fn html_child_inline_materialize_pending_text(
  state : HtmlChildTextState,
  source : @input.InputSource,
  current : HtmlChildBlockAccumulator,
) -> Unit {
  if current.inline_state.text_line_start == 0 {
    return
  }
  let text = current.inline_state.text.to_string()
  current.inline_state.text = StringBuilder::new()
  let line_start = current.inline_state.text_line_start
  let line_end = current.inline_state.text_line_end
  current.inline_state.text_line_start = 0
  current.inline_state.text_line_end = 0
  if text == "" {
    return
  }
  state.inline_order += 1
  current.inline_state.inlines.push(
    @core.make_inline_text(
      text,
      source_ref=html_token_lines_source_ref(
        source,
        line_start,
        line_end,
        "/inline/html:inline:text:" + state.inline_order.to_string(),
      ),
    ),
  )
}

///|
fn html_lower_child_text_blocks(
  source : @input.InputSource,
  text_chars : Array[Char],
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
  has_table? : Bool = true,
) -> (Array[@core.CoreBlock], Array[@core.AssetRef]) {
  let state = {
    lowering_state: { assets: [] },
    diagnostics,
    blocks: [],
    close_index: if has_table {
      html_child_token_close_index(events)
    } else {
      Map([])
    },
    current: None,
    skip_depth: 0,
    block_order: 0,
    inline_order: 0,
    link_depth: 0,
    link_text: StringBuilder::new(),
    link_href: None,
    link_line_start: 0,
    link_line_end: 0,
    link_pending_space: false,
    link_has_content: false,
    list_stack: [],
    list_item_stack: [],
  }
  let mut index = 0
  while index < events.length() {
    index = html_child_text_lower_event(
      state, source, text_chars, events, index,
    )
  }
  html_child_text_flush_link(state, source)
  html_child_text_flush_block(state, source)
  (state.blocks, state.lowering_state.assets)
}

///|
fn html_child_token_close_index(
  events : Array[@dhtml.HtmlTokenEvent],
) -> Map[Int, Int] {
  let out : Map[Int, Int] = Map([])
  let stacks : Map[String, Array[Int]] = Map([])
  for index in 0..<events.length() {
    let event = events[index]
    match event.kind {
      @dhtml.HtmlTokenEventKind::StartTag =>
        if !event.self_closing {
          match stacks.get(event.tag_name) {
            Some(existing) => existing.push(index)
            None => stacks.set(event.tag_name, [index])
          }
        }
      @dhtml.HtmlTokenEventKind::EndTag =>
        match stacks.get(event.tag_name) {
          Some(existing) =>
            if existing.length() > 0 {
              let open_index = existing.pop().unwrap()
              out.set(open_index, index)
            }
          None => ()
        }
      @dhtml.HtmlTokenEventKind::Text
      | @dhtml.HtmlTokenEventKind::Comment
      | @dhtml.HtmlTokenEventKind::Doctype => ()
    }
  }
  out
}

///|
fn html_child_text_lower_event(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  index : Int,
) -> Int {
  let event = events[index]
  if state.skip_depth > 0 {
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag && !event.self_closing {
      state.skip_depth += 1
    } else if event.kind == @dhtml.HtmlTokenEventKind::EndTag {
      state.skip_depth -= 1
    }
    return index + 1
  }
  match event.kind {
    @dhtml.HtmlTokenEventKind::Text =>
      html_child_text_append_text(state, source, text_chars, event)
    @dhtml.HtmlTokenEventKind::StartTag =>
      return html_child_text_start_tag(state, source, text_chars, events, index)
    @dhtml.HtmlTokenEventKind::EndTag =>
      html_child_text_end_tag(state, source, event)
    @dhtml.HtmlTokenEventKind::Comment | @dhtml.HtmlTokenEventKind::Doctype =>
      ()
  }
  index + 1
}

///|
fn html_child_text_start_tag(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  index : Int,
) -> Int {
  let event = events[index]
  let tag = event.tag_name
  if html_scope_event_should_skip(event) || html_token_skip_tag(tag) {
    if !event.self_closing {
      state.skip_depth = 1
    }
    return index + 1
  }
  if html_dom_counts_as_block(tag, false) {
    state.block_order += 1
  }
  if tag == "html" ||
    tag == "body" ||
    tag == "main" ||
    tag == "article" ||
    tag == "section" ||
    tag == "div" ||
    tag == "header" ||
    tag == "footer" {
    return index + 1
  }
  if tag == "a" {
    html_child_text_open_link(state, event)
    return index + 1
  }
  if tag == "br" {
    html_child_text_append_line_break(state, source, event)
    return index + 1
  }
  let heading = html_heading_level(tag)
  if heading > 0 {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Heading,
      level: heading,
      info: "",
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "p" {
    match state.current {
      Some(current) =>
        if current.kind == @core.BlockKind::BlockQuote {
          return index + 1
        }
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:p:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "blockquote" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::BlockQuote,
      level: 0,
      info: "",
      html_path: "/block/html:block:blockquote:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.list_stack.push({
      ordered: tag == "ol",
      start_line: event.span.line_start,
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      items: [],
    })
    return index + 1
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    let ordered = match state.list_stack.last() {
      Some(frame) => frame.ordered
      None => false
    }
    state.list_item_stack.push({
      ordered,
      start_line: event.span.line_start,
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      body_blocks: [],
    })
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "pre" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Code,
      level: 0,
      info: "",
      html_path: "/block/html:block:pre:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "hr" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_push_block(
      state,
      html_child_hr_block(source, event, state.block_order),
    )
    return index + 1
  }
  if tag == "img" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_append_image(state, source, event)
    return index + 1
  }
  if tag == "table" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    return html_child_text_append_table(
      state, source, text_chars, events, index,
    )
  }
  index + 1
}

///|
fn html_child_text_end_tag(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if tag == "a" {
    state.link_line_end = event.span.line_end
    html_child_text_flush_link(state, source)
    return
  }
  if tag == "p" {
    match state.current {
      Some(current) =>
        if current.kind == @core.BlockKind::BlockQuote {
          current.line_end = event.span.line_end
          return
        }
      None => ()
    }
  }
  let heading = html_heading_level(tag)
  if heading > 0 || tag == "p" || tag == "pre" || tag == "blockquote" {
    match state.current {
      Some(current) => current.line_end = event.span.line_end
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    return
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list_item(state, source, event.span.line_end)
    return
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list(state, source, event.span.line_end)
  }
}

///|
fn html_child_text_open_link(
  state : HtmlChildTextState,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  if state.link_depth == 0 {
    state.link_text = StringBuilder::new()
    state.link_href = html_child_text_event_href(event)
    state.link_line_start = event.span.line_start
    state.link_line_end = event.span.line_end
    state.link_pending_space = false
    state.link_has_content = false
  }
  state.link_depth += 1
}

///|
fn html_child_text_flush_link(
  state : HtmlChildTextState,
  source : @input.InputSource,
) -> Unit {
  if state.link_depth == 0 {
    return
  }
  state.link_depth = 0
  let trailing_space = state.link_pending_space
  let text = state.link_text.to_string().trim().to_owned()
  state.link_text = StringBuilder::new()
  state.link_pending_space = false
  state.link_has_content = false
  if text == "" {
    state.link_href = None
    return
  }
  match state.current {
    Some(current) => {
      html_child_inline_materialize_pending_text(state, source, current)
      if current.inline_state.pending_space && current.inline_state.has_content {
        state.inline_order += 1
        current.inline_state.inlines.push(
          @core.make_inline_text(
            " ",
            source_ref=html_token_lines_source_ref(
              source,
              state.link_line_start,
              state.link_line_end,
              "/inline/html:inline:text:" + state.inline_order.to_string(),
            ),
          ),
        )
      }
      state.inline_order += 1
      let inline_ref = html_token_lines_source_ref(
        source,
        state.link_line_start,
        state.link_line_end,
        "/inline/html:inline:a:" + state.inline_order.to_string(),
      )
      match state.link_href {
        Some(href) =>
          current.inline_state.inlines.push(
            @core.make_inline_link(text, href, source_ref=inline_ref),
          )
        None =>
          current.inline_state.inlines.push(
            @core.make_inline_text(text, source_ref=inline_ref),
          )
      }
      current.inline_state.has_content = true
      current.inline_state.pending_space = trailing_space
    }
    None => ()
  }
  state.link_href = None
}

///|
fn html_child_text_append_line_break(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  match state.current {
    Some(current) => {
      html_child_text_flush_link(state, source)
      html_child_inline_materialize_pending_text(state, source, current)
      state.inline_order += 1
      current.inline_state.inlines.push(
        @core.make_inline_line_break(
          source_ref=html_token_lines_source_ref(
            source,
            event.span.line_start,
            event.span.line_end,
            "/inline/html:inline:br:" + state.inline_order.to_string(),
          ),
        ),
      )
      current.inline_state.has_content = true
      current.inline_state.pending_space = false
      current.line_end = event.span.line_end
    }
    None => ()
  }
}

///|
fn html_child_text_append_text(
  state : HtmlChildTextState,
  _source : @input.InputSource,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let raw = html_scope_event_text(text_chars, event)
  match state.current {
    Some(current) => {
      let leading_space = current.kind != @core.BlockKind::Code &&
        html_text_has_leading_space_like(raw)
      let text = if current.kind == @core.BlockKind::Code {
        raw
      } else {
        html_compact_token_text(raw)
      }
      if text == "" {
        if current.kind != @core.BlockKind::Code &&
          current.inline_state.has_content {
          current.inline_state.pending_space = true
        }
        return
      }
      current.line_end = event.span.line_end
      if state.link_depth > 0 {
        let normalized = if current.kind != @core.BlockKind::Code &&
          state.link_has_content &&
          (state.link_pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        state.link_text.write_string(normalized)
        state.link_line_end = event.span.line_end
        state.link_pending_space = current.kind != @core.BlockKind::Code &&
          html_text_has_trailing_space_like(raw)
        state.link_has_content = true
      } else {
        let normalized = if current.kind != @core.BlockKind::Code &&
          current.inline_state.has_content &&
          (current.inline_state.pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        html_child_inline_append_text(
          current.inline_state,
          normalized,
          event.span.line_start,
          event.span.line_end,
        )
        current.inline_state.pending_space = current.kind !=
          @core.BlockKind::Code &&
          html_text_has_trailing_space_like(raw)
      }
      current.inline_state.has_content = true
    }
    None => ()
  }
}

///|
fn html_child_text_flush_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
) -> Unit {
  match state.current {
    Some(current) => {
      let text = if current.inline_state.inlines.length() == 0 {
        current.inline_state.text.to_string().trim().to_owned()
      } else {
        html_child_inline_materialize_pending_text(state, source, current)
        html_render_plain_inlines(
          html_trim_core_inlines_edges(current.inline_state.inlines),
        )
        .trim()
        .to_owned()
      }
      if text != "" {
        let block = @core.make_block(
          current.kind,
          text,
          source_ref=html_token_lines_source_ref(
            source,
            current.line_start,
            current.line_end,
            current.html_path,
          ),
        )
        if current.kind == @core.BlockKind::Heading {
          block.attrs.set("level", current.level.to_string())
          block.attrs.set("literal", "true")
          block.attrs.set("render_inline_escape_mode", "minimal")
          let rich = html_trim_core_inlines_edges(current.inline_state.inlines)
          if html_child_text_requires_rich_inlines(rich) {
            html_child_text_push_block(
              state,
              @core.block_with_rich_inlines(block, Some(rich)),
            )
          } else {
            html_child_text_push_block(state, block)
          }
        } else if current.kind == @core.BlockKind::Code {
          block.attrs.set("info", current.info)
          html_child_text_push_block(state, block)
        } else {
          block.attrs.set("literal", "true")
          block.attrs.set("render_inline_escape_mode", "minimal")
          let rich = html_trim_core_inlines_edges(current.inline_state.inlines)
          let final_block = if html_child_text_requires_rich_inlines(rich) {
            @core.block_with_rich_inlines(block, Some(rich))
          } else {
            block
          }
          html_child_text_push_block(state, final_block)
        }
      }
      state.current = None
    }
    None => ()
  }
}

///|
fn html_child_text_requires_rich_inlines(
  inlines : Array[@core.CoreInline],
) -> Bool {
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Link | @core.InlineKind::LineBreak => return true
      _ => ()
    }
  }
  false
}

///|
fn html_child_text_push_block(
  state : HtmlChildTextState,
  block : @core.CoreBlock,
) -> Unit {
  match state.list_item_stack.last() {
    Some(frame) => frame.body_blocks.push(block)
    None => state.blocks.push(block)
  }
}

///|
fn html_child_text_close_list_item(
  state : HtmlChildTextState,
  source : @input.InputSource,
  end_line : Int,
) -> Unit {
  let frame = match state.list_item_stack.pop() {
    Some(value) => value
    None => return
  }
  let body = frame.body_blocks
  let item = html_child_text_list_item_block(frame, body, source, end_line)
  match state.list_stack.last() {
    Some(list) => list.items.push(item)
    None => state.blocks.push(item)
  }
}

///|
fn html_child_text_list_item_block(
  frame : HtmlChildListItemFrame,
  body_blocks : Array[@core.CoreBlock],
  source : @input.InputSource,
  end_line : Int,
) -> @core.CoreBlock {
  let (text, rich, nested_lists, extras) = html_child_text_list_item_body_parts(
    body_blocks,
  )
  let item = @core.make_block(
    @core.BlockKind::ListItem,
    text,
    source_ref=html_token_lines_source_ref(
      source,
      frame.start_line,
      end_line,
      frame.html_path,
    ),
  )
  item.attrs.set("ordered", @fshared.bool_string(frame.ordered))
  if frame.ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = match rich {
    Some(inlines) => @core.block_with_rich_inlines(item, Some(inlines))
    None => item
  }
  let children : Array[@core.CoreBlock] = []
  children.append(nested_lists[:])
  children.append(extras[:])
  if children.length() > 0 {
    root = @core.block_with_children(root, children)
  }
  root
}

///|
fn html_child_text_list_item_body_parts(
  body_blocks : Array[@core.CoreBlock],
) -> (
  String,
  Array[@core.CoreInline]?,
  Array[@core.CoreBlock],
  Array[@core.CoreBlock],
) {
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  let mut root_text = ""
  let mut rich : Array[@core.CoreInline]? = None
  let mut root_taken = false
  for block in body_blocks {
    if block.kind == @core.BlockKind::List {
      nested_lists.push(block)
      continue
    }
    if !root_taken &&
      (
        block.kind == @core.BlockKind::Paragraph ||
        block.kind == @core.BlockKind::Heading ||
        block.kind == @core.BlockKind::BlockQuote ||
        block.kind == @core.BlockKind::Code
      ) {
      root_text = block.text
      rich = block.rich_inlines
      root_taken = true
      continue
    }
    extras.push(block)
  }
  (root_text, rich, nested_lists, extras)
}

///|
fn html_text_has_trailing_space_like(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  html_ascii_space_like(chars[chars.length() - 1])
}

///|
fn html_text_has_leading_space_like(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  html_ascii_space_like(chars[0])
}

///|
fn html_child_text_close_list(
  state : HtmlChildTextState,
  source : @input.InputSource,
  end_line : Int,
) -> Unit {
  let frame = match state.list_stack.pop() {
    Some(value) => value
    None => return
  }
  if frame.items.length() == 0 {
    return
  }
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=html_token_lines_source_ref(
      source,
      frame.start_line,
      end_line,
      frame.html_path,
    ),
  )
  list.attrs.set("ordered", @fshared.bool_string(frame.ordered))
  let lowered = @core.block_with_children(list, frame.items)
  match state.list_item_stack.last() {
    Some(item) => item.body_blocks.push(lowered)
    None => state.blocks.push(lowered)
  }
}

///|
fn html_child_hr_block(
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  block_order : Int,
) -> @core.CoreBlock {
  let block = @core.make_block(
    @core.BlockKind::Raw,
    "---",
    source_ref=html_token_lines_source_ref(
      source,
      event.span.line_start,
      event.span.line_end,
      "/block/html:block:hr:" + block_order.to_string(),
    ),
  )
  block.attrs.set("raw_kind", "thematic_break")
  block
}

///|
fn html_child_text_append_image(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let src = @dhtml.html_token_event_attr_value(event, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = html_child_image_kind(src)
  let alt = @dhtml.html_token_event_attr_value(event, "alt")
    .unwrap_or("image")
    .trim()
    .to_owned()
  let title = match @dhtml.html_token_event_attr_value(event, "title") {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
  let source_ref = html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    "/block/html:block:img:" + state.block_order.to_string(),
  )
  if kind == @dhtml.HtmlImageKind::Remote {
    state.diagnostics.degraded_features.push("html_remote_image_reference_only")
    return
  }
  if kind == @dhtml.HtmlImageKind::DataUri {
    state.diagnostics.degraded_features.push("html_data_image_reference_only")
    return
  }
  if kind == @dhtml.HtmlImageKind::Local {
    match html_child_local_image_asset(state, source_ref, src, alt) {
      Some(asset) => {
        let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
        image.attrs.set("alt", alt)
        image.attrs.set("path", asset.path.unwrap_or("#"))
        image.attrs.set("asset_id", asset.asset_id)
        match title {
          Some(value) => image.attrs.set("title", value)
          None => ()
        }
        html_child_text_push_block(state, image)
      }
      None => {
        let paragraph = @core.make_block(
          @core.BlockKind::Paragraph,
          html_image_placeholder_text(kind, alt),
          source_ref~,
        )
        paragraph.attrs.set("literal", "true")
        paragraph.attrs.set("render_inline_escape_mode", "minimal")
        html_child_text_push_block(state, paragraph)
      }
    }
    return
  }
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    html_image_placeholder_text(kind, alt),
    source_ref~,
  )
  paragraph.attrs.set("literal", "true")
  paragraph.attrs.set("render_inline_escape_mode", "minimal")
  html_child_text_push_block(state, paragraph)
}

///|
fn html_child_image_kind(src : String) -> @dhtml.HtmlImageKind {
  let trimmed = src.trim().to_owned()
  if trimmed == "" {
    return @dhtml.HtmlImageKind::Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return @dhtml.HtmlImageKind::Unsafe
  }
  if lower.has_prefix("data:") {
    return @dhtml.HtmlImageKind::DataUri
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return @dhtml.HtmlImageKind::Remote
  }
  if lower.has_prefix("/") {
    return @dhtml.HtmlImageKind::Unknown
  }
  @dhtml.HtmlImageKind::Local
}

///|
fn html_child_local_image_asset(
  state : HtmlChildTextState,
  source_ref : @core.SourceRef,
  src : String,
  alt : String,
) -> @core.AssetRef? {
  let normalized_src = html_strip_query_and_hash(src.trim().to_owned())
  if !html_safe_local_image_src(normalized_src) {
    return None
  }
  for existing in state.lowering_state.assets {
    if existing.attrs.get("source_path") == Some(normalized_src) {
      return Some(existing)
    }
  }
  let asset_index = state.lowering_state.assets.length() + 1
  let asset_id = "html-image-" + asset_index.to_string()
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = {
    ..asset,
    path: Some(
      "assets/image" +
      html_two_digit(asset_index) +
      "." +
      html_image_ext_from_src(normalized_src),
    ),
  }
  next_asset.attrs.set("source_path", normalized_src)
  next_asset.attrs.set("alt", alt)
  state.lowering_state.assets.push(next_asset)
  Some(next_asset)
}

///|
fn html_child_text_append_table(
  state : HtmlChildTextState,
  source : @input.InputSource,
  _text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
) -> Int {
  match state.close_index.get(open_index) {
    Some(close_index) => {
      let open_event = events[open_index]
      match
        html_child_table_block(
          state,
          source,
          _text_chars,
          events,
          open_index,
          close_index,
          state.block_order,
        ) {
        Some(table) => html_child_text_push_block(state, table)
        None => html_child_text_append_table_fallback(state, source, open_event)
      }
      close_index + 1
    }
    None => {
      html_child_text_append_table_fallback(state, source, events[open_index])
      open_index + 1
    }
  }
}

///|
fn html_child_text_append_table_fallback(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    event.tag_name,
    source_ref=html_token_lines_source_ref(
      source,
      event.span.line_start,
      event.span.line_end,
      "/block/html:block:" +
      event.tag_name +
      ":" +
      state.block_order.to_string(),
    ),
  )
  paragraph.attrs.set("literal", "true")
  paragraph.attrs.set("render_inline_escape_mode", "minimal")
  html_child_text_push_block(state, paragraph)
}

///|
fn html_child_table_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  block_order : Int,
) -> @core.CoreBlock? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let rows : Array[@core.CoreBlock] = []
  let mut header_rows = 0
  let mut index = open_index + 1
  let mut row_order = 0
  while index < close_index {
    let event = events[index]
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag &&
      event.tag_name == "tr" {
      match state.close_index.get(index) {
        Some(row_close) =>
          if row_close <= close_index {
            row_order += 1
            match
              html_child_table_row_block(
                state, source, text_chars, events, index, row_close, row_order,
              ) {
              Some(row) => {
                rows.push(row.0)
                if row.1 {
                  header_rows += 1
                }
                index = row_close + 1
                continue
              }
              None => ()
            }
          }
        None => ()
      }
    }
    index += 1
  }
  if rows.length() == 0 {
    return None
  }
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=html_token_lines_source_ref(
      source,
      open_event.span.line_start,
      close_event.span.line_end,
      "/block/html:block:table:" + block_order.to_string(),
    ),
  )
  table.attrs.set("header_rows", html_child_table_header_rows(rows).to_string())
  table.attrs.set(
    "table_column_count",
    html_child_table_column_count(rows).to_string(),
  )
  if header_rows > 0 {
    table.attrs.set("header_rows", header_rows.to_string())
  }
  Some(@core.block_with_children(table, rows))
}

///|
fn html_child_table_row_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  row_order : Int,
) -> (@core.CoreBlock, Bool)? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let row = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=html_token_lines_source_ref(
      source,
      open_event.span.line_start,
      close_event.span.line_end,
      "/table-row/html:table-row:" + row_order.to_string(),
    ),
  )
  row.attrs.set("literal", "true")
  let cells : Array[@core.CoreBlock] = []
  let mut header_cell_count = 0
  let mut index = open_index + 1
  while index < close_index {
    let event = events[index]
    let tag = event.tag_name
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag &&
      (tag == "td" || tag == "th") {
      match state.close_index.get(index) {
        Some(cell_close) =>
          if cell_close <= close_index {
            match
              html_child_table_cell_block(
                state,
                source,
                text_chars,
                events,
                index,
                cell_close,
                cells.length() + 1,
              ) {
              Some(cell) => {
                cells.push(cell)
                if tag == "th" {
                  header_cell_count += 1
                }
                index = cell_close + 1
                continue
              }
              None => ()
            }
          }
        None => ()
      }
    }
    index += 1
  }
  if cells.length() == 0 {
    return None
  }
  let row = { ..row, text: cells.map(cell => cell.text).join(" | ") }
  let row = @core.block_with_children(row, cells)
  Some((row, header_cell_count == cells.length()))
}

///|
fn html_child_table_cell_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  cell_order : Int,
) -> @core.CoreBlock? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let inlines = html_child_table_collect_inlines(
    state,
    source,
    text_chars,
    events,
    open_index + 1,
    close_index,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    return None
  }
  let cell = @core.make_block(
    @core.BlockKind::TableCell,
    text,
    source_ref=html_token_lines_source_ref(
      source,
      open_event.span.line_start,
      close_event.span.line_end,
      "/table-cell/html:table-cell:" + cell_order.to_string(),
    ),
  )
  cell.attrs.set("literal", "true")
  cell.attrs.set("render_inline_escape_mode", "minimal")
  if inlines.length() > 0 {
    Some(@core.block_with_rich_inlines(cell, Some(inlines)))
  } else {
    Some(cell)
  }
}

///|
fn html_child_table_collect_inlines(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  start_index : Int,
  end_index : Int,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  let mut index = start_index
  let mut pending_space = false
  while index < end_index {
    let event = events[index]
    let tag = event.tag_name
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag {
      if tag == "br" {
        out.push(
          @core.make_inline_line_break(
            source_ref=html_token_lines_source_ref(
              source,
              event.span.line_start,
              event.span.line_end,
              "/inline/html:inline:br:" + out.length().to_string(),
            ),
          ),
        )
        pending_space = false
      } else if tag == "img" {
        if pending_space && out.length() > 0 {
          out.push(
            @core.make_inline_text(
              " ",
              source_ref=html_token_lines_source_ref(
                source,
                event.span.line_start,
                event.span.line_end,
                "/inline/html:inline:text:" + out.length().to_string(),
              ),
            ),
          )
        }
        html_child_table_append_image_inline(state, source, event, out)
        pending_space = false
      } else if tag == "a" {
        match state.close_index.get(index) {
          Some(link_close) if link_close <= end_index => {
            let text = html_render_plain_inlines(
                html_child_table_collect_inlines(
                  state,
                  source,
                  text_chars,
                  events,
                  index + 1,
                  link_close,
                ),
              )
              .trim()
              .to_owned()
            if text != "" {
              if pending_space && out.length() > 0 {
                out.push(
                  @core.make_inline_text(
                    " ",
                    source_ref=html_token_lines_source_ref(
                      source,
                      event.span.line_start,
                      events[link_close].span.line_end,
                      "/inline/html:inline:text:" + out.length().to_string(),
                    ),
                  ),
                )
              }
              match html_child_text_event_href(event) {
                Some(href) =>
                  out.push(
                    @core.make_inline_link(
                      text,
                      href,
                      source_ref=html_token_lines_source_ref(
                        source,
                        event.span.line_start,
                        events[link_close].span.line_end,
                        "/inline/html:inline:a:" + out.length().to_string(),
                      ),
                    ),
                  )
                None =>
                  out.push(
                    @core.make_inline_text(
                      text,
                      source_ref=html_token_lines_source_ref(
                        source,
                        event.span.line_start,
                        events[link_close].span.line_end,
                        "/inline/html:inline:text:" + out.length().to_string(),
                      ),
                    ),
                  )
              }
            }
            index = link_close
          }
          _ => ()
        }
        pending_space = false
      } else if html_child_table_spacing_tag(tag) && out.length() > 0 {
        pending_space = true
      }
    }
    if event.kind == @dhtml.HtmlTokenEventKind::EndTag &&
      html_child_table_spacing_tag(tag) &&
      out.length() > 0 {
      pending_space = true
    }
    if event.kind == @dhtml.HtmlTokenEventKind::Text {
      let raw = html_scope_event_text(text_chars, event)
      let compact = html_compact_token_text(raw)
      if compact == "" {
        if out.length() > 0 {
          pending_space = true
        }
      } else {
        let text = if pending_space && out.length() > 0 {
          " " + compact
        } else {
          compact
        }
        out.push(
          @core.make_inline_text(
            text,
            source_ref=html_token_lines_source_ref(
              source,
              event.span.line_start,
              event.span.line_end,
              "/inline/html:inline:text:" + out.length().to_string(),
            ),
          ),
        )
        pending_space = false
      }
    }
    index += 1
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_child_table_spacing_tag(tag : String) -> Bool {
  tag == "p" ||
  tag == "div" ||
  tag == "li" ||
  tag == "blockquote" ||
  tag == "pre" ||
  tag == "ul" ||
  tag == "ol"
}

///|
fn html_child_table_append_image_inline(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  out : Array[@core.CoreInline],
) -> Unit {
  let src = @dhtml.html_token_event_attr_value(event, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let alt = @dhtml.html_token_event_attr_value(event, "alt")
    .unwrap_or("image")
    .trim()
    .to_owned()
  let kind = html_child_image_kind(src)
  let source_ref = html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    "/inline/html:inline:img:" + out.length().to_string(),
  )
  match kind {
    @dhtml.HtmlImageKind::Local =>
      match html_child_local_image_asset(state, source_ref, src, alt) {
        Some(asset) =>
          out.push(
            @core.make_inline_image(alt, asset.path.unwrap_or("#"), source_ref~),
          )
        None => out.push(@core.make_inline_text("[image]", source_ref~))
      }
    @dhtml.HtmlImageKind::Remote => {
      state.diagnostics.degraded_features.push(
        "html_remote_image_reference_only",
      )
      out.push(@core.make_inline_text("[remote]", source_ref~))
    }
    @dhtml.HtmlImageKind::DataUri => {
      state.diagnostics.degraded_features.push("html_data_image_reference_only")
      out.push(@core.make_inline_text("[inline data]", source_ref~))
    }
    _ =>
      out.push(
        @core.make_inline_text(
          html_image_placeholder_text(kind, alt),
          source_ref~,
        ),
      )
  }
}

///|
fn html_child_table_header_rows(rows : Array[@core.CoreBlock]) -> Int {
  if rows.length() == 0 {
    return 0
  }
  0
}

///|
fn html_child_table_column_count(rows : Array[@core.CoreBlock]) -> Int {
  let mut best = 0
  for row in rows {
    if row.children.length() > best {
      best = row.children.length()
    }
  }
  best
}

///|
fn html_child_text_event_href(event : @dhtml.HtmlTokenEvent) -> String? {
  let href = @dhtml.html_token_event_attr_value(event, "href")
    .unwrap_or("")
    .trim()
    .to_owned()
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
fn html_token_lower_event(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  if state.skip_depth > 0 {
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag && !event.self_closing {
      state.skip_depth += 1
    } else if event.kind == @dhtml.HtmlTokenEventKind::EndTag {
      state.skip_depth -= 1
    }
    return
  }
  match event.kind {
    @dhtml.HtmlTokenEventKind::Text =>
      html_token_append_text(state, text_chars, event)
    @dhtml.HtmlTokenEventKind::StartTag =>
      html_token_start_tag(state, source, event)
    @dhtml.HtmlTokenEventKind::EndTag =>
      html_token_end_tag(state, source, event)
    @dhtml.HtmlTokenEventKind::Comment | @dhtml.HtmlTokenEventKind::Doctype =>
      ()
  }
}

///|
fn html_token_start_tag(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if html_scope_event_should_skip(event) || html_token_skip_tag(tag) {
    if !event.self_closing {
      state.skip_depth = 1
    }
    return
  }
  let heading = html_heading_level(tag)
  if heading > 0 {
    html_token_flush_text_block(state, source)
    state.text_kind = @core.BlockKind::Heading
    state.heading_level = heading
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
    return
  }
  if tag == "p" ||
    tag == "section" ||
    tag == "article" ||
    tag == "main" ||
    tag == "div" ||
    tag == "header" {
    html_token_flush_text_block(state, source)
    state.text_kind = @core.BlockKind::Paragraph
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "br" {
    state.text.write_char('\n')
  } else if tag == "pre" {
    html_token_flush_text_block(state, source)
    state.in_pre = true
    state.text_kind = @core.BlockKind::Code
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "li" {
    html_token_flush_text_block(state, source)
    state.text_kind = @core.BlockKind::ListItem
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "ul" || tag == "ol" {
    state.list_depth += 1
  } else if tag == "blockquote" {
    html_token_flush_text_block(state, source)
    state.quote_depth += 1
    state.text_kind = @core.BlockKind::BlockQuote
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "hr" {
    html_token_flush_text_block(state, source)
    let block = @core.make_block(
      @core.BlockKind::Raw,
      "---",
      source_ref=html_token_source_ref(source, event, "/html_token/hr"),
    )
    block.attrs.set("raw_kind", "markdown")
    state.blocks.push(block)
  } else if tag == "img" {
    html_token_flush_text_block(state, source)
    let image = @core.make_block(
      @core.BlockKind::Image,
      "",
      source_ref=html_token_source_ref(source, event, "/html_token/img"),
    )
    image.attrs.set(
      "alt",
      @dhtml.html_token_event_attr_value(event, "alt").unwrap_or("image"),
    )
    image.attrs.set(
      "path",
      @dhtml.html_token_event_attr_value(event, "src").unwrap_or("#"),
    )
    image.attrs.set("render_inline_escape_mode", "minimal")
    state.blocks.push(image)
  }
}

///|
fn html_token_end_tag(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if html_heading_level(tag) > 0 ||
    tag == "p" ||
    tag == "li" ||
    tag == "pre" ||
    tag == "blockquote" ||
    tag == "section" ||
    tag == "article" ||
    tag == "main" {
    state.text_end_line = event.span.line_end
    html_token_flush_text_block(state, source)
    state.text_kind = @core.BlockKind::Paragraph
    state.heading_level = 0
    if tag == "pre" {
      state.in_pre = false
    }
    if tag == "blockquote" && state.quote_depth > 0 {
      state.quote_depth -= 1
    }
  } else if (tag == "ul" || tag == "ol") && state.list_depth > 0 {
    state.list_depth -= 1
  }
}

///|
fn html_token_append_text(
  state : HtmlTokenBlockState,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let raw = html_scope_event_text(text_chars, event)
  let text = if state.in_pre { raw } else { html_compact_token_text(raw) }
  if text.trim() == "" {
    return
  }
  if state.text_start_line == 0 {
    state.text_start_line = event.span.line_start
  }
  state.text_end_line = event.span.line_end
  if state.text_has_content && !state.in_pre {
    state.text.write_char(' ')
  }
  state.text.write_string(text)
  state.text_has_content = true
}

///|
fn html_token_flush_text_block(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
) -> Unit {
  let text = if state.in_pre {
    state.text.to_string()
  } else {
    state.text.to_string().trim().to_owned()
  }
  if text == "" {
    state.text = StringBuilder::new()
    state.text_has_content = false
    return
  }
  let source_ref = html_token_lines_source_ref(
    source,
    state.text_start_line,
    state.text_end_line,
    "/html_token/block[" + state.blocks.length().to_string() + "]",
  )
  let block = @core.make_block(state.text_kind, text, source_ref~)
  if state.text_kind == @core.BlockKind::Heading {
    block.attrs.set(
      "level",
      if state.heading_level <= 0 {
        "1"
      } else {
        state.heading_level.to_string()
      },
    )
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == @core.BlockKind::ListItem {
    block.attrs.set("ordered", "false")
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == @core.BlockKind::Paragraph ||
    state.text_kind == @core.BlockKind::BlockQuote {
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == @core.BlockKind::Code {
    block.attrs.set("info", "")
  }
  state.blocks.push(block)
  state.text = StringBuilder::new()
  state.text_has_content = false
  state.text_start_line = 0
  state.text_end_line = 0
}

///|
fn html_scope_event_text(
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> String {
  let start = if event.source_start < 0 { 0 } else { event.source_start }
  let end0 = if event.source_end > text_chars.length() {
    text_chars.length()
  } else {
    event.source_end
  }
  if end0 <= start {
    return ""
  }
  @dhtml.decode_html_entities(
    String::from_array(text_chars[start:end0].to_owned()),
  )
}

///|
fn html_compact_token_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut pending_space = false
  let mut wrote_non_space = false
  for ch in text.to_array() {
    if html_ascii_space_like(ch) {
      pending_space = true
    } else {
      if pending_space && wrote_non_space {
        out.write_char(' ')
      }
      out.write_char(ch)
      wrote_non_space = true
      pending_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn html_token_skip_tag(tag : String) -> Bool {
  tag == "script" ||
  tag == "style" ||
  tag == "template" ||
  tag == "noscript" ||
  tag == "svg" ||
  tag == "math"
}

///|
fn html_token_source_ref(
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  html_path : String,
) -> @core.SourceRef {
  html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    html_path,
  )
}

///|
fn html_token_lines_source_ref(
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  html_path : String,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(if line_start <= 0 { 1 } else { line_start }),
      Some(if line_end <= 0 { line_start } else { line_end }),
    ),
    Some(source.source_name),
    Some("html"),
    Some(html_path),
  )
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
fn html_block_scope_plans_from_events(
  text : String,
  events : Array[@dhtml.HtmlTokenEvent],
) -> Array[HtmlScopePlan] {
  let roots = html_scope_plan_ranges(
    @dhtml.html_tokens_collect_element_ranges(events, ["main", "article"]),
    "hybrid_root_",
  )
  if roots.length() > 0 {
    return roots
  }
  let sections = html_scope_plan_ranges(
    @dhtml.html_tokens_collect_element_ranges(events, ["section"]),
    "hybrid_section_",
  )
  if sections.length() > 0 {
    return sections
  }
  let subtrees = html_heading_subtree_scope_plans(events)
  if subtrees.length() > 0 {
    return subtrees
  }
  [{ source_start: 0, source_end: text.length(), label: "hybrid_document" }]
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
