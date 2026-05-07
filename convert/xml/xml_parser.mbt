///|
pub fn parse_xml(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("xml: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("xml: read failed: " + e.to_string())
  }

  let raw = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("xml: utf8 decode failed: " + e.to_string())
  }

  let text = normalize_xml_text(raw)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if text.trim() != "" {
    @cor.set_passthrough_markdown(doc, xml_fenced_markdown(text))
    @cor.push_with_origin(
      doc,
      @cor.Block::CodeBlock(text),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(1),
        line_end: Some(physical_line_count(text)),
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
fn normalize_xml_text(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(ch)
      i = i + 1
    }
  }

  String::from_array(out)
}

///|
fn xml_fenced_markdown(text : String) -> String {
  let fence = "`".repeat(required_fence_width(text))
  if text.has_suffix("\n") {
    fence + "xml\n" + text + fence + "\n"
  } else {
    fence + "xml\n" + text + "\n" + fence + "\n"
  }
}

///|
fn required_fence_width(text : String) -> Int {
  let chars = text.to_array()
  let mut longest = 0
  let mut current = 0

  for ch in chars {
    if ch == '`' {
      current = current + 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }

  if longest + 1 < 3 {
    3
  } else {
    longest + 1
  }
}

///|
fn physical_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }

  let mut count = 1
  let chars = text.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '\n' && i + 1 < chars.length() {
      count = count + 1
    }
  }
  count
}
