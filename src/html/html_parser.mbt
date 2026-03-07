///|
/// HTML parser entry
pub fn parse_html(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "HTML"))

  let nodes = scan_html_nodes(bs)
  let blocks = nodes_to_blocks(nodes, max_heading)

  for b in blocks {
    @cor.push(doc, b)
  }

  doc
}
