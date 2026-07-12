///|
priv struct PdfEmbeddedFontProgram {
  gid_unicode_gids : Array[Int]
  gid_unicode_values : Array[String]
  gid_glyph_name_gids : Array[Int]
  gid_glyph_name_values : Array[String]
  gid_advance_pairs : Array[Int]
  default_advance_width : Int?
}

///|
priv struct PdfSfntTableRecord {
  offset : Int
}

///|
fn pdf_extract_embedded_font_program(
  font_dict_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> PdfEmbeddedFontProgram? {
  let descriptor_ref = match
    pdf_extract_object_reference_after(font_dict_text, "/FontDescriptor") {
    Some(value) => value
    None => return None
  }
  let descriptor = match object_index.get(descriptor_ref) {
    Some(value) => value
    None => return None
  }
  match pdf_extract_object_reference_after(descriptor.dict_text, "/FontFile2") {
    Some(object_id) =>
      match object_index.get(object_id) {
        Some(object) =>
          match pdf_decode_stream_bytes(object, "embedded FontFile2") {
            Ok(bytes) => pdf_parse_embedded_sfnt_font_program(bytes)
            Err(_) => None
          }
        None => None
      }
    None =>
      match
        pdf_extract_object_reference_after(descriptor.dict_text, "/FontFile3") {
        Some(object_id) =>
          match object_index.get(object_id) {
            Some(object) => {
              let subtype = pdf_extract_name_after(object.dict_text, "/Subtype")
              let bytes = match
                pdf_decode_stream_bytes(object, "embedded FontFile3") {
                Ok(value) => value
                Err(_) => return None
              }
              match subtype {
                Some("OpenType") => pdf_parse_embedded_sfnt_font_program(bytes)
                Some("Type1C") =>
                  pdf_parse_embedded_cff_font_program(bytes, false)
                Some("CIDFontType0C") =>
                  pdf_parse_embedded_cff_font_program(bytes, true)
                _ => None
              }
            }
            None => None
          }
        None => None
      }
  }
}

///|
fn pdf_extract_cid_to_gid_map(
  cid_font_dict_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> Array[Int]? {
  match pdf_extract_dict_value(cid_font_dict_text, "/CIDToGIDMap") {
    Some(PdfNativeDictValue::Name("Identity")) => None
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      let object = match object_index.get(object_id) {
        Some(value) => value
        None => return None
      }
      let bytes = match pdf_decode_stream_bytes(object, "CIDToGIDMap") {
        Ok(value) => value
        Err(_) => return None
      }
      let mapping : Array[Int] = []
      let mut index = 0
      while index + 1 < bytes.length() {
        mapping.push(pdf_decode_big_endian_int(bytes, index, 2))
        index += 2
      }
      Some(mapping)
    }
    _ => None
  }
}

///|
fn pdf_embedded_font_decode_bytes(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  let program = match info.embedded_font_program {
    Some(value) => value
    None => return None
  }
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 {
    return None
  }
  let units : Array[PdfDecodedFontUnit] = []
  let text_parts : Array[String] = []
  let mut index = 0
  while index < bytes.length() {
    let mut matched = false
    for width in widths {
      if width <= 0 || index + width > bytes.length() {
        continue
      }
      let charcode = pdf_embedded_font_charcode_from_bytes(bytes, index, width)
      let gid = pdf_embedded_font_gid_for_charcode(info, charcode)
      let text = match gid {
        Some(value) => pdf_embedded_font_program_unicode(program, value)
        None => None
      }
      match text {
        Some(value) if value != "" => {
          units.push({
            byte_width: width,
            charcode,
            cid: if width > 1 ||
              pdf_font_is_identity_h(info) ||
              pdf_font_is_identity_v(info) {
              Some(charcode)
            } else {
              None
            },
            gid,
            text: value,
          })
          text_parts.push(value)
          index += width
          matched = true
          break
        }
        _ => ()
      }
    }
    if !matched {
      break
    }
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: text_parts.join(""), units })
  }
}

