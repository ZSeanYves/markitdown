///|
fn html_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::HtmlTokenStructure,
    true,
    false,
    true,
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
pub fn html_parser() -> @parser.Parser {
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
pub fn html_parse_with_token_events(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  events : Array[@dhtml.HtmlTokenEvent],
) -> @parser.ParseResult {
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    return html_block_stream_parse_result_from_events(source, text, events)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "html",
  )
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("probe_artifact_reused", "true")
  @fshared.apply_product_metrics(diagnostics, "html")
  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Err(err) => malformed_html_parse_result(source, text, diagnostics, err)
    Ok(doc) => {
      let validation = @dhtml.validate_html_document(doc)
      let inspect = @dhtml.inspect_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_metrics = html_semantic_metric_summary(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_metrics,
        semantic,
        text,
        0,
        false,
        document.assets.length(),
      )
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
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
      @parser.parse_result_with_document_capability(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        final_document,
        diagnostics,
        html_parser_capability(),
      )
    }
  }
}

///|
pub fn html_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dhtml.PreparedHtmlDocument,
) -> @parser.ParseResult {
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    match prepared.events {
      Some(events) =>
        return html_block_stream_parse_result_from_events(
          source,
          prepared.normalized_text,
          events,
        )
      None =>
        match prepared.event_summary {
          Some(_) =>
            return html_block_stream_parse_result_scanned(
              source,
              prepared.normalized_text,
            )
          None => ()
        }
    }
  }
  match prepared.document {
    Some(_) => {
      let events = prepared.events
      if events is Some(_) {
        let parsed = html_parse_with_token_events(
          source,
          context,
          prepared.normalized_text,
          events.unwrap(),
        )
        parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
        parsed
      } else {
        let diagnostics = @fshared.empty_parser_diagnostics(
          "html_parser",
          @parser.ParserMode::DomAstModel,
          source,
          "html",
        )
        malformed_html_parse_result(
          source,
          prepared.original_text,
          diagnostics,
          prepared.parse_error.unwrap_or("scan html failed"),
        )
      }
    }
    None => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "html",
      )
      malformed_html_parse_result(
        source,
        prepared.original_text,
        diagnostics,
        prepared.parse_error.unwrap_or("parse html failed"),
      )
    }
  }
}

