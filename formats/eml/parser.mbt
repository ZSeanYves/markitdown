///|
const EML_PARSER_NAME : String = "eml_parser"

///|
const EML_MAX_RECURSIVE_CHILDREN : Int = 64

///|
const EML_MAX_MATERIALIZED_ASSETS : Int = 64

///|
const EML_MAX_INLINE_BINARY_BYTES : Int = 32768

///|
pub fn eml_parser() -> @parser.Parser {
  eml_parser_with_registry(fn() { @parser.empty_registry() })
}

///|
pub fn eml_parser_with_registry(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    EML_PARSER_NAME,
    @parser.ParserMode::BlockStreaming,
    eml_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_eml_result(source, context, registry_provider)
    },
  )
}

///|
fn eml_parser_capability() -> @parser.ParserCapability {
  @parser.block_stream_parser_capability(
    @parser.StreamingGranularity::Message,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
priv struct EmlAssetRewrite {
  old_asset_id : String
  old_path : String
  new_asset_id : String
  new_path : String
}

///|
fn parse_eml_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry_provider : () -> @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let text = eml_decode_source_text(source, bytes)
  let diagnostics = eml_base_diagnostics(source, context)
  let parsed = try @deml.parse_eml_message(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(message) => {
      let inspect = @deml.inspect_eml_message(message)
      let lowered = lower_eml_message(
        message,
        source,
        context,
        registry_provider(),
        diagnostics,
      )
      eml_fill_metrics(diagnostics, inspect, text, lowered)
      diagnostics.pass_trace.push("parse:" + EML_PARSER_NAME)
      Ok(
        @parser.parse_result_with_blocks_capability(
          EML_PARSER_NAME,
          @parser.ParserMode::BlockStreaming,
          lowered.blocks,
          diagnostics,
          eml_parser_capability(),
          metadata=lowered.metadata,
          assets=lowered.assets,
          source_map=lowered.source_map,
          assembly=lowered.assembly,
        ),
      )
    }
    Err(err) => Ok(eml_malformed_parse_result(source, text, diagnostics, err))
  }
}

///|
fn eml_base_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @fshared.empty_parser_diagnostics(
    EML_PARSER_NAME,
    @parser.ParserMode::BlockStreaming,
    source,
    "eml",
  )
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "eml",
    EML_PARSER_NAME,
    @parser.ParserMode::BlockStreaming,
    @parser.ParserMode::BlockStreaming,
    "block_stream",
    "message",
    "eml_mime_part_block_stream",
  )
  @fshared.init_parser_count_metrics(diagnostics)
  diagnostics.metrics.set(
    "max_recursive_children",
    EML_MAX_RECURSIVE_CHILDREN.to_string(),
  )
  diagnostics.metrics.set(
    "max_materialized_assets",
    EML_MAX_MATERIALIZED_ASSETS.to_string(),
  )
  diagnostics.metrics.set("multipart_related_count", "0")
  diagnostics.metrics.set("multipart_alternative_count", "0")
  diagnostics.metrics.set("cid_rewrite_count", "0")
  diagnostics.metrics.set("selected_body_kind", "none")
  diagnostics.metrics.set("recursive_attachment_dispatch_count", "0")
  @fshared.apply_product_metrics(diagnostics, "eml")
  diagnostics
}

///|
fn eml_fill_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @deml.EmlInspectReport,
  text : String,
  document : @core.DocumentIR,
) -> Unit {
  diagnostics.metrics.set("part_count", inspect.part_count.to_string())
  diagnostics.metrics.set(
    "multipart_count",
    inspect.multipart_count.to_string(),
  )
  diagnostics.metrics.set(
    "text_part_count",
    inspect.text_part_count.to_string(),
  )
  diagnostics.metrics.set(
    "html_part_count",
    inspect.html_part_count.to_string(),
  )
  diagnostics.metrics.set(
    "attachment_count",
    inspect.attachment_count.to_string(),
  )
  diagnostics.metrics.set(
    "inline_image_count",
    inspect.inline_image_count.to_string(),
  )
  diagnostics.metrics.set(
    "nested_message_count",
    inspect.nested_message_count.to_string(),
  )
  diagnostics.metrics.set("max_depth_observed", inspect.max_depth.to_string())
  diagnostics.metrics.set("max_part_chars", inspect.max_part_chars.to_string())
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
}

