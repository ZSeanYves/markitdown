///|
pub enum PdfLayoutRecordKind {
  Line
  Block
  Boundary
} derive(Eq)

///|
pub struct PdfLayoutFeature {
  sample_id : String
  source_path : String
  record_kind : PdfLayoutRecordKind
  label : String?
  page_index : Int
  block_index : Int
  line_index : Int
  next_page_index : Int?
  next_block_index : Int?
  next_line_index : Int?
  text : String
  notes : String?
  feature_values : Map[String, Double]
}

///|
pub fn default_pdf_layout_feature_names() -> Array[String] {
  [
    "text_len", "normalized_text_len", "word_count", "digit_ratio", "punctuation_ratio",
    "uppercase_ratio", "cjk_ratio", "x0", "y0", "x1", "y1", "width", "height", "page_width",
    "page_height", "x_center_ratio", "y_center_ratio", "top_ratio", "bottom_ratio",
    "font_size_hint", "bold_hint", "line_gap_before", "line_gap_after", "indent_left",
    "alignment_hint", "near_image_distance", "page_edge_distance", "repeated_text_score",
    "source_ref_count", "is_heading_candidate", "is_page_number_candidate", "is_header_footer_candidate",
    "is_artifact_candidate", "is_caption_candidate", "is_table_cell_candidate", "is_noise_kind",
    "is_heading_kind", "line_count", "prev_gap_before", "next_gap_before", "prev_font_size_delta",
    "next_font_size_delta", "same_paragraph_candidate", "wrapped_candidate", "boundary_prev_no_sentence_end",
    "boundary_next_starts_lowercase", "boundary_next_continues_sentence", "boundary_similar_indent",
    "boundary_same_column_band", "boundary_table_guard", "boundary_caption_guard",
    "boundary_noise_guard", "boundary_heading_guard", "boundary_list_guard", "boundary_layout_compatible",
  ]
}

///|
pub fn default_pdf_layout_feature_tsv_columns() -> Array[String] {
  let out : Array[String] = [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "next_page_index", "next_block_index", "next_line_index", "text", "label",
  ]
  for name in default_pdf_layout_feature_names() {
    out.push(name)
  }
  out.push("notes")
  out
}

///|
pub fn render_pdf_layout_feature_tsv(
  features : Array[PdfLayoutFeature],
  feature_names : Array[String],
) -> String {
  let columns = feature_tsv_columns(feature_names)
  let lines : Array[String] = [columns.join("\t")]
  for feature in features {
    lines.push(render_pdf_layout_feature_row(feature, feature_names).join("\t"))
  }
  lines.join("\n") + "\n"
}

///|
pub fn render_pdf_layout_feature_row(
  feature : PdfLayoutFeature,
  feature_names : Array[String],
) -> Array[String] {
  let row : Array[String] = [
    tsv_escape(feature.sample_id),
    tsv_escape(feature.source_path),
    tsv_escape(pdf_layout_record_kind_name(feature.record_kind)),
    (feature.page_index + 1).to_string(),
    feature.block_index.to_string(),
    feature.line_index.to_string(),
    int_opt_tsv(feature.next_page_index, true),
    int_opt_tsv(feature.next_block_index, false),
    int_opt_tsv(feature.next_line_index, false),
    tsv_escape(feature.text),
    tsv_escape(
      match feature.label {
        Some(label) => label
        None => ""
      },
    ),
  ]

  for name in feature_names {
    row.push(tsv_escape(double_opt_tsv(feature.feature_values.get(name))))
  }

  row.push(
    tsv_escape(
      match feature.notes {
        Some(notes) => notes
        None => ""
      },
    ),
  )
  row
}

///|
pub fn make_pdf_layout_feature(
  sample_id : String,
  source_path : String,
  record_kind : PdfLayoutRecordKind,
  page_index : Int,
  block_index : Int,
  line_index : Int,
  next_page_index : Int?,
  next_block_index : Int?,
  next_line_index : Int?,
  text : String,
  label : String?,
  notes : String?,
  feature_values : Map[String, Double],
) -> PdfLayoutFeature {
  {
    sample_id,
    source_path,
    record_kind,
    label,
    page_index,
    block_index,
    line_index,
    next_page_index,
    next_block_index,
    next_line_index,
    text,
    notes,
    feature_values,
  }
}

