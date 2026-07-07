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
fn probe_outcome(
  summary_format : String,
  summary_parts : Array[String],
  prepared_source : @input.InputSource,
  probe_signals? : Array[ProbeSignal] = [],
  probe_failures? : Array[ProbeFailure] = [],
  probe_artifacts? : Array[RouteProbeArtifact] = [],
) -> ProbeOutcome {
  {
    probe_signals,
    probe_failures,
    summary_format,
    summary_parts,
    prepared_source,
    probe_artifacts,
  }
}

///|
fn probe_summary_line(label : String, value : Int, limit : Int?) -> String {
  match limit {
    Some(limit_value) =>
      label + "=" + value.to_string() + "/limit=" + limit_value.to_string()
    None => label + "=" + value.to_string()
  }
}

///|
fn signal_summary_lines(signals : Array[ProbeSignal]) -> Array[String] {
  let parts : Array[String] = []
  for signal in signals {
    let label = match signal.kind {
      ProbeSignalKind::CharCount => "chars"
      ProbeSignalKind::LineCount => "lines"
      ProbeSignalKind::BlockCount => "blocks"
      ProbeSignalKind::ListItemCount => "list_items"
      ProbeSignalKind::NodeCount => "nodes"
      ProbeSignalKind::MaxDepth => "depth"
      ProbeSignalKind::RowCount => "rows"
      ProbeSignalKind::ColCount => "cols"
      ProbeSignalKind::CellCount => "cells"
      ProbeSignalKind::CellEstimate => "estimated_cells"
      ProbeSignalKind::OutputCount => "outputs"
      ProbeSignalKind::AttachmentCount => "attachments"
      ProbeSignalKind::AssetCount => "assets"
      ProbeSignalKind::EntryCount => "entries"
      ProbeSignalKind::PageCount => "pages"
      ProbeSignalKind::SlideCount => "slides"
      ProbeSignalKind::SheetCount => "sheets"
      ProbeSignalKind::ScalarCount => "scalars"
      ProbeSignalKind::ObjectCount => "objects"
      ProbeSignalKind::ArrayCount => "arrays"
      ProbeSignalKind::HiddenRowCount => "hidden_rows"
      ProbeSignalKind::HiddenSheetCount => "hidden_sheets"
      ProbeSignalKind::CoveredCellCount => "covered_cells"
      ProbeSignalKind::NoteCount => "notes"
      ProbeSignalKind::CommentCount => "comments"
      ProbeSignalKind::ScannedPageCount => "scanned_pages"
      ProbeSignalKind::NativeTextPageCount => "native_text_pages"
    }
    parts.push(probe_summary_line(label, signal.observed, signal.limit))
  }
  parts
}

///|
fn unavailable_probe(
  summary_format : String,
  prepared_source : @input.InputSource,
) -> ProbeOutcome {
  probe_outcome(summary_format, ["unavailable"], prepared_source, probe_failures=[
    make_probe_failure(summary_format, "probe_unavailable"),
  ])
}

///|
fn markdown_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("markdown", source)
  }
  let scanned = @dmd.scan_markdown_document(text)
  let inspect = @dmd.inspect_markdown_document(scanned)
  let signals = [
    make_probe_signal(
      ProbeSignalKind::BlockCount,
      inspect.block_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      ProbeSignalKind::CharCount,
      text.length(),
      limit=Some(options.limits.max_line_chars),
    ),
    make_probe_signal(
      ProbeSignalKind::ListItemCount,
      inspect.list_item_count,
      limit=Some(options.limits.max_cols),
    ),
  ]
  probe_outcome(
    "markdown",
    signal_summary_lines(signals),
    prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::MarkdownScan(scanned, inspect)],
  )
}

