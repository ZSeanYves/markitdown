///|
fn ipynb_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::NotebookCellOutputGroup,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn ipynb_parser() -> @parser.Parser {
  @parser.make_parser(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    ipynb_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let text = match @input.read_input_text(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let parsed = try @dipynb.parse_ipynb_notebook(text) |> Ok catch {
        e => Err(e.to_string())
      }
      match parsed {
        Ok(notebook) =>
          Ok(
            ipynb_parse_with_preparsed_notebook(
              source,
              context,
              text,
              notebook,
              @dipynb.inspect_ipynb_notebook(notebook),
            ),
          )
        Err(err) => Ok(ipynb_malformed_parse_result(source, text, context, err))
      }
    },
  )
}

///|
pub fn ipynb_parse_with_preparsed_notebook(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  notebook : @dipynb.IpynbNotebook,
  inspect : @dipynb.IpynbInspectReport,
) -> @parser.ParseResult {
  let requested_blocks = context.requested_mode ==
    Some(@parser.ParserMode::BlockStreaming)
  let diagnostics = ipynb_base_diagnostics(source, context)
  let lowered = lower_ipynb_notebook(notebook, source, diagnostics)
  ipynb_fill_metrics(diagnostics, inspect, text, lowered, requested_blocks)
  diagnostics.pass_trace.push("parse:ipynb_parser")
  if requested_blocks {
    @parser.parse_result_with_blocks_capability(
      "ipynb_parser",
      @parser.ParserMode::BlockStreaming,
      lowered.blocks,
      diagnostics,
      ipynb_parser_capability(),
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=lowered.source_map,
      assembly=lowered.assembly,
    )
  } else {
    let final_document = @core.document_with_diagnostics(lowered, diagnostics)
    @parser.parse_result_with_document_capability(
      "ipynb_parser",
      @parser.ParserMode::DomAstModel,
      final_document,
      diagnostics,
      ipynb_parser_capability(),
    )
  }
}

///|
fn ipynb_base_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "ipynb",
  )
  diagnostics.metrics.set("parser_name", "ipynb_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set("input_kind", @fshared.input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "ipynb")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set(
    "effective_mode",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_streaming"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set(
    "ir_input_kind",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  diagnostics.metrics.set(
    "event_granularity",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "notebook_cell_output_group"
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "event_semantics",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "ipynb_cell_output_block_stream"
    } else {
      "dom_ast_model"
    },
  )
  @fshared.apply_product_metrics(diagnostics, "ipynb")
  diagnostics.metrics.set("ipynb_output_selected_mime", "none")
  diagnostics
}

///|
fn ipynb_fill_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dipynb.IpynbInspectReport,
  text : String,
  document : @core.DocumentIR,
  block_streaming : Bool,
) -> Unit {
  diagnostics.metrics.set(
    "nbformat",
    inspect.nbformat.map(v => v.to_string()).unwrap_or("null"),
  )
  diagnostics.metrics.set(
    "nbformat_minor",
    inspect.nbformat_minor.map(v => v.to_string()).unwrap_or("null"),
  )
  diagnostics.metrics.set("cell_count", inspect.cell_count.to_string())
  diagnostics.metrics.set(
    "markdown_cell_count",
    inspect.markdown_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "code_cell_count",
    inspect.code_cell_count.to_string(),
  )
  diagnostics.metrics.set("raw_cell_count", inspect.raw_cell_count.to_string())
  diagnostics.metrics.set("output_count", inspect.output_count.to_string())
  diagnostics.metrics.set(
    "stream_output_count",
    inspect.stream_output_count.to_string(),
  )
  diagnostics.metrics.set(
    "display_data_count",
    inspect.display_data_count.to_string(),
  )
  diagnostics.metrics.set(
    "execute_result_count",
    inspect.execute_result_count.to_string(),
  )
  diagnostics.metrics.set(
    "error_output_count",
    inspect.error_output_count.to_string(),
  )
  diagnostics.metrics.set(
    "attachment_count",
    inspect.attachment_count.to_string(),
  )
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set(
    "max_cell_source_chars",
    inspect.max_cell_source_chars.to_string(),
  )
  diagnostics.metrics.set(
    "max_output_text_chars",
    inspect.max_output_text_chars.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "builder_input_kind",
    if block_streaming {
      "block_stream"
    } else {
      "document"
    },
  )
}

///|
fn lower_ipynb_notebook(
  notebook : @dipynb.IpynbNotebook,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.document_with_source_map(
    @core.document_with_metadata(
      @core.empty_document_ir(),
      ipynb_document_metadata(notebook),
    ),
    Some(@core.empty_source_map()),
  )
  document.blocks.push(ipynb_summary_table_block(notebook, source))
  for cell in notebook.cells {
    document.blocks.append(
      lower_ipynb_cell(cell, notebook, source, diagnostics, document)[:],
    )
  }
  document
}

