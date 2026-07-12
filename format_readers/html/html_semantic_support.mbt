///|
fn html_semantic_map_push_string(
  map : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  match map.get(key) {
    Some(existing) => existing.push(value)
    None => map.set(key, [value])
  }
}

///|
fn html_semantic_note_marker(children : Array[HtmlNode]) -> String? {
  let preview = html_semantic_text_preview(children).0
  let trimmed = preview.trim().to_owned()
  if trimmed == "" {
    None
  } else if trimmed.length() <= 12 {
    Some(trimmed)
  } else {
    Some(trimmed[0:12].to_owned())
  }
}

///|
fn html_semantic_noise_candidate_reasons(
  element : HtmlElement,
) -> Array[HtmlNoiseCandidateReason] {
  let reasons : Array[HtmlNoiseCandidateReason] = []
  if element.tag_name == "nav" ||
    html_semantic_attr_token_contains(element.attributes, "role", "navigation") ||
    html_semantic_attr_token_contains(element.attributes, "class", "nav") ||
    html_semantic_attr_token_contains(element.attributes, "class", "menu") {
    reasons.push(HtmlNoiseCandidateReason::NavLike)
  }
  if element.tag_name == "footer" ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "footer",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "copyright",
    ) {
    reasons.push(HtmlNoiseCandidateReason::FooterLike)
  }
  if element.tag_name == "aside" ||
    html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "complementary",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "sidebar",
    ) ||
    html_semantic_attr_token_contains(element.attributes, "class", "toc") ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "infobox",
    ) {
    reasons.push(HtmlNoiseCandidateReason::SidebarLike)
  }
  if html_semantic_has_attr(element.attributes, "hidden") ||
    html_semantic_attr_token_contains(element.attributes, "aria-hidden", "true") ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["style"],
      "display:none",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["style"],
      "visibility:hidden",
    ) {
    reasons.push(HtmlNoiseCandidateReason::Hiddenish)
  }
  if element.tag_name == "script" ||
    element.tag_name == "style" ||
    element.tag_name == "template" {
    reasons.push(HtmlNoiseCandidateReason::ScriptStyleTemplate)
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "boilerplate",
    ) {
    reasons.push(HtmlNoiseCandidateReason::RepeatedBoilerplate)
  }
  reasons
}

///|
fn html_semantic_noise_confidence(
  element : HtmlElement,
  reasons : Array[HtmlNoiseCandidateReason],
) -> HtmlNoiseCandidateConfidence {
  if element.tag_name == "nav" ||
    element.tag_name == "footer" ||
    element.tag_name == "script" ||
    element.tag_name == "style" ||
    element.tag_name == "template" {
    return HtmlNoiseCandidateConfidence::High
  }
  if reasons.length() > 1 {
    HtmlNoiseCandidateConfidence::High
  } else {
    HtmlNoiseCandidateConfidence::Medium
  }
}

///|
fn html_semantic_noise_candidate_keys(
  facts : Array[HtmlNoiseCandidateFact],
) -> Array[String] {
  let out : Array[String] = []
  for fact in facts {
    out.push(fact.source_key)
  }
  out
}

///|
fn html_semantic_first_source_key(first : String?, second : String?) -> String? {
  match first {
    Some(value) => Some(value)
    None => second
  }
}

///|
fn html_semantic_source_key(tag_name : String, source_order : Int) -> String {
  "html:block:" + tag_name + ":" + source_order.to_string()
}

///|
fn html_semantic_inline_source_key(
  tag_name : String,
  source_order : Int,
) -> String {
  "html:inline:" + tag_name + ":" + source_order.to_string()
}

///|
fn html_semantic_list_source_key(source_order : Int) -> String {
  "html:list:" + source_order.to_string()
}

///|
fn html_semantic_list_item_source_key(source_order : Int) -> String {
  "html:list-item:" + source_order.to_string()
}

///|
fn html_semantic_blockquote_source_key(source_order : Int) -> String {
  "html:blockquote:" + source_order.to_string()
}

