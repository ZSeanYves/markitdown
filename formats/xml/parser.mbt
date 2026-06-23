///|
fn xml_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    true,
    @parser.StreamingGranularity::XmlStructure,
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
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
pub fn xml_lite_parser() -> @parser.Parser {
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
fn parse_xml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match read_xml_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let normalized = normalize_xml_text_for_next(text)
  let diagnostics = @light_common.empty_parser_diagnostics(
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "xml",
  )
  diagnostics.metrics.set("parser_name", "xml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "xml")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("ir_input_kind", "document")
  @light_common.apply_readiness_metrics(diagnostics, "xml", "near_ready")
  if normalized.trim() == "" {
    diagnostics.metrics.set("effective_mode", "dom_ast_model")
    diagnostics.metrics.set("streaming_fallback", "false")
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
      @light_common.count_physical_lines(normalized).to_string(),
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
    diagnostics.metrics.set("event_granularity", "none")
    diagnostics.metrics.set("event_semantics", "dom_ast_model")
    diagnostics.metrics.set("degraded_feature_count", "0")
    diagnostics.metrics.set("fallback_count", "0")
    diagnostics.pass_trace.push("parse:xml_parser")
    let document = @core.document_with_diagnostics(
      @core.empty_document_ir(),
      diagnostics,
    )
    return Ok(
      @parser.parse_result_with_document_capability(
        "xml_parser",
        @parser.ParserMode::DomAstModel,
        document,
        diagnostics,
        xml_parser_capability(),
      ),
    )
  }
  let parsed = try @dxml.parse_xml_document(normalized) |> Ok catch {
    e => Err(@dxml.XmlError::ParseError(e.to_string()))
  }
  match parsed {
    Ok(doc) => {
      let inspect = @dxml.inspect_xml_document(doc)
      let validation = @dxml.validate_xml_document(doc)
      if xml_requires_fail_closed_outline(doc, normalized) {
        return Ok(
          malformed_xml_text_parse_result(
            source, normalized, diagnostics, "xml parser policy rejected structured lowering",
          ),
        )
      }
      let dom_limit_reached = xml_dom_limit_reached(
        context, inspect, normalized,
      )
      if dom_limit_reached {
        let document = lower_xml_document(doc, source)
        let events = @pipeline.blocks_to_event_stream(document.blocks)
        diagnostics.metrics.set("parser_mode", "streaming_event")
        diagnostics.metrics.set("effective_mode", "streaming_event")
        diagnostics.metrics.set("ir_input_kind", "event_stream")
        diagnostics.metrics.set("streaming_fallback", "true")
        diagnostics.metrics.set("resource_limit_hit", "true")
        diagnostics.metrics.set("dom_limit_reached", "true")
        xml_fill_common_metrics(
          diagnostics,
          doc,
          inspect,
          validation,
          normalized,
          events.length(),
        )
        diagnostics.metrics.set(
          "block_count",
          document.blocks.length().to_string(),
        )
        diagnostics.metrics.set("event_granularity", "xml_structure")
        diagnostics.metrics.set("event_semantics", "xml_structure_event_stream")
        diagnostics.pass_trace.push("parse:xml_parser")
        return Ok(
          @parser.parse_result_with_events_capability(
            "xml_parser",
            @parser.ParserMode::StreamingEvent,
            events,
            diagnostics,
            xml_parser_capability(),
          ),
        )
      }
      let document = lower_xml_document(doc, source)
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
      diagnostics.metrics.set("streaming_fallback", "false")
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
      Ok(
        @parser.parse_result_with_document_capability(
          "xml_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          xml_parser_capability(),
        ),
      )
    }
    Err(err) =>
      Ok(malformed_xml_parse_result(source, normalized, diagnostics, err))
  }
}

///|
fn xml_dom_limit_reached(
  context : @parser.ParseContext,
  inspect : @dxml.XmlInspectReport,
  text : String,
) -> Bool {
  let node_limit = context.max_cells.unwrap_or(10000)
  let depth_limit = context.max_rows.unwrap_or(200)
  let text_limit = context.max_line_chars.unwrap_or(4000)
  inspect.node_count > node_limit ||
  inspect.max_depth > depth_limit ||
  text.length() > text_limit
}

///|
fn xml_fill_common_metrics(
  diagnostics : @core.Diagnostics,
  doc : @dxml.XmlDocument,
  inspect : @dxml.XmlInspectReport,
  validation : @dxml.XmlValidationReport,
  text : String,
  event_count : Int,
) -> Unit {
  diagnostics.metrics.set("element_count", inspect.element_count.to_string())
  diagnostics.metrics.set(
    "attribute_count",
    inspect.attribute_count.to_string(),
  )
  diagnostics.metrics.set(
    "text_node_count",
    inspect.text_node_count.to_string(),
  )
  diagnostics.metrics.set("comment_count", inspect.comment_count.to_string())
  diagnostics.metrics.set("cdata_count", inspect.cdata_count.to_string())
  diagnostics.metrics.set(
    "processing_instruction_count",
    inspect.processing_instruction_count.to_string(),
  )
  diagnostics.metrics.set("max_depth_observed", inspect.max_depth.to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "doctype_seen",
    @light_common.bool_string(doc.has_doctype),
  )
  diagnostics.metrics.set(
    "external_entity_seen",
    @light_common.bool_string(xml_doctype_contains_external_entity(doc)),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @light_common.bool_string(doc.has_unsupported_doctype),
  )
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set(
    "validation_issue_count",
    validation.issue_count.to_string(),
  )
  diagnostics.metrics.set("warning_count", validation.warning_count.to_string())
  diagnostics.metrics.set("error_count", validation.error_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  for issue in validation.issues {
    diagnostics.warnings.push(issue.message)
    diagnostics.fallback_trace.push("xml validation: " + issue.message)
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
fn lower_xml_document(
  doc : @dxml.XmlDocument,
  source : @input.InputSource,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  match doc.root {
    Some(root) => {
      let heading = @core.make_block(
        @core.BlockKind::Heading,
        "<" + root.name + ">",
        source_ref=xml_element_source_ref(source, root, "/" + root.name),
      )
      heading.attrs.set("level", "1")
      heading.attrs.set("literal", "true")
      document.blocks.push(heading)
      let list = @core.make_block(
        @core.BlockKind::List,
        "",
        source_ref=xml_element_source_ref(source, root, "/" + root.name),
      )
      append_xml_element_outline(list, root, source, "/" + root.name, 0)
      if list.children.length() > 0 {
        document.blocks.push(list)
      }
    }
    None => ()
  }
  document
}

///|
fn xml_requires_fail_closed_outline(
  doc : @dxml.XmlDocument,
  text : String,
) -> Bool {
  if doc.has_unsupported_doctype {
    return true
  }
  let root = match doc.root {
    Some(root) => root
    None => return false
  }
  for node in doc.nodes {
    match node {
      @dxml.XmlNode::Element(_) => ()
      @dxml.XmlNode::Text(text) => if text.text.trim() != "" { return true }
      @dxml.XmlNode::CData(cdata) => if cdata.text.trim() != "" { return true }
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
    }
  }
  xml_has_complex_mixed_content(root) ||
  xml_has_markdown_fence_text(root) ||
  xml_source_has_multiline_attribute_value(text) ||
  xml_has_default_namespace(root)
}

///|
fn xml_has_complex_mixed_content(element : @dxml.XmlElement) -> Bool {
  let mut has_nonempty_text = false
  let mut has_element_child = false
  for child in element.children {
    match child {
      @dxml.XmlNode::Element(child_element) => {
        has_element_child = true
        if xml_has_complex_mixed_content(child_element) {
          return true
        }
      }
      @dxml.XmlNode::Text(text) =>
        if text.text.trim() != "" {
          has_nonempty_text = true
        }
      @dxml.XmlNode::CData(cdata) =>
        if cdata.text.trim() != "" {
          has_nonempty_text = true
        }
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
    }
  }
  has_nonempty_text && has_element_child
}

///|
fn xml_has_markdown_fence_text(element : @dxml.XmlElement) -> Bool {
  for attr in element.attributes {
    if attr.value.contains("```") {
      return true
    }
  }
  for child in element.children {
    match child {
      @dxml.XmlNode::Element(child_element) =>
        if xml_has_markdown_fence_text(child_element) {
          return true
        }
      @dxml.XmlNode::Text(text) => if text.text.contains("```") { return true }
      @dxml.XmlNode::CData(cdata) =>
        if cdata.text.contains("```") {
          return true
        }
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
    }
  }
  false
}

///|
fn xml_has_default_namespace(element : @dxml.XmlElement) -> Bool {
  for attr in element.attributes {
    if attr.name == "xmlns" {
      return true
    }
  }
  for child in element.children {
    match child {
      @dxml.XmlNode::Element(child_element) =>
        if xml_has_default_namespace(child_element) {
          return true
        }
      @dxml.XmlNode::Text(_) => ()
      @dxml.XmlNode::CData(_) => ()
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
    }
  }
  false
}

///|
fn append_xml_element_outline(
  list : @core.CoreBlock,
  element : @dxml.XmlElement,
  source : @input.InputSource,
  path : String,
  depth : Int,
) -> Unit {
  for attr in element.attributes {
    list.children.push(
      {
        let item = @core.block_with_attr(
          @core.make_block(
            @core.BlockKind::ListItem,
            "@" + attr.name + ": " + attr.value,
            source_ref=xml_attribute_source_ref(
              source,
              attr,
              path + "/@" + attr.name,
            ),
          ),
          "ordered",
          "false",
        )
        item.attrs.set("literal", "true")
        item
      },
    )
  }

  let child_element_counts : Map[String, Int] = Map([], capacity=8)
  for child in element.children {
    match child {
      @dxml.XmlNode::Element(child_element) => {
        let next_count = child_element_counts
          .get(child_element.name)
          .unwrap_or(0)
        child_element_counts.set(child_element.name, next_count + 1)
        let child_path = path +
          "/" +
          child_element.name +
          "[" +
          next_count.to_string() +
          "]"
        match xml_simple_text_value(child_element) {
          Some(value) =>
            list.children.push(
              {
                let item = @core.block_with_attr(
                  @core.make_block(
                    @core.BlockKind::ListItem,
                    child_element.name + ": " + value,
                    source_ref=xml_element_source_ref(
                      source, child_element, child_path,
                    ),
                  ),
                  "ordered",
                  "false",
                )
                item.attrs.set("literal", "true")
                item
              },
            )
          None => {
            let label = if depth == 0 {
              "<" + child_element.name + ">"
            } else {
              child_element.name
            }
            let nested = @core.block_with_attr(
              @core.make_block(
                @core.BlockKind::ListItem,
                label,
                source_ref=xml_element_source_ref(
                  source, child_element, child_path,
                ),
              ),
              "ordered",
              "false",
            )
            nested.attrs.set("literal", "true")
            let child_list = @core.make_block(
              @core.BlockKind::List,
              "",
              source_ref=xml_element_source_ref(
                source, child_element, child_path,
              ),
            )
            append_xml_element_outline(
              child_list,
              child_element,
              source,
              child_path,
              depth + 1,
            )
            if child_list.children.length() > 0 {
              nested.children.push(child_list)
            }
            list.children.push(nested)
          }
        }
      }
      @dxml.XmlNode::Text(text) =>
        if text.text.trim() != "" {
          list.children.push(
            {
              let item = @core.block_with_attr(
                @core.make_block(
                  @core.BlockKind::ListItem,
                  text.text.trim().to_owned(),
                  source_ref=xml_text_source_ref(source, text, path),
                ),
                "ordered",
                "false",
              )
              item.attrs.set("literal", "true")
              item
            },
          )
        }
      @dxml.XmlNode::CData(cdata) =>
        if cdata.text.trim() != "" {
          list.children.push(
            {
              let item = @core.block_with_attr(
                @core.make_block(
                  @core.BlockKind::ListItem,
                  cdata.text.trim().to_owned(),
                  source_ref=xml_cdata_source_ref(source, cdata, path),
                ),
                "ordered",
                "false",
              )
              item.attrs.set("literal", "true")
              item
            },
          )
        }
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
    }
  }
}

///|
fn xml_simple_text_value(element : @dxml.XmlElement) -> String? {
  if element.attributes.length() > 0 {
    return None
  }
  let collected : Array[String] = []
  for child in element.children {
    match child {
      @dxml.XmlNode::Text(text) =>
        if text.text.trim() != "" {
          collected.push(text.text.trim().to_owned())
        }
      @dxml.XmlNode::CData(cdata) =>
        if cdata.text.trim() != "" {
          collected.push(cdata.text.trim().to_owned())
        }
      @dxml.XmlNode::Comment(_) => ()
      @dxml.XmlNode::ProcessingInstruction(_) => ()
      @dxml.XmlNode::Element(_) => return None
    }
  }
  if collected.length() == 0 {
    None
  } else if collected.length() == 1 {
    Some(collected[0])
  } else {
    Some(collected.join(" "))
  }
}

///|
fn malformed_xml_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : @dxml.XmlError,
) -> @parser.ParseResult {
  let info = @dxml.classify_xml_error(err)
  let source_ref = @core.source_ref_with_lines(
    @core.source_ref_with_bytes(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(0),
      Some(text.length()),
    ),
    Some(source.source_name),
    Some("xml"),
    Some(1),
    Some(@light_common.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "xml_fail_closed")
  block.attrs.set("info", "xml")
  diagnostics.errors.push("xml parse failed: " + err.to_string())
  diagnostics.degraded_features.push("xml_fail_closed")
  diagnostics.fallback_trace.push("xml parse failed closed: " + info.detail)
  diagnostics.metrics.set("parser_name", "xml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "xml")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "xml_dom_ast_model_failed_closed")
  diagnostics.metrics.set("element_count", "0")
  diagnostics.metrics.set("attribute_count", "0")
  diagnostics.metrics.set("text_node_count", "0")
  diagnostics.metrics.set("comment_count", "0")
  diagnostics.metrics.set("cdata_count", "0")
  diagnostics.metrics.set("processing_instruction_count", "0")
  diagnostics.metrics.set("max_depth_observed", "0")
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "doctype_seen",
    @light_common.bool_string(text.contains("<!DOCTYPE")),
  )
  diagnostics.metrics.set(
    "external_entity_seen",
    @light_common.bool_string(text.contains("SYSTEM")),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @light_common.bool_string(text.contains("<!ENTITY")),
  )
  diagnostics.metrics.set("validation_issue_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:xml_parser")
  let document = @core.empty_document_ir()
  document.blocks.push(block)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    xml_parser_capability(),
  )
}

///|
fn malformed_xml_text_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  detail : String,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    @core.source_ref_with_bytes(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(0),
      Some(text.length()),
    ),
    Some(source.source_name),
    Some("xml"),
    Some(1),
    Some(@light_common.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "xml_fail_closed")
  block.attrs.set("info", "xml")
  diagnostics.warnings.push("xml parse warning: " + detail)
  diagnostics.degraded_features.push("xml_fail_closed")
  diagnostics.fallback_trace.push("xml fail closed: " + detail)
  diagnostics.metrics.set("parser_name", "xml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "xml")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "xml_dom_ast_model_failed_closed")
  diagnostics.metrics.set("element_count", "0")
  diagnostics.metrics.set("attribute_count", "0")
  diagnostics.metrics.set("text_node_count", "0")
  diagnostics.metrics.set("comment_count", "0")
  diagnostics.metrics.set("cdata_count", "0")
  diagnostics.metrics.set("processing_instruction_count", "0")
  diagnostics.metrics.set("max_depth_observed", "0")
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "doctype_seen",
    @light_common.bool_string(text.contains("<!DOCTYPE")),
  )
  diagnostics.metrics.set(
    "external_entity_seen",
    @light_common.bool_string(text.contains("SYSTEM")),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @light_common.bool_string(text.contains("<!ENTITY") || text.contains("&")),
  )
  diagnostics.metrics.set("validation_issue_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:xml_parser")
  let document = @core.empty_document_ir()
  document.blocks.push(block)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "xml_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    xml_parser_capability(),
  )
}

///|
fn xml_element_source_ref(
  source : @input.InputSource,
  element : @dxml.XmlElement,
  path : String,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(element.span.line_start),
      Some(element.span.line_end),
    ),
    xpath: Some(path),
  }
}