///|
fn pdf_embedded_font_program_width_1000(
  info : PdfNativeFontInfo,
  unit : PdfDecodedFontUnit,
) -> Int? {
  let program = match info.embedded_font_program {
    Some(value) => value
    None => return None
  }
  match unit.gid {
    Some(gid) =>
      match pdf_lookup_flat_int_pairs(program.gid_advance_pairs, gid) {
        Some(width) => Some(width)
        None => program.default_advance_width
      }
    None => program.default_advance_width
  }
}

///|
fn pdf_parse_embedded_sfnt_font_program(
  bytes : Bytes,
) -> PdfEmbeddedFontProgram? {
  let tables = pdf_parse_sfnt_tables(bytes)
  let units_per_em = match pdf_sfnt_table_head_units_per_em(bytes, tables) {
    Some(value) if value > 0 => value
    _ => 1000
  }
  let num_glyphs = pdf_sfnt_table_num_glyphs(bytes, tables).unwrap_or(0)
  let num_h_metrics = pdf_sfnt_table_num_h_metrics(bytes, tables).unwrap_or(0)
  let gid_advance_pairs = pdf_sfnt_table_hmtx_advances(
    bytes, tables, units_per_em, num_glyphs, num_h_metrics,
  )
  let (gid_unicode_gids, gid_unicode_values) = pdf_sfnt_table_unicode_map(
    bytes, tables,
  )
  Some({
    gid_unicode_gids,
    gid_unicode_values,
    gid_glyph_name_gids: [],
    gid_glyph_name_values: [],
    gid_advance_pairs,
    default_advance_width: None,
  })
}

///|
fn pdf_parse_embedded_cff_font_program(
  bytes : Bytes,
  cid_font : Bool,
) -> PdfEmbeddedFontProgram? {
  ignore(cid_font)
  let private_default_width = pdf_cff_private_default_width(bytes)
  let private_nominal_width = pdf_cff_private_nominal_width(bytes)
  Some({
    gid_unicode_gids: [],
    gid_unicode_values: [],
    gid_glyph_name_gids: [],
    gid_glyph_name_values: [],
    gid_advance_pairs: [],
    default_advance_width: match private_default_width {
      Some(value) => Some(value)
      None => private_nominal_width
    },
  })
}

///|
fn pdf_embedded_font_program_unicode(
  program : PdfEmbeddedFontProgram,
  gid : Int,
) -> String? {
  match
    pdf_lookup_sorted_int_string_pairs(
      program.gid_unicode_gids,
      program.gid_unicode_values,
      gid,
    ) {
    Some(value) => Some(value)
    None =>
      match
        pdf_lookup_sorted_int_string_pairs(
          program.gid_glyph_name_gids,
          program.gid_glyph_name_values,
          gid,
        ) {
        Some(name) => pdf_font_glyph_name_to_unicode(name)
        None => None
      }
  }
}

///|
fn pdf_embedded_font_gid_for_charcode(
  info : PdfNativeFontInfo,
  charcode : Int,
) -> Int? {
  match info.cid_to_gid_map {
    Some(mapping) =>
      if charcode >= 0 && charcode < mapping.length() {
        Some(mapping[charcode])
      } else {
        None
      }
    None =>
      if info.descendant_subtype == Some("CIDFontType2") ||
        info.descendant_subtype == Some("CIDFontType0") ||
        pdf_font_is_identity_h(info) ||
        pdf_font_is_identity_v(info) {
        Some(charcode)
      } else if charcode >= 0 && charcode <= 0xFFFF {
        Some(charcode)
      } else {
        None
      }
  }
}

///|
fn pdf_embedded_font_charcode_from_bytes(
  bytes : Array[Int],
  start : Int,
  width : Int,
) -> Int {
  let mut value = 0
  let mut index = start
  while index < start + width && index < bytes.length() {
    value = value * 256 + (bytes[index] & 0xFF)
    index += 1
  }
  value
}

