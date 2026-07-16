///|
fn pdf_decode_stream_text(
  object : PdfNativeObject,
  context : String,
) -> Result[String, PdfNativeError] {
  match pdf_decode_stream_bytes(object, context) {
    Ok(bytes) => Ok(pdf_byte_string(bytes))
    Err(err) => Err(err)
  }
}

///|
fn pdf_decode_stream_bytes(
  object : PdfNativeObject,
  context : String,
) -> Result[Bytes, PdfNativeError] {
  let stream = match object.stream {
    Some(value) => value
    None =>
      return Err(
        ParseFailed(
          "object " +
          object.object_id.to_string() +
          " has no stream for " +
          context,
        ),
      )
  }
  let stream_bytes = stream.primary_bytes
  let filter_specs = match pdf_extract_stream_filter_specs(object.dict_text) {
    Ok(value) => value
    Err(err) =>
      return Err(
        UnsupportedFeature(
          "stream decode failed for object " +
          object.object_id.to_string() +
          " (" +
          context +
          "): " +
          err,
        ),
      )
  }
  let decoded = match
    decode_pdf_stream_filters_with_params(
      stream_bytes,
      filter_specs.0,
      filter_specs.1,
    ) {
    Ok(bytes) => Ok(bytes)
    Err(err) =>
      Err(
        PdfNativeError::UnsupportedFeature(
          "stream decode failed for object " +
          object.object_id.to_string() +
          " (" +
          context +
          "): " +
          err,
        ),
      )
  }
  decoded
}

