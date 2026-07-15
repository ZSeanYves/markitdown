///|
/// Parse HTML text into a tolerant, source-native DOM-ish model.
///
/// This parser does not execute scripts, fetch remote resources, or apply CSS.
pub fn parse_html_document(text : String) -> HtmlDocument raise {
  let normalized = normalize_html_source(text)
  let tokens = tokenize_normalized_html_document(normalized)
  let parser = HtmlParser::{ tokens, pos: 0 }
  parser.parse_document(count_html_source_chars(normalized))
}

///|
pub fn analyze_html_source(text : String) -> HtmlSourceAnalysis raise {
  let normalized = normalize_html_source(text)
  let scan = tokenize_normalized_html_event_scan(normalized)
  let parser = HtmlParser::{ tokens: scan.tokens, pos: 0 }
  {
    document: parser.parse_document(count_html_source_chars(normalized)),
    events: scan.events,
  }
}

///|
fn count_html_source_chars(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count += 1
  }
  count
}

///|
/// Classify a hard HTML parse failure into a stable error kind.
pub fn classify_html_error(err : HtmlError) -> HtmlErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unterminated comment") {
    HtmlErrorKind::UnterminatedComment
  } else if detail.contains("unterminated attribute value") ||
    detail.contains("missing attribute value") ||
    detail.contains("malformed attribute") {
    MalformedAttribute
  } else if detail.contains("unterminated start tag") ||
    detail.contains("unterminated end tag") ||
    detail.contains("unterminated self-closing tag") ||
    detail.contains("unterminated raw-text closing tag") ||
    detail.contains("unterminated doctype") {
    UnterminatedTag
  } else if detail.contains("unexpected eof") {
    UnexpectedEOF
  } else if detail.contains("expected name") {
    InvalidName
  } else if detail.contains("invalid") || detail.contains("malformed") {
    InvalidToken
  } else {
    Unknown
  }
  { kind, detail: err.to_string() }
}

///|
priv struct HtmlParser {
  tokens : Array[HtmlToken]
  mut pos : Int
}

///|
fn HtmlParser::parse_document(
  self : HtmlParser,
  source_length : Int,
) -> HtmlDocument {
  let nodes : Array[HtmlNode] = []
  let issues : Array[HtmlValidationIssue] = []
  let stack : Array[HtmlElement] = []
  let mut has_doctype = false

  fn push_node(
    nodes : Array[HtmlNode],
    stack : Array[HtmlElement],
    node : HtmlNode,
  ) -> Unit {
    if stack.length() > 0 {
      stack[stack.length() - 1].children.push(node)
    } else {
      nodes.push(node)
    }
  }

  while self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      Text(text, span) => {
        if stack.length() > 0 || text.trim() != "" {
          push_node(nodes, stack, Text({ text, span }))
        }
        self.pos += 1
      }
      Comment(text, span) => {
        push_node(nodes, stack, Comment({ text, span }))
        self.pos += 1
      }
      Doctype(text, span) => {
        has_doctype = true
        push_node(nodes, stack, Doctype({ text, span }))
        self.pos += 1
      }
      StartTag(tag_name, attributes, explicit_self_closing, span) => {
        let duplicate = collect_duplicate_attribute_names(attributes)
        for attr_name in duplicate {
          issues.push({
            kind: DuplicateAttribute,
            severity: Warning,
            line_start: Some(span.line_start),
            line_end: Some(span.line_end),
            tag_name: Some(tag_name),
            message: "duplicate attribute on <" + tag_name + ">: " + attr_name,
          })
        }

        for attr in attributes {
          if is_html_url_attribute(attr.name) {
            match classify_html_unsafe_url(attr.value) {
              Some(reason) =>
                issues.push({
                  kind: UnsafeUrl,
                  severity: Warning,
                  line_start: Some(attr.span.line_start),
                  line_end: Some(attr.span.line_end),
                  tag_name: Some(tag_name),
                  message: reason,
                })
              None => ()
            }
          }
        }

        if tag_name == "script" {
          issues.push({
            kind: ScriptElement,
            severity: Warning,
            line_start: Some(span.line_start),
            line_end: Some(span.line_end),
            tag_name: Some(tag_name),
            message: "script element is preserved as raw content and never executed",
          })
        }
        if tag_name == "style" {
          issues.push({
            kind: StyleElement,
            severity: Warning,
            line_start: Some(span.line_start),
            line_end: Some(span.line_end),
            tag_name: Some(tag_name),
            message: "style element is preserved as raw content and never rendered",
          })
        }

        let self_closing = explicit_self_closing ||
          is_html_void_element(tag_name)
        let element : HtmlElement = {
          tag_name,
          attributes,
          children: [],
          self_closing,
          span,
        }

        self.pos += 1

        if self_closing {
          push_node(nodes, stack, Element(element))
        } else {
          stack.push(element)
        }
      }
      EndTag(tag_name, span) => {
        self.pos += 1
        match close_html_element(stack, tag_name, issues, span) {
          Some(closed) => {
            let finished = {
              tag_name: closed.tag_name,
              attributes: closed.attributes,
              children: closed.children,
              self_closing: false,
              span: {
                line_start: closed.span.line_start,
                line_end: span.line_end,
                byte_start: closed.span.byte_start,
                byte_end: span.byte_end,
              },
            }
            push_node(nodes, stack, Element(finished))
          }
          None =>
            issues.push({
              kind: UnexpectedClosingTag,
              severity: Warning,
              line_start: Some(span.line_start),
              line_end: Some(span.line_end),
              tag_name: Some(tag_name),
              message: "unexpected closing tag: </" + tag_name + ">",
            })
        }
      }
    }
  }

  while stack.length() > 0 {
    match stack.pop() {
      Some(element) => {
        issues.push({
          kind: UnclosedElement,
          severity: Warning,
          line_start: Some(element.span.line_start),
          line_end: Some(element.span.line_end),
          tag_name: Some(element.tag_name),
          message: "unclosed element: <" + element.tag_name + ">",
        })
        push_node(
          nodes,
          stack,
          Element({
            tag_name: element.tag_name,
            attributes: element.attributes,
            children: element.children,
            self_closing: false,
            span: {
              line_start: element.span.line_start,
              line_end: element.span.line_end,
              byte_start: element.span.byte_start,
              byte_end: element.span.byte_end,
            },
          }),
        )
      }
      None => ()
    }
  }

  if nodes.length() == 0 {
    issues.push({
      kind: EmptyDocument,
      severity: Warning,
      line_start: None,
      line_end: None,
      tag_name: None,
      message: "document is empty",
    })
  }

  { nodes, source_length, has_doctype, issues }
}