///|
fn json_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("json", source)
  }
  let streamed = try @djson.parse_json_stream(text) |> Ok catch {
    _ => Err(())
  }
  match streamed {
    Ok(stream) => {
      let signals = [
        make_probe_signal(
          ProbeSignalKind::ObjectCount,
          stream.summary.object_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::MaxDepth,
          stream.summary.max_depth,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::NodeCount,
          stream.summary.object_count +
          stream.summary.array_count +
          stream.summary.scalar_count,
          limit=Some(options.limits.max_cells),
        ),
      ]
      probe_outcome(
        "json",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::JsonStream(stream)],
      )
    }
    Err(_) =>
      probe_outcome("json", ["parse_failed"], prepared_source, probe_failures=[
        make_probe_failure("json", "parse_failed"),
      ])
  }
}

///|
fn yaml_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("yaml", source)
  }
  let parsed = try @dyaml.parse_yaml_structure_events(text) |> Ok catch {
    _ => Err(())
  }
  match parsed {
    Ok(events) => {
      let inspect = @dyaml.inspect_yaml_structure_events(events)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::NodeCount,
          inspect.node_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          ProbeSignalKind::MaxDepth,
          inspect.max_depth,
          limit=Some(options.limits.max_rows),
        ),
      ]
      probe_outcome(
        "yaml",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::YamlEvents(events, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("yaml", ["parse_failed"], prepared_source, probe_failures=[
        make_probe_failure("yaml", "parse_failed"),
      ])
  }
}

///|
fn toml_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("toml", source)
  }
  let parsed = try @dtoml.parse_toml_document(text) |> Ok catch {
    _ => Err(())
  }
  let inspect = match parsed {
    Ok(doc) => Some((doc, @dtoml.inspect_toml_document(doc)))
    Err(_) => None
  }
  let signals = [
    make_probe_signal(ProbeSignalKind::CharCount, text.length()),
    make_probe_signal(
      ProbeSignalKind::LineCount,
      @fshared.count_physical_lines(text),
    ),
  ]
  probe_outcome(
    "toml",
    signal_summary_lines(signals),
    prepared_source,
    probe_signals=signals,
    probe_artifacts=match inspect {
      Some((doc, report)) => [RouteProbeArtifact::TomlDocument(doc, report)]
      None => []
    },
  )
}

///|
fn text_markup_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None =>
      return unavailable_probe(
        @input.detected_format_name(format),
        prepared_source,
      )
  }
  let doc = match format {
    @input.DetectedFormat::Tex => @dtext.parse_tex_document(text)
    @input.DetectedFormat::Rst => @dtext.parse_rst_document(text)
    @input.DetectedFormat::Asciidoc => @dtext.parse_asciidoc_document(text)
    _ => abort("unsupported text markup preflight format")
  }
  let inspect = @dtext.inspect_text_markup_document(doc, text)
  let signals = [
    make_probe_signal(ProbeSignalKind::BlockCount, inspect.block_count),
    make_probe_signal(
      ProbeSignalKind::LineCount,
      @fshared.count_physical_lines(text),
    ),
    make_probe_signal(ProbeSignalKind::CharCount, text.length()),
  ]
  probe_outcome(
    @input.detected_format_name(format),
    signal_summary_lines(signals),
    prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::TextMarkupDocument(doc, inspect)],
  )
}

///|
fn audio_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  let format_name = @input.detected_format_name(format)
  let artifact = make_audio_probe_artifact(format_name, probe_notes=[
    @formats.route_name(@formats.canonical_route_for_format(format)),
  ])
  probe_outcome(
    format_name,
    [@formats.route_name(@formats.canonical_route_for_format(format))],
    source,
    probe_artifacts=[RouteProbeArtifact::AudioProbe(artifact)],
  )
}

