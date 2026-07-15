///|
const EML_PARSER_NAME : String = "eml_parser"

///|
const EML_MAX_RECURSIVE_CHILDREN : Int = 64

///|
const EML_MAX_MATERIALIZED_ASSETS : Int = 64

///|
const EML_MAX_INLINE_BINARY_BYTES : Int = 32768

///|
const EML_MAX_INLINE_BASE64_RAW_CHARS_UPPER_BOUND : Int = 44864

///|
const EML_MAX_INLINE_BASE64_RAW_CHARS_LOWER_BOUND : Int = 43776

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
    BlockStreaming,
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
    Message,
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
  let prepared = match @deml.prepare_eml_message_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let diagnostics = eml_base_diagnostics(source, context)
  match prepared.message {
    Some(message) => {
      let inspect = prepared.inspect.unwrap_or(
        @deml.inspect_eml_message(message),
      )
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
          BlockStreaming,
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
    None =>
      Ok(
        eml_malformed_parse_result(
          source,
          text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
        ),
      )
  }
}

///|
fn eml_base_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @fshared.empty_parser_diagnostics(
    EML_PARSER_NAME,
    BlockStreaming,
    source,
    "eml",
  )
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "eml",
    EML_PARSER_NAME,
    BlockStreaming,
    BlockStreaming,
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
        Paragraph,
        "Skipped: recursive child limit reached",
        source_ref=eml_part_source_ref(source, part),
      ),
    )
    return blocks
  }
  if part.summary.mime_type == "application/x-markitdown-recovered-mime-part" {
    diagnostics.warnings.push(
      "eml recovered malformed MIME part at " + part.summary.json_pointer,
    )
    diagnostics.degraded_features.push("eml_malformed_part_recovered")
    eml_increment_metric(diagnostics, "recovered_part_count")
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
          Paragraph,
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
        Paragraph,
        "",
        source_ref=eml_part_source_ref(source, part),
      ),
    ]
  }
  let blocks : Array[@core.CoreBlock] = []
  for paragraph in paragraphs {
    blocks.push(
      @core.make_block(
        Paragraph,
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
    Some(Html),
  )
  let parsed = match
    @runtime.parse_child_to_block_product(registry, html_source, Html, context) {
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
      Json,
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
      Xml,
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
      Markdown,
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
    let materialized = eml_materialize_attachment_payload(
      attachment, false, true,
    )
    let asset_id = eml_attachment_asset_path(part, attachment)
    let source_ref = eml_attachment_source_ref(source, part, attachment)
    let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
    let next_asset = {
      ..asset,
      path: Some(asset_id),
      mime_type: Some(attachment.mime_type),
    }
    eml_attach_asset_payload(next_asset, materialized)
    document.assets.push(next_asset)
    let image = @core.make_block(Image, "", source_ref~)
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
    Some(format) =>
      if eml_detected_format_prefers_text_payload(format) {
        let materialized = eml_materialize_attachment_payload(
          attachment, true, false,
        )
        match materialized.decoded_text {
          Some(text) => {
            let child_blocks = eml_lower_typed_text_payload(
              text, format, part, source, context, registry, diagnostics,
            )
            if child_blocks.length() > 0 {
              blocks.append(child_blocks[:])
              return blocks
            }
          }
          None => ()
        }
      } else {
        let materialized = eml_materialize_attachment_payload(
          attachment, false, true,
        )
        match materialized.bytes {
          Some(bytes) => {
            let inner = @input.input_from_bytes_with_format(
              bytes,
              attachment.file_name.unwrap_or(source.source_name + ".child"),
              Some(format),
            )
            let child = match
              @runtime.parse_child_to_block_product(
                registry, inner, format, context,
              ) {
              Ok(value) => value
              Err(_) => {
                diagnostics.warnings.push(
                  "eml attachment parse fallback for " +
                  attachment.file_name.unwrap_or(attachment.mime_type),
                )
                diagnostics.degraded_features.push(
                  "eml_attachment_raw_fallback",
                )
                return eml_attachment_summary_blocks(attachment, part, source)
              }
            }
            eml_absorb_child_diagnostics(diagnostics, child.diagnostics)
            eml_increment_metric(
              diagnostics, "recursive_attachment_dispatch_count",
            )
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
          None => ()
        }
      }
    _ => ()
  }

  if document.assets.length() < EML_MAX_MATERIALIZED_ASSETS &&
    eml_should_materialize_attachment_asset(attachment) {
    let materialized = eml_materialize_attachment_payload(
      attachment, false, true,
    )
    if materialized.bytes is Some(_) {
      let asset_id = eml_attachment_asset_path(part, attachment)
      let source_ref = eml_attachment_source_ref(source, part, attachment)
      let asset = @core.make_asset_ref(Attachment, asset_id, source_ref~)
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: Some(attachment.mime_type),
      }
      eml_attach_asset_payload(next_asset, materialized)
      document.assets.push(next_asset)
    }
  }
  eml_attachment_summary_blocks(attachment, part, source)
}

///|
fn eml_detected_format_prefers_text_payload(
  format : @input.DetectedFormat,
) -> Bool {
  match format {
    Txt | Markdown | Json | Xml | Yaml | Toml | Html | Eml | Ipynb => true
    _ => false
  }
}

///|
fn eml_should_materialize_attachment_asset(
  attachment : @deml.EmlAttachment,
) -> Bool {
  if attachment.bytes is Some(_) {
    return true
  }
  match attachment.transfer_encoding {
    Base64 => {
      if attachment.raw_text.length() >
        EML_MAX_INLINE_BASE64_RAW_CHARS_UPPER_BOUND {
        return false
      }
      if attachment.raw_text.length() <=
        EML_MAX_INLINE_BASE64_RAW_CHARS_LOWER_BOUND {
        return true
      }
      eml_base64_body_within_inline_limit(
        attachment.raw_text,
        eml_max_inline_binary_base64_chars(),
      )
    }
    QuotedPrintable | SevenBit | EightBit | Binary | Other(_) =>
      attachment.raw_text.length() <= EML_MAX_INLINE_BINARY_BYTES
  }
}

///|
fn eml_max_inline_binary_base64_chars() -> Int {
  (EML_MAX_INLINE_BINARY_BYTES + 2) / 3 * 4
}

///|
fn eml_base64_body_within_inline_limit(raw : String, max_chars : Int) -> Bool {
  let mut compact_len = 0
  for ch in raw {
    if ch != '\n' && ch != '\r' && ch != ' ' && ch != '\t' {
      compact_len += 1
      if compact_len > max_chars {
        return false
      }
    }
  }
  true
}
