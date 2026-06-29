///|
fn probe_limit_reached(observed : Int, limit : Int) -> Bool {
  observed > limit
}

///|
fn read_probe_text(
  source : @input.InputSource,
) -> (String?, @input.InputSource) {
  match @input.read_input_text(source) {
    Ok(text) =>
      (
        Some(text),
        if source.text is Some(_) {
          source
        } else {
          @input.with_text_payload(source, text)
        },
      )
    Err(_) => (None, source)
  }
}

///|
fn read_probe_bytes(
  source : @input.InputSource,
) -> (Bytes?, @input.InputSource) {
  match @input.read_input_bytes(source) {
    Ok(bytes) =>
      (
        Some(bytes),
        if source.bytes is Some(_) {
          source
        } else {
          @input.with_bytes_payload(source, bytes)
        },
      )
    Err(_) => (None, source)
  }
}

///|
fn markdown_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "markdown_probe_unavailable",
        "markdown",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let scanned = @dmd.scan_markdown_document(text)
  let inspect = @dmd.inspect_markdown_document(scanned)
  let block_limit = options.limits.max_rows
  let char_limit = options.limits.max_line_chars
  let list_limit = options.limits.max_cols
  let list_pressure = inspect.list_item_count > list_limit
  let route = if probe_limit_reached(inspect.block_count, block_limit) ||
    probe_limit_reached(text.length(), char_limit) ||
    list_pressure {
    CanonicalRoute::BlockStreaming
  } else {
    CanonicalRoute::DomAstModel
  }
  let reason = if route == CanonicalRoute::BlockStreaming {
    "markdown_over_limit_block_streaming"
  } else {
    "markdown_within_dom_budget"
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "markdown",
    [
      "blocks=" +
      inspect.block_count.to_string() +
      "/limit=" +
      block_limit.to_string(),
      "chars=" + text.length().to_string() + "/limit=" + char_limit.to_string(),
      "list_items=" +
      inspect.list_item_count.to_string() +
      "/limit=" +
      list_limit.to_string(),
      "route=" + canonical_route_name(route),
    ],
    prepared_source,
    artifact=Some(RouteProbeArtifact::MarkdownScan(scanned, inspect)),
  )
}

///|
fn json_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "json_probe_unavailable",
        "json",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let streamed = try @djson.parse_json_stream(text) |> Ok catch {
    _ => Err(())
  }
  let route = match streamed {
    Ok(stream) =>
      if probe_limit_reached(
          stream.summary.object_count,
          options.limits.max_rows,
        ) ||
        probe_limit_reached(stream.summary.max_depth, options.limits.max_rows) ||
        probe_limit_reached(
          stream.summary.object_count +
          stream.summary.array_count +
          stream.summary.scalar_count,
          options.limits.max_cells,
        ) {
        CanonicalRoute::StreamingEvent
      } else {
        CanonicalRoute::DomAstModel
      }
    Err(_) => CanonicalRoute::DomAstModel
  }
  let reason = if route == CanonicalRoute::StreamingEvent {
    "json_over_limit_streaming_event"
  } else {
    "json_within_dom_budget"
  }
  let parts = match streamed {
    Ok(stream) =>
      [
        "objects=" +
        stream.summary.object_count.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "depth=" +
        stream.summary.max_depth.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "nodes=" +
        (stream.summary.object_count +
        stream.summary.array_count +
        stream.summary.scalar_count).to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "route=" + canonical_route_name(route),
      ]
    Err(_) => ["parse_failed", "route=" + canonical_route_name(route)]
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "json",
    parts,
    prepared_source,
    artifact=match streamed {
      Ok(stream) if route == CanonicalRoute::StreamingEvent =>
        Some(RouteProbeArtifact::JsonStream(stream))
      _ => None
    },
  )
}