///|
fn pdf_parse_sfnt_tables(bytes : Bytes) -> Map[String, PdfSfntTableRecord] {
  let tables : Map[String, PdfSfntTableRecord] = Map([])
  if bytes.length() < 12 {
    return tables
  }
  let num_tables = pdf_decode_big_endian_int(bytes, 4, 2)
  let mut index = 12
  for _ in 0..<num_tables {
    if index + 16 > bytes.length() {
      break
    }
    let tag = pdf_byte_string(bytes[index:index + 4].to_owned())
    let offset = pdf_decode_big_endian_int(bytes, index + 8, 4)
    tables.set(tag, { offset, })
    index += 16
  }
  tables
}

///|
fn pdf_sfnt_table_head_units_per_em(
  bytes : Bytes,
  tables : Map[String, PdfSfntTableRecord],
) -> Int? {
  let table = match tables.get("head") {
    Some(value) => value
    None => return None
  }
  if table.offset + 20 > bytes.length() {
    return None
  }
  Some(pdf_decode_big_endian_int(bytes, table.offset + 18, 2))
}

///|
fn pdf_sfnt_table_num_glyphs(
  bytes : Bytes,
  tables : Map[String, PdfSfntTableRecord],
) -> Int? {
  let table = match tables.get("maxp") {
    Some(value) => value
    None => return None
  }
  if table.offset + 6 > bytes.length() {
    return None
  }
  Some(pdf_decode_big_endian_int(bytes, table.offset + 4, 2))
}

///|
fn pdf_sfnt_table_num_h_metrics(
  bytes : Bytes,
  tables : Map[String, PdfSfntTableRecord],
) -> Int? {
  let table = match tables.get("hhea") {
    Some(value) => value
    None => return None
  }
  if table.offset + 36 > bytes.length() {
    return None
  }
  Some(pdf_decode_big_endian_int(bytes, table.offset + 34, 2))
}

///|
fn pdf_sfnt_table_hmtx_advances(
  bytes : Bytes,
  tables : Map[String, PdfSfntTableRecord],
  units_per_em : Int,
  num_glyphs : Int,
  num_h_metrics : Int,
) -> Array[Int] {
  let pairs : Array[Int] = []
  let table = match tables.get("hmtx") {
    Some(value) => value
    None => return pairs
  }
  let glyph_count = if num_glyphs > 0 { num_glyphs } else { num_h_metrics }
  let metrics_count = if num_h_metrics > 0 {
    num_h_metrics
  } else {
    glyph_count
  }
  let mut last_advance = 0
  for gid in 0..<glyph_count {
    let metric_offset = if gid < metrics_count {
      table.offset + gid * 4
    } else {
      table.offset + (metrics_count - 1) * 4
    }
    if metric_offset + 2 > bytes.length() {
      break
    }
    let advance = pdf_decode_big_endian_int(bytes, metric_offset, 2)
    if gid < metrics_count {
      last_advance = advance
    }
    let resolved = if advance > 0 { advance } else { last_advance }
    pairs.push(gid)
    pairs.push(pdf_scale_font_units_to_1000(resolved, units_per_em))
  }
  pairs
}

///|
fn pdf_sfnt_table_unicode_map(
  bytes : Bytes,
  tables : Map[String, PdfSfntTableRecord],
) -> (Array[Int], Array[String]) {
  let gids : Array[Int] = []
  let values : Array[String] = []
  let cmap = match tables.get("cmap") {
    Some(value) => value
    None => return (gids, values)
  }
  if cmap.offset + 4 > bytes.length() {
    return (gids, values)
  }
  let num_tables = pdf_decode_big_endian_int(bytes, cmap.offset + 2, 2)
  let records : Array[(Int, Int, Int)] = []
  let mut record_offset = cmap.offset + 4
  for _ in 0..<num_tables {
    if record_offset + 8 > bytes.length() {
      break
    }
    records.push(
      (
        pdf_decode_big_endian_int(bytes, record_offset, 2),
        pdf_decode_big_endian_int(bytes, record_offset + 2, 2),
        pdf_decode_big_endian_int(bytes, record_offset + 4, 4),
      ),
    )
    record_offset += 8
  }
  let chosen_offset = match pdf_choose_sfnt_unicode_cmap_offset(records) {
    Some(value) => value
    None => return (gids, values)
  }
  pdf_sfnt_collect_gid_unicode_pairs(bytes, cmap.offset + chosen_offset)
}

