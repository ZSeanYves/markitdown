///|
pub(all) enum PdfNativeError {
  BackendUnavailable(String)
  ReadFailed(String)
  ParseFailed(String)
  EncryptedUnsupported(String)
  EmptyTextLayer(String)
  UnsupportedFeature(String)
} derive(Eq)

///|
pub impl Show for PdfNativeError with fn to_string(self : PdfNativeError) -> String {
  match self {
    BackendUnavailable(msg) => msg
    ReadFailed(msg) => msg
    ParseFailed(msg) => msg
    EncryptedUnsupported(msg) => msg
    EmptyTextLayer(msg) => msg
    UnsupportedFeature(msg) => msg
  }
}

///|
fn txt_ligature_expansion(ch : Char) -> String? {
  match ch {
    '\u{FB00}' => Some("ff")
    '\u{FB01}' => Some("fi")
    '\u{FB02}' => Some("fl")
    '\u{FB03}' => Some("ffi")
    '\u{FB04}' => Some("ffl")
    '\u{FB05}' => Some("ft")
    '\u{FB06}' => Some("st")
    _ => None
  }
}

///|
pub fn extract_pdf_native_document_from_path(
  path : String,
) -> Result[PdfNativeDocument, PdfNativeError] {
  extract_pdf_native_document(@input.input_from_path(path))
}

///|
pub fn extract_pdf_native_document(
  source : @input.InputSource,
) -> Result[PdfNativeDocument, PdfNativeError] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) =>
      return Err(
        PdfNativeError::ReadFailed(
          "failed to read PDF bytes for " +
          pdf_native_source_id(source) +
          ": " +
          err,
        ),
      )
  }
  if bytes.length() == 0 {
    return Err(
      PdfNativeError::ParseFailed(
        "PDF bytes are empty for " + pdf_native_source_id(source),
      ),
    )
  }
  let view = pdf_byte_string(bytes)
  if !view.has_prefix("%PDF-") {
    return Err(
      PdfNativeError::ParseFailed(
        "input is not a PDF file: " + pdf_native_source_id(source),
      ),
    )
  }
  if view.contains("/Encrypt") {
    return Err(
      PdfNativeError::EncryptedUnsupported(
        "encrypted PDF is unsupported in root pdf_native backend: " +
        pdf_native_source_id(source),
      ),
    )
  }
  let objects = match pdf_parse_objects(bytes, view) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let object_index : Map[Int, PdfNativeObject] = Map([])
  for object in objects {
    object_index.set(object.object_id, object)
  }
  let fonts = match pdf_collect_font_infos(object_index) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let page_object_ids = pdf_page_object_ids(objects)
  let page_numbers = pdf_page_number_index(page_object_ids)
  let annotation_pages = pdf_annotation_page_index(
    objects, object_index, page_numbers,
  )
  let pages = match
    pdf_build_native_pages(source, objects, object_index, fonts, page_numbers) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  if pages.length() == 0 {
    return Err(
      PdfNativeError::ParseFailed(
        "no page objects found in PDF: " + pdf_native_source_id(source),
      ),
    )
  }
  let mut page_count = 0
  let mut text_block_count = 0
  let mut line_count = 0
  let mut span_count = 0
  let mut link_count = 0
  let mut annotation_count = 0
  let mut destination_count = 0
  for page in pages {
    page_count += 1
    text_block_count += page.text_blocks.length()
    line_count += pdf_native_page_line_count(page)
    span_count += pdf_native_page_span_count(page)
    link_count += page.link_candidates.length()
    annotation_count += page.annotations.length()
    destination_count += page.destinations.length()
  }
  let form_fields = pdf_extract_form_fields(
    source, view, object_index, page_numbers, annotation_pages,
  )
  let outline_items = pdf_extract_outline_items(
    source, view, object_index, page_numbers,
  )
  let named_destinations = pdf_extract_named_destinations(
    source, view, object_index, page_numbers,
  )
  let has_appendix_signal = annotation_count > 0 ||
    form_fields.length() > 0 ||
    outline_items.length() > 0 ||
    named_destinations.length() > 0 ||
    destination_count > 0
  if span_count == 0 {
    if !has_appendix_signal {
      return Err(
        PdfNativeError::EmptyTextLayer(
          "PDF native text layer is empty or not recoverable by root pdf_native backend: " +
          pdf_native_source_id(source),
        ),
      )
    }
  }
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some("pdf_native_backend"),
      Some("page_single_pass"),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  diagnostics.pass_trace.push("pdf_native:extract_document")
  diagnostics.pass_trace.push("pdf_native:primitive_text")
  diagnostics.metrics.set("parser_name", "pdf_native_backend")
  diagnostics.metrics.set("parser_mode", "page_single_pass")
  diagnostics.metrics.set("detected_format", "pdf")
  diagnostics.metrics.set("pdf_native_backend", "true")
  diagnostics.metrics.set("pdf_native_text_baseline", "true")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_v2_used", "false")
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if span_count == 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("page_count", page_count.to_string())
  diagnostics.metrics.set("pdf_page_count", page_count.to_string())
  diagnostics.metrics.set("pdf_text_block_count", text_block_count.to_string())
  diagnostics.metrics.set("text_line_count", line_count.to_string())
  diagnostics.metrics.set("pdf_text_line_count", line_count.to_string())
  diagnostics.metrics.set("text_span_count", span_count.to_string())
  diagnostics.metrics.set("pdf_text_span_count", span_count.to_string())
  diagnostics.metrics.set("link_count", link_count.to_string())
  diagnostics.metrics.set("pdf_link_candidate_count", link_count.to_string())
  diagnostics.metrics.set(
    "pdf_native_annotation_count",
    annotation_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_form_field_count",
    form_fields.length().to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_outline_count",
    outline_items.length().to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_destination_count",
    (destination_count + named_destinations.length()).to_string(),
  )
  diagnostics.metrics.set("pdf_grouping_strategy", "conservative_v1")
  diagnostics.metrics.set(
    "pdf_grouping_line_merge_count",
    (line_count - text_block_count).to_string(),
  )
  diagnostics.metrics.set(
    "pdf_grouping_paragraph_count",
    text_block_count.to_string(),
  )
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("native_backend", "root_minimal")
  diagnostics.metrics.set("supports_flate_text_streams", "true")
  diagnostics.metrics.set("supports_tounicode", "true")
  diagnostics.metrics.set("runtime_exposed", "false")
  diagnostics.metrics.set("product_path_enabled", "false")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  let metadata : Map[String, @core.JsonValue] = Map([])
  metadata.set("pdf_native_backend", @core.JsonValue::Bool(true))
  metadata.set("pdf_native_text_baseline", @core.JsonValue::Bool(true))
  metadata.set("pdf_ocr_used", @core.JsonValue::Bool(false))
  metadata.set("pdf_v2_used", @core.JsonValue::Bool(false))
  metadata.set("pdf_empty_text_layer", @core.JsonValue::Bool(span_count == 0))
  metadata.set("page_count", @core.JsonValue::Number(page_count.to_string()))
  metadata.set(
    "pdf_page_count",
    @core.JsonValue::Number(page_count.to_string()),
  )
  metadata.set(
    "pdf_text_block_count",
    @core.JsonValue::Number(text_block_count.to_string()),
  )
  metadata.set(
    "pdf_text_line_count",
    @core.JsonValue::Number(line_count.to_string()),
  )
  metadata.set(
    "pdf_text_span_count",
    @core.JsonValue::Number(span_count.to_string()),
  )
  metadata.set(
    "pdf_link_candidate_count",
    @core.JsonValue::Number(link_count.to_string()),
  )
  metadata.set(
    "pdf_native_annotation_count",
    @core.JsonValue::Number(annotation_count.to_string()),
  )
  metadata.set(
    "pdf_native_form_field_count",
    @core.JsonValue::Number(form_fields.length().to_string()),
  )
  metadata.set(
    "pdf_native_outline_count",
    @core.JsonValue::Number(outline_items.length().to_string()),
  )
  metadata.set(
    "pdf_native_destination_count",
    @core.JsonValue::Number(
      (destination_count + named_destinations.length()).to_string(),
    ),
  )
  let annotation_items : Array[@core.JsonValue] = []
  for page in pages {
    for annotation in page.annotations {
      annotation_items.push(
        pdf_native_backend_annotation_json(annotation, object_index),
      )
    }
  }
  if annotation_items.length() > 0 {
    metadata.set(
      "pdf_native_annotations",
      @core.JsonValue::Array(annotation_items),
    )
  }
  match pdf_extract_info_metadata(view, object_index) {
    Some(info) =>
      for entry in info.to_array() {
        metadata.set(entry.0, entry.1)
      }
    None => ()
  }
  Ok(
    make_pdf_native_document(
      pages~,
      form_fields~,
      outline_items~,
      named_destinations~,
      metadata~,
      diagnostics~,
    ),
  )
}

///|
priv struct PdfNativeObject {
  object_id : Int
  dict_text : String
  stream : PdfNativeStreamSlice?
}

///|
priv struct PdfNativeStreamSlice {
  primary_bytes : Bytes
  endstream_bytes : Bytes
  declared_length : Int?
}

///|
priv struct PdfNativeFontInfo {
  base_font : String?
  normalized_base_font : String?
  encoding_name : String?
  code_hex_widths : Array[Int]
  unicode_map : Map[String, String]
  has_tounicode : Bool
  tounicode_decode_failed : Bool
}

///|
priv enum PdfCMapStreamDecodeStrategy {
  NoFilter
  ZlibFlateDecode
  Failed
}

///|
priv enum PdfCMapRawFallbackStatus {
  Skipped(String)
}

///|
priv struct PdfCMapStreamDecodeDiagnostics {
  filter_name : String
  input_length : Int
  declared_length : Int?
  actual_sliced_length : Int
  zlib_status : String
  raw_fallback : PdfCMapRawFallbackStatus
}

///|
priv struct PdfCMapStreamDecodeFailure {
  strategy : PdfCMapStreamDecodeStrategy
  diagnostics : PdfCMapStreamDecodeDiagnostics
  message : String
}

///|
priv struct PdfCMapStreamDecodeResult {
  text : String
  strategy : PdfCMapStreamDecodeStrategy
  diagnostics : PdfCMapStreamDecodeDiagnostics
}

///|
priv struct PdfNativeTokenizedString {
  decoded : String
  terminated : Bool
}

///|
priv enum PdfNativeContentToken {
  Number(Double)
  Name(String)
  Word(String)
  LiteralString(PdfNativeTokenizedString)
  HexString(String)
  Array(Array[PdfNativeContentToken])
  Dict(String)
}

///|
priv struct PdfNativeTextFragment {
  text : String
  preserves_outer_space : Bool
  x : Double
  y : Double
  font_name : String?
  font_size : Double?
  bbox : PdfBBox
}

///|
priv struct PdfNativeGraphicsMatrix {
  a : Double
  d : Double
  e : Double
  f : Double
}

///|
fn pdf_parse_objects(
  bytes : Bytes,
  view : String,
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  ignore(view)
  let objects : Array[PdfNativeObject] = []
  let mut cursor = 0
  while true {
    let header = match pdf_find_next_object_header_bytes(bytes, cursor) {
      Some(found) => found
      None => break
    }
    let endobj = match
      pdf_find_bytes(bytes, pdf_ascii_bytes("endobj"), header.body_start) {
      Some(index) => index
      None =>
        return Err(
          PdfNativeError::ParseFailed(
            "unterminated PDF object " + header.object_id.to_string(),
          ),
        )
    }
    let object_body = bytes[header.body_start:endobj].to_owned()
    let stream_slice = match pdf_extract_stream_slice(object_body) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let dict_text = match stream_slice {
      Some(slice) => slice.0
      None => pdf_byte_string(object_body).trim().to_owned()
    }
    let stream = match stream_slice {
      Some(slice) => Some(slice.1)
      None => None
    }
    objects.push({ object_id: header.object_id, dict_text, stream })
    cursor = endobj + "endobj".length()
  }
  let expanded = match pdf_expand_object_streams(objects) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  objects.append(expanded[:])
  Ok(objects)
}

///|
priv struct PdfNativeObjectHeader {
  object_id : Int
  body_start : Int
}

///|
fn pdf_find_next_object_header_bytes(
  bytes : Bytes,
  start : Int,
) -> PdfNativeObjectHeader? {
  let mut cursor = start
  while cursor < bytes.length() {
    let marker = match pdf_find_bytes(bytes, pdf_ascii_bytes(" obj"), cursor) {
      Some(index) => index
      None => return None
    }
    let line_start = pdf_previous_line_start_bytes(bytes, marker)
    let header = pdf_byte_string(bytes[line_start:marker].to_owned())
      .trim()
      .to_owned()
    let parts = pdf_split_ascii_whitespace(header)
    if parts.length() >= 2 {
      match (pdf_parse_int(parts[0]), pdf_parse_int(parts[1])) {
        (Some(object_id), Some(generation)) => {
          ignore(generation)
          let body_start = pdf_skip_object_header_whitespace_bytes(
            bytes,
            marker + " obj".length(),
          )
          return Some({ object_id, body_start })
        }
        _ => ()
      }
    }
    cursor = marker + " obj".length()
  }
  None
}

///|
fn pdf_extract_stream_slice(
  object_body : Bytes,
) -> Result[(String, PdfNativeStreamSlice)?, PdfNativeError] {
  match pdf_find_bytes(object_body, pdf_ascii_bytes("stream"), 0) {
    None => Ok(None)
    Some(stream_rel) => {
      let dict_text = pdf_byte_string(object_body[:stream_rel].to_owned())
        .trim()
        .to_owned()
      let raw_start0 = stream_rel + "stream".length()
      let raw_start = if raw_start0 + 1 < object_body.length() &&
        pdf_byte_at(object_body, raw_start0) == '\r'.to_int() &&
        pdf_byte_at(object_body, raw_start0 + 1) == '\n'.to_int() {
        raw_start0 + 2
      } else if raw_start0 < object_body.length() &&
        (
          pdf_byte_at(object_body, raw_start0) == '\n'.to_int() ||
          pdf_byte_at(object_body, raw_start0) == '\r'.to_int()
        ) {
        raw_start0 + 1
      } else {
        raw_start0
      }
      let declared_length = match pdf_extract_int_after(dict_text, "/Length") {
        Some(length) if length >= 0 => Some(length)
        _ => None
      }
      let endstream_rel = match
        pdf_find_bytes(object_body, pdf_ascii_bytes("endstream"), raw_start) {
        Some(index) => index
        None =>
          return Err(
            PdfNativeError::ParseFailed(
              "stream object is missing endstream marker",
            ),
          )
      }
      let mut trimmed_end = endstream_rel
      if trimmed_end >= 2 &&
        pdf_byte_at(object_body, trimmed_end - 2) == '\r'.to_int() &&
        pdf_byte_at(object_body, trimmed_end - 1) == '\n'.to_int() {
        trimmed_end -= 2
      } else if trimmed_end >= 1 &&
        (
          pdf_byte_at(object_body, trimmed_end - 1) == '\n'.to_int() ||
          pdf_byte_at(object_body, trimmed_end - 1) == '\r'.to_int()
        ) {
        trimmed_end -= 1
      }
      if trimmed_end < raw_start {
        trimmed_end = raw_start
      }
      let endstream_bytes = object_body[raw_start:trimmed_end].to_owned()
      let primary_bytes = match declared_length {
        Some(length) if raw_start + length <= object_body.length() =>
          object_body[raw_start:raw_start + length].to_owned()
        _ => endstream_bytes
      }
      Ok(Some((dict_text, { primary_bytes, endstream_bytes, declared_length })))
    }
  }
}

///|
fn pdf_collect_font_infos(
  object_index : Map[Int, PdfNativeObject],
) -> Result[Map[Int, PdfNativeFontInfo], PdfNativeError] {
  let fonts : Map[Int, PdfNativeFontInfo] = Map([])
  for entry in object_index.to_array() {
    let object = entry.1
    if !pdf_object_is_font(object) {
      continue
    }
    let to_unicode_ref = pdf_extract_object_reference_after(
      object.dict_text,
      "/ToUnicode",
    )
    let mut tounicode_decode_failed = false
    let unicode_info = match to_unicode_ref {
      Some(ref_id) =>
        match object_index.get(ref_id) {
          Some(cmap_object) => {
            let cmap_text = match pdf_decode_cmap_stream_text(cmap_object) {
              Ok(result) => {
                ignore(pdf_cmap_stream_decode_result_summary(result))
                result.text
              }
              Err(failure) => {
                tounicode_decode_failed = true
                ignore(pdf_cmap_stream_decode_failure_summary(failure))
                ""
              }
            }
            if cmap_text == "" {
              (Map([]), [])
            } else {
              pdf_parse_tounicode_cmap(cmap_text)
            }
          }
          None => (Map([]), [])
        }
      None => (Map([]), [])
    }
    fonts.set(object.object_id, {
      base_font: pdf_extract_name_after(object.dict_text, "/BaseFont"),
      normalized_base_font: pdf_normalized_pdf_font_name(
        pdf_extract_name_after(object.dict_text, "/BaseFont"),
      ),
      encoding_name: pdf_extract_name_after(object.dict_text, "/Encoding"),
      code_hex_widths: unicode_info.1,
      unicode_map: unicode_info.0,
      has_tounicode: to_unicode_ref is Some(_) && !tounicode_decode_failed,
      tounicode_decode_failed,
    })
  }
  Ok(fonts)
}