///|
fn ipynb_document_metadata(
  notebook : @dipynb.IpynbNotebook,
) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", @core.JsonValue::String("ipynb"))
  match notebook.summary.nbformat {
    Some(value) =>
      metadata.set("nbformat", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match notebook.summary.nbformat_minor {
    Some(value) =>
      metadata.set("nbformat_minor", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match notebook.summary.kernelspec_display_name {
    Some(value) => metadata.set("title", @core.JsonValue::String(value))
    None => ()
  }
  metadata.set(
    "description",
    @core.JsonValue::String(
      "Jupyter notebook with " + notebook.cells.length().to_string() + " cells",
    ),
  )
  metadata
}

///|
fn ipynb_summary_table_block(
  notebook : @dipynb.IpynbNotebook,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=ipynb_source_ref(
      source,
      "/",
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
    ),
  )
  let rows : Array[Array[String]] = [
    ["Field", "Value"],
    [
      "nbformat",
      notebook.summary.nbformat.map(v => v.to_string()).unwrap_or("null"),
    ],
    [
      "nbformat_minor",
      notebook.summary.nbformat_minor.map(v => v.to_string()).unwrap_or("null"),
    ],
    ["cells", notebook.summary.cell_count.to_string()],
  ]
  match notebook.summary.kernelspec_name {
    Some(value) => rows.push(["kernelspec.name", value])
    None => ()
  }
  match notebook.summary.kernelspec_display_name {
    Some(value) => rows.push(["kernelspec.display_name", value])
    None => ()
  }
  match notebook.summary.language_name {
    Some(value) => rows.push(["language_info.name", value])
    None => ()
  }
  match notebook.summary.language_version {
    Some(value) => rows.push(["language_info.version", value])
    None => ()
  }
  for i in 0..<rows.length() {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=ipynb_source_ref(
        source,
        "/",
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
      ),
    )
    for cell_text in rows[i] {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          cell_text,
          source_ref=ipynb_source_ref(
            source,
            "/",
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
          ),
        ),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn lower_ipynb_cell(
  cell : @dipynb.IpynbCell,
  notebook : @dipynb.IpynbNotebook,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  blocks.push(ipynb_cell_label_block(cell, source))
  let language = ipynb_code_language(cell, notebook)
  match cell.kind {
    @dipynb.IpynbCellKind::Markdown =>
      blocks.append(lower_ipynb_markdown_cell(cell, source, diagnostics)[:])
    @dipynb.IpynbCellKind::Code =>
      blocks.push(ipynb_code_block(cell.source, source, cell, language))
    @dipynb.IpynbCellKind::Raw | @dipynb.IpynbCellKind::Unknown =>
      blocks.push(ipynb_raw_block(cell.source, source, cell))
  }
  for attachment in cell.attachments {
    let lowered = lower_ipynb_attachment(attachment, cell, source, document)
    blocks.append(lowered[:])
  }
  for i in 0..<cell.outputs.length() {
    blocks.append(
      lower_ipynb_output(
        cell,
        cell.outputs[i],
        i,
        source,
        diagnostics,
        document,
      )[:],
    )
  }
  blocks
}

///|
fn lower_ipynb_markdown_cell(
  cell : @dipynb.IpynbCell,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
) -> Array[@core.CoreBlock] {
  let rewritten = ipynb_rewrite_attachment_refs(cell.source, cell)
  let parse_source = @input.input_from_text_with_format(
    rewritten,
    source.source_name,
    Some(@input.DetectedFormat::Markdown),
  )
  let parser = @fmarkdown.markdown_parser()
  let result = (parser.parse)(
    parse_source,
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
  )
  match result {
    Ok(parsed) =>
      match parsed.document {
        Some(doc) => {
          let blocks : Array[@core.CoreBlock] = []
          for block in doc.blocks {
            blocks.push(ipynb_rebind_markdown_block(block, source, cell))
          }
          blocks
        }
        None => [ipynb_raw_block(rewritten, source, cell)]
      }
    Err(_) => {
      diagnostics.warnings.push(
        "ipynb markdown cell " +
        (cell.index + 1).to_string() +
        " fell back to raw markdown text",
      )
      diagnostics.degraded_features.push("ipynb_markdown_cell_raw_fallback")
      [ipynb_raw_block(rewritten, source, cell)]
    }
  }
}

///|
fn lower_ipynb_output(
  cell : @dipynb.IpynbCell,
  output : @dipynb.IpynbOutput,
  output_index : Int,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let output_kind_name = ipynb_output_kind_name(output.kind)
  blocks.push(ipynb_output_label_block(cell, output, output_index, source))
  match output.kind {
    @dipynb.IpynbOutputKind::Stream =>
      blocks.push(
        ipynb_fenced_text_block(
          output.text.unwrap_or(""),
          source,
          cell,
          Some(output_index),
          Some(output_kind_name),
          "text",
        ),
      )
    @dipynb.IpynbOutputKind::Error => {
      let text = if output.traceback.length() > 0 {
        output.traceback.join("")
      } else {
        output.ename.unwrap_or("error") + ": " + output.evalue.unwrap_or("")
      }
      blocks.push(
        ipynb_fenced_text_block(
          text,
          source,
          cell,
          Some(output_index),
          Some(output_kind_name),
          "text",
        ),
      )
    }
    _ => {
      let mime_blocks = lower_ipynb_mime_entries(
        output.mime_entries,
        source,
        cell,
        output.json_pointer,
        Some(output_index),
        Some(output_kind_name),
        diagnostics,
        document,
      )
      if mime_blocks.length() > 0 {
        blocks.append(mime_blocks[:])
      } else if output.text is Some(text) {
        blocks.push(
          ipynb_plain_or_fenced_text_block(
            text,
            source,
            cell,
            Some(output_index),
            Some(output_kind_name),
          ),
        )
      } else {
        diagnostics.warnings.push(
          "ipynb output " +
          (cell.index + 1).to_string() +
          "." +
          (output_index + 1).to_string() +
          " has no supported visible payload",
        )
        diagnostics.degraded_features.push("ipynb_output_empty_visible_payload")
      }
    }
  }
  blocks
}

///|
fn lower_ipynb_mime_entries(
  entries : Array[@dipynb.IpynbMimeEntry],
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_json_pointer : String,
  output_index : Int?,
  output_kind : String?,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
) -> Array[@core.CoreBlock] {
  let preferred = ipynb_preferred_mime_entry(entries)
  match preferred {
    Some(entry) => {
      diagnostics.metrics.set("ipynb_output_selected_mime", entry.mime_type)
      lower_ipynb_mime_entry(
        entry, source, cell, output_json_pointer, output_index, output_kind, diagnostics,
        document,
      )
    }
    None => []
  }
}

///|
fn lower_ipynb_mime_entry(
  entry : @dipynb.IpynbMimeEntry,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_json_pointer : String,
  output_index : Int?,
  output_kind : String?,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
) -> Array[@core.CoreBlock] {
  if ipynb_mime_is_image(entry.mime_type) {
    return [
      ipynb_materialize_image_asset(
        entry, source, cell, output_json_pointer, output_index, output_kind, document,
      ),
    ]
  }
  if entry.mime_type == "text/markdown" {
    match entry.text {
      Some(text) => {
        let parse_source = @input.input_from_text_with_format(
          text,
          source.source_name,
          Some(@input.DetectedFormat::Markdown),
        )
        let parser = @fmarkdown.markdown_parser()
        let result = (parser.parse)(
          parse_source,
          @parser.new_parse_context(@input.DetectedFormat::Markdown),
        )
        match result {
          Ok(parsed) =>
            match parsed.document {
              Some(doc) =>
                return doc.blocks.map(block => {
                  ipynb_rebind_output_block_source_ref(
                    block, source, cell, output_json_pointer, output_index, output_kind,
                  )
                })
              None => ()
            }
          Err(_) => ()
        }
      }
      None => ()
    }
  }
  if entry.mime_type == "text/html" {
    match entry.text {
      Some(text) =>
        match
          @fhtml.html_document_to_ir(
            @input.input_from_text_with_format(
              text,
              source.source_name,
              Some(@input.DetectedFormat::Html),
            ),
            text,
          ) {
          Ok((doc, _)) => {
            let lowered = doc.blocks.map(block => {
              ipynb_rebind_output_block_source_ref(
                block, source, cell, output_json_pointer, output_index, output_kind,
              )
            })
            if lowered.length() > 0 {
              return lowered
            }
            diagnostics.warnings.push(
              "ipynb html output had no visible html blocks and fell back to raw fenced html",
            )
            diagnostics.degraded_features.push(
              "ipynb_html_output_empty_visible_payload",
            )
            return [
              ipynb_fenced_text_block(
                text, source, cell, output_index, output_kind, "html",
              ),
            ]
          }
          Err(_) => {
            diagnostics.warnings.push(
              "ipynb html output fell back to raw fenced html",
            )
            diagnostics.degraded_features.push("ipynb_html_output_raw_fallback")
            return [
              ipynb_fenced_text_block(
                text, source, cell, output_index, output_kind, "html",
              ),
            ]
          }
        }
      None => ()
    }
  }
  if entry.mime_type == "application/javascript" ||
    entry.mime_type == "text/javascript" {
    match entry.text {
      Some(text) => {
        diagnostics.degraded_features.push(
          "ipynb_javascript_output_raw_fallback",
        )
        return [
          ipynb_fenced_text_block(
            text, source, cell, output_index, output_kind, "javascript",
          ),
        ]
      }
      None => ()
    }
  }
  if entry.mime_type == "application/json" || entry.mime_type.contains("+json") {
    let text = entry.raw_json_text.unwrap_or(entry.text.unwrap_or(""))
    let parse_source = @input.input_from_text_with_format(
      text,
      source.source_name,
      Some(@input.DetectedFormat::Json),
    )
    let parser = @fjson.json_parser()
    let result = (parser.parse)(
      parse_source,
      @parser.new_parse_context(@input.DetectedFormat::Json),
    )
    match result {
      Ok(parsed) =>
        match parsed.document {
          Some(doc) =>
            return doc.blocks.map(block => {
              ipynb_rebind_output_block_source_ref(
                block, source, cell, output_json_pointer, output_index, output_kind,
              )
            })
          None => ()
        }
      Err(_) =>
        diagnostics.degraded_features.push(
          "ipynb_structured_json_output_raw_fallback",
        )
    }
  }
  if entry.mime_type == "text/plain" {
    match entry.text {
      Some(text) =>
        return [
          ipynb_plain_or_fenced_text_block(
            text, source, cell, output_index, output_kind,
          ),
        ]
      None => ()
    }
  }
  let fallback_text = entry.text.unwrap_or(entry.raw_json_text.unwrap_or(""))
  diagnostics.warnings.push(
    "ipynb output MIME " + entry.mime_type + " fell back to raw fenced block",
  )
  if entry.mime_type == "application/json" || entry.mime_type.contains("+json") {
    diagnostics.degraded_features.push(
      "ipynb_structured_json_output_raw_fallback",
    )
  } else {
    diagnostics.degraded_features.push("ipynb_output_unknown_mime_raw_fallback")
  }
  [
    ipynb_fenced_text_block(
      fallback_text,
      source,
      cell,
      output_index,
      output_kind,
      ipynb_info_from_mime(entry.mime_type),
    ),
  ]
}

///|
fn ipynb_materialize_image_asset(
  entry : @dipynb.IpynbMimeEntry,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_json_pointer : String,
  output_index : Int?,
  output_kind : String?,
  document : @core.DocumentIR,
) -> @core.CoreBlock {
  let asset_id = ipynb_output_image_asset_path(
    cell,
    output_index,
    entry.mime_type,
  )
  let source_ref = ipynb_source_ref(
    source,
    output_json_pointer,
    Some(cell.index),
    Some(ipynb_cell_kind_name(cell.kind)),
    cell.cell_id,
    output_index,
    cell.execution_count,
    output_kind,
    None,
    Some(entry.mime_type),
  )
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = {
    ..asset,
    path: Some(asset_id),
    mime_type: Some(entry.mime_type),
  }
  ipynb_attach_inline_payload(next_asset, entry)
  document.assets.push(next_asset)
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("asset_id", asset_id)
  block.attrs.set("path", asset_id)
  block.attrs.set("alt", "notebook image")
  block
}

///|
fn lower_ipynb_attachment(
  attachment : @dipynb.IpynbAttachment,
  cell : @dipynb.IpynbCell,
  source : @input.InputSource,
  document : @core.DocumentIR,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for entry in attachment.mime_entries {
    if ipynb_mime_is_image(entry.mime_type) {
      let asset_id = ipynb_attachment_entry_asset_path(cell, attachment, entry)
      let source_ref = ipynb_source_ref(
        source,
        cell.json_pointer + "/attachments/" + attachment.name,
        Some(cell.index),
        Some(ipynb_cell_kind_name(cell.kind)),
        cell.cell_id,
        None,
        None,
        None,
        Some(attachment.name),
        Some(entry.mime_type),
      )
      let asset = @core.make_asset_ref(
        @core.AssetKind::Image,
        asset_id,
        source_ref~,
      )
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: Some(entry.mime_type),
      }
      ipynb_attach_inline_payload(next_asset, entry)
      document.assets.push(next_asset)
      let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
      image.attrs.set("asset_id", asset_id)
      image.attrs.set("path", asset_id)
      image.attrs.set("alt", attachment.name)
      blocks.push(image)
    } else {
      let asset_id = ipynb_attachment_entry_asset_path(cell, attachment, entry)
      let source_ref = ipynb_source_ref(
        source,
        cell.json_pointer + "/attachments/" + attachment.name,
        Some(cell.index),
        Some(ipynb_cell_kind_name(cell.kind)),
        cell.cell_id,
        None,
        None,
        None,
        Some(attachment.name),
        Some(entry.mime_type),
      )
      let asset = @core.make_asset_ref(
        @core.AssetKind::Attachment,
        asset_id,
        source_ref~,
      )
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: Some(entry.mime_type),
      }
      ipynb_attach_inline_payload(next_asset, entry)
      document.assets.push(next_asset)
      blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          "[Attachment: " + attachment.name + " | " + entry.mime_type + "]",
          source_ref~,
        ),
      )
    }
  }
  blocks
}

