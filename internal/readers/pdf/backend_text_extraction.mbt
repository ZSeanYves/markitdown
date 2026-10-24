///|
fn pdf_scan_content_tokens(
  content : String,
) -> Result[Array[PdfNativeContentToken], PdfNativeError] {
  let tokens : Array[PdfNativeContentToken] = []
  let mut index = 0
  while index < content.length() {
    index = pdf_skip_content_whitespace_and_comments(content, index)
    if index >= content.length() {
      break
    }
    let ch = pdf_char_at(content, index)
    match ch {
      '(' => {
        let parsed = pdf_parse_literal_token(content, index)
        if !parsed.0.terminated {
          return Err(
            ParseFailed("unterminated PDF literal string in content stream"),
          )
        }
        tokens.push(LiteralString(parsed.0))
        index = parsed.1
      }
      '<' =>
        if index + 1 < content.length() &&
          pdf_char_at(content, index + 1) == '<' {
          let parsed = pdf_parse_dict_token(content, index)
          tokens.push(Dict(parsed.0))
          index = parsed.1
        } else {
          let parsed = pdf_parse_hex_token(content, index)
          tokens.push(HexString(parsed.0))
          index = parsed.1
        }
      '[' => {
        let parsed = match pdf_parse_array_token(content, index) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        tokens.push(Array(parsed.0))
        index = parsed.1
      }
      '/' => {
        let parsed = pdf_parse_name_token(content, index)
        tokens.push(Name(parsed.0))
        index = parsed.1
      }
      _ => {
        let parsed = pdf_parse_word_token(content, index)
        if parsed.1 <= index {
          index += 1
          continue
        }
        match pdf_parse_double(parsed.0) {
          Some(value) => tokens.push(Number(value))
          None => tokens.push(Word(parsed.0))
        }
        index = parsed.1
      }
    }
  }
  Ok(tokens)
}

///|
fn pdf_parse_array_token(
  content : String,
  start : Int32,
) -> Result[(Array[PdfNativeContentToken], Int32), PdfNativeError] {
  let tokens : Array[PdfNativeContentToken] = []
  let mut index = start + 1
  while index < content.length() {
    index = pdf_skip_content_whitespace_and_comments(content, index)
    if index >= content.length() {
      break
    }
    if pdf_char_at(content, index) == ']' {
      return Ok((tokens, index + 1))
    }
    let ch = pdf_char_at(content, index)
    match ch {
      '(' => {
        let parsed = pdf_parse_literal_token(content, index)
        if !parsed.0.terminated {
          return Err(
            ParseFailed("unterminated PDF literal string in array token"),
          )
        }
        tokens.push(LiteralString(parsed.0))
        index = parsed.1
      }
      '<' =>
        if index + 1 < content.length() &&
          pdf_char_at(content, index + 1) == '<' {
          let parsed = pdf_parse_dict_token(content, index)
          tokens.push(Dict(parsed.0))
          index = parsed.1
        } else {
          let parsed = pdf_parse_hex_token(content, index)
          tokens.push(HexString(parsed.0))
          index = parsed.1
        }
      '[' => {
        let parsed = match pdf_parse_array_token(content, index) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        tokens.push(Array(parsed.0))
        index = parsed.1
      }
      '/' => {
        let parsed = pdf_parse_name_token(content, index)
        tokens.push(Name(parsed.0))
        index = parsed.1
      }
      _ => {
        let parsed = pdf_parse_word_token(content, index)
        if parsed.1 <= index {
          index += 1
          continue
        }
        match pdf_parse_double(parsed.0) {
          Some(value) => tokens.push(Number(value))
          None => tokens.push(Word(parsed.0))
        }
        index = parsed.1
      }
    }
  }
  Err(ParseFailed("unterminated PDF array token"))
}

