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
  let bbox = @model.chars_bbox(chars).unwrap_or(default_rect())
  let origin = first.origin
  let text = join_chars_text(chars)
  let source_refs = collect_source_refs(chars)

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