///|
fn ipynb_cell_label_block(
  cell : @dipynb.IpynbCell,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let label = if cell.kind == @dipynb.IpynbCellKind::Code &&
    cell.execution_count is Some(count) {
    "[Cell " +
    (cell.index + 1).to_string() +
    " | code | execution=" +
    count.to_string() +
    "]"
  } else {
    "[Cell " +
    (cell.index + 1).to_string() +
    " | " +
    ipynb_cell_kind_name(cell.kind) +
    "]"
  }
  @core.make_block(
    @core.BlockKind::Paragraph,
    label,
    source_ref=ipynb_source_ref(
      source,
      cell.json_pointer,
      Some(cell.index),
      Some(ipynb_cell_kind_name(cell.kind)),
      cell.cell_id,
      None,
      cell.execution_count,
      None,
      None,
      None,
    ),
  )
}

///|
fn ipynb_output_label_block(
  cell : @dipynb.IpynbCell,
  output : @dipynb.IpynbOutput,
  output_index : Int,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let flavor = match output.kind {
    @dipynb.IpynbOutputKind::Stream => output.name.unwrap_or("stdout")
    @dipynb.IpynbOutputKind::DisplayData =>
      ipynb_preferred_mime_label(output.mime_entries)
    @dipynb.IpynbOutputKind::ExecuteResult =>
      ipynb_preferred_mime_label(output.mime_entries)
    @dipynb.IpynbOutputKind::Error => output.ename.unwrap_or("error")
    @dipynb.IpynbOutputKind::Unknown => output.output_type
  }
  @core.make_block(
    @core.BlockKind::Paragraph,
    "[Output " +
    (cell.index + 1).to_string() +
    "." +
    (output_index + 1).to_string() +
    " | " +
    ipynb_output_kind_name(output.kind) +
    " | " +
    flavor +
    "]",
    source_ref=ipynb_source_ref(
      source,
      output.json_pointer,
      Some(cell.index),
      Some(ipynb_cell_kind_name(cell.kind)),
      cell.cell_id,
      Some(output_index),
      output.execution_count,
      Some(ipynb_output_kind_name(output.kind)),
      None,
      None,
    ),
  )
}

