///|
fn pdf_parse_objects(
  bytes : Bytes,
  view : String,
) -> Result[PdfParsedObjectStore, PdfNativeError] {
  match pdf_parse_objects_via_xref(bytes, view) {
    Ok(Some(store)) => Ok(store)
    Ok(None) => pdf_scan_object_store(bytes, view, "scan_fallback_v0")
    Err(err) =>
      match
        pdf_scan_object_store(bytes, view, "scan_fallback_after_xref_error_v1") {
        Ok(store) => Ok(store)
        Err(_) => Err(err)
      }
  }
}

///|
fn pdf_parse_objects_via_xref(
  bytes : Bytes,
  view : String,
) -> Result[PdfParsedObjectStore?, PdfNativeError] {
  let startxref = match pdf_find_startxref_offset(view) {
    Some(value) if value >= 0 && value < bytes.length() => value
    _ => return Ok(None)
  }
  let resolved = match pdf_resolve_xref_chain(bytes, view, startxref) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  pdf_build_store_from_resolved_xref(
    resolved,
    bytes.length(),
    fn(offset, length) {
      if offset < 0 || length < 0 || offset + length > bytes.length() {
        return Err("PDF object range is outside the payload")
      }
      Ok(bytes[offset:offset + length].to_owned())
    },
    "materialized_xref",
  )
}

///|
const PDF_RANDOM_ACCESS_WINDOW_MAX : Int = 32 * 1024 * 1024

///|
fn pdf_parse_objects_via_cursor(
  cursor : @input.SourceCursor,
) -> Result[PdfParsedObjectStore?, PdfNativeError] {
  let source_size = match cursor.size {
    Some(value) if value > 0L && value <= 512L * 1024L * 1024L => value.to_int()
    _ => return Ok(None)
  }
  let tail_length = source_size.min(64 * 1024)
  let tail_start = source_size - tail_length
  let tail = match pdf_cursor_read_exact(cursor, tail_start, tail_length) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let tail_view = pdf_byte_string(tail)
  let startxref = match pdf_find_startxref_offset(tail_view) {
    Some(value) if value >= 0 && value < source_size => value
    _ => return Ok(None)
  }
  let resolved = match
    pdf_resolve_xref_chain_cursor(cursor, source_size, startxref) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  pdf_build_store_from_resolved_xref(
    resolved,
    source_size,
    fn(offset, length) {
      match pdf_cursor_read_exact(cursor, offset, length) {
        Ok(value) => Ok(value)
        Err(err) => Err(err.to_string())
      }
    },
    "cursor_xref",
  )
}

///|
fn pdf_resolve_xref_chain_cursor(
  cursor : @input.SourceCursor,
  source_size : Int,
  startxref : Int,
) -> Result[PdfResolvedXrefChain, PdfNativeError] {
  let pending_offsets : Array[Int] = [startxref]
  let visited_offsets : Map[Int, Bool] = Map([])
  let entries : Map[Int, PdfNativeXrefEntry] = Map([])
  let trailer_hints : Array[String] = []
  let mut used_xref_stream = false
  let mut has_object_stream_refs = false
  let mut parsed_section_count = 0
  while pending_offsets.length() > 0 {
    let offset = pending_offsets.pop().unwrap_or(0)
    if offset < 0 || offset >= source_size {
      continue
    }
    if visited_offsets.get(offset).unwrap_or(false) {
      continue
    }
    visited_offsets.set(offset, true)
    let window_length = (source_size - offset).min(PDF_RANDOM_ACCESS_WINDOW_MAX)
    let window = match pdf_cursor_read_exact(cursor, offset, window_length) {
      Ok(value) => value
      Err(err) =>
        if parsed_section_count == 0 && entries.length() == 0 {
          return Err(err)
        } else {
          continue
        }
    }
    let window_view = pdf_byte_string(window)
    let section = match pdf_parse_xref_section(window, window_view, 0) {
      Ok(value) => value
      Err(err) =>
        if parsed_section_count == 0 && entries.length() == 0 {
          return Err(err)
        } else {
          continue
        }
    }
    parsed_section_count += 1
    if section.used_xref_stream {
      used_xref_stream = true
    }
    if section.has_object_stream_refs {
      has_object_stream_refs = true
    }
    if section.trailer_text.trim() != "" &&
      !trailer_hints.contains(section.trailer_text) {
      trailer_hints.push(section.trailer_text)
    }
    for entry in section.entries.to_array() {
      if !entries.contains(entry.0) {
        entries.set(entry.0, entry.1)
      }
    }
    for next_offset in section.next_offsets {
      if next_offset >= 0 &&
        next_offset < source_size &&
        !visited_offsets.get(next_offset).unwrap_or(false) {
        pending_offsets.push(next_offset)
      }
    }
  }
  Ok({ entries, trailer_hints, used_xref_stream, has_object_stream_refs })
}

