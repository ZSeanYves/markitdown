///|
/// Text and content-shape signals for PDF layout feature extraction.
///
/// Keep names stable: quality-lab feature reports depend on the builder keys,
/// while convert rules call these package-local helpers directly.
fn contains_currency_signal(text : String) -> Bool {
  let lower = text.to_lower()
  text.contains("$") ||
  text.contains("¥") ||
  text.contains("￥") ||
  text.contains("€") ||
  text.contains("£") ||
  lower.contains("usd") ||
  lower.contains("eur") ||
  lower.contains("cny") ||
  lower.contains("rmb")
}

///|
fn contains_time_signal(text : String) -> Bool {
  let chars = text.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    if chars[i] == ':' &&
      is_ascii_digit(chars[i - 1]) &&
      is_ascii_digit(chars[i + 1]) {
      return true
    }
  }
  false
}

///|
fn contains_date_signal(text : String) -> Bool {
  let lower = text.to_lower()
  let chars = text.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    let ch = chars[i]
    if (ch == '/' || ch == '-') &&
      is_ascii_digit(chars[i - 1]) &&
      is_ascii_digit(chars[i + 1]) {
      return true
    }
  }
  lower.contains("jan ") ||
  lower.contains("feb ") ||
  lower.contains("mar ") ||
  lower.contains("apr ") ||
  lower.contains("may ") ||
  lower.contains("jun ") ||
  lower.contains("jul ") ||
  lower.contains("aug ") ||
  lower.contains("sep ") ||
  lower.contains("oct ") ||
  lower.contains("nov ") ||
  lower.contains("dec ")
}

///|
fn looks_like_address_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if trimmed.contains(", ") && looks_like_us_state_zip_suffix(trimmed) {
    return true
  }
  begins_with_digit(trimmed) &&
  (
    lower.contains(" street") ||
    lower.contains(" st ") ||
    lower.contains(" avenue") ||
    lower.contains(" ave ") ||
    lower.contains(" road") ||
    lower.contains(" rd ") ||
    lower.contains(" boulevard") ||
    lower.contains(" blvd") ||
    lower.contains(" suite ") ||
    lower.contains(" ste ")
  )
}

///|
fn looks_like_separator_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let mut symbol_count = 0
  let symbols : Array[Char] = []
  for ch in chars {
    if is_feature_whitespace(ch) {
      continue
    }
    if !is_feature_latin(ch) && !is_feature_cjk(ch) && !is_ascii_digit(ch) {
      symbol_count += 1
      symbols.push(ch)
    } else {
      return false
    }
  }
  symbol_count >= 4 ||
  (symbol_count >= 2 && repeated_separator_symbol_run(symbols))
}

///|
fn looks_like_page_number_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if all_ascii_digits_feature(trimmed) && trimmed.length() <= 4 {
    return true
  }
  if looks_like_cjk_page_number(trimmed) {
    return true
  }
  let lower = trimmed.to_lower()
  if !lower.has_prefix("page ") {
    return false
  }
  let chars = lower.to_array()
  let suffix : Array[Char] = []
  for i = 5; i < chars.length(); i = i + 1 {
    suffix.push(chars[i])
  }
  all_ascii_digits_feature(String::from_array(suffix))
}

///|
fn looks_like_bullet_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_prefix("- ") ||
  trimmed.has_prefix("* ") ||
  trimmed.has_prefix("+ ") ||
  trimmed.has_prefix("• ") ||
  trimmed.has_prefix("•") ||
  trimmed.has_prefix(" ") ||
  trimmed.has_prefix("") ||
  trimmed.has_prefix("1. ") ||
  trimmed.has_prefix("a) ")
}

///|
fn contains_url_signal(text : String) -> Bool {
  let lower = text.to_lower()
  lower.contains("http://") ||
  lower.contains("https://") ||
  lower.contains("www.") ||
  lower.contains("mailto:")
}