///|
fn lower_eml_message(
  message : @deml.EmlMessage,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.document_with_source_map(
    @core.document_with_metadata(
      @core.empty_document_ir(),
      eml_message_metadata(message),
    ),
    Some(@core.empty_source_map()),
  )
  document.blocks.push(eml_headers_table_block(message, source))
  eml_record_body_selection_metrics(message, diagnostics)
  let mut child_count = 0
  let rewrites : Array[EmlAssetRewrite] = []
  for part in message.children {
    let lowered = lower_eml_part(
      part, source, context, registry, diagnostics, document, rewrites, child_count,
    )
    child_count += 1
    document.blocks.append(lowered[:])
  }
  document
}

///|
fn lower_eml_part(
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
  rewrites : Array[EmlAssetRewrite],
  child_count : Int,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  if child_count >= EML_MAX_RECURSIVE_CHILDREN {
    blocks.push(eml_part_label_block(part, source))
    diagnostics.warnings.push("eml recursive child limit reached")
    diagnostics.degraded_features.push("eml_recursive_child_limit")
    blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        "Skipped: recursive child limit reached",
        source_ref=eml_part_source_ref(source, part),
      ),
    )
    return blocks
  }
  if part.summary.media_type == "multipart" {
    blocks.push(eml_part_label_block(part, source))
    blocks.append(
      lower_eml_multipart_children(
        part,
        source,
        context,
        registry,
        diagnostics,
        document,
        rewrites,
        child_count + 1,
      )[:],
    )
    return blocks
  }
  blocks.push(eml_part_label_block(part, source))
  match part.child_message {
    Some(child_message) => {
      blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          "[Nested Message]",
          source_ref=eml_part_source_ref(source, part),
        ),
      )
      for nested in child_message.children {
        blocks.append(
          lower_eml_part(
            nested,
            source,
            context,
            registry,
            diagnostics,
            document,
            rewrites,
            child_count + 1,
          )[:],
        )
      }
      blocks
    }
    None => {
      if part.summary.mime_type == "text/plain" {
        blocks.append(lower_eml_text_plain_part(part, source)[:])
      } else if part.summary.mime_type == "text/html" {
        blocks.append(
          lower_eml_html_part(
            part, source, context, registry, diagnostics, document, rewrites,
          )[:],
        )
      } else {
        blocks.append(
          lower_eml_non_html_part(
            part, source, context, registry, diagnostics, document, rewrites,
          )[:],
        )
      }
      blocks
    }
  }
}

///|
fn lower_eml_text_plain_part(
  part : @deml.EmlPart,
  source : @input.InputSource,
) -> Array[@core.CoreBlock] {
  let body = match part.body_text {
    Some(value) => value.text
    None => part.raw_body
  }
  let paragraphs = eml_paragraphs(body)
  if paragraphs.length() == 0 {
    return [
      @core.make_block(
        @core.BlockKind::Paragraph,
        "",
        source_ref=eml_part_source_ref(source, part),
      ),
    ]
  }
  let blocks : Array[@core.CoreBlock] = []
  for paragraph in paragraphs {
    blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        paragraph,
        source_ref=eml_part_source_ref(source, part),
      ),
    )
  }
  blocks
}

///|
fn lower_eml_html_part(
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
  rewrites : Array[EmlAssetRewrite],
) -> Array[@core.CoreBlock] {
  let html0 = match part.body_text {
    Some(value) => value.text
    None => part.raw_body
  }
  let html = eml_rewrite_cid_references(
    html0,
    part,
    part.children,
    document,
    diagnostics,
  )
  let html_source = @input.input_from_text_with_format(
    html,
    source.source_name + ".html",
    Some(@input.DetectedFormat::Html),
  )
  let parsed = match
    @runtime.parse_child_to_block_product(
      registry,
      html_source,
      @input.DetectedFormat::Html,
      context,
    ) {
    Ok(value) => value
    Err(_) => return eml_raw_fenced_part(part, source, "html")
  }
  eml_absorb_child_diagnostics(diagnostics, parsed.diagnostics)
  let html_rewrites = eml_rewrite_child_assets(
    parsed.assets,
    part,
    rewrites,
    document,
    diagnostics,
  )
  eml_rewrite_child_blocks(parsed.blocks, html_rewrites, part, diagnostics)
}

