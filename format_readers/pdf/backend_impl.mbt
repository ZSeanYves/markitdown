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
fn pdf_native_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
    @input.InputKind::Reader => "reader"
  }
}

///|
fn pdf_native_line_text(line : PdfNativeTextLine) -> String {
  let parts : Array[String] = []
  for span in line.spans {
    if span.text != "" {
      parts.push(span.text)
    }
  }
  parts.join("")
}

///|
fn pdf_native_line_base_source_ref(line : PdfNativeTextLine) -> @core.SourceRef {
  match line.source_ref {
    Some(value) => value
    None =>
      match line.spans {
        [first, ..] =>
          match first.source_ref {
            Some(value) => value
            None => @core.empty_source_ref()
          }
        _ => @core.empty_source_ref()
      }
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
fn pdf_load_object_store(
  source : @input.InputSource,
) -> Result[PdfParsedObjectStore, PdfNativeError] {
  let cursor = match @input.open_source_cursor(source) {
    Ok(value) => value
    Err(_) => return pdf_load_object_store_materialized(source)
  }
  let prefix = match pdf_cursor_read_exact(cursor, 0, 5) {
    Ok(value) => value
    Err(_) => return pdf_load_object_store_materialized(source)
  }
  if pdf_byte_string(prefix) != "%PDF-" {
    return Err(
      PdfNativeError::ParseFailed(
        "input is not a PDF file: " + pdf_native_source_id(source),
      ),
    )
  }
  match pdf_parse_objects_via_cursor(cursor) {
    Ok(Some(store)) =>
      if pdf_parsed_store_is_encrypted(store) {
        Err(
          PdfNativeError::EncryptedUnsupported(
            "encrypted PDF is unsupported in native PDF reader backend: " +
            pdf_native_source_id(source),
          ),
        )
      } else {
        Ok(store)
      }
    Ok(None) | Err(_) => pdf_load_object_store_materialized(source)
  }
}

///|
fn pdf_load_object_store_materialized(
  source : @input.InputSource,
) -> Result[PdfParsedObjectStore, PdfNativeError] {
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
        "encrypted PDF is unsupported in native PDF reader backend: " +
        pdf_native_source_id(source),
      ),
    )
  }
  pdf_parse_objects(bytes, view)
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
  let parsed_store = match pdf_load_object_store(source) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let objects = parsed_store.objects
  let object_index = parsed_store.object_index
  let font_registry = match pdf_collect_font_infos(object_index) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let fonts = font_registry.infos
  let mut tounicode_failed_font_count = 0
  let mut tounicode_fail_closed_font_count = 0
  let decode_path_labels : Map[String, Bool] = Map([])
  let width_source_labels : Map[String, Bool] = Map([])
  let mut predefined_cmap_font_count = 0
  let mut embedded_font_program_count = 0
  let mut cid_to_gid_font_count = 0
  for entry in fonts.to_array() {
    let font = entry.1
    if font.tounicode_decode_failed {
      tounicode_failed_font_count += 1
    }
    if pdf_font_should_fail_closed_after_tounicode(font) {
      tounicode_fail_closed_font_count += 1
    }
    if font.predefined_cmap is Some(_) || font.cid_collection_cmap is Some(_) {
      predefined_cmap_font_count += 1
    }
    if font.embedded_font_program is Some(_) {
      embedded_font_program_count += 1
    }
    if font.cid_to_gid_map is Some(_) {
      cid_to_gid_font_count += 1
    }
    for label in pdf_font_decode_path_labels(font) {
      decode_path_labels.set(label, true)
    }
    for label in pdf_font_width_source_labels(font) {
      width_source_labels.set(label, true)
    }
  }
  let page_object_ids = pdf_ordered_page_object_ids(
    parsed_store.trailer_hints,
    object_index,
    objects,
  )
  let page_numbers = pdf_page_number_index(page_object_ids)
  let annotation_pages = pdf_annotation_page_index(
    objects, object_index, page_numbers,
  )
  let pages = match
    pdf_build_native_pages(
      source,
      page_object_ids,
      object_index,
      fonts,
      font_registry.inline_ids,
      page_numbers,
    ) {
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
  let mut image_count = 0
  let mut exportable_asset_count = 0
  let mut unsupported_image_asset_count = 0
  let all_image_candidates : Array[PdfNativeImageCandidate] = []
  let mut link_count = 0
  let mut annotation_count = 0
  let mut destination_count = 0
  for page in pages {
    page_count += 1
    text_block_count += page.text_blocks.length()
    line_count += pdf_native_page_line_count(page)
    span_count += pdf_native_page_span_count(page)
    image_count += page.image_candidates.length()
    all_image_candidates.append(page.image_candidates)
    exportable_asset_count += pdf_native_exportable_image_asset_count(
      page.image_candidates,
    )
    unsupported_image_asset_count += pdf_native_unsupported_image_asset_count(
      page.image_candidates,
    )
    link_count += page.link_candidates.length()
    annotation_count += page.annotations.length()
    destination_count += page.destinations.length()
  }
  let form_fields = pdf_extract_form_fields(
    source,
    parsed_store.trailer_hints,
    object_index,
    page_numbers,
    annotation_pages,
  )
  let outline_items = pdf_extract_outline_items(
    source,
    parsed_store.trailer_hints,
    object_index,
    page_numbers,
  )
  let named_destinations = pdf_extract_named_destinations(
    source,
    parsed_store.trailer_hints,
    object_index,
    page_numbers,
  )
  let has_appendix_signal = image_count > 0 ||
    annotation_count > 0 ||
    form_fields.length() > 0 ||
    outline_items.length() > 0 ||
    named_destinations.length() > 0 ||
    destination_count > 0
  if span_count == 0 {
    if !has_appendix_signal && tounicode_fail_closed_font_count == 0 {
      return Err(
        PdfNativeError::EmptyTextLayer(
          "PDF native text layer is empty or not recoverable by native PDF reader backend: " +
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
    Some(pdf_native_input_kind_name(@input.input_kind(source))),
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
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_xref_mode", parsed_store.xref_mode)
  diagnostics.metrics.set(
    "pdf_input_access_mode",
    parsed_store.input_access_mode,
  )
  diagnostics.metrics.set(
    "pdf_filter_decode_mode",
    parsed_store.filter_decode_mode,
  )
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
  diagnostics.metrics.set("image_count", image_count.to_string())
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
  diagnostics.metrics.set("asset_count", exportable_asset_count.to_string())
  diagnostics.metrics.set(
    "pdf_unsupported_image_asset_count",
    unsupported_image_asset_count.to_string(),
  )
  if unsupported_image_asset_count > 0 {
    diagnostics.warnings.append(
      pdf_native_unsupported_image_asset_details(all_image_candidates),
    )
    diagnostics.degraded_features.push("pdf_image_asset_unsupported")
  }
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("native_backend", "root_minimal")
  diagnostics.metrics.set("supports_flate_text_streams", "true")
  diagnostics.metrics.set("supports_tounicode", "true")
  diagnostics.metrics.set(
    "tounicode_decode_failed",
    if tounicode_failed_font_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_tounicode_failed_font_count",
    tounicode_failed_font_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_tounicode_fail_closed_font_count",
    tounicode_fail_closed_font_count.to_string(),
  )
  let decode_paths = pdf_sorted_metric_labels(decode_path_labels)
  let width_sources = pdf_sorted_metric_labels(width_source_labels)
  diagnostics.metrics.set(
    "pdf_font_decode_path",
    if decode_paths.length() == 0 {
      "none"
    } else {
      decode_paths.join("|")
    },
  )
  diagnostics.metrics.set(
    "pdf_predefined_cmap_used",
    if predefined_cmap_font_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_embedded_font_program_used",
    if embedded_font_program_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_cid_to_gid_used",
    if cid_to_gid_font_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_width_source",
    if width_sources.length() == 0 {
      "heuristic"
    } else {
      width_sources.join("|")
    },
  )
  diagnostics.metrics.set(
    "pdf_width_fallback_used",
    if pdf_metric_labels_contain(width_sources, "heuristic") {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("product_path_enabled", "false")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("probe_artifact_reused", "false")
  diagnostics.metrics.set("process_cache_hit", "false")
  if tounicode_failed_font_count > 0 {
    diagnostics.degraded_features.push("pdf_tounicode_decode_failed")
  }
  if tounicode_fail_closed_font_count > 0 && span_count == 0 {
    diagnostics.degraded_features.push("pdf_tounicode_fail_closed")
  }
  let metadata : Map[String, @core.JsonValue] = Map([])
  metadata.set("pdf_native_backend", @core.JsonValue::Bool(true))
  metadata.set("pdf_native_text_baseline", @core.JsonValue::Bool(true))
  metadata.set("pdf_ocr_used", @core.JsonValue::Bool(false))
  metadata.set("pdf_canonical_pipeline_used", @core.JsonValue::Bool(false))
  metadata.set(
    "pdf_predefined_cmap_used",
    @core.JsonValue::Bool(predefined_cmap_font_count > 0),
  )
  metadata.set(
    "pdf_embedded_font_program_used",
    @core.JsonValue::Bool(embedded_font_program_count > 0),
  )
  metadata.set(
    "pdf_cid_to_gid_used",
    @core.JsonValue::Bool(cid_to_gid_font_count > 0),
  )
  metadata.set(
    "pdf_width_fallback_used",
    @core.JsonValue::Bool(pdf_metric_labels_contain(width_sources, "heuristic")),
  )
  metadata.set(
    "pdf_font_decode_path",
    @core.JsonValue::String(
      if decode_paths.length() == 0 {
        "none"
      } else {
        decode_paths.join("|")
      },
    ),
  )
  metadata.set(
    "pdf_width_source",
    @core.JsonValue::String(
      if width_sources.length() == 0 {
        "heuristic"
      } else {
        width_sources.join("|")
      },
    ),
  )
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
  metadata.set("image_count", @core.JsonValue::Number(image_count.to_string()))
  metadata.set(
    "pdf_image_candidate_count",
    @core.JsonValue::Number(image_count.to_string()),
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
  match pdf_extract_info_metadata(parsed_store.trailer_hints, object_index) {
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
  descendant_subtype : String?
  encoding_name : String?
  code_hex_widths : Array[Int]
  unicode_map : Map[String, String]
  tounicode_invalid_keys : Map[String, Bool]
  has_tounicode : Bool
  tounicode_decode_failed : Bool
  tounicode_builtin_name : String?
  predefined_cmap : PdfResolvedPredefinedCMap?
  cid_collection_cmap : PdfResolvedPredefinedCMap?
  embedded_font_program : PdfEmbeddedFontProgram?
  cid_to_gid_map : Array[Int]?
  simple_widths : Map[Int, Int]
  simple_default_width : Int?
  cid_width_pairs : Array[Int]
  cid_default_width : Int?
  cid_vertical_width_pairs : Array[Int]
  cid_default_vertical_width : Int?
}

///|
priv struct PdfNativeFontEncodingInfo {
  encoding_name : String?
  code_hex_widths : Array[Int]
  unicode_map : Map[String, String]
}

///|
priv struct PdfFontRegistry {
  infos : Map[Int, PdfNativeFontInfo]
  inline_ids : Map[String, Int]
}

///|
priv struct PdfToUnicodeCMapInfo {
  mapping : Map[String, String]
  invalid_keys : Map[String, Bool]
  widths : Array[Int]
  usecmap_name : String?
  builtin_parent_name : String?
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
  vertical_writing : Bool
}

///|
priv struct PdfNativeGraphicsMatrix {
  a : Double
  d : Double
  e : Double
  f : Double
}

///|
priv struct PdfParsedObjectStore {
  objects : Array[PdfNativeObject]
  object_index : Map[Int, PdfNativeObject]
  trailer_hints : Array[String]
  xref_mode : String
  filter_decode_mode : String
  input_access_mode : String
}

///|
priv enum PdfNativeXrefEntry {
  InUse(Int, Int)
  Compressed(Int, Int)
}

///|
priv struct PdfParsedXrefSection {
  entries : Map[Int, PdfNativeXrefEntry]
  trailer_text : String
  next_offsets : Array[Int]
  used_xref_stream : Bool
  has_object_stream_refs : Bool
}

///|
priv struct PdfResolvedXrefChain {
  entries : Map[Int, PdfNativeXrefEntry]
  trailer_hints : Array[String]
  used_xref_stream : Bool
  has_object_stream_refs : Bool
}

///|
priv struct PdfXrefDirectObjectLocation {
  object_id : Int
  offset : Int
}

///|
priv struct PdfXrefCompressedObjectRef {
  object_id : Int
  object_stream_id : Int
}
