///|
priv struct PdfV2TextOutputLine {
  text : String
  fragment_index : Int
  page_index : Int?
  block_index : Int?
}

///|
priv struct PdfV2TextOutputParagraph {
  text : String
  fragment_index : Int
  line_count : Int
}

///|
fn pdf_v2_text_output_fragment_lines(
  fragment_index : Int,
  fragment : PdfV2FactFragment,
) -> Array[PdfV2TextOutputLine] {
  let text = pdf_v2_normalize_plain_text_fragment(fragment.text)
    .replace_all(old="<br />", new="\n")
    .replace_all(old="<br/>", new="\n")
    .replace_all(old="<br>", new="\n")
  let lines : Array[PdfV2TextOutputLine] = []
  for raw in text.split("\n") {
    let line = pdf_v2_normalize_paragraph_text(raw.to_owned())
    lines.push({
      text: line,
      fragment_index,
      page_index: fragment.page_index,
      block_index: fragment.block_index,
    })
  }
  lines
}

///|
fn pdf_v2_text_output_normalize_candidate_lines(
  raw_lines : Array[String],
  fallback_text : String,
  options : PdfV2ProductBridgeOptions,
) -> String {
  let lines : Array[PdfV2TextOutputLine] = []
  if raw_lines.length() == 0 {
    for raw in fallback_text.split("\n") {
      lines.push({
        text: pdf_v2_normalize_paragraph_text(raw.to_owned()),
        fragment_index: 0,
        page_index: None,
        block_index: None,
      })
    }
  } else {
    for raw in raw_lines {
      lines.push({
        text: pdf_v2_normalize_paragraph_text(raw),
        fragment_index: 0,
        page_index: None,
        block_index: None,
      })
    }
  }
  let text = pdf_v2_join_output_lines(lines)
  if options.suppress_page_number_like_noise {
    pdf_v2_candidate_strip_heading_tail_body(pdf_v2_strip_cjk_page_prefix(text))
  } else {
    pdf_v2_candidate_strip_heading_tail_body(text)
  }
}

///|
fn pdf_v2_candidate_strip_heading_tail_body(text : String) -> String {
  let t = text.trim().to_owned()
  match pdf_v2_candidate_heading_tail_split_index(t) {
    Some(index) => String::from_array(t.to_array()[:index].to_owned())
    None => t
  }
}

///|
fn pdf_v2_normalize_plain_text_fragment(text : String) -> String {
  pdf_v2_normalize_observed_compat_glyphs(@cor.normalize_pdf_text_cleanup(text))
}

///|
fn pdf_v2_normalize_paragraph_text(text : String) -> String {
  pdf_v2_repair_common_ligature_word_splits(
    pdf_v2_remove_spaces_between_cjk(
      pdf_v2_fix_ascii_punctuation_spacing(
        pdf_v2_collapse_ascii_spaces(
          pdf_v2_normalize_observed_compat_glyphs(
            @cor.normalize_pdf_text_cleanup(text),
          ),
        ),
      ),
    ),
  )
}

