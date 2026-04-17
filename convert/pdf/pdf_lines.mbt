///|
/// 从 pdf_core 的 PdfDocumentModel 构建 convert line 文档。
fn build_convert_lines(
  doc : @model.PdfDocumentModel,
  out_dir : String,
) -> PdfConvertDocument {
  let pages = Array::new()
  let next_image_idx : Ref[Int] = { val: 0 }

  for page in doc.pages {
    pages.push(build_convert_page_lines(page, out_dir, next_image_idx))
  }

  { pages, }
}

///|
fn build_convert_page_lines(
  page : @model.PdfPageModel,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> PdfConvertPage {
  let lines = Array::new()
  let mut line_index = 0

  for block_index = 0
      block_index < page.text_blocks.length()
      block_index = block_index + 1 {
    let block = page.text_blocks[block_index]

    for line in block.lines {
      let text = @model.line_text(line).trim().to_string()
      if text == "" {
        continue
      }

      lines.push(
        core_line_to_convert_line(
          page.page_index,
          line_index,
          block_index,
          block,
          line,
        ),
      )
      line_index = line_index + 1
    }
  }

  let images = export_convert_page_images(page, out_dir, next_image_idx)

  { _page_index: page.page_index, lines, blocks: [], images, objects: [] }
}

///|
fn core_line_to_convert_line(
  _page_index : Int,
  line_index : Int,
  _source_block_index : Int,
  block : @model.PdfTextBlock,
  line : @model.PdfTextLine,
) -> PdfConvertLine {
  let raw_text = @model.line_text(line)
  let text = raw_text.trim().to_string()

  {
    _page_index,
    line_index,
    text,
    _source_block_index,
    is_heading_candidate: block.is_heading_candidate,
    is_page_number_candidate: block.is_page_number_candidate,
    _bbox: line.bbox,
    font_size: pick_line_font_size(line),
    font_name: pick_line_font_name(line),
    indent_left: line.indent_left,
    line_gap_before: line.line_gap_before,
    _line_gap_after: line.line_gap_after,
  }
}

///|
fn pick_line_font_size(line : @model.PdfTextLine) -> Double? {
  let mut best : Double? = None
  for span in line.spans {
    match span.font_size {
      Some(sz) =>
        match best {
          Some(cur) => if sz > cur { best = Some(sz) }
          None => best = Some(sz)
        }
      None => ()
    }
  }
  best
}

///|
fn pick_line_font_name(line : @model.PdfTextLine) -> String? {
  for span in line.spans {
    match span.font_name {
      Some(name) => return Some(name)
      None => ()
    }
  }
  None
}

///|
/// 从 page.images 导出图片到 assets/，并构建 convert image。
fn export_convert_page_images(
  page : @model.PdfPageModel,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> Array[PdfConvertImage] {
  let out : Array[PdfConvertImage] = []

  if out_dir == "" {
    return out
  }

  let assets_dir = out_dir + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir) catch {
      _ => return out
    }
  }

  let mut _image_index = 0
  for image in page.images {
    let _export = export_single_pdf_image(image, out_dir, next_image_idx)
    match _export {
      Some(path) => {
        out.push({
          _page_index: page.page_index,
          _image_index,
          path,
          alt_text: image.alt_text,
          caption: None,
          _bbox: image.bbox,
          top_y: image.bbox.y1,
          left_x: image.bbox.x0,
          _width_px: image.width_px,
          _height_px: image.height_px,
          source_image_id: image.id,
        })
        _image_index = _image_index + 1
      }
      None => ()
    }
  }

  out
}