///|
fn lower_eml_non_html_part(
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
  rewrites : Array[EmlAssetRewrite],
) -> Array[@core.CoreBlock] {
  if part.attachments.length() > 0 {
    let blocks : Array[@core.CoreBlock] = []
    for attachment in part.attachments {
      blocks.append(
        lower_eml_attachment(
          attachment, part, source, context, registry, diagnostics, document, rewrites,
        )[:],
      )
    }
    return blocks
  }
  if part.summary.mime_type == "application/json" ||
    part.summary.mime_type.contains("+json") {
    let payload = match part.body_text {
      Some(value) => value.text
      None => part.raw_body
    }
    return eml_lower_typed_text_payload(
      payload,
      @input.DetectedFormat::Json,
      part,
      source,
      context,
      registry,
      diagnostics,
    )
  }
  if part.summary.mime_type == "application/xml" ||
    part.summary.mime_type.contains("+xml") {
    let payload = match part.body_text {
      Some(value) => value.text
      None => part.raw_body
    }
    return eml_lower_typed_text_payload(
      payload,
      @input.DetectedFormat::Xml,
      part,
      source,
      context,
      registry,
      diagnostics,
    )
  }
  if part.summary.mime_type == "text/markdown" {
    let payload = match part.body_text {
      Some(value) => value.text
      None => part.raw_body
    }
    return eml_lower_typed_text_payload(
      payload,
      @input.DetectedFormat::Markdown,
      part,
      source,
      context,
      registry,
      diagnostics,
    )
  }
  if part.summary.mime_type == "text/plain" {
    return lower_eml_text_plain_part(part, source)
  }
  eml_raw_fenced_part(
    part,
    source,
    eml_info_string_for_mime(part.summary.mime_type),
  )
}

///|
fn eml_lower_typed_text_payload(
  payload : String,
  format : @input.DetectedFormat,
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
) -> Array[@core.CoreBlock] {
  let inner = @input.input_from_text_with_format(
    payload,
    source.source_name + "." + @input.detected_format_name(format),
    Some(format),
  )
  let child = match
    @runtime.parse_child_to_block_product(registry, inner, format, context) {
    Ok(value) => value
    Err(_) =>
      return eml_raw_fenced_part(
        part,
        source,
        @input.detected_format_name(format),
      )
  }
  eml_absorb_child_diagnostics(diagnostics, child.diagnostics)
  eml_increment_metric(diagnostics, "recursive_attachment_dispatch_count")
  child.blocks
}

///|
fn lower_eml_attachment(
  attachment : @deml.EmlAttachment,
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
  rewrites : Array[EmlAssetRewrite],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  if eml_attachment_is_inline_image(attachment) &&
    document.assets.length() < EML_MAX_MATERIALIZED_ASSETS {
    let asset_id = eml_attachment_asset_path(part, attachment)
    let source_ref = eml_attachment_source_ref(source, part, attachment)
    let asset = @core.make_asset_ref(
      @core.AssetKind::Image,
      asset_id,
      source_ref~,
    )
    let next_asset = {
      ..asset,
      path: Some(asset_id),
      mime_type: Some(attachment.mime_type),
    }
    eml_attach_inline_payload(next_asset, attachment)
    document.assets.push(next_asset)
    let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
    image.attrs.set("asset_id", asset_id)
    image.attrs.set("path", asset_id)
    image.attrs.set(
      "alt",
      attachment.file_name.unwrap_or(
        attachment.content_id.unwrap_or("inline image"),
      ),
    )
    blocks.push(image)
    return blocks
  }

  match eml_attachment_detected_format(attachment) {
    Some(format) if attachment.decoded_text is Some(text) => {
      let child_blocks = eml_lower_typed_text_payload(
        text, format, part, source, context, registry, diagnostics,
      )
      if child_blocks.length() > 0 {
        blocks.append(child_blocks[:])
        return blocks
      }
    }
    Some(format) if attachment.bytes is Some(bytes) => {
      let inner = @input.input_from_bytes_with_format(
        bytes,
        attachment.file_name.unwrap_or(source.source_name + ".child"),
        Some(format),
      )
      let child = match
        @runtime.parse_child_to_block_product(registry, inner, format, context) {
        Ok(value) => value
        Err(_) => {
          diagnostics.warnings.push(
            "eml attachment parse fallback for " +
            attachment.file_name.unwrap_or(attachment.mime_type),
          )
          diagnostics.degraded_features.push("eml_attachment_raw_fallback")
          return eml_attachment_summary_blocks(attachment, part, source)
        }
      }
      eml_absorb_child_diagnostics(diagnostics, child.diagnostics)
      eml_increment_metric(diagnostics, "recursive_attachment_dispatch_count")
      let child_rewrites = eml_rewrite_child_assets(
        child.assets,
        part,
        rewrites,
        document,
        diagnostics,
      )
      return eml_rewrite_child_blocks(
        child.blocks,
        child_rewrites,
        part,
        diagnostics,
      )
    }
    _ => ()
  }

  if document.assets.length() < EML_MAX_MATERIALIZED_ASSETS &&
    attachment.bytes is Some(_) {
    let asset_id = eml_attachment_asset_path(part, attachment)
    let source_ref = eml_attachment_source_ref(source, part, attachment)
    let asset = @core.make_asset_ref(
      @core.AssetKind::Attachment,
      asset_id,
      source_ref~,
    )
    let next_asset = {
      ..asset,
      path: Some(asset_id),
      mime_type: Some(attachment.mime_type),
    }
    eml_attach_inline_payload(next_asset, attachment)
    document.assets.push(next_asset)
  }
  eml_attachment_summary_blocks(attachment, part, source)
}