///|
fn pdf_parse_literal_token(
  content : String,
  start : Int32,
) -> (PdfNativeTokenizedString, Int32) {
  let out : Array[Char] = []
  let mut index = start + 1
  let mut depth = 1
  while index < content.length() {
    let ch = pdf_char_at(content, index)
    if ch == '\\' {
      if index + 1 >= content.length() {
        index += 1
        break
      }
      let next = pdf_char_at(content, index + 1)
      match next {
        'n' => {
          out.push('\n')
          index += 2
          continue
        }
        'r' => {
          out.push('\r')
          index += 2
          continue
        }
        't' => {
          out.push('\t')
          index += 2
          continue
        }
        'b' => {
          out.push('\u{0008}')
          index += 2
          continue
        }
        'f' => {
          out.push('\u{000C}')
          index += 2
          continue
        }
        '(' => {
          out.push('(')
          index += 2
          continue
        }
        ')' => {
          out.push(')')
          index += 2
          continue
        }
        '\\' => {
          out.push('\\')
          index += 2
          continue
        }
        '\n' => {
          index += 2
          continue
        }
        '\r' => {
          if index + 2 < content.length() &&
            pdf_char_at(content, index + 2) == '\n' {
            index += 3
          } else {
            index += 2
          }
          continue
        }
        _ => {
          if pdf_is_octal_digit(next) {
            let octal = pdf_collect_octal_escape(content, index + 1)
            let code = pdf_parse_octal(octal.0).unwrap_or(0)
            out.push(Int32::unsafe_to_char(code & 0xFF))
            index = octal.1
            continue
          }
          out.push(next)
          index += 2
          continue
        }
      }
    }
    if ch == '(' {
      depth += 1
      out.push(ch)
      index += 1
      continue
    }
    if ch == ')' {
      depth -= 1
      if depth == 0 {
        return (
          { decoded: String::from_array(out), terminated: true, },
          index + 1,
        )
      }
      out.push(ch)
      index += 1
      continue
    }
    out.push(ch)
    index += 1
  }
  ({ decoded: String::from_array(out), terminated: false, }, index)
}

///|
fn pdf_parse_hex_token(content : String, start : Int32) -> (String, Int32) {
  let mut index = start + 1
  let out : Array[Char] = []
  while index < content.length() && pdf_char_at(content, index) != '>' {
    let ch = pdf_char_at(content, index)
    if !pdf_is_ascii_whitespace_char(ch) {
      out.push(ch)
    }
    index += 1
  }
  if out.length() % 2 == 1 {
    out.push('0')
  }
  (String::from_array(out), index + 1)
}

///|
fn pdf_parse_dict_token(content : String, start : Int32) -> (String, Int32) {
  let mut index = start
  let mut depth = 0
  while index + 1 < content.length() {
    if pdf_char_at(content, index) == '<' &&
      pdf_char_at(content, index + 1) == '<' {
      depth += 1
      index += 2
      continue
    }
    if pdf_char_at(content, index) == '>' &&
      pdf_char_at(content, index + 1) == '>' {
      depth -= 1
      index += 2
      if depth == 0 {
        return (content[start:index].to_owned(), index)
      }
      continue
    }
    index += 1
  }
  (content[start:index].to_owned(), index)
}

///|
fn pdf_parse_name_token(content : String, start : Int32) -> (String, Int32) {
  let mut index = start + 1
  while index < content.length() &&
        !pdf_is_token_delimiter(pdf_char_at(content, index)) &&
        !pdf_is_ascii_whitespace_char(pdf_char_at(content, index)) {
    index += 1
  }
  (content[start + 1:index].to_owned(), index)
}

///|
fn pdf_parse_word_token(content : String, start : Int32) -> (String, Int32) {
  let mut index = start
  while index < content.length() &&
        !pdf_is_token_delimiter(pdf_char_at(content, index)) &&
        !pdf_is_ascii_whitespace_char(pdf_char_at(content, index)) {
    index += 1
  }
  (content[start:index].to_owned(), index)
}

///|
fn pdf_skip_content_whitespace_and_comments(
  content : String,
  start : Int32,
) -> Int32 {
  let mut index = start
  while index < content.length() {
    let ch = pdf_char_at(content, index)
    if pdf_is_ascii_whitespace_char(ch) {
      index += 1
      continue
    }
    if ch == '%' {
      index += 1
      while index < content.length() &&
            pdf_char_at(content, index) != '\n' &&
            pdf_char_at(content, index) != '\r' {
        index += 1
      }
      continue
    }
    break
  }
  index
}

