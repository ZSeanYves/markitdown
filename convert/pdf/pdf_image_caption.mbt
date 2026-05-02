///|
fn infer_page_image_captions(
  page : PdfConvertPage,
  pipeline_debug : Bool,
) -> (Array[String?], Map[Int, Bool]) {
  let out : Array[String?] = []
  let consumed : Map[Int, Bool] = Map::new()
  for _ in page.images {
    out.push(None)
  }

  if page.images.is_empty() {
    return (out, consumed)
  }

  for image_index in 0..<page.images.length() {
    let image = page.images[image_index]
    let candidates : Array[(Int, PdfConvertBlock, String, Double)] = []
    for block in page.blocks {
      match classify_caption_candidate(block, image, page.images) {
        Some((text, score)) =>
          candidates.push((block.block_index, block, text, score))
        None => ()
      }
    }

    match pick_best_caption_candidate(candidates) {
      Some((block_index, text, status)) => {
        out[image_index] = Some(text)
        consumed.set(block_index, true)
        if pipeline_debug {
          println(
            "[pdf-image-caption] page=" +
            (page._page_index + 1).to_string() +
            " image=" +
            (image_index + 1).to_string() +
            " status=" +
            status +
            " block=" +
            (block_index + 1).to_string(),
          )
        }
      }
      None =>
        if pipeline_debug {
          println(
            "[pdf-image-caption] page=" +
            (page._page_index + 1).to_string() +
            " image=" +
            (image_index + 1).to_string() +
            " status=rejected_low_confidence",
          )
        }
    }
  }

  (out, consumed)
}

///|
fn classify_caption_candidate(
  block : PdfConvertBlock,
  image : PdfConvertImage,
  images : Array[PdfConvertImage],
) -> (String, Double)? {
  let text = block.text.trim().to_owned()
  if text == "" {
    return None
  }

  if block.kind != PdfConvertBlockKind::Paragraph {
    return None
  }

  if block.is_noise_candidate ||
    block.is_header_footer_candidate ||
    block.is_artifact_candidate ||
    block.is_heading_candidate {
    return None
  }

  let has_prefix = looks_like_image_caption_prefix(text)
  let no_prefix_ok = looks_like_no_prefix_image_caption(text, block, image)
  if !(has_prefix || no_prefix_ok) {
    return None
  }

  if text_has_too_many_words_for_caption(text) {
    return None
  }

  if looks_like_table_caption_prefix(text) {
    return None
  }

  if overlaps_other_images(block._bbox, image, images) {
    return None
  }

  if !is_block_above_image(block, image) && !is_block_below_image(block, image) {
    return None
  }

  let gap = caption_vertical_gap(block, image)
  let max_gap = if has_prefix { 36.0 } else { 18.0 }
  if gap < 0.0 || gap > max_gap {
    return None
  }

  let overlap = horizontal_overlap_width(block._bbox, image._bbox)
  if overlap <= 0.0 && !is_centered_near_image(block, image) {
    return None
  }

  let block_width = max_image_caption_f64(block._bbox.x1 - block._bbox.x0, 1.0)
  if overlap / block_width < (if has_prefix { 0.75 } else { 0.9 }) &&
    !is_centered_near_image(block, image) {
    return None
  }

  let mut score = 2.0
  if is_block_below_image(block, image) {
    score = score + 1.0
  }
  if has_prefix {
    score = score + 2.0
  }
  if abs_image_caption_f64(block.left_x - image.left_x) <= 24.0 ||
    is_within_x_span(block_center_x(block), image._bbox) {
    score = score + 1.0
  }
  if is_centered_near_image(block, image) {
    score = score + 1.0
  }
  if gap <= 18.0 {
    score = score + 1.0
  }
  if !has_prefix {
    score = score - 1.0
  }

  Some((text, score))
}

///|
fn pick_best_caption_candidate(
  candidates : Array[(Int, PdfConvertBlock, String, Double)],
) -> (Int, String, String)? {
  if candidates.is_empty() {
    return None
  }

  let mut best = candidates[0]
  for i in 1..<candidates.length() {
    let cur = candidates[i]
    if cur.3 > best.3 {
      best = cur
    }
  }

  let tied = candidates.filter(fn(x) {
    abs_image_caption_f64(x.3 - best.3) <= 0.1
  })
  if tied.length() != 1 {
    return None
  }

  Some((best.0, best.2, "matched"))
}

///|
fn looks_like_image_caption_prefix(text : String) -> Bool {
  let t = text.trim().to_owned()
  let lower = t.to_lower()
  lower.has_prefix("figure ") ||
  lower.has_prefix("figure") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("fig.") ||
  lower.has_prefix("image ") ||
  lower.has_prefix("photo ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("图") ||
  t.has_prefix("图片 ")
}

///|
fn looks_like_table_caption_prefix(text : String) -> Bool {
  let t = text.trim().to_owned()
  let lower = t.to_lower()
  lower.has_prefix("table ") ||
  lower.has_prefix("table") ||
  t.has_prefix("表 ")
}

///|
fn looks_like_no_prefix_image_caption(
  text : String,
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if image_caption_word_count(t) > 8 {
    return false
  }
  if ends_like_body_sentence(t) {
    return false
  }
  if !is_block_below_image(block, image) {
    return false
  }
  is_centered_near_image(block, image)
}

///|
fn text_has_too_many_words_for_caption(text : String) -> Bool {
  image_caption_word_count(text) > 18
}

///|
fn image_caption_word_count(text : String) -> Int {
  let mut count = 0
  let mut in_word = false
  for ch in text.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if in_word {
        in_word = false
      }
    } else if !in_word {
      count = count + 1
      in_word = true
    }
  }
  count
}

///|
fn overlaps_other_images(
  block_bbox : @model.PdfRect,
  target : PdfConvertImage,
  images : Array[PdfConvertImage],
) -> Bool {
  let mut overlap_count = 0
  for image in images {
    if image.source_image_id == target.source_image_id {
      continue
    }
    if rects_overlap_or_near_image_caption(block_bbox, image._bbox, 24.0) {
      overlap_count = overlap_count + 1
      if overlap_count > 0 {
        return true
      }
    }
  }
  false
}

///|
fn is_centered_near_image(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  let image_center = (image._bbox.x0 + image._bbox.x1) / 2.0
  let block_center = block_center_x(block)
  abs_image_caption_f64(image_center - block_center) <= 20.0
}

///|
fn ends_like_body_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn rects_overlap_or_near_image_caption(
  a : @model.PdfRect,
  b : @model.PdfRect,
  gap : Double,
) -> Bool {
  !(a.x1 + gap < b.x0 ||
  b.x1 + gap < a.x0 ||
  a.y1 + gap < b.y0 ||
  b.y1 + gap < a.y0)
}

///|
fn abs_image_caption_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn max_image_caption_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
