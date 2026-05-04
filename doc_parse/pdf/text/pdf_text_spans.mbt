///|
/// 页级 span 结果。
pub struct PdfPageSpans {
  page_index : Int
  spans : Array[@model.PdfTextSpan]
}

///|
/// 文档级 span 结果。
pub struct PdfDocumentSpans {
  pages : Array[PdfPageSpans]
}

///|
/// 从文档字符结果构建 span 结果。
pub fn build_document_spans(doc_chars : PdfDocumentChars) -> PdfDocumentSpans {
  let pages = Array::new()
  for page in doc_chars.pages {
    pages.push(build_page_spans(page))
  }
  { pages, }
}

///|
/// 从单页字符结果构建 spans。
pub fn build_page_spans(page_chars : PdfPageChars) -> PdfPageSpans {
  {
    page_index: page_chars.page_index,
    spans: build_spans_from_chars(page_chars.chars),
  }
}

///|
/// 从字符数组构建 spans。
///
/// 第一版规则：
/// - 同 source_stream_index
/// - 同 source_op_index
/// - 同 text_object_id
/// - 同 font_name
/// - 同 font_size
///
/// 就继续并进同一个 span。
pub fn build_spans_from_chars(
  chars : Array[@model.PdfChar],
) -> Array[@model.PdfTextSpan] {
  if chars.is_empty() {
    return []
  }

  let out = Array::new()

  let mut current_chars : Array[@model.PdfChar] = [chars[0]]
  let mut span_index = 0

  for i = 1; i < chars.length(); i = i + 1 {
    let prev = current_chars[current_chars.length() - 1]
    let cur = chars[i]

    if should_join_same_span(prev, cur) {
      current_chars.push(cur)
    } else {
      out.push(make_span_from_chars(current_chars, span_index))
      span_index = span_index + 1
      current_chars = [cur]
    }
  }

  out.push(make_span_from_chars(current_chars, span_index))
  out
}

///|
/// 判断两个字符是否应属于同一个最小 span。
fn should_join_same_span(left : @model.PdfChar, right : @model.PdfChar) -> Bool {
  same_source_group(left.source, right.source) &&
  left.font_name == right.font_name &&
  left.font_size == right.font_size
}

///|
/// 最小来源组一致：
/// 同页、同 stream、同 op、同 text object。
fn same_source_group(a : @model.PdfSourceRef, b : @model.PdfSourceRef) -> Bool {
  a.page_index == b.page_index &&
  a.source_stream_index == b.source_stream_index &&
  a.source_op_index == b.source_op_index &&
  a.text_object_id == b.text_object_id
}

///|
/// 由字符数组构造一个 span。
pub fn make_span_from_chars(
  chars : Array[@model.PdfChar],
  span_index : Int,
) -> @model.PdfTextSpan {
  let first = chars[0]
  let origin = first.origin
  let text = join_chars_text(chars)
  let source_refs = collect_source_refs(chars)

  let raw_bbox = @model.chars_bbox(chars)
  let bbox = match raw_bbox {
    Some(r) =>
      if is_useful_rect(r) {
        r
      } else {
        estimate_span_bbox(chars, origin, first.font_size)
      }
    None => estimate_span_bbox(chars, origin, first.font_size)
  }

  {
    id: make_span_id(first.source.page_index, span_index),
    bbox,
    origin,
    text,
    font_name: first.font_name,
    font_family: None,
    font_size: first.font_size,
    is_bold: false,
    is_italic: false,
    is_monospace: false,
    fill_color: first.fill_color,
    stroke_color: None,
    char_spacing: None,
    word_spacing: None,
    text_rise: None,
    scale_x: None,
    writing_direction: infer_writing_direction1(chars),
    language_hint: None,
    chars,
    source_refs,
    break_before: first.break_before,
    break_reason: first.break_reason,
  }
}

