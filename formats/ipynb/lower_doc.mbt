///|
fn lower_ipynb_notebook(
  notebook : @dipynb.IpynbNotebook,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  large_literal_markdown : Bool,
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
      lower_ipynb_cell(
        cell, notebook, source, diagnostics, document, large_literal_markdown,
      )[:],
    )
  }
  document
}

///|
fn ipynb_document_metadata(
  notebook : @dipynb.IpynbNotebook,
) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", String("ipynb"))
  match notebook.summary.nbformat {
    Some(value) => metadata.set("nbformat", Number(value.to_string()))
    None => ()
  }
  match notebook.summary.nbformat_minor {
    Some(value) => metadata.set("nbformat_minor", Number(value.to_string()))
    None => ()
  }
  match notebook.summary.kernelspec_display_name {
    Some(value) => metadata.set("title", String(value))
    None => ()
  }
  metadata.set(
    "description",
    String(
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
    Table,
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
      TableRow,
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
          TableCell,
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
  large_literal_markdown : Bool,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let language = ipynb_code_language(cell, notebook)
  if large_literal_markdown && cell.kind == Markdown {
    blocks.push(lower_ipynb_large_markdown_cell(cell, source))
  } else {
    blocks.push(ipynb_cell_label_block(cell, source))
    match cell.kind {
      Markdown =>
        blocks.append(
          lower_ipynb_markdown_cell(
            cell, source, diagnostics, large_literal_markdown,
          )[:],
        )
      Code => blocks.push(ipynb_code_block(cell.source, source, cell, language))
      Raw | Unknown => blocks.push(ipynb_raw_block(cell.source, source, cell))
    }
  }
  for attachment in cell.attachments {
    let lowered = lower_ipynb_attachment(attachment, cell, source, document)
    blocks.append(lowered[:])
  }
  let visible_outputs = ipynb_visible_outputs(cell.outputs)
  for i in 0..<visible_outputs.length() {
    blocks.append(
      lower_ipynb_output(
        cell,
        visible_outputs[i],
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
fn lower_ipynb_large_markdown_cell(
  cell : @dipynb.IpynbCell,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let rewritten = ipynb_rewrite_attachment_refs(cell.source, cell)
  let text = ipynb_cell_label_text(cell) + "\n\n" + rewritten
  let source_ref = ipynb_source_ref(
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
  source_ref.extra.set("ipynb_cell_label_json_pointer", cell.json_pointer)
  source_ref.extra.set("ipynb_compact_cell", "true")
  {
    block_id: "b_ipynb_compact_cell_" + cell.index.to_string(),
    kind: Raw,
    text,
    column_index: None,
    rich_inlines: None,
    children: [],
    attrs: Map([("raw_kind", "markdown_literal")]),
    source_ref: Some(source_ref),
    compact_source_ref: None,
    style: None,
    signals: [],
  }
}

///|
fn ipynb_visible_outputs(
  outputs : Array[@dipynb.IpynbOutput],
) -> Array[@dipynb.IpynbOutput] {
  let visible : Array[@dipynb.IpynbOutput] = []
  for output in outputs {
    if output.output_type == "clear_output" {
      visible.clear()
      continue
    }
    if output.output_type == "update_display_data" &&
      output.display_id is Some(id) {
      let mut replaced = false
      for index in 0..<visible.length() {
        if visible[index].display_id == Some(id) {
          visible[index] = output
          replaced = true
          break
        }
      }
      if !replaced {
        visible.push(output)
      }
      continue
    }
    visible.push(output)
  }
  visible
}

///|
fn lower_ipynb_markdown_cell(
  cell : @dipynb.IpynbCell,
  source : @input.InputSource,
  _diagnostics : @core.Diagnostics,
  large_literal_markdown : Bool,
) -> Array[@core.CoreBlock] {
  let rewritten = ipynb_rewrite_attachment_refs(cell.source, cell)
  let markdown_source_ref = ipynb_source_ref(
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
  if large_literal_markdown {
    let block = @core.make_block(Raw, rewritten, source_ref=markdown_source_ref)
    block.attrs.set("raw_kind", "markdown_literal")
    block.attrs.set("literal", "true")
    return [ipynb_finalize_markdown_block(block, cell)]
  }
  let parse_source = @input.input_from_text_with_format(
    rewritten,
    source.source_name,
    Some(Markdown),
  )
  let scanned = @dmd.scan_markdown_document(rewritten)
  let markdown_blocks = @fmarkdown.markdown_blocks_from_scanned_document_light_with_source_ref(
    parse_source,
    scanned,
    Some(markdown_source_ref),
  )
  markdown_blocks.map(block => ipynb_finalize_markdown_block(block, cell))
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
    Stream =>
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
    Error => {
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
          Some(Markdown),
        )
        let scanned = @dmd.scan_markdown_document(text)
        let parsed = @fmarkdown.markdown_parse_with_scanned_document(
          parse_source,
          @parser.new_parse_context(Markdown),
          scanned,
          @dmd.inspect_markdown_document(scanned),
        )
        match parsed.document {
          Some(doc) =>
            return doc.blocks.map(block => {
              ipynb_rebind_output_block_source_ref(
                block, source, cell, output_json_pointer, output_index, output_kind,
              )
            })
          None => ()
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
              Some(Html),
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
      Some(Json),
    )
    let parser = @fjson.json_parser()
    let result = (parser.parse)(parse_source, @parser.new_parse_context(Json))
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
  let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
  let next_asset = {
    ..asset,
    path: Some(asset_id),
    mime_type: Some(entry.mime_type),
  }
  ipynb_attach_asset_payload(next_asset, entry)
  document.assets.push(next_asset)
  let block = @core.make_block(Image, "", source_ref~)
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
      let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: Some(entry.mime_type),
      }
      next_asset.attrs.set("reference_path", "attachment:" + attachment.name)
      ipynb_attach_asset_payload(next_asset, entry)
      document.assets.push(next_asset)
      let image = @core.make_block(Image, "", source_ref~)
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
      let asset = @core.make_asset_ref(Attachment, asset_id, source_ref~)
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: Some(entry.mime_type),
      }
      ipynb_attach_asset_payload(next_asset, entry)
      document.assets.push(next_asset)
      blocks.push(
        @core.make_block(
          Paragraph,
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
  let label = ipynb_cell_label_text(cell)
  let block = @core.make_block(
    Paragraph,
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
  block.attrs.set("rag_solo_source_ref_only", "true")
  block
}

///|
fn ipynb_cell_label_text(cell : @dipynb.IpynbCell) -> String {
  if cell.kind == Code && cell.execution_count is Some(count) {
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
}

///|
fn ipynb_output_label_block(
  cell : @dipynb.IpynbCell,
  output : @dipynb.IpynbOutput,
  output_index : Int,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let flavor = match output.kind {
    Stream => output.name.unwrap_or("stdout")
    DisplayData => ipynb_preferred_mime_label(output.mime_entries)
    ExecuteResult => ipynb_preferred_mime_label(output.mime_entries)
    Error => output.ename.unwrap_or("error")
    Unknown => output.output_type
  }
  let block = @core.make_block(
    Paragraph,
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
  block.attrs.set("rag_solo_source_ref_only", "true")
  block
}

///|
fn ipynb_code_block(
  text : String,
  source : @input.InputSource,
  cell : @dipynb.IpynbCell,
  language : String?,
) -> @core.CoreBlock {
  let block = @core.make_block(
    Code,
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
    Code,
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
      Paragraph,
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
    Code,
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
  let extra : Map[String, String] = Map([])
  match cell_index {
    Some(value) => extra.set("ipynb_cell_index", value.to_string())
    None => ()
  }
  match cell_kind {
    Some(value) => extra.set("ipynb_cell_kind", value)
    None => ()
  }
  match cell_id {
    Some(value) => extra.set("ipynb_cell_id", value)
    None => ()
  }
  match output_index {
    Some(value) => extra.set("ipynb_output_index", value.to_string())
    None => ()
  }
  match execution_count {
    Some(value) => extra.set("ipynb_execution_count", value.to_string())
    None => ()
  }
  match output_kind {
    Some(value) => extra.set("ipynb_output_kind", value)
    None => ()
  }
  match attachment_name {
    Some(value) => extra.set("ipynb_attachment_name", value)
    None => ()
  }
  match mime_type {
    Some(value) => extra.set("ipynb_mime_type", value)
    None => ()
  }
  {
    ..@core.empty_source_ref(),
    file_id: Some(source.source_name),
    format: Some("ipynb"),
    json_pointer: Some(json_pointer),
    extra,
  }
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
fn ipynb_finalize_markdown_block(
  block : @core.CoreBlock,
  cell : @dipynb.IpynbCell,
) -> @core.CoreBlock {
  if block.kind == Image {
    let next = { ..block }
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
    block
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
  if block.children.length() == 0 {
    return { ..block, source_ref: Some(rebound_ref) }
  }
  let children : Array[@core.CoreBlock] = []
  for child in block.children {
    children.push(
      ipynb_rebind_output_block_source_ref(
        child, source, cell, output_json_pointer, output_index, output_kind,
      ),
    )
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
