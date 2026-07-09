///|
priv struct XmlStreamSummary {
  element_count : Int
  attribute_count : Int
  text_node_count : Int
  comment_count : Int
  cdata_count : Int
  processing_instruction_count : Int
  max_depth : Int
  has_doctype : Bool
  has_unsupported_doctype : Bool
  has_complex_mixed_content : Bool
  has_markdown_fence_text : Bool
  has_default_namespace : Bool
}

///|
fn xml_fill_stream_metrics(
  diagnostics : @core.Diagnostics,
  summary : XmlStreamSummary,
  text : String,
  event_count : Int,
) -> Unit {
  diagnostics.metrics.set("element_count", summary.element_count.to_string())
  diagnostics.metrics.set(
    "attribute_count",
    summary.attribute_count.to_string(),
  )
  diagnostics.metrics.set(
    "text_node_count",
    summary.text_node_count.to_string(),
  )
  diagnostics.metrics.set("comment_count", summary.comment_count.to_string())
  diagnostics.metrics.set("cdata_count", summary.cdata_count.to_string())
  diagnostics.metrics.set(
    "processing_instruction_count",
    summary.processing_instruction_count.to_string(),
  )
  diagnostics.metrics.set("max_depth_observed", summary.max_depth.to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "doctype_seen",
    @fshared.bool_string(summary.has_doctype),
  )
  diagnostics.metrics.set("external_entity_seen", "false")
  diagnostics.metrics.set(
    "custom_entity_seen",
    @fshared.bool_string(summary.has_unsupported_doctype),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("validation_issue_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set("event_count", event_count.to_string())
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
  diagnostics.metrics.set("doctype_seen", @fshared.bool_string(doc.has_doctype))
  diagnostics.metrics.set(
    "external_entity_seen",
    @fshared.bool_string(xml_doctype_contains_external_entity(doc)),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @fshared.bool_string(doc.has_unsupported_doctype),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
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
fn xml_generic_block_events_from_tokens(
  tokens : Array[@dxml.XmlToken],
  source : @input.InputSource,
) -> Array[@core.CoreEvent] {
  let blocks = xml_outline_blocks_from_tokens(tokens, source)
  let events : Array[@core.CoreEvent] = []
  if blocks.length() == 0 {
    return events
  }
  if blocks[0].kind == @core.BlockKind::Heading {
    xml_append_generic_block_events(events, blocks[0])
    if blocks.length() > 1 {
      xml_append_generic_block_events(events, blocks[1])
    }
    return events
  }
  for block in blocks {
    xml_append_generic_block_events(events, block)
  }
  events
}

///|
priv struct XmlOutlineFrame {
  element_name : String
  element_path : String
  element_ref : @core.SourceRef
  attributes : Array[@dxml.XmlAttribute]
  children : Array[@core.CoreBlock]
  text_values : Array[String]
}

///|
fn xml_outline_blocks_from_tokens(
  tokens : Array[@dxml.XmlToken],
  source : @input.InputSource,
) -> Array[@core.CoreBlock] {
  let stack : Array[XmlOutlineFrame] = []
  let roots : Array[@core.CoreBlock] = []
  let sibling_counts : Array[Map[String, Int]] = []
  for token in tokens {
    match token {
      @dxml.XmlToken::Declaration(_, _) => ()
      @dxml.XmlToken::ProcessingInstruction(_, _, _) => ()
      @dxml.XmlToken::Comment(_, _) => ()
      @dxml.XmlToken::Doctype(_, _) => ()
      @dxml.XmlToken::Text(text, span) =>
        if text.trim() != "" && stack.length() > 0 {
          let current = stack[stack.length() - 1]
          ignore(span)
          current.text_values.push(text.trim().to_owned())
        }
      @dxml.XmlToken::CData(text, span) =>
        if text.trim() != "" && stack.length() > 0 {
          let current = stack[stack.length() - 1]
          ignore(span)
          current.text_values.push(text.trim().to_owned())
        }
      @dxml.XmlToken::StartTag(name, attrs, self_closing, span) => {
        let (path, depth) = xml_outline_push_path(name, stack, sibling_counts)
        let frame = {
          element_name: name,
          element_path: path,
          element_ref: xml_stream_element_source_ref(source, span, path),
          attributes: attrs,
          children: [],
          text_values: [],
        }
        if self_closing {
          let block = xml_outline_frame_to_block(frame, source, depth)
          xml_outline_push_block(stack, roots, block)
        } else {
          stack.push(frame)
          sibling_counts.push(Map([]))
        }
      }
      @dxml.XmlToken::EndTag(_, _) =>
        match stack.pop() {
          Some(frame) => {
            ignore(sibling_counts.pop())
            let block = xml_outline_frame_to_block(
              frame,
              source,
              stack.length(),
            )
            xml_outline_push_block(stack, roots, block)
          }
          None => ()
        }
    }
  }
  if roots.length() == 0 {
    return roots
  }
  let first = roots[0]
  if first.kind != @core.BlockKind::ListItem {
    return roots
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    first.text,
    source_ref=first.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  heading.attrs.set("level", "1")
  heading.attrs.set("literal", "true")
  let blocks : Array[@core.CoreBlock] = [heading]
  if first.children.length() > 0 {
    if first.children.length() == 1 &&
      first.children[0].kind == @core.BlockKind::List {
      blocks.push(first.children[0])
    } else {
      let list = @core.make_block(
        @core.BlockKind::List,
        "",
        source_ref=first.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      list.attrs.set("ordered", "false")
      for child in first.children {
        list.children.push(child)
      }
      blocks.push(list)
    }
  }
  blocks
}

///|
fn xml_outline_push_path(
  name : String,
  stack : Array[XmlOutlineFrame],
  sibling_counts : Array[Map[String, Int]],
) -> (String, Int) {
  let depth = stack.length()
  let path = if depth == 0 {
    "/" + name
  } else {
    let parent_counts = sibling_counts[depth - 1]
    let next_count = parent_counts.get(name).unwrap_or(0)
    parent_counts.set(name, next_count + 1)
    stack[depth - 1].element_path +
    "/" +
    name +
    "[" +
    next_count.to_string() +
    "]"
  }
  (path, depth)
}

///|
fn xml_outline_frame_to_block(
  frame : XmlOutlineFrame,
  source : @input.InputSource,
  depth : Int,
) -> @core.CoreBlock {
  let label = if depth == 0 {
    "<" + frame.element_name + ">"
  } else if depth == 1 &&
    frame.attributes.length() == 0 &&
    frame.children.length() > 0 {
    "<" + frame.element_name + ">"
  } else if frame.attributes.length() == 0 &&
    frame.children.length() == 0 &&
    frame.text_values.length() > 0 {
    frame.element_name + ": " + frame.text_values.join(" ")
  } else {
    frame.element_name
  }
  let item = xml_list_item_block(label, frame.element_ref)
  for attr in frame.attributes {
    item.children.push(
      xml_list_item_block(
        "@" + attr.name + ": " + attr.value,
        xml_stream_attribute_source_ref(
          source,
          attr.span,
          frame.element_path + "/@" + attr.name,
        ),
      ),
    )
  }
  if frame.children.length() > 0 {
    let list = @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=frame.element_ref,
    )
    list.attrs.set("ordered", "false")
    for child in frame.children {
      list.children.push(child)
    }
    item.children.push(list)
  }
  item
}

///|
fn xml_outline_push_block(
  stack : Array[XmlOutlineFrame],
  roots : Array[@core.CoreBlock],
  block : @core.CoreBlock,
) -> Unit {
  if stack.length() == 0 {
    roots.push(block)
  } else {
    stack[stack.length() - 1].children.push(block)
  }
}

///|
fn xml_stream_element_source_ref(
  source : @input.InputSource,
  span : @dxml.XmlSourceSpan,
  path : String,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("xml"),
      Some(span.line_start),
      Some(span.line_end),
    ),
    xpath: Some(path),
  }
}

///|
fn xml_stream_attribute_source_ref(
  source : @input.InputSource,
  span : @dxml.XmlSourceSpan,
  path : String,
) -> @core.SourceRef {
  xml_stream_element_source_ref(source, span, path)
}

///|
fn xml_stream_summary(tokens : Array[@dxml.XmlToken]) -> XmlStreamSummary {
  let stack : Array[Bool] = []
  let child_element_seen : Array[Bool] = []
  let non_whitespace_text_before_child_seen : Array[Bool] = []
  let mut element_count = 0
  let mut attribute_count = 0
  let mut text_node_count = 0
  let mut comment_count = 0
  let mut cdata_count = 0
  let mut processing_instruction_count = 0
  let mut max_depth = 0
  let mut has_doctype = false
  let mut has_unsupported_doctype = false
  let mut has_complex_mixed_content = false
  let mut has_markdown_fence_text = false
  let mut has_default_namespace = false
  for token in tokens {
    match token {
      @dxml.XmlToken::Declaration(_, _) => ()
      @dxml.XmlToken::Doctype(text, _) => {
        has_doctype = true
        has_unsupported_doctype = true
        if text.contains("```") {
          has_markdown_fence_text = true
        }
      }
      @dxml.XmlToken::ProcessingInstruction(_, _, _) =>
        processing_instruction_count += 1
      @dxml.XmlToken::Comment(_, _) => comment_count += 1
      @dxml.XmlToken::CData(text, _) => {
        cdata_count += 1
        if text.trim() != "" {
          text_node_count += 1
          if stack.length() > 0 {
            let idx = stack.length() - 1
            if !child_element_seen[idx] {
              non_whitespace_text_before_child_seen[idx] = true
            }
          }
          if text.contains("```") {
            has_markdown_fence_text = true
          }
        }
      }
      @dxml.XmlToken::Text(text, _) =>
        if text.trim() != "" {
          text_node_count += 1
          if stack.length() > 0 {
            let idx = stack.length() - 1
            if !child_element_seen[idx] {
              non_whitespace_text_before_child_seen[idx] = true
            }
          }
          if text.contains("```") {
            has_markdown_fence_text = true
          }
        }
      @dxml.XmlToken::StartTag(_, attrs, self_closing, _) => {
        element_count += 1
        attribute_count += attrs.length()
        for attr in attrs {
          if attr.name == "xmlns" {
            has_default_namespace = true
          }
          if attr.value.contains("```") {
            has_markdown_fence_text = true
          }
        }
        if stack.length() > 0 {
          child_element_seen[stack.length() - 1] = true
        }
        let depth = stack.length() + 1
        if depth > max_depth {
          max_depth = depth
        }
        if !self_closing {
          stack.push(false)
          child_element_seen.push(false)
          non_whitespace_text_before_child_seen.push(false)
        }
      }
      @dxml.XmlToken::EndTag(_, _) =>
        if stack.length() > 0 {
          let has_child = child_element_seen.pop().unwrap_or(false)
          let has_text_before_child = non_whitespace_text_before_child_seen
            .pop()
            .unwrap_or(false)
          ignore(stack.pop())
          if has_child && has_text_before_child {
            has_complex_mixed_content = true
          }
        }
    }
  }
  {
    element_count,
    attribute_count,
    text_node_count,
    comment_count,
    cdata_count,
    processing_instruction_count,
    max_depth,
    has_doctype,
    has_unsupported_doctype,
    has_complex_mixed_content,
    has_markdown_fence_text,
    has_default_namespace,
  }
}

///|
fn xml_tokens_have_multiline_attribute_value(
  tokens : Array[@dxml.XmlToken],
) -> Bool {
  for token in tokens {
    match token {
      @dxml.XmlToken::StartTag(_, attrs, _, _) =>
        for attr in attrs {
          if attr.span.line_end > attr.span.line_start {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn xml_list_item_block(
  text : String,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let item = @core.make_block(@core.BlockKind::ListItem, text, source_ref~)
  item.attrs.set("ordered", "false")
  item.attrs.set("literal", "true")
  item
}

///|
fn xml_append_generic_block_events(
  out : Array[@core.CoreEvent],
  block : @core.CoreBlock,
) -> Unit {
  let source_ref = xml_generic_block_ref(
    block.source_ref.unwrap_or(@core.empty_source_ref()),
    block.kind,
    block.attrs.to_array(),
  )
  out.push({
    kind: @core.EventKind::StartBlock(block.kind),
    text: block.text,
    source_ref: Some(source_ref),
  })
  for child in block.children {
    xml_append_generic_block_events(out, child)
  }
  out.push({
    kind: @core.EventKind::EndBlock(block.kind),
    text: "",
    source_ref: Some(source_ref),
  })
}

///|
fn xml_generic_block_ref(
  source_ref : @core.SourceRef,
  kind : @core.BlockKind,
  attrs : Array[(String, String)],
) -> @core.SourceRef {
  let next = source_ref
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_block_kind", @core.block_kind_name(kind))
  for entry in attrs {
    next.extra.set("ir_block_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn count_xml_event_blocks(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    match event.kind {
      @core.EventKind::StartBlock(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn xml_requires_fail_closed_outline(
  doc : @dxml.XmlDocument,
  _text : String,
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
  xml_document_has_multiline_attribute_value(root) ||
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
fn xml_document_has_multiline_attribute_value(
  element : @dxml.XmlElement,
) -> Bool {
  for attr in element.attributes {
    if attr.span.line_end > attr.span.line_start {
      return true
    }
  }
  for child in element.children {
    match child {
      @dxml.XmlNode::Element(child_element) =>
        if xml_document_has_multiline_attribute_value(child_element) {
          return true
        }
      _ => ()
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
    Some(@fshared.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "xml_fail_closed")
  block.attrs.set("info", "xml")
  diagnostics.errors.push("xml parse failed: " + err.to_string())
  diagnostics.degraded_features.push("xml_fail_closed")
  diagnostics.fallback_trace.push("xml parse failed closed: " + info.detail)
  diagnostics.metrics.set("parser_name", "xml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set("input_kind", @fshared.input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "xml")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
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
    @fshared.bool_string(text.contains("<!DOCTYPE")),
  )
  diagnostics.metrics.set(
    "external_entity_seen",
    @fshared.bool_string(text.contains("SYSTEM")),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @fshared.bool_string(text.contains("<!ENTITY")),
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
    @fshared.count_physical_lines(text).to_string(),
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
    Some(@fshared.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "xml_fail_closed")
  block.attrs.set("info", "xml")
  diagnostics.warnings.push("xml parse warning: " + detail)
  diagnostics.degraded_features.push("xml_fail_closed")
  diagnostics.fallback_trace.push("xml fail closed: " + detail)
  diagnostics.metrics.set("parser_name", "xml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set("input_kind", @fshared.input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "xml")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
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
    @fshared.bool_string(text.contains("<!DOCTYPE")),
  )
  diagnostics.metrics.set(
    "external_entity_seen",
    @fshared.bool_string(text.contains("SYSTEM")),
  )
  diagnostics.metrics.set(
    "custom_entity_seen",
    @fshared.bool_string(text.contains("<!ENTITY") || text.contains("&")),
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
    @fshared.count_physical_lines(text).to_string(),
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
fn xml_doctype_contains_external_entity(doc : @dxml.XmlDocument) -> Bool {
  doc.has_unsupported_doctype
}