///|
fn contains_email_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut at = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '@' {
      at = i
      break
    }
  }
  if at <= 0 || at + 1 >= chars.length() {
    return false
  }
  if is_feature_whitespace(chars[at - 1]) ||
    is_feature_whitespace(chars[at + 1]) {
    return false
  }
  let mut local_start = at
  for i = at - 1; i >= 0; i = i - 1 {
    if is_feature_whitespace(chars[i]) {
      break
    }
    local_start = i
  }
  let mut domain_end = at
  for i = at + 1; i < chars.length(); i = i + 1 {
    if is_feature_whitespace(chars[i]) {
      break
    }
    domain_end = i
  }
  if local_start >= at || domain_end <= at {
    return false
  }
  let local_part = String::from_array(chars[local_start:at].to_owned())
  let domain = String::from_array(chars[at + 1:domain_end + 1].to_owned())
  valid_email_local_part(local_part) && valid_email_domain_part(domain)
}

///|
fn valid_email_local_part(local_part : String) -> Bool {
  let trimmed = local_part.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() == 0 {
    return false
  }
  let mut has_alnum = false
  for ch in chars {
    if !email_local_char(ch) {
      return false
    }
    if is_ascii_alpha(ch) || is_ascii_digit(ch) {
      has_alnum = true
    }
  }
  has_alnum &&
  chars[0] != '.' &&
  chars[0] != '-' &&
  chars[chars.length() - 1] != '.' &&
  chars[chars.length() - 1] != '-'
}

///|
fn email_local_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) ||
  is_ascii_digit(ch) ||
  ch == '.' ||
  ch == '_' ||
  ch == '-' ||
  ch == '+'
}

///|
fn valid_email_domain_part(domain : String) -> Bool {
  let trimmed = domain.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '.' ||
    chars[0] == '-' ||
    chars[chars.length() - 1] == '.' ||
    chars[chars.length() - 1] == '-' {
    return false
  }
  let mut has_dot = false
  let mut last_dot = -1
  let mut has_alpha = false
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if !email_domain_char(ch) {
      return false
    }
    if is_ascii_alpha(ch) {
      has_alpha = true
    }
    if ch == '.' {
      if i == 0 ||
        i + 1 >= chars.length() ||
        chars[i - 1] == '.' ||
        chars[i + 1] == '.' ||
        chars[i - 1] == '-' ||
        chars[i + 1] == '-' {
        return false
      }
      has_dot = true
      last_dot = i
    }
  }
  if !has_dot || !has_alpha || last_dot <= 0 || last_dot + 1 >= chars.length() {
    return false
  }
  let suffix = String::from_array(chars[last_dot + 1:].to_owned())
  suffix.length() >= 2 && contains_ascii_alpha_text(suffix)
}

///|
fn email_domain_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) || is_ascii_digit(ch) || ch == '.' || ch == '-'
}

///|
fn has_raw_hyphen_signal(text : String) -> Bool {
  text.contains("-") ||
  text.contains("‐") ||
  text.contains("‑") ||
  text.contains("–")
}

///|
fn ends_with_colon_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(":") || trimmed.has_suffix("：")
}

///|
fn has_terminal_period_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(".") ||
  trimmed.has_suffix("!") ||
  trimmed.has_suffix("?") ||
  trimmed.has_suffix("。") ||
  trimmed.has_suffix("！") ||
  trimmed.has_suffix("？")
}

///|
fn sentence_end_evidence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  has_terminal_period_signal(trimmed) ||
  contains_clause_punctuation_signal(trimmed) ||
  trimmed.contains(". (") ||
  trimmed.contains(".(") ||
  trimmed.contains("。(") ||
  trimmed.contains("。 (")
}

///|
fn contains_clause_punctuation_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed.to_array() {
    if ch == ',' ||
      ch == ';' ||
      ch == ':' ||
      ch == '，' ||
      ch == '、' ||
      ch == '；' ||
      ch == '：' {
      return true
    }
  }
  false
}

///|
fn has_markdown_escape_chars_signal(text : String) -> Bool {
  text.contains("#") ||
  text.contains("*") ||
  text.contains("[") ||
  text.contains("]") ||
  text.contains("`") ||
  text.contains(">") ||
  text.contains("|")
}

