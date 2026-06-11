///|
priv struct PdfV2TextOutputLine {
  text : String
  fragment_index : Int
}

///|
priv struct PdfV2TextOutputParagraph {
  text : String
  fragment_index : Int
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
    lines.push({ text: line, fragment_index })
  }
  lines
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
  .replace_all(old=" fl ow", new=" flow")
  .replace_all(old=" Fi rst", new=" First")
  .replace_all(old=" Fi nal", new=" Final")
  .replace_all(old=" Fi dential", new="Fidential")
  .replace_all(old=" Fi rm", new="Firm")
  .replace_all(old=" Fi ed", new="Fied")
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
  let repeated_counts = pdf_v2_repeated_noise_counts(fragments, options)
  let lines = pdf_v2_text_output_line_stream(fragments)
  let paragraphs : Array[PdfV2TextOutputParagraph] = []
  let current : Array[PdfV2TextOutputLine] = []

  fn flush_current() -> Unit {
    if current.length() == 0 {
      return
    }
    let text = pdf_v2_join_output_lines(current)
    if text != "" {
      paragraphs.push({ text, fragment_index: current[0].fragment_index })
    }
    current.clear()
  }

  let mut i = 0
  while i < lines.length() {
    if pdf_v2_should_skip_page_label_sequence(lines, i, options) {
      i = i + pdf_v2_page_label_sequence_length(lines, i)
      continue
    }
    let line = lines[i]
    if line.text == "" {
      flush_current()
      i = i + 1
      continue
    }
    if pdf_v2_should_drop_output_line(line.text, repeated_counts, options) {
      i = i + 1
      continue
    }
    if current.length() == 0 {
      current.push(line)
    } else {
      let last = current[current.length() - 1]
      if pdf_v2_output_line_starts_new_paragraph(last, line) {
        flush_current()
      }
      current.push(line)
    }
    i = i + 1
  }
  flush_current()
  paragraphs
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
      lines.push({ text: "", fragment_index })
    }
  }
  lines
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
  if pdf_v2_looks_like_standalone_title_line(l) {
    return true
  }
  if pdf_v2_join_without_space(l, r) ||
    pdf_v2_should_unwrap_hyphenated_word(l, r) ||
    pdf_v2_is_lowercase_continuation(r) {
    return false
  }
  if pdf_v2_ends_sentence(l) {
    return true
  }
  false
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
fn pdf_v2_looks_like_standalone_title_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 4 || t.length() > 48 {
    return false
  }
  if pdf_v2_ends_sentence(t) || t.has_suffix(":") || t.has_suffix("：") {
    return false
  }
  let words = pdf_v2_word_count(t)
  if words >= 5 {
    return false
  }
  if pdf_v2_all_ascii_lowercase_words(t) {
    return false
  }
  true
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
fn pdf_v2_all_ascii_lowercase_words(text : String) -> Bool {
  let chars = text.to_array()
  let mut saw_alpha = false
  for ch in chars {
    if ch >= 'A' && ch <= 'Z' {
      return false
    }
    if ch >= 'a' && ch <= 'z' {
      saw_alpha = true
    }
  }
  saw_alpha
}

///|
fn pdf_v2_should_drop_output_line(
  text : String,
  repeated_counts : Map[String, Int],
  options : PdfV2ProductBridgeOptions,
) -> Bool {
  if options.suppress_page_number_like_noise &&
    pdf_v2_is_page_number_like_noise(text) {
    return true
  }
  if options.suppress_repeated_page_artifact_noise {
    let key = pdf_v2_noise_key(text)
    if key != "" &&
      repeated_counts.get(key).unwrap_or(0) >= 2 &&
      pdf_v2_is_repeated_page_artifact_candidate(text) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_repeated_noise_counts(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  if !options.suppress_repeated_page_artifact_noise {
    return counts
  }
  for line in pdf_v2_text_output_line_stream(fragments) {
    let key = pdf_v2_noise_key(line.text)
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
  if t == "" || t.length() > 80 || pdf_v2_word_count(t) > 8 {
    return false
  }
  if pdf_v2_ends_sentence(t) && pdf_v2_word_count(t) >= 5 {
    return false
  }
  let lower = t.to_lower()
  lower.contains("header") ||
  lower.contains("footer") ||
  lower.contains("confidential") ||
  lower.contains("internal use") ||
  lower.contains("do not distribute") ||
  lower.contains("report") ||
  lower.has_prefix("page ")
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
  digits != "" && digits.length() <= 4 && pdf_v2_all_ascii_digits(digits)
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
fn pdf_v2_page_label_sequence_length(
  lines : Array[PdfV2TextOutputLine],
  index : Int,
) -> Int {
  if index + 2 < lines.length() {
    let a = lines[index].text
    let b = lines[index + 1].text
    let c = lines[index + 2].text
    if a == "第" && b == "页" && pdf_v2_all_ascii_digits(c) {
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