///|
fn pdf_extract_image_candidates_from_stream(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  object_index : Map[Int, PdfNativeObject],
  resources_text : String?,
  content_text : String,
  base_matrix? : PdfNativeGraphicsMatrix = pdf_identity_matrix(),
  remaining_depth? : Int = 6,
) -> Array[PdfNativeImageCandidate] {
  if remaining_depth <= 0 {
    return []
  }
  let tokens = match pdf_scan_content_tokens(content_text) {
    Ok(parsed) => parsed
    Err(_) => return []
  }
  let candidates : Array[PdfNativeImageCandidate] = []
  let operands : Array[PdfNativeContentToken] = []
  let graphics_stack : Array[PdfNativeGraphicsMatrix] = []
  let mut current_matrix = base_matrix
  for token in tokens {
    match token {
      Word(op) =>
        match op {
          "q" => {
            graphics_stack.push(current_matrix)
            operands.clear()
          }
          "Q" => {
            current_matrix = graphics_stack.pop().unwrap_or(base_matrix)
            operands.clear()
          }
          "cm" => {
            if operands.length() >= 6 {
              current_matrix = pdf_concat_graphics_matrix(
                current_matrix,
                pdf_matrix_from_operands(operands),
              )
            }
            operands.clear()
          }
          "Do" => {
            if operands.length() >= 1 {
              match pdf_token_name(operands[operands.length() - 1]) {
                Some(xobject_name) =>
                  candidates.append(
                    pdf_image_candidates_from_xobject_name(
                      source, geometry, object_index, resources_text, xobject_name,
                      current_matrix, remaining_depth,
                    )[:],
                  )
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
  candidates
}

///|
fn pdf_image_candidates_from_xobject_name(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  object_index : Map[Int, PdfNativeObject],
  resources_text : String?,
  xobject_name : String,
  current_matrix : PdfNativeGraphicsMatrix,
  remaining_depth : Int,
) -> Array[PdfNativeImageCandidate] {
  let resolved = match
    pdf_lookup_xobject_object(resources_text, xobject_name, object_index) {
    Some(value) => value
    None => return []
  }
  let (object_id, xobject) = resolved
  match pdf_extract_name_after(xobject.dict_text, "/Subtype") {
    Some("Image") =>
      [
        pdf_image_candidate_from_xobject(
          source, geometry, xobject_name, object_id, xobject, object_index, current_matrix,
        ),
      ]
    Some("Form") =>
      match pdf_decode_stream_text(xobject, "form xobject stream") {
        Ok(form_text) =>
          pdf_extract_image_candidates_from_stream(
            source,
            geometry,
            object_index,
            pdf_extract_resources_text(xobject.dict_text, object_index),
            form_text,
            base_matrix=pdf_concat_graphics_matrix(
              current_matrix,
              pdf_form_graphics_matrix(xobject.dict_text),
            ),
            remaining_depth=remaining_depth - 1,
          )
        Err(_) => []
      }
    _ => []
  }
}

///|
fn pdf_lookup_xobject_object(
  resources_text : String?,
  xobject_name : String,
  object_index : Map[Int, PdfNativeObject],
) -> (Int, PdfNativeObject)? {
  let resources_text = match resources_text {
    Some(value) => value
    None => return None
  }
  let xobject_dict = match
    pdf_inline_or_referenced_dict_text(resources_text, "/XObject", object_index) {
    Some(value) => value
    None => return None
  }
  let entries = match pdf_parse_dict_entries(xobject_dict) {
    Some(value) => value
    None => return None
  }
  let target_key = "/" + xobject_name
  for entry in entries {
    if entry.0 != target_key {
      continue
    }
    match entry.1 {
      Reference(object_id, generation) => {
        ignore(generation)
        match object_index.get(object_id) {
          Some(object) => return Some((object_id, object))
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn pdf_image_candidate_from_xobject(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  xobject_name : String,
  object_id : Int,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  current_matrix : PdfNativeGraphicsMatrix,
) -> PdfNativeImageCandidate {
  let image_width = pdf_extract_int_after(object.dict_text, "/Width")
    .unwrap_or(1)
    .to_double()
  let image_height = pdf_extract_int_after(object.dict_text, "/Height")
    .unwrap_or(1)
    .to_double()
  let bbox = pdf_image_bbox_from_graphics_matrix(
    current_matrix, image_width, image_height,
  )
  let source_ref = pdf_source_ref_for_image_candidate(
    source,
    geometry.page_no,
    bbox,
    object_id,
    xobject_name,
  )
  let asset_ref = pdf_exportable_image_asset_ref(
    source,
    geometry.page_no,
    bbox,
    xobject_name,
    object_id,
    object,
    object_index,
  )
  if asset_ref is None {
    source_ref.extra.set(
      "pdf_image_filter_chain",
      pdf_image_filter_chain_label(pdf_extract_filter_names(object.dict_text)),
    )
    let color_space = pdf_resolve_image_color_space(object, object_index)
    source_ref.extra.set(
      "pdf_image_color_space",
      pdf_resolved_image_color_space_label(color_space),
    )
    source_ref.extra.set(
      "pdf_image_asset_reason",
      if color_space is None {
        "unsupported_or_unresolved_color_space"
      } else {
        "unsupported_pixel_layout_or_filter_payload"
      },
    )
  }
  make_pdf_native_image_candidate(bbox, source_ref=Some(source_ref), asset_ref~)
}

///|
fn pdf_source_ref_for_image_candidate(
  source : @input.InputSource,
  page_no : Int,
  bbox : PdfBBox,
  object_id : Int,
  xobject_name : String,
) -> @core.SourceRef {
  let base = pdf_native_source_ref(source, page_no, bbox, None, None, 0.0)
  let next = @core.source_ref_with_extra(
    base,
    "pdf_object_id",
    object_id.to_string(),
  )
  @core.source_ref_with_extra(next, "pdf_xobject_name", xobject_name)
}

///|
fn pdf_exportable_image_asset_ref(
  source : @input.InputSource,
  page_no : Int,
  bbox : PdfBBox,
  xobject_name : String,
  object_id : Int,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> @core.AssetRef? {
  let payload_info = match pdf_exportable_image_payload(object, object_index) {
    Some(value) => value
    None => return None
  }
  if payload_info.mime_type == "application/octet-stream" {
    return None
  }
  let source_ref = pdf_source_ref_for_image_candidate(
    source, page_no, bbox, object_id, xobject_name,
  )
  let asset = @core.make_asset_ref(
    Image,
    "pdf:" + object_id.to_string(),
    source_ref~,
  )
  let next_asset = { ..asset, mime_type: Some(payload_info.mime_type) }
  next_asset.attrs.set("alt", "image")
  next_asset.attrs.set("file_ext", payload_info.ext)
  next_asset.payload = Some(Bytes(payload_info.payload))
  next_asset.attrs.set("pdf_object_id", object_id.to_string())
  next_asset.attrs.set("pdf_xobject_name", xobject_name)
  next_asset.attrs.set("pdf_filter_chain", payload_info.filter_chain)
  next_asset.attrs.set("pdf_decode_mode", payload_info.decode_mode)
  match payload_info.source_encoding {
    Some(value) => next_asset.attrs.set("pdf_source_encoding", value)
    None => ()
  }
  match payload_info.globals_object_id {
    Some(value) =>
      next_asset.attrs.set("pdf_jbig2_globals_object_id", value.to_string())
    None => ()
  }
  Some(next_asset)
}

///|
priv struct PdfExportableImagePayload {
  payload : Bytes
  mime_type : String
  ext : String
  filter_chain : String
  decode_mode : String
  source_encoding : String?
  globals_object_id : Int?
}

///|
priv struct PdfCcittFaxParams {
  compression : Int
  width : Int
  height : Int
  photometric : Int
  encoded_byte_align : Bool
}

///|
fn pdf_exportable_image_payload(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> PdfExportableImagePayload? {
  let stream = match object.stream {
    Some(value) => value
    None => return None
  }
  if pdf_image_decode_budget_exceeded(object, object_index, stream) {
    return None
  }
  let filters = pdf_extract_filter_names(object.dict_text)
  let filter_chain = pdf_image_filter_chain_label(filters)
  let payload = pdf_stream_selected_bytes(stream)
  let filter_specs = pdf_extract_stream_filter_specs(object.dict_text)
  let params = match filter_specs {
    Ok(specs) => specs.1
    Err(_) => {
      let empty : Array[PdfStreamDecodeParams?] = []
      for _ in filters {
        empty.push(None)
      }
      empty
    }
  }
  if filters.length() == 0 {
    match pdf_detect_binary_image_payload(payload) {
      Some((mime_type, ext)) =>
        return Some({
          payload,
          mime_type,
          ext,
          filter_chain,
          decode_mode: "decoded_pixels",
          source_encoding: None,
          globals_object_id: None,
        })
      None =>
        match
          pdf_decoded_pixels_png_payload(
            object, payload, filter_chain, object_index,
          ) {
          Some(value) => return Some(value)
          None => return None
        }
    }
  }
  let terminal_filter = filters[filters.length() - 1]
  let prefix_decoded = match
    pdf_decode_image_prefix_filters_with_params(
      payload,
      filters,
      params,
      filters.length() - 1,
    ) {
    Ok(value) => Some(value)
    Err(_) => None
  }
  match terminal_filter {
    "DCTDecode" | "JPXDecode" =>
      match (pdf_passthrough_image_format(terminal_filter), prefix_decoded) {
        (Some((mime_type, ext)), Some(decoded)) =>
          return Some({
            payload: decoded,
            mime_type,
            ext,
            filter_chain,
            decode_mode: "container_passthrough",
            source_encoding: Some(terminal_filter),
            globals_object_id: None,
          })
        _ =>
          return Some(
            pdf_raw_preserved_image_payload(
              payload,
              filter_chain,
              terminal_filter,
              filters.length() == 1,
            ),
          )
      }
    "JBIG2Decode" => {
      let globals_object_id = match
        pdf_image_filter_param_dict_text_at(
          object.dict_text,
          filters.length(),
          filters.length() - 1,
        ) {
        Some(dict_text) =>
          pdf_extract_object_reference_after(dict_text, "/JBIG2Globals")
        None => None
      }
      match prefix_decoded {
        Some(decoded) =>
          return Some({
            payload: decoded,
            mime_type: "image/x-jbig2",
            ext: "jb2",
            filter_chain,
            decode_mode: "raw_preserved",
            source_encoding: Some("JBIG2Decode"),
            globals_object_id,
          })
        None =>
          return Some({
            ..pdf_raw_preserved_image_payload(
              payload,
              filter_chain,
              "JBIG2Decode",
              filters.length() == 1,
            ),
            globals_object_id,
          })
      }
    }
    "CCITTFaxDecode" =>
      match prefix_decoded {
        Some(decoded) =>
          match
            pdf_ccitt_fax_params_from_image_object(
              object,
              pdf_image_filter_param_dict_text_at(
                object.dict_text,
                filters.length(),
                filters.length() - 1,
              ),
            ) {
            Some(params) =>
              return Some({
                payload: pdf_wrap_ccitt_payload_as_tiff(decoded, params),
                mime_type: "image/tiff",
                ext: "tif",
                filter_chain,
                decode_mode: "container_passthrough",
                source_encoding: Some("CCITTFaxDecode"),
                globals_object_id: None,
              })
            None =>
              return Some(
                pdf_raw_preserved_image_payload(
                  payload,
                  filter_chain,
                  "CCITTFaxDecode",
                  filters.length() == 1,
                ),
              )
          }
        None =>
          return Some(
            pdf_raw_preserved_image_payload(
              payload,
              filter_chain,
              "CCITTFaxDecode",
              filters.length() == 1,
            ),
          )
      }
    _ => ()
  }
  if !pdf_filters_all_image_decode_safe(filters) {
    return Some(
      pdf_raw_preserved_image_payload(
        payload,
        filter_chain,
        terminal_filter,
        filters.length() == 1,
      ),
    )
  }
  let decoded = match
    pdf_decode_image_prefix_filters_with_params(
      payload,
      filters,
      params,
      filters.length(),
    ) {
    Ok(value) => value
    Err(_) =>
      return Some(
        pdf_raw_preserved_image_payload(
          payload,
          filter_chain,
          terminal_filter,
          filters.length() == 1,
        ),
      )
  }
  match pdf_detect_binary_image_payload(decoded) {
    Some((mime_type, ext)) =>
      Some({
        payload: decoded,
        mime_type,
        ext,
        filter_chain,
        decode_mode: "decoded_pixels",
        source_encoding: None,
        globals_object_id: None,
      })
    None =>
      match
        pdf_decoded_pixels_png_payload(
          object, decoded, filter_chain, object_index,
        ) {
        Some(value) => Some(value)
        None =>
          Some({
            payload: decoded,
            mime_type: "application/octet-stream",
            ext: "bin",
            filter_chain,
            decode_mode: "raw_preserved",
            source_encoding: Some(terminal_filter),
            globals_object_id: None,
          })
      }
  }
}

///|
const PDF_MAX_IMAGE_DECODE_WORKING_BYTES : Int64 = 64L * 1024L * 1024L

///|
fn pdf_image_decode_budget_exceeded(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  stream : PdfNativeStreamSlice,
) -> Bool {
  let source_bytes = pdf_stream_selected_bytes(stream).length().to_int64()
  if source_bytes > PDF_MAX_IMAGE_DECODE_WORKING_BYTES {
    return true
  }
  let width = pdf_extract_int_after(object.dict_text, "/Width").unwrap_or(0)
  let height = pdf_extract_int_after(object.dict_text, "/Height").unwrap_or(0)
  let bits = pdf_extract_int_after(object.dict_text, "/BitsPerComponent").unwrap_or(
    8,
  )
  if width <= 0 || height <= 0 || bits <= 0 || bits > 16 {
    return true
  }
  let components = match pdf_resolve_image_color_space(object, object_index) {
    Some(value) => pdf_resolved_image_color_components(value)
    None => return true
  }
  if components <= 0 || components > 4 {
    return true
  }
  let width64 = width.to_int64()
  let height64 = height.to_int64()
  if width64 > PDF_MAX_IMAGE_DECODE_WORKING_BYTES / height64 {
    return true
  }
  let pixels = width64 * height64
  let decoded_bits = pixels * components.to_int64() * bits.to_int64()
  let decoded_bytes = (decoded_bits + 7L) / 8L
  let normalized_channels = if object.dict_text.contains("/SMask") {
    4L
  } else if components == 1 {
    1L
  } else {
    3L
  }
  let normalized_bytes = pixels * normalized_channels
  decoded_bytes > PDF_MAX_IMAGE_DECODE_WORKING_BYTES ||
  normalized_bytes > PDF_MAX_IMAGE_DECODE_WORKING_BYTES
}

///|
fn pdf_decoded_pixels_png_payload(
  object : PdfNativeObject,
  decoded : Bytes,
  filter_chain : String,
  object_index : Map[Int, PdfNativeObject],
) -> PdfExportableImagePayload? {
  let width = pdf_extract_int_after(object.dict_text, "/Width").unwrap_or(0)
  let height = pdf_extract_int_after(object.dict_text, "/Height").unwrap_or(0)
  let bits = pdf_extract_int_after(object.dict_text, "/BitsPerComponent").unwrap_or(
    8,
  )
  let color_space = match pdf_resolve_image_color_space(object, object_index) {
    Some(value) => value
    None => return None
  }
  let (pixels, channels) = match color_space {
    Indexed(base, high, palette) => {
      let expanded = match
        pdf_expand_indexed_rgb_pixels(
          decoded, width, height, bits, base, high, palette,
        ) {
        Some(value) => value
        None => return None
      }
      (expanded, 3)
    }
    CMYK if bits == 8 => {
      let converted = match pdf_convert_cmyk_to_rgb(decoded, width, height) {
        Some(value) => value
        None => return None
      }
      (converted, 3)
    }
    Gray =>
      if bits == 1 {
        let invert = object.dict_text.contains("/Decode [ 1 0 ]") ||
          object.dict_text.contains("/Decode [1 0]")
        let expanded = match
          pdf_expand_1bit_grayscale(decoded, width, height, invert) {
          Some(value) => value
          None => return None
        }
        (expanded, 1)
      } else if bits == 8 {
        (decoded, 1)
      } else {
        return None
      }
    RGB if bits == 8 => (decoded, 3)
    _ => return None
  }
  let alpha = match
    pdf_image_soft_mask_alpha(object, object_index, width, height) {
    Some(value) => Some(value)
    None => pdf_image_color_key_alpha(object, pixels, width, height, channels)
  }
  let (png_pixels, png_channels) = match alpha {
    Some(alpha) => {
      let rgba : Array[Byte] = []
      for pixel in 0..<(width * height) {
        if channels == 1 {
          let gray = pixels[pixel]
          rgba.push(gray)
          rgba.push(gray)
          rgba.push(gray)
          rgba.push(alpha[pixel])
        } else {
          let offset = pixel * 3
          rgba.push(pixels[offset])
          rgba.push(pixels[offset + 1])
          rgba.push(pixels[offset + 2])
          rgba.push(alpha[pixel])
        }
      }
      (Bytes::from_array(rgba), 4)
    }
    None => (pixels, channels)
  }
  match pdf_encode_png_8bit(png_pixels, width, height, png_channels) {
    Some(payload) =>
      Some({
        payload,
        mime_type: "image/png",
        ext: "png",
        filter_chain,
        decode_mode: "normalized_png",
        source_encoding: None,
        globals_object_id: None,
      })
    None => None
  }
}

///|
fn pdf_convert_cmyk_to_rgb(
  decoded : Bytes,
  width : Int,
  height : Int,
) -> Bytes? {
  if width <= 0 ||
    height <= 0 ||
    width > PDF_PNG_MAX_PIXELS / height ||
    decoded.length() != width * height * 4 {
    return None
  }
  let rgb : Array[Byte] = []
  for pixel in 0..<(width * height) {
    let offset = pixel * 4
    let c = decoded[offset].to_int()
    let m = decoded[offset + 1].to_int()
    let y = decoded[offset + 2].to_int()
    let k = decoded[offset + 3].to_int()
    rgb.push((255 - pdf_min_int(255, c + k)).to_byte())
    rgb.push((255 - pdf_min_int(255, m + k)).to_byte())
    rgb.push((255 - pdf_min_int(255, y + k)).to_byte())
  }
  Some(Bytes::from_array(rgb))
}

///|
fn pdf_expand_indexed_rgb_pixels(
  decoded : Bytes,
  width : Int,
  height : Int,
  bits : Int,
  base : PdfResolvedImageColorSpace,
  high : Int,
  palette : Bytes,
) -> Bytes? {
  if bits != 1 && bits != 2 && bits != 4 && bits != 8 {
    return None
  }
  let components = pdf_resolved_image_color_components(base)
  if high < 0 ||
    high > 255 ||
    components <= 0 ||
    palette.length() < (high + 1) * components ||
    width <= 0 ||
    height <= 0 ||
    width > PDF_PNG_MAX_PIXELS / height {
    return None
  }
  let row_bytes = (width * bits + 7) / 8
  if decoded.length() < row_bytes * height {
    return None
  }
  let rgb : Array[Byte] = []
  let mask = (1 << bits) - 1
  for row in 0..<height {
    for column in 0..<width {
      let bit_offset = column * bits
      let byte = decoded[row * row_bytes + bit_offset / 8].to_int()
      let shift = 8 - bits - bit_offset % 8
      let index = (byte >> shift) & mask
      if index > high {
        return None
      }
      let palette_offset = index * components
      match base {
        Gray => {
          let gray = palette[palette_offset]
          rgb.push(gray)
          rgb.push(gray)
          rgb.push(gray)
        }
        RGB => {
          rgb.push(palette[palette_offset])
          rgb.push(palette[palette_offset + 1])
          rgb.push(palette[palette_offset + 2])
        }
        CMYK => {
          let c = palette[palette_offset].to_int()
          let m = palette[palette_offset + 1].to_int()
          let y = palette[palette_offset + 2].to_int()
          let k = palette[palette_offset + 3].to_int()
          rgb.push((255 - pdf_min_int(255, c + k)).to_byte())
          rgb.push((255 - pdf_min_int(255, m + k)).to_byte())
          rgb.push((255 - pdf_min_int(255, y + k)).to_byte())
        }
        Indexed(_, _, _) => return None
      }
    }
  }
  Some(Bytes::from_array(rgb))
}

///|
fn pdf_min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn pdf_image_color_key_alpha(
  object : PdfNativeObject,
  pixels : Bytes,
  width : Int,
  height : Int,
  channels : Int,
) -> Bytes? {
  let ranges = pdf_extract_int_array_after(object.dict_text, "/Mask")
  if (channels != 1 && channels != 3) || ranges.length() != channels * 2 {
    return None
  }
  let alpha : Array[Byte] = []
  for pixel in 0..<(width * height) {
    let mut transparent = true
    for channel in 0..<channels {
      let value = pixels[pixel * channels + channel].to_int()
      if value < ranges[channel * 2] || value > ranges[channel * 2 + 1] {
        transparent = false
      }
    }
    alpha.push(if transparent { (0).to_byte() } else { (255).to_byte() })
  }
  Some(Bytes::from_array(alpha))
}

///|
fn pdf_image_soft_mask_alpha(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  width : Int,
  height : Int,
) -> Bytes? {
  let mask_id = match
    pdf_extract_object_reference_after(object.dict_text, "/SMask") {
    Some(value) => value
    None => return None
  }
  let mask = match object_index.get(mask_id) {
    Some(value) => value
    None => return None
  }
  if pdf_extract_int_after(mask.dict_text, "/Width") != Some(width) ||
    pdf_extract_int_after(mask.dict_text, "/Height") != Some(height) {
    return None
  }
  match pdf_resolve_image_color_space(mask, object_index) {
    Some(Gray) => ()
    _ => return None
  }
  let decoded = match pdf_decode_stream_bytes(mask, "soft mask image") {
    Ok(value) => value
    Err(_) => return None
  }
  let bits = pdf_extract_int_after(mask.dict_text, "/BitsPerComponent").unwrap_or(
    8,
  )
  if bits == 8 && decoded.length() == width * height {
    Some(decoded)
  } else if bits == 1 {
    let invert = mask.dict_text.contains("/Decode [ 1 0 ]") ||
      mask.dict_text.contains("/Decode [1 0]")
    pdf_expand_1bit_grayscale(decoded, width, height, invert)
  } else {
    None
  }
}

///|
fn pdf_passthrough_image_format(filter_name : String) -> (String, String)? {
  match filter_name {
    "DCTDecode" => Some(("image/jpeg", "jpg"))
    "JPXDecode" => Some(("image/jp2", "jp2"))
    _ => None
  }
}

///|
fn pdf_image_filter_chain_label(filters : Array[String]) -> String {
  if filters.length() == 0 {
    "none"
  } else {
    filters.join(",")
  }
}

///|
fn pdf_raw_preserved_image_payload(
  payload : Bytes,
  filter_chain : String,
  terminal_filter : String,
  filter_chain_passthrough_safe : Bool,
) -> PdfExportableImagePayload {
  match
    (
      filter_chain_passthrough_safe,
      pdf_passthrough_image_format(terminal_filter),
    ) {
    (true, Some((mime_type, ext))) =>
      {
        payload,
        mime_type,
        ext,
        filter_chain,
        decode_mode: "raw_preserved",
        source_encoding: Some(terminal_filter),
        globals_object_id: None,
      }
    _ =>
      {
        payload,
        mime_type: if terminal_filter == "JBIG2Decode" {
          "image/x-jbig2"
        } else {
          "application/octet-stream"
        },
        ext: if terminal_filter == "JBIG2Decode" {
          "jb2"
        } else {
          "bin"
        },
        filter_chain,
        decode_mode: "raw_preserved",
        source_encoding: Some(terminal_filter),
        globals_object_id: None,
      }
  }
}

///|
fn pdf_filters_all_image_decode_safe(filters : Array[String]) -> Bool {
  for filter_name in filters {
    if !pdf_image_filter_is_decode_safe(filter_name) {
      return false
    }
  }
  true
}

///|
fn pdf_image_filter_is_decode_safe(filter_name : String) -> Bool {
  match filter_name {
    "FlateDecode" => true
    "ASCIIHexDecode" => true
    "ASCII85Decode" => true
    "RunLengthDecode" => true
    "LZWDecode" => true
    _ => false
  }
}
