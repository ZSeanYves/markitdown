///|
priv struct PdfBuiltinPredefinedCMapEntry {
  family : String
  vertical_writing : Bool
  code_width_mask : Int
  base_one_byte_ranges : Array[Int]
  base_two_byte_ranges : Array[Int]
  vertical_override_one_byte_ranges : Array[Int]
  vertical_override_two_byte_ranges : Array[Int]
  range_blob : Bytes?
  base_one_byte_range_offset : Int
  base_one_byte_range_count : Int
  base_two_byte_range_offset : Int
  base_two_byte_range_count : Int
  vertical_override_one_byte_range_offset : Int
  vertical_override_one_byte_range_count : Int
  vertical_override_two_byte_range_offset : Int
  vertical_override_two_byte_range_count : Int
}

///|
priv struct PdfBuiltinUnicodeFamilyData {
  horizontal_runs : Array[Int]
  codepoints : String
  vertical_override_pairs : Array[Int]
  blob : Bytes?
  horizontal_run_offset : Int
  horizontal_run_count : Int
  vertical_override_pair_offset : Int
  vertical_override_pair_count : Int
  codepoint_offset : Int
  codepoint_count : Int
}

///|
priv struct PdfResolvedPredefinedCMap {
  source_name : String?
  family : String?
  vertical_writing : Bool
  code_width_mask : Int
  base_one_byte_ranges : Array[Int]
  base_two_byte_ranges : Array[Int]
  vertical_override_one_byte_ranges : Array[Int]
  vertical_override_two_byte_ranges : Array[Int]
  range_blob : Bytes?
  base_one_byte_range_offset : Int
  base_one_byte_range_count : Int
  base_two_byte_range_offset : Int
  base_two_byte_range_count : Int
  vertical_override_one_byte_range_offset : Int
  vertical_override_one_byte_range_count : Int
  vertical_override_two_byte_range_offset : Int
  vertical_override_two_byte_range_count : Int
  direct_decode_kind : String?
}

///|
fn pdf_resolve_predefined_cmap(name : String) -> PdfResolvedPredefinedCMap? {
  match pdf_builtin_predefined_cmap_entry(name) {
    Some(entry) =>
      Some({
        source_name: Some(name),
        family: Some(entry.family),
        vertical_writing: entry.vertical_writing,
        code_width_mask: entry.code_width_mask,
        base_one_byte_ranges: entry.base_one_byte_ranges,
        base_two_byte_ranges: entry.base_two_byte_ranges,
        vertical_override_one_byte_ranges: entry.vertical_override_one_byte_ranges,
        vertical_override_two_byte_ranges: entry.vertical_override_two_byte_ranges,
        range_blob: entry.range_blob,
        base_one_byte_range_offset: entry.base_one_byte_range_offset,
        base_one_byte_range_count: entry.base_one_byte_range_count,
        base_two_byte_range_offset: entry.base_two_byte_range_offset,
        base_two_byte_range_count: entry.base_two_byte_range_count,
        vertical_override_one_byte_range_offset: entry.vertical_override_one_byte_range_offset,
        vertical_override_one_byte_range_count: entry.vertical_override_one_byte_range_count,
        vertical_override_two_byte_range_offset: entry.vertical_override_two_byte_range_offset,
        vertical_override_two_byte_range_count: entry.vertical_override_two_byte_range_count,
        direct_decode_kind: None,
      })
    None =>
      match name {
        "Identity-H" =>
          Some(
            pdf_predefined_empty_resolved_cmap(
              Some(name),
              None,
              false,
              0x2,
              Some("identity"),
            ),
          )
        "Identity-V" =>
          Some(
            pdf_predefined_empty_resolved_cmap(
              Some(name),
              None,
              true,
              0x2,
              Some("identity"),
            ),
          )
        "TrueType-UCS2" =>
          Some(
            pdf_predefined_empty_resolved_cmap(
              Some(name),
              None,
              false,
              0x2,
              Some("utf16be"),
            ),
          )
        "Adobe-GB1-UCS2" => pdf_predefined_direct_cid_family("Adobe-GB1", false)
        "Adobe-Japan1-UCS2" =>
          pdf_predefined_direct_cid_family("Adobe-Japan1", false)
        "Adobe-CNS1-UCS2" =>
          pdf_predefined_direct_cid_family("Adobe-CNS1", false)
        "Adobe-Korea1-UCS2" =>
          pdf_predefined_direct_cid_family("Adobe-Korea1", false)
        _ =>
          if pdf_predefined_name_has_utf16_direct_decode(name) {
            Some(
              pdf_predefined_empty_resolved_cmap(
                Some(name),
                None,
                name.has_suffix("-V"),
                0xA,
                Some("utf16be"),
              ),
            )
          } else if pdf_predefined_name_has_utf8_direct_decode(name) {
            Some(
              pdf_predefined_empty_resolved_cmap(
                Some(name),
                None,
                name.has_suffix("-V"),
                0xF,
                Some("utf8"),
              ),
            )
          } else if pdf_predefined_name_has_utf32_direct_decode(name) {
            Some(
              pdf_predefined_empty_resolved_cmap(
                Some(name),
                None,
                name.has_suffix("-V"),
                0x8,
                Some("utf32be"),
              ),
            )
          } else {
            None
          }
      }
  }
}