///|
fn block_layout_feature_values(
  page : PdfConvertPage,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  repeated_text_score : Double,
  near_image_distance : Double?,
) -> Map[String, Double] {
  let out : Map[String, Double] = Map::new()
  let page_box = effective_page_box_for_convert_page(page)
  let page_width = @model.rect_width(page_box)
  let page_height = @model.rect_height(page_box)
  let normalized = normalize_pdf_comparison_text(block.text)
  let word_count = count_feature_words(normalized)

  set_feature(out, "text_len", block.text.length().to_double())
  set_feature(out, "normalized_text_len", normalized.length().to_double())
  set_feature(out, "word_count", word_count.to_double())
  set_feature(out, "digit_ratio", digit_ratio(block.text))
  set_feature(out, "punctuation_ratio", punctuation_ratio(block.text))
  set_feature(out, "uppercase_ratio", uppercase_ratio(block.text))
  set_feature(out, "cjk_ratio", cjk_ratio(block.text))
  set_feature(out, "x0", block._bbox.x0)
  set_feature(out, "y0", block._bbox.y0)
  set_feature(out, "x1", block._bbox.x1)
  set_feature(out, "y1", block._bbox.y1)
  set_feature(out, "width", @model.rect_width(block._bbox))
  set_feature(out, "height", @model.rect_height(block._bbox))
  set_feature(out, "page_width", page_width)
  set_feature(out, "page_height", page_height)
  set_feature(out, "x_center_ratio", rect_center_x_ratio(block._bbox, page_box))
  set_feature(out, "y_center_ratio", rect_center_y_ratio(block._bbox, page_box))
  set_feature(out, "top_ratio", top_ratio(block._bbox, page_box))
  set_feature(out, "bottom_ratio", bottom_ratio(block._bbox, page_box))
  set_feature_opt(out, "font_size_hint", block.dominant_font_size)
  set_feature(out, "bold_hint", bold_hint(block))
  set_feature_opt(out, "line_gap_before", block.first_line_gap_before)
  set_feature_opt(out, "line_gap_after", block.last_line_gap_after)
  set_feature_opt(out, "indent_left", block.first_indent_left)
  set_feature(
    out,
    "alignment_hint",
    alignment_hint_value(block.first_alignment_hint),
  )
  set_feature_opt(out, "near_image_distance", near_image_distance)
  set_feature(
    out,
    "page_edge_distance",
    page_edge_distance(block._bbox, page_box),
  )
  set_feature(out, "repeated_text_score", repeated_text_score)
  set_feature(
    out,
    "source_ref_count",
    block_source_ref_count(block).to_double(),
  )
  set_feature(
    out,
    "is_heading_candidate",
    bool_feature(block.is_heading_candidate),
  )
  set_feature(
    out,
    "is_page_number_candidate",
    bool_feature(block.is_noise_candidate),
  )
  set_feature(
    out,
    "is_header_footer_candidate",
    bool_feature(block.is_header_footer_candidate),
  )
  set_feature(
    out,
    "is_artifact_candidate",
    bool_feature(block.is_artifact_candidate),
  )
  set_feature(
    out,
    "is_caption_candidate",
    bool_feature(block.is_caption_candidate),
  )
  set_feature(
    out,
    "is_table_cell_candidate",
    bool_feature(block.is_table_cell_candidate),
  )
  set_feature(
    out,
    "is_noise_kind",
    bool_feature(block.kind == PdfConvertBlockKind::Noise),
  )
  set_feature(
    out,
    "is_heading_kind",
    bool_feature(block.kind == PdfConvertBlockKind::Heading),
  )
  set_feature(out, "line_count", block.line_count.to_double())
  set_feature_opt(
    out,
    "prev_gap_before",
    match prev {
      Some(p) => p.first_line_gap_before
      None => None
    },
  )
  set_feature_opt(
    out,
    "next_gap_before",
    match next {
      Some(n) => n.first_line_gap_before
      None => None
    },
  )
  set_feature(
    out,
    "prev_font_size_delta",
    font_size_delta(
      block.dominant_font_size,
      match prev {
        Some(p) => p.dominant_font_size
        None => None
      },
    ),
  )
  set_feature(
    out,
    "next_font_size_delta",
    font_size_delta(
      block.dominant_font_size,
      match next {
        Some(n) => n.dominant_font_size
        None => None
      },
    ),
  )
  set_feature(
    out,
    "same_paragraph_candidate",
    bool_feature(
      block.first_is_same_paragraph_with_prev_candidate ||
      block.last_is_same_paragraph_with_prev_candidate,
    ),
  )
  set_feature(
    out,
    "wrapped_candidate",
    bool_feature(
      block.first_is_wrapped_candidate || block.last_is_wrapped_candidate,
    ),
  )
  zero_boundary_fields(out)
  out
}

