///|
fn pdf_v2_image_asset_normalized_ext(
  asset : @pdfv2.PdfV2ImageAssetCandidate,
) -> String? {
  match asset.extension {
    Some(raw) => {
      let ext = raw.trim().to_owned().to_lower()
      if ext == "" {
        None
      } else if ext == "jpeg" {
        Some("jpg")
      } else if ext == "jbig2" {
        Some("jb2")
      } else {
        Some(ext)
      }
    }
    None => None
  }
}

///|
fn pdf_v2_image_asset_write_bytes(
  out_dir : String,
  ext : String,
  bytes : Array[Byte],
  next_image_idx : Ref[Int],
) -> String? {
  if out_dir.trim().to_owned() == "" || bytes.is_empty() {
    return None
  }
  let assets_dir = out_dir + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir) catch {
      _ => return None
    }
  }
  let rel = @cor.next_image_asset_rel_path_unique(next_image_idx, ext, out_dir)
  @fs.write_bytes_to_file(out_dir + "/" + rel, Bytes::from_array(bytes)) catch {
    _ => return None
  }
  Some(rel)
}

///|
fn pdf_v2_image_asset_bmp_from_pixels(
  pixels : Array[Byte],
  width : Int?,
  height : Int?,
  color_space : String?,
) -> Array[Byte]? {
  match (width, height) {
    (Some(w), Some(h)) => {
      if w <= 0 || h <= 0 {
        return None
      }
      let rgb_expected = w * h * 3
      let gray_expected = w * h
      let as_rgb24 = pixels.length() >= rgb_expected
      let as_gray8 = match color_space {
        Some(cs) if cs == "/DeviceGray" => pixels.length() >= gray_expected
        _ => false
      }
      if !as_rgb24 && !as_gray8 {
        return None
      }
      let row_raw = w * 3
      let row_pad = (4 - row_raw % 4) % 4
      let row_size = row_raw + row_pad
      let pixel_size = row_size * h
      let header_size = 14 + 40
      let file_size = header_size + pixel_size
      let out = Array::make(file_size, (0).to_byte())

      fn put_u8(pos : Int, value : Int) -> Unit {
        out[pos] = (value & 0xFF).to_byte()
      }

      fn put_u16_le(pos : Int, value : Int) -> Unit {
        put_u8(pos, value)
        put_u8(pos + 1, value >> 8)
      }

      fn put_u32_le(pos : Int, value : Int) -> Unit {
        put_u8(pos, value)
        put_u8(pos + 1, value >> 8)
        put_u8(pos + 2, value >> 16)
        put_u8(pos + 3, value >> 24)
      }

      put_u8(0, 'B'.to_int())
      put_u8(1, 'M'.to_int())
      put_u32_le(2, file_size)
      put_u16_le(6, 0)
      put_u16_le(8, 0)
      put_u32_le(10, header_size)
      put_u32_le(14, 40)
      put_u32_le(18, w)
      put_u32_le(22, h)
      put_u16_le(26, 1)
      put_u16_le(28, 24)
      put_u32_le(30, 0)
      put_u32_le(34, pixel_size)
      put_u32_le(38, 2835)
      put_u32_le(42, 2835)
      put_u32_le(46, 0)
      put_u32_le(50, 0)

      let mut dst = header_size
      for y = h - 1; y >= 0; y = y - 1 {
        if as_rgb24 {
          let mut src = y * w * 3
          for _x in 0..<w {
            let r = pixels[src].to_int() & 0xFF
            let g = pixels[src + 1].to_int() & 0xFF
            let b = pixels[src + 2].to_int() & 0xFF
            put_u8(dst, b)
            put_u8(dst + 1, g)
            put_u8(dst + 2, r)
            src = src + 3
            dst = dst + 3
          }
        } else {
          let mut src = y * w
          for _x in 0..<w {
            let v = pixels[src].to_int() & 0xFF
            put_u8(dst, v)
            put_u8(dst + 1, v)
            put_u8(dst + 2, v)
            src = src + 1
            dst = dst + 3
          }
        }
        for _pad in 0..<row_pad {
          put_u8(dst, 0)
          dst = dst + 1
        }
        if y == 0 {
          break
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn pdf_v2_image_asset_materialize_one(
  asset : @pdfv2.PdfV2ImageAssetCandidate?,
  width : Int?,
  height : Int?,
  color_space : String?,
  out_dir : String,
  next_image_idx : Ref[Int],
) -> @pdfv2.PdfV2ImageAssetCandidate? {
  match asset {
    Some(candidate) =>
      match candidate.bytes {
        Some(bytes) => {
          let ext = match pdf_v2_image_asset_normalized_ext(candidate) {
            Some(value) => value
            None => return asset
          }
          let data = if candidate.byte_kind ==
            @pdfv2.PdfV2ImageAssetByteKind::Decoded &&
            ext == "bmp" {
            match
              pdf_v2_image_asset_bmp_from_pixels(
                bytes, width, height, color_space,
              ) {
              Some(bmp) => bmp
              None => return asset
            }
          } else {
            bytes
          }
          match
            pdf_v2_image_asset_write_bytes(out_dir, ext, data, next_image_idx) {
            Some(rel_path) =>
              Some({
                ..candidate,
                rel_path: Some(rel_path),
                bytes: None,
                byte_count: Some(data.length()),
              })
            None => asset
          }
        }
        None => asset
      }
    None => None
  }
}

///|
fn pdf_v2_image_asset_caption_with_asset(
  caption : @pdfv2.PdfV2ImageCaptionCandidate?,
  asset : @pdfv2.PdfV2ImageAssetCandidate?,
) -> @pdfv2.PdfV2ImageCaptionCandidate? {
  match (caption, asset) {
    (Some(candidate), Some(asset_candidate)) =>
      match asset_candidate.rel_path {
        Some(path) if path.trim().to_owned() != "" =>
          Some({ ..candidate, asset_ref: Some(path) })
        _ => caption
      }
    _ => caption
  }
}

///|
fn pdf_v2_materialize_image_assets(
  model : @pdfv2.PdfV2DocumentModel,
  out_dir : String?,
) -> @pdfv2.PdfV2DocumentModel {
  match out_dir {
    Some(root) if root.trim().to_owned() != "" => {
      let next_image_idx : Ref[Int] = { val: 0 }
      let pages = model.pages.map(fn(page) {
        let images = page.images.map(fn(image) {
          let asset = pdf_v2_image_asset_materialize_one(
            image.asset,
            image.width,
            image.height,
            image.color_space,
            root,
            next_image_idx,
          )
          {
            ..image,
            asset,
            caption: pdf_v2_image_asset_caption_with_asset(image.caption, asset),
          }
        })
        let inline_images = page.inline_images.map(fn(image) {
          let asset = pdf_v2_image_asset_materialize_one(
            image.asset,
            image.width,
            image.height,
            image.color_space,
            root,
            next_image_idx,
          )
          { ..image, asset, }
        })
        { ..page, images, inline_images }
      })
      { ..model, pages, }
    }
    _ => model
  }
}
