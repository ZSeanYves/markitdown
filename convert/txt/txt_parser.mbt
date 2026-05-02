///|
pub fn parse_txt(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("txt: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("txt: read failed: " + e.to_string())
  }

  let raw = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("txt: utf8 decode failed: " + e.to_string())
  }

  let text = normalize_txt_text(raw)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  for para in paragraph_spans(text) {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph(para.text),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(para.line_start),
        line_end: Some(para.line_end),
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }

  doc
}

///|
priv struct ParagraphSpan {
  text : String
  line_start : Int
  line_end : Int
}

///|
fn normalize_txt_text(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }

  without_bom.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}

///|
fn paragraph_spans(text : String) -> Array[ParagraphSpan] {
  if text == "" {
    return []
  }

  let lines = split_lines_preserve_trailing(text)
  let out : Array[ParagraphSpan] = []
  let current : Array[String] = []
  let mut line_start = 0
  let mut line_end = 0

  for i in 0..<lines.length() {
    let line_no = i + 1
    let trimmed = lines[i].trim().to_owned()
    if trimmed == "" {
      if current.length() > 0 {
        out.push({ text: current.join(" "), line_start, line_end })
        current.clear()
        line_start = 0
        line_end = 0
      }
      continue
    }

    if current.length() == 0 {
      line_start = line_no
    }
    current.push(trimmed)
    line_end = line_no
  }

  if current.length() > 0 {
    out.push({ text: current.join(" "), line_start, line_end })
  }

  out
}

///|
fn split_lines_preserve_trailing(text : String) -> Array[String] {
  let out : Array[String] = []
  let line : Array[Char] = []

  for ch in text.to_array() {
    if ch == '\n' {
      out.push(String::from_array(line))
      line.clear()
    } else {
      line.push(ch)
    }
  }

  out.push(String::from_array(line))
  out
}