///|
fn export_single_pdf_image(
  image : @model.PdfImageObject,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> String? {
  match image.payload {
    Some(@model.PdfImagePayload::Jpeg(bytes)) =>
      write_pdf_image_asset(bytes, "jpg", out_dir, next_image_idx)
    Some(@model.PdfImagePayload::Jpeg2000(bytes)) =>
      write_pdf_image_asset(bytes, "jp2", out_dir, next_image_idx)
    Some(@model.PdfImagePayload::Jbig2(bytes, _)) =>
      write_pdf_image_asset(bytes, "jb2", out_dir, next_image_idx)
    Some(@model.PdfImagePayload::RawRgb24(bytes)) =>
      write_pdf_raw_rgb24_as_bmp(
        bytes,
        image.width_px,
        image.height_px,
        out_dir,
        next_image_idx,
      )
    None => None
  }
}

///|
fn write_pdf_raw_rgb24_as_bmp(
  rgb : @pdfio.MutableBytes,
  width : Int,
  height : Int,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> String? {
  if width <= 0 || height <= 0 || out_dir == "" {
    return None
  }

  let expected = width * height * 3
  if @pdfio.bytes_size(rgb) < expected {
    return None
  }

  let row_raw = width * 3
  let row_pad = (4 - row_raw % 4) % 4
  let row_size = row_raw + row_pad
  let pixel_size = row_size * height
  let header_size = 14 + 40
  let file_size = header_size + pixel_size

  let out = @pdfio.mkbytes(file_size)

  fn put_u8(pos : Int, v : Int) -> Unit {
    @pdfio.bset(out, pos, v & 0xFF)
  }

  fn put_u16_le(pos : Int, v : Int) -> Unit {
    put_u8(pos, v)
    put_u8(pos + 1, v >> 8)
  }

  fn put_u32_le(pos : Int, v : Int) -> Unit {
    put_u8(pos, v)
    put_u8(pos + 1, v >> 8)
    put_u8(pos + 2, v >> 16)
    put_u8(pos + 3, v >> 24)
  }

  // BITMAPFILEHEADER
  put_u8(0, 'B'.to_int())
  put_u8(1, 'M'.to_int())
  put_u32_le(2, file_size)
  put_u16_le(6, 0)
  put_u16_le(8, 0)
  put_u32_le(10, header_size)

  // BITMAPINFOHEADER (40 bytes)
  put_u32_le(14, 40)
  put_u32_le(18, width)
  put_u32_le(22, height) // 正高度：bottom-up BMP
  put_u16_le(26, 1) // planes
  put_u16_le(28, 24) // bpp
  put_u32_le(30, 0) // BI_RGB
  put_u32_le(34, pixel_size)
  put_u32_le(38, 2835)
  put_u32_le(42, 2835)
  put_u32_le(46, 0)
  put_u32_le(50, 0)

  let mut dst = header_size

  // BMP 正高度要求从最后一行开始写
  for y = height - 1; y >= 0; y = y - 1 {
    let mut src = y * width * 3

    for _x = 0; _x < width; _x = _x + 1 {
      let r = @pdfio.bget(rgb, src)
      let g = @pdfio.bget(rgb, src + 1)
      let b = @pdfio.bget(rgb, src + 2)

      // BMP 像素顺序是 BGR
      put_u8(dst, b)
      put_u8(dst + 1, g)
      put_u8(dst + 2, r)

      src = src + 3
      dst = dst + 3
    }

    for pad_i = 0; pad_i < row_pad; pad_i = pad_i + 1 {
      put_u8(dst, 0)
      dst = dst + 1
    }

    if y == 0 {
      break
    }
  }

  let rel_out = @cor.next_image_asset_rel_path_unique(
    next_image_idx, "bmp", out_dir,
  )
  let abs_out = out_dir + "/" + rel_out

  @fs.write_bytes_to_file(abs_out, Bytes::from_array(out)) catch {
    _ => return None
  }

  Some(rel_out)
}

///|
fn write_pdf_image_asset(
  data : @pdfio.MutableBytes,
  ext : String,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> String? {
  if ext == "" || out_dir == "" {
    return None
  }

  let rel_out = @cor.next_image_asset_rel_path_unique(
    next_image_idx, ext, out_dir,
  )
  let dst = out_dir + "/" + rel_out

  @fs.write_bytes_to_file(dst, Bytes::from_array(data)) catch {
    _ => return None
  }

  Some(rel_out)
}
