///|
pub fn collect_html_validation_issues(
  doc : HtmlDocument,
) -> Array[HtmlValidationIssue] {
  doc.issues
}

///|
pub fn validate_html_document(doc : HtmlDocument) -> HtmlValidationReport {
  let issues = collect_html_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0
  for issue in issues {
    match issue.severity {
      HtmlValidationSeverity::Warning => warning_count += 1
      HtmlValidationSeverity::Error => error_count += 1
    }
  }
  { issue_count: issues.length(), warning_count, error_count, issues }
}

///|
pub fn inspect_html_document(doc : HtmlDocument) -> HtmlInspectReport {
  let stats = HtmlInspectStats::{
    node_count: 0,
    element_count: 0,
    text_node_count: 0,
    comment_count: 0,
    doctype_count: 0,
    attribute_count: 0,
    link_element_count: 0,
    image_element_count: 0,
    heading_element_count: 0,
    table_element_count: 0,
    list_element_count: 0,
    form_element_count: 0,
    script_element_count: 0,
    style_element_count: 0,
    pre_element_count: 0,
    code_element_count: 0,
    max_depth: 0,
  }

  for node in doc.nodes {
    visit_html_node(node, stats, 1)
  }

  let validation = validate_html_document(doc)
  {
    node_count: stats.node_count,
    element_count: stats.element_count,
    text_node_count: stats.text_node_count,
    comment_count: stats.comment_count,
    doctype_count: stats.doctype_count,
    attribute_count: stats.attribute_count,
    link_element_count: stats.link_element_count,
    image_element_count: stats.image_element_count,
    heading_element_count: stats.heading_element_count,
    table_element_count: stats.table_element_count,
    list_element_count: stats.list_element_count,
    form_element_count: stats.form_element_count,
    script_element_count: stats.script_element_count,
    style_element_count: stats.style_element_count,
    pre_element_count: stats.pre_element_count,
    code_element_count: stats.code_element_count,
    max_depth: stats.max_depth,
    has_doctype: doc.has_doctype,
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
    is_empty: doc.nodes.length() == 0,
  }
}

///|
priv struct HtmlInspectStats {
  mut node_count : Int
  mut element_count : Int
  mut text_node_count : Int
  mut comment_count : Int
  mut doctype_count : Int
  mut attribute_count : Int
  mut link_element_count : Int
  mut image_element_count : Int
  mut heading_element_count : Int
  mut table_element_count : Int
  mut list_element_count : Int
  mut form_element_count : Int
  mut script_element_count : Int
  mut style_element_count : Int
  mut pre_element_count : Int
  mut code_element_count : Int
  mut max_depth : Int
}

///|
fn visit_html_node(
  node : HtmlNode,
  stats : HtmlInspectStats,
  depth : Int,
) -> Unit {
  stats.node_count += 1
  if depth > stats.max_depth {
    stats.max_depth = depth
  }

  match node {
    HtmlNode::Element(element) => {
      stats.element_count += 1
      stats.attribute_count += element.attributes.length()
      match element.tag_name {
        "a" => stats.link_element_count += 1
        "img" => stats.image_element_count += 1
        "table" => stats.table_element_count += 1
        "ul" | "ol" | "dl" => stats.list_element_count += 1
        "form" => stats.form_element_count += 1
        "script" => stats.script_element_count += 1
        "style" => stats.style_element_count += 1
        "pre" => stats.pre_element_count += 1
        "code" => stats.code_element_count += 1
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" =>
          stats.heading_element_count += 1
        _ => ()
      }
      for child in element.children {
        visit_html_node(child, stats, depth + 1)
      }
    }
    HtmlNode::Text(_) => stats.text_node_count += 1
    HtmlNode::Comment(_) => stats.comment_count += 1
    HtmlNode::Doctype(_) => stats.doctype_count += 1
  }
}