///|
fn html_semantic_attribute_summary(
  element : HtmlElement,
  source_key : String,
) -> (Array[HtmlSemanticAttributeSummary], Array[HtmlSemanticWarning]) {
  let out : Array[HtmlSemanticAttributeSummary] = []
  let warnings : Array[HtmlSemanticWarning] = []
  let mut i = 0
  for attr in element.attributes {
    if i >= HTML_SEMANTIC_ATTR_MAX_COUNT {
      warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::AttributeSummaryTruncated,
          source_key,
          element.tag_name,
          "html semantic attribute summary truncated for <" +
          element.tag_name +
          ">",
        ),
      )
      break
    }
    let (value_preview, truncated) = bounded_html_semantic_preview(
      attr.value,
      HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
    )
    if truncated {
      warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::AttributeValuePreviewTruncated,
          source_key,
          element.tag_name,
          "html semantic attribute value preview truncated for <" +
          element.tag_name +
          ">",
        ),
      )
    }
    out.push({
      name: attr.name,
      value_preview,
      quote_style: attr.quote_style,
      span: attr.span,
    })
    i += 1
  }
  (out, warnings)
}

///|
fn html_semantic_attr_value(
  attrs : Array[HtmlAttribute],
  name : String,
) -> String? {
  for attr in attrs {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn html_semantic_has_attr(attrs : Array[HtmlAttribute], name : String) -> Bool {
  for attr in attrs {
    if attr.name == name {
      return true
    }
  }
  false
}

///|
fn html_semantic_attr_preview_complete(
  attrs : Array[HtmlAttribute],
  name : String,
) -> Bool {
  match html_semantic_attr_value(attrs, name) {
    Some(value) =>
      value.trim().length() <= HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS
    None => true
  }
}

///|
fn html_semantic_attr_token_contains(
  attrs : Array[HtmlAttribute],
  name : String,
  token : String,
) -> Bool {
  match html_semantic_attr_value(attrs, name) {
    Some(value) => html_semantic_text_has_token(value, token)
    None => false
  }
}

///|
fn html_semantic_attr_any_contains(
  attrs : Array[HtmlAttribute],
  names : Array[String],
  needle : String,
) -> Bool {
  for name in names {
    match html_semantic_attr_value(attrs, name) {
      Some(value) => if value.to_lower().contains(needle) { return true }
      None => ()
    }
  }
  false
}

///|
fn html_semantic_text_has_token(value : String, token : String) -> Bool {
  let lower_token = token.to_lower()
  for raw in value.to_lower().split(" ") {
    let trimmed = raw.trim().to_owned()
    if trimmed == lower_token || trimmed.contains(lower_token) {
      return true
    }
  }
  false
}

///|
fn html_semantic_optional_bounded_attr(
  attrs : Array[HtmlAttribute],
  name : String,
) -> String? {
  match html_semantic_attr_value(attrs, name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(
          bounded_html_semantic_preview(
            trimmed,
            HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
          ).0,
        )
      }
    }
    None => None
  }
}

///|
fn classify_html_semantic_link_kind(href : String) -> HtmlLinkKind {
  let trimmed = href.trim().to_owned()
  if trimmed == "" {
    return HtmlLinkKind::Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return HtmlLinkKind::Unsafe
  }
  if lower.has_prefix("data:") {
    return HtmlLinkKind::Data
  }
  if lower.has_prefix("#") || lower.has_prefix("/") {
    return HtmlLinkKind::Internal
  }
  if lower.has_prefix("mailto:") {
    return HtmlLinkKind::Mailto
  }
  if lower.has_prefix("tel:") {
    return HtmlLinkKind::Tel
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return HtmlLinkKind::External
  }
  HtmlLinkKind::Unknown
}

