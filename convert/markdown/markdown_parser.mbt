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

  let text = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("markdown: utf8 decode failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  @cor.set_passthrough_markdown(doc, text)

  for block in conservative_markdown_blocks(text) {
    @cor.push_with_origin(
      doc,
      block,
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
      }),
    )
  }

  doc
}
