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

  let raw_bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }
  let bs = normalize_html_input_bytes(raw_bs)

  let doc = @cor.new_document()

  let nodes = scan_html_nodes(bs)
  let html_blocks = nodes_to_blocks(nodes, max_heading, input_path, out_dir)
  let blocks = html_blocks.blocks
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
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(path),
          row_index: None,
          column_index: None,
          key_path: None,
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
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(img.path),
          row_index: None,
          column_index: None,
          key_path: None,
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

  doc
}

///|
fn normalize_html_input_bytes(bs : Bytes) -> Bytes {
  let n = bs.length()
  let mut start = 0
  if n >= 3 && bs[0] == 0xEF && bs[1] == 0xBB && bs[2] == 0xBF {
    start = 3
  }

  let out : Array[Byte] = []
  let mut i = start
  while i < n {
    let b = bs[i]
    if b == '\r'.to_int().to_byte() {
      out.push('\n'.to_int().to_byte())
      if i + 1 < n && bs[i + 1] == '\n'.to_int().to_byte() {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(b)
      i = i + 1
    }
  }

  Bytes::from_array(out)
}