///|
fn classify_html_semantic_image_kind(src : String) -> HtmlImageKind {
  let trimmed = src.trim().to_owned()
  if trimmed == "" {
    return HtmlImageKind::Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return HtmlImageKind::Unsafe
  }
  if lower.has_prefix("data:") {
    return HtmlImageKind::DataUri
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return HtmlImageKind::Remote
  }
  if lower.has_prefix("/") {
    return HtmlImageKind::Unknown
  }
  HtmlImageKind::Local
}

///|
fn bounded_html_semantic_url(value : String) -> String {
  bounded_html_semantic_preview(
    value.trim().to_owned(),
    HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
  ).0
}

///|
fn html_semantic_url_fact_value(href : String, kind : HtmlLinkKind) -> String {
  let trimmed = href.trim().to_owned()
  match kind {
    HtmlLinkKind::Unsafe | HtmlLinkKind::Data =>
      bounded_html_semantic_url(trimmed)
    _ => trimmed
  }
}

///|
fn html_semantic_image_src_fact_value(
  src : String,
  kind : HtmlImageKind,
) -> String {
  let trimmed = src.trim().to_owned()
  match kind {
    HtmlImageKind::DataUri | HtmlImageKind::Unsafe =>
      bounded_html_semantic_url(trimmed)
    _ => trimmed
  }
}

///|
fn push_html_semantic_warnings(
  ctx : HtmlSemanticCollectCtx,
  warnings : Array[HtmlSemanticWarning],
) -> Unit {
  for warning in warnings {
    ctx.warnings.push(warning)
  }
}

///|
fn new_html_semantic_warning(
  kind : HtmlSemanticWarningKind,
  source_key : String,
  tag_name : String,
  message : String,
) -> HtmlSemanticWarning {
  {
    kind,
    severity: html_semantic_warning_kind_severity(kind),
    source_key,
    tag_name,
    message,
  }
}

///|
fn html_semantic_warning_kind_severity(
  kind : HtmlSemanticWarningKind,
) -> HtmlWarningSeverity {
  match kind {
    HtmlSemanticWarningKind::TextPreviewTruncated => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::EmptyUrl => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::EmptyImageSource => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::RemoteImage => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::AttributeSummaryTruncated =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::AttributeValuePreviewTruncated =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::UnsupportedElement => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DepthLimitExceeded => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::UnsafeUrl => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DataUriImage => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::TableSizeLimitExceeded =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MalformedTableStructure =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::BrokenNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MissingNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DuplicateNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MalformedDocumentScope =>
      HtmlWarningSeverity::Warning
  }
}

///|
fn push_html_semantic_unsupported_fact(
  ctx : HtmlSemanticCollectCtx,
  kind : HtmlUnsupportedKind,
  severity : HtmlWarningSeverity,
  related_source_key : String?,
  tag_name : String,
  source_order : Int,
  depth : Int,
  parent_source_key : String?,
  text_preview : String,
  attributes : Array[HtmlSemanticAttributeSummary],
  url : String?,
  span : HtmlSourceSpan,
  message : String,
) -> String {
  ctx.next_unsupported_order += 1
  let source_key = "html:unsupported:" + ctx.next_unsupported_order.to_string()
  ctx.unsupported.push({
    kind,
    severity,
    source_key,
    related_source_key,
    tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_source_key,
    text_preview: bounded_html_semantic_preview(
      text_preview,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    attributes,
    url,
    span,
    message,
  })
  source_key
}

///|
fn push_html_semantic_guard_unsupported_facts(
  ctx : HtmlSemanticCollectCtx,
  warnings : Array[HtmlSemanticWarning],
  related_source_key : String,
  tag_name : String,
  source_order : Int,
  depth : Int,
  parent_source_key : String?,
  text_preview : String,
  attributes : Array[HtmlSemanticAttributeSummary],
  span : HtmlSourceSpan,
) -> Unit {
  for warning in warnings {
    match html_semantic_guard_unsupported_kind(warning.kind) {
      Some(kind) =>
        ignore(
          push_html_semantic_unsupported_fact(
            ctx,
            kind,
            warning.severity,
            Some(related_source_key),
            tag_name,
            source_order,
            depth,
            parent_source_key,
            text_preview,
            attributes,
            None,
            span,
            warning.message,
          ),
        )
      None => ()
    }
  }
}

///|
fn html_semantic_guard_unsupported_kind(
  kind : HtmlSemanticWarningKind,
) -> HtmlUnsupportedKind? {
  match kind {
    HtmlSemanticWarningKind::TextPreviewTruncated =>
      Some(HtmlUnsupportedKind::HugeTextNode)
    HtmlSemanticWarningKind::AttributeSummaryTruncated
    | HtmlSemanticWarningKind::AttributeValuePreviewTruncated =>
      Some(HtmlUnsupportedKind::HugeAttributeValue)
    HtmlSemanticWarningKind::DepthLimitExceeded =>
      Some(HtmlUnsupportedKind::DeepNesting)
    _ => None
  }
}

///|
fn clamp_html_semantic_depth(depth : Int) -> Int {
  if depth > HTML_SEMANTIC_MAX_DEPTH {
    HTML_SEMANTIC_MAX_DEPTH
  } else {
    depth
  }
}

///|
fn html_semantic_text_preview(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (normalize_html_semantic_preview(String::from_array(out)), truncated)
}

///|
fn html_semantic_whitespace_text_preview(
  children : Array[HtmlNode],
) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (String::from_array(out), truncated)
}

