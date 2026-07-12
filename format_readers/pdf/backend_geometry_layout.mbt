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
fn pdf_parse_tounicode_cmap_info(cmap_text : String) -> PdfToUnicodeCMapInfo {
  let mapping : Map[String, String] = Map([])
  let invalid_keys : Map[String, Bool] = Map([])
  let widths : Map[Int, Bool] = Map([])
  let tokens = match pdf_scan_content_tokens(cmap_text) {
    Ok(value) => value
    Err(_) =>
      return {
        mapping,
        invalid_keys,
        widths: [2],
        usecmap_name: None,
        builtin_parent_name: None,
      }
  }
  let mut in_codespacerange = false
  let mut in_bfchar = false
  let mut in_bfrange = false
  let mut usecmap_name : String? = None
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
      PdfNativeContentToken::Name(name) =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            PdfNativeContentToken::Word("usecmap") => {
              usecmap_name = Some(name)
              index += 1
            }
            _ => ()
          }
        }
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
              } else if src != "" {
                invalid_keys.set(src.to_upper(), true)
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
                invalid_keys,
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
                invalid_keys,
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
  for entry in mapping.to_array() {
    invalid_keys.set(entry.0, false)
  }
  {
    mapping,
    invalid_keys,
    widths: if sorted_widths.length() == 0 {
      [2]
    } else {
      sorted_widths
    },
    usecmap_name,
    builtin_parent_name: None,
  }
}

///|
fn pdf_apply_tounicode_bfrange(
  mapping : Map[String, String],
  invalid_keys : Map[String, Bool],
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
                } else {
                  invalid_keys.set(
                    pdf_hex_upper(cursor, start_hex.length()),
                    true,
                  )
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
                let codepoint = base_cp + offset
                if codepoint > 0x10FFFF ||
                  pdf_codepoint_is_noncharacter(codepoint) {
                  invalid_keys.set(key, true)
                } else {
                  let value = String::from_array([
                    Int::unsafe_to_char(codepoint),
                  ])
                  mapping.set(key, value)
                }
              }
            None =>
              for offset in 0..<(end_code - start_code + 1) {
                invalid_keys.set(
                  pdf_hex_upper(start_code + offset, start_hex.length()),
                  true,
                )
              }
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
fn pdf_font_aliases_from_resources_text(
  resources_text : String?,
  object_index : Map[Int, PdfNativeObject],
  inline_font_ids : Map[String, Int],
) -> Map[String, Int] {
  let aliases : Map[String, Int] = Map([])
  let font_dict_text = match
    pdf_font_resource_dict_text(resources_text, object_index) {
    Some(text) => text
    None => return aliases
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
          PdfNativeDictValue::Dict(inline_font_dict) =>
            match inline_font_ids.get(inline_font_dict) {
              Some(object_id) =>
                if entry.0.has_prefix("/") && entry.0.length() > 1 {
                  aliases.set(entry.0[1:].to_owned(), object_id)
                }
              None => ()
            }
          _ => ()
        }
      }
    None => ()
  }
  aliases
}