///|
fn pdf_choose_sfnt_unicode_cmap_offset(
  records : Array[(Int, Int, Int)],
) -> Int? {
  let mut chosen_rank = 1_000_000
  let mut chosen_offset : Int? = None
  for record in records {
    let rank = match record {
      (0, _encoding, _offset) => 0
      (3, 10, _offset) => 1
      (3, 1, _offset) => 2
      (3, 0, _offset) => 3
      _ => continue
    }
    if rank < chosen_rank {
      chosen_rank = rank
      chosen_offset = Some(record.2)
    }
  }
  chosen_offset
}

///|
fn pdf_sfnt_collect_gid_unicode_pairs(
  bytes : Bytes,
  subtable_offset : Int,
) -> (Array[Int], Array[String]) {
  let gids : Array[Int] = []
  let values : Array[String] = []
  if subtable_offset + 2 > bytes.length() {
    return (gids, values)
  }
  let format = pdf_decode_big_endian_int(bytes, subtable_offset, 2)
  let gid_to_text : Map[Int, String] = Map([])
  match format {
    0 => pdf_sfnt_parse_cmap_format0(bytes, subtable_offset, gid_to_text)
    4 => pdf_sfnt_parse_cmap_format4(bytes, subtable_offset, gid_to_text)
    6 => pdf_sfnt_parse_cmap_format6(bytes, subtable_offset, gid_to_text)
    12 => pdf_sfnt_parse_cmap_format12(bytes, subtable_offset, gid_to_text)
    _ => ()
  }
  let sorted = gid_to_text.to_array()
  sorted.sort_by(fn(left, right) {
    if left.0 < right.0 {
      -1
    } else if left.0 > right.0 {
      1
    } else {
      0
    }
  })
  for entry in sorted {
    gids.push(entry.0)
    values.push(entry.1)
  }
  (gids, values)
}

///|
fn pdf_sfnt_parse_cmap_format0(
  bytes : Bytes,
  offset : Int,
  gid_to_text : Map[Int, String],
) -> Unit {
  if offset + 262 > bytes.length() {
    return
  }
  for i in 0..<256 {
    let gid = pdf_byte_at(bytes, offset + 6 + i)
    if gid > 0 && gid_to_text.get(gid) == None {
      gid_to_text.set(gid, pdf_string_from_codepoints([i]))
    }
  }
}

///|
fn pdf_sfnt_parse_cmap_format6(
  bytes : Bytes,
  offset : Int,
  gid_to_text : Map[Int, String],
) -> Unit {
  if offset + 10 > bytes.length() {
    return
  }
  let first_code = pdf_decode_big_endian_int(bytes, offset + 6, 2)
  let entry_count = pdf_decode_big_endian_int(bytes, offset + 8, 2)
  let mut cursor = offset + 10
  for i in 0..<entry_count {
    if cursor + 2 > bytes.length() {
      break
    }
    let gid = pdf_decode_big_endian_int(bytes, cursor, 2)
    if gid > 0 && gid_to_text.get(gid) == None {
      gid_to_text.set(gid, pdf_string_from_codepoints([first_code + i]))
    }
    cursor += 2
  }
}

///|
fn pdf_sfnt_parse_cmap_format12(
  bytes : Bytes,
  offset : Int,
  gid_to_text : Map[Int, String],
) -> Unit {
  if offset + 16 > bytes.length() {
    return
  }
  let group_count = pdf_decode_big_endian_int(bytes, offset + 12, 4)
  let mut cursor = offset + 16
  for _ in 0..<group_count {
    if cursor + 12 > bytes.length() {
      break
    }
    let start_char = pdf_decode_big_endian_int(bytes, cursor, 4)
    let end_char = pdf_decode_big_endian_int(bytes, cursor + 4, 4)
    let start_gid = pdf_decode_big_endian_int(bytes, cursor + 8, 4)
    for codepoint in start_char..<(end_char + 1) {
      let gid = start_gid + (codepoint - start_char)
      if gid > 0 && gid_to_text.get(gid) == None && codepoint <= 0x10FFFF {
        gid_to_text.set(gid, pdf_string_from_codepoints([codepoint]))
      }
    }
    cursor += 12
  }
}