///|
fn pdf_build_native_pages(
  source : @input.InputSource,
  objects : Array[PdfNativeObject],
  object_index : Map[Int, PdfNativeObject],
  fonts : Map[Int, PdfNativeFontInfo],
  page_numbers : Map[Int, Int],
) -> Result[Array[PdfNativePage], PdfNativeError] {
  let pages : Array[PdfNativePage] = []
  let mut page_no = 1
  for object in objects {
    if !pdf_object_is_page(object) {
      continue
    }
    let geometry = pdf_page_geometry(object, object_index, page_no)
    let font_aliases = pdf_page_font_aliases(object, object_index)
    let content_refs = pdf_extract_object_references_after(
      object.dict_text,
      "/Contents",
    )
    let fragments : Array[PdfNativeTextFragment] = []
    for content_ref in content_refs {
      let content_object = match object_index.get(content_ref) {
        Some(found) => found
        None =>
          return Err(
            PdfNativeError::ParseFailed(
              "page " +
              page_no.to_string() +
              " references missing content object " +
              content_ref.to_string(),
            ),
          )
      }
      let content_text = match
        pdf_decode_stream_text(content_object, "content stream") {
        Ok(text) => text
        Err(err) => return Err(err)
      }
      let page_fragments = match
        pdf_extract_text_fragments_from_stream(
          source, geometry, font_aliases, fonts, content_text,
        ) {
        Ok(parsed) => parsed
        Err(err) => return Err(err)
      }
      fragments.append(page_fragments[:])
    }
    let lines = pdf_group_text_fragments_into_lines(source, geometry, fragments)
    let text_blocks = pdf_group_lines_into_text_blocks(source, geometry, lines)
    let link_candidates = pdf_page_link_candidates(
      source, object, object_index, geometry, page_numbers,
    )
    let annotations = pdf_page_annotations(
      source, object, object_index, geometry, page_numbers,
    )
    let destinations = pdf_page_destinations(annotations)
    let diagnostics = @core.empty_diagnostics()
    diagnostics.metrics.set("page_no", page_no.to_string())
    diagnostics.metrics.set("text_line_count", lines.length().to_string())
    diagnostics.metrics.set(
      "text_block_count",
      text_blocks.length().to_string(),
    )
    diagnostics.metrics.set(
      "text_span_count",
      pdf_native_count_line_spans(lines).to_string(),
    )
    diagnostics.metrics.set("pdf_grouping_strategy", "conservative_v1")
    diagnostics.metrics.set(
      "pdf_grouping_line_merge_count",
      (lines.length() - text_blocks.length()).to_string(),
    )
    diagnostics.metrics.set(
      "pdf_grouping_paragraph_count",
      text_blocks.length().to_string(),
    )
    diagnostics.metrics.set("link_count", link_candidates.length().to_string())
    diagnostics.metrics.set(
      "pdf_native_annotation_count",
      annotations.length().to_string(),
    )
    diagnostics.metrics.set(
      "pdf_native_destination_count",
      destinations.length().to_string(),
    )
    diagnostics.metrics.set("table_count", "0")
    diagnostics.metrics.set("image_count", "0")
    pages.push(
      make_pdf_native_page(
        geometry,
        text_blocks~,
        link_candidates~,
        annotations~,
        destinations~,
        diagnostics~,
      ),
    )
    page_no += 1
  }
  Ok(pages)
}

///|
fn pdf_decode_stream_text(
  object : PdfNativeObject,
  context : String,
) -> Result[String, PdfNativeError] {
  let stream = match object.stream {
    Some(value) => value
    None =>
      return Err(
        PdfNativeError::ParseFailed(
          "object " +
          object.object_id.to_string() +
          " has no stream for " +
          context,
        ),
      )
  }
  let stream_bytes = stream.primary_bytes
  let filters = pdf_extract_filter_names(object.dict_text)
  let decoded = if filters.length() == 0 {
    Ok(stream_bytes)
  } else if filters.length() == 1 && filters[0] == "FlateDecode" {
    match @dpdfnative.inflate_pdf_stream(stream_bytes) {
      Ok(bytes) => Ok(bytes)
      Err(err) =>
        Err(
          PdfNativeError::ParseFailed(
            "flate decode failed for object " +
            object.object_id.to_string() +
            " (" +
            context +
            "): " +
            err,
          ),
        )
    }
  } else {
    Err(
      PdfNativeError::UnsupportedFeature(
        "unsupported PDF stream filter in object " +
        object.object_id.to_string() +
        " (" +
        context +
        "): " +
        filters.join(","),
      ),
    )
  }
  match decoded {
    Ok(bytes) => Ok(pdf_byte_string(bytes))
    Err(err) => Err(err)
  }
}

///|
/// ToUnicode/CMap-scoped decode adapter. This is not a generic PDF StreamDecode
/// framework and must stay local to font CMap recovery.
fn pdf_decode_cmap_stream_text(
  object : PdfNativeObject,
) -> Result[PdfCMapStreamDecodeResult, PdfCMapStreamDecodeFailure] {
  let stream = match object.stream {
    Some(value) => value
    None =>
      return Err({
        strategy: Failed,
        diagnostics: {
          filter_name: "missing",
          input_length: 0,
          declared_length: None,
          actual_sliced_length: 0,
          zlib_status: "skipped:no_stream",
          raw_fallback: Skipped("no_stream"),
        },
        message: "object " +
        object.object_id.to_string() +
        " has no CMap stream",
      })
  }
  let filters = pdf_extract_filter_names(object.dict_text)
  let selected_bytes = pdf_cmap_stream_selected_bytes(stream)
  let diagnostics : PdfCMapStreamDecodeDiagnostics = {
    filter_name: if filters.length() == 0 {
      "none"
    } else {
      filters.join(",")
    },
    input_length: selected_bytes.length(),
    declared_length: stream.declared_length,
    actual_sliced_length: stream.endstream_bytes.length(),
    zlib_status: "skipped",
    raw_fallback: Skipped("not_needed"),
  }
  if filters.length() == 0 {
    return Ok({
      text: pdf_byte_string(selected_bytes),
      strategy: NoFilter,
      diagnostics,
    })
  }
  if filters.length() != 1 || filters[0] != "FlateDecode" {
    return Err({
      strategy: Failed,
      diagnostics: pdf_cmap_decode_diagnostics_with(
        diagnostics,
        raw_fallback=Skipped("unsupported_filter"),
      ),
      message: "unsupported CMap stream filter: " + filters.join(","),
    })
  }
  match @dpdfnative.inflate_pdf_stream(selected_bytes) {
    Ok(bytes) =>
      Ok({
        text: pdf_byte_string(bytes),
        strategy: ZlibFlateDecode,
        diagnostics: pdf_cmap_decode_diagnostics_with(
          diagnostics,
          zlib_status="ok",
          raw_fallback=Skipped("not_needed"),
        ),
      })
    Err(err) =>
      Err({
        strategy: Failed,
        diagnostics: pdf_cmap_decode_diagnostics_with(
          diagnostics,
          zlib_status="failed:" + err,
          raw_fallback=Skipped("no_raw_flate_evidence"),
        ),
        message: "flate decode failed for object " +
        object.object_id.to_string() +
        " (cmap): " +
        err,
      })
  }
}

///|
fn pdf_cmap_stream_selected_bytes(stream : PdfNativeStreamSlice) -> Bytes {
  if stream.primary_bytes.length() == stream.endstream_bytes.length() + 1 &&
    pdf_bytes_match_except_suffix(stream.primary_bytes, stream.endstream_bytes) &&
    pdf_stream_suffix_is_single_eol(
      stream.primary_bytes,
      stream.endstream_bytes,
    ) {
    stream.endstream_bytes
  } else {
    stream.primary_bytes
  }
}

///|
fn pdf_cmap_decode_diagnostics_with(
  base : PdfCMapStreamDecodeDiagnostics,
  zlib_status? : String = base.zlib_status,
  raw_fallback? : PdfCMapRawFallbackStatus = base.raw_fallback,
) -> PdfCMapStreamDecodeDiagnostics {
  {
    filter_name: base.filter_name,
    input_length: base.input_length,
    declared_length: base.declared_length,
    actual_sliced_length: base.actual_sliced_length,
    zlib_status,
    raw_fallback,
  }
}

///|
fn pdf_cmap_stream_decode_strategy_name(
  strategy : PdfCMapStreamDecodeStrategy,
) -> String {
  match strategy {
    NoFilter => "NoFilter"
    ZlibFlateDecode => "ZlibFlateDecode"
    Failed => "Failed"
  }
}

///|
fn pdf_cmap_raw_fallback_status_name(
  status : PdfCMapRawFallbackStatus,
) -> String {
  match status {
    Skipped(reason) => "Skipped(" + reason + ")"
  }
}

///|
fn pdf_cmap_stream_decode_result_summary(
  result : PdfCMapStreamDecodeResult,
) -> String {
  "strategy=" +
  pdf_cmap_stream_decode_strategy_name(result.strategy) +
  " filter=" +
  result.diagnostics.filter_name +
  " input=" +
  result.diagnostics.input_length.to_string() +
  " sliced=" +
  result.diagnostics.actual_sliced_length.to_string() +
  " zlib=" +
  result.diagnostics.zlib_status +
  " raw=" +
  pdf_cmap_raw_fallback_status_name(result.diagnostics.raw_fallback)
}

///|
fn pdf_cmap_stream_decode_failure_summary(
  failure : PdfCMapStreamDecodeFailure,
) -> String {
  failure.message +
  " strategy=" +
  pdf_cmap_stream_decode_strategy_name(failure.strategy) +
  " filter=" +
  failure.diagnostics.filter_name +
  " input=" +
  failure.diagnostics.input_length.to_string() +
  " sliced=" +
  failure.diagnostics.actual_sliced_length.to_string() +
  " zlib=" +
  failure.diagnostics.zlib_status +
  " raw=" +
  pdf_cmap_raw_fallback_status_name(failure.diagnostics.raw_fallback)
}

///|
fn pdf_extract_text_fragments_from_stream(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  font_aliases : Map[String, Int],
  fonts : Map[Int, PdfNativeFontInfo],
  content_text : String,
) -> Result[Array[PdfNativeTextFragment], PdfNativeError] {
  let tokens = match pdf_scan_content_tokens(content_text) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let fragments : Array[PdfNativeTextFragment] = []
  let operands : Array[PdfNativeContentToken] = []
  let graphics_stack : Array[PdfNativeGraphicsMatrix] = []
  let actual_text_stack : Array[String?] = []
  let mut current_matrix = pdf_identity_matrix()
  let mut text_matrix = pdf_identity_matrix()
  let mut in_text = false
  let mut current_font_alias : String? = None
  let mut current_font_size : Double? = None
  for token in tokens {
    match token {
      PdfNativeContentToken::Word(op) =>
        match op {
          "q" => {
            graphics_stack.push(current_matrix)
            operands.clear()
          }
          "Q" => {
            current_matrix = graphics_stack
              .pop()
              .unwrap_or(pdf_identity_matrix())
            operands.clear()
          }
          "BT" => {
            in_text = true
            text_matrix = pdf_identity_matrix()
            operands.clear()
          }
          "ET" => {
            in_text = false
            operands.clear()
          }
          "cm" => {
            if operands.length() >= 6 {
              let matrix = pdf_matrix_from_operands(operands)
              current_matrix = matrix
            }
            operands.clear()
          }
          "Tm" => {
            if operands.length() >= 6 {
              text_matrix = pdf_matrix_from_operands(operands)
            }
            operands.clear()
          }
          "Td" | "TD" => {
            if operands.length() >= 2 {
              let tx = pdf_token_number(operands[operands.length() - 2]).unwrap_or(
                0.0,
              )
              let ty = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                0.0,
              )
              text_matrix = {
                ..text_matrix,
                e: text_matrix.e + tx * pdf_text_matrix_x_scale(text_matrix),
                f: text_matrix.f + ty * pdf_text_matrix_y_scale(text_matrix),
              }
            }
            operands.clear()
          }
          "Tf" => {
            if operands.length() >= 2 {
              current_font_alias = pdf_token_name(
                operands[operands.length() - 2],
              )
              current_font_size = pdf_token_number(
                operands[operands.length() - 1],
              )
            }
            operands.clear()
          }
          "BDC" => {
            let actual_text = pdf_actual_text_from_operands(operands)
            actual_text_stack.push(actual_text)
            operands.clear()
          }
          "EMC" => {
            ignore(actual_text_stack.pop())
            operands.clear()
          }
          "Tj" => {
            if in_text && operands.length() >= 1 {
              let fragment = pdf_fragment_from_text_operand(
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
              )
              match fragment {
                Some(value) => fragments.push(value)
                None => ()
              }
            }
            operands.clear()
          }
          "TJ" => {
            if in_text && operands.length() >= 1 {
              let fragment = pdf_fragment_from_text_operand(
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
              )
              match fragment {
                Some(value) => fragments.push(value)
                None => ()
              }
            }
            operands.clear()
          }
          _ => operands.clear()
        }
      _ => operands.push(token)
    }
  }
  Ok(fragments)
}

///|
fn pdf_scan_content_tokens(
  content : String,
) -> Result[Array[PdfNativeContentToken], PdfNativeError] {
  let tokens : Array[PdfNativeContentToken] = []
  let mut index = 0
  while index < content.length() {
    index = pdf_skip_content_whitespace_and_comments(content, index)
    if index >= content.length() {
      break
    }
    let ch = pdf_char_at(content, index)
    match ch {
      '(' => {
        let parsed = pdf_parse_literal_token(content, index)
        if !parsed.0.terminated {
          return Err(
            PdfNativeError::ParseFailed(
              "unterminated PDF literal string in content stream",
            ),
          )
        }
        tokens.push(PdfNativeContentToken::LiteralString(parsed.0))
        index = parsed.1
      }
      '<' =>
        if index + 1 < content.length() &&
          pdf_char_at(content, index + 1) == '<' {
          let parsed = pdf_parse_dict_token(content, index)
          tokens.push(PdfNativeContentToken::Dict(parsed.0))
          index = parsed.1
        } else {
          let parsed = pdf_parse_hex_token(content, index)
          tokens.push(PdfNativeContentToken::HexString(parsed.0))
          index = parsed.1
        }
      '[' => {
        let parsed = match pdf_parse_array_token(content, index) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        tokens.push(PdfNativeContentToken::Array(parsed.0))
        index = parsed.1
      }
      '/' => {
        let parsed = pdf_parse_name_token(content, index)
        tokens.push(PdfNativeContentToken::Name(parsed.0))
        index = parsed.1
      }
      _ => {
        let parsed = pdf_parse_word_token(content, index)
        if parsed.1 <= index {
          index += 1
          continue
        }
        match pdf_parse_double(parsed.0) {
          Some(value) => tokens.push(PdfNativeContentToken::Number(value))
          None => tokens.push(PdfNativeContentToken::Word(parsed.0))
        }
        index = parsed.1
      }
    }
  }
  Ok(tokens)
}

///|
fn pdf_parse_array_token(
  content : String,
  start : Int,
) -> Result[(Array[PdfNativeContentToken], Int), PdfNativeError] {
  let tokens : Array[PdfNativeContentToken] = []
  let mut index = start + 1
  while index < content.length() {
    index = pdf_skip_content_whitespace_and_comments(content, index)
    if index >= content.length() {
      break
    }
    if pdf_char_at(content, index) == ']' {
      return Ok((tokens, index + 1))
    }
    let ch = pdf_char_at(content, index)
    match ch {
      '(' => {
        let parsed = pdf_parse_literal_token(content, index)
        if !parsed.0.terminated {
          return Err(
            PdfNativeError::ParseFailed(
              "unterminated PDF literal string in array token",
            ),
          )
        }
        tokens.push(PdfNativeContentToken::LiteralString(parsed.0))
        index = parsed.1
      }
      '<' =>
        if index + 1 < content.length() &&
          pdf_char_at(content, index + 1) == '<' {
          let parsed = pdf_parse_dict_token(content, index)
          tokens.push(PdfNativeContentToken::Dict(parsed.0))
          index = parsed.1
        } else {
          let parsed = pdf_parse_hex_token(content, index)
          tokens.push(PdfNativeContentToken::HexString(parsed.0))
          index = parsed.1
        }
      '[' => {
        let parsed = match pdf_parse_array_token(content, index) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        tokens.push(PdfNativeContentToken::Array(parsed.0))
        index = parsed.1
      }
      '/' => {
        let parsed = pdf_parse_name_token(content, index)
        tokens.push(PdfNativeContentToken::Name(parsed.0))
        index = parsed.1
      }
      _ => {
        let parsed = pdf_parse_word_token(content, index)
        if parsed.1 <= index {
          index += 1
          continue
        }
        match pdf_parse_double(parsed.0) {
          Some(value) => tokens.push(PdfNativeContentToken::Number(value))
          None => tokens.push(PdfNativeContentToken::Word(parsed.0))
        }
        index = parsed.1
      }
    }
  }
  Err(PdfNativeError::ParseFailed("unterminated PDF array token"))
}

///|
fn pdf_parse_literal_token(
  content : String,
  start : Int,
) -> (PdfNativeTokenizedString, Int) {
  let out : Array[Char] = []
  let mut index = start + 1
  let mut depth = 1
  while index < content.length() {
    let ch = pdf_char_at(content, index)
    if ch == '\\' {
      if index + 1 >= content.length() {
        index += 1
        break
      }
      let next = pdf_char_at(content, index + 1)
      match next {
        'n' => {
          out.push('\n')
          index += 2
          continue
        }
        'r' => {
          out.push('\r')
          index += 2
          continue
        }
        't' => {
          out.push('\t')
          index += 2
          continue
        }
        'b' => {
          out.push('\u{0008}')
          index += 2
          continue
        }
        'f' => {
          out.push('\u{000C}')
          index += 2
          continue
        }
        '(' => {
          out.push('(')
          index += 2
          continue
        }
        ')' => {
          out.push(')')
          index += 2
          continue
        }
        '\\' => {
          out.push('\\')
          index += 2
          continue
        }
        '\n' => {
          index += 2
          continue
        }
        '\r' => {
          if index + 2 < content.length() &&
            pdf_char_at(content, index + 2) == '\n' {
            index += 3
          } else {
            index += 2
          }
          continue
        }
        _ => {
          if pdf_is_octal_digit(next) {
            let octal = pdf_collect_octal_escape(content, index + 1)
            let code = pdf_parse_octal(octal.0).unwrap_or(0)
            out.push(Int::unsafe_to_char(code & 0xFF))
            index = octal.1
            continue
          }
          out.push(next)
          index += 2
          continue
        }
      }
    }
    if ch == '(' {
      depth += 1
      out.push(ch)
      index += 1
      continue
    }
    if ch == ')' {
      depth -= 1
      if depth == 0 {
        return (
          { decoded: String::from_array(out), terminated: true },
          index + 1,
        )
      }
      out.push(ch)
      index += 1
      continue
    }
    out.push(ch)
    index += 1
  }
  ({ decoded: String::from_array(out), terminated: false }, index)
}

///|
fn pdf_parse_hex_token(content : String, start : Int) -> (String, Int) {
  let mut index = start + 1
  let out : Array[Char] = []
  while index < content.length() && pdf_char_at(content, index) != '>' {
    let ch = pdf_char_at(content, index)
    if !pdf_is_ascii_whitespace_char(ch) {
      out.push(ch)
    }
    index += 1
  }
  if out.length() % 2 == 1 {
    out.push('0')
  }
  (String::from_array(out), index + 1)
}

///|
fn pdf_parse_dict_token(content : String, start : Int) -> (String, Int) {
  let mut index = start
  let mut depth = 0
  while index + 1 < content.length() {
    if pdf_char_at(content, index) == '<' &&
      pdf_char_at(content, index + 1) == '<' {
      depth += 1
      index += 2
      continue
    }
    if pdf_char_at(content, index) == '>' &&
      pdf_char_at(content, index + 1) == '>' {
      depth -= 1
      index += 2
      if depth == 0 {
        return (content[start:index].to_owned(), index)
      }
      continue
    }
    index += 1
  }
  (content[start:index].to_owned(), index)
}

