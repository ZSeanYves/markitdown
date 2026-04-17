///|
/// HTML converter entrypoint.
///
/// Model boundary:
/// - uses a lightweight DOM-like semantic scan (not browser layout engine)
/// - focuses on robust structural blocks for markdown + metadata sidecar
/// - keeps provenance lightweight at block/asset level
pub fn parse_html(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }

  let doc = @cor.new_document()

  let nodes = scan_html_nodes(bs)
  let blocks = nodes_to_blocks(nodes, max_heading, input_path, out_dir)
  let src = @cor.basename(input_path)
  let mut asset_idx = 0

  for i in 0..<blocks.length() {
    match blocks[i] {
      @cor.Block::Image(_alt, path) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: None,
        })
      }
      @cor.Block::ImageBlock(img) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, img.path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: img.caption,
        })
      }
      _ => ()
    }

    @cor.push_with_origin(
      doc,
      blocks[i],
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