///|
fn ipynb_code_block(
  text : String,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  language : String?,
) -> @core.CoreBlock {
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=ipynb_source_ref(
      source,
      cell.json_pointer + "/source",
      Some(cell.index),
      Some(ipynb_cell_kind_name(cell.kind)),
      cell.cell_id,
      None,
      cell.execution_count,
      None,
      None,
      None,
    ),
  )
  match language {
    Some(info) if info != "" => block.attrs.set("info", info)
    _ => ()
  }
  block
}

///|
fn ipynb_raw_block(
  text : String,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
) -> @core.CoreBlock {
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=ipynb_source_ref(
      source,
      cell.json_pointer + "/source",
      Some(cell.index),
      Some(ipynb_cell_kind_name(cell.kind)),
      cell.cell_id,
      None,
      cell.execution_count,
      None,
      None,
      None,
    ),
  )
  block.attrs.set("info", "text")
  block
}

///|
fn ipynb_plain_or_fenced_text_block(
  text : String,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_index : Int?,
  output_kind : String?,
) -> @core.CoreBlock {
  if text.contains("\n") {
    ipynb_fenced_text_block(
      text, source, cell, output_index, output_kind, "text",
    )
  } else {
    @core.make_block(
      @core.BlockKind::Paragraph,
      text,
      source_ref=ipynb_source_ref(
        source,
        cell.json_pointer + "/outputs",
        Some(cell.index),
        Some(ipynb_cell_kind_name(cell.kind)),
        cell.cell_id,
        output_index,
        cell.execution_count,
        output_kind,
        None,
        None,
      ),
    )
  }
}