///|
fn html_semantic_raw_text_preview(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (String::from_array(out), truncated)
}

///|
fn html_semantic_container_has_direct_text(children : Array[HtmlNode]) -> Bool {
  for child in children {
    match child {
      HtmlNode::Text(text) => if text.text.trim() != "" { return true }
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_code_text(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_code_text(
        child,
        out,
        HTML_SEMANTIC_CODE_TEXT_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (
    String::from_array(out)
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .trim()
    .to_owned(),
    truncated,
  )
}

///|
fn append_html_semantic_code_text(
  node : HtmlNode,
  out : Array[Char],
  max_chars : Int,
) -> Bool {
  if out.length() >= max_chars {
    return true
  }
  match node {
    HtmlNode::Text(text) =>
      append_html_semantic_preview_chars(out, text.text, max_chars)
    HtmlNode::Comment(comment) =>
      append_html_semantic_preview_chars(out, comment.text, max_chars)
    HtmlNode::Element(element) => {
      for child in element.children {
        if append_html_semantic_code_text(child, out, max_chars) {
          return true
        }
      }
      false
    }
    HtmlNode::Doctype(_) => false
  }
}

///|
fn append_html_semantic_text_preview(
  node : HtmlNode,
  out : Array[Char],
  max_chars : Int,
) -> Bool {
  if out.length() >= max_chars {
    return true
  }
  match node {
    HtmlNode::Text(text) =>
      append_html_semantic_preview_chars(out, text.text, max_chars)
    HtmlNode::Element(element) => {
      for child in element.children {
        if append_html_semantic_text_preview(child, out, max_chars) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn append_html_semantic_preview_chars(
  out : Array[Char],
  text : String,
  max_chars : Int,
) -> Bool {
  for ch in text {
    if out.length() >= max_chars {
      return true
    }
    out.push(ch)
  }
  false
}

///|
fn html_semantic_child_has_adjacent_text(
  children : Array[HtmlNode],
  index : Int,
) -> Bool {
  let before = if index > 0 {
    html_semantic_node_has_meaningful_text(children[index - 1])
  } else {
    false
  }
  let after = if index + 1 < children.length() {
    html_semantic_node_has_meaningful_text(children[index + 1])
  } else {
    false
  }
  before || after
}

///|
fn html_semantic_node_has_meaningful_text(node : HtmlNode) -> Bool {
  match node {
    HtmlNode::Text(text) => text.text.trim() != ""
    _ => false
  }
}

///|
fn html_semantic_count_elements_by_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> Int {
  let mut count = 0
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          count += 1
        }
        count += html_semantic_count_elements_by_tag(element.children, tag_name)
      }
      _ => ()
    }
  }
  count
}

///|
fn html_semantic_first_dom_key_for_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          return Some(
            "html:dom:" + tag_name + ":" + element.span.line_start.to_string(),
          )
        }
        match html_semantic_first_dom_key_for_tag(element.children, tag_name) {
          Some(key) => return Some(key)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_first_block_key_by_tag(
  blocks : Array[HtmlBlockFact],
  tag_name : String,
) -> String? {
  for block in blocks {
    if block.tag_name == tag_name {
      return Some(block.source_key)
    }
  }
  None
}

///|
fn html_semantic_first_text_preview_for_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          return Some(html_semantic_text_preview(element.children).0)
        }
        match
          html_semantic_first_text_preview_for_tag(element.children, tag_name) {
          Some(value) => return Some(value)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_first_meta_charset(nodes : Array[HtmlNode]) -> String? {
  match html_semantic_first_meta_attr(nodes, "charset", "") {
    Some(value) => Some(value)
    None => html_semantic_first_meta_named_content(nodes, "charset")
  }
}

///|
fn html_semantic_first_meta_named_content(
  nodes : Array[HtmlNode],
  name : String,
) -> String? {
  match html_semantic_first_meta_attr(nodes, "name", name) {
    Some(value) => Some(value)
    None => html_semantic_first_meta_attr(nodes, "property", name)
  }
}

///|
fn html_semantic_first_meta_attr(
  nodes : Array[HtmlNode],
  attr_name : String,
  attr_value : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == "meta" {
          if attr_name == "charset" {
            match
              html_semantic_optional_bounded_attr(element.attributes, "charset") {
              Some(value) => return Some(value)
              None => ()
            }
          } else {
            let matches = match
              html_semantic_attr_value(element.attributes, attr_name) {
              Some(value) => value.to_lower() == attr_value.to_lower()
              None => false
            }
            if matches {
              match
                html_semantic_optional_bounded_attr(
                  element.attributes,
                  "content",
                ) {
                Some(value) => return Some(value)
                None => ()
              }
            }
          }
        }
        match
          html_semantic_first_meta_attr(element.children, attr_name, attr_value) {
          Some(value) => return Some(value)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_validation_has_malformed_root(
  issues : Array[HtmlValidationIssue],
) -> Bool {
  for issue in issues {
    match issue.kind {
      HtmlValidationIssueKind::UnclosedElement
      | HtmlValidationIssueKind::UnexpectedClosingTag
      | HtmlValidationIssueKind::MalformedTag => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_has_leading_whitespace(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() > 0 && html_semantic_char_is_space(chars[0])
}

///|
fn html_semantic_has_trailing_whitespace(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() > 0 && html_semantic_char_is_space(chars[chars.length() - 1])
}

///|
fn html_semantic_contains_newline(text : String) -> Bool {
  text.contains("\n") || text.contains("\r")
}

///|
fn html_semantic_contains_repeated_whitespace(text : String) -> Bool {
  let mut last_space = false
  for ch in text {
    let is_space = html_semantic_char_is_space(ch)
    if is_space && last_space {
      return true
    }
    last_space = is_space
  }
  false
}

///|
fn html_semantic_char_is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn bounded_html_semantic_preview(
  text : String,
  max_chars : Int,
) -> (String, Bool) {
  let out : Array[Char] = []
  for ch in text {
    if out.length() >= max_chars {
      return (String::from_array(out), true)
    }
    out.push(ch)
  }
  (String::from_array(out), false)
}

///|
fn normalize_html_semantic_preview(text : String) -> String {
  let out : Array[Char] = []
  let mut last_space = false
  for ch in text {
    let is_space = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    if is_space {
      if !last_space && out.length() > 0 {
        out.push(' ')
        last_space = true
      }
    } else {
      out.push(ch)
      last_space = false
    }
  }
  let normalized = String::from_array(out).trim().to_owned()
  normalized
}