///|
fn pdf_predefined_empty_resolved_cmap(
  source_name : String?,
  family : String?,
  vertical_writing : Bool,
  code_width_mask : Int,
  direct_decode_kind : String?,
) -> PdfResolvedPredefinedCMap {
  {
    source_name,
    family,
    vertical_writing,
    code_width_mask,
    base_one_byte_ranges: [],
    base_two_byte_ranges: [],
    vertical_override_one_byte_ranges: [],
    vertical_override_two_byte_ranges: [],
    range_blob: None,
    base_one_byte_range_offset: 0,
    base_one_byte_range_count: 0,
    base_two_byte_range_offset: 0,
    base_two_byte_range_count: 0,
    vertical_override_one_byte_range_offset: 0,
    vertical_override_one_byte_range_count: 0,
    vertical_override_two_byte_range_offset: 0,
    vertical_override_two_byte_range_count: 0,
    direct_decode_kind,
  }
}

///|
fn pdf_predefined_direct_cid_family(
  family : String,
  vertical_writing : Bool,
) -> PdfResolvedPredefinedCMap? {
  Some(
    pdf_predefined_empty_resolved_cmap(
      None,
      Some(family),
      vertical_writing,
      0x2,
      Some("cid_family"),
    ),
  )
}

///|
fn pdf_predefined_name_has_utf16_direct_decode(name : String) -> Bool {
  (
    name.has_prefix("UniJIS-") ||
    name.has_prefix("UniJIS2004-") ||
    name.has_prefix("UniJISX0213-") ||
    name.has_prefix("UniJISX02132004-") ||
    name.has_prefix("UniCNS-") ||
    name.has_prefix("UniKS-")
  ) &&
  (name.contains("UTF16") || name.contains("UCS2"))
}

///|
fn pdf_predefined_name_has_utf8_direct_decode(name : String) -> Bool {
  (
    name.has_prefix("UniJIS-") ||
    name.has_prefix("UniJIS2004-") ||
    name.has_prefix("UniJISX0213-") ||
    name.has_prefix("UniJISX02132004-") ||
    name.has_prefix("UniCNS-") ||
    name.has_prefix("UniKS-")
  ) &&
  name.contains("UTF8")
}

///|
fn pdf_predefined_name_has_utf32_direct_decode(name : String) -> Bool {
  (
    name.has_prefix("UniJIS-") ||
    name.has_prefix("UniJIS2004-") ||
    name.has_prefix("UniJISX0213-") ||
    name.has_prefix("UniJISX02132004-") ||
    name.has_prefix("UniCNS-") ||
    name.has_prefix("UniKS-")
  ) &&
  name.contains("UTF32")
}

///|
fn pdf_predefined_cmap_decode_bytes(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  match cmap.direct_decode_kind {
    Some("utf16be") => pdf_predefined_decode_utf16be(bytes, cmap)
    Some("utf8") => pdf_predefined_decode_utf8(bytes, cmap)
    Some("utf32be") => pdf_predefined_decode_utf32be(bytes, cmap)
    Some("cid_family") => pdf_predefined_decode_cid_identity(bytes, cmap)
    Some("identity") => pdf_predefined_decode_identity_ascii(bytes, cmap)
    _ => pdf_predefined_decode_mapped_codes(bytes, cmap)
  }
}