///|
fn form_key_value_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  (trimmed.contains(":") || trimmed.contains("：")) &&
  count_feature_words(trimmed) <= 4 &&
  !has_terminal_period_signal(trimmed)
}

///|
fn option_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains("usage:") ||
    lower.contains("command line") ||
    lower.contains(" switch") ||
    lower.contains(" option") {
    return true
  }
  if trimmed.contains("<") && trimmed.contains(">") {
    return true
  }
  if has_raw_hyphen_signal(trimmed) &&
    ((trimmed.contains("[") && trimmed.contains("]")) || trimmed.contains("=")) {
    return true
  }
  if !(trimmed.has_prefix("--") ||
    trimmed.has_prefix("- - ") ||
    starts_with_short_option_cluster_signal(trimmed)) {
    return false
  }
  lower.contains("timeout") ||
  lower.contains("help") ||
  lower.contains("fatal") ||
  lower.contains("warn") ||
  lower.contains("usage") ||
  lower.contains("python") ||
  lower.contains("listcheck") ||
  lower.contains("listmessage") ||
  lower.contains("custommessage") ||
  lower.contains("logdir") ||
  lower.contains("logfile") ||
  lower.contains("jsondir") ||
  lower.contains(".json") ||
  lower.contains(".jar") ||
  lower.contains(".py") ||
  trimmed.contains("<") ||
  trimmed.contains(">") ||
  trimmed.contains("=")
}

///|
fn starts_with_short_option_cluster_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() >= 3 &&
    chars[0] == '-' &&
    is_ascii_alpha(chars[1]) &&
    (chars[2] == ',' || is_feature_whitespace(chars[2])) {
    return true
  }
  chars.length() >= 4 &&
  is_ascii_alpha(chars[0]) &&
  chars[1] == ',' &&
  is_feature_whitespace(chars[2]) &&
  chars[3] == '-'
}

///|
fn top_zone_candidate(rect : @model.PdfRect, page_box : @model.PdfRect) -> Bool {
  top_ratio(rect, page_box) <= 0.12
}

///|
fn bottom_zone_candidate(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Bool {
  bottom_ratio(rect, page_box) <= 0.12
}

///|
fn repeated_edge_candidate(
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  repeated_text_score : Double,
) -> Bool {
  repeated_text_score >= 0.34 &&
  block.line_count <= 2 &&
  (
    top_zone_candidate(block._bbox, page_box) ||
    bottom_zone_candidate(block._bbox, page_box)
  )
}

///|
fn looks_like_list_marker_token_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed == "-" ||
    trimmed == "*" ||
    trimmed == "+" ||
    trimmed == "•" ||
    trimmed == "" {
    return true
  }
  let chars = trimmed.to_array()
  if chars.length() == 2 &&
    is_ascii_alpha(chars[0]) &&
    (chars[1] == '.' || chars[1] == ')') {
    return true
  }
  if chars.length() >= 2 &&
    chars[0] == '.' &&
    all_ascii_digits_feature(String::from_array(chars[1:].to_owned())) {
    return true
  }
  let last = chars[chars.length() - 1]
  if (last == '.' || last == ')') &&
    all_ascii_digits_feature(
      String::from_array(chars[:chars.length() - 1].to_owned()),
    ) {
    return true
  }
  false
}

///|
fn contains_path_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains("://") || contains_email_signal(trimmed) {
    return false
  }
  if trimmed.has_prefix("./") ||
    trimmed.has_prefix("../") ||
    trimmed.has_prefix("~/") ||
    trimmed.contains("\\") ||
    looks_like_windows_drive_path(trimmed) {
    return true
  }
  if looks_like_dotted_identifier_signal(trimmed) {
    return true
  }
  if lower.contains(".pdf") ||
    lower.contains(".epub") ||
    lower.contains(".xhtml") ||
    lower.contains(".html") ||
    lower.contains(".xml") ||
    lower.contains(".json") ||
    lower.contains(".txt") ||
    lower.contains(".py") ||
    lower.contains(".js") ||
    lower.contains(".css") ||
    lower.contains(".md") {
    return true
  }
  let slash_count = count_char_feature(trimmed, '/')
  slash_count >= 2 &&
  !trimmed.contains(" ") &&
  contains_ascii_alpha_text(trimmed)
}