///|
fn ipynb_fenced_text_block(
  text : String,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_index : Int?,
  output_kind : String?,
  info : String,
) -> @core.CoreBlock {
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=ipynb_source_ref(
      source,
      cell.json_pointer + "/outputs",
      Some(cell.index),
      Some(ipynb_cell_kind_name(cell.kind)),
      cell.cell_id,
      output_index,
      cell.execution_count,
      output_kind,
      None,
      None,
    ),
  )
  block.attrs.set("info", info)
  block
}

///|
fn ipynb_source_ref(
  source : @input.InputSource,
  json_pointer : String,
  cell_index : Int?,
  cell_kind : String?,
  cell_id : String?,
  output_index : Int?,
  execution_count : Int?,
  output_kind : String?,
  attachment_name : String?,
  mime_type : String?,
) -> @core.SourceRef {
  let source_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("ipynb"),
    Some(json_pointer),
  )
  let with_cell = match cell_index {
    Some(value) =>
      @core.source_ref_with_extra(
        source_ref,
        "ipynb_cell_index",
        value.to_string(),
      )
    None => source_ref
  }
  let with_kind = match cell_kind {
    Some(value) =>
      @core.source_ref_with_extra(with_cell, "ipynb_cell_kind", value)
    None => with_cell
  }
  let with_id = match cell_id {
    Some(value) =>
      @core.source_ref_with_extra(with_kind, "ipynb_cell_id", value)
    None => with_kind
  }
  let with_output = match output_index {
    Some(value) =>
      @core.source_ref_with_extra(
        with_id,
        "ipynb_output_index",
        value.to_string(),
      )
    None => with_id
  }
  let with_exec = match execution_count {
    Some(value) =>
      @core.source_ref_with_extra(
        with_output,
        "ipynb_execution_count",
        value.to_string(),
      )
    None => with_output
  }
  let with_output_kind = match output_kind {
    Some(value) =>
      @core.source_ref_with_extra(with_exec, "ipynb_output_kind", value)
    None => with_exec
  }
  let with_attachment = match attachment_name {
    Some(value) =>
      @core.source_ref_with_extra(
        with_output_kind, "ipynb_attachment_name", value,
      )
    None => with_output_kind
  }
  match mime_type {
    Some(value) =>
      @core.source_ref_with_extra(with_attachment, "ipynb_mime_type", value)
    None => with_attachment
  }
}