///|
fn boundary_layout_feature_values(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> Map[String, Double] {
  let out : Map[String, Double] = Map::new()
  let decision = collect_page_boundary_merge_evidence(prev_page, cur_page)
  set_feature(out, "text_len", 0.0)
  set_feature(out, "normalized_text_len", 0.0)
  set_feature(out, "word_count", 0.0)
  set_feature(out, "digit_ratio", 0.0)
  set_feature(out, "punctuation_ratio", 0.0)
  set_feature(out, "uppercase_ratio", 0.0)
  set_feature(out, "cjk_ratio", 0.0)
  set_feature(out, "x0", 0.0)
  set_feature(out, "y0", 0.0)
  set_feature(out, "x1", 0.0)
  set_feature(out, "y1", 0.0)
  set_feature(out, "width", 0.0)
  set_feature(out, "height", 0.0)
  set_feature(out, "page_width", 0.0)
  set_feature(out, "page_height", 0.0)
  set_feature(out, "x_center_ratio", 0.0)
  set_feature(out, "y_center_ratio", 0.0)
  set_feature(out, "top_ratio", 0.0)
  set_feature(out, "bottom_ratio", 0.0)
  set_feature(out, "font_size_hint", 0.0)
  set_feature(out, "bold_hint", 0.0)
  set_feature(out, "line_gap_before", 0.0)
  set_feature(out, "line_gap_after", 0.0)
  set_feature(out, "indent_left", 0.0)
  set_feature(out, "alignment_hint", 0.0)
  set_feature(out, "near_image_distance", 0.0)
  set_feature(out, "page_edge_distance", 0.0)
  set_feature(out, "repeated_text_score", 0.0)
  set_feature(out, "source_ref_count", 0.0)
  set_feature(out, "is_heading_candidate", 0.0)
  set_feature(out, "is_page_number_candidate", 0.0)
  set_feature(out, "is_header_footer_candidate", 0.0)
  set_feature(out, "is_artifact_candidate", 0.0)
  set_feature(out, "is_caption_candidate", 0.0)
  set_feature(out, "is_table_cell_candidate", 0.0)
  set_feature(out, "is_noise_kind", 0.0)
  set_feature(out, "is_heading_kind", 0.0)
  set_feature(out, "line_count", 0.0)
  set_feature(out, "prev_gap_before", 0.0)
  set_feature(out, "next_gap_before", 0.0)
  set_feature(out, "prev_font_size_delta", 0.0)
  set_feature(out, "next_font_size_delta", 0.0)
  set_feature(
    out,
    "same_paragraph_candidate",
    bool_feature(decision.same_paragraph_candidate),
  )
  set_feature(
    out,
    "wrapped_candidate",
    bool_feature(decision.wrapped_line_continuation),
  )
  set_feature(
    out,
    "boundary_prev_no_sentence_end",
    bool_feature(decision.previous_no_sentence_end),
  )
  set_feature(
    out,
    "boundary_next_starts_lowercase",
    bool_feature(decision.next_starts_lowercase),
  )
  set_feature(
    out,
    "boundary_next_continues_sentence",
    bool_feature(decision.next_continues_sentence),
  )
  set_feature(
    out,
    "boundary_similar_indent",
    bool_feature(decision.similar_indent),
  )
  set_feature(
    out,
    "boundary_same_column_band",
    bool_feature(decision.same_column_band),
  )
  set_feature(out, "boundary_table_guard", bool_feature(decision.table_guard))
  set_feature(
    out,
    "boundary_caption_guard",
    bool_feature(decision.caption_guard),
  )
  set_feature(out, "boundary_noise_guard", bool_feature(decision.noise_guard))
  set_feature(
    out,
    "boundary_heading_guard",
    bool_feature(decision.heading_guard),
  )
  set_feature(out, "boundary_list_guard", bool_feature(decision.list_guard))
  set_feature(
    out,
    "boundary_layout_compatible",
    bool_feature(decision.layout_compatible),
  )
  out
}

///|
fn feature_tsv_columns(feature_names : Array[String]) -> Array[String] {
  let out : Array[String] = [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "next_page_index", "next_block_index", "next_line_index", "text", "label",
  ]
  for name in feature_names {
    out.push(name)
  }
  out.push("notes")
  out
}

///|
fn set_feature(out : Map[String, Double], key : String, value : Double) -> Unit {
  out.set(key, value)
}

///|
fn set_feature_opt(
  out : Map[String, Double],
  key : String,
  value : Double?,
) -> Unit {
  match value {
    Some(v) => out.set(key, v)
    None => ()
  }
}

///|
fn zero_boundary_fields(out : Map[String, Double]) -> Unit {
  set_feature(out, "boundary_prev_no_sentence_end", 0.0)
  set_feature(out, "boundary_next_starts_lowercase", 0.0)
  set_feature(out, "boundary_next_continues_sentence", 0.0)
  set_feature(out, "boundary_similar_indent", 0.0)
  set_feature(out, "boundary_same_column_band", 0.0)
  set_feature(out, "boundary_table_guard", 0.0)
  set_feature(out, "boundary_caption_guard", 0.0)
  set_feature(out, "boundary_noise_guard", 0.0)
  set_feature(out, "boundary_heading_guard", 0.0)
  set_feature(out, "boundary_list_guard", 0.0)
  set_feature(out, "boundary_layout_compatible", 0.0)
}

///|
fn count_feature_words(text : String) -> Int {
  if text.trim() == "" {
    return 0
  }

  let mut count = 0
  for part in text.split(" ") {
    if part.trim() != "" {
      count += 1
    }
  }
  count
}

///|
fn digit_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= '0' && ch <= '9' })
}

