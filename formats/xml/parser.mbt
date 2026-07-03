///|
fn xml_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::XmlStructure,
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
pub fn xml_parser() -> @parser.Parser {
  @parser.make_parser(
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    xml_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_xml_document_result(source, context)
    },
  )
}

///|
pub fn xml_parse_with_structure_tokens(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  tokens : Array[@dxml.XmlToken],
) -> @parser.ParseResult {
  parse_xml_document_result_from_normalized(
    source,
    context,
    normalize_xml_text_for_next(text),
    tokenized=Some(tokens),
  )
}

///|
fn parse_xml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match read_xml_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  Ok(
    parse_xml_document_result_from_normalized(
      source,
      context,
      normalize_xml_text_for_next(text),
      tokenized=None,
    ),
  )
}

///|
fn parse_xml_document_result_from_normalized(
  source : @input.InputSource,
  context : @parser.ParseContext,
  normalized : String,
  tokenized? : Array[@dxml.XmlToken]? = None,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "xml",
  )
  let requested_streaming = context.requested_mode ==
    Some(@parser.ParserMode::StreamingEvent)
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "xml",
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    if requested_streaming {
      @parser.ParserMode::StreamingEvent
    } else {
      @parser.ParserMode::DomAstModel
    },
    if requested_streaming {
      "event_stream"
    } else {
      "document"
    },
    if requested_streaming {
      @parser.StreamingGranularity::XmlStructure
    } else {
      @parser.StreamingGranularity::None
    },
    if requested_streaming {
      "xml_structure_event_stream"
    } else {
      "dom_ast_model"
    },
  )
  @fshared.apply_product_metrics(diagnostics, "xml")
  if normalized.trim() == "" {
    diagnostics.metrics.set("resource_limit_hit", "false")
    diagnostics.metrics.set("dom_limit_reached", "false")
    diagnostics.metrics.set("element_count", "0")
    diagnostics.metrics.set("attribute_count", "0")
    diagnostics.metrics.set("text_node_count", "0")
    diagnostics.metrics.set("comment_count", "0")
    diagnostics.metrics.set("cdata_count", "0")
    diagnostics.metrics.set("processing_instruction_count", "0")
    diagnostics.metrics.set("max_depth_observed", "0")
    diagnostics.metrics.set("syntax_error_count", "0")
    diagnostics.metrics.set("doctype_seen", "false")
    diagnostics.metrics.set("external_entity_seen", "false")
    diagnostics.metrics.set("custom_entity_seen", "false")
    diagnostics.metrics.set(
      "line_count",
      @fshared.count_physical_lines(normalized).to_string(),
    )
    diagnostics.metrics.set("char_count", normalized.length().to_string())
    diagnostics.metrics.set("table_count", "0")
    diagnostics.metrics.set("image_count", "0")
    diagnostics.metrics.set("asset_count", "0")
    diagnostics.metrics.set("validation_issue_count", "0")
    diagnostics.metrics.set("warning_count", "0")
    diagnostics.metrics.set("error_count", "0")
    diagnostics.metrics.set("block_count", "0")
    diagnostics.metrics.set("event_count", "0")
    diagnostics.metrics.set("degraded_feature_count", "0")
    diagnostics.metrics.set("fallback_count", "0")
    diagnostics.pass_trace.push("parse:xml_parser")
    let document = @core.document_with_diagnostics(
      @core.empty_document_ir(),
      diagnostics,
    )
    return @parser.parse_result_with_document_capability(
      "xml_parser",
      @parser.ParserMode::DomAstModel,
      document,
      diagnostics,
      xml_parser_capability(),
    )
  }
  if requested_streaming {
    let parsed_tokens = match tokenized {
      Some(tokens) => Ok(tokens)
      None =>
        try @dxml.parse_xml_structure_tokens(normalized) |> Ok catch {
          e => Err(@dxml.XmlError::ParseError(e.to_string()))
        }
    }
    match parsed_tokens {
      Ok(tokens) => {
        let summary = xml_stream_summary(tokens)
        let has_multiline_attribute = xml_tokens_have_multiline_attribute_value(
          tokens,
        )
        diagnostics.metrics.set(
          "stream_policy_has_unsupported_doctype",
          @fshared.bool_string(summary.has_unsupported_doctype),
        )
        diagnostics.metrics.set(
          "stream_policy_has_complex_mixed_content",
          @fshared.bool_string(summary.has_complex_mixed_content),
        )
        diagnostics.metrics.set(
          "stream_policy_has_markdown_fence_text",
          @fshared.bool_string(summary.has_markdown_fence_text),
        )
        diagnostics.metrics.set(
          "stream_policy_has_default_namespace",
          @fshared.bool_string(summary.has_default_namespace),
        )
        diagnostics.metrics.set(
          "stream_policy_has_multiline_attribute_value",
          @fshared.bool_string(has_multiline_attribute),
        )
        if summary.has_unsupported_doctype ||
          summary.has_complex_mixed_content ||
          summary.has_markdown_fence_text ||
          summary.has_default_namespace ||
          has_multiline_attribute {
          return malformed_xml_text_parse_result(
            source, normalized, diagnostics, "xml parser policy rejected structured lowering",
          )
        }
        let events = xml_generic_block_events_from_tokens(tokens, source)
        diagnostics.metrics.set("parser_mode", "streaming_event")
        diagnostics.metrics.set("effective_mode", "streaming_event")
        diagnostics.metrics.set("ir_input_kind", "event_stream")
        diagnostics.metrics.set("resource_limit_hit", "false")
        diagnostics.metrics.set("dom_limit_reached", "false")
        xml_fill_stream_metrics(
          diagnostics,
          summary,
          normalized,
          events.length(),
        )
        diagnostics.metrics.set(
          "block_count",
          count_xml_event_blocks(events).to_string(),
        )
        diagnostics.metrics.set("event_granularity", "xml_structure")
        diagnostics.metrics.set("event_semantics", "xml_structure_event_stream")
        diagnostics.pass_trace.push("parse:xml_parser")
        return @parser.parse_result_with_events_capability(
          "xml_parser",
          @parser.ParserMode::StreamingEvent,
          events,
          diagnostics,
          xml_parser_capability(),
        )
      }
      Err(err) =>
        return malformed_xml_parse_result(source, normalized, diagnostics, err)
    }
  }

  let parsed = try @dxml.parse_xml_document(normalized) |> Ok catch {
    e => Err(@dxml.XmlError::ParseError(e.to_string()))
  }
  match parsed {
    Ok(doc) => {
      let inspect = @dxml.inspect_xml_document(doc)
      let validation = @dxml.validate_xml_document(doc)
      if xml_requires_fail_closed_outline(doc, normalized) {
        return malformed_xml_text_parse_result(
          source, normalized, diagnostics, "xml parser policy rejected structured lowering",
        )
      }
      let document = lower_xml_document(doc, source)
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("dom_limit_reached", "false")
      xml_fill_common_metrics(
        diagnostics, doc, inspect, validation, normalized, 0,
      )
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      diagnostics.metrics.set("event_granularity", "none")
      diagnostics.metrics.set("event_semantics", "dom_ast_model")
      diagnostics.pass_trace.push("parse:xml_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      @parser.parse_result_with_document_capability(
        "xml_parser",
        @parser.ParserMode::DomAstModel,
        final_document,
        diagnostics,
        xml_parser_capability(),
      )
    }
    Err(err) => malformed_xml_parse_result(source, normalized, diagnostics, err)
  }
}

///|