///|
fn pdf_cursor_read_exact(
  cursor : @input.SourceCursor,
  offset : Int,
  length : Int,
) -> Result[Bytes, PdfNativeError] {
  if offset < 0 || length < 0 {
    return Err(ReadFailed("PDF cursor range is invalid"))
  }
  let output = Buffer()
  let mut consumed = 0
  while consumed < length {
    let chunk = match
      @input.source_cursor_read_at(
        cursor,
        (offset + consumed).to_int64(),
        length=length - consumed,
      ) {
      Ok(value) => value
      Err(message) => return Err(ReadFailed(message))
    }
    if chunk.length() == 0 || chunk.length() > length - consumed {
      return Err(ReadFailed("unexpected EOF in PDF cursor"))
    }
    output.write_bytes(chunk)
    consumed += chunk.length()
  }
  Ok(output.to_bytes())
}

///|
fn pdf_parsed_store_is_encrypted(store : PdfParsedObjectStore) -> Bool {
  store.trailer_hints.any(hint => hint.contains("/Encrypt"))
}

///|
fn pdf_build_store_from_resolved_xref(
  resolved : PdfResolvedXrefChain,
  source_size : Int,
  read_range : (Int, Int) -> Result[Bytes, String],
  input_access_mode : String,
) -> Result[PdfParsedObjectStore?, PdfNativeError] {
  let direct_locations : Array[PdfXrefDirectObjectLocation] = []
  let compressed_refs : Array[PdfXrefCompressedObjectRef] = []
  for entry in resolved.entries.to_array() {
    match entry.1 {
      InUse(offset, _generation) =>
        if offset >= 0 && offset < source_size {
          direct_locations.push({ object_id: entry.0, offset })
        }
      Compressed(object_stream_id, _object_index_in_stream) =>
        compressed_refs.push({ object_id: entry.0, object_stream_id })
    }
  }
  if direct_locations.length() == 0 && compressed_refs.length() == 0 {
    return Ok(None)
  }
  direct_locations.sort_by(fn(left, right) {
    if left.offset < right.offset {
      -1
    } else if left.offset > right.offset {
      1
    } else if left.object_id < right.object_id {
      -1
    } else if left.object_id > right.object_id {
      1
    } else {
      0
    }
  })
  let objects : Array[PdfNativeObject] = []
  let object_index : Map[Int, PdfNativeObject] = Map([])
  let mut location_index = 0
  while location_index < direct_locations.length() {
    let location = direct_locations[location_index]
    let next_offset = if location_index + 1 < direct_locations.length() {
      direct_locations[location_index + 1].offset
    } else {
      source_size
    }
    let available = if next_offset > location.offset {
      next_offset - location.offset
    } else {
      source_size - location.offset
    }
    let window_length = available.min(PDF_RANDOM_ACCESS_WINDOW_MAX)
    let window = match read_range(location.offset, window_length) {
      Ok(value) => value
      Err(message) => return Err(ReadFailed(message))
    }
    let object = match pdf_parse_indirect_object_at(window, 0) {
      Ok(value) => value
      Err(_err) => {
        location_index += 1
        continue
      }
    }
    if object.object_id != location.object_id {
      location_index += 1
      continue
    }
    if object_index.get(object.object_id) is Some(_) {
      location_index += 1
      continue
    }
    objects.push(object)
    object_index.set(object.object_id, object)
    location_index += 1
  }
  if objects.length() == 0 {
    return Ok(None)
  }
  if compressed_refs.length() > 0 {
    let expected_compressed : Map[Int, Bool] = Map([])
    let ordered_object_stream_ids : Array[Int] = []
    let seen_stream_ids : Map[Int, Bool] = Map([])
    for compressed_ref in compressed_refs {
      expected_compressed.set(compressed_ref.object_id, true)
      if !seen_stream_ids.get(compressed_ref.object_stream_id).unwrap_or(false) {
        seen_stream_ids.set(compressed_ref.object_stream_id, true)
        ordered_object_stream_ids.push(compressed_ref.object_stream_id)
      }
    }
    ordered_object_stream_ids.sort_by(fn(left, right) {
      let left_offset = match resolved.entries.get(left) {
        Some(InUse(offset, _generation)) => offset
        _ => left
      }
      let right_offset = match resolved.entries.get(right) {
        Some(InUse(offset, _generation)) => offset
        _ => right
      }
      if left_offset < right_offset {
        -1
      } else if left_offset > right_offset {
        1
      } else if left < right {
        -1
      } else if left > right {
        1
      } else {
        0
      }
    })
    for object_stream_id in ordered_object_stream_ids {
      let object_stream = match object_index.get(object_stream_id) {
        Some(value) => value
        None => continue
      }
      let parsed = match pdf_parse_object_stream_entries(object_stream) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      for embedded in parsed {
        if !expected_compressed.get(embedded.object_id).unwrap_or(false) {
          continue
        }
        if object_index.get(embedded.object_id) is Some(_) {
          continue
        }
        objects.push(embedded)
        object_index.set(embedded.object_id, embedded)
      }
    }
  }
  Ok(
    Some(
      pdf_build_parsed_object_store(
        objects,
        object_index,
        resolved.trailer_hints,
        pdf_xref_mode_name(
          resolved.used_xref_stream,
          resolved.has_object_stream_refs,
        ),
        input_access_mode,
      ),
    ),
  )
}