///|
fn pdf_parse_name_token(content : String, start : Int) -> (String, Int) {
  let mut index = start + 1
  while index < content.length() &&
        !pdf_is_token_delimiter(pdf_char_at(content, index)) &&
        !pdf_is_ascii_whitespace_char(pdf_char_at(content, index)) {
    index += 1
  }
  (content[start + 1:index].to_owned(), index)
}

///|
fn pdf_parse_word_token(content : String, start : Int) -> (String, Int) {
  let mut index = start
  while index < content.length() &&
        !pdf_is_token_delimiter(pdf_char_at(content, index)) &&
        !pdf_is_ascii_whitespace_char(pdf_char_at(content, index)) {
    index += 1
  }
  (content[start:index].to_owned(), index)
}

///|
fn pdf_skip_content_whitespace_and_comments(
  content : String,
  start : Int,
) -> Int {
  let mut index = start
  while index < content.length() {
    let ch = pdf_char_at(content, index)
    if pdf_is_ascii_whitespace_char(ch) {
      index += 1
      continue
    }
    if ch == '%' {
      index += 1
      while index < content.length() &&
            pdf_char_at(content, index) != '\n' &&
            pdf_char_at(content, index) != '\r' {
        index += 1
      }
      continue
    }
    break
  }
  index
}

///|
fn pdf_fragment_from_text_operand(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  current_matrix : PdfNativeGraphicsMatrix,
  text_matrix : PdfNativeGraphicsMatrix,
  current_font_alias : String?,
  current_font_size : Double?,
  font_aliases : Map[String, Int],
  fonts : Map[Int, PdfNativeFontInfo],
  token : PdfNativeContentToken,
  actual_text : String?,
) -> PdfNativeTextFragment? {
  let font_object_id = match current_font_alias {
    Some(font_alias_name) => font_aliases.get(font_alias_name)
    None => None
  }
  let font_info = match font_object_id {
    Some(object_id) => fonts.get(object_id)
    None => None
  }
  let resolved_text = match actual_text {
    Some(value) if value.trim() != "" => value
    _ =>
      match pdf_decode_text_operand(token, font_info) {
        Some(text) => text
        None => return None
      }
  }
  if resolved_text.trim() == "" {
    return None
  }
  let font_name = match font_info {
    Some(info) => info.base_font
    None => current_font_alias
  }
  let preserves_outer_space = pdf_text_has_outer_space(resolved_text) &&
    pdf_text_outer_space_is_latinish(resolved_text)
  let fragment_text = if preserves_outer_space {
    pdf_normalize_pdf_fragment_text(resolved_text)
  } else {
    pdf_normalize_pdf_text(resolved_text)
  }
  if fragment_text.trim() == "" {
    return None
  }
  let font_size = pdf_effective_font_size(text_matrix, current_font_size)
  let x = current_matrix.e + text_matrix.e
  let y = current_matrix.f + text_matrix.f
  let bbox = pdf_estimate_text_bbox(fragment_text, x, y, font_size)
  let source_ref = pdf_native_source_ref(
    source,
    geometry.page_no,
    bbox,
    None,
    font_name,
    font_size,
  )
  ignore(source_ref)
  Some({
    text: fragment_text,
    preserves_outer_space,
    x,
    y,
    font_name,
    font_size: Some(font_size),
    bbox,
  })
}

///|
fn pdf_decode_text_operand(
  token : PdfNativeContentToken,
  font_info : PdfNativeFontInfo?,
) -> String? {
  match token {
    PdfNativeContentToken::LiteralString(value) =>
      Some(pdf_decode_content_literal_pdf_text(value.decoded, font_info))
    PdfNativeContentToken::HexString(hex) =>
      pdf_decode_hex_pdf_text(hex, font_info)
    PdfNativeContentToken::Array(items) =>
      match pdf_decode_joined_hex_array(items, font_info) {
        Some(text) => Some(text)
        None => {
          let parts : Array[String] = []
          for item in items {
            match item {
              PdfNativeContentToken::LiteralString(value) =>
                parts.push(
                  pdf_decode_content_literal_pdf_text(value.decoded, font_info),
                )
              PdfNativeContentToken::HexString(hex) =>
                match pdf_decode_hex_pdf_text(hex, font_info) {
                  Some(text) => parts.push(text)
                  None => ()
                }
              _ => ()
            }
          }
          let joined = parts.join("")
          if joined == "" {
            None
          } else {
            Some(joined)
          }
        }
      }
    _ => None
  }
}

///|
fn pdf_decode_hex_pdf_text(
  hex : String,
  font_info : PdfNativeFontInfo?,
) -> String? {
  if hex.trim() == "" {
    return None
  }
  match font_info {
    Some(info) if info.tounicode_decode_failed => None
    Some(info) if pdf_font_uses_code_unit_decode(info) => {
      match pdf_identity_h_ascii_rescue(hex, info) {
        Some(rescued) => return Some(rescued)
        None => ()
      }
      let widths = pdf_font_decode_widths(info)
      let parts : Array[String] = []
      let mut index = 0
      while index < hex.length() {
        let mut matched = false
        for width in widths {
          let hex_width = width * 2
          if index + hex_width > hex.length() {
            continue
          }
          let key = hex[index:index + hex_width].to_owned().to_upper()
          match info.unicode_map.get(key) {
            Some(value) => {
              if pdf_is_usable_tounicode_text(value) {
                parts.push(value)
              }
              index += hex_width
              matched = true
              break
            }
            None => ()
          }
        }
        if !matched {
          let fallback_width = match
            pdf_first_matching_code_width(widths, hex.length() - index) {
            Some(width) => width
            None => 1
          }
          let fallback_hex_width = fallback_width * 2
          if index + fallback_hex_width > hex.length() {
            break
          }
          let key = hex[index:index + fallback_hex_width].to_owned().to_upper()
          match pdf_decode_font_code_fallback(key, info) {
            Some(value) => parts.push(value)
            None => ()
          }
          index += fallback_hex_width
        }
      }
      let joined = parts.join("")
      if joined == "" {
        pdf_decode_raw_cjk_hex_fallback(hex, info)
      } else {
        Some(joined)
      }
    }
    Some(info) =>
      match pdf_decode_raw_cjk_hex_fallback(hex, info) {
        Some(decoded) => Some(decoded)
        None => pdf_hex_to_string(hex)
      }
    _ => pdf_hex_to_string(hex)
  }
}

///|
fn pdf_decode_joined_hex_array(
  items : Array[PdfNativeContentToken],
  font_info : PdfNativeFontInfo?,
) -> String? {
  let info = match font_info {
    Some(value) => value
    None => return None
  }
  if !pdf_font_uses_code_unit_decode(info) {
    return None
  }
  let hex_parts : Array[String] = []
  for item in items {
    match item {
      PdfNativeContentToken::HexString(hex) => hex_parts.push(hex)
      PdfNativeContentToken::Number(_) => ()
      _ => return None
    }
  }
  if hex_parts.length() == 0 {
    return None
  }
  pdf_decode_hex_pdf_text(hex_parts.join(""), Some(info))
}

///|
fn pdf_group_text_fragments_into_lines(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  fragments : Array[PdfNativeTextFragment],
) -> Array[PdfNativeTextLine] {
  let ordered : Array[PdfNativeTextFragment] = []
  ordered.append(fragments[:])
  ordered.sort_by(fn(left, right) {
    pdf_fragment_reading_order_compare(left, right)
  })
  let lines : Array[PdfNativeTextLine] = []
  let mut current : Array[PdfNativeTextFragment] = []
  let mut current_baseline = 0.0
  for fragment in ordered {
    if current.length() == 0 {
      current = [fragment]
      current_baseline = fragment.y
      continue
    }
    let tolerance = pdf_line_merge_tolerance(current, fragment)
    if pdf_abs_double(fragment.y - current_baseline) <= tolerance {
      current.push(fragment)
      current_baseline = (current_baseline + fragment.y) / 2.0
    } else {
      lines.push(
        pdf_finalize_line(source, geometry, current, lines.length() + 1),
      )
      current = [fragment]
      current_baseline = fragment.y
    }
  }
  if current.length() > 0 {
    lines.push(pdf_finalize_line(source, geometry, current, lines.length() + 1))
  }
  lines
}

///|
fn pdf_finalize_line(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  fragments : Array[PdfNativeTextFragment],
  line_index : Int,
) -> PdfNativeTextLine {
  let ordered : Array[PdfNativeTextFragment] = []
  ordered.append(fragments[:])
  ordered.sort_by(fn(left, right) { pdf_fragment_visual_compare(left, right) })
  let spans : Array[PdfNativeTextSpan] = []
  let mut merged_bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  let mut reading_index = 1
  for fragment in ordered {
    let gap = if spans.length() == 0 {
      None
    } else {
      Some(fragment.x - pdf_bbox_right(merged_bbox))
    }
    let prepared_text = pdf_prepare_line_text_fragment(
      fragment.text,
      gap,
      fragment.font_size,
      preserve_outer_space=fragment.preserves_outer_space,
    )
    let source_ref = pdf_native_source_ref(
      source,
      geometry.page_no,
      fragment.bbox,
      Some(line_index),
      fragment.font_name,
      fragment.font_size.unwrap_or(0.0),
      reading_order_index=Some(reading_index),
    )
    let span = make_pdf_native_text_span(
      prepared_text,
      fragment.bbox,
      source_ref=Some(source_ref),
      font_name=fragment.font_name,
      font_size=fragment.font_size,
      reading_order_index=Some(reading_index),
    )
    spans.push(span)
    merged_bbox = if pdf_bbox_is_empty(merged_bbox) {
      fragment.bbox
    } else {
      pdf_union_bbox(merged_bbox, fragment.bbox)
    }
    reading_index += 1
  }
  let line_source_ref = pdf_native_source_ref(
    source,
    geometry.page_no,
    merged_bbox,
    Some(line_index),
    None,
    0.0,
    reading_order_index=Some(line_index),
  )
  make_pdf_native_text_line(
    spans,
    merged_bbox,
    source_ref=Some(line_source_ref),
    reading_order_index=Some(line_index),
  )
}

///|
fn pdf_group_lines_into_text_blocks(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  lines : Array[PdfNativeTextLine],
) -> Array[PdfNativeTextBlock] {
  let ordered : Array[PdfNativeTextLine] = []
  ordered.append(lines[:])
  ordered.sort_by(fn(left, right) {
    pdf_native_line_reading_order_compare(left, right)
  })
  let blocks : Array[PdfNativeTextBlock] = []
  let mut current : Array[PdfNativeTextLine] = []
  for line in ordered {
    if pdf_native_line_text(line) == "" {
      continue
    }
    if current.length() == 0 {
      current = [line]
      continue
    }
    if pdf_should_merge_line_into_block(current, line) {
      current.push(line)
    } else {
      blocks.push(
        pdf_finalize_text_block(source, geometry, current, blocks.length() + 1),
      )
      current = [line]
    }
  }
  if current.length() > 0 {
    blocks.push(
      pdf_finalize_text_block(source, geometry, current, blocks.length() + 1),
    )
  }
  blocks
}

///|
fn pdf_finalize_text_block(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  lines : Array[PdfNativeTextLine],
  block_index : Int,
) -> PdfNativeTextBlock {
  let block_bbox = pdf_native_lines_bbox(lines)
  let first_line = lines[0]
  let base_ref = pdf_native_line_base_source_ref(first_line)
  let first_page = base_ref.page.unwrap_or(geometry.page_no)
  let first_line_no = base_ref.line_start.unwrap_or(block_index)
  let last_line_ref = pdf_native_line_base_source_ref(lines[lines.length() - 1])
  let last_line_no = last_line_ref.line_end.unwrap_or(
    last_line_ref.line_start.unwrap_or(first_line_no),
  )
  let block_source_ref = pdf_native_source_ref(
    source,
    first_page,
    block_bbox,
    Some(first_line_no),
    None,
    0.0,
    reading_order_index=first_line.reading_order_index,
  )
  let next = { ..block_source_ref, line_end: Some(last_line_no) }
  next.extra.set("pdf_text_block_index", block_index.to_string())
  make_pdf_native_text_block(
    lines,
    block_bbox,
    source_ref=Some(next),
    reading_order_index=first_line.reading_order_index,
  )
}

///|
fn pdf_should_merge_line_into_block(
  current : Array[PdfNativeTextLine],
  next : PdfNativeTextLine,
) -> Bool {
  if current.length() == 0 {
    return true
  }
  let previous = current[current.length() - 1]
  if pdf_native_line_text(previous) == "" || pdf_native_line_text(next) == "" {
    return false
  }
  if pdf_line_looks_like_list_boundary(previous) ||
    pdf_line_looks_like_list_boundary(next) {
    return false
  }
  if pdf_line_has_strong_terminal_punctuation(previous) {
    return false
  }
  if !pdf_line_looks_like_continuation(next) {
    return false
  }
  let vertical_gap = pdf_native_line_vertical_gap(previous, next)
  let max_height = pdf_double_max(previous.bbox.height, next.bbox.height)
  if vertical_gap > pdf_double_max(6.0, max_height * 1.2) {
    return false
  }
  let left_shift = pdf_abs_double(previous.bbox.x - next.bbox.x)
  let max_width = pdf_double_max(previous.bbox.width, next.bbox.width)
  let indent_threshold = pdf_double_max(8.0, max_width * 0.12)
  if left_shift > indent_threshold {
    return false
  }
  let font_gap = pdf_abs_double(
    pdf_native_line_average_font_size(previous) -
    pdf_native_line_average_font_size(next),
  )
  if font_gap > 1.5 {
    return false
  }
  true
}

///|
fn pdf_line_looks_like_list_boundary(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return true
  }
  let chars = trimmed.to_array()
  if chars.length() >= 2 &&
    pdf_is_ascii_digit(chars[0]) &&
    (chars[1] == '.' || chars[1] == ')') {
    return true
  }
  false
}

///|
fn pdf_line_has_strong_terminal_punctuation(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  match trimmed.to_array()[trimmed.length() - 1] {
    '.' => true
    '!' => true
    '?' => true
    ':' => true
    ';' => true
    '。' => true
    '！' => true
    '？' => true
    '：' => true
    '；' => true
    _ => false
  }
}

///|
fn pdf_line_looks_like_continuation(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let first = trimmed.to_array()[0]
  pdf_is_cjk_char(first) ||
  (first >= 'a' && first <= 'z') ||
  first == '"' ||
  first == '\'' ||
  first == '(' ||
  first == '['
}

///|
fn pdf_native_line_average_font_size(line : PdfNativeTextLine) -> Double {
  let mut total = 0.0
  let mut count = 0
  for span in line.spans {
    match span.font_size {
      Some(value) => {
        total += value
        count += 1
      }
      None => ()
    }
  }
  if count == 0 {
    12.0
  } else {
    total / count.to_double()
  }
}

///|
fn pdf_native_line_vertical_gap(
  upper : PdfNativeTextLine,
  lower : PdfNativeTextLine,
) -> Double {
  let upper_bottom = pdf_bbox_bottom(upper.bbox)
  let lower_top = lower.bbox.y
  if lower_top > upper_bottom {
    lower_top - upper_bottom
  } else {
    0.0
  }
}

///|
fn pdf_page_link_candidates(
  source : @input.InputSource,
  page_object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  geometry : PdfPageGeometry,
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeLinkCandidate] {
  let links : Array[PdfNativeLinkCandidate] = []
  for
    annotation in pdf_page_annotations(
      source, page_object, object_index, geometry, page_numbers,
    ) {
    if annotation.subtype != "Link" {
      continue
    }
    match (annotation.bbox, annotation.target) {
      (Some(bbox), Some(target)) =>
        links.push(
          make_pdf_native_link_candidate(
            bbox,
            target,
            text=annotation.text,
            source_ref=annotation.source_ref,
            annotation_index=annotation.annotation_index,
            annotation_object_id=annotation.object_id,
          ),
        )
      _ => ()
    }
  }
  links
}

///|
fn pdf_page_annotations(
  source : @input.InputSource,
  page_object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  geometry : PdfPageGeometry,
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeAnnotation] {
  let refs = pdf_extract_resolved_object_references_after(
    page_object.dict_text,
    "/Annots",
    object_index,
  )
  let annotations : Array[PdfNativeAnnotation] = []
  for i in 0..<refs.length() {
    let ref_id = refs[i]
    match object_index.get(ref_id) {
      Some(object) =>
        match
          pdf_annotation_from_object(
            source,
            object,
            object_index,
            geometry.page_no,
            i,
            ref_id,
            page_numbers,
          ) {
          Some(annotation) => annotations.push(annotation)
          None => ()
        }
      None => ()
    }
  }
  annotations
}

///|
fn pdf_page_destinations(
  annotations : Array[PdfNativeAnnotation],
) -> Array[PdfNativeDestination] {
  let destinations : Array[PdfNativeDestination] = []
  for annotation in annotations {
    match annotation.destination {
      Some(destination) => destinations.push(destination)
      None => ()
    }
  }
  destinations
}

