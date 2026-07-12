///|
fn pdf_empty_tounicode_cmap_info() -> PdfToUnicodeCMapInfo {
  {
    mapping: Map([]),
    invalid_keys: Map([]),
    widths: [],
    usecmap_name: None,
    builtin_parent_name: None,
  }
}

///|
fn pdf_merge_desc_widths(left : Array[Int], right : Array[Int]) -> Array[Int] {
  let merged : Map[Int, Bool] = Map([])
  for width in left {
    if width > 0 {
      merged.set(width, true)
    }
  }
  for width in right {
    if width > 0 {
      merged.set(width, true)
    }
  }
  pdf_sort_desc_widths(merged)
}

///|
fn pdf_collect_font_encoding_info(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> PdfNativeFontEncodingInfo {
  let base_font = pdf_extract_name_after(object.dict_text, "/BaseFont")
  let subtype = pdf_extract_name_after(object.dict_text, "/Subtype")
  let default_encoding_name = pdf_font_default_encoding_name(base_font, subtype)
  match pdf_extract_dict_value(object.dict_text, "/Encoding") {
    Some(value) =>
      pdf_font_encoding_info_from_value(
        value, object_index, default_encoding_name,
      )
    None =>
      match default_encoding_name {
        Some(name) => pdf_font_encoding_info_from_dict(None, Some(name))
        None =>
          { encoding_name: None, code_hex_widths: [], unicode_map: Map([]) }
      }
  }
}

///|
fn pdf_font_encoding_info_from_value(
  value : PdfNativeDictValue,
  object_index : Map[Int, PdfNativeObject],
  default_encoding_name : String?,
) -> PdfNativeFontEncodingInfo {
  match value {
    PdfNativeDictValue::Name(name) =>
      pdf_font_encoding_info_from_dict(None, Some(name))
    PdfNativeDictValue::Dict(dict_text) =>
      pdf_font_encoding_info_from_dict(Some(dict_text), default_encoding_name)
    PdfNativeDictValue::Reference(object_id, generation) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) => {
          let dict_text = if object.dict_text.contains("<<") {
            Some(object.dict_text)
          } else {
            None
          }
          pdf_font_encoding_info_from_dict(dict_text, default_encoding_name)
        }
        None =>
          match default_encoding_name {
            Some(name) => pdf_font_encoding_info_from_dict(None, Some(name))
            None =>
              { encoding_name: None, code_hex_widths: [], unicode_map: Map([]) }
          }
      }
    }
    _ =>
      match default_encoding_name {
        Some(name) => pdf_font_encoding_info_from_dict(None, Some(name))
        None =>
          { encoding_name: None, code_hex_widths: [], unicode_map: Map([]) }
      }
  }
}

///|
fn pdf_font_encoding_info_from_dict(
  dict_text : String?,
  default_encoding_name : String?,
) -> PdfNativeFontEncodingInfo {
  let base_encoding_name = match dict_text {
    Some(text) =>
      match pdf_extract_name_after(text, "/BaseEncoding") {
        Some(name) => Some(name)
        None => default_encoding_name
      }
    None => default_encoding_name
  }
  let glyph_names = match base_encoding_name {
    Some(name) => pdf_font_base_encoding_code_to_glyph_map(name)
    None => Map([])
  }
  match dict_text {
    Some(text) =>
      match pdf_extract_dict_value(text, "/Differences") {
        Some(PdfNativeDictValue::Array(tokens)) =>
          pdf_apply_font_encoding_differences(glyph_names, tokens)
        _ => ()
      }
    None => ()
  }
  let unicode_map : Map[String, String] = Map([])
  for entry in glyph_names.to_array() {
    match pdf_font_glyph_name_to_unicode(entry.1) {
      Some(text) if pdf_is_usable_tounicode_text(text) =>
        unicode_map.set(pdf_hex_upper(entry.0, 2), text)
      _ => ()
    }
  }
  {
    encoding_name: base_encoding_name,
    code_hex_widths: if unicode_map.length() > 0 {
      [1]
    } else {
      []
    },
    unicode_map,
  }
}

