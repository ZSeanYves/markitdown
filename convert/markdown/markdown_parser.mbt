///|
/// Markdown passthrough converter entrypoint.
///
/// Design boundary:
/// - reads UTF-8 markdown bytes
/// - preserves original body for final markdown emission
/// - only performs conservative block splitting for metadata sidecar summary
pub fn parse_markdown(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("markdown: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("markdown: read failed: " + e.to_string())
  }

  let raw = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("markdown: utf8 decode failed: " + e.to_string())
  }
  let text = normalize_markdown_source(raw)

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  @cor.set_passthrough_markdown(doc, text)

  for block in conservative_markdown_blocks(text) {
    @cor.push_with_origin(
      doc,
      block.block,
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(block.line_start),
        line_end: Some(block.line_end),
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
fn normalize_markdown_source(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }
  let out : Array[Char] = []
  let chars = without_bom.to_array()
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(chars[i])
      i += 1
    }
  }

  String::from_array(out)
}