///|
fn pdf_scan_object_store(
  bytes : Bytes,
  view : String,
  xref_mode : String,
) -> Result[PdfParsedObjectStore, PdfNativeError] {
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
          ParseFailed("unterminated PDF object " + header.object_id.to_string()),
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
  let object_index : Map[Int, PdfNativeObject] = Map([])
  for object in objects {
    object_index.set(object.object_id, object)
  }
  Ok(
    pdf_build_parsed_object_store(
      objects,
      object_index,
      pdf_collect_trailer_hints_from_view(view),
      xref_mode,
      "materialized_scan",
    ),
  )
}

///|
fn pdf_build_parsed_object_store(
  objects : Array[PdfNativeObject],
  object_index : Map[Int, PdfNativeObject],
  trailer_hints : Array[String],
  xref_mode : String,
  input_access_mode : String,
) -> PdfParsedObjectStore {
  {
    objects,
    object_index,
    trailer_hints,
    xref_mode,
    filter_decode_mode: "filter_chain_v1",
    input_access_mode,
  }
}

///|
fn pdf_xref_mode_name(
  used_xref_stream : Bool,
  has_object_stream_refs : Bool,
) -> String {
  if used_xref_stream && has_object_stream_refs {
    "xref_stream_objstm_v1"
  } else if used_xref_stream {
    "xref_stream_v1"
  } else if has_object_stream_refs {
    "classic_xref_table_objstm_v1"
  } else {
    "classic_xref_table_v1"
  }
}