///|
pub fn html_document_to_ir(
  source : @input.InputSource,
  text : String,
) -> Result[(@core.DocumentIR, @core.Diagnostics), String] {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "html",
  )
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "dom_ast_model")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "html")

  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) => {
      let validation = @dhtml.validate_html_document(doc)
      let inspect = @dhtml.inspect_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_metrics = html_semantic_metric_summary(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_metrics,
        semantic,
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
/// Benchmark-oriented helper that only builds the HTML lowering indexes.
pub fn html_lowering_prepare_metric(
  doc : @dhtml.HtmlDocument,
  semantic : @dhtml.HtmlSemanticDocument,
) -> Int {
  let dom_index = html_dom_lowering_index(doc)
  let lowering_index = html_lowering_index(semantic, dom_index.nav_spans)
  html_lowering_index_item_count(lowering_index)
}

///|
/// Benchmark-oriented helper that builds lowering indexes and collects the
/// top-level blocks that survive HTML semantic filtering.
pub fn html_lowering_top_level_block_metric(
  doc : @dhtml.HtmlDocument,
  semantic : @dhtml.HtmlSemanticDocument,
) -> Int {
  let dom_index = html_dom_lowering_index(doc)
  let lowering_index = html_lowering_index(semantic, dom_index.nav_spans)
  let top_blocks = html_collect_top_level_blocks(semantic, lowering_index)
  top_blocks.length()
}

///|
/// Benchmark-oriented helper that runs the remaining lowering tail from
/// semantic facts into Core IR blocks.
pub fn html_lowering_block_metric(
  source : @input.InputSource,
  doc : @dhtml.HtmlDocument,
  semantic : @dhtml.HtmlSemanticDocument,
) -> Int {
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
  lowered.blocks.length()
}

///|
fn parse_html_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dhtml.prepare_html_document_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let requested_blocks = context.requested_mode ==
    Some(@parser.ParserMode::BlockStreaming)
  if requested_blocks {
    return Ok(html_block_stream_parse_result(source, text, context))
  }

  match prepared.document {
    None => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "html",
      )
      return Ok(
        malformed_html_parse_result(
          source,
          text,
          diagnostics,
          prepared.parse_error.unwrap_or("parse html failed"),
        ),
      )
    }
    Some(doc) => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "html_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "html",
      )
      diagnostics.metrics.set("parser_name", "html_parser")
      diagnostics.metrics.set("parser_mode", "dom_ast_model")
      diagnostics.metrics.set(
        "input_kind",
        @fshared.input_kind_name(@input.input_kind(source)),
      )
      diagnostics.metrics.set("detected_format", "html")
      diagnostics.metrics.set(
        "requested_mode",
        @fshared.requested_mode_name(context),
      )
      diagnostics.metrics.set("ir_input_kind", "document")
      @fshared.apply_product_metrics(diagnostics, "html")

      let validation = @dhtml.validate_html_document(doc)
      let inspect = @dhtml.inspect_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_metrics = html_semantic_metric_summary(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_metrics,
        semantic,
        text,
        0,
        false,
        document.assets.length(),
      )
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
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
fn html_block_stream_parse_result(
  source : @input.InputSource,
  text : String,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  let diagnostics = html_block_stream_diagnostics(source, context)
  let lowered = if html_prefers_semantic_block_stream(source) {
    html_lower_semantic_block_stream_document(source, text, diagnostics)
  } else if html_requires_semantic_block_stream_markup(source) {
    html_lower_child_semantic_block_stream_document(source, text, diagnostics)
  } else if html_prefers_child_text_fast_block_stream(source) {
    html_lower_child_text_block_stream_document(source, text, diagnostics)
  } else {
    html_lower_block_stream_document(source, text, diagnostics)
  }
  html_block_stream_parse_result_from_lowered(text, diagnostics, lowered)
}

///|
fn html_block_stream_parse_result_from_events(
  source : @input.InputSource,
  text : String,
  events : Array[@dhtml.HtmlTokenEvent],
) -> @parser.ParseResult {
  let diagnostics = html_block_stream_diagnostics(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Html),
  )
  diagnostics.metrics.set("requested_mode", "block_streaming")
  diagnostics.metrics.set("probe_artifact_reused", "true")
  let large_token_path = text.length() > 4_194_304 &&
    !html_child_events_require_semantic_block_stream(events)
  let lowered = if large_token_path {
    html_lower_child_text_block_stream_document_from_events(
      source, text, diagnostics, events,
    )
  } else if html_prefers_semantic_block_stream(source) {
    html_lower_semantic_block_stream_document(source, text, diagnostics)
  } else if html_requires_semantic_block_stream_markup(source) {
    html_lower_child_semantic_block_stream_document(source, text, diagnostics)
  } else if html_prefers_child_text_fast_block_stream(source) {
    html_lower_child_text_block_stream_document_from_events(
      source, text, diagnostics, events,
    )
  } else {
    html_lower_block_stream_document_from_events(
      source, text, diagnostics, events,
    )
  }
  html_block_stream_parse_result_from_lowered(text, diagnostics, lowered)
}

///|
fn html_block_stream_parse_result_scanned(
  source : @input.InputSource,
  text : String,
) -> @parser.ParseResult {
  let diagnostics = html_block_stream_diagnostics(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Html),
  )
  diagnostics.metrics.set("requested_mode", "block_streaming")
  diagnostics.metrics.set("probe_artifact_reused", "true")
  let lowered = html_lower_child_text_block_stream_document_scanned(
    source, text, diagnostics,
  )
  html_block_stream_parse_result_from_lowered(text, diagnostics, lowered)
}