///|
fn identifier_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if contains_url_signal(trimmed) || contains_email_signal(trimmed) {
    return false
  }
  if looks_like_dotted_identifier_signal(trimmed) ||
    looks_like_windows_drive_path(trimmed) ||
    trimmed.contains("::") {
    return true
  }
  if trimmed.contains("=") && contains_camel_case_token_signal(trimmed) {
    return true
  }
  contains_camel_case_token_signal(trimmed) && count_feature_words(trimmed) <= 3
}

///|
fn technical_literal_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if contains_url_signal(trimmed) || contains_email_signal(trimmed) {
    return false
  }
  if contains_date_signal(trimmed) ||
    contains_time_signal(trimmed) ||
    contains_currency_signal(trimmed) {
    return false
  }
  if quantity_price_signal(trimmed) || payment_card_signal(trimmed) {
    return false
  }
  if technical_sentence_guard_signal(trimmed) {
    return false
  }
  if looks_like_bullet_signal(trimmed) &&
    !option_like_signal(trimmed) &&
    count_feature_words(trimmed) >= 4 {
    return false
  }
  if option_like_signal(trimmed) ||
    contains_path_like_signal(trimmed) ||
    assignment_like_signal(trimmed) {
    return true
  }
  let separator_count = technical_separator_count(trimmed)
  (identifier_like_signal(trimmed) && count_feature_words(trimmed) <= 4) ||
  (
    separator_count >= 3 &&
    count_feature_words(trimmed) <= 12 &&
    !has_terminal_period_signal(trimmed)
  ) ||
  (
    contains_camel_case_token_signal(trimmed) &&
    separator_count >= 2 &&
    count_feature_words(trimmed) <= 6
  )
}

///|
fn sentence_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 5 {
    return false
  }
  if technical_sentence_guard_signal(trimmed) {
    return true
  }
  if technical_literal_signal(trimmed) || !sentence_end_evidence_signal(trimmed) {
    return false
  }
  latin_ratio(trimmed) >= 0.35 ||
  cjk_ratio(trimmed) >= 0.35 ||
  contains_url_signal(trimmed) ||
  contains_email_signal(trimmed)
}

///|
fn figure_reference_sentence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  if caption_marker_starts_line_signal(trimmed) &&
    !caption_lead_in_signal(trimmed) {
    return false
  }
  let has_reference = contains_enumerated_reference_signal(lower, "figure ") ||
    contains_enumerated_reference_signal(lower, "fig. ") ||
    contains_enumerated_reference_signal(lower, "fig ") ||
    contains_enumerated_reference_signal(lower, "table ") ||
    contains_enumerated_reference_signal(lower, "chart ") ||
    contains_enumerated_reference_signal(lower, "图 ") ||
    contains_enumerated_reference_signal(lower, "表 ")
  has_reference &&
  (
    caption_reference_only_signal(trimmed) ||
    caption_lead_in_signal(trimmed) ||
    lower.contains(" below ") ||
    lower.contains(" above ") ||
    lower.contains(" illustrates ") ||
    lower.contains(" illustrate ") ||
    lower.contains(" shows ") ||
    lower.contains(" show ") ||
    lower.contains(" is given in ")
  )
}

///|
fn section_reference_sentence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  contains_enumerated_reference_signal(lower, "section ") ||
  contains_enumerated_reference_signal(lower, "sec. ") ||
  contains_enumerated_reference_signal(lower, "sec ")
}