///|
fn pdf_find_startxref_offset(view : String) -> Int? {
  let start = match pdf_find_last_substring(view, "startxref") {
    Some(value) => value
    None => return None
  }
  let tail_start = start + "startxref".length()
  if tail_start >= view.length() {
    return None
  }
  let parts = pdf_split_ascii_whitespace(view[tail_start:].to_owned())
  if parts.length() == 0 {
    None
  } else {
    pdf_parse_int(parts[0])
  }
}

///|
fn pdf_resolve_xref_chain(
  bytes : Bytes,
  view : String,
  startxref : Int,
) -> Result[PdfResolvedXrefChain, PdfNativeError] {
  let pending_offsets : Array[Int] = [startxref]
  let visited_offsets : Map[Int, Bool] = Map([])
  let entries : Map[Int, PdfNativeXrefEntry] = Map([])
  let trailer_hints : Array[String] = []
  let mut used_xref_stream = false
  let mut has_object_stream_refs = false
  let mut parsed_section_count = 0
  while pending_offsets.length() > 0 {
    let offset = pending_offsets.pop().unwrap_or(0)
    if offset < 0 || offset >= bytes.length() {
      continue
    }
    if visited_offsets.get(offset).unwrap_or(false) {
      continue
    }
    visited_offsets.set(offset, true)
    let section = match pdf_parse_xref_section(bytes, view, offset) {
      Ok(value) => value
      Err(err) =>
        if parsed_section_count == 0 && entries.length() == 0 {
          return Err(err)
        } else {
          continue
        }
    }
    parsed_section_count += 1
    if section.used_xref_stream {
      used_xref_stream = true
    }
    if section.has_object_stream_refs {
      has_object_stream_refs = true
    }
    if section.trailer_text.trim() != "" &&
      !trailer_hints.contains(section.trailer_text) {
      trailer_hints.push(section.trailer_text)
    }
    for entry in section.entries.to_array() {
      if !entries.contains(entry.0) {
        entries.set(entry.0, entry.1)
      }
    }
    for next_offset in section.next_offsets {
      if next_offset >= 0 &&
        next_offset < bytes.length() &&
        !visited_offsets.get(next_offset).unwrap_or(false) {
        pending_offsets.push(next_offset)
      }
    }
  }
  Ok({ entries, trailer_hints, used_xref_stream, has_object_stream_refs })
}

///|
fn pdf_parse_xref_section(
  bytes : Bytes,
  view : String,
  offset : Int,
) -> Result[PdfParsedXrefSection, PdfNativeError] {
  let cursor = pdf_skip_ascii_whitespace_and_comments_bytes(bytes, offset)
  if pdf_bytes_have_prefix(bytes, cursor, "xref") {
    pdf_parse_classic_xref_section(bytes, view, cursor)
  } else {
    pdf_parse_xref_stream_section(bytes, view, cursor)
  }
}

