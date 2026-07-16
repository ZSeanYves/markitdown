///|
fn markdown_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("markdown", source)
  }
  let text = text_payload.text
  if options.output_mode == Markdown && text.length() >= 1_048_576 {
    let line_count = markdown_probe_line_count(text)
    let signals = [
      make_probe_signal(
        BlockCount,
        line_count,
        limit=Some(options.limits.max_rows),
        note=Some("large literal block upper bound"),
      ),
      make_probe_signal(
        CharCount,
        text.length(),
        limit=Some(options.limits.max_line_chars),
      ),
      make_probe_signal(
        ListItemCount,
        0,
        limit=Some(options.limits.max_cols),
        note=Some("deferred in large Markdown output path"),
      ),
    ]
    return probe_outcome(
      "markdown",
      signal_summary_lines(signals),
      text_payload.prepared_source,
      probe_signals=signals,
      probe_artifacts=[
        MarkdownLargeLiteral(text_payload.prepared_source, text, line_count),
      ],
    )
  }
  let prepared = @dmd.prepare_markdown_document_from_text(
    text_payload.prepared_source,
    text,
  )
  let inspect = prepared.inspect
  let signals = [
    make_probe_signal(
      BlockCount,
      inspect.block_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      CharCount,
      text.length(),
      limit=Some(options.limits.max_line_chars),
    ),
    make_probe_signal(
      ListItemCount,
      inspect.list_item_count,
      limit=Some(options.limits.max_cols),
    ),
  ]
  probe_outcome(
    "markdown",
    signal_summary_lines(signals),
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[MarkdownPrepared(prepared)],
  )
}

///|
fn markdown_probe_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut count = 1
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  count
}

///|
fn json_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @djson.prepare_json_document_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("json", source)
  }
  match prepared.stream {
    Some(stream) => {
      let signals = [
        make_probe_signal(
          ObjectCount,
          stream.summary.object_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          MaxDepth,
          stream.summary.max_depth,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          NodeCount,
          stream.summary.object_count +
          stream.summary.array_count +
          stream.summary.scalar_count,
          limit=Some(options.limits.max_cells),
        ),
      ]
      probe_outcome(
        "json",
        signal_summary_lines(signals),
        prepared.prepared_source,
        probe_signals=signals,
        probe_artifacts=[JsonPrepared(prepared)],
      )
    }
    None =>
      probe_outcome("json", ["parse_failed"], prepared.prepared_source, probe_failures=[
        make_probe_failure("json", "parse_failed"),
      ])
  }
}

///|
fn yaml_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dyaml.prepare_yaml_document_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("yaml", source)
  }
  match prepared.inspect {
    Some(inspect) => {
      let signals = [
        make_probe_signal(
          NodeCount,
          inspect.node_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          MaxDepth,
          inspect.max_depth,
          limit=Some(options.limits.max_rows),
        ),
      ]
      probe_outcome(
        "yaml",
        signal_summary_lines(signals),
        prepared.prepared_source,
        probe_signals=signals,
        probe_artifacts=[YamlPrepared(prepared)],
      )
    }
    None =>
      probe_outcome("yaml", ["parse_failed"], prepared.prepared_source, probe_failures=[
        make_probe_failure("yaml", "parse_failed"),
      ])
  }
}

///|
fn toml_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dtoml.prepare_toml_document_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("toml", source)
  }
  let text = prepared.original_text
  let signals = [
    make_probe_signal(CharCount, text.length()),
    make_probe_signal(LineCount, @fshared.count_physical_lines(text)),
  ]
  probe_outcome(
    "toml",
    signal_summary_lines(signals),
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=match (prepared.document, prepared.inspect) {
      (Some(_), Some(_)) => [TomlPrepared(prepared)]
      _ => []
    },
  )
}

///|
fn text_markup_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  let prepared = match format {
    Tex => @dtext.prepare_tex_document_from_source(source)
    Rst => @dtext.prepare_rst_document_from_source(source)
    Asciidoc => @dtext.prepare_asciidoc_document_from_source(source)
    _ => abort("unsupported text markup preflight format")
  }
  let prepared = match prepared {
    Ok(value) => value
    Err(_) =>
      return unavailable_probe(@input.detected_format_name(format), source)
  }
  let signals = [
    make_probe_signal(BlockCount, prepared.inspect.block_count),
    make_probe_signal(LineCount, prepared.inspect.line_count),
    make_probe_signal(CharCount, prepared.original_text.length()),
  ]
  probe_outcome(
    @input.detected_format_name(format),
    signal_summary_lines(signals),
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[TextMarkupPrepared(prepared)],
  )
}