///|
fn yaml_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "yaml_probe_unavailable",
        "yaml",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let parsed = try @dyaml.parse_yaml_structure_events(text) |> Ok catch {
    _ => Err(())
  }
  let route = match parsed {
    Ok(events) => {
      let inspect = @dyaml.inspect_yaml_structure_events(events)
      let text_budget = inspect.scalar_count +
        inspect.mapping_count +
        inspect.sequence_count
      if probe_limit_reached(inspect.node_count, options.limits.max_cells) ||
        probe_limit_reached(inspect.max_depth, options.limits.max_rows) ||
        text_budget > options.limits.max_cells / 8 {
        CanonicalRoute::StreamingEvent
      } else {
        CanonicalRoute::DomAstModel
      }
    }
    Err(_) => CanonicalRoute::DomAstModel
  }
  let reason = if route == CanonicalRoute::StreamingEvent {
    "yaml_over_limit_streaming_event"
  } else {
    "yaml_within_dom_budget"
  }
  let parts = match parsed {
    Ok(events) => {
      let inspect = @dyaml.inspect_yaml_structure_events(events)
      [
        "nodes=" +
        inspect.node_count.to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "depth=" +
        inspect.max_depth.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "route=" + canonical_route_name(route),
      ]
    }
    Err(_) => ["parse_failed", "route=" + canonical_route_name(route)]
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "yaml",
    parts,
    prepared_source,
    artifact=match parsed {
      Ok(events) if route == CanonicalRoute::StreamingEvent =>
        Some(
          RouteProbeArtifact::YamlEvents(
            events,
            @dyaml.inspect_yaml_structure_events(events),
          ),
        )
      _ => None
    },
  )
}