///|
fn pdf_fragment_from_text_operand(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  current_matrix : PdfNativeGraphicsMatrix,
  text_matrix : PdfNativeGraphicsMatrix,
  current_font_alias : String?,
  current_font_size : Double?,
  font_info : PdfNativeFontInfo?,
  token : PdfNativeContentToken,
  actual_text : String?,
  text_rise~ : Double = 0.0,
  successful_literal~ : Ref[PdfDecodedFontBytes?]? = None,
) -> PdfNativeTextFragment? {
  let resolved_text = match actual_text {
    Some(value) if value.trim() != "" => value
    _ =>
      match pdf_decode_text_operand(token, font_info, successful_literal~) {
        Some(text) => text
        None => return None
      }
  }
  if resolved_text.trim() == "" {
    return None
  }
  let font_name = match font_info {
    Some(info) => info.base_font
    None => current_font_alias
  }
  let preserves_outer_space = pdf_text_has_outer_space(resolved_text) &&
    pdf_text_outer_space_is_latinish(resolved_text)
  let fragment_text = if preserves_outer_space {
    pdf_normalize_pdf_fragment_text(resolved_text)
  } else {
    pdf_normalize_pdf_text(resolved_text)
  }
  if fragment_text.trim() == "" {
    return None
  }
  let font_size = pdf_effective_font_size(text_matrix, current_font_size)
  let x = current_matrix.e + text_matrix.e
  let y = current_matrix.f +
    text_matrix.f +
    text_rise * pdf_text_matrix_y_scale(text_matrix)
  let bbox = pdf_estimate_text_bbox(fragment_text, x, y, font_size)
  let source_ref = pdf_native_source_ref(
    source,
    geometry.page_no,
    bbox,
    None,
    font_name,
    font_size,
  )
  ignore(source_ref)
  Some({
    text: fragment_text,
    preserves_outer_space,
    x,
    y,
    font_name,
    font_size: Some(font_size),
    bbox,
    vertical_writing: match font_info {
      Some(info) => pdf_font_uses_vertical_writing(info)
      None => false
    },
  })
}

///|
fn pdf_append_text_operand_fragment(
  fragments : Array[PdfNativeTextFragment],
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  current_matrix : PdfNativeGraphicsMatrix,
  text_matrix : PdfNativeGraphicsMatrix,
  current_font_alias : String?,
  current_font_size : Double?,
  font_aliases : Map[String, Int32],
  fonts : Map[Int32, PdfNativeFontInfo],
  token : PdfNativeContentToken,
  actual_text : String?,
  char_spacing : Double,
  word_spacing : Double,
  horizontal_scaling : Double,
  text_rise : Double,
) -> PdfNativeGraphicsMatrix {
  let font_info = pdf_font_info_for_alias(
    current_font_alias, font_aliases, fonts,
  )
  // One synchronous operand owns this success-only receipt. Display decoding
  // fills it only on the existing non-BOM code-unit literal path. Failure,
  // ActualText, Hex and TJ/array paths keep their original decoding behavior.
  let successful_literal : Ref[PdfDecodedFontBytes?]? = match token {
    LiteralString(value) if !value.decoded.has_prefix("\u{00FE}\u{00FF}") &&
      !value.decoded.has_prefix("\u{00FF}\u{00FE}") &&
      !(actual_text is Some(text) && text.trim() != "") &&
      font_info is Some(info) &&
      pdf_font_uses_code_unit_decode(info) => Some(Ref(None))
    _ => None
  }
  match
    pdf_fragment_from_text_operand(
      source,
      geometry,
      current_matrix,
      text_matrix,
      current_font_alias,
      current_font_size,
      font_info,
      token,
      actual_text,
      text_rise~,
      successful_literal~,
    ) {
    Some(fragment) => fragments.push(fragment)
    None => ()
  }
  let font_size = pdf_effective_font_size(text_matrix, current_font_size)
  let advance = if successful_literal is Some(receipt) &&
    receipt.val is Some(decoded) &&
    font_info is Some(info) {
    pdf_text_decoded_advance_width(
      decoded, info, font_size, char_spacing, word_spacing, horizontal_scaling,
    )
  } else {
    pdf_text_operand_advance_width(
      token, font_info, font_size, char_spacing, word_spacing, horizontal_scaling,
    )
  }
  let vertical_writing = match font_info {
    Some(info) => pdf_font_uses_vertical_writing(info)
    None => false
  }
  if vertical_writing {
    { ..text_matrix, f: text_matrix.f - advance, }
  } else {
    { ..text_matrix, e: text_matrix.e + advance, }
  }
}