///|
fn pdf_parse_classic_xref_section(
  bytes : Bytes,
  view : String,
  offset : Int,
) -> Result[PdfParsedXrefSection, PdfNativeError] {
  ignore(view)
  let mut cursor = offset + "xref".length()
  let entries : Map[Int, PdfNativeXrefEntry] = Map([])
  while true {
    cursor = pdf_skip_ascii_whitespace_and_comments_bytes(bytes, cursor)
    if cursor >= bytes.length() {
      return Err(ParseFailed("classic xref table is truncated before trailer"))
    }
    if pdf_bytes_have_prefix(bytes, cursor, "trailer") {
      cursor += "trailer".length()
      break
    }
    let header_line = pdf_read_ascii_line(bytes, cursor)
    cursor = header_line.1
    let header_parts = pdf_split_ascii_whitespace(header_line.0)
    if header_parts.length() < 2 {
      return Err(
        ParseFailed(
          "classic xref subsection header is malformed: " + header_line.0,
        ),
      )
    }
    let first_object = match pdf_parse_int(header_parts[0]) {
      Some(value) if value >= 0 => value
      _ =>
        return Err(
          ParseFailed(
            "classic xref subsection first object is invalid: " + header_line.0,
          ),
        )
    }
    let object_count = match pdf_parse_int(header_parts[1]) {
      Some(value) if value >= 0 => value
      _ =>
        return Err(
          ParseFailed(
            "classic xref subsection length is invalid: " + header_line.0,
          ),
        )
    }
    for index in 0..<object_count {
      let entry_line = pdf_read_ascii_line(bytes, cursor)
      cursor = entry_line.1
      let entry_parts = pdf_split_ascii_whitespace(entry_line.0)
      if entry_parts.length() < 3 {
        return Err(
          ParseFailed("classic xref entry is malformed: " + entry_line.0),
        )
      }
      let object_id = first_object + index
      let offset_value = match pdf_parse_int(entry_parts[0]) {
        Some(value) if value >= 0 => value
        _ =>
          return Err(
            ParseFailed("classic xref entry offset is invalid: " + entry_line.0),
          )
      }
      let generation = match pdf_parse_int(entry_parts[1]) {
        Some(value) if value >= 0 => value
        _ =>
          return Err(
            ParseFailed(
              "classic xref entry generation is invalid: " + entry_line.0,
            ),
          )
      }
      let state = entry_parts[2]
      if state == "n" {
        entries.set(object_id, InUse(offset_value, generation))
      }
    }
  }
  cursor = pdf_skip_ascii_whitespace_and_comments_bytes(bytes, cursor)
  let trailer_text = match pdf_parse_dict_text_at(view, cursor) {
    Some(value) => value
    None =>
      return Err(
        ParseFailed("classic xref trailer dictionary is missing or malformed"),
      )
  }
  Ok({
    entries,
    trailer_text,
    next_offsets: pdf_collect_xref_follow_offsets(trailer_text),
    used_xref_stream: false,
    has_object_stream_refs: false,
  })
}

///|
fn pdf_parse_xref_stream_section(
  bytes : Bytes,
  view : String,
  offset : Int,
) -> Result[PdfParsedXrefSection, PdfNativeError] {
  ignore(view)
  let object = match pdf_parse_indirect_object_at(bytes, offset) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let widths = match pdf_extract_int_array_after(object.dict_text, "/W") {
    [a, b, c] => [a, b, c]
    _ =>
      return Err(
        ParseFailed(
          "xref stream object " +
          object.object_id.to_string() +
          " is missing valid /W widths",
        ),
      )
  }
  let section_pairs = match
    pdf_extract_int_array_after(object.dict_text, "/Index") {
    [] =>
      match pdf_extract_int_after(object.dict_text, "/Size") {
        Some(size) if size >= 0 => [0, size]
        _ =>
          return Err(
            ParseFailed(
              "xref stream object " +
              object.object_id.to_string() +
              " is missing valid /Index or /Size",
            ),
          )
      }
    values => values
  }
  if section_pairs.length() % 2 != 0 {
    return Err(
      ParseFailed(
        "xref stream object " +
        object.object_id.to_string() +
        " has malformed /Index array",
      ),
    )
  }
  let entry_width = widths[0] + widths[1] + widths[2]
  if entry_width <= 0 {
    return Err(
      ParseFailed(
        "xref stream object " +
        object.object_id.to_string() +
        " has invalid entry width",
      ),
    )
  }
  let raw_stream = match pdf_decode_stream_bytes(object, "xref stream") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let entries : Map[Int, PdfNativeXrefEntry] = Map([])
  let mut cursor = 0
  let mut has_object_stream_refs = false
  let mut index = 0
  while index + 1 < section_pairs.length() {
    let first_object = section_pairs[index]
    let object_count = section_pairs[index + 1]
    if first_object < 0 || object_count < 0 {
      return Err(
        ParseFailed(
          "xref stream object " +
          object.object_id.to_string() +
          " has negative /Index values",
        ),
      )
    }
    for item in 0..<object_count {
      if cursor + entry_width > raw_stream.length() {
        return Err(
          ParseFailed(
            "xref stream object " +
            object.object_id.to_string() +
            " is truncated",
          ),
        )
      }
      let field0 = pdf_decode_big_endian_int(raw_stream, cursor, widths[0])
      let field1 = pdf_decode_big_endian_int(
        raw_stream,
        cursor + widths[0],
        widths[1],
      )
      let field2 = pdf_decode_big_endian_int(
        raw_stream,
        cursor + widths[0] + widths[1],
        widths[2],
      )
      let object_id = first_object + item
      let entry_type = if widths[0] == 0 { 1 } else { field0 }
      match entry_type {
        0 => ()
        1 => entries.set(object_id, InUse(field1, field2))
        2 => {
          has_object_stream_refs = true
          entries.set(object_id, Compressed(field1, field2))
        }
        _ => ()
      }
      cursor += entry_width
    }
    index += 2
  }
  Ok({
    entries,
    trailer_text: object.dict_text,
    next_offsets: pdf_collect_xref_follow_offsets(object.dict_text),
    used_xref_stream: true,
    has_object_stream_refs,
  })
}