///|
fn pdf_sfnt_parse_cmap_format4(
  bytes : Bytes,
  offset : Int,
  gid_to_text : Map[Int, String],
) -> Unit {
  if offset + 16 > bytes.length() {
    return
  }
  let seg_count = pdf_decode_big_endian_int(bytes, offset + 6, 2) / 2
  let end_codes_offset = offset + 14
  let start_codes_offset = end_codes_offset + seg_count * 2 + 2
  let id_delta_offset = start_codes_offset + seg_count * 2
  let id_range_offset_offset = id_delta_offset + seg_count * 2
  for segment in 0..<seg_count {
    let end_code = pdf_decode_big_endian_int(
      bytes,
      end_codes_offset + segment * 2,
      2,
    )
    let start_code = pdf_decode_big_endian_int(
      bytes,
      start_codes_offset + segment * 2,
      2,
    )
    let id_delta = pdf_decode_big_endian_int(
      bytes,
      id_delta_offset + segment * 2,
      2,
    )
    let id_range_offset = pdf_decode_big_endian_int(
      bytes,
      id_range_offset_offset + segment * 2,
      2,
    )
    if start_code > end_code || end_code == 0xFFFF {
      continue
    }
    for codepoint in start_code..<(end_code + 1) {
      let gid = if id_range_offset == 0 {
        (codepoint + id_delta) & 0xFFFF
      } else {
        let glyph_offset = id_range_offset_offset +
          segment * 2 +
          id_range_offset +
          (codepoint - start_code) * 2
        if glyph_offset + 2 > bytes.length() {
          continue
        }
        let raw_gid = pdf_decode_big_endian_int(bytes, glyph_offset, 2)
        if raw_gid == 0 {
          0
        } else {
          (raw_gid + id_delta) & 0xFFFF
        }
      }
      if gid > 0 && gid_to_text.get(gid) == None {
        gid_to_text.set(gid, pdf_string_from_codepoints([codepoint]))
      }
    }
  }
}

///|
fn pdf_cff_private_default_width(bytes : Bytes) -> Int? {
  pdf_cff_private_dict_value(bytes, 20)
}

///|
fn pdf_cff_private_nominal_width(bytes : Bytes) -> Int? {
  pdf_cff_private_dict_value(bytes, 21)
}

///|
fn pdf_cff_private_dict_value(bytes : Bytes, target_op : Int) -> Int? {
  let (top_dict_bytes, top_strings) = match
    pdf_cff_top_dict_and_strings(bytes) {
    Some(value) => value
    None => return None
  }
  let top_entries = pdf_cff_parse_dict_entries(top_dict_bytes)
  let private_entry = match top_entries.get(18) {
    Some(values) if values.length() >= 2 => values
    _ => return None
  }
  let private_size = private_entry[0]
  let private_offset = private_entry[1]
  if private_offset < 0 ||
    private_size <= 0 ||
    private_offset + private_size > bytes.length() {
    return None
  }
  ignore(top_strings)
  let private_bytes = bytes[private_offset:private_offset + private_size].to_owned()
  let private_entries = pdf_cff_parse_dict_entries(private_bytes)
  match private_entries.get(target_op) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}

///|
fn pdf_cff_top_dict_and_strings(bytes : Bytes) -> (Bytes, Array[String])? {
  if bytes.length() < 4 {
    return None
  }
  let name_index = pdf_cff_read_index(bytes, 4)
  let top_index = pdf_cff_read_index(bytes, name_index.1)
  let string_index = pdf_cff_read_index(bytes, top_index.1)
  match top_index.0 {
    [top_dict, ..] =>
      Some((top_dict, pdf_cff_strings_from_index(string_index.0)))
    _ => None
  }
}