///|
fn pdf_predefined_cmap_tounicode_info(name : String) -> PdfToUnicodeCMapInfo? {
  match name {
    "Identity-H" =>
      Some({
        mapping: Map([]),
        invalid_keys: Map([]),
        widths: [2],
        usecmap_name: None,
        builtin_parent_name: Some(name),
      })
    "Identity-V" =>
      Some({
        mapping: Map([]),
        invalid_keys: Map([]),
        widths: [2],
        usecmap_name: None,
        builtin_parent_name: Some(name),
      })
    "Adobe-GB1-UCS2" =>
      pdf_predefined_tounicode_from_family(name, "Adobe-GB1", false)
    "Adobe-Japan1-UCS2" =>
      pdf_predefined_tounicode_from_family(name, "Adobe-Japan1", false)
    "Adobe-CNS1-UCS2" =>
      pdf_predefined_tounicode_from_family(name, "Adobe-CNS1", false)
    "Adobe-Korea1-UCS2" =>
      pdf_predefined_tounicode_from_family(name, "Adobe-Korea1", false)
    _ => None
  }
}

///|
fn pdf_predefined_tounicode_from_family(
  name : String,
  family : String,
  vertical : Bool,
) -> PdfToUnicodeCMapInfo? {
  let data = match pdf_builtin_unicode_family_data(family) {
    Some(value) => value
    None => return None
  }
  let mapping = pdf_predefined_family_unicode_mapping(data, vertical)
  Some({
    mapping,
    invalid_keys: Map([]),
    widths: [2],
    usecmap_name: None,
    builtin_parent_name: Some(name),
  })
}

///|
fn pdf_predefined_family_unicode_mapping(
  data : PdfBuiltinUnicodeFamilyData,
  vertical : Bool,
) -> Map[String, String] {
  let mapping : Map[String, String] = Map([])
  match data.blob {
    Some(blob) => {
      let mut run_index = 0
      while run_index < data.horizontal_run_count {
        let start_cid = pdf_blob_u16_triplet_field(
          blob,
          data.horizontal_run_offset,
          run_index,
          0,
        )
        let run_len = pdf_blob_u16_triplet_field(
          blob,
          data.horizontal_run_offset,
          run_index,
          1,
        )
        let offset = pdf_blob_u16_triplet_field(
          blob,
          data.horizontal_run_offset,
          run_index,
          2,
        )
        if run_len > 0 &&
          offset >= 0 &&
          offset + run_len <= data.codepoint_count {
          for delta in 0..<run_len {
            match
              pdf_blob_bmp_codepoint_at(
                blob,
                data.codepoint_offset,
                offset + delta,
              ) {
              Some(codepoint) =>
                match pdf_predefined_codepoint_text(codepoint) {
                  Some(text) =>
                    mapping.set(pdf_hex_upper(start_cid + delta, 4), text)
                  None => ()
                }
              None => ()
            }
          }
        }
        run_index += 1
      }
      if vertical {
        let mut override_index = 0
        while override_index < data.vertical_override_pair_count {
          let cid = pdf_blob_u16_pair_field(
            blob,
            data.vertical_override_pair_offset,
            override_index,
            0,
          )
          let codepoint = pdf_blob_u16_pair_field(
            blob,
            data.vertical_override_pair_offset,
            override_index,
            1,
          )
          match pdf_predefined_codepoint_text(codepoint) {
            Some(text) => mapping.set(pdf_hex_upper(cid, 4), text)
            None => ()
          }
          override_index += 1
        }
      }
    }
    None => {
      let runs = data.horizontal_runs
      let codepoints = data.codepoints
      let mut index = 0
      while index + 2 < runs.length() {
        let start_cid = runs[index]
        let run_len = runs[index + 1]
        let offset = runs[index + 2]
        if run_len > 0 && offset >= 0 && offset + run_len <= codepoints.length() {
          for delta in 0..<run_len {
            match pdf_predefined_codepoint_text_at(codepoints, offset + delta) {
              Some(text) =>
                mapping.set(pdf_hex_upper(start_cid + delta, 4), text)
              None => ()
            }
          }
        }
        index += 3
      }
      if vertical {
        let overrides = data.vertical_override_pairs
        let mut override_index = 0
        while override_index + 1 < overrides.length() {
          match pdf_predefined_codepoint_text(overrides[override_index + 1]) {
            Some(text) =>
              mapping.set(pdf_hex_upper(overrides[override_index], 4), text)
            None => ()
          }
          override_index += 2
        }
      }
    }
  }
  mapping
}

