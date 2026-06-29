///|
pub(all) enum XmlStructureScanStatus {
  Success
  ParseFailed
} derive(Eq)

///|
pub struct XmlStructureScan {
  status : XmlStructureScanStatus
  node_count : Int
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
  error_code : Int
}

///|
pub fn scan_xml_structure_bytes(xml_bytes : Bytes) -> XmlStructureScan {
  scan_xml_structure(xml_scan_decode_bytes(xml_bytes))
}

///|
pub fn scan_xml_structure(xml : String) -> XmlStructureScan {
  let tokens = try parse_xml_structure_tokens(xml) |> Ok catch {
    _ => Err(())
  }
  let parsed = try parse_xml_document(xml) |> Ok catch {
    _ => Err(())
  }
  match (tokens, parsed) {
    (Ok(xml_tokens), Ok(_)) => xml_structure_scan_from_tokens(xml_tokens)
    _ => empty_xml_structure_scan()
  }
}

///|
fn xml_structure_scan_from_tokens(tokens : Array[XmlToken]) -> XmlStructureScan {
  let stack : Array[Bool] = []
  let child_element_seen : Array[Bool] = []
  let non_whitespace_text_before_child_seen : Array[Bool] = []
  let mut node_count = 0
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
      XmlToken::Declaration(_, _) => ()
      XmlToken::Doctype(text, _) => {
        node_count += 1
        has_doctype = true
        has_unsupported_doctype = true
        if text.contains("```") {
          has_markdown_fence_text = true
        }
      }
      XmlToken::ProcessingInstruction(target, body, _) => {
        node_count += 1
        processing_instruction_count += 1
        if target.contains("```") || body.contains("```") {
          has_markdown_fence_text = true
        }
      }
      XmlToken::Comment(text, _) => {
        node_count += 1
        comment_count += 1
        if text.contains("```") {
          has_markdown_fence_text = true
        }
      }
      XmlToken::CData(text, _) => {
        cdata_count += 1
        if text.trim() != "" {
          node_count += 1
          text_node_count += 1
          if stack.length() > 0 {
            let index = stack.length() - 1
            if !child_element_seen[index] {
              non_whitespace_text_before_child_seen[index] = true
            }
          }
          if text.contains("```") {
            has_markdown_fence_text = true
          }
        }
      }
      XmlToken::Text(text, _) =>
        if text.trim() != "" {
          node_count += 1
          text_node_count += 1
          if stack.length() > 0 {
            let index = stack.length() - 1
            if !child_element_seen[index] {
              non_whitespace_text_before_child_seen[index] = true
            }
          }
          if text.contains("```") {
            has_markdown_fence_text = true
          }
        }
      XmlToken::StartTag(_, attrs, self_closing, _) => {
        node_count += 1 + attrs.length()
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
      XmlToken::EndTag(_, _) =>
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
    status: XmlStructureScanStatus::Success,
    node_count,
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
    error_code: 0,
  }
}

///|
fn empty_xml_structure_scan() -> XmlStructureScan {
  {
    status: XmlStructureScanStatus::ParseFailed,
    node_count: 0,
    element_count: 0,
    attribute_count: 0,
    text_node_count: 0,
    comment_count: 0,
    cdata_count: 0,
    processing_instruction_count: 0,
    max_depth: 0,
    has_doctype: false,
    has_unsupported_doctype: false,
    has_complex_mixed_content: false,
    has_markdown_fence_text: false,
    has_default_namespace: false,
    error_code: 0,
  }
}

///|
fn xml_scan_decode_bytes(xml_bytes : Bytes) -> String {
  @utf8.decode(xml_bytes, ignore_bom=false) catch {
    _ => {
      let chars : Array[Char] = []
      for b in xml_bytes {
        let value = b.to_int()
        chars.push(
          Int::unsafe_to_char(if value >= 0 { value } else { value + 256 }),
        )
      }
      String::from_array(chars)
    }
  }
}