///|
fn xml_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let bytes = match bytes {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "xml_probe_unavailable",
        "xml",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let text = match @input.read_input_text(prepared_source) {
    Ok(value) => Some(value)
    Err(_) => None
  }
  let text = match text {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "xml_probe_unavailable",
        "xml",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let xml_scan = @dxml.scan_xml_structure_bytes(bytes)
  let native_summary = if xml_scan.status ==
    @dxml.XmlStructureScanStatus::Success {
    Some({ node_count: xml_scan.node_count, max_depth: xml_scan.max_depth })
  } else {
    None
  }
  let parsed = try @dxml.parse_xml_structure_tokens(text) |> Ok catch {
    _ => Err(())
  }
  let route = match parsed {
    Ok(tokens) => {
      let inspect = match native_summary {
        Some(summary) => summary
        None => xml_stream_probe_summary_from_tokens(tokens)
      }
      if probe_limit_reached(inspect.node_count, options.limits.max_cells) ||
        probe_limit_reached(inspect.max_depth, options.limits.max_rows) ||
        (
          probe_limit_reached(text.length(), options.limits.max_line_chars * 6) &&
          inspect.node_count > options.limits.max_rows / 5
        ) {
        CanonicalRoute::StreamingEvent
      } else {
        CanonicalRoute::DomAstModel
      }
    }
    Err(_) =>
      match native_summary {
        Some(inspect) =>
          if probe_limit_reached(inspect.node_count, options.limits.max_cells) ||
            probe_limit_reached(inspect.max_depth, options.limits.max_rows) ||
            (
              probe_limit_reached(
                text.length(),
                options.limits.max_line_chars * 6,
              ) &&
              inspect.node_count > options.limits.max_rows / 5
            ) {
            CanonicalRoute::StreamingEvent
          } else {
            CanonicalRoute::DomAstModel
          }
        None => CanonicalRoute::DomAstModel
      }
  }
  let reason = if route == CanonicalRoute::StreamingEvent {
    "xml_over_limit_streaming_event"
  } else {
    "xml_within_dom_budget"
  }
  let parts = match native_summary {
    Some(inspect) =>
      [
        "nodes=" +
        inspect.node_count.to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "depth=" +
        inspect.max_depth.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "chars=" +
        text.length().to_string() +
        "/limit=" +
        options.limits.max_line_chars.to_string(),
        "probe=xml_structure_scan",
        "route=" + canonical_route_name(route),
      ]
    None =>
      match parsed {
        Ok(tokens) => {
          let inspect = xml_stream_probe_summary_from_tokens(tokens)
          [
            "nodes=" +
            inspect.node_count.to_string() +
            "/limit=" +
            options.limits.max_cells.to_string(),
            "depth=" +
            inspect.max_depth.to_string() +
            "/limit=" +
            options.limits.max_rows.to_string(),
            "chars=" +
            text.length().to_string() +
            "/limit=" +
            options.limits.max_line_chars.to_string(),
            "probe=moonbit_xml_tokens",
            "route=" + canonical_route_name(route),
          ]
        }
        Err(_) =>
          [
            "parse_failed",
            "probe=xml_structure_unavailable",
            "route=" + canonical_route_name(route),
          ]
      }
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "xml",
    parts,
    prepared_source,
    artifact=match parsed {
      Ok(tokens) if route == CanonicalRoute::StreamingEvent =>
        Some(RouteProbeArtifact::XmlTokens(tokens))
      _ => None
    },
  )
}

///|
priv struct XmlProbeSummary {
  node_count : Int
  max_depth : Int
}

///|
priv struct HtmlProbeSummary {
  node_count : Int
  block_scope_count : Int
  structural_scope_count : Int
  token_count : Int
  max_depth : Int
  char_count : Int
}

///|
fn xml_stream_probe_summary_from_tokens(
  tokens : Array[@dxml.XmlToken],
) -> XmlProbeSummary {
  let mut node_count = 0
  let mut depth = 0
  let mut max_depth = 0
  for token in tokens {
    match token {
      @dxml.XmlToken::Declaration(_, _) => ()
      @dxml.XmlToken::Doctype(_, _) => node_count += 1
      @dxml.XmlToken::ProcessingInstruction(_, _, _) => node_count += 1
      @dxml.XmlToken::Comment(_, _) => node_count += 1
      @dxml.XmlToken::CData(text, _) => if text.trim() != "" { node_count += 1 }
      @dxml.XmlToken::Text(text, _) => if text.trim() != "" { node_count += 1 }
      @dxml.XmlToken::StartTag(_, attrs, self_closing, _) => {
        node_count += 1 + attrs.length()
        if !self_closing {
          depth += 1
          if depth > max_depth {
            max_depth = depth
          }
        }
      }
      @dxml.XmlToken::EndTag(_, _) => if depth > 0 { depth -= 1 }
    }
  }
  { node_count, max_depth }
}

///|
fn html_probe_summary_from_events(
  text : String,
  events : Array[@dhtml.HtmlTokenEvent],
) -> HtmlProbeSummary {
  let mut node_count = 0
  let mut depth = 0
  let mut max_depth = 0
  let mut block_scope_count = 0
  let mut structural_scope_count = 0
  for event in events {
    match event.kind {
      @dhtml.HtmlTokenEventKind::Doctype => node_count += 1
      @dhtml.HtmlTokenEventKind::Comment => node_count += 1
      @dhtml.HtmlTokenEventKind::Text =>
        if event.source_end > event.source_start {
          node_count += 1
        }
      @dhtml.HtmlTokenEventKind::StartTag => {
        node_count += 1 + event.attributes.length()
        if event.tag_name == "main" ||
          event.tag_name == "article" ||
          event.tag_name == "section" {
          block_scope_count += 1
        }
        if event.tag_name == "main" ||
          event.tag_name == "article" ||
          event.tag_name == "section" ||
          event.tag_name == "nav" ||
          event.tag_name == "aside" ||
          event.tag_name == "table" ||
          event.tag_name == "ul" ||
          event.tag_name == "ol" {
          structural_scope_count += 1
        }
        if !event.self_closing {
          depth += 1
          if depth > max_depth {
            max_depth = depth
          }
        }
      }
      @dhtml.HtmlTokenEventKind::EndTag => if depth > 0 { depth -= 1 }
    }
  }
  {
    node_count,
    block_scope_count,
    structural_scope_count,
    token_count: events.length(),
    max_depth,
    char_count: text.length(),
  }
}

///|
fn html_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None =>
      return canonical_preflight_probe(
        format,
        CanonicalRoute::DomAstModel,
        "html_probe_unavailable",
        "html",
        ["unavailable"],
        source,
        artifact=None,
      )
  }
  let normalized_text = @dhtml.normalize_html_token_source(text)
  let scanned = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  let route = match scanned {
    Ok(events) => {
      let probe = html_probe_summary_from_events(normalized_text, events)
      if probe_limit_reached(probe.node_count, options.limits.max_cells) ||
        probe_limit_reached(probe.token_count, options.limits.max_cells) ||
        probe_limit_reached(probe.block_scope_count, options.limits.max_rows) ||
        probe_limit_reached(probe.max_depth, options.limits.max_rows) ||
        probe.structural_scope_count > options.limits.max_rows / 4 ||
        (
          probe.char_count > options.limits.max_line_chars * 64 &&
          probe.structural_scope_count > 0
        ) {
        CanonicalRoute::BlockStreaming
      } else {
        CanonicalRoute::DomAstModel
      }
    }
    Err(_) => CanonicalRoute::DomAstModel
  }
  let reason = if route == CanonicalRoute::BlockStreaming {
    "html_over_limit_block_streaming"
  } else {
    "html_within_dom_budget"
  }
  let parts = match scanned {
    Ok(events) => {
      let probe = html_probe_summary_from_events(normalized_text, events)
      [
        "nodes=" +
        probe.node_count.to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "tokens=" +
        probe.token_count.to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "scopes=" +
        probe.block_scope_count.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "structural_scopes=" +
        probe.structural_scope_count.to_string() +
        "/limit=" +
        (options.limits.max_rows / 4).to_string(),
        "depth=" +
        probe.max_depth.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "chars=" +
        probe.char_count.to_string() +
        "/limit=" +
        (options.limits.max_line_chars * 64).to_string(),
        "route=" + canonical_route_name(route),
      ]
    }
    Err(_) => ["scan_failed", "route=" + canonical_route_name(route)]
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "html",
    parts,
    prepared_source,
    artifact=match scanned {
      Ok(events) if route == CanonicalRoute::BlockStreaming =>
        Some(RouteProbeArtifact::HtmlEvents(normalized_text, events))
      _ => None
    },
  )
}

