///|
/// Return XML validation issues surfaced after a successful parse.
pub fn collect_xml_validation_issues(
  doc : XmlDocument,
) -> Array[XmlValidationIssue] {
  let issues : Array[XmlValidationIssue] = []

  if doc.has_unsupported_doctype {
    issues.push({
      kind: UnsupportedDoctype,
      severity: Warning,
      line_start: None,
      line_end: None,
      message: "doctype is preserved as unsupported syntax and never fetched or expanded",
    })
  }

  let root_count = count_root_elements(doc.nodes)
  if root_count > 1 {
    issues.push({
      kind: MultipleRootElements,
      severity: Error,
      line_start: None,
      line_end: None,
      message: "document has multiple root elements",
    })
  }

  let has_non_empty_node = doc.nodes.length() > 0
  if !has_non_empty_node {
    issues.push({
      kind: EmptyDocument,
      severity: Warning,
      line_start: None,
      line_end: None,
      message: "document is empty",
    })
  }

  issues
}

///|
/// Aggregate XML validation counts and issues into a deterministic report.
pub fn validate_xml_document(doc : XmlDocument) -> XmlValidationReport {
  let issues = collect_xml_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0

  for issue in issues {
    match issue.severity {
      Warning => warning_count += 1
      Error => error_count += 1
    }
  }

  { issue_count: issues.length(), warning_count, error_count, issues }
}

///|
/// Summarize structure for a parsed XML document.
pub fn inspect_xml_document(doc : XmlDocument) -> XmlInspectReport {
  let stats = XmlInspectStats::{
    node_count: 0,
    element_count: 0,
    attribute_count: 0,
    text_node_count: 0,
    comment_count: 0,
    cdata_count: 0,
    processing_instruction_count: 0,
    max_depth: 0,
  }

  for node in doc.nodes {
    visit_xml_node(node, stats, 1)
  }

  let validation = validate_xml_document(doc)
  {
    node_count: stats.node_count,
    element_count: stats.element_count,
    attribute_count: stats.attribute_count,
    text_node_count: stats.text_node_count,
    comment_count: stats.comment_count,
    cdata_count: stats.cdata_count,
    processing_instruction_count: stats.processing_instruction_count,
    max_depth: stats.max_depth,
    has_doctype: doc.has_doctype,
    has_unsupported_doctype: doc.has_unsupported_doctype,
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
    is_empty: doc.nodes.length() == 0,
  }
}

///|
priv struct XmlInspectStats {
  mut node_count : Int
  mut element_count : Int
  mut attribute_count : Int
  mut text_node_count : Int
  mut comment_count : Int
  mut cdata_count : Int
  mut processing_instruction_count : Int
  mut max_depth : Int
}

///|
fn visit_xml_node(node : XmlNode, stats : XmlInspectStats, depth : Int) -> Unit {
  stats.node_count += 1
  if depth > stats.max_depth {
    stats.max_depth = depth
  }

  match node {
    Element(element) => {
      stats.element_count += 1
      stats.attribute_count += element.attributes.length()
      for child in element.children {
        visit_xml_node(child, stats, depth + 1)
      }
    }
    Text(_) => stats.text_node_count += 1
    Comment(_) => stats.comment_count += 1
    ProcessingInstruction(_) => stats.processing_instruction_count += 1
    CData(_) => stats.cdata_count += 1
  }
}

///|
fn count_root_elements(nodes : Array[XmlNode]) -> Int {
  let mut count = 0
  for node in nodes {
    match node {
      Element(_) => count += 1
      _ => ()
    }
  }
  count
}
