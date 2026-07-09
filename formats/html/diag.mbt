///|
priv struct HtmlSemanticMetricSummary {
  link_count : Int
  image_count : Int
  table_count : Int
  max_depth : Int
  noise_repeated_boilerplate_count : Int
  warning_count : Int
  warning_error_count : Int
  unsupported_fact_count : Int
  unsupported_script_count : Int
  unsupported_style_count : Int
  unsupported_iframe_count : Int
  unsupported_embed_count : Int
  unsupported_object_count : Int
  unsupported_remote_image_count : Int
  unsupported_data_image_count : Int
  unsupported_unsafe_url_count : Int
}

///|
fn html_semantic_metric_summary(
  semantic : @dhtml.HtmlSemanticDocument,
) -> HtmlSemanticMetricSummary {
  let mut noise_repeated_boilerplate_count = 0
  for noise in semantic.noise_candidates {
    for reason in noise.reasons {
      if reason == @dhtml.HtmlNoiseCandidateReason::RepeatedBoilerplate {
        noise_repeated_boilerplate_count += 1
      }
    }
  }

  let mut warning_count = 0
  let mut warning_error_count = 0
  for warning in semantic.warnings {
    warning_count += 1
    if warning.severity == @dhtml.HtmlWarningSeverity::Error {
      warning_error_count += 1
    }
  }

  let mut unsupported_script_count = 0
  let mut unsupported_style_count = 0
  let mut unsupported_iframe_count = 0
  let mut unsupported_embed_count = 0
  let mut unsupported_object_count = 0
  let mut unsupported_remote_image_count = 0
  let mut unsupported_data_image_count = 0
  let mut unsupported_unsafe_url_count = 0
  for unsupported in semantic.unsupported {
    match unsupported.kind {
      @dhtml.HtmlUnsupportedKind::Script => unsupported_script_count += 1
      @dhtml.HtmlUnsupportedKind::Style => unsupported_style_count += 1
      @dhtml.HtmlUnsupportedKind::Iframe => unsupported_iframe_count += 1
      @dhtml.HtmlUnsupportedKind::Embed => unsupported_embed_count += 1
      @dhtml.HtmlUnsupportedKind::Object => unsupported_object_count += 1
      @dhtml.HtmlUnsupportedKind::RemoteImage =>
        unsupported_remote_image_count += 1
      @dhtml.HtmlUnsupportedKind::DataImage => unsupported_data_image_count += 1
      @dhtml.HtmlUnsupportedKind::UnsafeUrl => unsupported_unsafe_url_count += 1
      _ => ()
    }
  }

  {
    link_count: semantic.links.length(),
    image_count: semantic.images.length(),
    table_count: semantic.tables.length(),
    max_depth: semantic.max_depth,
    noise_repeated_boilerplate_count,
    warning_count,
    warning_error_count,
    unsupported_fact_count: semantic.unsupported.length(),
    unsupported_script_count,
    unsupported_style_count,
    unsupported_iframe_count,
    unsupported_embed_count,
    unsupported_object_count,
    unsupported_remote_image_count,
    unsupported_data_image_count,
    unsupported_unsafe_url_count,
  }
}

