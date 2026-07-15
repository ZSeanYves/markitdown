///|
fn pdf_decode_image_prefix_filters_with_params(
  payload : Bytes,
  filters : Array[String],
  params : Array[PdfStreamDecodeParams?],
  decode_count : Int,
) -> Result[Bytes, String] {
  let limit = if decode_count < filters.length() {
    decode_count
  } else {
    filters.length()
  }
  let prefix_filters : Array[String] = []
  let prefix_params : Array[PdfStreamDecodeParams?] = []
  for index in 0..<limit {
    prefix_filters.push(filters[index])
    prefix_params.push(
      if index < params.length() {
        params[index]
      } else {
        None
      },
    )
  }
  decode_pdf_stream_filters_with_params(payload, prefix_filters, prefix_params)
}

///|
fn pdf_image_filter_param_dict_text_at(
  dict_text : String,
  filter_count : Int,
  filter_index : Int,
) -> String? {
  let value = match pdf_extract_dict_value(dict_text, "/DecodeParms") {
    Some(found) => Some(found)
    None => pdf_extract_dict_value(dict_text, "/DP")
  }
  match value {
    Some(PdfNativeDictValue::Dict(text)) if filter_count == 1 &&
      filter_index == 0 => Some(text)
    Some(PdfNativeDictValue::Array(items)) =>
      if filter_index < items.length() {
        match items[filter_index] {
          PdfNativeContentToken::Dict(text) => Some(text)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn pdf_dict_bool_value(dict_text : String, key : String) -> Bool? {
  match pdf_extract_dict_value(dict_text, key) {
    Some(PdfNativeDictValue::Word("true")) => Some(true)
    Some(PdfNativeDictValue::Word("false")) => Some(false)
    _ => None
  }
}

///|
fn pdf_ccitt_fax_params_from_image_object(
  object : PdfNativeObject,
  decode_param_dict_text : String?,
) -> PdfCcittFaxParams? {
  let width = pdf_extract_int_after(object.dict_text, "/Width").unwrap_or(0)
  let raw_height = pdf_extract_int_after(object.dict_text, "/Height").unwrap_or(
    0,
  )
  let bits_per_component = pdf_extract_int_after(
    object.dict_text,
    "/BitsPerComponent",
  ).unwrap_or(1)
  if width <= 0 || raw_height <= 0 || bits_per_component != 1 {
    return None
  }
  let k = match decode_param_dict_text {
    Some(text) => pdf_extract_int_after(text, "/K").unwrap_or(0)
    None => 0
  }
  let rows = match decode_param_dict_text {
    Some(text) => pdf_extract_int_after(text, "/Rows").unwrap_or(raw_height)
    None => raw_height
  }
  if rows <= 0 {
    return None
  }
  let black_is_1 = match decode_param_dict_text {
    Some(text) => pdf_dict_bool_value(text, "/BlackIs1").unwrap_or(false)
    None => false
  }
  let encoded_byte_align = match decode_param_dict_text {
    Some(text) =>
      pdf_dict_bool_value(text, "/EncodedByteAlign").unwrap_or(false)
    None => false
  }
  Some({
    compression: if k < 0 {
      4
    } else {
      3
    },
    width,
    height: rows,
    photometric: if black_is_1 {
      1
    } else {
      0
    },
    encoded_byte_align,
  })
}

///|
fn pdf_push_u16le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn pdf_push_u32le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn pdf_push_tiff_ifd_entry_short(
  out : Array[Byte],
  tag : Int,
  value : Int,
) -> Unit {
  pdf_push_u16le(out, tag)
  pdf_push_u16le(out, 3)
  pdf_push_u32le(out, 1)
  pdf_push_u16le(out, value)
  pdf_push_u16le(out, 0)
}

///|
fn pdf_push_tiff_ifd_entry_long(
  out : Array[Byte],
  tag : Int,
  value : Int,
) -> Unit {
  pdf_push_u16le(out, tag)
  pdf_push_u16le(out, 4)
  pdf_push_u32le(out, 1)
  pdf_push_u32le(out, value)
}

///|
fn pdf_wrap_ccitt_payload_as_tiff(
  payload : Bytes,
  params : PdfCcittFaxParams,
) -> Bytes {
  ignore(params.encoded_byte_align)
  let entry_count = 9
  let ifd_offset = 8
  let strip_offset = ifd_offset + 2 + entry_count * 12 + 4
  let out : Array[Byte] = []
  out.push('I'.to_int().to_byte())
  out.push('I'.to_int().to_byte())
  pdf_push_u16le(out, 42)
  pdf_push_u32le(out, ifd_offset)
  pdf_push_u16le(out, entry_count)
  pdf_push_tiff_ifd_entry_long(out, 256, params.width)
  pdf_push_tiff_ifd_entry_long(out, 257, params.height)
  pdf_push_tiff_ifd_entry_short(out, 258, 1)
  pdf_push_tiff_ifd_entry_short(out, 259, params.compression)
  pdf_push_tiff_ifd_entry_short(out, 262, params.photometric)
  pdf_push_tiff_ifd_entry_long(out, 273, strip_offset)
  pdf_push_tiff_ifd_entry_short(out, 277, 1)
  pdf_push_tiff_ifd_entry_long(out, 278, params.height)
  pdf_push_tiff_ifd_entry_long(out, 279, payload.length())
  pdf_push_u32le(out, 0)
  out.append(payload.to_array())
  Bytes::from_array(out)
}

///|
fn pdf_detect_binary_image_payload(payload : Bytes) -> (String, String)? {
  if payload.length() >= 2 &&
    pdf_byte_at(payload, 0) == 0xFF &&
    pdf_byte_at(payload, 1) == 0xD8 {
    return Some(("image/jpeg", "jpg"))
  }
  if payload.length() >= 8 &&
    pdf_byte_at(payload, 0) == 0x89 &&
    pdf_byte_at(payload, 1) == 0x50 &&
    pdf_byte_at(payload, 2) == 0x4E &&
    pdf_byte_at(payload, 3) == 0x47 &&
    pdf_byte_at(payload, 4) == 0x0D &&
    pdf_byte_at(payload, 5) == 0x0A &&
    pdf_byte_at(payload, 6) == 0x1A &&
    pdf_byte_at(payload, 7) == 0x0A {
    return Some(("image/png", "png"))
  }
  if payload.length() >= 6 {
    let header = pdf_byte_string(payload[:6].to_owned())
    if header == "GIF87a" || header == "GIF89a" {
      return Some(("image/gif", "gif"))
    }
  }
  if payload.length() >= 2 &&
    pdf_byte_at(payload, 0) == 'B'.to_int() &&
    pdf_byte_at(payload, 1) == 'M'.to_int() {
    return Some(("image/bmp", "bmp"))
  }
  if payload.length() >= 12 &&
    pdf_byte_string(payload[:4].to_owned()) == "RIFF" &&
    pdf_byte_string(payload[8:12].to_owned()) == "WEBP" {
    return Some(("image/webp", "webp"))
  }
  None
}

///|
fn pdf_concat_graphics_matrix(
  outer : PdfNativeGraphicsMatrix,
  inner : PdfNativeGraphicsMatrix,
) -> PdfNativeGraphicsMatrix {
  {
    a: outer.a * inner.a,
    d: outer.d * inner.d,
    e: outer.a * inner.e + outer.e,
    f: outer.d * inner.f + outer.f,
  }
}

///|
fn pdf_form_graphics_matrix(dict_text : String) -> PdfNativeGraphicsMatrix {
  match pdf_extract_dict_value(dict_text, "/Matrix") {
    Some(PdfNativeDictValue::Array(values)) =>
      pdf_matrix_from_token_array(values).unwrap_or(pdf_identity_matrix())
    _ => pdf_identity_matrix()
  }
}

///|
fn pdf_matrix_from_token_array(
  values : Array[PdfNativeContentToken],
) -> PdfNativeGraphicsMatrix? {
  if values.length() < 6 {
    return None
  }
  Some({
    a: pdf_token_number(values[0]).unwrap_or(1.0),
    d: pdf_token_number(values[3]).unwrap_or(1.0),
    e: pdf_token_number(values[4]).unwrap_or(0.0),
    f: pdf_token_number(values[5]).unwrap_or(0.0),
  })
}

///|
fn pdf_image_bbox_from_graphics_matrix(
  matrix : PdfNativeGraphicsMatrix,
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> PdfBBox {
  let raw_width = if pdf_abs_double(matrix.a) > 0.0 {
    matrix.a
  } else {
    intrinsic_width
  }
  let raw_height = if pdf_abs_double(matrix.d) > 0.0 {
    matrix.d
  } else {
    intrinsic_height
  }
  let width = pdf_abs_double(raw_width)
  let height = pdf_abs_double(raw_height)
  let x = if raw_width >= 0.0 { matrix.e } else { matrix.e + raw_width }
  let y = if raw_height >= 0.0 { matrix.f } else { matrix.f + raw_height }
  make_pdf_bbox(x, y, width, height)
}

///|
fn pdf_native_exportable_image_asset_count(
  image_candidates : Array[PdfNativeImageCandidate],
) -> Int {
  image_candidates.filter(candidate => candidate.asset_ref is Some(_)).length()
}

///|
fn pdf_native_unsupported_image_asset_count(
  image_candidates : Array[PdfNativeImageCandidate],
) -> Int {
  image_candidates.filter(candidate => candidate.asset_ref is None).length()
}

///|
fn pdf_native_unsupported_image_asset_details(
  image_candidates : Array[PdfNativeImageCandidate],
) -> Array[String] {
  let details : Array[String] = []
  let mut omitted = 0
  for candidate in image_candidates {
    if candidate.asset_ref is Some(_) {
      continue
    }
    if details.length() >= 8 {
      omitted += 1
      continue
    }
    let source_ref = match candidate.source_ref {
      Some(value) => value
      None => {
        details.push("PDF image asset omitted: metadata unavailable")
        continue
      }
    }
    details.push(
      "PDF image asset omitted: object_id=" +
      source_ref.extra.get("pdf_object_id").unwrap_or("unknown") +
      " xobject=" +
      source_ref.extra.get("pdf_xobject_name").unwrap_or("unknown") +
      " filters=" +
      source_ref.extra.get("pdf_image_filter_chain").unwrap_or("none") +
      " color_space=" +
      source_ref.extra.get("pdf_image_color_space").unwrap_or("unresolved") +
      " reason=" +
      source_ref.extra.get("pdf_image_asset_reason").unwrap_or("unknown"),
    )
  }
  if omitted > 0 {
    details.push(
      "PDF image asset diagnostics omitted for " +
      omitted.to_string() +
      " additional candidates",
    )
  }
  details
}

///|
/// ToUnicode/CMap-scoped decode wrapper. This is not a generic PDF StreamDecode
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
  let filter_specs = match pdf_extract_stream_filter_specs(object.dict_text) {
    Ok(value) => value
    Err(err) =>
      return Err({
        strategy: Failed,
        diagnostics: {
          filter_name: "DecodeParms",
          input_length: stream.primary_bytes.length(),
          declared_length: stream.declared_length,
          actual_sliced_length: stream.endstream_bytes.length(),
          zlib_status: "failed:" + err,
          raw_fallback: Skipped("filter_decode_failed"),
        },
        message: "filter decode failed for object " +
        object.object_id.to_string() +
        " (cmap): " +
        err,
      })
  }
  let filters = filter_specs.0
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
  match
    decode_pdf_stream_filters_with_params(
      selected_bytes,
      filters,
      filter_specs.1,
    ) {
    Ok(bytes) =>
      Ok({
        text: pdf_byte_string(bytes),
        strategy: if filters.length() == 1 && filters[0] == "FlateDecode" {
          ZlibFlateDecode
        } else {
          Failed
        },
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
          raw_fallback=Skipped("filter_decode_failed"),
        ),
        message: "filter decode failed for object " +
        object.object_id.to_string() +
        " (cmap): " +
        err,
      })
  }
}

///|
fn pdf_stream_selected_bytes(stream : PdfNativeStreamSlice) -> Bytes {
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
fn pdf_cmap_stream_selected_bytes(stream : PdfNativeStreamSlice) -> Bytes {
  pdf_stream_selected_bytes(stream)
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