///|
fn xlsx_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let opened_pkg = match bytes {
    Some(payload) =>
      try @ox.open_ooxml_package(payload) |> Ok catch {
        err => Err(err.to_string())
      }
    None =>
      match @input.read_input_bytes(source) {
        Ok(payload) =>
          try @ox.open_ooxml_package(payload) |> Ok catch {
            err => Err(err.to_string())
          }
        Err(err) => Err(err)
      }
  }
  let summary = match opened_pkg {
    Ok(pkg) =>
      @dxlsx.xlsx_route_preflight_summary_with_package(
        pkg,
        options.limits.max_rows,
        options.limits.max_cols,
        options.limits.max_cells,
      )
    Err(err) => Err(err)
  }
  let route = match summary {
    Ok(probe) =>
      if probe.visible_sheet_count > options.limits.max_rows ||
        probe.max_sheet_rows > options.limits.max_rows ||
        probe.max_sheet_cols > options.limits.max_cols ||
        probe.estimated_cells > options.limits.max_cells {
        CanonicalRoute::BlockStreaming
      } else {
        CanonicalRoute::PackageSinglePass
      }
    Err(_) => CanonicalRoute::PackageSinglePass
  }
  let reason = if route == CanonicalRoute::BlockStreaming {
    "xlsx_over_limit_block_streaming"
  } else {
    "xlsx_within_package_budget"
  }
  let probe_summary_parts = match summary {
    Ok(probe) =>
      [
        "visible_sheets=" +
        probe.visible_sheet_count.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "sheet_rows=" +
        probe.max_sheet_rows.to_string() +
        "/limit=" +
        options.limits.max_rows.to_string(),
        "sheet_cols=" +
        probe.max_sheet_cols.to_string() +
        "/limit=" +
        options.limits.max_cols.to_string(),
        "estimated_cells=" +
        probe.estimated_cells.to_string() +
        "/limit=" +
        options.limits.max_cells.to_string(),
        "route=" + canonical_route_name(route),
      ]
    Err(_) => ["probe_failed", "route=" + canonical_route_name(route)]
  }
  canonical_preflight_probe(
    format,
    route,
    reason,
    "xlsx",
    probe_summary_parts,
    prepared_source,
    artifact=match opened_pkg {
      Ok(pkg) => Some(RouteProbeArtifact::XlsxPackage(pkg))
      Err(_) => None
    },
  )
}

///|
fn canonical_preflight_probe(
  format : @input.DetectedFormat,
  route : CanonicalRoute,
  reason : String,
  summary_format : String,
  summary_parts : Array[String],
  prepared_source : @input.InputSource,
  artifact? : RouteProbeArtifact? = None,
) -> PreflightProbe {
  ignore(format)
  {
    selected_route: route,
    reason,
    summary_format,
    summary_parts,
    prepared_source,
    probe_artifact: artifact,
  }
}

///|
fn preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> PreflightProbe {
  if options.mode == ConvertMode::Stream {
    let route = canonical_route_for_format(format, options)
    return canonical_preflight_probe(
      format,
      route,
      "explicit_stream_mode",
      @input.detected_format_name(format),
      ["explicit_stream", canonical_route_name(route)],
      source,
      artifact=None,
    )
  }
  match format {
    @input.DetectedFormat::Markdown =>
      markdown_preflight_probe(source, format, options)
    @input.DetectedFormat::Json => json_preflight_probe(source, format, options)
    @input.DetectedFormat::Yaml => yaml_preflight_probe(source, format, options)
    @input.DetectedFormat::Xml => xml_preflight_probe(source, format, options)
    @input.DetectedFormat::Html => html_preflight_probe(source, format, options)
    @input.DetectedFormat::Xlsx => xlsx_preflight_probe(source, format, options)
    _ => {
      let route = canonical_route_for_format(format, options)
      canonical_preflight_probe(
        format,
        route,
        route_reason_for_format(format, options, route),
        @input.detected_format_name(format),
        [canonical_route_name(route)],
        source,
        artifact=None,
      )
    }
  }
}