///|
fn lower_eml_multipart_children(
  part : @deml.EmlPart,
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  diagnostics : @core.Diagnostics,
  document : @core.DocumentIR,
  rewrites : Array[EmlAssetRewrite],
  child_count : Int,
) -> Array[@core.CoreBlock] {
  if part.summary.mime_type == "multipart/alternative" {
    eml_increment_metric(diagnostics, "multipart_alternative_count")
    let children = eml_selected_alternative_children(part, diagnostics)
    let blocks : Array[@core.CoreBlock] = []
    for child in children {
      blocks.append(
        lower_eml_part(
          child, source, context, registry, diagnostics, document, rewrites, child_count,
        )[:],
      )
    }
    return blocks
  }
  if part.summary.mime_type == "multipart/related" {
    eml_increment_metric(diagnostics, "multipart_related_count")
  }
  let blocks : Array[@core.CoreBlock] = []
  for child in part.children {
    blocks.append(
      lower_eml_part(
        child, source, context, registry, diagnostics, document, rewrites, child_count,
      )[:],
    )
  }
  blocks
}

///|
fn eml_selected_alternative_children(
  part : @deml.EmlPart,
  diagnostics : @core.Diagnostics,
) -> Array[@deml.EmlPart] {
  let html_parts : Array[@deml.EmlPart] = []
  let plain_parts : Array[@deml.EmlPart] = []
  for child in part.children {
    if child.summary.mime_type == "text/plain" && child.body_text is Some(_) {
      plain_parts.push(child)
    } else if child.summary.mime_type == "text/html" &&
      child.body_text is Some(_) {
      html_parts.push(child)
    }
  }
  if plain_parts.length() > 0 {
    diagnostics.metrics.set("selected_body_kind", "text/plain")
    return [plain_parts[0]]
  }
  if html_parts.length() > 0 {
    diagnostics.metrics.set("selected_body_kind", "text/html")
    return [html_parts[0]]
  }
  diagnostics.metrics.set("selected_body_kind", part.summary.mime_type)
  if part.children.length() == 0 {
    []
  } else {
    [part.children[0]]
  }
}

///|
fn eml_record_body_selection_metrics(
  message : @deml.EmlMessage,
  diagnostics : @core.Diagnostics,
) -> Unit {
  let mut selected = diagnostics.metrics
    .get("selected_body_kind")
    .unwrap_or("none")
  if selected == "none" {
    if message.text_plain.length() > 0 {
      selected = "text/plain"
    } else if message.text_html.length() > 0 {
      selected = "text/html"
    }
    diagnostics.metrics.set("selected_body_kind", selected)
  }
}