///|
fn pdf_font_info_for_alias(
  current_font_alias : String?,
  font_aliases : Map[String, Int32],
  fonts : Map[Int32, PdfNativeFontInfo],
) -> PdfNativeFontInfo? {
  let font_object_id = match current_font_alias {
    Some(font_alias_name) => font_aliases.get(font_alias_name)
    None => None
  }
  match font_object_id {
    Some(object_id) => fonts.get(object_id)
    None => None
  }
}

///|
fn pdf_decode_text_operand(
  token : PdfNativeContentToken,
  font_info : PdfNativeFontInfo?,
  successful_literal~ : Ref[PdfDecodedFontBytes?]? = None,
) -> String? {
  match token {
    LiteralString(value) =>
      Some(
        pdf_decode_content_literal_pdf_text(
          value.decoded,
          font_info,
          successful_literal~,
        ),
      )
    HexString(hex) => pdf_decode_hex_pdf_text(hex, font_info)
    Array(items) =>
      match pdf_decode_joined_hex_array(items, font_info) {
        Some(text) => Some(text)
        None => {
          let parts : Array[String] = []
          for item in items {
            match item {
              LiteralString(value) =>
                parts.push(
                  pdf_decode_content_literal_pdf_text(value.decoded, font_info),
                )
              HexString(hex) =>
                match pdf_decode_hex_pdf_text(hex, font_info) {
                  Some(text) => parts.push(text)
                  None => ()
                }
              _ => ()
            }
          }
          let joined = parts.join("")
          if joined == "" {
            None
          } else {
            Some(joined)
          }
        }
      }
    _ => None
  }
}

///|
fn pdf_text_operand_advance_width(
  token : PdfNativeContentToken,
  font_info : PdfNativeFontInfo?,
  font_size : Double,
  char_spacing : Double,
  word_spacing : Double,
  horizontal_scaling : Double,
) -> Double {
  match token {
    LiteralString(value) =>
      match font_info {
        Some(info) =>
          match
            pdf_decode_literal_bytes_with_font_result(
              pdf_string_byte_values(value.decoded),
              info,
            ) {
            Some(decoded) =>
              pdf_text_decoded_advance_width(
                decoded, info, font_size, char_spacing, word_spacing, horizontal_scaling,
              )
            None =>
              pdf_text_string_advance_width(
                pdf_decode_content_literal_pdf_text(value.decoded, font_info),
                font_size,
                char_spacing,
                word_spacing,
                horizontal_scaling,
              )
          }
        None =>
          pdf_text_string_advance_width(
            pdf_decode_content_literal_pdf_text(value.decoded, font_info),
            font_size,
            char_spacing,
            word_spacing,
            horizontal_scaling,
          )
      }
    HexString(hex) =>
      match font_info {
        Some(info) =>
          match pdf_decode_hex_pdf_text_result(hex, info) {
            Some(decoded) =>
              pdf_text_decoded_advance_width(
                decoded, info, font_size, char_spacing, word_spacing, horizontal_scaling,
              )
            None =>
              match pdf_decode_hex_pdf_text(hex, font_info) {
                Some(text) =>
                  pdf_text_string_advance_width(
                    text, font_size, char_spacing, word_spacing, horizontal_scaling,
                  )
                None => 0.0
              }
          }
        None =>
          match pdf_decode_hex_pdf_text(hex, font_info) {
            Some(text) =>
              pdf_text_string_advance_width(
                text, font_size, char_spacing, word_spacing, horizontal_scaling,
              )
            None => 0.0
          }
      }
    Array(items) => {
      let mut width = 0.0
      for item in items {
        match item {
          Number(value) =>
            width += (0.0 - value) * font_size * horizontal_scaling / 1000.0
          LiteralString(value) =>
            width += pdf_text_operand_advance_width(
              LiteralString(value),
              font_info,
              font_size,
              char_spacing,
              word_spacing,
              horizontal_scaling,
            )
          HexString(hex) =>
            width += pdf_text_operand_advance_width(
              HexString(hex),
              font_info,
              font_size,
              char_spacing,
              word_spacing,
              horizontal_scaling,
            )
          _ => ()
        }
      }
      width
    }
    _ => 0.0
  }
}

