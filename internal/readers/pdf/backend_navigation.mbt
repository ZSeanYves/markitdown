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
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeOutlineItem] {
  let catalog = match pdf_catalog_object(trailer_hints, object_index) {
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
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> Array[PdfNativeDestination] {
  let catalog = match pdf_catalog_object(trailer_hints, object_index) {
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
  let dests_dict = match
    pdf_inline_or_referenced_dict_text(dict_text, "/Dests", object_index) {
    Some(value) => value
    None => return []
  }
  let visited : Map[Int, Bool] = Map([])
  pdf_extract_named_destinations_from_name_tree(
    source, dests_dict, object_index, page_numbers, visited, 16,
  )
}

///|
fn pdf_extract_named_destinations_from_name_tree(
  source : @input.InputSource,
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
  visited : Map[Int, Bool],
  remaining_depth : Int,
) -> Array[PdfNativeDestination] {
  if remaining_depth <= 0 {
    return []
  }
  let out : Array[PdfNativeDestination] = []
  match pdf_extract_dict_value(dict_text, "/Names") {
    Some(Array(tokens)) => {
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
  for kid_id in pdf_extract_object_references_after(dict_text, "/Kids") {
    if visited.get(kid_id).unwrap_or(false) {
      continue
    }
    visited.set(kid_id, true)
    match object_index.get(kid_id) {
      Some(object) =>
        out.append(
          pdf_extract_named_destinations_from_name_tree(
            source,
            object.dict_text,
            object_index,
            page_numbers,
            visited,
            remaining_depth - 1,
          )[:],
        )
      None => ()
    }
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
    Array(tokens) => pdf_destination_from_tokens(tokens, 0, None, page_numbers)
    Dict(dict_text) =>
      match pdf_extract_dict_value(dict_text, "/D") {
        Some(value) =>
          pdf_destination_from_value(value, object_index, 0, None, page_numbers)
        None => None
      }
    Name(name) =>
      Some(
        make_pdf_native_destination(name=Some(name), raw_value=Some("/" + name)),
      )
    LiteralString(value) =>
      Some(
        make_pdf_native_destination(
          name=Some(pdf_normalize_pdf_text(value.decoded)),
          raw_value=Some(pdf_normalize_pdf_text(value.decoded)),
        ),
      )
    HexString(hex) =>
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