///|
fn html_block_stream_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "html_parser",
    @parser.ParserMode::BlockStreaming,
    source,
    "html",
  )
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "block_streaming")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "block_streaming")
  diagnostics.metrics.set("ir_input_kind", "block_stream")
  diagnostics.metrics.set("event_granularity", "html_token_structure")
  diagnostics.metrics.set("event_semantics", "html_block_stream")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "html")
  diagnostics
}

///|
fn html_prefers_semantic_block_stream(source : @input.InputSource) -> Bool {
  @input.input_kind(source) == @input.InputKind::Bytes
}

///|
fn html_prefers_child_text_fast_block_stream(
  source : @input.InputSource,
) -> Bool {
  @input.input_kind(source) == @input.InputKind::Text &&
  @input.input_text(source) is Some(_)
}

///|
fn html_requires_semantic_block_stream_markup(
  source : @input.InputSource,
) -> Bool {
  if @input.input_kind(source) != @input.InputKind::Text {
    return false
  }
  let text = match @input.input_text(source) {
    Some(value) => value
    None => return false
  }
  html_contains_ascii_case_insensitive(text, "<figure") ||
  html_contains_ascii_case_insensitive(text, "<details") ||
  html_contains_ascii_case_insensitive(text, "<summary")
}

///|
fn html_contains_ascii_case_insensitive(
  text : String,
  needle_lower : String,
) -> Bool {
  let haystack = text.to_array()
  let needle = needle_lower.to_array()
  if needle.length() == 0 {
    return true
  }
  if haystack.length() < needle.length() {
    return false
  }
  let limit = haystack.length() - needle.length()
  for start in 0..<=limit {
    let mut matched = true
    for offset in 0..<needle.length() {
      if html_lower_ascii_char(haystack[start + offset]) != needle[offset] {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
  }
  false
}

///|
fn html_lower_ascii_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + 32)
  } else {
    ch
  }
}

///|
fn html_block_stream_parse_result_from_lowered(
  text : String,
  diagnostics : @core.Diagnostics,
  lowered : HtmlLoweringResult,
) -> @parser.ParseResult {
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.pass_trace.push("parse:html_parser:block_stream_route")
  diagnostics.pass_trace.push("lower:html_scope_subtree_blocks")
  diagnostics.pass_trace.push("parse:html_parser")
  @parser.parse_result_with_blocks_capability(
    "html_parser",
    @parser.ParserMode::BlockStreaming,
    lowered.blocks,
    diagnostics,
    html_parser_capability(),
    metadata=lowered.metadata,
    assets=lowered.assets,
  )
}

///|
fn html_lower_semantic_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    _ => Err(())
  }
  match parsed {
    Ok(doc) => {
      let validation = @dhtml.validate_html_document(doc)
      let inspect = @dhtml.inspect_html_document(doc)
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_metrics = html_semantic_metric_summary(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_common_metrics(
        diagnostics,
        inspect,
        validation,
        semantic_metrics,
        semantic,
        text,
        0,
        false,
        document.assets.length(),
      )
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "false")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set("scope_plan_labels", "semantic_block_stream")
      {
        blocks: document.blocks,
        metadata: document.metadata,
        assets: document.assets,
      }
    }
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "unavailable")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set(
        "scope_plan_labels", "semantic_block_stream_failed",
      )
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
}

///|
fn html_lower_child_semantic_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let parsed = try @dhtml.parse_html_document(text) |> Ok catch {
    _ => Err(())
  }
  match parsed {
    Ok(doc) => {
      let semantic = @dhtml.collect_html_semantic_document(doc)
      let semantic_metrics = html_semantic_metric_summary(semantic)
      let document = lower_html_document(doc, semantic, source)
      html_fill_child_semantic_metrics(
        diagnostics,
        semantic_metrics,
        semantic,
        text,
        document.assets.length(),
      )
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "false")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set(
        "scope_plan_labels", "child_semantic_block_stream",
      )
      {
        blocks: document.blocks,
        metadata: document.metadata,
        assets: document.assets,
      }
    }
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "unavailable")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set(
        "scope_plan_labels", "child_semantic_block_stream_failed",
      )
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
}

///|