///|
fn pdf_predefined_decode_mapped_codes(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  let family = match cmap.family {
    Some(value) => value
    None => return None
  }
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index < bytes.length() {
    let unit = match
      pdf_predefined_decode_next_mapped_unit(bytes, index, cmap, family) {
      Some(value) => value
      None => break
    }
    parts.push(unit.text)
    units.push(unit)
    index += unit.byte_width
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_predefined_decode_next_mapped_unit(
  bytes : Array[Int],
  start : Int,
  cmap : PdfResolvedPredefinedCMap,
  family : String,
) -> PdfDecodedFontUnit? {
  for width in pdf_predefined_decode_candidate_widths(cmap, bytes, start) {
    match
      pdf_predefined_decode_next_mapped_unit_at_width(
        bytes, start, cmap, family, width,
      ) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn pdf_predefined_decode_candidate_widths(
  cmap : PdfResolvedPredefinedCMap,
  bytes : Array[Int],
  start : Int,
) -> Array[Int] {
  let has_one = pdf_predefined_code_width_mask_contains(cmap.code_width_mask, 1)
  let has_two = pdf_predefined_code_width_mask_contains(cmap.code_width_mask, 2)
  if has_one && has_two {
    let first_byte = if start < bytes.length() {
      bytes[start] & 0xFF
    } else {
      0
    }
    if pdf_predefined_prefers_single_byte_first(cmap, first_byte) {
      [1, 2]
    } else {
      [2, 1]
    }
  } else if has_two {
    [2]
  } else if has_one {
    [1]
  } else {
    []
  }
}

///|
fn pdf_predefined_prefers_single_byte_first(
  cmap : PdfResolvedPredefinedCMap,
  first_byte : Int,
) -> Bool {
  match cmap.source_name {
    Some(name) =>
      if name.has_prefix("90ms-RKSJ-") || name.has_prefix("83pv-RKSJ-") {
        first_byte <= 0x80 || (first_byte >= 0xA1 && first_byte <= 0xDF)
      } else {
        first_byte <= 0x7F
      }
    None => first_byte <= 0x7F
  }
}

///|
fn pdf_predefined_decode_next_mapped_unit_at_width(
  bytes : Array[Int],
  start : Int,
  cmap : PdfResolvedPredefinedCMap,
  family : String,
  width : Int,
) -> PdfDecodedFontUnit? {
  if !pdf_predefined_code_width_mask_contains(cmap.code_width_mask, width) ||
    width <= 0 ||
    start + width > bytes.length() {
    return None
  }
  let code = pdf_embedded_font_charcode_from_bytes(bytes, start, width)
  let cid = match pdf_predefined_cmap_lookup_cid(cmap, width, code) {
    Some(value) => value
    None => return None
  }
  let text = match
    pdf_predefined_family_unicode_value(family, cmap.vertical_writing, cid) {
    Some(value) => value
    None => return None
  }
  Some({ byte_width: width, charcode: code, cid: Some(cid), gid: None, text })
}

///|
fn pdf_predefined_decode_cid_identity(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  let family = match cmap.family {
    Some(value) => value
    None => return None
  }
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 1 < bytes.length() {
    let cid = pdf_embedded_font_charcode_from_bytes(bytes, index, 2)
    let text = match
      pdf_predefined_family_unicode_value(family, cmap.vertical_writing, cid) {
      Some(value) => value
      None => break
    }
    parts.push(text)
    units.push({ byte_width: 2, charcode: cid, cid: Some(cid), gid: None, text })
    index += 2
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_predefined_decode_identity_ascii(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  ignore(cmap)
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 1 < bytes.length() {
    let code = pdf_embedded_font_charcode_from_bytes(bytes, index, 2)
    if code >= 0 && code <= 0x7F {
      let text = pdf_string_from_codepoints([code])
      parts.push(text)
      units.push({
        byte_width: 2,
        charcode: code,
        cid: Some(code),
        gid: None,
        text,
      })
      index += 2
    } else {
      break
    }
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_predefined_decode_utf16be(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  ignore(cmap)
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 1 < bytes.length() {
    let first = pdf_embedded_font_charcode_from_bytes(bytes, index, 2)
    if first >= 0xD800 && first <= 0xDBFF && index + 3 < bytes.length() {
      let second = pdf_embedded_font_charcode_from_bytes(bytes, index + 2, 2)
      if second >= 0xDC00 && second <= 0xDFFF {
        let codepoint = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
        let text = pdf_string_from_codepoints([codepoint])
        parts.push(text)
        units.push({
          byte_width: 4,
          charcode: codepoint,
          cid: None,
          gid: None,
          text,
        })
        index += 4
        continue
      }
    }
    let text = pdf_string_from_codepoints([first])
    parts.push(text)
    units.push({ byte_width: 2, charcode: first, cid: None, gid: None, text })
    index += 2
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_predefined_decode_utf32be(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  ignore(cmap)
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 3 < bytes.length() {
    let codepoint = pdf_embedded_font_charcode_from_bytes(bytes, index, 4)
    if codepoint < 0 || codepoint > 0x10FFFF {
      break
    }
    let text = pdf_string_from_codepoints([codepoint])
    parts.push(text)
    units.push({
      byte_width: 4,
      charcode: codepoint,
      cid: None,
      gid: None,
      text,
    })
    index += 4
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_predefined_decode_utf8(
  bytes : Array[Int],
  cmap : PdfResolvedPredefinedCMap,
) -> PdfDecodedFontBytes? {
  ignore(cmap)
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index < bytes.length() {
    let width = pdf_utf8_sequence_width(bytes[index] & 0xFF)
    if width <= 0 || index + width > bytes.length() {
      break
    }
    let payload : Array[Byte] = []
    for cursor in index..<(index + width) {
      payload.push((bytes[cursor] & 0xFF).to_byte())
    }
    let text = try
      @utf8.decode(Bytes::from_array(payload), ignore_bom=false) |> Some
    catch {
      _ => None
    }
    match text {
      Some(value) if value != "" => {
        let chars = value.to_array()
        if chars.length() != 1 {
          break
        }
        parts.push(value)
        units.push({
          byte_width: width,
          charcode: chars[0].to_int(),
          cid: None,
          gid: None,
          text: value,
        })
        index += width
      }
      _ => break
    }
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_utf8_sequence_width(first_byte : Int) -> Int {
  if first_byte <= 0x7F {
    1
  } else if first_byte >= 0xC2 && first_byte <= 0xDF {
    2
  } else if first_byte >= 0xE0 && first_byte <= 0xEF {
    3
  } else if first_byte >= 0xF0 && first_byte <= 0xF4 {
    4
  } else {
    0
  }
}

///|
fn pdf_predefined_code_widths_from_mask(code_width_mask : Int) -> Array[Int] {
  let widths : Array[Int] = []
  for width in [4, 3, 2, 1] {
    if pdf_predefined_code_width_mask_contains(code_width_mask, width) {
      widths.push(width)
    }
  }
  widths
}

///|
fn pdf_predefined_code_width_mask_contains(
  code_width_mask : Int,
  width : Int,
) -> Bool {
  if width <= 0 || width > 4 {
    false
  } else {
    (code_width_mask & (1 << (width - 1))) != 0
  }
}

///|
fn pdf_predefined_cmap_lookup_cid(
  cmap : PdfResolvedPredefinedCMap,
  width : Int,
  code : Int,
) -> Int? {
  if !pdf_predefined_code_width_mask_contains(cmap.code_width_mask, width) {
    return None
  }
  let (
    base_ranges,
    override_ranges,
    base_offset,
    base_count,
    override_offset,
    override_count,
  ) = match width {
    1 =>
      (
        cmap.base_one_byte_ranges,
        cmap.vertical_override_one_byte_ranges,
        cmap.base_one_byte_range_offset,
        cmap.base_one_byte_range_count,
        cmap.vertical_override_one_byte_range_offset,
        cmap.vertical_override_one_byte_range_count,
      )
    2 =>
      (
        cmap.base_two_byte_ranges,
        cmap.vertical_override_two_byte_ranges,
        cmap.base_two_byte_range_offset,
        cmap.base_two_byte_range_count,
        cmap.vertical_override_two_byte_range_offset,
        cmap.vertical_override_two_byte_range_count,
      )
    _ => return None
  }
  let override_match = match cmap.range_blob {
    Some(blob) if override_count > 0 =>
      pdf_predefined_lookup_linear_range_blob(
        blob, override_offset, override_count, code,
      )
    _ => pdf_predefined_lookup_linear_range(override_ranges, code)
  }
  match override_match {
    Some(value) if value < 0 => None
    Some(value) => Some(value)
    None =>
      match cmap.range_blob {
        Some(blob) if base_count > 0 =>
          pdf_predefined_lookup_linear_range_blob(
            blob, base_offset, base_count, code,
          )
        _ => pdf_predefined_lookup_linear_range(base_ranges, code)
      }
  }
}

///|
fn pdf_predefined_lookup_linear_range(ranges : Array[Int], key : Int) -> Int? {
  if ranges.length() < 3 {
    return None
  }
  let mut left = 0
  let mut right = ranges.length() / 3 - 1
  while left <= right {
    let middle = (left + right) / 2
    let base = middle * 3
    let start_key = ranges[base]
    let start_value = ranges[base + 1]
    let run_len = ranges[base + 2]
    let end_key = start_key + run_len - 1
    if key < start_key {
      if middle == 0 {
        break
      }
      right = middle - 1
    } else if key > end_key {
      left = middle + 1
    } else if start_value < 0 {
      return Some(start_value)
    } else {
      return Some(start_value + (key - start_key))
    }
  }
  None
}

///|
fn pdf_predefined_lookup_linear_range_blob(
  blob : Bytes,
  byte_offset : Int,
  entry_count : Int,
  key : Int,
) -> Int? {
  if entry_count <= 0 {
    return None
  }
  let mut left = 0
  let mut right = entry_count - 1
  while left <= right {
    let middle = (left + right) / 2
    let start_key = pdf_blob_u16_triplet_field(blob, byte_offset, middle, 0)
    let raw_start_value = pdf_blob_u16_triplet_field(
      blob, byte_offset, middle, 1,
    )
    let start_value = if raw_start_value == 0xFFFF {
      -1
    } else {
      raw_start_value
    }
    let run_len = pdf_blob_u16_triplet_field(blob, byte_offset, middle, 2)
    let end_key = start_key + run_len - 1
    if key < start_key {
      if middle == 0 {
        break
      }
      right = middle - 1
    } else if key > end_key {
      left = middle + 1
    } else if start_value < 0 {
      return Some(start_value)
    } else {
      return Some(start_value + (key - start_key))
    }
  }
  None
}

///|
fn pdf_predefined_family_unicode_value(
  family : String,
  vertical : Bool,
  cid : Int,
) -> String? {
  let data = match pdf_builtin_unicode_family_data(family) {
    Some(value) => value
    None => return None
  }
  match data.blob {
    Some(blob) => {
      if vertical {
        match
          pdf_predefined_lookup_blob_pair_value(
            blob,
            data.vertical_override_pair_offset,
            data.vertical_override_pair_count,
            cid,
          ) {
          Some(codepoint) =>
            match pdf_predefined_codepoint_text(codepoint) {
              Some(text) => return Some(text)
              None => ()
            }
          None => ()
        }
      }
      match
        pdf_predefined_lookup_codepoint_in_runs_blob(
          blob,
          data.horizontal_run_offset,
          data.horizontal_run_count,
          data.codepoint_offset,
          data.codepoint_count,
          cid,
        ) {
        Some(codepoint) => pdf_predefined_codepoint_text(codepoint)
        None => None
      }
    }
    None => {
      if vertical {
        match pdf_lookup_flat_int_pairs(data.vertical_override_pairs, cid) {
          Some(codepoint) =>
            match pdf_predefined_codepoint_text(codepoint) {
              Some(text) => return Some(text)
              None => ()
            }
          None => ()
        }
      }
      match
        pdf_predefined_lookup_codepoint_in_runs(
          data.horizontal_runs,
          data.codepoints,
          cid,
        ) {
        Some(codepoint) => pdf_predefined_codepoint_text(codepoint)
        None => None
      }
    }
  }
}

///|
fn pdf_predefined_lookup_codepoint_in_runs(
  horizontal_runs : Array[Int],
  codepoints : String,
  cid : Int,
) -> Int? {
  if horizontal_runs.length() < 3 {
    return None
  }
  let mut left = 0
  let mut right = horizontal_runs.length() / 3 - 1
  while left <= right {
    let middle = (left + right) / 2
    let base = middle * 3
    let start_cid = horizontal_runs[base]
    let run_len = horizontal_runs[base + 1]
    let offset = horizontal_runs[base + 2]
    let end_cid = start_cid + run_len - 1
    if cid < start_cid {
      if middle == 0 {
        break
      }
      right = middle - 1
    } else if cid > end_cid {
      left = middle + 1
    } else {
      let codepoint_index = offset + (cid - start_cid)
      if codepoint_index >= 0 && codepoint_index < codepoints.length() {
        return pdf_predefined_bmp_codepoint_at(codepoints, codepoint_index)
      }
      return None
    }
  }
  None
}

///|
fn pdf_predefined_lookup_codepoint_in_runs_blob(
  blob : Bytes,
  horizontal_run_offset : Int,
  horizontal_run_count : Int,
  codepoint_offset : Int,
  codepoint_count : Int,
  cid : Int,
) -> Int? {
  if horizontal_run_count <= 0 {
    return None
  }
  let mut left = 0
  let mut right = horizontal_run_count - 1
  while left <= right {
    let middle = (left + right) / 2
    let start_cid = pdf_blob_u16_triplet_field(
      blob, horizontal_run_offset, middle, 0,
    )
    let run_len = pdf_blob_u16_triplet_field(
      blob, horizontal_run_offset, middle, 1,
    )
    let offset = pdf_blob_u16_triplet_field(
      blob, horizontal_run_offset, middle, 2,
    )
    let end_cid = start_cid + run_len - 1
    if cid < start_cid {
      if middle == 0 {
        break
      }
      right = middle - 1
    } else if cid > end_cid {
      left = middle + 1
    } else {
      let codepoint_index = offset + (cid - start_cid)
      if codepoint_index >= 0 && codepoint_index < codepoint_count {
        return pdf_blob_bmp_codepoint_at(
          blob, codepoint_offset, codepoint_index,
        )
      }
      return None
    }
  }
  None
}

///|
fn pdf_predefined_lookup_blob_pair_value(
  blob : Bytes,
  byte_offset : Int,
  entry_count : Int,
  key : Int,
) -> Int? {
  if entry_count <= 0 {
    return None
  }
  let mut left = 0
  let mut right = entry_count - 1
  while left <= right {
    let middle = (left + right) / 2
    let pair_key = pdf_blob_u16_pair_field(blob, byte_offset, middle, 0)
    if key < pair_key {
      if middle == 0 {
        break
      }
      right = middle - 1
    } else if key > pair_key {
      left = middle + 1
    } else {
      return Some(pdf_blob_u16_pair_field(blob, byte_offset, middle, 1))
    }
  }
  None
}

///|
fn pdf_predefined_bmp_codepoint_at(text : String, index : Int) -> Int? {
  if index < 0 || index >= text.length() {
    return None
  }
  let code_unit = text.code_units().unsafe_get(index).to_int()
  if code_unit >= 0xD800 && code_unit <= 0xDFFF {
    None
  } else {
    Some(code_unit)
  }
}

///|
fn pdf_predefined_codepoint_text_at(text : String, index : Int) -> String? {
  match pdf_predefined_bmp_codepoint_at(text, index) {
    Some(codepoint) => pdf_predefined_codepoint_text(codepoint)
    None => None
  }
}

///|
fn pdf_predefined_codepoint_text(codepoint : Int) -> String? {
  if codepoint < 0 || codepoint > 0x10FFFF {
    None
  } else if codepoint >= 0xD800 && codepoint <= 0xDFFF {
    None
  } else {
    Some(pdf_string_from_codepoints([codepoint]))
  }
}