///|
fn html_fill_common_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dhtml.HtmlInspectReport,
  validation : @dhtml.HtmlValidationReport,
  semantic_metrics : HtmlSemanticMetricSummary,
  semantic : @dhtml.HtmlSemanticDocument,
  text : String,
  event_count : Int,
  large_mode : Bool,
  asset_count : Int,
) -> Unit {
  diagnostics.metrics.set("node_count", inspect.node_count.to_string())
  diagnostics.metrics.set("element_count", inspect.element_count.to_string())
  diagnostics.metrics.set(
    "text_node_count",
    inspect.text_node_count.to_string(),
  )
  diagnostics.metrics.set("doctype_count", inspect.doctype_count.to_string())
  diagnostics.metrics.set("comment_count", inspect.comment_count.to_string())
  diagnostics.metrics.set(
    "attribute_count",
    inspect.attribute_count.to_string(),
  )
  diagnostics.metrics.set(
    "script_count",
    inspect.script_element_count.to_string(),
  )
  diagnostics.metrics.set(
    "style_count",
    inspect.style_element_count.to_string(),
  )
  diagnostics.metrics.set("link_count", semantic_metrics.link_count.to_string())
  diagnostics.metrics.set(
    "image_count",
    semantic_metrics.image_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_count",
    semantic_metrics.table_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    semantic_metrics.max_depth.to_string(),
  )
  diagnostics.metrics.set(
    "validation_issue_count",
    validation.issue_count.to_string(),
  )
  let scope_source = html_scope_source_metric(semantic)
  diagnostics.metrics.set("scope_source", scope_source)
  diagnostics.metrics.set(
    "selected_content_root",
    html_selected_content_root_metric(semantic),
  )
  diagnostics.metrics.set("readability_mode", "hybrid")
  diagnostics.metrics.set(
    "noise_repeated_boilerplate_count",
    semantic_metrics.noise_repeated_boilerplate_count.to_string(),
  )
  diagnostics.metrics.set(
    "boilerplate_skipped_block_count",
    html_boilerplate_skipped_block_count(semantic).to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    (validation.warning_count + semantic_metrics.warning_count).to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    (validation.error_count + semantic_metrics.warning_error_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_node_count",
    (semantic_metrics.unsupported_script_count +
    semantic_metrics.unsupported_style_count +
    semantic_metrics.unsupported_iframe_count +
    semantic_metrics.unsupported_embed_count +
    semantic_metrics.unsupported_object_count +
    semantic_metrics.unsupported_remote_image_count +
    semantic_metrics.unsupported_data_image_count +
    semantic_metrics.unsupported_unsafe_url_count).to_string(),
  )
  diagnostics.metrics.set(
    "dropped_node_count",
    (semantic_metrics.unsupported_fact_count + validation.issue_count).to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_feature_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set(
    "resource_limit_hit",
    @fshared.bool_string(large_mode),
  )
  diagnostics.metrics.set(
    "has_doctype",
    @fshared.bool_string(inspect.has_doctype),
  )

  for issue in validation.issues {
    diagnostics.warnings.push("html validation: " + issue.message)
  }
  if inspect.script_element_count > 0 {
    diagnostics.degraded_features.push("html_script_dropped")
  }
  if inspect.style_element_count > 0 {
    diagnostics.degraded_features.push("html_style_dropped")
  }
  if semantic_metrics.unsupported_iframe_count > 0 {
    diagnostics.degraded_features.push("html_iframe_dropped")
  }
  if semantic_metrics.unsupported_embed_count > 0 {
    diagnostics.degraded_features.push("html_embed_dropped")
  }
  if semantic_metrics.unsupported_object_count > 0 {
    diagnostics.degraded_features.push("html_object_dropped")
  }
  if semantic_metrics.unsupported_remote_image_count > 0 {
    diagnostics.degraded_features.push("html_remote_image_reference_only")
  }
  if semantic_metrics.unsupported_data_image_count > 0 {
    diagnostics.degraded_features.push("html_data_image_reference_only")
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
fn html_fill_child_semantic_metrics(
  diagnostics : @core.Diagnostics,
  semantic_metrics : HtmlSemanticMetricSummary,
  semantic : @dhtml.HtmlSemanticDocument,
  text : String,
  asset_count : Int,
) -> Unit {
  diagnostics.metrics.set("link_count", semantic_metrics.link_count.to_string())
  diagnostics.metrics.set(
    "image_count",
    semantic_metrics.image_count.to_string(),
  )
  diagnostics.metrics.set(
    "table_count",
    semantic_metrics.table_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    semantic_metrics.max_depth.to_string(),
  )
  diagnostics.metrics.set("scope_source", html_scope_source_metric(semantic))
  diagnostics.metrics.set(
    "selected_content_root",
    html_selected_content_root_metric(semantic),
  )
  diagnostics.metrics.set("readability_mode", "hybrid")
  diagnostics.metrics.set(
    "noise_repeated_boilerplate_count",
    semantic_metrics.noise_repeated_boilerplate_count.to_string(),
  )
  diagnostics.metrics.set(
    "boilerplate_skipped_block_count",
    html_boilerplate_skipped_block_count(semantic).to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    semantic_metrics.warning_count.to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    semantic_metrics.warning_error_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsafe_node_count",
    (semantic_metrics.unsupported_script_count +
    semantic_metrics.unsupported_style_count +
    semantic_metrics.unsupported_iframe_count +
    semantic_metrics.unsupported_embed_count +
    semantic_metrics.unsupported_object_count +
    semantic_metrics.unsupported_remote_image_count +
    semantic_metrics.unsupported_data_image_count +
    semantic_metrics.unsupported_unsafe_url_count).to_string(),
  )
  diagnostics.metrics.set(
    "dropped_node_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_feature_count",
    semantic_metrics.unsupported_fact_count.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("asset_count", asset_count.to_string())
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("validation_issue_count", "0")
  diagnostics.metrics.set("has_doctype", "false")

  for warning in semantic.warnings {
    diagnostics.warnings.push("html semantic: " + warning.message)
  }
  if semantic_metrics.unsupported_script_count > 0 {
    diagnostics.degraded_features.push("html_script_dropped")
  }
  if semantic_metrics.unsupported_style_count > 0 {
    diagnostics.degraded_features.push("html_style_dropped")
  }
  if semantic_metrics.unsupported_iframe_count > 0 {
    diagnostics.degraded_features.push("html_iframe_dropped")
  }
  if semantic_metrics.unsupported_embed_count > 0 {
    diagnostics.degraded_features.push("html_embed_dropped")
  }
  if semantic_metrics.unsupported_object_count > 0 {
    diagnostics.degraded_features.push("html_object_dropped")
  }
  if semantic_metrics.unsupported_remote_image_count > 0 {
    diagnostics.degraded_features.push("html_remote_image_reference_only")
  }
  if semantic_metrics.unsupported_data_image_count > 0 {
    diagnostics.degraded_features.push("html_data_image_reference_only")
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
fn html_scope_source_metric(semantic : @dhtml.HtmlSemanticDocument) -> String {
  for scope in semantic.scope {
    return match scope.scope_source {
      @dhtml.HtmlDocumentScopeSource::Body => "body"
      @dhtml.HtmlDocumentScopeSource::Main => "main"
      @dhtml.HtmlDocumentScopeSource::Article => "article"
      @dhtml.HtmlDocumentScopeSource::DocumentRoot => "document_root"
      @dhtml.HtmlDocumentScopeSource::Fragment => "fragment"
      @dhtml.HtmlDocumentScopeSource::Heuristic => "heuristic"
    }
  }
  "none"
}

///|
fn html_selected_content_root_metric(
  semantic : @dhtml.HtmlSemanticDocument,
) -> String {
  for scope in semantic.scope {
    match scope.selected_scope_reason {
      "" => ()
      value => return value
    }
  }
  "none"
}

///|
fn html_boilerplate_skipped_block_count(
  semantic : @dhtml.HtmlSemanticDocument,
) -> Int {
  let skipped : Map[String, Bool] = Map([])
  for block in semantic.blocks {
    if block.tag_name == "nav" {
      skipped.set(block.source_key, true)
    }
  }
  for noise in semantic.noise_candidates {
    if !html_noise_should_skip(noise) {
      continue
    }
    match noise.block_source_key {
      Some(key) => if !skipped.contains(key) { skipped.set(key, true) }
      None => ()
    }
  }
  skipped.length()
}
