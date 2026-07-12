///|
priv struct PdfDecodedFontUnit {
  byte_width : Int
  charcode : Int
  cid : Int?
  gid : Int?
  text : String
}

///|
priv struct PdfDecodedFontBytes {
  text : String
  units : Array[PdfDecodedFontUnit]
}

///|
fn pdf_collect_simple_font_widths(font_dict_text : String) -> Map[Int, Int] {
  let widths : Map[Int, Int] = Map([])
  let first_char = match pdf_extract_int_after(font_dict_text, "/FirstChar") {
    Some(value) => value
    None => return widths
  }
  let width_tokens = match pdf_extract_dict_value(font_dict_text, "/Widths") {
    Some(PdfNativeDictValue::Array(tokens)) => tokens
    _ => return widths
  }
  let mut code = first_char
  for token in width_tokens {
    match pdf_token_number(token) {
      Some(value) if pdf_double_is_integral(value) => {
        widths.set(code, value.to_int())
        code += 1
      }
      _ => ()
    }
  }
  widths
}

///|
fn pdf_collect_font_missing_width(
  font_dict_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> Int? {
  let descriptor_ref = match
    pdf_extract_object_reference_after(font_dict_text, "/FontDescriptor") {
    Some(value) => value
    None => return None
  }
  let descriptor = match object_index.get(descriptor_ref) {
    Some(value) => value
    None => return None
  }
  pdf_extract_int_after(descriptor.dict_text, "/MissingWidth")
}

///|
fn pdf_collect_cid_font_width_pairs(cid_font_dict_text : String) -> Array[Int] {
  let pairs : Array[Int] = []
  let tokens = match pdf_extract_dict_value(cid_font_dict_text, "/W") {
    Some(PdfNativeDictValue::Array(items)) => items
    _ => return pairs
  }
  let mut index = 0
  while index < tokens.length() {
    let start_cid = match pdf_token_number(tokens[index]) {
      Some(value) if pdf_double_is_integral(value) => value.to_int()
      _ => {
        index += 1
        continue
      }
    }
    if index + 1 >= tokens.length() {
      break
    }
    match tokens[index + 1] {
      PdfNativeContentToken::Array(values) => {
        let mut cid = start_cid
        for token in values {
          match pdf_token_number(token) {
            Some(width) if pdf_double_is_integral(width) => {
              pairs.push(cid)
              pairs.push(width.to_int())
              cid += 1
            }
            _ => ()
          }
        }
        index += 2
      }
      _ =>
        if index + 2 < tokens.length() {
          match
            (
              pdf_token_number(tokens[index + 1]),
              pdf_token_number(tokens[index + 2]),
            ) {
            (Some(end_cid), Some(width)) =>
              if pdf_double_is_integral(end_cid) &&
                pdf_double_is_integral(width) {
                let last_cid = end_cid.to_int()
                let resolved_width = width.to_int()
                for cid in start_cid..<(last_cid + 1) {
                  pairs.push(cid)
                  pairs.push(resolved_width)
                }
                index += 3
              } else {
                index += 1
              }
            _ => index += 1
          }
        } else {
          break
        }
    }
  }
  pairs
}

///|
fn pdf_collect_cid_default_width(cid_font_dict_text : String) -> Int? {
  pdf_extract_int_after(cid_font_dict_text, "/DW")
}

///|
fn pdf_collect_cid_vertical_width_pairs(
  cid_font_dict_text : String,
) -> Array[Int] {
  let pairs : Array[Int] = []
  let tokens = match pdf_extract_dict_value(cid_font_dict_text, "/W2") {
    Some(PdfNativeDictValue::Array(items)) => items
    _ => return pairs
  }
  let mut index = 0
  while index < tokens.length() {
    let start_cid = match pdf_token_number(tokens[index]) {
      Some(value) if pdf_double_is_integral(value) => value.to_int()
      _ => {
        index += 1
        continue
      }
    }
    if index + 1 >= tokens.length() {
      break
    }
    match tokens[index + 1] {
      PdfNativeContentToken::Array(values) => {
        let mut cid = start_cid
        let mut value_index = 0
        while value_index + 2 < values.length() {
          match
            (
              pdf_token_number(values[value_index]),
              pdf_token_number(values[value_index + 1]),
              pdf_token_number(values[value_index + 2]),
            ) {
            (Some(w1y), Some(_v1x), Some(_v1y)) =>
              if pdf_double_is_integral(w1y) {
                pairs.push(cid)
                pairs.push(pdf_abs_int(w1y.to_int()))
                cid += 1
              }
            _ => ()
          }
          value_index += 3
        }
        index += 2
      }
      _ =>
        if index + 4 < tokens.length() {
          match
            (
              pdf_token_number(tokens[index + 1]),
              pdf_token_number(tokens[index + 2]),
              pdf_token_number(tokens[index + 3]),
              pdf_token_number(tokens[index + 4]),
            ) {
            (Some(end_cid), Some(w1y), Some(_v1x), Some(_v1y)) =>
              if pdf_double_is_integral(end_cid) && pdf_double_is_integral(w1y) {
                let last_cid = end_cid.to_int()
                let resolved_width = pdf_abs_int(w1y.to_int())
                for cid in start_cid..<(last_cid + 1) {
                  pairs.push(cid)
                  pairs.push(resolved_width)
                }
                index += 5
              } else {
                index += 1
              }
            _ => index += 1
          }
        } else {
          break
        }
    }
  }
  pairs
}

///|
fn pdf_collect_cid_default_vertical_width(cid_font_dict_text : String) -> Int? {
  match pdf_extract_dict_value(cid_font_dict_text, "/DW2") {
    Some(PdfNativeDictValue::Array(values)) if values.length() > 0 =>
      match pdf_token_number(values[0]) {
        Some(width) if pdf_double_is_integral(width) =>
          Some(pdf_abs_int(width.to_int()))
        _ => None
      }
    _ => None
  }
}

///|
fn pdf_lookup_flat_int_pairs(pairs : Array[Int], key : Int) -> Int? {
  if pairs.length() < 2 {
    return None
  }
  let mut left = 0
  let mut right = pairs.length() / 2 - 1
  while left <= right {
    let middle = (left + right) / 2
    let middle_key = pairs[middle * 2]
    if middle_key == key {
      return Some(pairs[middle * 2 + 1])
    }
    if middle_key < key {
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
fn pdf_font_unit_explicit_width_1000(
  info : PdfNativeFontInfo,
  unit : PdfDecodedFontUnit,
) -> Int? {
  if pdf_font_uses_vertical_writing(info) {
    let cid = match unit.cid {
      Some(value) => value
      None => unit.charcode
    }
    match pdf_lookup_flat_int_pairs(info.cid_vertical_width_pairs, cid) {
      Some(width) => return Some(width)
      None =>
        match info.cid_default_vertical_width {
          Some(width) => return Some(width)
          None => ()
        }
    }
  }
  if unit.byte_width == 1 {
    match info.simple_widths.get(unit.charcode) {
      Some(width) => return Some(width)
      None =>
        match info.simple_default_width {
          Some(width) => return Some(width)
          None => ()
        }
    }
  }
  let cid = match unit.cid {
    Some(value) => value
    None =>
      if pdf_font_is_identity_h(info) || pdf_font_is_identity_v(info) {
        unit.charcode
      } else {
        return None
      }
  }
  match pdf_lookup_flat_int_pairs(info.cid_width_pairs, cid) {
    Some(width) => Some(width)
    None => info.cid_default_width
  }
}

///|
fn pdf_font_unit_advance_1000(
  info : PdfNativeFontInfo,
  unit : PdfDecodedFontUnit,
) -> (Int, String) {
  match pdf_font_unit_explicit_width_1000(info, unit) {
    Some(width) => (width, "pdf_dict")
    None =>
      match pdf_embedded_font_program_width_1000(info, unit) {
        Some(width) => (width, "embedded_font")
        None =>
          (pdf_estimate_text_width(unit.text, 1000.0).to_int(), "heuristic")
      }
  }
}

///|
fn pdf_text_decoded_advance_width(
  decoded : PdfDecodedFontBytes,
  info : PdfNativeFontInfo,
  font_size : Double,
  char_spacing : Double,
  word_spacing : Double,
  horizontal_scaling : Double,
) -> Double {
  if decoded.units.length() == 0 {
    return pdf_text_string_advance_width(
      decoded.text,
      font_size,
      char_spacing,
      word_spacing,
      horizontal_scaling,
    )
  }
  let mut base_width = 0.0
  let mut spacing = 0.0
  for unit in decoded.units {
    let (advance_1000, _) = pdf_font_unit_advance_1000(info, unit)
    base_width += font_size * advance_1000.to_double() / 1000.0
    spacing += char_spacing
    if unit.text == " " {
      spacing += word_spacing
    }
  }
  (base_width + spacing) * horizontal_scaling
}

///|
fn pdf_font_width_source_labels(info : PdfNativeFontInfo) -> Array[String] {
  let labels : Array[String] = []
  if info.simple_widths.length() > 0 ||
    info.cid_width_pairs.length() > 0 ||
    info.cid_vertical_width_pairs.length() > 0 {
    labels.push("pdf_dict")
  }
  if info.embedded_font_program is Some(_) {
    labels.push("embedded_font")
  }
  if labels.length() == 0 {
    ["heuristic"]
  } else {
    labels
  }
}

///|
fn pdf_font_decode_path_labels(info : PdfNativeFontInfo) -> Array[String] {
  let labels : Array[String] = []
  if info.has_tounicode || info.unicode_map.length() > 0 {
    labels.push(
      if info.has_tounicode {
        "tounicode"
      } else {
        "encoding_differences"
      },
    )
  }
  if info.tounicode_builtin_name is Some(_) {
    labels.push("tounicode_builtin")
  }
  if info.cid_collection_cmap is Some(_) {
    labels.push("cid_collection_cmap")
    labels.push("predefined_cmap")
  }
  if info.embedded_font_program is Some(_) {
    labels.push("embedded_font_program")
  }
  if info.predefined_cmap is Some(_) {
    labels.push("predefined_cmap")
  }
  if pdf_font_may_use_raw_cjk_decode(info) {
    labels.push("raw_cjk")
  }
  if pdf_font_is_identity_h(info) || pdf_font_is_identity_v(info) {
    labels.push("identity_ascii")
  }
  if labels.length() == 0 {
    ["heuristic"]
  } else {
    labels
  }
}

///|
fn pdf_sorted_metric_labels(labels : Map[String, Bool]) -> Array[String] {
  let out : Array[String] = []
  for entry in labels.to_array() {
    if entry.1 {
      out.push(entry.0)
    }
  }
  out.sort()
  out
}

///|
fn pdf_metric_labels_contain(labels : Array[String], expected : String) -> Bool {
  for label in labels {
    if label == expected {
      return true
    }
  }
  false
}

///|
fn pdf_abs_int(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}