///|
fn xml_attribute_source_ref(
  source : @input.InputSource,
  attr : @dxml.XmlAttribute,
  path : String,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(attr.span.line_start),
      Some(attr.span.line_end),
    ),
    xpath: Some(path),
  }
}

///|
fn xml_text_source_ref(
  source : @input.InputSource,
  text : @dxml.XmlText,
  path : String,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(text.span.line_start),
      Some(text.span.line_end),
    ),
    xpath: Some(path),
  }
}

///|
fn xml_cdata_source_ref(
  source : @input.InputSource,
  cdata : @dxml.XmlCData,
  path : String,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(cdata.span.line_start),
      Some(cdata.span.line_end),
    ),
    xpath: Some(path),
  }
}

///|
fn normalize_xml_text_for_next(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(ch)
      i += 1
    }
  }
  String::from_array(out)
}

///|
fn read_xml_input_text(source : @input.InputSource) -> Result[String, String] {
  match source.text {
    Some(text) => Ok(text)
    None =>
      match @input.read_input_bytes(source) {
        Ok(bytes) => decode_xml_input_bytes(bytes)
        Err(err) => Err(err)
      }
  }
}

///|
fn decode_xml_input_bytes(bytes : Bytes) -> Result[String, String] {
  let declared = sniff_xml_declared_encoding(bytes)
  match declared {
    Some(encoding) =>
      if encoding == "iso-8859-1" || encoding == "latin1" {
        return Ok(decode_iso_8859_1_bytes(bytes))
      }
    None => ()
  }
  try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
    _ => Err("utf8 decode failed")
  }
}