///|
fn technical_sentence_guard_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  if contains_path_like_signal(trimmed) ||
    option_like_signal(trimmed) ||
    quantity_price_signal(trimmed) ||
    payment_card_signal(trimmed) {
    return false
  }
  if figure_reference_sentence_signal(trimmed) ||
    section_reference_sentence_signal(trimmed) {
    return true
  }
  word_count >= 9 &&
  (
    contains_camel_case_token_signal(trimmed) ||
    (trimmed.contains("(") && trimmed.contains(")")) ||
    trimmed.contains("=")
  ) &&
  (latin_ratio(trimmed) >= 0.35 || cjk_ratio(trimmed) >= 0.35)
}

///|
fn citation_reference_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '[' {
    let mut close = -1
    for i = 1; i < chars.length(); i = i + 1 {
      if chars[i] == ']' {
        close = i
        break
      }
      if !is_ascii_digit(chars[i]) {
        return false
      }
    }
    return close >= 2 &&
      close + 1 < chars.length() &&
      is_feature_whitespace(chars[close + 1])
  }
  if chars[0] == '(' {
    let mut close = -1
    for i = 1; i < chars.length(); i = i + 1 {
      if chars[i] == ')' {
        close = i
        break
      }
      if !is_ascii_digit(chars[i]) {
        return false
      }
    }
    return close >= 2 &&
      close + 1 < chars.length() &&
      is_feature_whitespace(chars[close + 1])
  }
  false
}

///|
fn page_label_pattern_signal(text : String) -> Bool {
  let parts = text.trim().split(" ")
  let mut saw_page = false
  let mut saw_page_number = false
  for part in parts {
    let token = part.trim().to_owned().to_lower()
    if token == "" {
      continue
    }
    if saw_page {
      if !saw_page_number {
        if !all_ascii_digits_feature(token) {
          return false
        }
        saw_page_number = true
        continue
      }
      return false
    }
    if token == "page" {
      saw_page = true
    }
  }
  saw_page && saw_page_number
}

///|
fn contains_enumerated_reference_signal(
  lower : String,
  prefix : String,
) -> Bool {
  let chars = lower.to_array()
  let prefix_chars = prefix.to_array()
  if prefix_chars.is_empty() || chars.length() <= prefix_chars.length() {
    return false
  }
  for i = 0; i + prefix_chars.length() < chars.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < prefix_chars.length(); j = j + 1 {
      if chars[i + j] != prefix_chars[j] {
        matched = false
        break
      }
    }
    if matched && is_ascii_digit(chars[i + prefix_chars.length()]) {
      return true
    }
  }
  false
}

///|
fn cleanup_shell_signal(
  text : String,
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  repeated_text_score : Double,
  page_block_count : Int,
  page_median_font_size : Double?,
) -> Bool {
  let relative = relative_font_size(
    block.dominant_font_size,
    page_median_font_size,
  )
  let relative_ok = match relative {
    Some(value) => value >= 0.9 && value <= 1.15
    None => true
  }
  repeated_edge_candidate(block, page_box, repeated_text_score) &&
  top_zone_candidate(block._bbox, page_box) &&
  page_label_pattern_signal(text) &&
  block.line_count == 1 &&
  count_feature_words(text) >= 3 &&
  count_feature_words(text) <= 6 &&
  !has_terminal_period_signal(text) &&
  !contains_clause_punctuation_signal(text) &&
  page_block_count <= 6 &&
  relative_ok
}

///|
fn sku_like_signal(text : String) -> Bool {
  for part in text.trim().split(" ") {
    if looks_like_sku_token(part.trim().to_owned()) {
      return true
    }
  }
  false
}

///|
fn quantity_price_signal(text : String) -> Bool {
  contains_currency_signal(text) &&
  text.contains("@") &&
  count_numeric_runs(text) >= 2
}

///|
fn payment_card_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  (
    lower.contains("card") ||
    lower.contains("payment") ||
    lower.contains("credit") ||
    lower.contains("debit")
  ) &&
  (
    lower.contains("ending in ") ||
    lower.contains("ending ") ||
    lower.contains("last4") ||
    lower.contains("last 4")
  ) &&
  has_four_digit_run(trimmed)
}