///|
fn pdf_text_string_advance_width(
  text : String,
  font_size : Double,
  char_spacing : Double,
  word_spacing : Double,
  horizontal_scaling : Double,
) -> Double {
  if text == "" {
    return 0.0
  }
  let base_width = pdf_estimate_text_width(text, font_size)
  let chars = text.to_array()
  let mut spacing = char_spacing * chars.length().to_double()
  for ch in chars {
    if ch == ' ' {
      spacing += word_spacing
    }
  }
  (base_width + spacing) * horizontal_scaling
}

///|
fn pdf_decode_hex_pdf_text(
  hex : String,
  font_info : PdfNativeFontInfo?,
) -> String? {
  if hex.trim() == "" {
    return None
  }
  match font_info {
    Some(info) => {
      let invalid_tounicode_bytes = match pdf_hex_byte_values(hex) {
        Some(bytes) => pdf_bytes_hit_invalid_tounicode(bytes, info)
        None => false
      }
      match pdf_decode_hex_pdf_text_result(hex, info) {
        Some(decoded) => Some(decoded.text)
        None =>
          if invalid_tounicode_bytes ||
            pdf_font_should_fail_closed_after_tounicode(info) {
            None
          } else {
            match pdf_decode_raw_cjk_hex_fallback(hex, info) {
              Some(decoded) => Some(decoded)
              None => pdf_hex_to_string(hex)
            }
          }
      }
    }
    None => pdf_hex_to_string(hex)
  }
}

///|
fn pdf_decode_joined_hex_array(
  items : Array[PdfNativeContentToken],
  font_info : PdfNativeFontInfo?,
) -> String? {
  let info = match font_info {
    Some(value) => value
    None => return None
  }
  if !pdf_font_uses_code_unit_decode(info) {
    return None
  }
  let hex_parts : Array[String] = []
  for item in items {
    match item {
      HexString(hex) => hex_parts.push(hex)
      Number(_) => ()
      _ => return None
    }
  }
  if hex_parts.length() == 0 {
    return None
  }
  pdf_decode_hex_pdf_text(hex_parts.join(""), Some(info))
}

///|
fn pdf_group_text_fragments_into_lines(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  fragments : Array[PdfNativeTextFragment],
) -> Array[PdfNativeTextLine] {
  let ordered : Array[PdfNativeTextFragment] = []
  ordered.append(fragments[:])
  ordered.sort_by(fn(left, right) {
    pdf_fragment_reading_order_compare(left, right)
  })
  let lines : Array[PdfNativeTextLine] = []
  let mut current : Array[PdfNativeTextFragment] = []
  let mut current_baseline = 0.0
  let mut current_vertical = false
  for fragment in ordered {
    if current.length() == 0 {
      current = [fragment]
      current_baseline = if fragment.vertical_writing {
        fragment.x
      } else {
        fragment.y
      }
      current_vertical = fragment.vertical_writing
      continue
    }
    let tolerance = pdf_line_merge_tolerance(current, fragment)
    let next_vertical = current_vertical || fragment.vertical_writing
    let candidate_baseline = if next_vertical { fragment.x } else { fragment.y }
    if pdf_abs_double(candidate_baseline - current_baseline) <= tolerance {
      current.push(fragment)
      current_baseline = (current_baseline + candidate_baseline) / 2.0
      current_vertical = next_vertical
    } else {
      lines.push(
        pdf_finalize_line(source, geometry, current, lines.length() + 1),
      )
      current = [fragment]
      current_baseline = if fragment.vertical_writing {
        fragment.x
      } else {
        fragment.y
      }
      current_vertical = fragment.vertical_writing
    }
  }
  if current.length() > 0 {
    lines.push(pdf_finalize_line(source, geometry, current, lines.length() + 1))
  }
  lines
}