///|
fn close_html_element(
  stack : Array[HtmlElement],
  tag_name : String,
  issues : Array[HtmlValidationIssue],
  end_span : HtmlSourceSpan,
) -> HtmlElement? {
  let mut matched_index = -1
  for i in 0..<stack.length() {
    let idx = stack.length() - 1 - i
    if stack[idx].tag_name == tag_name {
      matched_index = idx
      break
    }
  }

  if matched_index < 0 {
    return None
  }

  while stack.length() > matched_index + 1 {
    match stack.pop() {
      Some(unclosed) => {
        issues.push({
          kind: UnclosedElement,
          severity: Warning,
          line_start: Some(unclosed.span.line_start),
          line_end: Some(end_span.line_start),
          tag_name: Some(unclosed.tag_name),
          message: "unclosed element: <" + unclosed.tag_name + ">",
        })
        let repaired = HtmlNode::Element({
          tag_name: unclosed.tag_name,
          attributes: unclosed.attributes,
          children: unclosed.children,
          self_closing: false,
          span: {
            line_start: unclosed.span.line_start,
            line_end: end_span.line_start,
            byte_start: unclosed.span.byte_start,
            byte_end: end_span.byte_start,
          },
        })
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(repaired)
        }
      }
      None => ()
    }
  }

  match stack.pop() {
    Some(element) => Some(element)
    None => None
  }
}

///|
fn collect_duplicate_attribute_names(
  attrs : Array[HtmlAttribute],
) -> Array[String] {
  let duplicates : Array[String] = []
  let seen : Array[String] = []
  for attr in attrs {
    let mut exists = false
    for prev in seen {
      if prev == attr.name {
        exists = true
        break
      }
    }
    if exists {
      let mut already_reported = false
      for name in duplicates {
        if name == attr.name {
          already_reported = true
          break
        }
      }
      if !already_reported {
        duplicates.push(attr.name)
      }
    } else {
      seen.push(attr.name)
    }
  }
  duplicates
}

///|
fn is_html_url_attribute(name : String) -> Bool {
  name == "href" ||
  name == "src" ||
  name == "poster" ||
  name == "action" ||
  name == "formaction"
}

///|
fn classify_html_unsafe_url(raw : String) -> String? {
  let trimmed = raw.trim().to_lower()
  if trimmed == "" {
    return None
  }
  if trimmed.has_prefix("javascript:") {
    return Some("unsafe url uses javascript: scheme")
  }
  if trimmed.has_prefix("vbscript:") {
    return Some("unsafe url uses vbscript: scheme")
  }
  if trimmed.has_prefix("data:") {
    return Some("unsafe url uses data: scheme")
  }
  None
}

///|
fn is_html_void_element(tag_name : String) -> Bool {
  tag_name == "area" ||
  tag_name == "base" ||
  tag_name == "br" ||
  tag_name == "col" ||
  tag_name == "embed" ||
  tag_name == "hr" ||
  tag_name == "img" ||
  tag_name == "input" ||
  tag_name == "link" ||
  tag_name == "meta" ||
  tag_name == "param" ||
  tag_name == "source" ||
  tag_name == "track" ||
  tag_name == "wbr"
}