///|
fn ipynb_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  context : @parser.ParseContext,
  err : String,
) -> @parser.ParseResult {
  let diagnostics = ipynb_base_diagnostics(source, context)
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=@core.source_ref_with_lines(
      ipynb_source_ref(
        source,
        "/",
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
      ),
      Some(source.source_name),
      Some("ipynb"),
      Some(1),
      Some(@fshared.count_physical_lines(text)),
    ),
  )
  block.attrs.set("info", "json")
  diagnostics.warnings.push("ipynb parse warning: " + err)
  diagnostics.degraded_features.push("ipynb_raw_fenced_fallback")
  diagnostics.fallback_trace.push("ipynb parse failed -> raw fenced block")
  diagnostics.metrics.set("nbformat", "null")
  diagnostics.metrics.set("nbformat_minor", "null")
  diagnostics.metrics.set("cell_count", "0")
  diagnostics.metrics.set("markdown_cell_count", "0")
  diagnostics.metrics.set("code_cell_count", "0")
  diagnostics.metrics.set("raw_cell_count", "0")
  diagnostics.metrics.set("output_count", "0")
  diagnostics.metrics.set("stream_output_count", "0")
  diagnostics.metrics.set("display_data_count", "0")
  diagnostics.metrics.set("execute_result_count", "0")
  diagnostics.metrics.set("error_output_count", "0")
  diagnostics.metrics.set("attachment_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("max_cell_source_chars", "0")
  diagnostics.metrics.set("max_output_text_chars", "0")
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "builder_input_kind",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  diagnostics.pass_trace.push("parse:ipynb_parser")
  let document = @core.document_from_blocks([block])
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    ipynb_parser_capability(),
  )
}

///|
fn ipynb_code_language(
  cell : @dipynb.IpynbCell,
  notebook : @dipynb.IpynbNotebook,
) -> String? {
  let lines = cell.source.split("\n").to_array()
  if lines.length() > 0 {
    let first = lines[0].trim()
    if first.has_prefix("%%") && first.length() > 2 {
      let body = first[2:].trim().to_owned()
      if body != "" {
        let parts = body.split(" ").to_array()
        return Some(parts[0].trim().to_owned())
      }
    }
  }
  notebook.summary.language_name
}

///|
fn ipynb_rewrite_attachment_refs(
  text : String,
  cell : @dipynb.IpynbCell,
) -> String {
  let mut out = text
  for attachment in cell.attachments {
    let asset_path = ipynb_attachment_asset_path(cell, attachment)
    out = out.replace_all(old="attachment:" + attachment.name, new=asset_path)
  }
  out
}

///|
fn ipynb_output_image_asset_path(
  cell : @dipynb.IpynbCell,
  output_index : Int?,
  mime_type : String,
) -> String {
  if output_index is Some(index) {
    "assets/ipynb-cell" +
    ipynb_pad2(cell.index + 1) +
    "-output" +
    ipynb_pad2(index + 1) +
    ipynb_mime_ext(mime_type)
  } else {
    "assets/ipynb-cell" +
    ipynb_pad2(cell.index + 1) +
    "-attachment-inline" +
    ipynb_mime_ext(mime_type)
  }
}