///|
/// 当前 bbox 是否真的可用，而不是默认零矩形。
fn is_useful_rect(rect : @model.PdfRect) -> Bool {
  @model.is_rect_valid(rect) && (rect.x1 > rect.x0 || rect.y1 > rect.y0)
}

///|
/// 在 glyph bbox 还不可用时，用 origin + 字号 + 文本长度粗估 span bbox。
fn estimate_span_bbox(
  chars : Array[@model.PdfChar],
  origin : @model.PdfPoint,
  font_size : Double?,
) -> @model.PdfRect {
  let fs = font_size.unwrap_or(12.0)
  let width = estimate_chars_width(chars, fs)

  {
    x0: origin.x,
    y0: origin.y - fs * 0.85,
    x1: origin.x + width,
    y1: origin.y + fs * 0.25,
  }
}

///|
/// 粗估字符总宽度。
fn estimate_chars_width(
  chars : Array[@model.PdfChar],
  font_size : Double,
) -> Double {
  let mut total = 0.0
  for ch in chars {
    total = total + estimate_single_char_width(ch, font_size)
  }
  if total <= 0.0 {
    font_size
  } else {
    total
  }
}

///|
/// 单字符宽度粗估：
/// - CJK 约 1.0em
/// - ASCII 字母/数字约 0.6em
/// - 空格约 0.33em
/// - 其他约 0.5em
fn estimate_single_char_width(
  ch : @model.PdfChar,
  font_size : Double,
) -> Double {
  let text = ch.decoded_text
  let c = first_char_opt_local(text)

  match c {
    Some(x) =>
      if is_cjk_char_local(x) {
        font_size
      } else if x == ' ' || x == '\t' {
        font_size * 0.33
      } else if is_ascii_letter_local(x) || is_ascii_digit_local(x) {
        font_size * 0.6
      } else {
        font_size * 0.5
      }
    None => font_size * 0.5
  }
}

///|
fn first_char_opt_local(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn is_ascii_letter_local(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ascii_digit_local(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_cjk_char_local(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
/// 拼接字符文本。
///
/// 第一版直接用 decoded_text 顺序拼接。
fn join_chars_text(chars : Array[@model.PdfChar]) -> String {
  let mut buf = ""
  for ch in chars {
    buf = buf + ch.decoded_text
  }
  buf
}

///|
/// 收集去重后的 source refs。
///
/// 第一版去重规则很保守：
/// 同 page/stream/op/text_object/content_order/source_object_ref 则视为同一来源。
fn collect_source_refs(
  chars : Array[@model.PdfChar],
) -> Array[@model.PdfSourceRef] {
  let out = Array::new()
  for ch in chars {
    if !source_refs_contains(out, ch.source) {
      out.push(ch.source)
    }
  }
  out
}

///|
fn source_refs_contains(
  refs : Array[@model.PdfSourceRef],
  target : @model.PdfSourceRef,
) -> Bool {
  for r in refs {
    if same_source_ref(r, target) {
      return true
    }
  }
  false
}

///|
fn same_source_ref(a : @model.PdfSourceRef, b : @model.PdfSourceRef) -> Bool {
  a.page_index == b.page_index &&
  a.source_stream_index == b.source_stream_index &&
  a.source_op_index == b.source_op_index &&
  a.text_object_id == b.text_object_id &&
  a.content_order_index == b.content_order_index &&
  a.source_object_ref == b.source_object_ref
}

///|
/// 第一版书写方向先统一给 LTR。
///
/// 后面如果你开始接：
/// - rotation
/// - Tm
/// - x/y 递增
/// 再升级这里。
fn infer_writing_direction1(
  _chars : Array[@model.PdfChar],
) -> @model.PdfWritingDirection {
  @model.PdfWritingDirection::LeftToRight
}

///|
fn make_span_id(page_index : Int, span_index : Int) -> String {
  "p" + page_index.to_string() + "_span_" + span_index.to_string()
}