///|
fn ipynb_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("ipynb", source)
  }
  let parsed = try @dipynb.parse_ipynb_notebook(text) |> Ok catch {
    _ => Err(())
  }
  match parsed {
    Ok(notebook) => {
      let inspect = @dipynb.inspect_ipynb_notebook(notebook)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::BlockCount,
          inspect.cell_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::OutputCount,
          inspect.output_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          ProbeSignalKind::AttachmentCount,
          inspect.attachment_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          ProbeSignalKind::CharCount,
          text.length(),
          limit=Some(options.limits.max_line_chars),
        ),
      ]
      probe_outcome(
        "ipynb",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::IpynbNotebook(notebook, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("ipynb", ["parse_failed"], prepared_source, probe_failures=[
        make_probe_failure("ipynb", "parse_failed"),
      ])
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
fn xml_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  ignore(
    match bytes {
      Some(value) => value
      None => return unavailable_probe("xml", source)
    },
  )
  let text = match @input.read_input_text(prepared_source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("xml", source)
  }
  let parsed = try @dxml.parse_xml_structure_tokens(text) |> Ok catch {
    _ => Err(())
  }
  match parsed {
    Ok(tokens) => {
      let inspect = xml_stream_probe_summary_from_tokens(tokens)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::NodeCount,
          inspect.node_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          ProbeSignalKind::MaxDepth,
          inspect.max_depth,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::CharCount,
          text.length(),
          limit=Some(options.limits.max_line_chars * 6),
        ),
      ]
      probe_outcome(
        "xml",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::XmlTokens(tokens)],
      )
    }
    Err(_) =>
      probe_outcome("xml", ["parse_failed"], prepared_source, probe_failures=[
        make_probe_failure("xml", "parse_failed"),
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
    max_depth,
    char_count: text.length(),
  }
}

///|
fn html_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (text, prepared_source) = read_probe_text(source)
  let text = match text {
    Some(value) => value
    None => return unavailable_probe("html", source)
  }
  let normalized_text = @dhtml.normalize_html_token_source(text)
  let scanned = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match scanned {
    Ok(events) => {
      let probe = html_probe_summary_from_events(normalized_text, events)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::NodeCount,
          probe.node_count,
          limit=Some(options.limits.max_cells),
        ),
        make_probe_signal(
          ProbeSignalKind::BlockCount,
          probe.block_scope_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::MaxDepth,
          probe.max_depth,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::CharCount,
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
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[
          RouteProbeArtifact::HtmlEvents(normalized_text, events),
        ],
      )
    }
    Err(_) =>
      probe_outcome("html", ["scan_failed"], prepared_source, probe_failures=[
        make_probe_failure("html", "scan_failed"),
      ])
  }
}

///|
fn xlsx_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
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
  match (opened_pkg, summary) {
    (Ok(pkg), Ok(probe)) => {
      let signals = [
        make_probe_signal(
          ProbeSignalKind::SheetCount,
          probe.visible_sheet_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::RowCount,
          probe.max_sheet_rows,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::ColCount,
          probe.max_sheet_cols,
          limit=Some(options.limits.max_cols),
        ),
        make_probe_signal(
          ProbeSignalKind::CellEstimate,
          probe.estimated_cells,
          limit=Some(options.limits.max_cells),
        ),
      ]
      probe_outcome(
        "xlsx",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::XlsxPackage(pkg)],
      )
    }
    (_, Err(_)) =>
      probe_outcome("xlsx", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("xlsx", "probe_failed"),
      ])
    _ => unavailable_probe("xlsx", prepared_source)
  }
}