///|
fn eml_rewrite_cid_references(
  html : String,
  part : @deml.EmlPart,
  sibling_parts : Array[@deml.EmlPart],
  document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
) -> String {
  let mut out = html
  let inline_attachments = eml_inline_image_attachments_for_related(
    part, sibling_parts,
  )
  for item in inline_attachments {
    let attachment = item.0
    let owner_part = item.1
    let content_id = attachment.content_id.unwrap_or("").trim().to_owned()
    if content_id == "" {
      continue
    }
    let asset_path = eml_attachment_asset_path(owner_part, attachment)
    let before = out
    out = out.replace_all(old="cid:" + content_id, new=asset_path)
    out = out.replace_all(old="cid:<" + content_id + ">", new=asset_path)
    if out != before {
      eml_increment_metric(diagnostics, "cid_rewrite_count")
      eml_materialize_inline_attachment_asset(attachment, owner_part, document)
    }
  }
  out
}

///|
fn eml_increment_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = diagnostics.metrics.get(key).unwrap_or("0")
  let next = (@string.parse_int(current.trim()) catch { _ => 0 }) + 1
  diagnostics.metrics.set(key, next.to_string())
}

///|
fn eml_inline_image_attachments_for_related(
  part : @deml.EmlPart,
  sibling_parts : Array[@deml.EmlPart],
) -> Array[(@deml.EmlAttachment, @deml.EmlPart)] {
  let out : Array[(@deml.EmlAttachment, @deml.EmlPart)] = []
  for attachment in part.attachments {
    if eml_attachment_is_inline_image(attachment) {
      out.push((attachment, part))
    }
  }
  for sibling in sibling_parts {
    for attachment in sibling.attachments {
      if eml_attachment_is_inline_image(attachment) {
        out.push((attachment, sibling))
      }
    }
  }
  out
}

///|
fn eml_materialize_inline_attachment_asset(
  attachment : @deml.EmlAttachment,
  owner_part : @deml.EmlPart,
  document : @core.DocumentIR,
) -> Unit {
  let asset_path = eml_attachment_asset_path(owner_part, attachment)
  let existing = document.assets.any(fn(asset) {
    asset.path == Some(asset_path)
  })
  if existing ||
    document.assets.length() >= EML_MAX_MATERIALIZED_ASSETS ||
    attachment.bytes is None {
    return
  }
  let asset = @core.make_asset_ref(@core.AssetKind::Image, asset_path)
  let next_asset = {
    ..asset,
    path: Some(asset_path),
    mime_type: Some(attachment.mime_type),
  }
  eml_attach_inline_payload(next_asset, attachment)
  document.assets.push(next_asset)
}

///|
fn eml_attachment_summary_blocks(
  attachment : @deml.EmlAttachment,
  part : @deml.EmlPart,
  source : @input.InputSource,
) -> Array[@core.CoreBlock] {
  [
    @core.make_block(
      @core.BlockKind::Paragraph,
      "[Attachment: " +
      attachment.file_name.unwrap_or(attachment.mime_type) +
      " | " +
      attachment.mime_type +
      "]",
      source_ref=eml_attachment_source_ref(source, part, attachment),
    ),
  ]
}

///|
fn eml_headers_table_block(
  message : @deml.EmlMessage,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=eml_message_source_ref(source),
  )
  let rows : Array[Array[String]] = [["Field", "Value"]]
  eml_push_summary_row(rows, "Subject", message.header_map.subject)
  eml_push_summary_row(rows, "From", message.header_map.from)
  eml_push_summary_row(rows, "To", message.header_map.to)
  eml_push_summary_row(rows, "Cc", message.header_map.cc)
  eml_push_summary_row(rows, "Date", message.header_map.date)
  eml_push_summary_row(rows, "Message-ID", message.header_map.message_id)
  rows.push(["Parts", message.children.length().to_string()])
  rows.push(["Attachments", message.attachments.length().to_string()])
  for row_values in rows {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=eml_message_source_ref(source),
    )
    for cell_text in row_values {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          cell_text,
          source_ref=eml_message_source_ref(source),
        ),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn eml_push_summary_row(
  rows : Array[Array[String]],
  field : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) if text.trim() != "" =>
      rows.push([field, text.trim().to_owned()])
    _ => ()
  }
}

