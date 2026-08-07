///|
/// Parse XML text into a safe, source-native document model.
///
/// This parser does not perform DTD expansion, namespace semantic resolution,
/// or browser-style recovery.
pub fn parse_xml_document(text : String) -> XmlDocument raise {
  let tokens = tokenize_xml_document(text)
  let parser = XmlParser::{ tokens, pos: 0 }
  parser.parse_document(count_xml_source_chars(text))
}

///|
/// Tokenize XML and keep source-native structure tokens without constructing
/// the source-native document tree.
pub fn parse_xml_structure_tokens(text : String) -> Array[XmlToken] raise {
  tokenize_xml_document(text)
}

///|
fn count_xml_source_chars(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count += 1
  }
  count
}

///|
/// Classify a hard XML parse failure into a stable error kind.
pub fn classify_xml_error(err : XmlError) -> XmlErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unexpected end") ||
    detail.contains("unterminated") {
    XmlErrorKind::UnexpectedEOF
  } else if detail.contains("empty document") {
    EmptyDocument
  } else if detail.contains("expected name") {
    InvalidName
  } else if detail.contains("mismatched closing tag") {
    MismatchedTag
  } else if detail.contains("unexpected closing tag") {
    UnexpectedClosingTag
  } else if detail.contains("unclosed tag") {
    UnclosedTag
  } else if detail.contains("duplicate attribute") {
    DuplicateAttribute
  } else if detail.contains("doctype") {
    UnsupportedDoctype
  } else if detail.contains("unsupported entity") {
    UnsupportedEntity
  } else if detail.contains("entity ref") {
    MalformedEntity
  } else if detail.contains("multiple root elements") {
    MultipleRootElements
  } else if detail.contains("malformed") ||
    detail.contains("invalid") ||
    detail.contains("unquoted attribute value") ||
    detail.contains("missing attribute value") {
    InvalidToken
  } else {
    Unknown
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
      Declaration(_, _) => self.pos += 1
      Doctype(_, _) => {
        has_doctype = true
        has_unsupported_doctype = true
        self.pos += 1
      }
      ProcessingInstruction(target, body, span) => {
        nodes.push(ProcessingInstruction({ target, body, span }))
        self.pos += 1
      }
      Comment(text, span) => {
        nodes.push(Comment({ text, span }))
        self.pos += 1
      }
      Text(text, span) => {
        if text.trim() != "" {
          if root is Some(_) {
            raise ParseError("multiple root elements")
          }
          nodes.push(Text({ text, span }))
        }
        self.pos += 1
      }
      CData(text, span) => {
        if root is Some(_) {
          raise ParseError("multiple root elements")
        }
        nodes.push(CData({ text, span }))
        self.pos += 1
      }
      StartTag(_, _, _, _) => {
        let element = self.parse_element()
        if root is Some(_) {
          raise ParseError("multiple root elements")
        }
        root = Some(element)
        nodes.push(Element(element))
      }
      EndTag(_, _) =>
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
    StartTag(name, attrs, self_closing, span) => {
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
      EndTag(end_name, end_span) => {
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
      StartTag(_, _, _, _) => children.push(Element(self.parse_element()))
      Text(text, text_span) => {
        children.push(Text({ text, span: text_span }))
        self.pos += 1
      }
      Comment(text, comment_span) => {
        children.push(Comment({ text, span: comment_span }))
        self.pos += 1
      }
      CData(text, cdata_span) => {
        children.push(CData({ text, span: cdata_span }))
        self.pos += 1
      }
      ProcessingInstruction(target, body, pi_span) => {
        children.push(ProcessingInstruction({ target, body, span: pi_span }))
        self.pos += 1
      }
      Declaration(_, _) =>
        raise ParseError(
          "xml declaration is only allowed before the root element",
        )
      Doctype(_, _) =>
        raise ParseError("doctype is unsupported inside the document body")
    }
  }

  raise ParseError("unclosed tag: " + name)
}
