///|
fn collect_html_semantic_scope_fact(
  doc : HtmlDocument,
  ctx : HtmlSemanticCollectCtx,
) -> Unit {
  let body_count = html_semantic_count_elements_by_tag(doc.nodes, "body")
  let html_count = html_semantic_count_elements_by_tag(doc.nodes, "html")
  let html_node_key = html_semantic_first_dom_key_for_tag(doc.nodes, "html")
  let head_node_key = html_semantic_first_dom_key_for_tag(doc.nodes, "head")
  let body_node_key = html_semantic_first_block_key_by_tag(ctx.blocks, "body")
  let main_node_key = html_semantic_first_block_key_by_tag(ctx.blocks, "main")
  let article_node_key = html_semantic_first_block_key_by_tag(
    ctx.blocks,
    "article",
  )
  let selected_content_root_key = match main_node_key {
    Some(key) => Some(key)
    None =>
      match article_node_key {
        Some(key) => Some(key)
        None => body_node_key
      }
  }
  let scope_source = match main_node_key {
    Some(_) => HtmlDocumentScopeSource::Main
    None =>
      match article_node_key {
        Some(_) => HtmlDocumentScopeSource::Article
        None =>
          match body_node_key {
            Some(_) => HtmlDocumentScopeSource::Body
            None =>
              if html_count > 0 {
                HtmlDocumentScopeSource::DocumentRoot
              } else if doc.nodes.length() > 0 {
                HtmlDocumentScopeSource::Fragment
              } else {
                HtmlDocumentScopeSource::Heuristic
              }
          }
      }
  }
  let selected_scope_reason = match scope_source {
    HtmlDocumentScopeSource::Body => "body"
    HtmlDocumentScopeSource::Main => "main"
    HtmlDocumentScopeSource::Article => "article"
    HtmlDocumentScopeSource::DocumentRoot => "document_root"
    HtmlDocumentScopeSource::Fragment => "fragment"
    HtmlDocumentScopeSource::Heuristic => "heuristic"
  }
  let missing_body_warning = html_count > 0 && body_count == 0
  let multiple_body_warning = body_count > 1 || html_count > 1
  let malformed_root_warning = multiple_body_warning ||
    html_semantic_validation_has_malformed_root(doc.issues)
  let warnings : Array[HtmlSemanticWarning] = []
  if missing_body_warning {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "body",
        "html semantic document scope is missing body",
      ),
    )
  }
  if multiple_body_warning {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "body",
        "html semantic document scope has multiple body/html roots",
      ),
    )
  }
  if malformed_root_warning && warnings.length() == 0 {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "",
        "html semantic document scope saw malformed root recovery",
      ),
    )
  }
  push_html_semantic_warnings(ctx, warnings)
  ctx.scope.push({
    source_key: "html:scope:1",
    html_node_key,
    head_node_key,
    body_node_key,
    selected_content_root_key,
    scope_source,
    title_text_preview: html_semantic_first_text_preview_for_tag(
      doc.nodes,
      "title",
    ),
    meta_charset: html_semantic_first_meta_charset(doc.nodes),
    meta_viewport: html_semantic_first_meta_named_content(doc.nodes, "viewport"),
    meta_description: html_semantic_first_meta_named_content(
      doc.nodes,
      "description",
    ),
    malformed_root_warning,
    multiple_body_warning,
    missing_body_warning,
    selected_scope_reason,
    noise_candidate_source_keys: html_semantic_noise_candidate_keys(
      ctx.noise_candidates,
    ),
    warnings,
  })
}

///|
fn collect_html_semantic_noise_candidate_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String?,
  parent_source_key : String?,
  source_order : Int,
  depth : Int,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
) -> Unit {
  let reasons = html_semantic_noise_candidate_reasons(element)
  if reasons.length() == 0 {
    return
  }
  ctx.next_noise_order += 1
  let confidence = html_semantic_noise_confidence(element, reasons)
  ctx.noise_candidates.push({
    source_key: "html:noise:" + ctx.next_noise_order.to_string(),
    block_source_key,
    parent_source_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    text_preview,
    attributes,
    reasons,
    confidence,
    span: element.span,
  })
}

///|