///|
fn eml_part_label_block(
  part : @deml.EmlPart,
  source : @input.InputSource,
) -> @core.CoreBlock {
  let label = "[Part " +
    (part.index + 1).to_string() +
    " | " +
    part.summary.mime_type +
    "]"
  @core.make_block(
    @core.BlockKind::Paragraph,
    label,
    source_ref=eml_part_source_ref(source, part),
  )
}

///|
fn eml_raw_fenced_part(
  part : @deml.EmlPart,
  source : @input.InputSource,
  info : String,
) -> Array[@core.CoreBlock] {
  let raw = @core.make_block(
    @core.BlockKind::Code,
    if part.raw_body.trim() == "" {
      part.summary.mime_type
    } else {
      part.raw_body
    },
    source_ref=eml_part_source_ref(source, part),
  )
  if info.trim() != "" {
    raw.attrs.set("info", info)
  }
  [raw]
}

///|
fn eml_rewrite_child_assets(
  assets : Array[@core.AssetRef],
  owner_part : @deml.EmlPart,
  _rewrites : Array[EmlAssetRewrite],
  document : @core.DocumentIR,
  _diagnostics : @core.Diagnostics,
) -> Array[EmlAssetRewrite] {
  let local_rewrites : Array[EmlAssetRewrite] = []
  for asset in assets {
    let old_asset_id = asset.asset_id
    let old_path = asset.path.unwrap_or(old_asset_id)
    let pointer_slug = eml_slug(owner_part.summary.json_pointer)
    let new_asset_id = "eml:" + pointer_slug + ":" + old_asset_id
    let ext = eml_asset_ext(asset.path, asset.mime_type)
    let rel_path = "assets/eml-" +
      pointer_slug +
      "-" +
      (document.assets.length() + 1).to_string() +
      ext
    let rewritten = { ..asset, asset_id: new_asset_id, path: Some(rel_path) }
    document.assets.push(rewritten)
    local_rewrites.push({
      old_asset_id,
      old_path,
      new_asset_id,
      new_path: rel_path,
    })
  }
  local_rewrites
}

///|
fn eml_rewrite_child_blocks(
  blocks : Array[@core.CoreBlock],
  rewrites : Array[EmlAssetRewrite],
  _owner_part : @deml.EmlPart,
  _diagnostics : @core.Diagnostics,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for block in blocks {
    out.push(eml_rewrite_child_block(block, rewrites))
  }
  out
}

///|
fn eml_rewrite_child_block(
  block : @core.CoreBlock,
  rewrites : Array[EmlAssetRewrite],
) -> @core.CoreBlock {
  let next = { ..block }
  if block.kind == @core.BlockKind::Image {
    let old_asset_id = block.attrs.get("asset_id").unwrap_or("")
    let old_path = block.attrs.get("path").unwrap_or("")
    match eml_find_asset_rewrite(rewrites, old_asset_id, old_path) {
      Some(rewrite) => {
        next.attrs.set("asset_id", rewrite.new_asset_id)
        next.attrs.set("path", rewrite.new_path)
      }
      None => ()
    }
  }
  if next.children.length() > 0 {
    let rewritten_children : Array[@core.CoreBlock] = []
    for child in next.children {
      rewritten_children.push(eml_rewrite_child_block(child, rewrites))
    }
    return { ..next, children: rewritten_children }
  }
  next
}

///|
fn eml_find_asset_rewrite(
  rewrites : Array[EmlAssetRewrite],
  old_asset_id : String,
  old_path : String,
) -> EmlAssetRewrite? {
  for rewrite in rewrites {
    if old_asset_id != "" && rewrite.old_asset_id == old_asset_id {
      return Some(rewrite)
    }
    if old_path != "" && rewrite.old_path == old_path {
      return Some(rewrite)
    }
  }
  None
}

///|
fn eml_message_metadata(message : @deml.EmlMessage) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", @core.JsonValue::String("eml"))
  match message.header_map.subject {
    Some(value) => metadata.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match message.header_map.from {
    Some(value) => metadata.set("from", @core.JsonValue::String(value))
    None => ()
  }
  match message.header_map.to {
    Some(value) => metadata.set("to", @core.JsonValue::String(value))
    None => ()
  }
  metadata.set(
    "description",
    @core.JsonValue::String(
      "email message with " + message.children.length().to_string() + " parts",
    ),
  )
  metadata
}

