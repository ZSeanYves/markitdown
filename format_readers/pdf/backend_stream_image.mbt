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
        PdfNativeError::ParseFailed(
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
      PdfNativeContentToken::Word(op) =>
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
      PdfNativeDictValue::Reference(object_id, generation) => {
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
    @core.AssetKind::Image,
    "pdf:" + object_id.to_string(),
    source_ref~,
  )
  let next_asset = { ..asset, mime_type: Some(payload_info.mime_type) }
  next_asset.attrs.set("alt", "image")
  next_asset.attrs.set("file_ext", payload_info.ext)
  next_asset.payload = Some(@core.AssetPayload::Bytes(payload_info.payload))
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
    PdfResolvedImageColorSpace::Indexed(base, high, palette) => {
      let expanded = match
        pdf_expand_indexed_rgb_pixels(
          decoded, width, height, bits, base, high, palette,
        ) {
        Some(value) => value
        None => return None
      }
      (expanded, 3)
    }
    PdfResolvedImageColorSpace::CMYK if bits == 8 => {
      let converted = match pdf_convert_cmyk_to_rgb(decoded, width, height) {
        Some(value) => value
        None => return None
      }
      (converted, 3)
    }
    PdfResolvedImageColorSpace::Gray =>
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
    PdfResolvedImageColorSpace::RGB if bits == 8 => (decoded, 3)
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
        PdfResolvedImageColorSpace::Gray => {
          let gray = palette[palette_offset]
          rgb.push(gray)
          rgb.push(gray)
          rgb.push(gray)
        }
        PdfResolvedImageColorSpace::RGB => {
          rgb.push(palette[palette_offset])
          rgb.push(palette[palette_offset + 1])
          rgb.push(palette[palette_offset + 2])
        }
        PdfResolvedImageColorSpace::CMYK => {
          let c = palette[palette_offset].to_int()
          let m = palette[palette_offset + 1].to_int()
          let y = palette[palette_offset + 2].to_int()
          let k = palette[palette_offset + 3].to_int()
          rgb.push((255 - pdf_min_int(255, c + k)).to_byte())
          rgb.push((255 - pdf_min_int(255, m + k)).to_byte())
          rgb.push((255 - pdf_min_int(255, y + k)).to_byte())
        }
        PdfResolvedImageColorSpace::Indexed(_, _, _) => return None
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
    Some(PdfResolvedImageColorSpace::Gray) => ()
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