///|
fn pdf_v2_collapse_ascii_spaces(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in text {
    if ch == ' ' || ch == '\t' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_remove_spaces_between_cjk(text : String) -> String {
  let chars = text.to_array()
  if chars.length() < 3 {
    return text
  }
  let out = StringBuilder::new()
  let mut changed = false
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch == ' ' &&
      i > 0 &&
      i + 1 < chars.length() &&
      pdf_v2_is_cjk(chars[i - 1]) &&
      pdf_v2_is_cjk(chars[i + 1]) {
      changed = true
      continue
    }
    out.write_char(ch)
  }
  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn pdf_v2_fix_ascii_punctuation_spacing(text : String) -> String {
  let chars = text.to_array()
  if chars.length() < 2 {
    return text
  }
  let out = StringBuilder::new()
  let mut changed = false
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch == ' ' &&
      i + 1 < chars.length() &&
      pdf_v2_ascii_right_tight_punctuation(chars[i + 1]) {
      changed = true
      continue
    }
    out.write_char(ch)
  }
  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn pdf_v2_repair_common_ligature_word_splits(text : String) -> String {
  text
  .replace_all(old=" fi rst", new=" first")
  .replace_all(old=" fi nal", new=" final")
  .replace_all(old=" fi dential", new="fidential")
  .replace_all(old=" fi rm", new="firm")
  .replace_all(old=" fi ed", new="fied")
  .replace_all(old="di ff erent", new="different")
  .replace_all(old=" fl ow", new=" flow")
  .replace_all(old=" Fi rst", new=" First")
  .replace_all(old=" Fi nal", new=" Final")
  .replace_all(old=" Fi dential", new="Fidential")
  .replace_all(old=" Fi rm", new="Firm")
  .replace_all(old=" Fi ed", new="Fied")
  .replace_all(old="Di ff erent", new="Different")
  .replace_all(old=" Fl ow", new=" Flow")
}

///|
fn pdf_v2_ascii_right_tight_punctuation(ch : Char) -> Bool {
  ch == ',' || ch == '.' || ch == '!' || ch == '?' || ch == ';' || ch == ':'
}

///|
fn pdf_v2_normalize_observed_compat_glyphs(text : String) -> String {
  let out = StringBuilder::new()
  let mut changed = false
  for ch in text {
    match pdf_v2_observed_compat_glyph(ch) {
      Some(mapped) => {
        out.write_string(mapped)
        changed = true
      }
      None => out.write_char(ch)
    }
  }
  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn pdf_v2_observed_compat_glyph(ch : Char) -> String? {
  match ch {
    '⼀' => Some("一")
    '⽤' => Some("用")
    '⽂' => Some("文")
    '⻚' => Some("页")
    '⽬' => Some("目")
    '⾏' => Some("行")
    '⾸' => Some("首")
    '⽀' => Some("支")
    '⼆' => Some("二")
    '⼈' => Some("人")
    '⼝' => Some("口")
    '⼤' => Some("大")
    '⼩' => Some("小")
    '⼯' => Some("工")
    '⽣' => Some("生")
    '⽰' => Some("示")
    '⽴' => Some("立")
    '⽽' => Some("而")
    '⾃' => Some("自")
    _ => None
  }
}

///|
fn pdf_v2_text_output_paragraphs(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2TextOutputParagraph] {
  let lines = pdf_v2_text_output_line_stream(fragments)
  let paragraphs : Array[PdfV2TextOutputParagraph] = []
  let current : Array[PdfV2TextOutputLine] = []

  fn flush_current() -> Unit {
    if current.length() == 0 {
      return
    }
    let text = if options.suppress_page_number_like_noise {
      pdf_v2_strip_cjk_page_prefix(pdf_v2_join_output_lines(current))
    } else {
      pdf_v2_join_output_lines(current)
    }
    if text != "" {
      let line_count = pdf_v2_text_output_logical_line_count(
        text,
        current.length(),
      )
      paragraphs.push({
        text,
        fragment_index: current[0].fragment_index,
        line_count,
      })
    }
    current.clear()
  }

  let mut i = 0
  while i < lines.length() {
    let mut line = lines[i]
    match pdf_v2_split_cjk_page_prefix_target_index(lines, i, options) {
      Some(target_index) => {
        i = target_index
        line = {
          text: pdf_v2_strip_cjk_page_prefix(lines[target_index].text),
          fragment_index: lines[target_index].fragment_index,
          page_index: lines[target_index].page_index,
          block_index: lines[target_index].block_index,
        }
      }
      None => ()
    }
    if pdf_v2_should_skip_page_label_sequence(lines, i, options) {
      i = i + pdf_v2_page_label_sequence_length(lines, i)
      continue
    }
    if options.suppress_page_number_like_noise {
      line = {
        text: pdf_v2_strip_cjk_page_prefix(line.text),
        fragment_index: line.fragment_index,
        page_index: line.page_index,
        block_index: line.block_index,
      }
    }
    if line.text == "" {
      match pdf_v2_next_non_empty_line_index(lines, i + 1) {
        Some(next_index) =>
          if current.length() > 0 &&
            pdf_v2_should_ignore_blank_between_output_lines(
              current[current.length() - 1],
              lines[next_index],
            ) {
            i = i + 1
            continue
          }
        None => ()
      }
      flush_current()
      i = i + 1
      continue
    }
    if pdf_v2_should_drop_output_line(line.text, options) {
      i = i + 1
      continue
    }
    if current.length() == 0 {
      current.push(line)
    } else {
      let last = current[current.length() - 1]
      match pdf_v2_split_heading_tail_from_body(current, line) {
        Some((heading_tail, body)) => {
          current.push(heading_tail)
          flush_current()
          current.push(body)
          i = i + 1
          continue
        }
        None => ()
      }
      let joined = pdf_v2_join_output_lines(current)
      let current_starts_new = pdf_v2_current_output_starts_new_paragraph(
        current, line,
      )
      if pdf_v2_current_numbered_heading_waits_for_tail(joined, line.text) {
        current.push(line)
        i = i + 1
        continue
      } else if current_starts_new {
        flush_current()
      } else if pdf_v2_current_cross_block_body_continues(joined, line.text) {
        current.push(line)
        i = i + 1
        continue
      } else if pdf_v2_output_line_starts_new_paragraph(last, line) {
        flush_current()
      }
      current.push(line)
    }
    i = i + 1
  }
  flush_current()
  pdf_v2_filter_repeated_artifact_paragraphs(paragraphs, options)
}

///|
fn pdf_v2_text_output_line_stream(
  fragments : Array[PdfV2FactFragment],
) -> Array[PdfV2TextOutputLine] {
  let lines : Array[PdfV2TextOutputLine] = []
  for fragment_index in 0..<fragments.length() {
    let fragment = fragments[fragment_index]
    if fragment.kind == PdfV2FactFragmentKind::PlainText {
      lines.append(pdf_v2_text_output_fragment_lines(fragment_index, fragment))
    } else {
      lines.push({
        text: "",
        fragment_index,
        page_index: fragment.page_index,
        block_index: fragment.block_index,
      })
    }
  }
  lines
}

///|
fn pdf_v2_current_output_starts_new_paragraph(
  current : Array[PdfV2TextOutputLine],
  right : PdfV2TextOutputLine,
) -> Bool {
  if current.length() == 0 {
    return false
  }
  let joined = pdf_v2_join_output_lines(current)
  let r = right.text.trim().to_owned()
  if joined == "" || r == "" {
    return false
  }
  let last = current[current.length() - 1]
  if last.page_index != right.page_index {
    return true
  }
  if pdf_v2_current_complete_cjk_heading_before(joined, r) {
    return true
  }
  if pdf_v2_current_numbered_heading_waits_for_tail(joined, r) {
    return false
  }
  if pdf_v2_current_output_line_continues(joined, r) {
    return false
  }
  if pdf_v2_current_cross_block_body_continues(joined, r) {
    return false
  }
  if pdf_v2_current_block_boundary(last, right) {
    return true
  }
  false
}

///|
fn pdf_v2_split_heading_tail_from_body(
  current : Array[PdfV2TextOutputLine],
  right : PdfV2TextOutputLine,
) -> (PdfV2TextOutputLine, PdfV2TextOutputLine)? {
  if current.length() == 0 {
    return None
  }
  let joined = pdf_v2_join_output_lines(current)
  if !pdf_v2_numbered_section_heading_prefix(joined) ||
    pdf_v2_numbered_section_heading_complete(joined) {
    return None
  }
  if pdf_v2_cjk_heading_tail_exact(right.text) {
    return None
  }
  match pdf_v2_take_cjk_heading_tail_prefix(right.text) {
    Some((tail, body_text)) => {
      let tail_line = {
        text: tail,
        fragment_index: right.fragment_index,
        page_index: right.page_index,
        block_index: right.block_index,
      }
      let body_line = {
        text: body_text,
        fragment_index: right.fragment_index,
        page_index: right.page_index,
        block_index: right.block_index,
      }
      Some((tail_line, body_line))
    }
    None => None
  }
}

///|
fn pdf_v2_output_line_starts_new_paragraph(
  left : PdfV2TextOutputLine,
  right : PdfV2TextOutputLine,
) -> Bool {
  let l = left.text.trim().to_owned()
  let r = right.text.trim().to_owned()
  if l == "" || r == "" {
    return true
  }
  if left.page_index != right.page_index {
    return !pdf_v2_cross_page_output_line_continues(l, r)
  }
  if pdf_v2_output_line_starts_semantic_marker(l) ||
    pdf_v2_output_line_starts_semantic_marker(r) ||
    pdf_v2_is_page_number_like_noise(l) ||
    pdf_v2_is_page_number_like_noise(r) {
    return true
  }
  if pdf_v2_looks_like_standalone_title_line(l) {
    return true
  }
  if pdf_v2_looks_like_standalone_title_line(r) {
    return true
  }
  if pdf_v2_repeated_artifact_line_before_body(l, r) {
    return true
  }
  if pdf_v2_output_line_continues_hardwrap(l, r) {
    return false
  }
  if pdf_v2_ends_sentence(l) &&
    (
      !pdf_v2_same_known_block(left, right) ||
      pdf_v2_short_artifact_fragment_start(r)
    ) {
    return true
  }
  false
}

///|
fn pdf_v2_should_ignore_blank_between_output_lines(
  left : PdfV2TextOutputLine,
  right : PdfV2TextOutputLine,
) -> Bool {
  let l = left.text.trim().to_owned()
  let r = right.text.trim().to_owned()
  if l == "" || r == "" {
    return false
  }
  if left.page_index != right.page_index {
    return pdf_v2_cross_page_output_line_continues(l, r)
  }
  if pdf_v2_numbered_section_heading_waits_across_blank(l, r) {
    return true
  }
  if pdf_v2_output_line_starts_semantic_marker(l) ||
    pdf_v2_output_line_starts_semantic_marker(r) ||
    pdf_v2_is_page_number_like_noise(l) ||
    pdf_v2_is_page_number_like_noise(r) {
    return false
  }
  if pdf_v2_looks_like_standalone_title_line(l) ||
    pdf_v2_looks_like_standalone_title_line(r) ||
    pdf_v2_ends_sentence(l) {
    return false
  }
  pdf_v2_output_line_continues_hardwrap(l, r)
}

///|
fn pdf_v2_numbered_section_heading_waits_across_blank(
  left_text : String,
  right_text : String,
) -> Bool {
  if !pdf_v2_numbered_section_heading_prefix(left_text) ||
    pdf_v2_numbered_section_heading_complete(left_text) {
    return false
  }
  pdf_v2_cjk_heading_tail_exact(right_text) ||
  pdf_v2_take_cjk_heading_tail_prefix(right_text) is Some(_)
}

///|
fn pdf_v2_output_line_starts_semantic_marker(text : String) -> Bool {
  pdf_v2_text_flow_parse_marker(text) is Some(_)
}

///|
fn pdf_v2_join_output_lines(lines : Array[PdfV2TextOutputLine]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut text = lines[0].text
  for i in 1..<lines.length() {
    let right = lines[i].text
    if right == "" {
      continue
    }
    if pdf_v2_should_unwrap_hyphenated_word(text, right) {
      text = pdf_v2_trim_trailing_wrap_hyphen(text) + right
    } else if pdf_v2_join_without_space(text, right) {
      text = text + right
    } else {
      text = text + " " + right
    }
    text = pdf_v2_normalize_paragraph_text(text)
  }
  pdf_v2_normalize_paragraph_text(text)
}

///|
fn pdf_v2_text_output_logical_line_count(
  text : String,
  raw_line_count : Int,
) -> Int {
  if pdf_v2_cjk_heading_ready_for_body(text) ||
    pdf_v2_looks_like_standalone_title_line(text) {
    1
  } else {
    raw_line_count
  }
}

///|
fn pdf_v2_should_unwrap_hyphenated_word(left : String, right : String) -> Bool {
  if !pdf_v2_has_wrap_hyphen(left) {
    return false
  }
  let left_part = pdf_v2_trailing_ascii_letters(
    pdf_v2_trim_trailing_wrap_hyphen(left),
  )
  let right_part = pdf_v2_leading_ascii_letters(right)
  if left_part == "" || right_part == "" {
    return false
  }
  let word = (left_part + right_part).to_lower()
  if word.length() < 4 || word.length() > 32 {
    return false
  }
  pdf_v2_known_wrap_prefix(left_part.to_lower()) ||
  pdf_v2_known_wrap_suffix(right_part.to_lower()) ||
  (left_part.length() >= 3 && right_part.length() >= 3)
}

///|
fn pdf_v2_has_wrap_hyphen(text : String) -> Bool {
  text.has_suffix("-") ||
  text.has_suffix("\u{2010}") ||
  text.has_suffix("\u{2011}")
}

///|
fn pdf_v2_trim_trailing_wrap_hyphen(text : String) -> String {
  if !pdf_v2_has_wrap_hyphen(text) {
    return text
  }
  let chars = text.to_array()
  if chars.length() == 0 {
    ""
  } else {
    String::from_array(chars[:chars.length() - 1].to_owned())
  }
}

///|
fn pdf_v2_join_without_space(left : String, right : String) -> Bool {
  match (pdf_v2_last_char(left), pdf_v2_first_char(right)) {
    (Some(lc), Some(rc)) =>
      (pdf_v2_is_cjk(lc) && pdf_v2_is_cjk(rc)) ||
      pdf_v2_cjk_punctuation_to_cjk_continuation(lc, rc) ||
      pdf_v2_right_tight_punctuation(rc) ||
      pdf_v2_left_tight_punctuation(lc) ||
      pdf_v2_numeric_separator_continuation(left, rc) ||
      pdf_v2_ligature_piece_continuation(left, right)
    _ => false
  }
}

///|
fn pdf_v2_ligature_piece_continuation(left : String, right : String) -> Bool {
  let left_word = pdf_v2_trailing_ascii_letters(left).to_lower()
  let right_word = pdf_v2_leading_ascii_letters(right).to_lower()
  if left_word == "" || right_word == "" {
    return false
  }
  if pdf_v2_known_wrap_prefix(left_word) && right_word.length() <= 4 {
    return true
  }
  if pdf_v2_has_ligature_fragment_hint(left_word) &&
    pdf_v2_known_wrap_suffix(right_word) {
    return true
  }
  false
}

///|
fn pdf_v2_has_ligature_fragment_hint(text : String) -> Bool {
  text.has_suffix("fi") ||
  text.has_suffix("fl") ||
  text.has_suffix("ff") ||
  text.has_suffix("ffi") ||
  text.has_suffix("ffl")
}

///|
fn pdf_v2_known_wrap_prefix(text : String) -> Bool {
  text == "uni" ||
  text == "inter" ||
  text == "multi" ||
  text == "trans" ||
  text == "micro" ||
  text == "macro" ||
  text == "hyper" ||
  text == "meta" ||
  text == "auto"
}

///|
fn pdf_v2_known_wrap_suffix(text : String) -> Bool {
  text == "ed" ||
  text == "er" ||
  text == "es" ||
  text == "ly" ||
  text == "ing" ||
  text == "tion" ||
  text == "sion" ||
  text == "ment" ||
  text == "ness" ||
  text == "able" ||
  text == "ible" ||
  text == "ity" ||
  text == "ation" ||
  text == "ations"
}

///|
fn pdf_v2_numeric_separator_continuation(left : String, right : Char) -> Bool {
  if !pdf_v2_is_ascii_digit(right) {
    return false
  }
  let chars = left.to_array()
  if chars.length() < 2 {
    return false
  }
  let last = chars[chars.length() - 1]
  let prev = chars[chars.length() - 2]
  (last == '/' || last == '.' || last == ',' || last == ':') &&
  pdf_v2_is_ascii_digit(prev)
}

///|
fn pdf_v2_is_lowercase_continuation(text : String) -> Bool {
  match pdf_v2_first_char(text) {
    Some(ch) => ch >= 'a' && ch <= 'z'
    None => false
  }
}

///|
fn pdf_v2_same_known_block(
  left : PdfV2TextOutputLine,
  right : PdfV2TextOutputLine,
) -> Bool {
  match (left.block_index, right.block_index) {
    (Some(l), Some(r)) => l == r && left.page_index == right.page_index
    _ => false
  }
}

///|
fn pdf_v2_current_block_boundary(
  left : PdfV2TextOutputLine,
  right : PdfV2TextOutputLine,
) -> Bool {
  match (left.block_index, right.block_index) {
    (Some(l), Some(r)) => l != r || left.page_index != right.page_index
    _ => false
  }
}

///|
fn pdf_v2_short_artifact_fragment_start(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" || t.to_array().length() > 16 || pdf_v2_ends_sentence(t) {
    return false
  }
  let lower = t.to_lower()
  if pdf_v2_repeated_line_has_artifact_keyword(lower) {
    return true
  }
  if pdf_v2_word_count(t) > 2 {
    return false
  }
  match pdf_v2_first_char(t) {
    Some(ch) => ch >= 'A' && ch <= 'Z'
    None => false
  }
}

///|
fn pdf_v2_repeated_artifact_line_before_body(
  left_text : String,
  right_text : String,
) -> Bool {
  let left = left_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if !pdf_v2_is_strict_repeated_artifact_line(left) {
    return false
  }
  pdf_v2_line_looks_like_body_start(right)
}

///|
fn pdf_v2_is_strict_repeated_artifact_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if !pdf_v2_is_repeated_page_artifact_candidate(t) ||
    pdf_v2_repeated_line_has_title_shape(t) {
    return false
  }
  let lower = t.to_lower()
  if pdf_v2_repeated_line_has_artifact_keyword(lower) {
    return true
  }
  pdf_v2_short_all_caps_line(t)
}

///|
fn pdf_v2_short_all_caps_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  let chars = t.to_array()
  if chars.length() < 4 || chars.length() > 24 {
    return false
  }
  let mut letters = 0
  for ch in chars {
    if ch >= 'A' && ch <= 'Z' {
      letters = letters + 1
    } else if ch >= 'a' && ch <= 'z' {
      return false
    } else if ch == ' ' || ch == '-' || ch == '_' || pdf_v2_is_ascii_digit(ch) {
      continue
    } else {
      return false
    }
  }
  letters >= 3
}

