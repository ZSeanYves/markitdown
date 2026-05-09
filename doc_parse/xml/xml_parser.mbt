///|
pub fn parse_xml_document(text : String) -> XmlDocument raise {
  let tokens = tokenize_xml_document(text)
  let parser = XmlParser::{ tokens, pos: 0 }
  parser.parse_document(text.to_array().length())
}

///|
pub fn classify_xml_error(err : XmlError) -> XmlErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unexpected end") ||
    detail.contains("unterminated") {
    XmlErrorKind::UnexpectedEOF
  } else if detail.contains("empty document") {
    XmlErrorKind::EmptyDocument
  } else if detail.contains("expected name") {
    XmlErrorKind::InvalidName
  } else if detail.contains("mismatched closing tag") {
    XmlErrorKind::MismatchedTag
  } else if detail.contains("unexpected closing tag") {
    XmlErrorKind::UnexpectedClosingTag
  } else if detail.contains("unclosed tag") {
    XmlErrorKind::UnclosedTag
  } else if detail.contains("duplicate attribute") {
    XmlErrorKind::DuplicateAttribute
  } else if detail.contains("doctype") {
    XmlErrorKind::UnsupportedDoctype
  } else if detail.contains("unsupported entity") {
    XmlErrorKind::UnsupportedEntity
  } else if detail.contains("entity ref") {
    XmlErrorKind::MalformedEntity
  } else if detail.contains("multiple root elements") {
    XmlErrorKind::MultipleRootElements
  } else if detail.contains("malformed") ||
    detail.contains("invalid") ||
    detail.contains("unquoted attribute value") ||
    detail.contains("missing attribute value") {
    XmlErrorKind::InvalidToken
  } else {
    XmlErrorKind::Unknown
  }
  { kind, detail: err.to_string() }
}

///|
priv struct XmlParser {
  tokens : Array[XmlToken]
  mut pos : Int
}

///|
fn XmlParser::parse_document(
  self : XmlParser,
  source_length : Int,
) -> XmlDocument raise {
  let nodes : Array[XmlNode] = []
  let mut root : XmlElement? = None
  let mut has_doctype = false
  let mut has_unsupported_doctype = false

  while self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XmlToken::Declaration(_, _) => self.pos += 1
      XmlToken::Doctype(_, _) => {
        has_doctype = true
        has_unsupported_doctype = true
        self.pos += 1
      }
      XmlToken::ProcessingInstruction(target, body, span) => {
        nodes.push(XmlNode::ProcessingInstruction({ target, body, span }))
        self.pos += 1
      }
      XmlToken::Comment(text, span) => {
        nodes.push(XmlNode::Comment({ text, span }))
        self.pos += 1
      }
      XmlToken::Text(text, span) => {
        if text.trim() != "" {
          if root is Some(_) {
            raise ParseError("multiple root elements")
          }
          nodes.push(XmlNode::Text({ text, span }))
        }
        self.pos += 1
      }
      XmlToken::CData(text, span) => {
        if root is Some(_) {
          raise ParseError("multiple root elements")
        }
        nodes.push(XmlNode::CData({ text, span }))
        self.pos += 1
      }
      XmlToken::StartTag(_, _, _, _) => {
        let element = self.parse_element()
        if root is Some(_) {
          raise ParseError("multiple root elements")
        }
        root = Some(element)
        nodes.push(XmlNode::Element(element))
      }
      XmlToken::EndTag(_, _) =>
        raise ParseError("unexpected closing tag at document level")
    }
  }

  if nodes.length() == 0 {
    raise ParseError("empty document")
  }

  { nodes, root, source_length, has_doctype, has_unsupported_doctype }
}

///|
fn XmlParser::parse_element(self : XmlParser) -> XmlElement raise {
  let (name, attributes, self_closing, span) = match self.tokens[self.pos] {
    XmlToken::StartTag(name, attrs, self_closing, span) => {
      self.pos += 1
      (name, attrs, self_closing, span)
    }
    _ => raise ParseError("expected start tag")
  }

  if self_closing {
    return { name, attributes, children: [], self_closing, span }
  }

  let children : Array[XmlNode] = []
  let mut line_end = span.line_end

  while self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XmlToken::EndTag(end_name, end_span) => {
        if end_name != name {
          raise ParseError(
            "mismatched closing tag: expected </" +
            name +
            "> but found </" +
            end_name +
            ">",
          )
        }
        self.pos += 1
        line_end = end_span.line_end
        return {
          name,
          attributes,
          children,
          self_closing,
          span: { line_start: span.line_start, line_end },
        }
      }
      XmlToken::StartTag(_, _, _, _) =>
        children.push(XmlNode::Element(self.parse_element()))
      XmlToken::Text(text, text_span) => {
        children.push(XmlNode::Text({ text, span: text_span }))
        self.pos += 1
      }
      XmlToken::Comment(text, comment_span) => {
        children.push(XmlNode::Comment({ text, span: comment_span }))
        self.pos += 1
      }
      XmlToken::CData(text, cdata_span) => {
        children.push(XmlNode::CData({ text, span: cdata_span }))
        self.pos += 1
      }
      XmlToken::ProcessingInstruction(target, body, pi_span) => {
        children.push(
          XmlNode::ProcessingInstruction({ target, body, span: pi_span }),
        )
        self.pos += 1
      }
      XmlToken::Declaration(_, _) =>
        raise ParseError(
          "xml declaration is only allowed before the root element",
        )
      XmlToken::Doctype(_, _) =>
        raise ParseError("doctype is unsupported inside the document body")
    }
  }

  raise ParseError("unclosed tag: " + name)
}