///|
fn eml_part_source_ref(
  source : @input.InputSource,
  part : @deml.EmlPart,
) -> @core.SourceRef {
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("eml"),
    None,
    None,
  )
  let base = @core.source_ref_with_extra(
    base,
    "eml_json_pointer",
    part.summary.json_pointer,
  )
  let base = @core.source_ref_with_extra(
    base,
    "eml_mime_type",
    part.summary.mime_type,
  )
  match part.summary.content_id {
    Some(value) => @core.source_ref_with_extra(base, "eml_content_id", value)
    None => base
  }
}

///|
fn eml_attachment_source_ref(
  source : @input.InputSource,
  part : @deml.EmlPart,
  attachment : @deml.EmlAttachment,
) -> @core.SourceRef {
  let base = eml_part_source_ref(source, part)
  match attachment.file_name {
    Some(value) =>
      @core.source_ref_with_extra(base, "eml_attachment_name", value)
    None => base
  }
}

///|
fn eml_message_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("eml"),
    None,
    None,
  )
}

///|
fn eml_decode_source_text(source : @input.InputSource, bytes : Bytes) -> String {
  match source.text {
    Some(text) => text
    None =>
      @utf8.decode(bytes, ignore_bom=false) catch {
        _ => {
          let chars : Array[Char] = []
          for byte in bytes.to_array() {
            chars.push(Int::unsafe_to_char(byte.to_int()))
          }
          String::from_array(chars)
        }
      }
  }
}

///|
fn eml_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
) -> @parser.ParseResult {
  diagnostics.warnings.push("eml parse failed; returned raw fenced fallback")
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("eml_raw_fenced_fallback")
  diagnostics.fallback_trace.push("eml_raw_fenced_fallback")
  diagnostics.metrics.set("syntax_error_count", "1")
  @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
  let raw = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=eml_message_source_ref(source),
  )
  raw.attrs.set("info", "eml")
  @parser.parse_result_with_blocks_capability(
    EML_PARSER_NAME,
    @parser.ParserMode::BlockStreaming,
    [raw],
    diagnostics,
    eml_parser_capability(),
  )
}

///|
fn eml_absorb_child_diagnostics(
  diagnostics : @core.Diagnostics,
  child : @core.Diagnostics,
) -> Unit {
  for warning in child.warnings {
    diagnostics.warnings.push(warning)
  }
  for degraded in child.degraded_features {
    diagnostics.degraded_features.push(degraded)
  }
  for fallback in child.fallback_trace {
    diagnostics.fallback_trace.push(fallback)
  }
  for entry in child.metrics.to_array() {
    ignore(entry)
  }
}

///|
fn eml_paragraphs(text : String) -> Array[String] {
  let normalized = text.replace_all(old="\r\n", new="\n").trim().to_owned()
  if normalized == "" {
    return []
  }
  normalized
  .split("\n\n")
  .to_array()
  .map(p => p.trim().replace_all(old="\n", new=" ").to_owned())
  .filter(p => p != "")
}

///|
fn eml_attachment_detected_format(
  attachment : @deml.EmlAttachment,
) -> @input.DetectedFormat? {
  match attachment.mime_type {
    "text/markdown" => Some(@input.DetectedFormat::Markdown)
    "application/json" => Some(@input.DetectedFormat::Json)
    "application/x-ipynb+json" => Some(@input.DetectedFormat::Ipynb)
    "application/xml" | "text/xml" => Some(@input.DetectedFormat::Xml)
    "application/yaml" | "text/yaml" | "application/x-yaml" =>
      Some(@input.DetectedFormat::Yaml)
    "application/toml" => Some(@input.DetectedFormat::Toml)
    "text/html" => Some(@input.DetectedFormat::Html)
    "text/plain" => Some(@input.DetectedFormat::Txt)
    "message/rfc822" => Some(@input.DetectedFormat::Eml)
    _ =>
      match attachment.file_name {
        Some(name) => {
          let parts = name.split(".").to_array()
          let ext = if parts.length() == 0 {
            ""
          } else {
            parts[parts.length() - 1].to_owned()
          }
          match @input.parse_detected_format(ext) {
            @input.DetectedFormat::Unknown => None
            format => Some(format)
          }
        }
        None => None
      }
  }
}