///|
fn pdf_v2_line_looks_like_body_start(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if pdf_v2_ends_sentence(t) ||
    t.to_array().length() >= 12 ||
    pdf_v2_word_count(t) >= 3 ||
    pdf_v2_cjk_body_start_fragment(t) {
    return true
  }
  false
}

///|
fn pdf_v2_current_complete_cjk_heading_before(
  current_text : String,
  right_text : String,
) -> Bool {
  let current = current_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if current == "" || right == "" {
    return false
  }
  if !pdf_v2_cjk_heading_ready_for_body(current) {
    return false
  }
  pdf_v2_cjk_body_start_fragment(right) ||
  pdf_v2_looks_like_standalone_title_line(right) ||
  right.to_array().length() >= 8
}

///|
fn pdf_v2_current_numbered_heading_waits_for_tail(
  current_text : String,
  right_text : String,
) -> Bool {
  let current = current_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if !pdf_v2_numbered_section_heading_prefix(current) {
    return false
  }
  if pdf_v2_numbered_section_heading_complete(current) {
    return false
  }
  pdf_v2_cjk_heading_tail_exact(right) || pdf_v2_cjk_short_fragment(right)
}

///|
fn pdf_v2_current_output_line_continues(
  current_text : String,
  right_text : String,
) -> Bool {
  pdf_v2_output_line_continues_hardwrap(current_text, right_text) ||
  pdf_v2_cross_block_cjk_term_continuation(current_text, right_text)
}