///|
fn pdf_parse_tounicode_cmap(
  cmap_text : String,
) -> (Map[String, String], Array[Int]) {
  let mapping : Map[String, String] = Map([])
  let widths : Map[Int, Bool] = Map([])
  let tokens = match pdf_scan_content_tokens(cmap_text) {
    Ok(value) => value
    Err(_) => return (mapping, [2])
  }
  let mut in_codespacerange = false
  let mut in_bfchar = false
  let mut in_bfrange = false
  let mut index = 0
  while index < tokens.length() {
    match tokens[index] {
      PdfNativeContentToken::Word("begincodespacerange") => {
        in_codespacerange = true
        in_bfchar = false
        in_bfrange = false
      }
      PdfNativeContentToken::Word("endcodespacerange") =>
        in_codespacerange = false
      PdfNativeContentToken::Word("beginbfchar") => {
        in_codespacerange = false
        in_bfchar = true
        in_bfrange = false
      }
      PdfNativeContentToken::Word("endbfchar") => in_bfchar = false
      PdfNativeContentToken::Word("beginbfrange") => {
        in_codespacerange = false
        in_bfchar = false
        in_bfrange = true
      }
      PdfNativeContentToken::Word("endbfrange") => in_bfrange = false
      PdfNativeContentToken::HexString(start_hex) if in_codespacerange =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            PdfNativeContentToken::HexString(_end_hex) => {
              let width = start_hex.length() / 2
              if width > 0 {
                widths.set(width, true)
              }
              index += 1
            }
            _ => ()
          }
        }
      PdfNativeContentToken::HexString(src) if in_bfchar =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            PdfNativeContentToken::HexString(dst) => {
              let width = src.length() / 2
              if width > 0 {
                widths.set(width, true)
              }
              let value = pdf_hex_to_string(dst).unwrap_or("")
              if src != "" && pdf_is_usable_tounicode_text(value) {
                mapping.set(src.to_upper(), value)
              }
              index += 1
            }
            _ => ()
          }
        }
      PdfNativeContentToken::HexString(start_hex) if in_bfrange =>
        if index + 2 < tokens.length() {
          let start_width = start_hex.length() / 2
          if start_width > 0 {
            widths.set(start_width, true)
          }
          match (tokens[index + 1], tokens[index + 2]) {
            (
              PdfNativeContentToken::HexString(end_hex),
              PdfNativeContentToken::HexString(base_hex),
            ) =>
              pdf_apply_tounicode_bfrange(
                mapping,
                start_hex,
                end_hex,
                base_hex,
                None,
              )
            (
              PdfNativeContentToken::HexString(end_hex),
              PdfNativeContentToken::Array(items),
            ) =>
              pdf_apply_tounicode_bfrange(
                mapping,
                start_hex,
                end_hex,
                "",
                Some(items),
              )
            _ => ()
          }
          index += 2
        }
      _ => ()
    }
    index += 1
  }
  let sorted_widths = pdf_sort_desc_widths(widths)
  if sorted_widths.length() == 0 {
    (mapping, [2])
  } else {
    (mapping, sorted_widths)
  }
}

///|
fn pdf_apply_tounicode_bfrange(
  mapping : Map[String, String],
  start_hex : String,
  end_hex : String,
  base_hex : String,
  values : Array[PdfNativeContentToken]?,
) -> Unit {
  match (pdf_parse_hex_int(start_hex), pdf_parse_hex_int(end_hex)) {
    (Some(start_code), Some(end_code)) =>
      match values {
        Some(items) => {
          let mut cursor = start_code
          for item in items {
            if cursor > end_code {
              break
            }
            match item {
              PdfNativeContentToken::HexString(value_hex) => {
                let value = pdf_hex_to_string(value_hex).unwrap_or("")
                if pdf_is_usable_tounicode_text(value) {
                  mapping.set(pdf_hex_upper(cursor, start_hex.length()), value)
                }
                cursor += 1
              }
              _ => ()
            }
          }
        }
        None =>
          match pdf_first_codepoint_from_hex(base_hex) {
            Some(base_cp) =>
              for offset in 0..<(end_code - start_code + 1) {
                let key = pdf_hex_upper(start_code + offset, start_hex.length())
                let value = String::from_array([
                  Int::unsafe_to_char(base_cp + offset),
                ])
                mapping.set(key, value)
              }
            None => ()
          }
      }
    _ => ()
  }
}

///|
fn pdf_sort_desc_widths(widths : Map[Int, Bool]) -> Array[Int] {
  let out : Array[Int] = []
  for entry in widths.to_array() {
    if entry.1 && entry.0 > 0 {
      out.push(entry.0)
    }
  }
  out.sort_by(fn(left, right) {
    if left > right {
      -1
    } else if left < right {
      1
    } else {
      0
    }
  })
  out
}

///|
fn pdf_page_geometry(
  page_object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  page_no : Int,
) -> PdfPageGeometry {
  let media_box = match
    pdf_extract_rect_after(page_object.dict_text, "/MediaBox") {
    Some(bbox) => Some(bbox)
    None =>
      match pdf_extract_parent_page_boxes(page_object.dict_text, object_index) {
        Some(bbox) => Some(bbox)
        None => None
      }
  }
  match media_box {
    Some(bbox) =>
      make_pdf_page_geometry(
        page_no,
        bbox.width,
        bbox.height,
        crop_box=Some(bbox),
      )
    None => make_pdf_page_geometry(page_no, 0.0, 0.0)
  }
}

///|
fn pdf_object_is_font(object : PdfNativeObject) -> Bool {
  match pdf_extract_name_after(object.dict_text, "/Type") {
    Some("Font") => true
    _ => object.dict_text.contains("/Type /Font")
  }
}

///|
fn pdf_extract_parent_page_boxes(
  page_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> PdfBBox? {
  match pdf_extract_object_reference_after(page_text, "/Parent") {
    Some(parent_id) =>
      match object_index.get(parent_id) {
        Some(parent) => pdf_extract_rect_after(parent.dict_text, "/MediaBox")
        None => None
      }
    None => None
  }
}

///|
fn pdf_page_font_aliases(
  page_object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> Map[String, Int] {
  let aliases : Map[String, Int] = Map([])
  let resources_text = match
    pdf_extract_resources_text(page_object.dict_text, object_index) {
    Some(text) => text
    None => return aliases
  }
  let font_dict_text = match
    pdf_extract_inline_dict_after(resources_text, "/Font") {
    Some(text) => text
    None =>
      match pdf_extract_object_reference_after(resources_text, "/Font") {
        Some(font_ref) =>
          match object_index.get(font_ref) {
            Some(font_object) => font_object.dict_text
            None => return aliases
          }
        None => return aliases
      }
  }
  match pdf_parse_dict_entries(font_dict_text) {
    Some(entries) =>
      for entry in entries {
        match entry.1 {
          PdfNativeDictValue::Reference(object_id, generation) => {
            ignore(generation)
            if entry.0.has_prefix("/") && entry.0.length() > 1 {
              aliases.set(entry.0[1:].to_owned(), object_id)
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  aliases
}

///|
fn pdf_extract_resources_text(
  page_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  match pdf_extract_inline_dict_after(page_text, "/Resources") {
    Some(text) => Some(text)
    None =>
      match pdf_extract_object_reference_after(page_text, "/Resources") {
        Some(ref_id) =>
          match object_index.get(ref_id) {
            Some(object) => Some(object.dict_text)
            None => None
          }
        None => pdf_extract_parent_resources_text(page_text, object_index, 8)
      }
  }
}

///|
fn pdf_extract_parent_resources_text(
  page_text : String,
  object_index : Map[Int, PdfNativeObject],
  remaining_depth : Int,
) -> String? {
  if remaining_depth <= 0 {
    return None
  }
  match pdf_extract_object_reference_after(page_text, "/Parent") {
    Some(parent_id) =>
      match object_index.get(parent_id) {
        Some(parent) =>
          match pdf_extract_resources_text(parent.dict_text, object_index) {
            Some(text) => Some(text)
            None =>
              pdf_extract_parent_resources_text(
                parent.dict_text,
                object_index,
                remaining_depth - 1,
              )
          }
        None => None
      }
    None => None
  }
}

///|
fn pdf_extract_info_metadata(
  view : String,
  object_index : Map[Int, PdfNativeObject],
) -> Map[String, @core.JsonValue]? {
  let trailer_index = match pdf_find_substring(view, "trailer", 0) {
    Some(index) => index
    None => return None
  }
  let info_ref = match
    pdf_extract_object_reference_after(view[trailer_index:].to_owned(), "/Info") {
    Some(ref_id) => ref_id
    None => return None
  }
  let info_object = match object_index.get(info_ref) {
    Some(object) => object
    None => return None
  }
  let metadata : Map[String, @core.JsonValue] = Map([])
  for
    key in [
      "/Title", "/Author", "/Subject", "/Keywords", "/Producer", "/Creator",
    ] {
    match pdf_extract_literal_string_after(info_object.dict_text, key) {
      Some(value) if value.trim() != "" =>
        metadata.set(
          key[1:].to_owned().to_lower(),
          @core.JsonValue::String(pdf_normalize_pdf_text(value)),
        )
      _ => ()
    }
  }
  if metadata.length() == 0 {
    None
  } else {
    Some(metadata)
  }
}

///|
fn pdf_page_object_ids(objects : Array[PdfNativeObject]) -> Array[Int] {
  let out : Array[Int] = []
  let seen : Map[Int, Bool] = Map([])
  for object in objects {
    if pdf_object_is_page(object) &&
      !seen.get(object.object_id).unwrap_or(false) {
      seen.set(object.object_id, true)
      out.push(object.object_id)
    }
  }
  out
}

///|
fn pdf_page_number_index(page_object_ids : Array[Int]) -> Map[Int, Int] {
  let index : Map[Int, Int] = Map([])
  for i in 0..<page_object_ids.length() {
    index.set(page_object_ids[i], i + 1)
  }
  index
}

///|
fn pdf_annotation_page_index(
  objects : Array[PdfNativeObject],
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Map[Int, Int] {
  let index : Map[Int, Int] = Map([])
  for object in objects {
    if !pdf_object_is_page(object) {
      continue
    }
    let page_index = match page_numbers.get(object.object_id) {
      Some(value) => value
      None => continue
    }
    for
      ref_id in pdf_extract_resolved_object_references_after(
        object.dict_text,
        "/Annots",
        object_index,
      ) {
      if index.get(ref_id) == None {
        index.set(ref_id, page_index)
      }
    }
  }
  index
}

///|
fn pdf_trailer_text(view : String) -> String? {
  let trailer_index = match pdf_find_substring(view, "trailer", 0) {
    Some(index) => index
    None => return None
  }
  Some(view[trailer_index:].to_owned())
}

///|
fn pdf_catalog_object(
  view : String,
  object_index : Map[Int, PdfNativeObject],
) -> PdfNativeObject? {
  let trailer = match pdf_trailer_text(view) {
    Some(value) => value
    None => return pdf_catalog_object_fallback(object_index)
  }
  let root_ref = match pdf_extract_object_reference_after(trailer, "/Root") {
    Some(value) => value
    None => return pdf_catalog_object_fallback(object_index)
  }
  match object_index.get(root_ref) {
    Some(value) => Some(value)
    None => pdf_catalog_object_fallback(object_index)
  }
}

///|
fn pdf_object_is_page(object : PdfNativeObject) -> Bool {
  match pdf_extract_dict_value(object.dict_text, "/Type") {
    Some(PdfNativeDictValue::Name("Page")) => true
    _ => false
  }
}

///|
fn pdf_extract_object_reference_after(text : String, key : String) -> Int? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      Some(object_id)
    }
    _ => None
  }
}

///|
fn pdf_extract_object_references_after(
  text : String,
  key : String,
) -> Array[Int] {
  let refs : Array[Int] = []
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      refs.push(object_id)
    }
    Some(PdfNativeDictValue::Array(tokens)) =>
      refs.append(pdf_collect_reference_ids_from_tokens(tokens)[:])
    _ => ()
  }
  refs
}

///|
fn pdf_extract_resolved_object_references_after(
  text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
) -> Array[Int] {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) => {
          let refs = pdf_reference_ids_from_object_text(object.dict_text)
          if refs.length() > 0 {
            refs
          } else {
            [object_id]
          }
        }
        None => [object_id]
      }
    }
    Some(PdfNativeDictValue::Array(tokens)) =>
      pdf_collect_reference_ids_from_tokens(tokens)
    _ => []
  }
}

///|
fn pdf_reference_ids_from_object_text(text : String) -> Array[Int] {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("[") {
    return []
  }
  let tokens = match pdf_scan_content_tokens(trimmed) {
    Ok(value) => value
    Err(_) => return []
  }
  if tokens.length() == 1 {
    match tokens[0] {
      PdfNativeContentToken::Array(items) =>
        return pdf_collect_reference_ids_from_tokens(items)
      _ => ()
    }
  }
  pdf_collect_reference_ids_from_tokens(tokens)
}

///|
fn pdf_catalog_object_fallback(
  object_index : Map[Int, PdfNativeObject],
) -> PdfNativeObject? {
  for entry in object_index.to_array() {
    let object = entry.1
    match pdf_extract_name_after(object.dict_text, "/Type") {
      Some("Catalog") => return Some(object)
      _ => ()
    }
  }
  None
}

///|
fn pdf_extract_name_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Name(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_int_after(text : String, key : String) -> Int? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Number(value)) =>
      if pdf_double_is_integral(value) {
        Some(value.to_int())
      } else {
        None
      }
    Some(PdfNativeDictValue::Word(value)) => pdf_parse_int(value)
    _ => None
  }
}

///|
fn pdf_extract_literal_string_after(text : String, key : String) -> String? {
  let tail = match pdf_slice_after_key(text, key) {
    Some(value) => value
    None => return None
  }
  match tail.find("(") {
    Some(rel) => {
      let parsed = pdf_parse_literal_token(tail, rel)
      if parsed.0.terminated {
        Some(pdf_decode_literal_pdf_text(parsed.0.decoded))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn pdf_extract_rect_after(text : String, key : String) -> PdfBBox? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Array(tokens)) if tokens.length() >= 4 =>
      match
        (
          pdf_token_number(tokens[0]),
          pdf_token_number(tokens[1]),
          pdf_token_number(tokens[2]),
          pdf_token_number(tokens[3]),
        ) {
        (Some(x0), Some(y0), Some(x1), Some(y1)) =>
          Some(make_pdf_bbox(x0, y0, x1 - x0, y1 - y0))
        _ => None
      }
    _ => None
  }
}

///|
fn pdf_extract_inline_dict_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Dict(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_string_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::LiteralString(value)) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(value.decoded)))
    Some(PdfNativeDictValue::HexString(value)) =>
      match pdf_decode_hex_pdf_text(value, None) {
        Some(decoded) => Some(pdf_normalize_pdf_text(decoded))
        None => None
      }
    Some(PdfNativeDictValue::Name(value)) => Some(value)
    Some(PdfNativeDictValue::Word(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_raw_string_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::LiteralString(value)) =>
      Some(pdf_decode_literal_pdf_text(value.decoded))
    Some(PdfNativeDictValue::HexString(value)) =>
      pdf_decode_hex_pdf_text(value, None)
    Some(PdfNativeDictValue::Name(value)) => Some(value)
    Some(PdfNativeDictValue::Word(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_string_array_after(text : String, key : String) -> Array[String] {
  let values : Array[String] = []
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Array(tokens)) =>
      pdf_collect_string_array_values(tokens, values)
    Some(value) =>
      match pdf_dict_value_text(value) {
        Some(text) if text.trim() != "" => values.push(text.trim().to_owned())
        _ => ()
      }
    None => ()
  }
  values
}

///|
fn pdf_dict_value_text(value : PdfNativeDictValue) -> String? {
  match value {
    PdfNativeDictValue::LiteralString(token) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(token.decoded)))
    PdfNativeDictValue::HexString(hex) => pdf_decode_hex_pdf_text(hex, None)
    PdfNativeDictValue::Name(name) => Some(name)
    PdfNativeDictValue::Word(word) => Some(word)
    PdfNativeDictValue::Number(number) => Some(number.to_string())
    _ => None
  }
}

///|
fn pdf_token_text(token : PdfNativeContentToken) -> String? {
  match token {
    PdfNativeContentToken::LiteralString(value) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(value.decoded)))
    PdfNativeContentToken::HexString(hex) => pdf_decode_hex_pdf_text(hex, None)
    PdfNativeContentToken::Name(name) => Some(name)
    PdfNativeContentToken::Word(word) => Some(word)
    PdfNativeContentToken::Number(number) => Some(number.to_string())
    _ => None
  }
}

///|
fn pdf_collect_string_array_values(
  tokens : Array[PdfNativeContentToken],
  values : Array[String],
) -> Unit {
  for token in tokens {
    match token {
      PdfNativeContentToken::Array(items) => {
        let pair_text = pdf_token_array_preferred_text(items)
        if pair_text != "" {
          values.push(pair_text)
        } else {
          pdf_collect_string_array_values(items, values)
        }
      }
      _ =>
        match pdf_token_text(token) {
          Some(value) if value.trim() != "" =>
            values.push(value.trim().to_owned())
          _ => ()
        }
    }
  }
}

///|
fn pdf_token_array_preferred_text(
  items : Array[PdfNativeContentToken],
) -> String {
  if items.length() == 0 {
    return ""
  }
  match pdf_token_text(items[0]) {
    Some(value) if value.trim() != "" => value.trim().to_owned()
    _ => ""
  }
}

///|
fn pdf_decode_literal_pdf_text(value : String) -> String {
  match pdf_decode_utf16_literal_string(value) {
    Some(decoded) => decoded
    None => pdf_decode_pdfdoc_byte_string(value)
  }
}

///|
fn pdf_decode_content_literal_pdf_text(
  value : String,
  font_info : PdfNativeFontInfo?,
) -> String {
  match pdf_decode_utf16_literal_string(value) {
    Some(decoded) => decoded
    None => {
      let bytes = pdf_string_byte_values(value)
      match font_info {
        Some(info) if pdf_font_uses_code_unit_decode(info) =>
          match pdf_decode_literal_bytes_with_font(bytes, info) {
            Some(decoded) => decoded
            None => pdf_decode_pdfdoc_bytes(bytes)
          }
        Some(info) if pdf_font_is_winansi(info) =>
          pdf_decode_winansi_bytes(bytes)
        _ => pdf_decode_pdfdoc_bytes(bytes)
      }
    }
  }
}

///|
fn pdf_decode_utf16_literal_string(value : String) -> String? {
  let chars = value.to_array()
  if chars.length() < 2 {
    return None
  }
  if chars[0] == '\u{00FE}' && chars[1] == '\u{00FF}' {
    let hex_parts : Array[String] = ["FEFF"]
    let mut index = 2
    while index < chars.length() {
      hex_parts.push(pdf_hex_upper(chars[index].to_int(), 2))
      index += 1
    }
    return pdf_hex_to_string(hex_parts.join(""))
  }
  if chars[0] == '\u{00FF}' && chars[1] == '\u{00FE}' {
    let bytes : Array[Byte] = []
    let mut index = 2
    while index < chars.length() {
      bytes.push(chars[index].to_int().to_byte())
      index += 1
    }
    let decoded = @encoding.decode(
      Bytes::from_array(bytes),
      encoding=@encoding.UTF16LE,
    ) catch {
      _ => return None
    }
    return Some(pdf_strip_utf16_bom(decoded))
  }
  None
}

