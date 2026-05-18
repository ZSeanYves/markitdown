///|
fn collect_visible_form_notes(page : PdfConvertPage) -> Array[String] {
  let out : Array[String] = []
  for form in page.forms {
    if !should_emit_visible_widget_form_in_markdown(form) {
      continue
    }
    match render_visible_form_note(form, page._page_index) {
      Some(text) => out.push(text)
      None => ()
    }
  }
  out
}

///|
fn render_visible_form_note(
  form : PdfConvertFormField,
  page_index : Int,
) -> String? {
  let label = match normalized_optional_annotation_field(form.field_name) {
    Some(name) => name
    None => "Field " + (form._form_index + 1).to_string()
  }

  let body = match form.field_type {
    "/Tx" =>
      match normalized_optional_annotation_field(form.field_value) {
        Some(value) => Some(value)
        None => None
      }
    "/Ch" => {
      let value = normalized_optional_annotation_field(form.field_value)
      match value {
        Some(v) => Some(v)
        None =>
          if !form.options.is_empty() {
            Some("options: " + form.options.join(", "))
          } else {
            None
          }
      }
    }
    "/Btn" =>
      match form.checked_state {
        Some(true) => Some("checked")
        Some(false) => Some("unchecked")
        None =>
          match normalized_optional_annotation_field(form.field_value) {
            Some(v) => Some(v)
            None => None
          }
      }
    _ =>
      match normalized_optional_annotation_field(form.field_value) {
        Some(value) => Some(value)
        None => None
      }
  }

  match body {
    Some(text) =>
      if text.trim() == "" {
        None
      } else {
        Some(
          form_type_label(form.field_type) +
          " (page " +
          (page_index + 1).to_string() +
          "): " +
          label +
          " — " +
          normalize_pdf_form_value_text(text),
        )
      }
    None => None
  }
}

///|
fn should_emit_visible_widget_form_in_markdown(
  form : PdfConvertFormField,
) -> Bool {
  @model.pdf_annotation_is_view_visible(form.flags)
}

///|
fn normalize_pdf_form_value_text(text : String) -> String {
  normalize_pdf_form_value_breaks(text)
  .split("\n")
  .map(fn(line) { line.trim().to_owned() })
  .filter(fn(line) { line != "" })
  .join(" / ")
}

///|
fn normalize_pdf_form_value_breaks(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
      continue
    }

    let br_len = html_break_tag_length(chars, i)
    if br_len > 0 {
      out.push('\n')
      i = i + br_len
      continue
    }

    out.push(chars[i])
    i = i + 1
  }

  String::from_array(out)
}

///|
fn html_break_tag_length(chars : Array[Char], start : Int) -> Int {
  if start < 0 || start >= chars.length() || chars[start] != '<' {
    return 0
  }
  if start + 3 >= chars.length() {
    return 0
  }
  if !ascii_char_eq_ignore_case(chars[start + 1], 'b') {
    return 0
  }
  if !ascii_char_eq_ignore_case(chars[start + 2], 'r') {
    return 0
  }

  let mut i = start + 3
  while i < chars.length() && chars[i] == ' ' {
    i = i + 1
  }
  if i < chars.length() && chars[i] == '/' {
    i = i + 1
    while i < chars.length() && chars[i] == ' ' {
      i = i + 1
    }
  }
  if i < chars.length() && chars[i] == '>' {
    i - start + 1
  } else {
    0
  }
}

///|
fn ascii_char_eq_ignore_case(ch : Char, expected_lower : Char) -> Bool {
  if ch == expected_lower {
    true
  } else if expected_lower >= 'a' && expected_lower <= 'z' {
    let expected_upper = Char::from_int(
      expected_lower.to_int() - ('a'.to_int() - 'A'.to_int()),
    )
    ch == expected_upper
  } else {
    false
  }
}

///|
fn form_type_label(field_type : String) -> String {
  match field_type.trim() {
    "/Tx" => "Text"
    "/Ch" => "Choice"
    "/Btn" => "Button"
    raw => if raw.has_prefix("/") { raw[1:].to_owned() } else { raw.to_owned() }
  }
}

///|
fn emit_pdf_form_notes_to_ir(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  notes : Array[String],
) -> Unit {
  for text in notes {
    @cor.push_with_origin(
      out,
      @cor.Block::Paragraph(text),
      Some({
        source_name: Some(source_name),
        page: Some(page_index + 1),
        slide: None,
        sheet: None,
        block_index: Some(out.blocks.val.length()),
        heading_path: Some(["Forms"]),
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }
}