///|
fn pdf_v2_output_line_continues_hardwrap(
  left_text : String,
  right_text : String,
) -> Bool {
  pdf_v2_join_without_space(left_text, right_text) ||
  pdf_v2_should_unwrap_hyphenated_word(left_text, right_text) ||
  pdf_v2_is_lowercase_continuation(right_text) ||
  pdf_v2_mixed_cjk_ascii_term_continuation(left_text, right_text)
}

///|
fn pdf_v2_cross_page_output_line_continues(
  left_text : String,
  right_text : String,
) -> Bool {
  let left = left_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if left == "" ||
    right == "" ||
    pdf_v2_ends_sentence(left) ||
    pdf_v2_output_line_starts_semantic_marker(right) ||
    pdf_v2_is_page_number_like_noise(left) ||
    pdf_v2_is_page_number_like_noise(right) ||
    pdf_v2_looks_like_standalone_title_line(left) ||
    pdf_v2_looks_like_standalone_title_line(right) {
    return false
  }
  pdf_v2_output_line_continues_hardwrap(left, right)
}

///|
fn pdf_v2_mixed_cjk_ascii_term_continuation(
  left_text : String,
  right_text : String,
) -> Bool {
  let left = left_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if left == "" ||
    right == "" ||
    pdf_v2_ends_sentence(left) ||
    pdf_v2_output_line_starts_semantic_marker(right) ||
    pdf_v2_is_page_number_like_noise(left) ||
    pdf_v2_is_page_number_like_noise(right) ||
    pdf_v2_looks_like_standalone_title_line(left) ||
    pdf_v2_looks_like_standalone_title_line(right) {
    return false
  }
  match (pdf_v2_last_char(left), pdf_v2_first_char(right)) {
    (Some(lc), Some(rc)) =>
      if pdf_v2_is_ascii_letter(lc) && pdf_v2_is_cjk(rc) {
        let term = pdf_v2_trailing_ascii_letters(left)
        pdf_v2_has_cjk(left) && pdf_v2_short_upper_ascii_term(term)
      } else if pdf_v2_is_cjk(lc) && pdf_v2_is_ascii_letter(rc) {
        let term = pdf_v2_leading_ascii_letters(right)
        pdf_v2_has_cjk(left) && pdf_v2_short_upper_ascii_term(term)
      } else {
        false
      }
    _ => false
  }
}

