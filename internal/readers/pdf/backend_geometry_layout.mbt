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
      Word("begincodespacerange") => {
        in_codespacerange = true
        in_bfchar = false
        in_bfrange = false
      }
      Word("endcodespacerange") => in_codespacerange = false
      Word("beginbfchar") => {
        in_codespacerange = false
        in_bfchar = true
        in_bfrange = false
      }
      Word("endbfchar") => in_bfchar = false
      Word("beginbfrange") => {
        in_codespacerange = false
        in_bfchar = false
        in_bfrange = true
      }
      Word("endbfrange") => in_bfrange = false
      Name(name) =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            Word("usecmap") => {
              usecmap_name = Some(name)
              index += 1
            }
            _ => ()
          }
        }
      HexString(start_hex) if in_codespacerange =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            HexString(_end_hex) => {
              let width = start_hex.length() / 2
              if width > 0 {
                widths.set(width, true)
              }
              index += 1
            }
            _ => ()
          }
        }
      HexString(src) if in_bfchar =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            HexString(dst) => {
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
      HexString(start_hex) if in_bfrange =>
        if index + 2 < tokens.length() {
          let start_width = start_hex.length() / 2
          if start_width > 0 {
            widths.set(start_width, true)
          }
          match (tokens[index + 1], tokens[index + 2]) {
            (HexString(end_hex), HexString(base_hex)) =>
              pdf_apply_tounicode_bfrange(
                mapping,
                invalid_keys,
                start_hex,
                end_hex,
                base_hex,
                None,
              )
            (HexString(end_hex), Array(items)) =>
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
              HexString(value_hex) => {
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
          Reference(object_id, generation) => {
            ignore(generation)
            if entry.0.has_prefix("/") && entry.0.length() > 1 {
              aliases.set(entry.0[1:].to_owned(), object_id)
            }
          }
          Dict(inline_font_dict) =>
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
          String(pdf_normalize_pdf_text(value)),
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
    Some(Name("Page")) => true
    _ => false
  }
}

///|
fn pdf_object_is_pages_node(object : PdfNativeObject) -> Bool {
  match pdf_extract_dict_value(object.dict_text, "/Type") {
    Some(Name("Pages")) => true
    _ => false
  }
}

///|
fn pdf_extract_object_reference_after(text : String, key : String) -> Int? {
  match pdf_extract_dict_value(text, key) {
    Some(Reference(object_id, generation)) => {
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
    Some(Reference(object_id, generation)) => {
      ignore(generation)
      refs.push(object_id)
    }
    Some(Array(tokens)) =>
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
    Some(Reference(object_id, generation)) => {
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
    Some(Array(tokens)) => pdf_collect_reference_ids_from_tokens(tokens)
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
      Array(items) => return pdf_collect_reference_ids_from_tokens(items)
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
    Some(Name(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_int_after(text : String, key : String) -> Int? {
  match pdf_extract_dict_value(text, key) {
    Some(Number(value)) =>
      if pdf_double_is_integral(value) {
        Some(value.to_int())
      } else {
        None
      }
    Some(Word(value)) => pdf_parse_int(value)
    _ => None
  }
}

///|
fn pdf_extract_int_array_after(text : String, key : String) -> Array[Int] {
  let values : Array[Int] = []
  match pdf_extract_dict_value(text, key) {
    Some(Array(tokens)) =>
      for token in tokens {
        match pdf_token_number(token) {
          Some(value) if pdf_double_is_integral(value) =>
            values.push(value.to_int())
          _ => ()
        }
      }
    Some(Number(value)) =>
      if pdf_double_is_integral(value) {
        values.push(value.to_int())
      }
    Some(Word(value)) =>
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
    Some(Array(tokens)) if tokens.length() >= 4 =>
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
    Some(Dict(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_string_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(LiteralString(value)) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(value.decoded)))
    Some(HexString(value)) =>
      match pdf_decode_hex_pdf_text(value, None) {
        Some(decoded) => Some(pdf_normalize_pdf_text(decoded))
        None => None
      }
    Some(Name(value)) => Some(value)
    Some(Word(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_raw_string_after(text : String, key : String) -> String? {
  match pdf_extract_dict_value(text, key) {
    Some(LiteralString(value)) =>
      Some(pdf_decode_literal_pdf_text(value.decoded))
    Some(HexString(value)) => pdf_decode_hex_pdf_text(value, None)
    Some(Name(value)) => Some(value)
    Some(Word(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_extract_string_array_after(text : String, key : String) -> Array[String] {
  let values : Array[String] = []
  match pdf_extract_dict_value(text, key) {
    Some(Array(tokens)) => pdf_collect_string_array_values(tokens, values)
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
    LiteralString(token) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(token.decoded)))
    HexString(hex) => pdf_decode_hex_pdf_text(hex, None)
    Name(name) => Some(name)
    Word(word) => Some(word)
    Number(number) => Some(number.to_string())
    _ => None
  }
}

///|
fn pdf_token_text(token : PdfNativeContentToken) -> String? {
  match token {
    LiteralString(value) =>
      Some(pdf_normalize_pdf_text(pdf_decode_literal_pdf_text(value.decoded)))
    HexString(hex) => pdf_decode_hex_pdf_text(hex, None)
    Name(name) => Some(name)
    Word(word) => Some(word)
    Number(number) => Some(number.to_string())
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
      Array(items) => {
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