///|
fn punctuation_ratio(text : String) -> Double {
  char_ratio(text, is_feature_punctuation)
}

///|
fn uppercase_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= 'A' && ch <= 'Z' })
}

///|
fn cjk_ratio(text : String) -> Double {
  char_ratio(text, is_feature_cjk)
}

///|
fn char_ratio(text : String, pred : (Char) -> Bool) -> Double {
  let chars = text.to_array()
  if chars.length() == 0 {
    return 0.0
  }

  let mut hits = 0
  for ch in chars {
    if pred(ch) {
      hits += 1
    }
  }
  hits.to_double() / chars.length().to_double()
}

///|
fn is_feature_punctuation(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ':' ||
  ch == ';' ||
  ch == '!' ||
  ch == '?' ||
  ch == '-' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '"' ||
  ch == '\'' ||
  ch == '。' ||
  ch == '，' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？'
}

///|
fn is_feature_cjk(ch : Char) -> Bool {
  let v = ch.to_int()
  (v >= 0x4E00 && v <= 0x9FFF) ||
  (v >= 0x3400 && v <= 0x4DBF) ||
  (v >= 0x3040 && v <= 0x30FF) ||
  (v >= 0xAC00 && v <= 0xD7AF)
}

///|
fn rect_center_x_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let width = @model.rect_width(page_box)
  if width <= 0.0 {
    return 0.0
  }
  ((rect.x0 + rect.x1) / 2.0 - page_box.x0) / width
}

///|
fn rect_center_y_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  ((rect.y0 + rect.y1) / 2.0 - page_box.y0) / height
}

///|
fn top_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (page_box.y1 - rect.y1) / height
}

///|
fn bottom_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (rect.y0 - page_box.y0) / height
}

///|
fn page_edge_distance(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let top = abs_feature_f64(page_box.y1 - rect.y1)
  let bottom = abs_feature_f64(rect.y0 - page_box.y0)
  let left = abs_feature_f64(rect.x0 - page_box.x0)
  let right = abs_feature_f64(page_box.x1 - rect.x1)
  min_feature_f64(min_feature_f64(top, bottom), min_feature_f64(left, right))
}

///|
fn block_source_ref_count(block : PdfConvertBlock) -> Int {
  block.source_block_line_count
}

///|
fn bold_hint(block : PdfConvertBlock) -> Double {
  match block.dominant_font_name {
    Some(name) => if name.to_lower().contains("bold") { 1.0 } else { 0.0 }
    None => 0.0
  }
}

///|
fn alignment_hint_value(value : String?) -> Double {
  match value {
    Some(raw) => {
      let v = raw.to_lower()
      if v == "left" {
        0.0
      } else if v == "center" {
        1.0
      } else if v == "right" {
        2.0
      } else if v == "justify" {
        3.0
      } else {
        -1.0
      }
    }
    None => -1.0
  }
}

///|
fn font_size_delta(current : Double?, neighbor : Double?) -> Double {
  match (current, neighbor) {
    (Some(a), Some(b)) => a - b
    _ => 0.0
  }
}

///|
fn effective_page_box_for_convert_page(page : PdfConvertPage) -> @model.PdfRect {
  match page.crop_box {
    Some(box) => box
    None =>
      match page.media_box {
        Some(box) => box
        None => { x0: 0.0, y0: 0.0, x1: 1.0, y1: 1.0 }
      }
  }
}

///|
fn bool_feature(v : Bool) -> Double {
  if v {
    1.0
  } else {
    0.0
  }
}

///|
fn pdf_layout_record_kind_name(kind : PdfLayoutRecordKind) -> String {
  match kind {
    PdfLayoutRecordKind::Line => "line"
    PdfLayoutRecordKind::Block => "block"
    PdfLayoutRecordKind::Boundary => "boundary"
  }
}

///|
fn int_opt_tsv(value : Int?, one_based_page : Bool) -> String {
  match value {
    Some(v) => if one_based_page { (v + 1).to_string() } else { v.to_string() }
    None => ""
  }
}

///|
fn double_opt_tsv(value : Double?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

///|
fn tsv_escape(text : String) -> String {
  text
  .replace_all(old="\t", new=" ")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\n", new=" ")
}

///|
fn abs_feature_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn min_feature_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