///|
fn pdf_font_resource_dict_text(
  resources_text : String?,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  let resources_text = match resources_text {
    Some(text) => text
    None => return None
  }
  match pdf_extract_inline_dict_after(resources_text, "/Font") {
    Some(text) => Some(text)
    None =>
      match pdf_extract_object_reference_after(resources_text, "/Font") {
        Some(font_ref) =>
          match object_index.get(font_ref) {
            Some(font_object) => Some(font_object.dict_text)
            None => None
          }
        None => None
      }
  }
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
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
) -> Map[String, @core.JsonValue]? {
  let info_ref = match
    pdf_lookup_trailer_object_reference(trailer_hints, "/Info") {
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
fn pdf_ordered_page_object_ids(
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
  objects : Array[PdfNativeObject],
) -> Array[Int] {
  let catalog = match pdf_catalog_object(trailer_hints, object_index) {
    Some(value) => value
    None => return pdf_page_object_ids(objects)
  }
  let pages_ref = match
    pdf_extract_object_reference_after(catalog.dict_text, "/Pages") {
    Some(value) => value
    None => return pdf_page_object_ids(objects)
  }
  let ordered = pdf_collect_page_tree_ids(object_index, pages_ref, Map([]), 0)
  if ordered.length() > 0 {
    ordered
  } else {
    pdf_page_object_ids(objects)
  }
}

///|
fn pdf_collect_page_tree_ids(
  object_index : Map[Int, PdfNativeObject],
  object_id : Int,
  visited : Map[Int, Bool],
  depth : Int,
) -> Array[Int] {
  if depth >= 256 || visited.get(object_id).unwrap_or(false) {
    return []
  }
  visited.set(object_id, true)
  let object = match object_index.get(object_id) {
    Some(value) => value
    None => return []
  }
  if pdf_object_is_page(object) {
    return [object_id]
  }
  if !pdf_object_is_pages_node(object) {
    return []
  }
  let ordered : Array[Int] = []
  for
    kid_id in pdf_extract_resolved_object_references_after(
      object.dict_text,
      "/Kids",
      object_index,
    ) {
    ordered.append(
      pdf_collect_page_tree_ids(object_index, kid_id, visited, depth + 1)[:],
    )
  }
  ordered
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
fn pdf_lookup_trailer_object_reference(
  trailer_hints : Array[String],
  key : String,
) -> Int? {
  for trailer in trailer_hints {
    match pdf_extract_object_reference_after(trailer, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn pdf_catalog_object(
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
) -> PdfNativeObject? {
  let root_ref = match
    pdf_lookup_trailer_object_reference(trailer_hints, "/Root") {
    Some(value) => value
    None => return pdf_catalog_object_fallback(object_index)
  }
  match object_index.get(root_ref) {
    Some(value) => Some(value)
    None => pdf_catalog_object_fallback(object_index)
  }
}

///|
fn pdf_collect_xref_follow_offsets(trailer_text : String) -> Array[Int] {
  let offsets : Array[Int] = []
  let seen : Map[Int, Bool] = Map([])
  for key in ["/Prev", "/XRefStm"] {
    match pdf_extract_int_after(trailer_text, key) {
      Some(value) if value >= 0 && !seen.get(value).unwrap_or(false) => {
        seen.set(value, true)
        offsets.push(value)
      }
      _ => ()
    }
  }
  offsets
}

///|
fn pdf_object_is_page(object : PdfNativeObject) -> Bool {
  match pdf_extract_dict_value(object.dict_text, "/Type") {
    Some(PdfNativeDictValue::Name("Page")) => true
    _ => false
  }
}

///|
fn pdf_object_is_pages_node(object : PdfNativeObject) -> Bool {
  match pdf_extract_dict_value(object.dict_text, "/Type") {
    Some(PdfNativeDictValue::Name("Pages")) => true
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
fn pdf_extract_int_array_after(text : String, key : String) -> Array[Int] {
  let values : Array[Int] = []
  match pdf_extract_dict_value(text, key) {
    Some(PdfNativeDictValue::Array(tokens)) =>
      for token in tokens {
        match pdf_token_number(token) {
          Some(value) if pdf_double_is_integral(value) =>
            values.push(value.to_int())
          _ => ()
        }
      }
    Some(PdfNativeDictValue::Number(value)) =>
      if pdf_double_is_integral(value) {
        values.push(value.to_int())
      }
    Some(PdfNativeDictValue::Word(value)) =>
      match pdf_parse_int(value) {
        Some(parsed) => values.push(parsed)
        None => ()
      }
    _ => ()
  }
  values
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
        Some(info) if pdf_font_uses_code_unit_decode(info) => {
          let invalid_tounicode_bytes = pdf_bytes_hit_invalid_tounicode(
            bytes, info,
          )
          match pdf_decode_literal_bytes_with_font(bytes, info) {
            Some(decoded) => decoded
            None =>
              if invalid_tounicode_bytes ||
                pdf_font_should_fail_closed_after_tounicode(info) {
                ""
              } else {
                pdf_decode_pdfdoc_bytes(bytes)
              }
          }
        }
        Some(info) if pdf_font_is_winansi(info) =>
          match pdf_decode_raw_cjk_bytes_for_font(bytes, info) {
            Some(decoded) => decoded
            None => pdf_decode_winansi_bytes(bytes)
          }
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
  match pdf_decode_literal_bytes_with_font_result(bytes, info) {
    Some(decoded) => Some(decoded.text)
    None =>
      match pdf_decode_raw_cjk_bytes_for_font(bytes, info) {
        Some(decoded) => Some(decoded)
        None =>
          if pdf_font_is_winansi(info) {
            let decoded = pdf_decode_winansi_bytes(bytes)
            if decoded != "" {
              Some(decoded)
            } else {
              None
            }
          } else {
            None
          }
      }
  }
}

///|
fn pdf_decode_hex_pdf_text_result(
  hex : String,
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  let bytes = match pdf_hex_byte_values(hex) {
    Some(value) => value
    None => return None
  }
  pdf_decode_literal_bytes_with_font_result(bytes, info)
}

///|
fn pdf_decode_literal_bytes_with_font_result(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  let invalid_tounicode_bytes = pdf_bytes_hit_invalid_tounicode(bytes, info)
  match pdf_decode_bytes_with_unicode_map(bytes, info) {
    Some(decoded) => return Some(decoded)
    None =>
      if invalid_tounicode_bytes ||
        pdf_font_should_fail_closed_after_tounicode(info) {
        return None
      }
  }
  match info.tounicode_builtin_name {
    Some(name) =>
      match pdf_resolve_predefined_cmap(name) {
        Some(cmap) =>
          match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
            Some(decoded) => return Some(decoded)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  match pdf_embedded_font_decode_bytes(bytes, info) {
    Some(decoded) => return Some(decoded)
    None => ()
  }
  match info.cid_collection_cmap {
    Some(cmap) =>
      match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
        Some(decoded) => return Some(decoded)
        None => ()
      }
    None => ()
  }
  match info.predefined_cmap {
    Some(cmap) =>
      match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
        Some(decoded) => return Some(decoded)
        None => ()
      }
    None => ()
  }
  if pdf_font_is_identity_h(info) || pdf_font_is_identity_v(info) {
    return pdf_identity_ascii_decoded_units(bytes)
  }
  None
}

///|
fn pdf_decode_bytes_with_unicode_map(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  if !info.has_tounicode &&
    info.encoding_name == Some("WinAnsiEncoding") &&
    pdf_font_prefers_raw_gb_family_decode(info) {
    return None
  }
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 || info.unicode_map.length() == 0 {
    return None
  }
  let units : Array[PdfDecodedFontUnit] = []
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
        Some(value) if pdf_is_usable_tounicode_text(value) => {
          units.push({
            byte_width: width,
            charcode: pdf_embedded_font_charcode_from_bytes(bytes, index, width),
            cid: pdf_font_unit_cid_hint(
              info,
              width,
              pdf_embedded_font_charcode_from_bytes(bytes, index, width),
            ),
            gid: None,
            text: value,
          })
          parts.push(value)
          index += width
          matched = true
          break
        }
        _ => ()
      }
    }
    if matched {
      continue
    }
    let width = match
      pdf_first_matching_code_width(widths, (bytes.length() - index) * 2) {
      Some(value) => value
      None => 1
    }
    if width <= 0 || index + width > bytes.length() {
      break
    }
    let key = pdf_hex_from_bytes(bytes, index, width)
    if info.has_tounicode &&
      info.tounicode_invalid_keys.get(key).unwrap_or(false) {
      return None
    }
    match pdf_decode_font_code_fallback(key, info) {
      Some(value) => {
        let charcode = pdf_embedded_font_charcode_from_bytes(
          bytes, index, width,
        )
        units.push({
          byte_width: width,
          charcode,
          cid: pdf_font_unit_cid_hint(info, width, charcode),
          gid: None,
          text: value,
        })
        parts.push(value)
        index += width
      }
      None => break
    }
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_bytes_hit_invalid_tounicode(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> Bool {
  if !info.has_tounicode || info.tounicode_invalid_keys.length() == 0 {
    return false
  }
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 {
    return false
  }
  let mut index = 0
  while index < bytes.length() {
    let width = match
      pdf_first_matching_code_width(widths, (bytes.length() - index) * 2) {
      Some(value) => value
      None => 1
    }
    if width <= 0 || index + width > bytes.length() {
      break
    }
    let key = pdf_hex_from_bytes(bytes, index, width)
    if info.tounicode_invalid_keys.get(key).unwrap_or(false) {
      return true
    }
    index += width
  }
  false
}

///|
fn pdf_font_unit_cid_hint(
  info : PdfNativeFontInfo,
  byte_width : Int,
  charcode : Int,
) -> Int? {
  if byte_width > 1 ||
    pdf_font_is_identity_h(info) ||
    pdf_font_is_identity_v(info) ||
    info.descendant_subtype == Some("CIDFontType0") ||
    info.descendant_subtype == Some("CIDFontType2") ||
    pdf_font_has_predefined_cid_encoding(info) {
    Some(charcode)
  } else {
    None
  }
}

///|
fn pdf_identity_ascii_decoded_units(bytes : Array[Int]) -> PdfDecodedFontBytes? {
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 1 < bytes.length() {
    let charcode = pdf_embedded_font_charcode_from_bytes(bytes, index, 2)
    if charcode < 0 || charcode > 0x7F {
      break
    }
    let text = pdf_string_from_codepoints([charcode])
    parts.push(text)
    units.push({ byte_width: 2, charcode, cid: Some(charcode), gid: None, text })
    index += 2
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
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
    0x90 => '\u{2019}'
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