///|
fn ipynb_attachment_asset_path(
  cell : @dipynb.IpynbCell,
  attachment : @dipynb.IpynbAttachment,
) -> String {
  "assets/ipynb-cell" +
  ipynb_pad2(cell.index + 1) +
  "-attachment-" +
  ipynb_slug(attachment.name) +
  ipynb_attachment_ext(attachment)
}

///|
fn ipynb_attachment_entry_asset_path(
  cell : @dipynb.IpynbCell,
  attachment : @dipynb.IpynbAttachment,
  entry : @dipynb.IpynbMimeEntry,
) -> String {
  "assets/ipynb-cell" +
  ipynb_pad2(cell.index + 1) +
  "-attachment-" +
  ipynb_slug(attachment.name) +
  ipynb_asset_ext_for_entry(entry)
}

///|
fn ipynb_asset_ext_for_entry(entry : @dipynb.IpynbMimeEntry) -> String {
  if ipynb_mime_is_image(entry.mime_type) {
    ipynb_mime_ext(entry.mime_type)
  } else if entry.mime_type == "application/json" ||
    entry.mime_type.contains("+json") {
    ".json"
  } else if entry.mime_type == "text/plain" {
    ".txt"
  } else if entry.mime_type == "text/markdown" {
    ".md"
  } else if entry.mime_type == "text/html" {
    ".html"
  } else if entry.mime_type == "text/latex" {
    ".tex"
  } else {
    ".bin"
  }
}

///|
fn ipynb_attach_inline_payload(
  asset : @core.AssetRef,
  entry : @dipynb.IpynbMimeEntry,
) -> Unit {
  match ipynb_inline_payload(entry) {
    Some((kind, payload)) => {
      asset.attrs.set("inline_payload_kind", kind)
      asset.attrs.set("inline_payload", payload)
    }
    None => ()
  }
}