///|
fn pdf_finalize_line(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  fragments : Array[PdfNativeTextFragment],
  line_index : Int32,
) -> PdfNativeTextLine {
  let vertical_line = fragments.any(fn(fragment) { fragment.vertical_writing })
  let ordered : Array[PdfNativeTextFragment] = []
  ordered.append(fragments[:])
  ordered.sort_by(fn(left, right) {
    if vertical_line {
      pdf_fragment_vertical_compare(left, right)
    } else {
      pdf_fragment_visual_compare(left, right)
    }
  })
  let spans : Array[PdfNativeTextSpan] = []
  let mut merged_bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  let mut reading_index = 1
  for fragment in ordered {
    let gap = if spans.length() == 0 {
      None
    } else if vertical_line {
      None
    } else {
      Some(fragment.x - pdf_bbox_right(merged_bbox))
    }
    let prepared_text = pdf_prepare_line_text_fragment(
      fragment.text,
      gap,
      fragment.font_size,
      preserve_outer_space=fragment.preserves_outer_space,
    )
    let source_ref = pdf_native_source_ref(
      source,
      geometry.page_no,
      fragment.bbox,
      Some(line_index),
      fragment.font_name,
      fragment.font_size.unwrap_or(0.0),
      reading_order_index=Some(reading_index),
    )
    let span = make_pdf_native_text_span(
      prepared_text,
      fragment.bbox,
      source_ref=Some(source_ref),
      font_name=fragment.font_name,
      font_size=fragment.font_size,
      reading_order_index=Some(reading_index),
    )
    spans.push(span)
    merged_bbox = if pdf_bbox_is_empty(merged_bbox) {
      fragment.bbox
    } else {
      pdf_union_bbox(merged_bbox, fragment.bbox)
    }
    reading_index += 1
  }
  let line_source_ref = pdf_native_source_ref(
    source,
    geometry.page_no,
    merged_bbox,
    Some(line_index),
    None,
    0.0,
    reading_order_index=Some(line_index),
  )
  make_pdf_native_text_line(
    spans,
    merged_bbox,
    source_ref=Some(line_source_ref),
    reading_order_index=Some(line_index),
  )
}

///|
fn pdf_group_lines_into_text_blocks(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  lines : Array[PdfNativeTextLine],
) -> Array[PdfNativeTextBlock] {
  let ordered : Array[PdfNativeTextLine] = []
  ordered.append(lines[:])
  ordered.sort_by(fn(left, right) {
    pdf_native_line_reading_order_compare(left, right)
  })
  let blocks : Array[PdfNativeTextBlock] = []
  let mut current : Array[PdfNativeTextLine] = []
  for line in ordered {
    if pdf_native_line_text(line) == "" {
      continue
    }
    if current.length() == 0 {
      current = [line]
      continue
    }
    if pdf_should_merge_line_into_block(current, line) {
      current.push(line)
    } else {
      blocks.push(
        pdf_finalize_text_block(source, geometry, current, blocks.length() + 1),
      )
      current = [line]
    }
  }
  if current.length() > 0 {
    blocks.push(
      pdf_finalize_text_block(source, geometry, current, blocks.length() + 1),
    )
  }
  blocks
}