///|
fn pdf_decode_literal_bytes_with_font(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> String? {
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 {
    return None
  }
  let parts : Array[String] = []
  let mut index = 0
  while index < bytes.length() {
    let mut matched = false
    for width in widths {
      if width <= 0 || index + width > bytes.length() {
        continue
      }
      let key = pdf_hex_from_bytes(bytes, index, width)
      match info.unicode_map.get(key) {
        Some(value) => {
          if pdf_is_usable_tounicode_text(value) {
            parts.push(value)
          }
          index += width
          matched = true
          break
        }
        None => ()
      }
    }
    if !matched {
      let width = if pdf_font_has_multibyte_widths(widths) {
        widths[widths.length() - 1]
      } else {
        1
      }
      if width <= 0 || index + width > bytes.length() {
        break
      }
      let key = pdf_hex_from_bytes(bytes, index, width)
      match pdf_decode_font_code_fallback(key, info) {
        Some(value) => parts.push(value)
        None => ()
      }
      index += width
    }
  }
  let joined = parts.join("")
  if joined != "" {
    return Some(joined)
  }
  if pdf_font_is_winansi(info) {
    let decoded = pdf_decode_winansi_bytes(bytes)
    if decoded != "" {
      return Some(decoded)
    }
  }
  None
}

///|
fn pdf_string_byte_values(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  for ch in text.to_array() {
    bytes.push(ch.to_int() & 0xFF)
  }
  bytes
}

///|
fn pdf_hex_from_bytes(bytes : Array[Int], start : Int, width : Int) -> String {
  let parts : Array[String] = []
  let mut index = start
  while index < start + width && index < bytes.length() {
    parts.push(pdf_hex_upper(bytes[index] & 0xFF, 2))
    index += 1
  }
  parts.join("")
}

///|
fn pdf_decode_pdfdoc_byte_string(value : String) -> String {
  pdf_decode_pdfdoc_bytes(pdf_string_byte_values(value))
}

///|
fn pdf_decode_pdfdoc_bytes(bytes : Array[Int]) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(pdf_pdfdoc_byte_char(byte & 0xFF))
  }
  String::from_array(chars)
}

///|
fn pdf_decode_winansi_bytes(bytes : Array[Int]) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(pdf_winansi_byte_char(byte & 0xFF))
  }
  String::from_array(chars)
}

///|
fn pdf_pdfdoc_byte_char(byte : Int) -> Char {
  match byte {
    0x18 => '\u{02D8}'
    0x19 => '\u{02C7}'
    0x1A => '\u{02C6}'
    0x1B => '\u{02D9}'
    0x1C => '\u{02DD}'
    0x1D => '\u{02DB}'
    0x1E => '\u{02DA}'
    0x1F => '\u{02DC}'
    0x80 => '\u{2022}'
    0x81 => '\u{2020}'
    0x82 => '\u{2021}'
    0x83 => '\u{2026}'
    0x84 => '\u{2014}'
    0x85 => '\u{2013}'
    0x86 => '\u{0192}'
    0x87 => '\u{2044}'
    0x88 => '\u{2039}'
    0x89 => '\u{203A}'
    0x8A => '\u{2212}'
    0x8B => '\u{2030}'
    0x8C => '\u{201E}'
    0x8D => '\u{201C}'
    0x8E => '\u{201D}'
    0x8F => '\u{2018}'
    0x90 => '\u{2019}'
    0x91 => '\u{201A}'
    0x92 => '\u{2122}'
    0x93 => '\u{FB01}'
    0x94 => '\u{FB02}'
    0x95 => '\u{0141}'
    0x96 => '\u{0152}'
    0x97 => '\u{0160}'
    0x98 => '\u{0178}'
    0x99 => '\u{017D}'
    0x9A => '\u{0131}'
    0x9B => '\u{0142}'
    0x9C => '\u{0153}'
    0x9D => '\u{0161}'
    0x9E => '\u{017E}'
    0xA0 => '\u{20AC}'
    _ => Int::unsafe_to_char(byte)
  }
}

///|
fn pdf_winansi_byte_char(byte : Int) -> Char {
  match byte {
    0x80 => '\u{20AC}'
    0x82 => '\u{201A}'
    0x83 => '\u{0192}'
    0x84 => '\u{201E}'
    0x85 => '\u{2026}'
    0x86 => '\u{2020}'
    0x87 => '\u{2021}'
    0x88 => '\u{02C6}'
    0x89 => '\u{2030}'
    0x8A => '\u{0160}'
    0x8B => '\u{2039}'
    0x8C => '\u{0152}'
    0x8E => '\u{017D}'
    0x91 => '\u{2018}'
    0x92 => '\u{2019}'
    0x93 => '\u{201C}'
    0x94 => '\u{201D}'
    0x95 => '\u{2022}'
    0x96 => '\u{2013}'
    0x97 => '\u{2014}'
    0x98 => '\u{02DC}'
    0x99 => '\u{2122}'
    0x9A => '\u{0161}'
    0x9B => '\u{203A}'
    0x9C => '\u{0153}'
    0x9E => '\u{017E}'
    0x9F => '\u{0178}'
    _ => Int::unsafe_to_char(byte)
  }
}

///|
fn pdf_annotation_from_object(
  source : @input.InputSource,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  annotation_index : Int,
  object_id : Int,
  page_numbers : Map[Int, Int],
) -> PdfNativeAnnotation? {
  let subtype = match pdf_extract_name_after(object.dict_text, "/Subtype") {
    Some(value) => value
    None => return None
  }
  let flags = pdf_extract_int_after(object.dict_text, "/F")
  if !pdf_annotation_should_surface(subtype, flags) {
    return None
  }
  let bbox = pdf_extract_rect_after(object.dict_text, "/Rect")
  let source_ref = match bbox {
    Some(value) =>
      Some(pdf_native_source_ref(source, page_index, value, None, None, 0.0))
    None => None
  }
  let action = pdf_annotation_action_summary(
    object.dict_text,
    object_index,
    page_index,
    source_ref,
    page_numbers,
  )
  let destination = match
    pdf_destination_from_key(
      object.dict_text,
      "/Dest",
      object_index,
      page_index,
      source_ref,
      page_numbers,
    ) {
    Some(value) => Some(value)
    None => action.2
  }
  let target = match action.1 {
    Some(value) => Some(value)
    None =>
      match destination {
        Some(dest) => pdf_destination_target_text(dest)
        None => None
      }
  }
  let text = pdf_annotation_text(object.dict_text)
  Some(
    make_pdf_native_annotation(
      page_index,
      subtype,
      bbox~,
      text~,
      title=pdf_extract_string_after(object.dict_text, "/T"),
      name=pdf_extract_string_after(object.dict_text, "/NM"),
      modified_at=pdf_extract_string_after(object.dict_text, "/M"),
      action_kind=action.0,
      target~,
      destination~,
      source_ref~,
      annotation_index=Some(annotation_index),
      object_id=Some(object_id),
    ),
  )
}

///|
fn pdf_annotation_text(dict_text : String) -> String? {
  for key in ["/Contents", "/TU", "/T", "/V"] {
    match pdf_extract_string_after(dict_text, key) {
      Some(value) if value.trim() != "" =>
        return Some(pdf_annotation_normalized_text(value))
      _ => ()
    }
  }
  None
}

///|
fn pdf_annotation_normalized_text(value : String) -> String {
  value
  .split("\n")
  .to_array()
  .map(line => line.trim().to_owned())
  .filter(line => line != "")
  .join(" / ")
}

///|
fn pdf_annotation_should_surface(subtype : String, flags : Int?) -> Bool {
  if subtype == "Widget" {
    return true
  }
  let value = flags.unwrap_or(0)
  let hidden = pdf_annotation_flag_is_set(value, 1)
  let print = pdf_annotation_flag_is_set(value, 2)
  let no_view = pdf_annotation_flag_is_set(value, 5)
  if no_view && !print {
    return false
  }
  if hidden && !print {
    return false
  }
  true
}

///|
fn pdf_annotation_flag_is_set(flags : Int, bit_index : Int) -> Bool {
  (flags & (1 << bit_index)) != 0
}

///|
fn pdf_annotation_file_name(
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  let file_spec = match
    pdf_inline_or_referenced_dict_text(dict_text, "/FS", object_index) {
    Some(value) => value
    None => return None
  }
  for key in ["/UF", "/F", "/Desc"] {
    match pdf_extract_string_after(file_spec, key) {
      Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
      _ => ()
    }
  }
  None
}