///|
fn ipynb_inline_payload(entry : @dipynb.IpynbMimeEntry) -> (String, String)? {
  if entry.mime_type == "image/svg+xml" {
    match entry.text {
      Some(payload) => return Some(("utf8", payload))
      None => ()
    }
  }
  if ipynb_mime_is_image(entry.mime_type) {
    match entry.text {
      Some(payload) => {
        let normalized = payload
          .replace_all(old="\n", new="")
          .replace_all(old="\r", new="")
        if normalized != "" {
          return Some(("base64", normalized))
        }
      }
      None => ()
    }
  }
  if entry.mime_type == "application/json" || entry.mime_type.contains("+json") {
    match entry.raw_json_text {
      Some(payload) => return Some(("utf8", payload))
      None => ()
    }
  }
  if entry.mime_type.has_prefix("text/") {
    match entry.text {
      Some(payload) => return Some(("utf8", payload))
      None => ()
    }
  }
  match entry.text {
    Some(payload) => {
      let normalized = payload
        .replace_all(old="\n", new="")
        .replace_all(old="\r", new="")
      if normalized != "" {
        Some(("base64", normalized))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn ipynb_rebind_block_source_ref(
  block : @core.CoreBlock,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
) -> @core.CoreBlock {
  let rebound_ref = ipynb_source_ref(
    source,
    cell.json_pointer + "/source",
    Some(cell.index),
    Some(ipynb_cell_kind_name(cell.kind)),
    cell.cell_id,
    None,
    cell.execution_count,
    None,
    None,
    None,
  )
  let children : Array[@core.CoreBlock] = []
  if block.children.length() > 0 {
    for child in block.children {
      children.push(ipynb_rebind_block_source_ref(child, source, cell))
    }
  }
  { ..block, source_ref: Some(rebound_ref), children }
}

///|
fn ipynb_rebind_markdown_block(
  block : @core.CoreBlock,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
) -> @core.CoreBlock {
  let rebound = ipynb_rebind_block_source_ref(block, source, cell)
  if rebound.kind == @core.BlockKind::Image {
    let next = { ..rebound }
    let alt = next.attrs.get("alt").unwrap_or("").trim().to_owned()
    match ipynb_attachment_for_alt(cell.attachments, alt) {
      Some(attachment) => {
        let path = ipynb_attachment_asset_path(cell, attachment)
        next.attrs.set("path", path)
      }
      None => ()
    }
    next
  } else {
    rebound
  }
}

///|
fn ipynb_rebind_output_block_source_ref(
  block : @core.CoreBlock,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  output_json_pointer : String,
  output_index : Int?,
  output_kind : String?,
) -> @core.CoreBlock {
  let rebound_ref = ipynb_source_ref(
    source,
    output_json_pointer,
    Some(cell.index),
    Some(ipynb_cell_kind_name(cell.kind)),
    cell.cell_id,
    output_index,
    cell.execution_count,
    output_kind,
    None,
    None,
  )
  let children : Array[@core.CoreBlock] = []
  if block.children.length() > 0 {
    for child in block.children {
      children.push(
        ipynb_rebind_output_block_source_ref(
          child, source, cell, output_json_pointer, output_index, output_kind,
        ),
      )
    }
  }
  { ..block, source_ref: Some(rebound_ref), children }
}

///|
fn ipynb_attachment_for_alt(
  attachments : Array[@dipynb.IpynbAttachment],
  alt : String,
) -> @dipynb.IpynbAttachment? {
  for attachment in attachments {
    if attachment.name == alt ||
      attachment.name == alt + ".png" ||
      attachment.name == alt + ".jpg" ||
      attachment.name == alt + ".jpeg" ||
      attachment.name == alt + ".gif" ||
      attachment.name == alt + ".svg" {
      return Some(attachment)
    }
  }
  None
}

///|
fn ipynb_cell_kind_name(kind : @dipynb.IpynbCellKind) -> String {
  match kind {
    @dipynb.IpynbCellKind::Markdown => "markdown"
    @dipynb.IpynbCellKind::Code => "code"
    @dipynb.IpynbCellKind::Raw => "raw"
    @dipynb.IpynbCellKind::Unknown => "unknown"
  }
}

///|
fn ipynb_output_kind_name(kind : @dipynb.IpynbOutputKind) -> String {
  match kind {
    @dipynb.IpynbOutputKind::Stream => "stream"
    @dipynb.IpynbOutputKind::DisplayData => "display_data"
    @dipynb.IpynbOutputKind::ExecuteResult => "execute_result"
    @dipynb.IpynbOutputKind::Error => "error"
    @dipynb.IpynbOutputKind::Unknown => "unknown"
  }
}

///|
fn ipynb_preferred_mime_entry(
  entries : Array[@dipynb.IpynbMimeEntry],
) -> @dipynb.IpynbMimeEntry? {
  let order = [
    "image/png", "image/jpeg", "image/gif", "image/svg+xml", "text/markdown", "text/html",
    "application/javascript", "text/javascript", "application/json",
  ]
  for target in order {
    for entry in entries {
      if entry.mime_type == target {
        return Some(entry)
      }
    }
  }
  for entry in entries {
    if entry.mime_type.contains("+json") {
      return Some(entry)
    }
  }
  for target in ["text/plain", "text/latex"] {
    for entry in entries {
      if entry.mime_type == target {
        return Some(entry)
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries[0])
  }
}

///|
fn ipynb_preferred_mime_label(
  entries : Array[@dipynb.IpynbMimeEntry],
) -> String {
  match ipynb_preferred_mime_entry(entries) {
    Some(entry) => entry.mime_type
    None => "none"
  }
}

///|
fn ipynb_mime_is_image(mime_type : String) -> Bool {
  mime_type == "image/png" ||
  mime_type == "image/jpeg" ||
  mime_type == "image/gif" ||
  mime_type == "image/svg+xml"
}

///|
fn ipynb_mime_ext(mime_type : String) -> String {
  match mime_type {
    "image/png" => ".png"
    "image/jpeg" => ".jpg"
    "image/gif" => ".gif"
    "image/svg+xml" => ".svg"
    _ => ".bin"
  }
}

///|
fn ipynb_info_from_mime(mime_type : String) -> String {
  match mime_type {
    "text/html" => "html"
    "text/latex" => "latex"
    "application/json" => "json"
    _ => if mime_type.contains("+json") { "json" } else { "text" }
  }
}

///|
fn ipynb_slug(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_hyphen = false
  for ch in text.trim().to_lower() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out.write_char(ch)
      prev_hyphen = false
    } else if !prev_hyphen {
      out.write_char('-')
      prev_hyphen = true
    }
  }
  let built = ipynb_trim_hyphens(out.to_string())
  if built == "" {
    "attachment"
  } else {
    built
  }
}

///|
fn ipynb_attachment_ext(attachment : @dipynb.IpynbAttachment) -> String {
  for entry in attachment.mime_entries {
    if ipynb_mime_is_image(entry.mime_type) {
      return ipynb_mime_ext(entry.mime_type)
    }
  }
  ".bin"
}

///|
fn ipynb_trim_hyphens(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && chars[start] == '-' {
    start += 1
  }
  while end > start && chars[end - 1] == '-' {
    end -= 1
  }
  if start >= end {
    ""
  } else if start == 0 && end == chars.length() {
    text
  } else {
    String::from_array(chars[start:end])
  }
}

///|
fn ipynb_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