///|
fn eml_attachment_is_inline_image(attachment : @deml.EmlAttachment) -> Bool {
  attachment.disposition == Some(@deml.EmlDispositionKind::Inline) &&
  (
    attachment.mime_type == "image/png" ||
    attachment.mime_type == "image/jpeg" ||
    attachment.mime_type == "image/gif" ||
    attachment.mime_type == "image/svg+xml"
  )
}

///|
fn eml_attachment_asset_path(
  part : @deml.EmlPart,
  attachment : @deml.EmlAttachment,
) -> String {
  "assets/eml-" +
  eml_slug(part.summary.json_pointer) +
  "-" +
  eml_slug(attachment.file_name.unwrap_or(attachment.mime_type)) +
  eml_attachment_ext(attachment.mime_type)
}

///|
fn eml_attachment_ext(mime_type : String) -> String {
  match mime_type {
    "image/png" => ".png"
    "image/jpeg" => ".jpg"
    "image/gif" => ".gif"
    "image/svg+xml" => ".svg"
    "application/json" => ".json"
    "application/xml" | "text/xml" => ".xml"
    "application/x-ipynb+json" => ".ipynb"
    "text/html" => ".html"
    "text/markdown" => ".md"
    "application/toml" => ".toml"
    _ => ".bin"
  }
}

///|
fn eml_attach_inline_payload(
  asset : @core.AssetRef,
  attachment : @deml.EmlAttachment,
) -> Unit {
  match attachment.bytes {
    Some(bytes) =>
      if attachment.mime_type == "image/svg+xml" ||
        attachment.mime_type.has_prefix("text/") ||
        attachment.mime_type == "application/json" ||
        attachment.mime_type.contains("+json") ||
        attachment.mime_type.contains("+xml") ||
        attachment.mime_type == "application/xml" {
        let text = attachment.decoded_text.unwrap_or(
          eml_decode_source_text(
            @input.input_from_text("", source_name="<attachment>"),
            bytes,
          ),
        )
        asset.attrs.set("inline_payload_kind", "utf8")
        asset.attrs.set("inline_payload", text)
      } else if bytes.length() <= EML_MAX_INLINE_BINARY_BYTES {
        asset.attrs.set("inline_payload_kind", "base64")
        asset.attrs.set("inline_payload", @base64.encode(bytes, url_safe=false))
      } else {
        ()
      }
    None =>
      match attachment.decoded_text {
        Some(text) => {
          asset.attrs.set("inline_payload_kind", "utf8")
          asset.attrs.set("inline_payload", text)
        }
        None => ()
      }
  }
}

///|
fn eml_info_string_for_mime(mime_type : String) -> String {
  if mime_type.contains("+json") || mime_type == "application/json" {
    "json"
  } else if mime_type.contains("+xml") ||
    mime_type == "application/xml" ||
    mime_type == "text/xml" {
    "xml"
  } else if mime_type == "text/html" {
    "html"
  } else if mime_type == "text/markdown" {
    "markdown"
  } else if mime_type.has_prefix("text/") {
    "text"
  } else {
    mime_type
  }
}

///|
fn eml_slug(text : String) -> String {
  let out : Array[Char] = []
  for ch in text.to_lower().to_array() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out.push(ch)
    } else if out.length() == 0 || out.last().unwrap_or('-') != '-' {
      out.push('-')
    }
  }
  let normalized = eml_trim_dashes(String::from_array(out))
  if normalized == "" {
    "part"
  } else {
    normalized
  }
}

///|
fn eml_asset_ext(path : String?, mime_type : String?) -> String {
  match path {
    Some(value) => {
      let trimmed = value.trim()
      match trimmed.split(".").to_array().last() {
        Some(ext) if ext.trim() != "" => "." + ext.trim().to_lower().to_owned()
        _ => eml_attachment_ext(mime_type.unwrap_or(""))
      }
    }
    None => eml_attachment_ext(mime_type.unwrap_or(""))
  }
}

///|
fn eml_trim_dashes(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end_ = chars.length()
  while start < end_ && chars[start] == '-' {
    start += 1
  }
  while end_ > start && chars[end_ - 1] == '-' {
    end_ -= 1
  }
  if start == 0 && end_ == chars.length() {
    text
  } else {
    String::from_array(chars[start:end_].to_owned())
  }
}