///|
fn pdf_parse_indirect_object_at(
  bytes : Bytes,
  offset : Int,
) -> Result[PdfNativeObject, PdfNativeError] {
  let header = match pdf_find_object_header_at(bytes, offset) {
    Some(value) => value
    None =>
      return Err(
        ParseFailed(
          "failed to parse indirect object header at offset " +
          offset.to_string(),
        ),
      )
  }
  let endobj = match
    pdf_find_bytes(bytes, pdf_ascii_bytes("endobj"), header.body_start) {
    Some(index) => index
    None =>
      return Err(
        ParseFailed("unterminated PDF object " + header.object_id.to_string()),
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
  Ok({ object_id: header.object_id, dict_text, stream })
}

///|
fn pdf_collect_trailer_hints_from_view(view : String) -> Array[String] {
  let hints : Array[String] = []
  let trailer_index = match pdf_find_last_substring(view, "trailer") {
    Some(value) => value
    None => return hints
  }
  let dict_start = match pdf_find_substring(view, "<<", trailer_index) {
    Some(value) => value
    None => return hints
  }
  match pdf_parse_dict_text_at(view, dict_start) {
    Some(value) => hints.push(value)
    None => ()
  }
  hints
}

///|
priv struct PdfNativeObjectHeader {
  object_id : Int
  body_start : Int
}

///|
fn pdf_find_object_header_at(
  bytes : Bytes,
  start : Int,
) -> PdfNativeObjectHeader? {
  let cursor = pdf_skip_ascii_whitespace_and_comments_bytes(bytes, start)
  let marker = match pdf_find_bytes(bytes, pdf_ascii_bytes(" obj"), cursor) {
    Some(value) => value
    None => return None
  }
  let header = pdf_byte_string(bytes[cursor:marker].to_owned())
    .trim()
    .to_owned()
  let parts = pdf_split_ascii_whitespace(header)
  if parts.length() < 2 {
    return None
  }
  match (pdf_parse_int(parts[0]), pdf_parse_int(parts[1])) {
    (Some(object_id), Some(generation)) => {
      ignore(generation)
      let body_start = pdf_skip_object_header_whitespace_bytes(
        bytes,
        marker + " obj".length(),
      )
      Some({ object_id, body_start })
    }
    _ => None
  }
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
          return Err(ParseFailed("stream object is missing endstream marker"))
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
        Some(length) if length <= object_body.length() - raw_start =>
          object_body[raw_start:raw_start + length].to_owned()
        _ => endstream_bytes
      }
      Ok(Some((dict_text, { primary_bytes, endstream_bytes, declared_length })))
    }
  }
}