///|
fn sniff_xml_declared_encoding(bytes : Bytes) -> String? {
  let mut limit = bytes.length()
  if limit > 256 {
    limit = 256
  }
  let chars : Array[Char] = []
  let mut index = 0
  while index < limit {
    chars.push(Int::unsafe_to_char(bytes[index].to_int()))
    index += 1
  }
  let prefix = String::from_array(chars)
  match prefix.find("encoding") {
    Some(rel_start) => {
      let start = rel_start + 8
      let suffix = prefix[start:].to_owned()
      match suffix.find("=") {
        Some(eq_rel) => {
          let mut pos = eq_rel + 1
          while pos < suffix.length() {
            let ch = suffix.unsafe_get(pos).unsafe_to_char()
            if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
              pos += 1
            } else {
              break
            }
          }
          if pos >= suffix.length() {
            return None
          }
          let quote = suffix.unsafe_get(pos).unsafe_to_char()
          if quote != '"' && quote != '\'' {
            return None
          }
          let body = suffix[pos + 1:].to_owned()
          let needle = String::from_array([quote])
          match body.find(needle) {
            Some(end_rel) =>
              Some(body[:end_rel].to_owned().trim().to_owned().to_lower())
            None => None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn decode_iso_8859_1_bytes(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(Int::unsafe_to_char(xml_byte_to_int(byte)))
  }
  String::from_array(chars)
}

///|
fn xml_source_has_multiline_attribute_value(text : String) -> Bool {
  let chars = text.to_array()
  let mut in_single = false
  let mut in_double = false
  let mut saw_content = false
  for ch in chars {
    if in_single {
      if ch == '\'' {
        in_single = false
      } else if saw_content && ch == '\n' {
        return true
      } else if ch != ' ' && ch != '\t' && ch != '\r' {
        saw_content = true
      }
      continue
    }
    if in_double {
      if ch == '"' {
        in_double = false
      } else if saw_content && ch == '\n' {
        return true
      } else if ch != ' ' && ch != '\t' && ch != '\r' {
        saw_content = true
      }
      continue
    }
    if ch == '\'' {
      in_single = true
      saw_content = false
    } else if ch == '"' {
      in_double = true
      saw_content = false
    }
  }
  false
}

///|
fn xml_byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}

///|
fn xml_doctype_contains_external_entity(doc : @dxml.XmlDocument) -> Bool {
  doc.has_unsupported_doctype
}