///|
fn pdf_native_backend_annotation_json(
  annotation : PdfNativeAnnotation,
  object_index : Map[Int, PdfNativeObject],
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("subtype", @core.JsonValue::String(annotation.subtype))
  payload.set(
    "page",
    @core.JsonValue::Number(annotation.page_index.to_string()),
  )
  match annotation.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_backend_bbox_json_value(bbox))
    None => ()
  }
  match annotation.text {
    Some(value) => payload.set("text", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.title {
    Some(value) => payload.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.modified_at {
    Some(value) => payload.set("modified_at", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.action_kind {
    Some(value) => payload.set("action_kind", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.target {
    Some(value) => payload.set("target", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.annotation_index {
    Some(value) =>
      payload.set(
        "annotation_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match annotation.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match annotation.destination {
    Some(value) =>
      payload.set("destination", pdf_native_backend_destination_json(value))
    None => ()
  }
  match annotation.object_id {
    Some(object_id) =>
      match object_index.get(object_id) {
        Some(object) => {
          match pdf_extract_int_after(object.dict_text, "/F") {
            Some(value) => {
              payload.set("flags", @core.JsonValue::Number(value.to_string()))
              payload.set(
                "flag_hidden",
                @core.JsonValue::Bool((value & (1 << 1)) != 0),
              )
              payload.set(
                "flag_print",
                @core.JsonValue::Bool((value & (1 << 2)) != 0),
              )
              payload.set(
                "flag_no_view",
                @core.JsonValue::Bool((value & (1 << 5)) != 0),
              )
            }
            None => ()
          }
          match pdf_annotation_file_name(object.dict_text, object_index) {
            Some(value) =>
              payload.set("file_name", @core.JsonValue::String(value))
            None => ()
          }
          match pdf_extract_string_after(object.dict_text, "/Subj") {
            Some(value) if value.trim() != "" =>
              payload.set("subject", @core.JsonValue::String(value))
            _ => ()
          }
        }
        None => ()
      }
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_backend_destination_json(
  destination : PdfNativeDestination,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match destination.page_index {
    Some(value) =>
      payload.set("page_index", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match destination.target_page_index {
    Some(value) =>
      payload.set(
        "target_page_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.target_page_object_id {
    Some(value) =>
      payload.set(
        "target_page_object_id",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.kind {
    Some(value) => payload.set("kind", @core.JsonValue::String(value))
    None => ()
  }
  match destination.raw_value {
    Some(value) => payload.set("raw_value", @core.JsonValue::String(value))
    None => ()
  }
  match destination.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match destination.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_backend_bbox_json_value(bbox : PdfBBox) -> @core.JsonValue {
  @core.JsonValue::Object(
    Map([
      ("x", @core.JsonValue::String(bbox.x.to_string())),
      ("y", @core.JsonValue::String(bbox.y.to_string())),
      ("width", @core.JsonValue::String(bbox.width.to_string())),
      ("height", @core.JsonValue::String(bbox.height.to_string())),
    ]),
  )
}

///|
fn pdf_annotation_action_summary(
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> (String?, String?, PdfNativeDestination?) {
  let action_text = match
    pdf_inline_or_referenced_dict_text(dict_text, "/A", object_index) {
    Some(value) => value
    None => return (None, None, None)
  }
  let action_kind = pdf_extract_name_after(action_text, "/S")
  match action_kind {
    Some("URI") =>
      (Some("URI"), pdf_extract_string_after(action_text, "/URI"), None)
    Some("GoTo") => {
      let destination = pdf_destination_from_key(
        action_text, "/D", object_index, page_index, source_ref, page_numbers,
      )
      (
        Some("GoTo"),
        match destination {
          Some(dest) => pdf_destination_target_text(dest)
          None => None
        },
        destination,
      )
    }
    Some(kind) => (Some(kind), None, None)
    None => (None, None, None)
  }
}

///|
fn pdf_destination_from_key(
  dict_text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  match pdf_extract_dict_value(dict_text, key) {
    Some(value) =>
      pdf_destination_from_value(
        value, object_index, page_index, source_ref, page_numbers,
      )
    None => None
  }
}

///|
fn pdf_destination_from_value(
  value : PdfNativeDictValue,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  match value {
    PdfNativeDictValue::Reference(object_id, generation) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) =>
          match pdf_extract_dict_value(object.dict_text, "/D") {
            Some(inner) =>
              pdf_destination_from_value(
                inner, object_index, page_index, source_ref, page_numbers,
              )
            None =>
              Some(
                make_pdf_native_destination(
                  page_index=Some(page_index),
                  raw_value=Some(object.dict_text),
                  source_ref~,
                  object_id=Some(object_id),
                ),
              )
          }
        None => None
      }
    }
    PdfNativeDictValue::Array(tokens) =>
      pdf_destination_from_tokens(tokens, page_index, source_ref, page_numbers)
    PdfNativeDictValue::Name(name) =>
      Some(
        make_pdf_native_destination(
          page_index=Some(page_index),
          raw_value=Some("/" + name),
          name=Some(name),
          source_ref~,
        ),
      )
    PdfNativeDictValue::LiteralString(text) =>
      Some(
        make_pdf_native_destination(
          page_index=Some(page_index),
          raw_value=Some(pdf_normalize_pdf_text(text.decoded)),
          name=Some(pdf_normalize_pdf_text(text.decoded)),
          source_ref~,
        ),
      )
    PdfNativeDictValue::HexString(hex) =>
      match pdf_decode_hex_pdf_text(hex, None) {
        Some(decoded) =>
          Some(
            make_pdf_native_destination(
              page_index=Some(page_index),
              raw_value=Some(decoded),
              name=Some(decoded),
              source_ref~,
            ),
          )
        None => None
      }
    PdfNativeDictValue::Dict(dict_text) =>
      match pdf_extract_dict_value(dict_text, "/D") {
        Some(inner) =>
          pdf_destination_from_value(
            inner, object_index, page_index, source_ref, page_numbers,
          )
        None =>
          Some(
            make_pdf_native_destination(
              page_index=Some(page_index),
              raw_value=Some(dict_text),
              source_ref~,
            ),
          )
      }
    _ => None
  }
}

///|
fn pdf_destination_from_tokens(
  tokens : Array[PdfNativeContentToken],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  let target_page_object_id = pdf_collect_reference_ids_from_tokens(tokens).get(
    0,
  )
  let target_page_index = match target_page_object_id {
    Some(object_id) => page_numbers.get(object_id)
    None => None
  }
  let kind = if tokens.length() >= 4 { pdf_token_name(tokens[3]) } else { None }
  let raw_value = pdf_destination_tokens_text(tokens)
  Some(
    make_pdf_native_destination(
      page_index=Some(page_index),
      target_page_index~,
      target_page_object_id~,
      kind~,
      raw_value=Some(raw_value),
      source_ref~,
      object_id=target_page_object_id,
    ),
  )
}

///|
fn pdf_destination_tokens_text(tokens : Array[PdfNativeContentToken]) -> String {
  let parts : Array[String] = []
  for token in tokens {
    match token {
      PdfNativeContentToken::Name(value) => parts.push("/" + value)
      PdfNativeContentToken::Word(value) => parts.push(value)
      PdfNativeContentToken::Number(value) => parts.push(value.to_string())
      PdfNativeContentToken::LiteralString(value) =>
        parts.push(pdf_normalize_pdf_text(value.decoded))
      PdfNativeContentToken::HexString(value) =>
        match pdf_decode_hex_pdf_text(value, None) {
          Some(decoded) => parts.push(decoded)
          None => parts.push(value)
        }
      _ => ()
    }
  }
  parts.join(" ")
}

///|
fn pdf_destination_target_text(destination : PdfNativeDestination) -> String? {
  match destination.target_page_index {
    Some(page) => Some("page " + page.to_string())
    None =>
      match destination.name {
        Some(value) if value.trim() != "" =>
          Some(
            "named destination \"" +
            pdf_destination_display_name(value.trim().to_owned()) +
            "\"",
          )
        _ =>
          if pdf_destination_has_visible_hint(destination) {
            Some("unresolved destination")
          } else {
            None
          }
      }
  }
}

///|
fn pdf_destination_display_name(name : String) -> String {
  name.replace(old="\"", new="\\\"")
}

///|
fn pdf_destination_has_visible_hint(destination : PdfNativeDestination) -> Bool {
  match destination.raw_value {
    Some(value) if value.trim() != "" => true
    _ =>
      match destination.kind {
        Some(value) if value.trim() != "" => true
        _ =>
          destination.target_page_object_id is Some(_) ||
          destination.object_id is Some(_)
      }
  }
}

///|
fn pdf_inline_or_referenced_dict_text(
  dict_text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  match pdf_extract_dict_value(dict_text, key) {
    Some(PdfNativeDictValue::Dict(value)) => Some(value)
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) => Some(object.dict_text)
        None => None
      }
    }
    _ => None
  }
}

///|
fn pdf_extract_form_fields(
  source : @input.InputSource,
  view : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
  annotation_pages : Map[Int, Int],
) -> Array[PdfNativeFormField] {
  let catalog = match pdf_catalog_object(view, object_index) {
    Some(value) => value
    None => return []
  }
  let acroform = match
    pdf_inline_or_referenced_dict_text(
      catalog.dict_text,
      "/AcroForm",
      object_index,
    ) {
    Some(value) => value
    None => return []
  }
  let refs = pdf_extract_object_references_after(acroform, "/Fields")
  let out : Array[PdfNativeFormField] = []
  let visited : Map[Int, Bool] = Map([])
  let seen : Map[String, Bool] = Map([])
  for ref_id in refs {
    match object_index.get(ref_id) {
      Some(object) =>
        out.append(
          pdf_form_fields_from_object(
            source,
            object,
            object_index,
            ref_id,
            None,
            None,
            None,
            None,
            None,
            [],
            None,
            page_numbers,
            annotation_pages,
            None,
            visited,
            seen,
            0,
          )[:],
        )
      None => ()
    }
  }
  out
}

///|
fn pdf_form_fields_from_object(
  source : @input.InputSource,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  object_id : Int,
  inherited_type : String?,
  inherited_name : String?,
  inherited_alt_name : String?,
  inherited_value : String?,
  inherited_default_value : String?,
  inherited_options : Array[String],
  inherited_flags : Int?,
  page_numbers : Map[Int, Int],
  annotation_pages : Map[Int, Int],
  inherited_page_index : Int?,
  visited : Map[Int, Bool],
  seen : Map[String, Bool],
  depth : Int,
) -> Array[PdfNativeFormField] {
  if depth >= 32 || visited.get(object_id).unwrap_or(false) {
    return []
  }
  visited.set(object_id, true)
  let field_type = match pdf_extract_name_after(object.dict_text, "/FT") {
    Some(value) => Some(value)
    None => inherited_type
  }
  let field_name = pdf_form_field_inherit_text(
    pdf_extract_string_after(object.dict_text, "/T"),
    inherited_name,
  )
  let alt_name = pdf_form_field_inherit_text(
    pdf_extract_string_after(object.dict_text, "/TU"),
    inherited_alt_name,
  )
  let field_value = match pdf_extract_form_value(object.dict_text, field_type) {
    Some(value) => Some(value)
    None => inherited_value
  }
  let default_value = match pdf_extract_form_default_value(object.dict_text) {
    Some(value) => Some(value)
    None => inherited_default_value
  }
  let direct_options = pdf_extract_form_options(object.dict_text)
  let options = if direct_options.length() > 0 {
    direct_options
  } else {
    inherited_options
  }
  let flags = match pdf_extract_int_after(object.dict_text, "/Ff") {
    Some(value) => Some(value)
    None => inherited_flags
  }
  let kids = pdf_extract_object_references_after(object.dict_text, "/Kids")
  let page_index = match
    pdf_page_index_from_object(object.dict_text, page_numbers) {
    Some(value) => Some(value)
    None =>
      match annotation_pages.get(object_id) {
        Some(value) => Some(value)
        None => inherited_page_index
      }
  }
  let bbox = pdf_extract_rect_after(object.dict_text, "/Rect")
  let is_widget = match pdf_extract_name_after(object.dict_text, "/Subtype") {
    Some("Widget") => true
    _ => bbox is Some(_) || annotation_pages.contains(object_id)
  }
  let source_ref = match (page_index, bbox) {
    (Some(page), Some(rect)) =>
      Some(pdf_native_source_ref(source, page, rect, None, None, 0.0))
    _ => None
  }
  let widget_object_id = if is_widget { Some(object_id) } else { None }
  let should_emit = if is_widget {
    true
  } else if kids.length() == 0 {
    pdf_form_field_has_visible_facts(
      field_type, field_name, alt_name, field_value, default_value, options,
    )
  } else {
    false
  }
  let dedup_key = match widget_object_id {
    Some(value) => "widget:" + value.to_string()
    None => "field:" + object_id.to_string()
  }
  let field = if should_emit && !seen.get(dedup_key).unwrap_or(false) {
    seen.set(dedup_key, true)
    [
      make_pdf_native_form_field(
        page_index~,
        field_type~,
        field_name~,
        alternate_name=alt_name,
        value=field_value,
        default_value~,
        options~,
        bbox~,
        source_ref~,
        object_id=Some(object_id),
        widget_object_id~,
        flags~,
      ),
    ]
  } else {
    []
  }
  let out : Array[PdfNativeFormField] = []
  out.append(field[:])
  for kid_id in kids {
    match object_index.get(kid_id) {
      Some(kid) =>
        out.append(
          pdf_form_fields_from_object(
            source,
            kid,
            object_index,
            kid_id,
            field_type,
            field_name,
            alt_name,
            field_value,
            default_value,
            options,
            flags,
            page_numbers,
            annotation_pages,
            page_index,
            visited,
            seen,
            depth + 1,
          )[:],
        )
      None => ()
    }
  }
  out
}

///|
fn pdf_form_field_inherit_text(value : String?, inherited : String?) -> String? {
  match value {
    Some(text) if text.trim() != "" => Some(text)
    _ => inherited
  }
}

///|
fn pdf_form_field_has_visible_facts(
  field_type : String?,
  field_name : String?,
  alt_name : String?,
  value : String?,
  default_value : String?,
  options : Array[String],
) -> Bool {
  if field_type is Some(_) {
    true
  } else {
    match field_name {
      Some(text) if text.trim() != "" => true
      _ =>
        match alt_name {
          Some(text) if text.trim() != "" => true
          _ =>
            match value {
              Some(text) if text.trim() != "" => true
              _ =>
                match default_value {
                  Some(text) if text.trim() != "" => true
                  _ => options.length() > 0
                }
            }
        }
    }
  }
}

///|
fn pdf_extract_form_value(dict_text : String, field_type : String?) -> String? {
  match field_type {
    Some("Btn") =>
      match pdf_extract_string_after(dict_text, "/V") {
        Some("Off") => Some("false")
        Some(_) => Some("true")
        None =>
          match pdf_extract_name_after(dict_text, "/AS") {
            Some("Off") => Some("false")
            Some(_) => Some("true")
            None => Some("false")
          }
      }
    Some("Ch") =>
      match pdf_extract_string_array_after(dict_text, "/V") {
        [] => None
        [value] => Some(pdf_annotation_normalized_text(value))
        values =>
          Some(
            values
            .map(value => pdf_annotation_normalized_text(value))
            .join(", "),
          )
      }
    _ =>
      match pdf_extract_raw_string_after(dict_text, "/V") {
        Some(value) => Some(pdf_form_normalized_value_text(value))
        None => None
      }
  }
}

///|
fn pdf_extract_form_default_value(dict_text : String) -> String? {
  match pdf_extract_string_array_after(dict_text, "/DV") {
    [] =>
      match pdf_extract_raw_string_after(dict_text, "/DV") {
        Some(value) => Some(pdf_form_normalized_value_text(value))
        None => None
      }
    [value] => Some(pdf_form_normalized_value_text(value))
    values =>
      Some(
        values.map(value => pdf_form_normalized_value_text(value)).join(", "),
      )
  }
}

///|
fn pdf_extract_form_options(dict_text : String) -> Array[String] {
  let raw = pdf_extract_string_array_after(dict_text, "/Opt")
  let deduped : Array[String] = []
  for value in raw {
    let normalized = pdf_form_normalized_value_text(value)
    if normalized != "" && !deduped.contains(normalized) {
      deduped.push(normalized)
    }
  }
  deduped
}

///|
fn pdf_form_normalized_value_text(value : String) -> String {
  let segments : Array[String] = []
  let current : Array[Char] = []
  let chars = value.to_array()
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch == '\r' || ch == '\n' {
      let segment = pdf_normalize_pdf_text(String::from_array(current))
      if segment != "" {
        segments.push(segment)
      }
      current.clear()
      if ch == '\r' && index + 1 < chars.length() && chars[index + 1] == '\n' {
        index += 1
      }
    } else {
      current.push(ch)
    }
    index += 1
  }
  let tail = pdf_normalize_pdf_text(String::from_array(current))
  if tail != "" {
    segments.push(tail)
  }
  segments.join(" / ")
}

///|
fn pdf_page_index_from_object(
  dict_text : String,
  page_numbers : Map[Int, Int],
) -> Int? {
  match pdf_extract_object_reference_after(dict_text, "/P") {
    Some(object_id) => page_numbers.get(object_id)
    None => None
  }
}

///|
fn pdf_extract_outline_items(
  source : @input.InputSource,
  view : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeOutlineItem] {
  let catalog = match pdf_catalog_object(view, object_index) {
    Some(value) => value
    None => return []
  }
  let outlines_ref = match
    pdf_extract_object_reference_after(catalog.dict_text, "/Outlines") {
    Some(value) => value
    None => return []
  }
  let outlines_object = match object_index.get(outlines_ref) {
    Some(value) => value
    None => return []
  }
  let first_ref = match
    pdf_extract_object_reference_after(outlines_object.dict_text, "/First") {
    Some(value) => value
    None => return []
  }
  pdf_walk_outline_siblings(
    source, object_index, first_ref, 0, 0, page_numbers, 128,
  )
}

///|
fn pdf_walk_outline_siblings(
  source : @input.InputSource,
  object_index : Map[Int, PdfNativeObject],
  start_ref : Int,
  level : Int,
  order_offset : Int,
  page_numbers : Map[Int, Int],
  remaining : Int,
) -> Array[PdfNativeOutlineItem] {
  if remaining <= 0 {
    return []
  }
  let out : Array[PdfNativeOutlineItem] = []
  let visited : Map[Int, Bool] = Map([])
  let mut current = Some(start_ref)
  let mut order_index = order_offset
  let mut budget = remaining
  while current is Some(_) && budget > 0 {
    let current_ref = current.unwrap_or(0)
    if visited.get(current_ref).unwrap_or(false) {
      break
    }
    visited.set(current_ref, true)
    budget -= 1
    match object_index.get(current_ref) {
      Some(object) => {
        let title = pdf_extract_string_after(object.dict_text, "/Title").unwrap_or(
          "(untitled)",
        )
        let source_ref = match
          pdf_extract_rect_after(object.dict_text, "/Rect") {
          Some(rect) =>
            match pdf_page_index_from_object(object.dict_text, page_numbers) {
              Some(page) =>
                Some(pdf_native_source_ref(source, page, rect, None, None, 0.0))
              None => None
            }
          None => None
        }
        let action = pdf_annotation_action_summary(
          object.dict_text,
          object_index,
          0,
          source_ref,
          page_numbers,
        )
        let destination = match
          pdf_destination_from_key(
            object.dict_text,
            "/Dest",
            object_index,
            0,
            source_ref,
            page_numbers,
          ) {
          Some(value) => Some(value)
          None => action.2
        }
        let target = match action.1 {
          Some(value) => Some(value)
          None =>
            match destination {
              Some(dest) => pdf_destination_target_text(dest)
              None => None
            }
        }
        let page_index = match destination {
          Some(dest) => dest.target_page_index
          None => None
        }
        out.push(
          make_pdf_native_outline_item(
            title,
            level,
            order_index,
            page_index~,
            action_kind=action.0,
            target~,
            destination~,
            source_ref~,
            object_id=Some(current_ref),
          ),
        )
        order_index += 1
        match pdf_extract_object_reference_after(object.dict_text, "/First") {
          Some(child_ref) => {
            let child_items = pdf_walk_outline_siblings(
              source,
              object_index,
              child_ref,
              level + 1,
              order_index,
              page_numbers,
              budget,
            )
            out.append(child_items[:])
            order_index += child_items.length()
          }
          None => ()
        }
        current = pdf_extract_object_reference_after(object.dict_text, "/Next")
      }
      None => break
    }
  }
  out
}

///|
fn pdf_extract_named_destinations(
  source : @input.InputSource,
  view : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeDestination] {
  let catalog = match pdf_catalog_object(view, object_index) {
    Some(value) => value
    None => return []
  }
  let out : Array[PdfNativeDestination] = []
  match
    pdf_inline_or_referenced_dict_text(
      catalog.dict_text,
      "/Names",
      object_index,
    ) {
    Some(names_dict) =>
      out.append(
        pdf_extract_named_destinations_from_names_dict(
          source, names_dict, object_index, page_numbers,
        )[:],
      )
    None => ()
  }
  match
    pdf_inline_or_referenced_dict_text(
      catalog.dict_text,
      "/Dests",
      object_index,
    ) {
    Some(dests_dict) =>
      out.append(
        pdf_extract_named_destinations_from_flat_dict(
          source, dests_dict, object_index, page_numbers,
        )[:],
      )
    None => ()
  }
  out
}

///|
fn pdf_extract_named_destinations_from_names_dict(
  source : @input.InputSource,
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeDestination] {
  let out : Array[PdfNativeDestination] = []
  let dests_dict = match
    pdf_inline_or_referenced_dict_text(dict_text, "/Dests", object_index) {
    Some(value) => value
    None => return out
  }
  match pdf_extract_dict_value(dests_dict, "/Names") {
    Some(PdfNativeDictValue::Array(tokens)) => {
      let mut index = 0
      while index + 1 < tokens.length() {
        let name = match pdf_token_text(tokens[index]) {
          Some(value) => value
          None => {
            index += 2
            continue
          }
        }
        let destination = match
          pdf_destination_from_content_token(
            tokens[index + 1],
            object_index,
            source,
            page_numbers,
          ) {
          Some(value) => value
          None => {
            index += 2
            continue
          }
        }
        out.push(
          make_pdf_native_destination(
            page_index=destination.page_index,
            target_page_index=destination.target_page_index,
            target_page_object_id=destination.target_page_object_id,
            kind=destination.kind,
            raw_value=destination.raw_value,
            name=Some(name),
            source_ref=destination.source_ref,
            object_id=destination.object_id,
          ),
        )
        index += 2
      }
    }
    _ => ()
  }
  out
}

///|
fn pdf_extract_named_destinations_from_flat_dict(
  source : @input.InputSource,
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeDestination] {
  let entries = match pdf_parse_dict_entries(dict_text) {
    Some(value) => value
    None => return []
  }
  let out : Array[PdfNativeDestination] = []
  for entry in entries {
    let name = if entry.0.has_prefix("/") {
      entry.0[1:].to_owned()
    } else {
      entry.0
    }
    match
      pdf_destination_from_value(entry.1, object_index, 0, None, page_numbers) {
      Some(destination) =>
        out.push(
          make_pdf_native_destination(
            page_index=destination.page_index,
            target_page_index=destination.target_page_index,
            target_page_object_id=destination.target_page_object_id,
            kind=destination.kind,
            raw_value=destination.raw_value,
            name=Some(name),
            source_ref=destination.source_ref,
            object_id=destination.object_id,
          ),
        )
      None => ()
    }
  }
  ignore(source)
  out
}

///|
fn pdf_destination_from_content_token(
  token : PdfNativeContentToken,
  object_index : Map[Int, PdfNativeObject],
  source : @input.InputSource,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  ignore(source)
  match token {
    PdfNativeContentToken::Array(tokens) =>
      pdf_destination_from_tokens(tokens, 0, None, page_numbers)
    PdfNativeContentToken::Dict(dict_text) =>
      match pdf_extract_dict_value(dict_text, "/D") {
        Some(value) =>
          pdf_destination_from_value(value, object_index, 0, None, page_numbers)
        None => None
      }
    PdfNativeContentToken::Name(name) =>
      Some(
        make_pdf_native_destination(name=Some(name), raw_value=Some("/" + name)),
      )
    PdfNativeContentToken::LiteralString(value) =>
      Some(
        make_pdf_native_destination(
          name=Some(pdf_normalize_pdf_text(value.decoded)),
          raw_value=Some(pdf_normalize_pdf_text(value.decoded)),
        ),
      )
    PdfNativeContentToken::HexString(hex) =>
      match pdf_decode_hex_pdf_text(hex, None) {
        Some(decoded) =>
          Some(
            make_pdf_native_destination(
              name=Some(decoded),
              raw_value=Some(decoded),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn pdf_slice_after_key(text : String, key : String) -> String? {
  match pdf_find_substring(text, key, 0) {
    Some(index) => Some(text[index + key.length():].trim().to_owned())
    None => None
  }
}

///|
fn pdf_native_source_ref(
  source : @input.InputSource,
  page_no : Int,
  bbox : PdfBBox,
  line_index : Int?,
  font_name : String?,
  font_size : Double,
  reading_order_index? : Int? = None,
) -> @core.SourceRef {
  let source_id = pdf_native_source_id(source)
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source_id),
    Some("pdf"),
    line_index,
    line_index,
  )
  let next = {
    ..base,
    page: Some(page_no),
    bbox: Some({
      x0: bbox.x,
      y0: bbox.y,
      x1: pdf_bbox_right(bbox),
      y1: pdf_bbox_bottom(bbox),
    }),
  }
  next.extra.set("pdf_backend", "root_native_minimal")
  next.extra.set("page_no", page_no.to_string())
  if font_size > 0.0 {
    next.extra.set("font_size", font_size.to_string())
  }
  match font_name {
    Some(value) => next.extra.set("font_name", value)
    None => ()
  }
  match reading_order_index {
    Some(value) => next.extra.set("reading_order_index", value.to_string())
    None => ()
  }
  next
}

///|
fn pdf_effective_font_size(
  text_matrix : PdfNativeGraphicsMatrix,
  current_font_size : Double?,
) -> Double {
  let tf = current_font_size.unwrap_or(0.0)
  let scale = pdf_double_max(
    pdf_abs_double(text_matrix.a),
    pdf_abs_double(text_matrix.d),
  )
  if tf <= 0.0 {
    if scale > 0.0 {
      scale
    } else {
      12.0
    }
  } else if scale > 1.5 {
    scale * tf
  } else {
    tf
  }
}

///|
fn pdf_text_matrix_x_scale(matrix : PdfNativeGraphicsMatrix) -> Double {
  let scale = pdf_abs_double(matrix.a)
  if scale > 0.0 {
    scale
  } else {
    1.0
  }
}

///|
fn pdf_text_matrix_y_scale(matrix : PdfNativeGraphicsMatrix) -> Double {
  let scale = pdf_abs_double(matrix.d)
  if scale > 0.0 {
    scale
  } else {
    1.0
  }
}

///|
fn pdf_estimate_text_bbox(
  text : String,
  x : Double,
  baseline_y : Double,
  font_size : Double,
) -> PdfBBox {
  let width = pdf_estimate_text_width(text, font_size)
  let height = if font_size > 0.0 { font_size * 1.2 } else { 12.0 }
  let top = if baseline_y - height * 0.85 > 0.0 {
    baseline_y - height * 0.85
  } else {
    baseline_y
  }
  make_pdf_bbox(x, top, width, height)
}

///|
fn pdf_estimate_text_width(text : String, font_size : Double) -> Double {
  let mut width = 0.0
  for ch in text.to_array() {
    width += if ch == ' ' {
      font_size * 0.35
    } else if pdf_is_ascii_punctuation(ch) {
      font_size * 0.4
    } else if ch.to_int() < 128 {
      font_size * 0.62
    } else {
      font_size
    }
  }
  if width <= 0.0 {
    font_size
  } else {
    width
  }
}

///|
fn pdf_prepare_line_text_fragment(
  text : String,
  gap : Double?,
  font_size : Double?,
  preserve_outer_space? : Bool = false,
) -> String {
  let normalized = if preserve_outer_space {
    pdf_normalize_pdf_fragment_text(text)
  } else {
    pdf_normalize_line_fragment_text(text)
  }
  match gap {
    Some(value) => {
      let size = font_size.unwrap_or(12.0)
      if normalized.has_prefix(" ") {
        normalized
      } else if value > size * 0.45 && !pdf_text_prefers_no_gap(normalized) {
        " " + normalized
      } else {
        normalized
      }
    }
    None => normalized
  }
}

///|
fn pdf_normalize_line_fragment_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  let mut saw_non_space = false
  for ch in text.to_array() {
    let is_space = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    if is_space {
      if saw_non_space && !previous_space {
        chars.push(' ')
      }
      previous_space = true
    } else {
      chars.push(ch)
      previous_space = false
      saw_non_space = true
    }
  }
  if chars.length() > 0 && chars[chars.length() - 1] == ' ' {
    ignore(chars.pop())
  }
  String::from_array(chars)
}

///|
fn pdf_normalize_pdf_fragment_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  let mut saw_non_space = false
  let mut started_with_space = false
  let mut ended_with_space = false
  for ch in text.to_array() {
    if ch == '\u{0000}' {
      continue
    }
    let is_space = pdf_is_pdf_space(ch)
    if is_space {
      if saw_non_space {
        if !previous_space {
          chars.push(' ')
        }
        ended_with_space = true
      } else {
        started_with_space = true
      }
      previous_space = true
    } else {
      match txt_ligature_expansion(ch) {
        Some(value) => {
          chars.append(value.to_array())
          previous_space = false
          saw_non_space = true
          ended_with_space = false
        }
        None => {
          chars.push(ch)
          previous_space = false
          saw_non_space = true
          ended_with_space = false
        }
      }
    }
  }
  if chars.length() == 0 {
    return ""
  }
  let body = String::from_array(chars)
  let prefix = if started_with_space { " " } else { "" }
  let suffix = if ended_with_space { " " } else { "" }
  prefix + body + suffix
}

///|
fn pdf_text_has_outer_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  pdf_is_pdf_space(chars[0]) || pdf_is_pdf_space(chars[chars.length() - 1])
}

///|
fn pdf_text_outer_space_is_latinish(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let mut has_ascii_word_char = false
  for ch in trimmed.to_array() {
    if pdf_is_cjk_char(ch) {
      return false
    }
    if pdf_is_ascii_digit(ch) ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') {
      has_ascii_word_char = true
    }
  }
  has_ascii_word_char
}

///|
fn pdf_is_pdf_space(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{0008}' ||
  ch == '\u{000C}'
}

///|
fn pdf_text_prefers_no_gap(text : String) -> Bool {
  match text.to_array() {
    [first, ..] =>
      pdf_is_cjk_char(first) ||
      pdf_is_ascii_punctuation(first) ||
      pdf_is_cjk_punctuation(first)
    _ => false
  }
}

///|
fn pdf_actual_text_from_operands(
  operands : Array[PdfNativeContentToken],
) -> String? {
  for token in operands {
    match token {
      PdfNativeContentToken::Dict(text) =>
        match pdf_extract_literal_string_after(text, "/ActualText") {
          Some(value) if value.trim() != "" =>
            match pdf_decode_actual_text_literal(value) {
              Some(decoded) if decoded.trim() != "" => return Some(decoded)
              _ => return Some(value)
            }
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_decode_actual_text_literal(value : String) -> String? {
  let chars = value.to_array()
  if chars.length() < 4 || (chars.length() - 2) % 2 != 0 {
    return None
  }
  if chars[0] != '\u{00FE}' || chars[1] != '\u{00FF}' {
    return None
  }
  let hex_parts : Array[String] = ["FEFF"]
  let mut index = 2
  while index < chars.length() {
    hex_parts.push(pdf_hex_upper(chars[index].to_int(), 2))
    index += 1
  }
  pdf_hex_to_string(hex_parts.join(""))
}

///|
fn pdf_matrix_from_operands(
  operands : Array[PdfNativeContentToken],
) -> PdfNativeGraphicsMatrix {
  let base = operands.length() - 6
  {
    a: pdf_token_number(operands[base]).unwrap_or(1.0),
    d: pdf_token_number(operands[base + 3]).unwrap_or(1.0),
    e: pdf_token_number(operands[base + 4]).unwrap_or(0.0),
    f: pdf_token_number(operands[base + 5]).unwrap_or(0.0),
  }
}

///|
fn pdf_token_number(token : PdfNativeContentToken) -> Double? {
  match token {
    PdfNativeContentToken::Number(value) => Some(value)
    _ => None
  }
}

///|
fn pdf_token_name(token : PdfNativeContentToken) -> String? {
  match token {
    PdfNativeContentToken::Name(value) => Some(value)
    _ => None
  }
}

///|
fn pdf_hex_to_string(hex : String) -> String? {
  if hex == "" {
    return None
  }
  let normalized = hex.trim().to_owned()
  if normalized == "" {
    return None
  }
  if normalized.length() >= 4 && normalized[0:4].to_upper() == "FEFF" {
    match pdf_decode_hex_utf16be(normalized) {
      Some(text) if text != "" => return Some(text)
      _ => ()
    }
  }
  if normalized.length() % 4 == 0 {
    let chars : Array[Char] = []
    let mut index = 0
    while index + 4 <= normalized.length() {
      match pdf_parse_hex_int(normalized[index:index + 4].to_owned()) {
        Some(codepoint) =>
          if pdf_codepoint_is_noncharacter(codepoint) {
            return None
          } else {
            chars.push(Int::unsafe_to_char(codepoint))
          }
        None => ()
      }
      index += 4
    }
    let text = String::from_array(chars)
    if text != "" {
      return Some(text)
    }
  }
  if normalized.length() % 2 == 0 {
    let chars : Array[Char] = []
    let mut index = 0
    while index + 2 <= normalized.length() {
      match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
        Some(codepoint) =>
          if pdf_codepoint_is_noncharacter(codepoint) {
            return None
          } else {
            chars.push(Int::unsafe_to_char(codepoint))
          }
        None => ()
      }
      index += 2
    }
    let text = String::from_array(chars)
    if text != "" {
      return Some(text)
    }
  }
  None
}

///|
fn pdf_first_codepoint_from_hex(hex : String) -> Int? {
  if hex.length() % 4 == 0 && hex.length() >= 4 {
    pdf_parse_hex_int(hex[0:4].to_owned())
  } else if hex.length() % 2 == 0 && hex.length() >= 2 {
    pdf_parse_hex_int(hex[0:2].to_owned())
  } else {
    None
  }
}

///|
fn pdf_hex_upper(value : Int, width : Int) -> String {
  let hex = pdf_int_to_hex(value).to_upper()
  if hex.length() >= width {
    hex
  } else {
    "0".repeat(width - hex.length()) + hex
  }
}

///|
fn pdf_int_to_hex(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let rev_digits : Array[Char] = []
  let mut n = value
  while n > 0 {
    let rem = n % 16
    let ch = if rem < 10 {
      Int::unsafe_to_char('0'.to_int() + rem)
    } else {
      Int::unsafe_to_char('A'.to_int() + rem - 10)
    }
    rev_digits.push(ch)
    n = n / 16
  }
  let digits : Array[Char] = []
  let mut index = rev_digits.length()
  while index > 0 {
    index -= 1
    digits.push(rev_digits[index])
  }
  String::from_array(digits)
}

///|
fn pdf_collect_octal_escape(content : String, start : Int) -> (String, Int) {
  let out : Array[Char] = []
  let mut index = start
  let mut count = 0
  while index < content.length() &&
        count < 3 &&
        pdf_is_octal_digit(pdf_char_at(content, index)) {
    out.push(pdf_char_at(content, index))
    index += 1
    count += 1
  }
  (String::from_array(out), index)
}

///|
fn pdf_parse_octal(value : String) -> Int? {
  let mut out = 0
  for ch in value.to_array() {
    if !pdf_is_octal_digit(ch) {
      return None
    }
    out = out * 8 + (ch.to_int() - '0'.to_int())
  }
  Some(out)
}

///|
fn pdf_parse_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  Some(@string.parse_int(trimmed) catch { _ => return None })
}

///|
fn pdf_parse_double(text : String) -> Double? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  Some(@string.parse_double(trimmed) catch { _ => return None })
}

///|
fn pdf_parse_hex_int(hex : String) -> Int? {
  let trimmed = hex.trim().to_upper()
  if trimmed == "" {
    return None
  }
  let mut out = 0
  for ch in trimmed.to_array() {
    let value = if ch >= '0' && ch <= '9' {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'A' && ch <= 'F' {
      10 + ch.to_int() - 'A'.to_int()
    } else {
      return None
    }
    out = out * 16 + value
  }
  Some(out)
}

///|
fn pdf_first_matching_code_width(
  widths : Array[Int],
  remaining_hex_chars : Int,
) -> Int? {
  for width in widths {
    if width > 0 && width * 2 <= remaining_hex_chars {
      return Some(width)
    }
  }
  None
}

///|
fn pdf_split_ascii_whitespace(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut start : Int? = None
  for index in 0..<text.length() {
    if pdf_is_ascii_whitespace_char(pdf_char_at(text, index)) {
      match start {
        Some(value) if index > value => out.push(text[value:index].to_owned())
        _ => ()
      }
      start = None
    } else if start is None {
      start = Some(index)
    }
  }
  match start {
    Some(value) if value < text.length() => out.push(text[value:].to_owned())
    _ => ()
  }
  out
}

///|
fn pdf_byte_string(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes.to_array() {
    chars.push(Int::unsafe_to_char(byte.to_int()))
  }
  String::from_array(chars)
}

///|
fn pdf_ascii_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
fn pdf_find_bytes(bytes : Bytes, needle : Bytes, start : Int) -> Int? {
  let haystack = bytes.to_array()
  let target = needle.to_array()
  if target.length() == 0 {
    return Some(start)
  }
  let mut index = start
  while index + target.length() <= haystack.length() {
    let mut matched = true
    for offset in 0..<target.length() {
      if haystack[index + offset] != target[offset] {
        matched = false
        break
      }
    }
    if matched {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn pdf_byte_at(bytes : Bytes, index : Int) -> Int {
  bytes.unsafe_get(index).to_int()
}

///|
fn pdf_bytes_match_except_suffix(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() + 1 {
    return false
  }
  let left_arr = left.to_array()
  let right_arr = right.to_array()
  for i in 0..<right_arr.length() {
    if left_arr[i] != right_arr[i] {
      return false
    }
  }
  true
}

///|
fn pdf_stream_suffix_is_single_eol(
  declared_bytes : Bytes,
  trimmed_bytes : Bytes,
) -> Bool {
  if declared_bytes.length() != trimmed_bytes.length() + 1 {
    return false
  }
  let suffix = pdf_byte_at(declared_bytes, declared_bytes.length() - 1)
  suffix == '\n'.to_int() || suffix == '\r'.to_int()
}

///|
fn pdf_previous_line_start_bytes(bytes : Bytes, index : Int) -> Int {
  let arr = bytes.to_array()
  let mut cursor = index
  while cursor > 0 {
    let byte = arr[cursor - 1].to_int()
    if byte == '\n'.to_int() || byte == '\r'.to_int() {
      return cursor
    }
    cursor -= 1
  }
  0
}

///|
fn pdf_skip_object_header_whitespace_bytes(bytes : Bytes, start : Int) -> Int {
  let arr = bytes.to_array()
  let mut index = start
  while index < arr.length() {
    let byte = arr[index].to_int()
    if byte == ' '.to_int() ||
      byte == '\t'.to_int() ||
      byte == '\n'.to_int() ||
      byte == '\r'.to_int() ||
      byte == '\u{000C}'.to_int() {
      index += 1
    } else {
      break
    }
  }
  index
}

///|
fn pdf_find_substring(text : String, needle : String, start : Int) -> Int? {
  if start < 0 || start > text.length() {
    return None
  }
  match text[start:].find(needle) {
    Some(rel) => Some(start + rel)
    None => None
  }
}

///|
fn pdf_identity_matrix() -> PdfNativeGraphicsMatrix {
  { a: 1.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
fn pdf_line_merge_tolerance(
  current : Array[PdfNativeTextFragment],
  next : PdfNativeTextFragment,
) -> Double {
  let mut size = next.font_size.unwrap_or(12.0)
  for fragment in current {
    let current_size = fragment.font_size.unwrap_or(12.0)
    if current_size < size {
      size = current_size
    }
  }
  pdf_double_max(2.0, size * 0.45)
}

///|
fn pdf_normalize_pdf_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut previous_space = false
  for ch in text.to_array() {
    if ch == '\u{0000}' {
      continue
    }
    let is_control_space = ch == '\r' ||
      ch == '\n' ||
      ch == '\t' ||
      ch == '\u{0008}' ||
      ch == '\u{000C}'
    if is_control_space {
      if !previous_space {
        out.write_char(' ')
      }
      previous_space = true
    } else {
      match txt_ligature_expansion(ch) {
        Some(value) => {
          out.write_string(value)
          previous_space = false
        }
        None => {
          out.write_char(ch)
          previous_space = ch == ' '
        }
      }
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_fragment_visual_compare(
  left : PdfNativeTextFragment,
  right : PdfNativeTextFragment,
) -> Int {
  if left.x < right.x {
    -1
  } else if left.x > right.x {
    1
  } else {
    0
  }
}

///|
fn pdf_fragment_reading_order_compare(
  left : PdfNativeTextFragment,
  right : PdfNativeTextFragment,
) -> Int {
  let y_gap = pdf_abs_double(left.y - right.y)
  if y_gap > 2.0 {
    if left.y > right.y {
      -1
    } else {
      1
    }
  } else {
    pdf_fragment_visual_compare(left, right)
  }
}

///|
fn pdf_native_line_reading_order_compare(
  left : PdfNativeTextLine,
  right : PdfNativeTextLine,
) -> Int {
  match (left.reading_order_index, right.reading_order_index) {
    (Some(a), Some(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        pdf_native_line_bbox_compare(left, right)
      }
    _ => pdf_native_line_bbox_compare(left, right)
  }
}

///|
fn pdf_native_line_bbox_compare(
  left : PdfNativeTextLine,
  right : PdfNativeTextLine,
) -> Int {
  let y_gap = pdf_abs_double(left.bbox.y - right.bbox.y)
  if y_gap > 2.0 {
    if left.bbox.y < right.bbox.y {
      -1
    } else {
      1
    }
  } else if left.bbox.x < right.bbox.x {
    -1
  } else if left.bbox.x > right.bbox.x {
    1
  } else {
    0
  }
}

///|
fn pdf_native_lines_bbox(lines : Array[PdfNativeTextLine]) -> PdfBBox {
  let mut bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  for line in lines {
    bbox = if pdf_bbox_is_empty(bbox) {
      line.bbox
    } else {
      pdf_union_bbox(bbox, line.bbox)
    }
  }
  bbox
}

///|
fn pdf_font_uses_code_unit_decode(info : PdfNativeFontInfo) -> Bool {
  if info.tounicode_decode_failed {
    return false
  }
  info.has_tounicode ||
  info.unicode_map.length() > 0 ||
  pdf_font_is_identity_h(info) ||
  pdf_font_has_multibyte_widths(info.code_hex_widths)
}

///|
fn pdf_font_decode_widths(info : PdfNativeFontInfo) -> Array[Int] {
  if info.code_hex_widths.length() > 0 {
    info.code_hex_widths
  } else if pdf_font_is_identity_h(info) {
    [2]
  } else {
    [1]
  }
}

///|
fn pdf_font_has_multibyte_widths(widths : Array[Int]) -> Bool {
  for width in widths {
    if width > 1 {
      return true
    }
  }
  false
}

///|
fn pdf_font_is_identity_h(info : PdfNativeFontInfo) -> Bool {
  info.encoding_name == Some("Identity-H")
}

///|
fn pdf_decode_font_code_fallback(
  key : String,
  info : PdfNativeFontInfo,
) -> String? {
  let decoded = match pdf_hex_to_string(key) {
    Some(value) => value
    None => return None
  }
  if !pdf_text_has_disallowed_control(decoded) {
    return Some(decoded)
  }
  if pdf_font_is_identity_h(info) && key == "0001" {
    return Some(" ")
  }
  None
}

///|
fn pdf_decode_raw_cjk_hex_fallback(
  hex : String,
  info : PdfNativeFontInfo,
) -> String? {
  if !pdf_font_may_use_raw_cjk_decode(info) {
    return None
  }
  let bytes = match pdf_hex_byte_values(hex) {
    Some(value) => value
    None => return None
  }
  if !pdf_raw_cjk_bytes_need_decode(bytes) {
    return None
  }
  let decoded = pdf_decode_gb2312_first_bytes(bytes)
  let strong_cjk_evidence = pdf_font_has_cjk_name_evidence(info)
  if pdf_raw_cjk_decode_result_is_confident_gb2312(decoded) ||
    (
      strong_cjk_evidence &&
      pdf_raw_cjk_decode_result_is_safe_gb2312_token(decoded)
    ) {
    Some(decoded.text)
  } else {
    None
  }
}

///|
fn pdf_text_has_disallowed_control(text : String) -> Bool {
  for ch in text.to_array() {
    let code = ch.to_int()
    if code == 0x0000 {
      return true
    }
    if code < 0x0020 &&
      ch != '\t' &&
      ch != '\n' &&
      ch != '\r' &&
      ch != '\u{0008}' &&
      ch != '\u{000C}' {
      return true
    }
  }
  false
}

///|
fn pdf_is_usable_tounicode_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text.to_array() {
    if pdf_codepoint_is_noncharacter(ch.to_int()) {
      return false
    }
  }
  true
}

///|
fn pdf_codepoint_is_noncharacter(code : Int) -> Bool {
  (code >= 0xFDD0 && code <= 0xFDEF) || (code & 0xFFFE) == 0xFFFE
}

///|
fn pdf_identity_h_ascii_rescue(
  hex : String,
  info : PdfNativeFontInfo,
) -> String? {
  if info.has_tounicode || !pdf_font_is_identity_h(info) {
    return None
  }
  let raw_codes = pdf_hex_codes_as_ints(hex)
  if raw_codes is None {
    return None
  }
  let rescued = pdf_rescued_identity_h_ascii_codepoints(raw_codes.unwrap())
  match rescued {
    Some(codepoints) => Some(pdf_string_from_codepoints(codepoints))
    None => None
  }
}

///|
fn pdf_hex_codes_as_ints(hex : String) -> Array[Int]? {
  let normalized = hex.trim().to_upper()
  if normalized == "" || normalized.length() % 4 != 0 {
    return None
  }
  let codes : Array[Int] = []
  let mut index = 0
  while index + 4 <= normalized.length() {
    match pdf_parse_hex_int(normalized[index:index + 4].to_owned()) {
      Some(code) => codes.push(code)
      None => return None
    }
    index += 4
  }
  Some(codes)
}

///|
fn pdf_hex_byte_values(hex : String) -> Array[Int]? {
  let normalized = hex.trim().to_upper()
  if normalized == "" || normalized.length() % 2 != 0 {
    return None
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index + 2 <= normalized.length() {
    match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
      Some(value) => bytes.push(value)
      None => return None
    }
    index += 2
  }
  Some(bytes)
}

///|
fn pdf_ascii_lower_codepoint(codepoint : Int) -> Int {
  if codepoint >= 65 && codepoint <= 90 {
    codepoint + 32
  } else {
    codepoint
  }
}

///|
fn pdf_font_may_use_raw_cjk_decode(info : PdfNativeFontInfo) -> Bool {
  if info.has_tounicode || info.tounicode_decode_failed {
    return false
  }
  if pdf_font_is_identity_h(info) {
    return false
  }
  pdf_font_has_cjk_name_evidence(info) || pdf_font_is_winansi(info)
}

///|
fn pdf_font_has_cjk_name_evidence(info : PdfNativeFontInfo) -> Bool {
  let normalized = match info.normalized_base_font {
    Some(value) => value
    None => return false
  }
  if pdf_string_contains_cjk_char(normalized) {
    return true
  }
  normalized.contains("gb2312") ||
  normalized.contains("gbk") ||
  normalized.contains("cjk") ||
  normalized.contains("song") ||
  normalized.contains("fang") ||
  normalized.contains("hei") ||
  normalized.contains("kai") ||
  normalized.contains("ming") ||
  normalized.contains("sim")
}

///|
fn pdf_string_contains_cjk_char(text : String) -> Bool {
  for ch in text.to_array() {
    if pdf_is_cjk_char(ch) {
      return true
    }
  }
  false
}

///|
fn pdf_font_is_winansi(info : PdfNativeFontInfo) -> Bool {
  info.encoding_name == Some("WinAnsiEncoding")
}

///|
fn pdf_raw_cjk_bytes_need_decode(bytes : Array[Int]) -> Bool {
  let mut index = 0
  let mut saw_pair = false
  while index < bytes.length() {
    let byte = bytes[index]
    if byte >= 0 && byte <= 0x7F {
      index += 1
      continue
    }
    if index + 1 >= bytes.length() {
      return false
    }
    if pdf_native_gb2312_lookup_codepoint(byte, bytes[index + 1]) is Some(_) {
      saw_pair = true
      index += 2
    } else {
      return false
    }
  }
  saw_pair
}

///|
fn pdf_raw_cjk_decode_result_is_safe_gb2312_token(
  result : PdfRawCjkDecodeResult,
) -> Bool {
  result.invalid_byte_count == 0 &&
  result.has_high_bytes &&
  result.decoded_two_byte_count > 0 &&
  result.text != ""
}

///|
fn pdf_lower_ascii_word_equals(word : Array[Int], expected : String) -> Bool {
  let chars = expected.to_array()
  if word.length() != chars.length() {
    return false
  }
  for i in 0..<word.length() {
    if word[i] != chars[i].to_int() {
      return false
    }
  }
  true
}

///|
fn pdf_is_common_ascii_word(word : Array[Int]) -> Bool {
  pdf_lower_ascii_word_equals(word, "a") ||
  pdf_lower_ascii_word_equals(word, "an") ||
  pdf_lower_ascii_word_equals(word, "and") ||
  pdf_lower_ascii_word_equals(word, "are") ||
  pdf_lower_ascii_word_equals(word, "as") ||
  pdf_lower_ascii_word_equals(word, "at") ||
  pdf_lower_ascii_word_equals(word, "be") ||
  pdf_lower_ascii_word_equals(word, "by") ||
  pdf_lower_ascii_word_equals(word, "for") ||
  pdf_lower_ascii_word_equals(word, "from") ||
  pdf_lower_ascii_word_equals(word, "have") ||
  pdf_lower_ascii_word_equals(word, "in") ||
  pdf_lower_ascii_word_equals(word, "is") ||
  pdf_lower_ascii_word_equals(word, "not") ||
  pdf_lower_ascii_word_equals(word, "of") ||
  pdf_lower_ascii_word_equals(word, "on") ||
  pdf_lower_ascii_word_equals(word, "or") ||
  pdf_lower_ascii_word_equals(word, "that") ||
  pdf_lower_ascii_word_equals(word, "the") ||
  pdf_lower_ascii_word_equals(word, "this") ||
  pdf_lower_ascii_word_equals(word, "to") ||
  pdf_lower_ascii_word_equals(word, "will") ||
  pdf_lower_ascii_word_equals(word, "with")
}

///|
fn pdf_count_common_ascii_words(codepoints : Array[Int]) -> Int {
  let mut count = 0
  let mut word : Array[Int] = []
  for codepoint in codepoints {
    let lowered = pdf_ascii_lower_codepoint(codepoint)
    if lowered >= 97 && lowered <= 122 {
      word.push(lowered)
    } else if word.length() > 0 {
      if pdf_is_common_ascii_word(word) {
        count += 1
      }
      word = []
    }
  }
  if word.length() > 0 && pdf_is_common_ascii_word(word) {
    count += 1
  }
  count
}

///|
fn pdf_count_ascii_words(codepoints : Array[Int]) -> Int {
  let mut count = 0
  let mut inside_word = false
  for codepoint in codepoints {
    let lowered = pdf_ascii_lower_codepoint(codepoint)
    if lowered >= 97 && lowered <= 122 {
      if !inside_word {
        count += 1
        inside_word = true
      }
    } else {
      inside_word = false
    }
  }
  count
}

///|
fn pdf_ascii_shift_score(codepoints : Array[Int]) -> (Int, Int, Int, Int, Int)? {
  let mut spaces = 0
  let mut lowercase = 0
  let mut uppercase = 0
  let mut digits = 0
  let mut punctuation = 0
  for codepoint in codepoints {
    if codepoint < 32 || codepoint > 126 {
      return None
    }
    if codepoint == 32 {
      spaces += 1
    } else if codepoint >= 97 && codepoint <= 122 {
      lowercase += 1
    } else if codepoint >= 65 && codepoint <= 90 {
      uppercase += 1
    } else if codepoint >= 48 && codepoint <= 57 {
      digits += 1
    } else {
      punctuation += 1
    }
  }
  let common_words = pdf_count_common_ascii_words(codepoints)
  let words = pdf_count_ascii_words(codepoints)
  let score = spaces * 6 +
    lowercase * 3 +
    uppercase +
    digits +
    punctuation +
    common_words * 12
  Some((score, spaces, lowercase, common_words, words))
}

///|
fn pdf_rescued_identity_h_ascii_codepoints(
  raw_codes : Array[Int],
) -> Array[Int]? {
  if raw_codes.length() < 8 {
    return None
  }
  for code in raw_codes {
    if code <= 0 || code > 255 {
      return None
    }
  }
  let mut baseline_score = -1000
  let mut baseline_spaces = 0
  let mut baseline_common_words = 0
  match
    pdf_ascii_shift_score(pdf_identity_h_ascii_baseline_codes(raw_codes, 0)) {
    Some((score, spaces, _lowercase, common_words, _words)) => {
      baseline_score = score
      baseline_spaces = spaces
      baseline_common_words = common_words
    }
    None => ()
  }
  if baseline_spaces > 0 && baseline_common_words > 0 {
    return None
  }
  let mut best_score = baseline_score
  let mut best_shift = 0
  let mut best_spaces = 0
  let mut best_lowercase = 0
  let mut best_common_words = 0
  let mut best_words = 0
  for shift in 1..<=95 {
    let shifted = pdf_identity_h_ascii_baseline_codes(raw_codes, shift)
    match pdf_ascii_shift_score(shifted) {
      Some((score, spaces, lowercase, common_words, words)) =>
        if score > best_score {
          best_score = score
          best_shift = shift
          best_spaces = spaces
          best_lowercase = lowercase
          best_common_words = common_words
          best_words = words
        }
      None => ()
    }
  }
  if best_shift == 0 {
    return None
  }
  if best_score < baseline_score + 24 {
    return None
  }
  if best_spaces == 0 || best_lowercase < 3 {
    return None
  }
  if best_common_words == 0 {
    return None
  }
  if best_common_words == 1 &&
    (best_words < 2 || raw_codes.length() < 12 || best_lowercase < 6) {
    return None
  }
  let rescued : Array[Int] = []
  for code in raw_codes {
    if code == 1 {
      rescued.push(32)
    } else {
      rescued.push(code + best_shift)
    }
  }
  Some(rescued)
}

///|
fn pdf_identity_h_ascii_baseline_codes(
  raw_codes : Array[Int],
  shift : Int,
) -> Array[Int] {
  let shifted : Array[Int] = []
  for code in raw_codes {
    if code == 1 {
      shifted.push(32)
    } else {
      shifted.push(code + shift)
    }
  }
  shifted
}

///|
fn pdf_string_from_codepoints(codepoints : Array[Int]) -> String {
  let chars : Array[Char] = []
  for codepoint in codepoints {
    chars.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(chars)
}

///|
fn pdf_normalized_pdf_font_name(name : String?) -> String? {
  let raw = match name {
    Some(value) => value.trim().to_owned()
    None => return None
  }
  if raw == "" {
    return None
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index < raw.length() {
    let ch = pdf_char_at(raw, index)
    if ch == '#' && index + 2 < raw.length() {
      match pdf_parse_hex_int(raw[index + 1:index + 3].to_owned()) {
        Some(code) => {
          bytes.push(code)
          index += 3
          continue
        }
        None => ()
      }
    }
    bytes.push(ch.to_int())
    index += 1
  }
  let decoded = pdf_decode_gb2312_first_bytes(bytes)
  if pdf_raw_cjk_decode_result_is_confident_gb2312(decoded) {
    Some(decoded.text.to_lower())
  } else {
    let chars : Array[Char] = []
    for byte in bytes {
      chars.push(Int::unsafe_to_char(byte))
    }
    Some(String::from_array(chars).to_lower())
  }
}

///|
fn pdf_is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn pdf_is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x3040 && code <= 0x30FF) ||
  (code >= 0xAC00 && code <= 0xD7AF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn pdf_native_source_id(source : @input.InputSource) -> String {
  match source.path {
    Some(path) => path
    None => source.source_name
  }
}

///|
fn pdf_native_count_line_spans(lines : Array[PdfNativeTextLine]) -> Int {
  let mut count = 0
  for line in lines {
    count += line.spans.length()
  }
  count
}

///|
fn pdf_native_page_line_count(page : PdfNativePage) -> Int {
  let mut count = 0
  for block in page.text_blocks {
    count += block.lines.length()
  }
  count
}

///|
fn pdf_native_page_span_count(page : PdfNativePage) -> Int {
  let mut count = 0
  for block in page.text_blocks {
    for line in block.lines {
      count += line.spans.length()
    }
  }
  count
}

///|
fn pdf_is_ascii_whitespace_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\u{000C}'
}

///|
fn pdf_is_token_delimiter(ch : Char) -> Bool {
  ch == '(' ||
  ch == ')' ||
  ch == '<' ||
  ch == '>' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '/' ||
  ch == '%'
}

///|
fn pdf_is_octal_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '7'
}

///|
fn pdf_is_ascii_punctuation(ch : Char) -> Bool {
  (ch >= '!' && ch <= '/') ||
  (ch >= ':' && ch <= '@') ||
  (ch >= '[' && ch <= '`') ||
  (ch >= '{' && ch <= '~')
}

///|
fn pdf_is_cjk_punctuation(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x3000 && code <= 0x303F) ||
  (code >= 0xFF00 && code <= 0xFF0F) ||
  (code >= 0xFF1A && code <= 0xFF20) ||
  (code >= 0xFF3B && code <= 0xFF40) ||
  (code >= 0xFF5B && code <= 0xFF65)
}

///|
fn pdf_abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn pdf_char_at(text : String, index : Int) -> Char {
  text.unsafe_get(index).unsafe_to_char()
}

///|
priv enum PdfNativeDictValue {
  Number(Double)
  Name(String)
  Word(String)
  LiteralString(PdfNativeTokenizedString)
  HexString(String)
  Array(Array[PdfNativeContentToken])
  Dict(String)
  Reference(Int, Int)
}

///|
fn pdf_expand_object_streams(
  objects : Array[PdfNativeObject],
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  let expanded : Array[PdfNativeObject] = []
  for object in objects {
    match pdf_extract_name_after(object.dict_text, "/Type") {
      Some("ObjStm") => {
        let parsed = match pdf_parse_object_stream_entries(object) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        expanded.append(parsed[:])
      }
      _ => ()
    }
  }
  Ok(expanded)
}

///|
fn pdf_parse_object_stream_entries(
  object : PdfNativeObject,
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  let stream_text = match pdf_decode_stream_text(object, "object stream") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let first = match pdf_extract_int_after(object.dict_text, "/First") {
    Some(value) if value >= 0 && value <= stream_text.length() => value
    _ =>
      return Err(
        PdfNativeError::ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " is missing valid /First",
        ),
      )
  }
  let count = match pdf_extract_int_after(object.dict_text, "/N") {
    Some(value) if value >= 0 => value
    _ =>
      return Err(
        PdfNativeError::ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " is missing valid /N",
        ),
      )
  }
  let header_text = stream_text[:first].to_owned()
  let body_text = stream_text[first:].to_owned()
  let header_parts = pdf_split_ascii_whitespace(header_text)
  if header_parts.length() < count * 2 {
    return Err(
      PdfNativeError::ParseFailed(
        "object stream " + object.object_id.to_string() + " header is truncated",
      ),
    )
  }
  let entries : Array[(Int, Int)] = []
  let mut index = 0
  while index + 1 < count * 2 {
    match
      (
        pdf_parse_int(header_parts[index]),
        pdf_parse_int(header_parts[index + 1]),
      ) {
      (Some(object_id), Some(offset)) => entries.push((object_id, offset))
      _ =>
        return Err(
          PdfNativeError::ParseFailed(
            "object stream " +
            object.object_id.to_string() +
            " header contains invalid object entry",
          ),
        )
    }
    index += 2
  }
  let out : Array[PdfNativeObject] = []
  for idx in 0..<entries.length() {
    let (object_id, offset) = entries[idx]
    let next_offset = if idx + 1 < entries.length() {
      entries[idx + 1].1
    } else {
      body_text.length()
    }
    if offset < 0 || next_offset < offset || next_offset > body_text.length() {
      return Err(
        PdfNativeError::ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " has invalid embedded object offsets",
        ),
      )
    }
    let embedded_body = body_text[offset:next_offset].trim().to_owned()
    let embedded_bytes = pdf_ascii_bytes(embedded_body)
    let stream_slice = match pdf_extract_stream_slice(embedded_bytes) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let dict_text = match stream_slice {
      Some(slice) => slice.0
      None => embedded_body
    }
    let stream = match stream_slice {
      Some(slice) => Some(slice.1)
      None => None
    }
    out.push({ object_id, dict_text, stream })
  }
  Ok(out)
}

///|
fn pdf_extract_filter_names(dict_text : String) -> Array[String] {
  match pdf_extract_dict_value(dict_text, "/Filter") {
    Some(PdfNativeDictValue::Name(value)) => [value]
    Some(PdfNativeDictValue::Array(tokens)) => {
      let names : Array[String] = []
      for token in tokens {
        match token {
          PdfNativeContentToken::Name(value) => names.push(value)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
}

///|
fn pdf_collect_reference_ids_from_tokens(
  tokens : Array[PdfNativeContentToken],
) -> Array[Int] {
  let refs : Array[Int] = []
  let mut index = 0
  while index + 2 < tokens.length() {
    match (tokens[index], tokens[index + 1], tokens[index + 2]) {
      (
        PdfNativeContentToken::Number(object_id),
        PdfNativeContentToken::Number(_generation),
        PdfNativeContentToken::Word("R"),
      ) =>
        if pdf_double_is_integral(object_id) {
          refs.push(object_id.to_int())
        }
      _ => ()
    }
    index += 1
  }
  refs
}

///|
fn pdf_extract_dict_value(text : String, key : String) -> PdfNativeDictValue? {
  let parsed = match pdf_parse_dict_entries(text) {
    Some(value) => value
    None => return None
  }
  for entry in parsed {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pdf_parse_dict_entries(
  text : String,
) -> Array[(String, PdfNativeDictValue)]? {
  let start = match text.find("<<") {
    Some(index) => index
    None => return None
  }
  let parsed = pdf_parse_dict_token(text, start)
  let dict_text = parsed.0
  if !dict_text.has_prefix("<<") || !dict_text.has_suffix(">>") {
    return None
  }
  let content = dict_text[2:dict_text.length() - 2].to_owned()
  let tokens = match pdf_scan_content_tokens(content) {
    Ok(value) => value
    Err(_) => return None
  }
  let entries : Array[(String, PdfNativeDictValue)] = []
  let mut index = 0
  while index < tokens.length() {
    match tokens[index] {
      PdfNativeContentToken::Name(name) => {
        let (value, next_index) = pdf_dict_value_from_tokens(tokens, index + 1)
        if name != "" {
          entries.push(("/" + name, value))
        }
        index = next_index
      }
      _ => index += 1
    }
  }
  Some(entries)
}

///|
fn pdf_dict_value_from_tokens(
  tokens : Array[PdfNativeContentToken],
  start : Int,
) -> (PdfNativeDictValue, Int) {
  if start >= tokens.length() {
    return (PdfNativeDictValue::Word(""), start)
  }
  if start + 2 < tokens.length() {
    match (tokens[start], tokens[start + 1], tokens[start + 2]) {
      (
        PdfNativeContentToken::Number(object_id),
        PdfNativeContentToken::Number(generation),
        PdfNativeContentToken::Word("R"),
      ) =>
        if pdf_double_is_integral(object_id) &&
          pdf_double_is_integral(generation) {
          return (
            PdfNativeDictValue::Reference(
              object_id.to_int(),
              generation.to_int(),
            ),
            start + 3,
          )
        }
      _ => ()
    }
  }
  match tokens[start] {
    PdfNativeContentToken::Number(value) =>
      (PdfNativeDictValue::Number(value), start + 1)
    PdfNativeContentToken::Name(value) =>
      (PdfNativeDictValue::Name(value), start + 1)
    PdfNativeContentToken::Word(value) =>
      (PdfNativeDictValue::Word(value), start + 1)
    PdfNativeContentToken::LiteralString(value) =>
      (PdfNativeDictValue::LiteralString(value), start + 1)
    PdfNativeContentToken::HexString(value) =>
      (PdfNativeDictValue::HexString(value), start + 1)
    PdfNativeContentToken::Array(value) =>
      (PdfNativeDictValue::Array(value), start + 1)
    PdfNativeContentToken::Dict(value) =>
      (PdfNativeDictValue::Dict(value), start + 1)
  }
}

///|
fn pdf_decode_hex_utf16be(hex : String) -> String? {
  let normalized = hex.trim().to_upper()
  if normalized.length() < 4 || normalized.length() % 2 != 0 {
    return None
  }
  let bytes : Array[Byte] = []
  let mut index = 0
  while index + 2 <= normalized.length() {
    match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
      Some(value) => bytes.push(value.to_byte())
      None => return None
    }
    index += 2
  }
  let decoded = @encoding.decode(
    Bytes::from_array(bytes),
    encoding=@encoding.UTF16BE,
  ) catch {
    _ => return None
  }
  Some(pdf_strip_utf16_bom(decoded))
}

///|
fn pdf_strip_utf16_bom(text : String) -> String {
  let chars = text.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    String::from_array(chars[1:])
  } else {
    text
  }
}

///|
fn pdf_double_is_integral(value : Double) -> Bool {
  value.to_int().to_double() == value
}