///|
fn odt_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let document = match bytes {
    Some(payload) =>
      try @dodf.open_odt_document(payload) |> Ok catch {
        err => Err(err.to_string())
      }
    None => Err("probe_unavailable")
  }
  match document {
    Ok(doc) => {
      let inspect = @dodf.inspect_odt_document(doc)
      let signals = [
        make_probe_signal(ProbeSignalKind::BlockCount, inspect.block_count),
        make_probe_signal(ProbeSignalKind::NoteCount, inspect.note_count),
        make_probe_signal(ProbeSignalKind::CommentCount, inspect.comment_count),
      ]
      probe_outcome(
        "odt",
        signal_summary_lines(signals) +
        [
          probe_summary_line("images", inspect.image_count, None),
          probe_summary_line("tables", inspect.table_count, None),
        ],
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::OdtDocument(doc, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("odt", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("odt", "probe_failed"),
      ])
  }
}

///|
fn ods_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let document = match bytes {
    Some(payload) =>
      try @dodf.open_ods_document(payload) |> Ok catch {
        err => Err(err.to_string())
      }
    None => Err("probe_unavailable")
  }
  match document {
    Ok(doc) => {
      let inspect = @dodf.inspect_ods_document(doc)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::SheetCount,
          inspect.visible_sheet_count,
        ),
        make_probe_signal(
          ProbeSignalKind::HiddenSheetCount,
          inspect.hidden_sheet_count,
        ),
        make_probe_signal(
          ProbeSignalKind::RowCount,
          inspect.non_empty_row_count,
        ),
        make_probe_signal(
          ProbeSignalKind::CellEstimate,
          inspect.used_cell_count,
        ),
        make_probe_signal(
          ProbeSignalKind::HiddenRowCount,
          inspect.hidden_row_count,
        ),
        make_probe_signal(
          ProbeSignalKind::CoveredCellCount,
          inspect.covered_cell_count,
        ),
      ]
      probe_outcome(
        "ods",
        signal_summary_lines(signals) +
        [
          probe_summary_line("max_cols", inspect.max_sheet_cols, None),
          probe_summary_line("used_cols", inspect.max_used_cols, None),
        ],
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::OdsDocument(doc, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("ods", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("ods", "probe_failed"),
      ])
  }
}

///|
fn odp_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let document = match bytes {
    Some(payload) =>
      try @dodf.open_odp_document(payload) |> Ok catch {
        err => Err(err.to_string())
      }
    None => Err("probe_unavailable")
  }
  match document {
    Ok(doc) => {
      let inspect = @dodf.inspect_odp_document(doc)
      let signals = [
        make_probe_signal(ProbeSignalKind::SlideCount, inspect.slide_count),
        make_probe_signal(ProbeSignalKind::BlockCount, inspect.block_count),
        make_probe_signal(ProbeSignalKind::NoteCount, inspect.notes_count),
        make_probe_signal(ProbeSignalKind::AssetCount, inspect.image_count),
      ]
      probe_outcome(
        "odp",
        signal_summary_lines(signals),
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::OdpDocument(doc, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("odp", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("odp", "probe_failed"),
      ])
  }
}

///|
fn pdf_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  match bytes {
    Some(_) => ()
    None =>
      return probe_outcome("pdf", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("pdf", "probe_failed"),
      ])
  }
  let native = @fpdf.extract_pdf_native_document(prepared_source)
  match native {
    Ok(document) => {
      let mut native_text_pages = 0
      let mut scanned_pages = 0
      for page in document.pages {
        let mut span_count = 0
        for block in page.text_blocks {
          for line in block.lines {
            span_count += line.spans.length()
          }
        }
        if span_count > 0 {
          native_text_pages += 1
        } else {
          scanned_pages += 1
        }
      }
      let signals = [
        make_probe_signal(ProbeSignalKind::PageCount, document.pages.length()),
        make_probe_signal(
          ProbeSignalKind::NativeTextPageCount,
          native_text_pages,
        ),
        make_probe_signal(
          ProbeSignalKind::ScannedPageCount,
          scanned_pages,
          note=Some(pdf_ocr_policy_name(options.pdf_ocr_policy)),
        ),
      ]
      let summary = [
        "pdf_ocr_policy=" + pdf_ocr_policy_name(options.pdf_ocr_policy),
        "convert_mode=" + convert_mode_name(options.mode),
        "native_text_pages=" + native_text_pages.to_string(),
        "scanned_pages=" + scanned_pages.to_string(),
      ]
      probe_outcome("pdf", summary, prepared_source, probe_signals=signals, probe_artifacts=[
        RouteProbeArtifact::PdfNativeDocument(document),
      ])
    }
    Err(_error) => {
      let signals = [
        make_probe_signal(
          ProbeSignalKind::PageCount,
          0,
          note=Some(pdf_ocr_policy_name(options.pdf_ocr_policy)),
        ),
      ]
      let summary = [
        "pdf_ocr_policy=" + pdf_ocr_policy_name(options.pdf_ocr_policy),
        "convert_mode=" + convert_mode_name(options.mode),
        "native_probe=failed",
      ]
      probe_outcome("pdf", summary, prepared_source, probe_signals=signals, probe_failures=[
        make_probe_failure("pdf", "native_probe_failed"),
      ])
    }
  }
}