///|
fn pdf_apply_font_encoding_differences(
  glyph_names : Map[Int, String],
  tokens : Array[PdfNativeContentToken],
) -> Unit {
  let mut current_code : Int? = None
  for token in tokens {
    match token {
      PdfNativeContentToken::Number(value) =>
        if pdf_double_is_integral(value) {
          current_code = Some(value.to_int())
        }
      PdfNativeContentToken::Name(name) =>
        match current_code {
          Some(code) => {
            glyph_names.set(code, name)
            current_code = Some(code + 1)
          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn pdf_font_default_encoding_name(
  base_font : String?,
  subtype : String?,
) -> String? {
  let normalized = pdf_normalized_pdf_font_name(base_font)
  match normalized {
    Some(name) if name.contains("zapfdingbats") => Some("ZapfDingbats")
    Some(name) if name.contains("symbol") => Some("Symbol")
    _ =>
      match subtype {
        Some("Type0") => None
        Some("CIDFontType0") => None
        Some("CIDFontType2") => None
        Some("Type1") => Some("StandardEncoding")
        Some("MMType1") => Some("StandardEncoding")
        Some("TrueType") => Some("WinAnsiEncoding")
        Some("Type3") => Some("StandardEncoding")
        _ => Some("StandardEncoding")
      }
  }
}

///|
fn pdf_find_cmap_object_id_by_name(
  object_index : Map[Int, PdfNativeObject],
  cmap_name : String,
) -> Int? {
  for entry in object_index.to_array() {
    match pdf_extract_name_after(entry.1.dict_text, "/CMapName") {
      Some(name) if name == cmap_name => return Some(entry.0)
      _ => ()
    }
  }
  None
}

///|
fn pdf_parent_tounicode_cmap_info(
  cmap_object : PdfNativeObject,
  local_usecmap_name : String?,
  object_index : Map[Int, PdfNativeObject],
  visited : Map[Int, Bool],
  remaining_depth : Int,
) -> PdfToUnicodeCMapInfo {
  if remaining_depth <= 0 {
    return pdf_empty_tounicode_cmap_info()
  }
  match pdf_extract_dict_value(cmap_object.dict_text, "/UseCMap") {
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      match
        pdf_collect_tounicode_cmap_info(
          object_id,
          object_index,
          visited,
          remaining_depth - 1,
        ) {
        Ok(info) => info
        Err(_) => pdf_empty_tounicode_cmap_info()
      }
    }
    Some(PdfNativeDictValue::Name(name)) =>
      match pdf_find_cmap_object_id_by_name(object_index, name) {
        Some(object_id) =>
          match
            pdf_collect_tounicode_cmap_info(
              object_id,
              object_index,
              visited,
              remaining_depth - 1,
            ) {
            Ok(info) => info
            Err(_) => pdf_empty_tounicode_cmap_info()
          }
        None =>
          match pdf_predefined_cmap_tounicode_info(name) {
            Some(info) => info
            None => pdf_empty_tounicode_cmap_info()
          }
      }
    _ =>
      match local_usecmap_name {
        Some(name) =>
          match pdf_find_cmap_object_id_by_name(object_index, name) {
            Some(object_id) =>
              match
                pdf_collect_tounicode_cmap_info(
                  object_id,
                  object_index,
                  visited,
                  remaining_depth - 1,
                ) {
                Ok(info) => info
                Err(_) => pdf_empty_tounicode_cmap_info()
              }
            None =>
              match pdf_predefined_cmap_tounicode_info(name) {
                Some(info) => info
                None => pdf_empty_tounicode_cmap_info()
              }
          }
        None => pdf_empty_tounicode_cmap_info()
      }
  }
}

///|
fn pdf_collect_tounicode_cmap_info(
  cmap_object_id : Int,
  object_index : Map[Int, PdfNativeObject],
  visited : Map[Int, Bool],
  remaining_depth : Int,
) -> Result[PdfToUnicodeCMapInfo, String] {
  if remaining_depth <= 0 {
    return Ok(pdf_empty_tounicode_cmap_info())
  }
  if visited.get(cmap_object_id).unwrap_or(false) {
    return Ok(pdf_empty_tounicode_cmap_info())
  }
  visited.set(cmap_object_id, true)
  let cmap_object = match object_index.get(cmap_object_id) {
    Some(value) => value
    None => return Err("missing ToUnicode CMap object")
  }
  let cmap_text = match pdf_decode_cmap_stream_text(cmap_object) {
    Ok(result) => {
      ignore(pdf_cmap_stream_decode_result_summary(result))
      result.text
    }
    Err(failure) => {
      ignore(pdf_cmap_stream_decode_failure_summary(failure))
      return Err(failure.message)
    }
  }
  let cmap_info = if cmap_text == "" {
    pdf_empty_tounicode_cmap_info()
  } else {
    pdf_parse_tounicode_cmap_info(cmap_text)
  }
  let parent = pdf_parent_tounicode_cmap_info(
    cmap_object,
    cmap_info.usecmap_name,
    object_index,
    visited,
    remaining_depth,
  )
  let mapping : Map[String, String] = Map([])
  let invalid_keys : Map[String, Bool] = Map([])
  for entry in parent.mapping.to_array() {
    mapping.set(entry.0, entry.1)
  }
  for entry in parent.invalid_keys.to_array() {
    invalid_keys.set(entry.0, entry.1)
  }
  for entry in cmap_info.mapping.to_array() {
    mapping.set(entry.0, entry.1)
  }
  for entry in cmap_info.invalid_keys.to_array() {
    invalid_keys.set(entry.0, entry.1)
  }
  for entry in mapping.to_array() {
    invalid_keys.set(entry.0, false)
  }
  Ok({
    mapping,
    invalid_keys,
    widths: if cmap_info.widths.length() > 0 {
      pdf_merge_desc_widths(cmap_info.widths, parent.widths)
    } else {
      parent.widths
    },
    usecmap_name: cmap_info.usecmap_name,
    builtin_parent_name: match cmap_info.builtin_parent_name {
      Some(value) => Some(value)
      None => parent.builtin_parent_name
    },
  })
}

///|
fn pdf_collect_font_infos(
  object_index : Map[Int, PdfNativeObject],
) -> Result[PdfFontRegistry, PdfNativeError] {
  let fonts : Map[Int, PdfNativeFontInfo] = Map([])
  let inline_ids : Map[String, Int] = Map([])
  let mut next_inline_id = -1
  for entry in object_index.to_array() {
    let object = entry.1
    if !pdf_object_is_font(object) {
      continue
    }
    match pdf_register_font_info(fonts, object, object_index) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  for entry in object_index.to_array() {
    let candidate_texts : Array[String?] = [Some(entry.1.dict_text)]
    let resources_text = pdf_extract_resources_text(
      entry.1.dict_text,
      object_index,
    )
    if resources_text is Some(_) {
      candidate_texts.push(resources_text)
    }
    for candidate_text in candidate_texts {
      match pdf_font_resource_dict_text(candidate_text, object_index) {
        Some(font_dict_text) =>
          match pdf_parse_dict_entries(font_dict_text) {
            Some(dict_entries) =>
              for dict_entry in dict_entries {
                match dict_entry.1 {
                  PdfNativeDictValue::Dict(inline_font_dict) =>
                    if inline_ids.get(inline_font_dict) == None {
                      inline_ids.set(inline_font_dict, next_inline_id)
                      match
                        pdf_register_font_info(
                          fonts,
                          {
                            object_id: next_inline_id,
                            dict_text: inline_font_dict,
                            stream: None,
                          },
                          object_index,
                        ) {
                        Ok(_) => ()
                        Err(err) => return Err(err)
                      }
                      next_inline_id -= 1
                    }
                  _ => ()
                }
              }
            None => ()
          }
        None => ()
      }
    }
  }
  Ok({ infos: fonts, inline_ids })
}

///|
fn pdf_register_font_info(
  fonts : Map[Int, PdfNativeFontInfo],
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> Result[Unit, PdfNativeError] {
  if fonts.get(object.object_id) is Some(_) {
    return Ok(())
  }
  let descendant_object = pdf_primary_descendant_font_object(
    object, object_index,
  )
  let leaf_object = match descendant_object {
    Some(value) => value
    None => object
  }
  let encoding_info = pdf_collect_font_encoding_info(object, object_index)
  let to_unicode_ref = pdf_extract_object_reference_after(
    object.dict_text,
    "/ToUnicode",
  )
  let mut tounicode_decode_failed = false
  let unicode_info = match to_unicode_ref {
    Some(ref_id) => {
      let visited : Map[Int, Bool] = Map([])
      match pdf_collect_tounicode_cmap_info(ref_id, object_index, visited, 8) {
        Ok(value) => value
        Err(_) => {
          tounicode_decode_failed = true
          pdf_empty_tounicode_cmap_info()
        }
      }
    }
    None => pdf_empty_tounicode_cmap_info()
  }
  let predefined_cmap = match encoding_info.encoding_name {
    Some(name) => pdf_resolve_predefined_cmap(name)
    None => None
  }
  let cid_collection_cmap = pdf_font_cid_collection_cmap(
    encoding_info.encoding_name,
    leaf_object.dict_text,
  )
  let unicode_map : Map[String, String] = Map([])
  for entry in encoding_info.unicode_map.to_array() {
    unicode_map.set(entry.0, entry.1)
  }
  for entry in unicode_info.mapping.to_array() {
    unicode_map.set(entry.0, entry.1)
  }
  let code_hex_widths = pdf_font_combined_code_width_hints(
    encoding_info.code_hex_widths,
    unicode_info.widths,
    predefined_cmap,
  )
  let embedded_font_program = pdf_extract_embedded_font_program(
    leaf_object.dict_text,
    object_index,
  )
  let cid_to_gid_map = pdf_extract_cid_to_gid_map(
    leaf_object.dict_text,
    object_index,
  )
  fonts.set(object.object_id, {
    base_font: pdf_extract_name_after(object.dict_text, "/BaseFont"),
    normalized_base_font: pdf_normalized_pdf_font_name(
      pdf_extract_name_after(object.dict_text, "/BaseFont"),
    ),
    descendant_subtype: if descendant_object is Some(_) {
      pdf_extract_name_after(leaf_object.dict_text, "/Subtype")
    } else {
      None
    },
    encoding_name: encoding_info.encoding_name,
    code_hex_widths,
    unicode_map,
    tounicode_invalid_keys: unicode_info.invalid_keys,
    has_tounicode: to_unicode_ref is Some(_) && !tounicode_decode_failed,
    tounicode_decode_failed,
    tounicode_builtin_name: unicode_info.builtin_parent_name,
    predefined_cmap,
    cid_collection_cmap,
    embedded_font_program,
    cid_to_gid_map,
    simple_widths: pdf_collect_simple_font_widths(object.dict_text),
    simple_default_width: pdf_collect_font_missing_width(
      leaf_object.dict_text,
      object_index,
    ),
    cid_width_pairs: pdf_collect_cid_font_width_pairs(leaf_object.dict_text),
    cid_default_width: pdf_collect_cid_default_width(leaf_object.dict_text),
    cid_vertical_width_pairs: pdf_collect_cid_vertical_width_pairs(
      leaf_object.dict_text,
    ),
    cid_default_vertical_width: pdf_collect_cid_default_vertical_width(
      leaf_object.dict_text,
    ),
  })
  Ok(())
}

///|
fn pdf_primary_descendant_font_object(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> PdfNativeObject? {
  if pdf_extract_name_after(object.dict_text, "/Subtype") != Some("Type0") {
    return None
  }
  match
    pdf_extract_object_references_after(object.dict_text, "/DescendantFonts") {
    [first, ..] => object_index.get(first)
    _ => None
  }
}

///|
fn pdf_font_cid_collection_cmap(
  encoding_name : String?,
  cid_font_dict_text : String,
) -> PdfResolvedPredefinedCMap? {
  if encoding_name != Some("Identity-H") && encoding_name != Some("Identity-V") {
    return None
  }
  let cid_system_info = match
    pdf_extract_inline_dict_after(cid_font_dict_text, "/CIDSystemInfo") {
    Some(value) => value
    None => return None
  }
  if pdf_extract_string_after(cid_system_info, "/Registry") != Some("Adobe") {
    return None
  }
  let family = match pdf_extract_string_after(cid_system_info, "/Ordering") {
    Some("GB1") => "Adobe-GB1"
    Some("Japan1") => "Adobe-Japan1"
    Some("CNS1") => "Adobe-CNS1"
    Some("Korea1") => "Adobe-Korea1"
    _ => return None
  }
  pdf_predefined_direct_cid_family(family, encoding_name == Some("Identity-V"))
}

///|
fn pdf_font_combined_code_width_hints(
  encoding_widths : Array[Int],
  tounicode_widths : Array[Int],
  predefined_cmap : PdfResolvedPredefinedCMap?,
) -> Array[Int] {
  let widths : Map[Int, Bool] = Map([])
  for width in encoding_widths {
    if width > 0 {
      widths.set(width, true)
    }
  }
  for width in tounicode_widths {
    if width > 0 {
      widths.set(width, true)
    }
  }
  match predefined_cmap {
    Some(cmap) =>
      for width in pdf_predefined_code_widths_from_mask(cmap.code_width_mask) {
        if width > 0 {
          widths.set(width, true)
        }
      }
    None => ()
  }
  pdf_sort_desc_widths(widths)
}

///|
fn pdf_build_native_pages(
  source : @input.InputSource,
  page_object_ids : Array[Int],
  object_index : Map[Int, PdfNativeObject],
  fonts : Map[Int, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int],
  page_numbers : Map[Int, Int],
) -> Result[Array[PdfNativePage], PdfNativeError] {
  let pages : Array[PdfNativePage] = []
  for page_object_id in page_object_ids {
    let object = match object_index.get(page_object_id) {
      Some(value) => value
      None =>
        return Err(
          PdfNativeError::ParseFailed(
            "page tree references missing page object " +
            page_object_id.to_string(),
          ),
        )
    }
    let page_no = page_numbers.get(page_object_id).unwrap_or(pages.length() + 1)
    let geometry = pdf_page_geometry(object, object_index, page_no)
    let resources_text = pdf_extract_resources_text(
      object.dict_text,
      object_index,
    )
    let font_aliases = pdf_font_aliases_from_resources_text(
      resources_text, object_index, inline_font_ids,
    )
    let content_refs = pdf_extract_object_references_after(
      object.dict_text,
      "/Contents",
    )
    let fragments : Array[PdfNativeTextFragment] = []
    let image_candidates : Array[PdfNativeImageCandidate] = []
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
          source,
          geometry,
          font_aliases,
          fonts,
          inline_font_ids,
          content_text,
          object_index~,
          resources_text~,
        ) {
        Ok(parsed) => parsed
        Err(err) => return Err(err)
      }
      fragments.append(page_fragments[:])
      image_candidates.append(
        pdf_extract_image_candidates_from_stream(
          source, geometry, object_index, resources_text, content_text,
        )[:],
      )
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
    diagnostics.metrics.set(
      "image_count",
      image_candidates.length().to_string(),
    )
    diagnostics.metrics.set(
      "asset_count",
      pdf_native_exportable_image_asset_count(image_candidates).to_string(),
    )
    pages.push(
      make_pdf_native_page(
        geometry,
        text_blocks~,
        image_candidates~,
        link_candidates~,
        annotations~,
        destinations~,
        diagnostics~,
      ),
    )
  }
  Ok(pages)
}

///|