///|
fn pdf_v2_short_upper_ascii_term(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 2 || t.length() > 8 {
    return false
  }
  let mut letters = 0
  for ch in t {
    if ch >= 'A' && ch <= 'Z' {
      letters = letters + 1
    } else {
      return false
    }
  }
  letters >= 2
}

///|
fn pdf_v2_cjk_punctuation_to_cjk_continuation(
  left : Char,
  right : Char,
) -> Bool {
  pdf_v2_cjk_continuation_punctuation(left) && pdf_v2_is_cjk(right)
}

///|
fn pdf_v2_cjk_continuation_punctuation(ch : Char) -> Bool {
  ch == '，' || ch == '、' || ch == '：' || ch == '；'
}

///|
fn pdf_v2_current_cross_block_body_continues(
  current_text : String,
  right_text : String,
) -> Bool {
  let current = current_text.trim().to_owned()
  let right = right_text.trim().to_owned()
  if current == "" || right == "" {
    return false
  }
  pdf_v2_english_body_sentence_continues(current, right)
}

///|
fn pdf_v2_cross_block_cjk_term_continuation(
  current_text : String,
  right_text : String,
) -> Bool {
  match (pdf_v2_last_char(current_text), pdf_v2_first_char(right_text)) {
    (Some(lc), Some(rc)) =>
      pdf_v2_is_cjk(lc) &&
      ((rc >= 'A' && rc <= 'Z') || (rc >= 'a' && rc <= 'z')) &&
      (right_text.contains(" ") || pdf_v2_ends_sentence(right_text))
    _ => false
  }
}

///|
fn pdf_v2_english_body_sentence_continues(
  current_text : String,
  right_text : String,
) -> Bool {
  if !pdf_v2_ends_sentence(current_text) ||
    !pdf_v2_ends_sentence(right_text) ||
    !pdf_v2_english_body_sentence(current_text) ||
    !pdf_v2_english_body_sentence(right_text) {
    return false
  }
  match pdf_v2_first_char(right_text) {
    Some(ch) => ch >= 'A' && ch <= 'Z'
    None => false
  }
}

///|
fn pdf_v2_english_body_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.contains("://") {
    return false
  }
  pdf_v2_word_count(t) >= 5 &&
  pdf_v2_ascii_letter_count(t) >= 12 &&
  pdf_v2_english_noise_merge_body_signal(t)
}

///|
fn pdf_v2_english_noise_merge_body_signal(text : String) -> Bool {
  let lower = text.to_lower()
  lower.contains("body") ||
  lower.contains("cleanup") ||
  lower.contains("header") ||
  lower.contains("footer") ||
  lower.contains("removed") ||
  lower.contains("remove")
}