///|
fn audio_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  let format_name = @input.detected_format_name(format)
  probe_outcome(
    format_name,
    [@fmeta.route_name(@fmeta.canonical_route_for_format(format))],
    source,
  )
}

///|
fn ipynb_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dipynb.prepare_ipynb_notebook_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("ipynb", source)
  }
  match prepared.notebook {
    Some(notebook) => {
      let inspect = prepared.inspect.unwrap_or(
        @dipynb.inspect_ipynb_notebook(notebook),
      )
      let signals = [
        make_probe_signal(
          BlockCount,
          inspect.cell_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          OutputCount,
          inspect.output_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          AttachmentCount,
          inspect.attachment_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          CharCount,
          prepared.original_text.length(),
          limit=Some(options.limits.max_line_chars),
        ),
      ]
      probe_outcome(
        "ipynb",
        signal_summary_lines(signals),
        prepared.prepared_source,
        probe_signals=signals,
        probe_artifacts=[IpynbPrepared(prepared)],
      )
    }
    None =>
      probe_outcome(
        "ipynb",
        ["parse_failed"],
        prepared.prepared_source,
        probe_failures=[make_probe_failure("ipynb", "parse_failed")],
        probe_artifacts=[IpynbPrepared(prepared)],
      )
  }
}

///|
priv struct XmlProbeSummary {
  node_count : Int
  max_depth : Int
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
      Declaration(_, _) => ()
      Doctype(_, _) => node_count += 1
      ProcessingInstruction(_, _, _) => node_count += 1
      Comment(_, _) => node_count += 1
      CData(text, _) => if text.trim() != "" { node_count += 1 }
      Text(text, _) => if text.trim() != "" { node_count += 1 }
      StartTag(_, attrs, self_closing, _) => {
        node_count += 1 + attrs.length()
        if !self_closing {
          depth += 1
          if depth > max_depth {
            max_depth = depth
          }
        }
      }
      EndTag(_, _) => if depth > 0 { depth -= 1 }
    }
  }
  { node_count, max_depth }
}

///|
fn xml_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dxml.prepare_xml_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("xml", source)
  }
  match prepared.tokens {
    Some(tokens) => {
      let inspect = xml_stream_probe_summary_from_tokens(tokens)
      let signals = [
        make_probe_signal(
          NodeCount,
          inspect.node_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          MaxDepth,
          inspect.max_depth,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          CharCount,
          prepared.original_text.length(),
          limit=Some(options.limits.max_line_chars * 6),
        ),
      ]
      probe_outcome(
        "xml",
        signal_summary_lines(signals),
        prepared.prepared_source,
        probe_signals=signals,
        probe_artifacts=[XmlPrepared(prepared)],
      )
    }
    None =>
      probe_outcome("xml", ["parse_failed"], prepared.prepared_source, probe_failures=[
        make_probe_failure(
          "xml",
          prepared.parse_error.unwrap_or("parse_failed"),
        ),
      ])
  }
}

///|
priv struct HtmlProbeSummary {
  node_count : Int
  block_scope_count : Int
  structural_scope_count : Int
  max_depth : Int
  char_count : Int
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
      Doctype | Comment => node_count += 1
      Text => if event.source_end > event.source_start { node_count += 1 }
      StartTag => {
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
      EndTag => if depth > 0 { depth -= 1 }
    }
  }
  {
    node_count,
    block_scope_count,
    structural_scope_count,
    max_depth,
    char_count: text.length(),
  }
}

///|
fn html_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dhtml.prepare_html_document_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("html", source)
  }
  let probe = match prepared.events {
    Some(events) =>
      html_probe_summary_from_events(prepared.normalized_text, events)
    None =>
      match prepared.event_summary {
        Some(summary) =>
          {
            node_count: summary.node_count,
            block_scope_count: summary.block_scope_count,
            structural_scope_count: summary.structural_scope_count,
            max_depth: summary.max_depth,
            char_count: summary.char_count,
          }
        None =>
          return probe_outcome(
            "html",
            ["scan_failed"],
            prepared.prepared_source,
            probe_failures=[make_probe_failure("html", "scan_failed")],
          )
      }
  }
  let signals = [
    make_probe_signal(
      NodeCount,
      probe.node_count,
      limit=Some(options.limits.max_cells),
    ),
    make_probe_signal(
      BlockCount,
      probe.block_scope_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      MaxDepth,
      probe.max_depth,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      CharCount,
      probe.char_count,
      limit=Some(options.limits.max_line_chars * 64),
    ),
  ]
  probe_outcome(
    "html",
    signal_summary_lines(signals) +
    [
      probe_summary_line(
        "scopes",
        probe.structural_scope_count,
        Some(options.limits.max_rows),
      ),
    ],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[HtmlPrepared(prepared)],
  )
}