///|
fn pdf_finalize_text_block(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  lines : Array[PdfNativeTextLine],
  block_index : Int32,
) -> PdfNativeTextBlock {
  let block_bbox = pdf_native_lines_bbox(lines)
  let first_line = lines[0]
  let base_ref = pdf_native_line_base_source_ref(first_line)
  let first_page = base_ref.page.unwrap_or(geometry.page_no)
  let first_line_no = base_ref.line_start.unwrap_or(block_index)
  let last_line_ref = pdf_native_line_base_source_ref(lines[lines.length() - 1])
  let last_line_no = last_line_ref.line_end.unwrap_or(
    last_line_ref.line_start.unwrap_or(first_line_no),
  )
  let block_source_ref = pdf_native_source_ref(
    source,
    first_page,
    block_bbox,
    Some(first_line_no),
    None,
    0.0,
    reading_order_index=first_line.reading_order_index,
  )
  let next = { ..block_source_ref, line_end: Some(last_line_no), }
  next.extra.set("pdf_text_block_index", block_index.to_string())
  make_pdf_native_text_block(
    lines,
    block_bbox,
    source_ref=Some(next),
    reading_order_index=first_line.reading_order_index,
  )
}

///|
fn pdf_should_merge_line_into_block(
  current : Array[PdfNativeTextLine],
  next : PdfNativeTextLine,
) -> Bool {
  if current.length() == 0 {
    return true
  }
  let previous = current[current.length() - 1]
  if pdf_native_line_text(previous) == "" || pdf_native_line_text(next) == "" {
    return false
  }
  if pdf_line_looks_like_list_boundary(previous) ||
    pdf_line_looks_like_list_boundary(next) {
    return false
  }
  if pdf_line_has_strong_terminal_punctuation(previous) {
    return false
  }
  if !pdf_line_looks_like_continuation(next) {
    return false
  }
  let vertical_gap = pdf_native_line_vertical_gap(previous, next)
  let max_height = pdf_double_max(previous.bbox.height, next.bbox.height)
  if vertical_gap > pdf_double_max(6.0, max_height * 1.2) {
    return false
  }
  let left_shift = pdf_abs_double(previous.bbox.x - next.bbox.x)
  let max_width = pdf_double_max(previous.bbox.width, next.bbox.width)
  let indent_threshold = pdf_double_max(8.0, max_width * 0.12)
  if left_shift > indent_threshold {
    return false
  }
  let font_gap = pdf_abs_double(
    pdf_native_line_average_font_size(previous) -
    pdf_native_line_average_font_size(next),
  )
  if font_gap > 1.5 {
    return false
  }
  true
}

///|
fn pdf_line_looks_like_list_boundary(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return true
  }
  let chars = trimmed.to_array()
  if chars.length() >= 2 &&
    pdf_is_ascii_digit(chars[0]) &&
    (chars[1] == '.' || chars[1] == ')') {
    return true
  }
  false
}

///|
fn pdf_line_has_strong_terminal_punctuation(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  match chars[chars.length() - 1] {
    '.' => true
    '!' => true
    '?' => true
    ':' => true
    ';' => true
    '。' => true
    '！' => true
    '？' => true
    '：' => true
    '；' => true
    _ => false
  }
}

///|
fn pdf_line_looks_like_continuation(line : PdfNativeTextLine) -> Bool {
  let text = pdf_native_line_text(line)
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let first = trimmed.to_array()[0]
  pdf_is_cjk_char(first) ||
  (first >= 'a' && first <= 'z') ||
  first == '"' ||
  first == '\'' ||
  first == '(' ||
  first == '['
}

///|
fn pdf_native_line_average_font_size(line : PdfNativeTextLine) -> Double {
  let mut total = 0.0
  let mut count = 0
  for span in line.spans {
    match span.font_size {
      Some(value) => {
        total += value
        count += 1
      }
      None => ()
    }
  }
  if count == 0 {
    12.0
  } else {
    total / count.to_double()
  }
}

///|
fn pdf_native_line_vertical_gap(
  upper : PdfNativeTextLine,
  lower : PdfNativeTextLine,
) -> Double {
  let upper_bottom = pdf_bbox_bottom(upper.bbox)
  let lower_top = lower.bbox.y
  if lower_top > upper_bottom {
    lower_top - upper_bottom
  } else {
    0.0
  }
}

///|