///|
fn pdf_v2_ascii_letter_count(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if pdf_v2_is_ascii_letter(ch) {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_cjk_heading_ready_for_body(text : String) -> Bool {
  pdf_v2_cjk_chapter_heading_complete(text) ||
  pdf_v2_numbered_section_heading_complete(text)
}

///|
fn pdf_v2_cjk_chapter_heading_complete(text : String) -> Bool {
  let t = text.trim().to_owned()
  if !t.has_prefix("第") || !(t.contains("章") || t.contains("节")) {
    return false
  }
  let chars = t.to_array()
  if chars.length() < 6 || chars.length() > 30 {
    return false
  }
  if pdf_v2_ends_sentence(t) {
    return false
  }
  pdf_v2_cjk_heading_tail_word(t)
}

///|
fn pdf_v2_numbered_section_heading_prefix(text : String) -> Bool {
  let t = text.trim().to_owned()
  let chars = t.to_array()
  if chars.length() < 3 || !pdf_v2_is_ascii_digit(chars[0]) {
    return false
  }
  let mut saw_dot = false
  for ch in chars {
    if pdf_v2_is_ascii_digit(ch) {
      continue
    } else if ch == '.' {
      saw_dot = true
    } else {
      return saw_dot
    }
  }
  false
}

///|
fn pdf_v2_numbered_section_heading_complete(text : String) -> Bool {
  let t = text.trim().to_owned()
  if !pdf_v2_numbered_section_heading_prefix(t) || pdf_v2_ends_sentence(t) {
    return false
  }
  pdf_v2_cjk_heading_tail_word(t)
}

///|
fn pdf_v2_cjk_heading_tail_word(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix("概述") ||
  t.has_suffix("路线") ||
  t.has_suffix("目标") ||
  t.has_suffix("背景") ||
  t.has_suffix("方法") ||
  t.has_suffix("方案") ||
  t.has_suffix("设计") ||
  t.has_suffix("实现") ||
  t.has_suffix("总结") ||
  t.has_suffix("结论") ||
  t.has_suffix("绪论") ||
  t.has_suffix("引言")
}

///|
fn pdf_v2_cjk_heading_tail_exact(text : String) -> Bool {
  let t = text.trim().to_owned()
  t == "目标" ||
  t == "概述" ||
  t == "路线" ||
  t == "背景" ||
  t == "方法" ||
  t == "方案" ||
  t == "设计" ||
  t == "实现"
}

///|
fn pdf_v2_take_cjk_heading_tail_prefix(text : String) -> (String, String)? {
  let t = text.trim().to_owned()
  let tails = [
    "目标", "概述", "路线", "背景", "方法", "方案", "设计", "实现",
  ]
  for tail in tails {
    if t.has_prefix(tail) && t.length() > tail.length() {
      let chars = t.to_array()
      let tail_chars = tail.to_array()
      let body = String::from_array(chars[tail_chars.length():].to_owned())
        .trim()
        .to_owned()
      if body != "" && pdf_v2_line_looks_like_body_start(body) {
        return Some((tail, body))
      }
    }
  }
  None
}

///|
fn pdf_v2_candidate_heading_tail_split_index(text : String) -> Int? {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 || !pdf_v2_is_ascii_digit(chars[0]) {
    return None
  }
  let mut i = 0
  while i < chars.length() &&
        (pdf_v2_is_ascii_digit(chars[i]) || chars[i] == '.') {
    i = i + 1
  }
  if i == 0 || i >= chars.length() || chars[i] != ' ' {
    return None
  }
  i = i + 1
  let mut cjk_count = 0
  while i < chars.length() && pdf_v2_is_cjk(chars[i]) {
    cjk_count = cjk_count + 1
    let current = String::from_array(chars[:i + 1].to_owned())
    let rest = String::from_array(chars[i + 1:].to_owned()).trim().to_owned()
    if cjk_count >= 2 &&
      pdf_v2_numbered_section_heading_complete(current) &&
      rest != "" &&
      pdf_v2_line_looks_like_body_start(rest) {
      return Some(i + 1)
    }
    i = i + 1
  }
  None
}

///|
fn pdf_v2_cjk_body_start_fragment(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_prefix("本") ||
  t.has_prefix("系统") ||
  t.has_prefix("实现") ||
  t.has_prefix("采用") ||
  t.has_prefix("通过") ||
  t.has_prefix("为了") ||
  t.has_prefix("首先") ||
  t.has_prefix("然后")
}

///|
fn pdf_v2_cjk_short_fragment(text : String) -> Bool {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 || chars.length() > 8 {
    return false
  }
  for ch in chars {
    if !pdf_v2_is_cjk(ch) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_looks_like_standalone_title_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  let char_count = t.to_array().length()
  if char_count < 4 || char_count > 48 {
    return false
  }
  if pdf_v2_ends_sentence(t) || t.has_suffix(":") || t.has_suffix("：") {
    return false
  }
  pdf_v2_heading_basic_shape_ok(t) && pdf_v2_heading_has_title_shape(t)
}

///|
fn pdf_v2_ends_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_v2_word_count(text : String) -> Int {
  let mut count = 0
  for raw in text.split(" ") {
    if raw.trim() != "" {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_should_drop_output_line(
  text : String,
  options : PdfV2ProductBridgeOptions,
) -> Bool {
  if options.suppress_page_number_like_noise &&
    pdf_v2_is_page_number_like_noise(text) {
    return true
  }
  false
}

///|
fn pdf_v2_filter_repeated_artifact_paragraphs(
  paragraphs : Array[PdfV2TextOutputParagraph],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2TextOutputParagraph] {
  if options.suppress_repeated_page_artifact_noise {
    let repeated_counts = pdf_v2_repeated_paragraph_noise_counts(paragraphs)
    let out : Array[PdfV2TextOutputParagraph] = []
    for paragraph in paragraphs {
      let key = pdf_v2_noise_key(paragraph.text)
      if key != "" &&
        repeated_counts.get(key).unwrap_or(0) >= 2 &&
        pdf_v2_is_repeated_page_artifact_candidate(paragraph.text) {
        continue
      }
      out.push(paragraph)
    }
    out
  } else {
    paragraphs
  }
}

///|
fn pdf_v2_repeated_paragraph_noise_counts(
  paragraphs : Array[PdfV2TextOutputParagraph],
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for paragraph in paragraphs {
    let key = pdf_v2_noise_key(paragraph.text)
    if key != "" {
      counts.set(key, counts.get(key).unwrap_or(0) + 1)
    }
  }
  counts
}

///|
fn pdf_v2_noise_key(text : String) -> String {
  let t = pdf_v2_normalize_paragraph_text(text).to_lower()
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in t {
    let mapped = if pdf_v2_is_ascii_digit(ch) {
      '#'
    } else if ch == '\t' {
      ' '
    } else {
      ch
    }
    if mapped == ' ' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(mapped)
      prev_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_is_repeated_page_artifact_candidate(text : String) -> Bool {
  let t = pdf_v2_normalize_paragraph_text(text)
  let word_count = pdf_v2_word_count(t)
  if t == "" || t.length() > 80 || word_count > 8 {
    return false
  }
  if pdf_v2_ends_sentence(t) && word_count >= 5 {
    return false
  }
  let lower = t.to_lower()
  if pdf_v2_repeated_line_has_artifact_keyword(lower) {
    return true
  }
  if pdf_v2_repeated_line_has_title_shape(t) {
    return false
  }
  if pdf_v2_repeated_line_has_mixed_numeric_content(t) {
    return false
  }
  if word_count <= 3 && t.length() <= 40 && !pdf_v2_ends_sentence(t) {
    return true
  }
  false
}

///|
fn pdf_v2_repeated_line_has_artifact_keyword(lower : String) -> Bool {
  lower.contains("header") ||
  lower.contains("footer") ||
  lower.contains("confidential") ||
  lower.contains("internal use") ||
  lower.contains("do not distribute") ||
  lower.contains("report") ||
  lower.has_prefix("page ")
}

///|
fn pdf_v2_repeated_line_has_mixed_numeric_content(text : String) -> Bool {
  let mut has_digit = false
  let mut has_letter = false
  for ch in text {
    if pdf_v2_is_ascii_digit(ch) {
      has_digit = true
    } else if pdf_v2_is_ascii_letter(ch) {
      has_letter = true
    }
  }
  has_digit && has_letter
}

///|
fn pdf_v2_repeated_line_has_title_shape(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  lower == "abstract" ||
  lower == "introduction" ||
  lower == "background" ||
  lower == "method" ||
  lower == "methods" ||
  lower == "results" ||
  lower == "discussion" ||
  lower == "summary" ||
  lower == "details" ||
  lower == "conclusion" ||
  lower == "references" ||
  (text.has_prefix("第") && (text.contains("章") || text.contains("节"))) ||
  pdf_v2_repeated_line_has_english_title_shape(text)
}

///|
fn pdf_v2_repeated_line_has_english_title_shape(text : String) -> Bool {
  let word_count = pdf_v2_word_count(text)
  if word_count < 2 || word_count > 6 {
    return false
  }
  let mut latin_words = 0
  let mut capitalized_words = 0
  for raw in text.split(" ") {
    let word = raw.trim().to_owned()
    if word == "" {
      continue
    }
    match pdf_v2_first_char(word) {
      Some(ch) =>
        if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
          latin_words = latin_words + 1
          if ch >= 'A' && ch <= 'Z' {
            capitalized_words = capitalized_words + 1
          }
        }
      None => ()
    }
  }
  latin_words >= 2 && capitalized_words >= 2
}

///|
fn pdf_v2_is_page_number_like_noise(text : String) -> Bool {
  let t = pdf_v2_normalize_paragraph_text(text)
  if t == "" {
    return false
  }
  let compact = t.replace_all(old=" ", new="")
  if compact.length() <= 4 && pdf_v2_all_ascii_digits(compact) {
    return true
  }
  let lower = t.to_lower()
  if lower.has_prefix("p. ") &&
    pdf_v2_all_ascii_digits(lower[3:].trim().to_owned()) {
    return true
  }
  if pdf_v2_looks_like_page_label(t) ||
    pdf_v2_looks_like_cjk_page_label(compact) ||
    pdf_v2_looks_like_fraction_label(compact) ||
    pdf_v2_looks_like_dash_page_label(compact) {
    return true
  }
  false
}

///|
fn pdf_v2_looks_like_page_label(text : String) -> Bool {
  let lower = text.to_lower()
  if !lower.has_prefix("page ") {
    return false
  }
  let tail = lower[5:].trim().to_owned()
  if tail == "" || tail.length() > 12 {
    return false
  }
  if pdf_v2_all_ascii_digits(tail) {
    return true
  }
  if tail.has_prefix("no. ") {
    return pdf_v2_all_ascii_digits(tail[4:].trim().to_owned())
  }
  let parts : Array[String] = []
  for part in tail.split(" of ") {
    parts.push(part.to_owned())
  }
  if parts.length() == 2 {
    return pdf_v2_all_ascii_digits(parts[0].trim().to_owned()) &&
      pdf_v2_all_ascii_digits(parts[1].trim().to_owned())
  }
  false
}

///|
fn pdf_v2_looks_like_cjk_page_label(compact : String) -> Bool {
  if !compact.has_prefix("第") || !compact.contains("页") {
    return false
  }
  let digits = compact
    .replace_all(old="第", new="")
    .replace_all(old="页", new="")
    .trim()
    .to_owned()
  if digits == "" {
    return false
  }
  (digits.length() <= 4 && pdf_v2_all_ascii_digits(digits)) ||
  pdf_v2_looks_like_fraction_label(digits)
}

///|
fn pdf_v2_looks_like_fraction_label(compact : String) -> Bool {
  let parts : Array[String] = []
  for part in compact.split("/") {
    parts.push(part.to_owned())
  }
  if parts.length() != 2 {
    return false
  }
  let left = parts[0].trim().to_owned()
  let right = parts[1].trim().to_owned()
  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  pdf_v2_all_ascii_digits(left) &&
  pdf_v2_all_ascii_digits(right)
}

///|
fn pdf_v2_looks_like_dash_page_label(compact : String) -> Bool {
  if compact.length() > 12 || !compact.contains("-") {
    return false
  }
  let parts : Array[String] = []
  for part in compact.split("-") {
    parts.push(part.to_owned())
  }
  let mut non_empty = 0
  for part in parts {
    let t = part.trim().to_owned()
    if t != "" {
      if !pdf_v2_all_ascii_digits(t) {
        return false
      }
      non_empty = non_empty + 1
    }
  }
  non_empty >= 1 && non_empty <= 2
}

///|
fn pdf_v2_should_skip_page_label_sequence(
  lines : Array[PdfV2TextOutputLine],
  index : Int,
  options : PdfV2ProductBridgeOptions,
) -> Bool {
  if !options.suppress_page_number_like_noise {
    return false
  }
  pdf_v2_page_label_sequence_length(lines, index) > 0
}

///|
fn pdf_v2_split_cjk_page_prefix_target_index(
  lines : Array[PdfV2TextOutputLine],
  index : Int,
  options : PdfV2ProductBridgeOptions,
) -> Int? {
  if !options.suppress_page_number_like_noise || index + 1 >= lines.length() {
    return None
  }
  if lines[index].text != "第" {
    return None
  }
  match pdf_v2_next_non_empty_line_index(lines, index + 1) {
    Some(target_index) =>
      if pdf_v2_starts_with_cjk_page_prefix(lines[target_index].text) {
        Some(target_index)
      } else {
        None
      }
    None => None
  }
}

///|
fn pdf_v2_next_non_empty_line_index(
  lines : Array[PdfV2TextOutputLine],
  start : Int,
) -> Int? {
  let mut i = start
  while i < lines.length() {
    if lines[i].text.trim() != "" {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn pdf_v2_starts_with_cjk_page_prefix(text : String) -> Bool {
  let chars = text.trim().to_owned().to_array()
  (chars.length() >= 2 && chars[0] == '页' && chars[1] == ' ') ||
  (
    chars.length() >= 3 &&
    chars[0] == '第' &&
    chars[1] == '页' &&
    chars[2] == ' '
  )
}

///|
fn pdf_v2_strip_cjk_page_prefix(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  if chars.length() >= 2 && chars[0] == '页' && chars[1] == ' ' {
    let out = StringBuilder::new()
    for i = 2; i < chars.length(); i = i + 1 {
      out.write_char(chars[i])
    }
    return out.to_string().trim().to_owned()
  }
  if chars.length() >= 3 &&
    chars[0] == '第' &&
    chars[1] == '页' &&
    chars[2] == ' ' {
    let out = StringBuilder::new()
    for i = 3; i < chars.length(); i = i + 1 {
      out.write_char(chars[i])
    }
    return out.to_string().trim().to_owned()
  }
  text
}

///|
fn pdf_v2_page_label_sequence_length(
  lines : Array[PdfV2TextOutputLine],
  index : Int,
) -> Int {
  if index >= lines.length() || lines[index].text.trim().to_owned() == "" {
    return 0
  }
  match pdf_v2_next_non_empty_line_index(lines, index + 1) {
    Some(second_index) => {
      let a = lines[index].text
      let b = lines[second_index].text
      match pdf_v2_next_non_empty_line_index(lines, second_index + 1) {
        Some(third_index) => {
          let c = lines[third_index].text
          if a == "第" && b == "页" && pdf_v2_is_page_number_like_noise(c) {
            return third_index - index + 1
          }
          if a == "第" && pdf_v2_all_ascii_digits(b) && c == "页" {
            return third_index - index + 1
          }
        }
        None => ()
      }
      if a == "第" && b == "页" {
        return second_index - index + 1
      }
      let joined = a + b
      if pdf_v2_is_page_number_like_noise(joined) {
        return second_index - index + 1
      }
    }
    None => ()
  }
  if index + 2 < lines.length() {
    let a = lines[index].text
    let b = lines[index + 1].text
    let c = lines[index + 2].text
    if a == "第" && b == "页" && pdf_v2_is_page_number_like_noise(c) {
      return 3
    }
    if a == "第" && pdf_v2_all_ascii_digits(b) && c == "页" {
      return 3
    }
  }
  if index + 1 < lines.length() {
    if lines[index].text == "第" && lines[index + 1].text == "页" {
      return 2
    }
    let joined = lines[index].text + lines[index + 1].text
    if pdf_v2_is_page_number_like_noise(joined) {
      return 2
    }
  }
  0
}

///|
fn pdf_v2_first_char(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn pdf_v2_last_char(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn pdf_v2_trailing_ascii_letters(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  let out_rev = StringBuilder::new()
  let mut i = chars.length()
  while i > 0 {
    let ch = chars[i - 1]
    if pdf_v2_is_ascii_letter(ch) {
      out_rev.write_char(ch)
    } else {
      break
    }
    i = i - 1
  }
  pdf_v2_reverse_string(out_rev.to_string())
}

///|
fn pdf_v2_leading_ascii_letters(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.trim().to_owned() {
    if pdf_v2_is_ascii_letter(ch) {
      out.write_char(ch)
    } else {
      break
    }
  }
  out.to_string()
}

///|
fn pdf_v2_reverse_string(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = chars.length()
  while i > 0 {
    out.write_char(chars[i - 1])
    i = i - 1
  }
  out.to_string()
}

///|
fn pdf_v2_is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn pdf_v2_is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn pdf_v2_all_ascii_digits(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if !pdf_v2_is_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_is_cjk(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn pdf_v2_has_cjk(text : String) -> Bool {
  for ch in text {
    if pdf_v2_is_cjk(ch) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_left_tight_punctuation(ch : Char) -> Bool {
  ch == '(' ||
  ch == '[' ||
  ch == '（' ||
  ch == '《' ||
  ch == '“' ||
  ch == '‘'
}

///|
fn pdf_v2_right_tight_punctuation(ch : Char) -> Bool {
  ch == ',' ||
  ch == '.' ||
  ch == '!' ||
  ch == '?' ||
  ch == ';' ||
  ch == ':' ||
  ch == ')' ||
  ch == ']' ||
  ch == '、' ||
  ch == '，' ||
  ch == '。' ||
  ch == '；' ||
  ch == '：' ||
  ch == '！' ||
  ch == '？' ||
  ch == '）' ||
  ch == '》' ||
  ch == '”' ||
  ch == '’'
}