///|
fn zip_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let archive = match bytes {
    Some(payload) =>
      try @dzip.open_zip(payload) |> Ok catch {
        err => Err(err.to_string())
      }
    None => Err("probe_unavailable")
  }
  match archive {
    Ok(value) => {
      let report = @dzip.inspect_zip_archive(value)
      let signals = [
        make_probe_signal(
          ProbeSignalKind::EntryCount,
          report.file_entry_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::AssetCount,
          report.inventory.entries.length(),
        ),
      ]
      probe_outcome(
        "zip",
        signal_summary_lines(signals) +
        [
          probe_summary_line(
            "decoded_bytes",
            report.total_uncompressed_size,
            None,
          ),
        ],
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::ZipArchiveInspect(value, report)],
      )
    }
    Err(_) =>
      probe_outcome("zip", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("zip", "probe_failed"),
      ])
  }
}

///|
fn epub_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let (bytes, prepared_source) = read_probe_bytes(source)
  let opened = match bytes {
    Some(payload) =>
      try @depub.open_epub_package(payload, source.source_name) |> Ok catch {
        err => Err(err.to_string())
      }
    None => Err("probe_unavailable")
  }
  match opened {
    Ok(pkg) => {
      let inspect = @depub.inspect_epub_package(pkg)
      let inventory = inspect.inventory
      let signals = [
        make_probe_signal(
          ProbeSignalKind::EntryCount,
          inventory.part_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::BlockCount,
          inventory.spine_linear_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::AssetCount,
          inventory.cover_candidate_count,
        ),
      ]
      probe_outcome(
        "epub",
        signal_summary_lines(signals) +
        [
          probe_summary_line("manifest", inventory.manifest_count, None),
          probe_summary_line("spine", inventory.spine_count, None),
        ],
        prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::EpubPackageInspect(pkg, inspect)],
      )
    }
    Err(_) =>
      probe_outcome("epub", ["probe_failed"], prepared_source, probe_failures=[
        make_probe_failure("epub", "probe_failed"),
      ])
  }
}

///|
fn generic_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  probe_outcome(
    @input.detected_format_name(format),
    [@formats.route_name(@formats.canonical_route_for_format(format))],
    source,
  )
}

///|
fn preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match format {
    @input.DetectedFormat::Markdown => markdown_preflight_probe(source, options)
    @input.DetectedFormat::Json => json_preflight_probe(source, options)
    @input.DetectedFormat::Ipynb => ipynb_preflight_probe(source, options)
    @input.DetectedFormat::Yaml => yaml_preflight_probe(source, options)
    @input.DetectedFormat::Toml => toml_preflight_probe(source, options)
    @input.DetectedFormat::Tex => text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Rst => text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Asciidoc =>
      text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Audio(_) => audio_preflight_probe(source, format)
    @input.DetectedFormat::Xml => xml_preflight_probe(source, options)
    @input.DetectedFormat::Html => html_preflight_probe(source, options)
    @input.DetectedFormat::Zip => zip_preflight_probe(source, options)
    @input.DetectedFormat::Epub => epub_preflight_probe(source, options)
    @input.DetectedFormat::Xlsx => xlsx_preflight_probe(source, options)
    @input.DetectedFormat::Odt => odt_preflight_probe(source, options)
    @input.DetectedFormat::Ods => ods_preflight_probe(source, options)
    @input.DetectedFormat::Odp => odp_preflight_probe(source, options)
    @input.DetectedFormat::Pdf => pdf_preflight_probe(source, options)
    _ => generic_preflight_probe(source, format)
  }
}