///|
fn pdf_cff_read_index(bytes : Bytes, offset : Int) -> (Array[Bytes], Int) {
  if offset + 2 > bytes.length() {
    return ([], bytes.length())
  }
  let count = pdf_decode_big_endian_int(bytes, offset, 2)
  if count == 0 {
    return ([], offset + 2)
  }
  if offset + 3 > bytes.length() {
    return ([], bytes.length())
  }
  let off_size = pdf_byte_at(bytes, offset + 2)
  let offsets_start = offset + 3
  let data_start = offsets_start + (count + 1) * off_size
  if data_start > bytes.length() || off_size <= 0 {
    return ([], bytes.length())
  }
  let offsets : Array[Int] = []
  for i in 0..<(count + 1) {
    offsets.push(
      pdf_decode_big_endian_int(bytes, offsets_start + i * off_size, off_size),
    )
  }
  let objects : Array[Bytes] = []
  for i in 0..<count {
    let start = data_start + offsets[i] - 1
    let end_ = data_start + offsets[i + 1] - 1
    if start < data_start || end_ < start || end_ > bytes.length() {
      return (objects, bytes.length())
    }
    objects.push(bytes[start:end_].to_owned())
  }
  (objects, data_start + offsets[count] - 1)
}

///|
fn pdf_cff_strings_from_index(index : Array[Bytes]) -> Array[String] {
  let out : Array[String] = []
  for entry in index {
    out.push(pdf_byte_string(entry))
  }
  out
}

///|
fn pdf_cff_parse_dict_entries(dict_bytes : Bytes) -> Map[Int, Array[Int]] {
  let entries : Map[Int, Array[Int]] = Map([])
  let operands : Array[Int] = []
  let mut index = 0
  while index < dict_bytes.length() {
    let byte = pdf_byte_at(dict_bytes, index)
    if byte <= 21 {
      let op = if byte == 12 && index + 1 < dict_bytes.length() {
        index += 1
        1200 + pdf_byte_at(dict_bytes, index)
      } else {
        byte
      }
      let values : Array[Int] = []
      values.append(operands[:])
      entries.set(op, values)
      operands.clear()
      index += 1
      continue
    }
    match pdf_cff_read_number(dict_bytes, index) {
      Some((value, next_index)) => {
        operands.push(value)
        index = next_index
      }
      None => break
    }
  }
  entries
}

///|
fn pdf_cff_read_number(bytes : Bytes, index : Int) -> (Int, Int)? {
  if index >= bytes.length() {
    return None
  }
  let b0 = pdf_byte_at(bytes, index)
  if b0 >= 32 && b0 <= 246 {
    return Some((b0 - 139, index + 1))
  }
  if b0 >= 247 && b0 <= 250 && index + 1 < bytes.length() {
    return Some(
      ((b0 - 247) * 256 + pdf_byte_at(bytes, index + 1) + 108, index + 2),
    )
  }
  if b0 >= 251 && b0 <= 254 && index + 1 < bytes.length() {
    return Some(
      (0 - ((b0 - 251) * 256 + pdf_byte_at(bytes, index + 1) + 108), index + 2),
    )
  }
  if b0 == 28 && index + 2 < bytes.length() {
    let raw = pdf_decode_big_endian_int(bytes, index + 1, 2)
    let value = if raw > 32767 { raw - 65536 } else { raw }
    return Some((value, index + 3))
  }
  if b0 == 29 && index + 4 < bytes.length() {
    let raw = pdf_decode_big_endian_int(bytes, index + 1, 4)
    return Some((raw, index + 5))
  }
  None
}

///|
fn pdf_lookup_sorted_int_string_pairs(
  keys : Array[Int],
  values : Array[String],
  key : Int,
) -> String? {
  if keys.length() == 0 || keys.length() != values.length() {
    return None
  }
  let mut left = 0
  let mut right = keys.length() - 1
  while left <= right {
    let middle = (left + right) / 2
    if keys[middle] == key {
      return Some(values[middle])
    }
    if keys[middle] < key {
      left = middle + 1
    } else if middle == 0 {
      break
    } else {
      right = middle - 1
    }
  }
  None
}

///|
fn pdf_scale_font_units_to_1000(value : Int, units_per_em : Int) -> Int {
  if units_per_em <= 0 {
    value
  } else {
    (value * 1000 + units_per_em / 2) / units_per_em
  }
}
