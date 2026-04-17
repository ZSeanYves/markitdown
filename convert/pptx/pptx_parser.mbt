///|
/// PPTX parser
/// Strategy:
/// - resolve slide order from ppt/presentation.xml + rels
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - classify slide paragraphs into heading / list item / paragraph
pub fn parse_pptx(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  let p = open_pptx(input_path) catch {
    e => raise @cor.AppError("pptx: open package failed: " + e.to_string())
  }

  let slides = list_slide_entries_in_presentation_order(p)
  let doc = @cor.new_document()

  if slides.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no slides found)"))
    return doc
  }

  let image_idx : Ref[Int] = { val: 0 }
  let src = @cor.basename(input_path)
  let mut idx = 1
  for path in slides {
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(
        clamp_heading(2, max_heading),
        "Slide " + idx.to_string(),
      ),
      Some({
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
      }),
    )

    let xml = p.read_bytes_required(path)
    let _ = build_slide_rel_context(p, path)
    let hyperlinks = slide_hyperlink_map(p, path)
    let images = export_slide_images(p, path, xml, out_dir, idx, image_idx)
    let paras = extract_slide_paragraphs(xml, hyperlinks)
    let (image_captions, consumed_caption_para_ids) = infer_slide_image_captions(
      images, paras,
    )
    let marked_paras = mark_image_caption_associated_paras(
      paras,
      consumed_caption_para_ids,
      consumed_caption_texts(image_captions),
    )
    let blocks = classify_slide_paragraphs(
      drop_consumed_caption_paras(marked_paras, consumed_caption_para_ids),
    )

    for i in 0..<images.length() {
      let img = images[i]
      let nearby_caption = image_captions[i]
      @cor.push_with_origin(
        doc,
        @cor.Block::ImageBlock({
          path: img._path,
          alt_text: Some(img._alt),
          title: None,
          caption: nearby_caption,
          origin: Some({
            source_name: Some(src),
            page: None,
            slide: Some(idx),
            sheet: None,
            block_index: None,
            heading_path: None,
          }),
        }),
        Some({
          source_name: Some(src),
          page: None,
          slide: Some(idx),
          sheet: None,
          block_index: Some(doc.blocks.val.length()),
          heading_path: None,
        }),
      )
      @cor.set_asset_origin(doc, img._path, {
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        origin_id: Some(
          "slide-" + idx.to_string() + "-image-" + (i + 1).to_string(),
        ),
        nearby_caption,
      })
    }

    if blocks.length() == 0 && images.length() == 0 {
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph("(empty)"),
        Some({
          source_name: Some(src),
          page: None,
          slide: Some(idx),
          sheet: None,
          block_index: Some(doc.blocks.val.length()),
          heading_path: None,
        }),
      )
    } else {
      let mut prev_was_list = false

      for b in blocks {
        match b {
          PptxBlock::Heading(text, inlines) => {
            if prev_was_list {
              @cor.push_with_origin(
                doc,
                @cor.Block::BlankLine,
                Some({
                  source_name: Some(src),
                  page: None,
                  slide: Some(idx),
                  sheet: None,
                  block_index: Some(doc.blocks.val.length()),
                  heading_path: None,
                }),
              )
            }
            let heading = if has_link_inline(inlines) {
              @cor.Block::RichHeading(clamp_heading(3, max_heading), inlines)
            } else {
              @cor.Block::Heading(clamp_heading(3, max_heading), text)
            }
            @cor.push_with_origin(
              doc,
              heading,
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = false
          }
          PptxBlock::Paragraph(text, inlines) => {
            if prev_was_list {
              @cor.push_with_origin(
                doc,
                @cor.Block::BlankLine,
                Some({
                  source_name: Some(src),
                  page: None,
                  slide: Some(idx),
                  sheet: None,
                  block_index: Some(doc.blocks.val.length()),
                  heading_path: None,
                }),
              )
            }
            let para = if has_link_inline(inlines) {
              @cor.Block::RichParagraph(inlines)
            } else {
              @cor.Block::Paragraph(text)
            }
            @cor.push_with_origin(
              doc,
              para,
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = false
          }
          PptxBlock::ListItem(ordered, level, text, inlines) => {
            let item = if has_link_inline(inlines) {
              @cor.Block::RichListItem(ordered, level, inlines)
            } else {
              @cor.Block::ListItem(ordered, level, text)
            }
            @cor.push_with_origin(
              doc,
              item,
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = true
          }
        }
      }
    }

    @cor.push_with_origin(
      doc,
      @cor.Block::BlankLine,
      Some({
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
      }),
    )
    idx = idx + 1
  }

  doc
}

///|
fn has_link_inline(xs : Array[@cor.Inline]) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn infer_slide_image_captions(
  images : Array[PptxSlideImage],
  paras : Array[SlideParagraph],
) -> (Array[String?], Map[Int, Bool]) {
  let out : Array[String?] = []
  let consumed : Map[Int, Bool] = Map::new()
  for _ in images {
    out.push(None)
  }

  if images.length() != 1 {
    return (out, consumed)
  }

  let candidates : Array[(Int, String)] = []
  for para in paras {
    let t = para.text.trim().to_string()
    let is_non_bullet = match para.bullet_kind {
      None => true
      Some(_) => false
    }
    if is_non_bullet && is_caption_like_text(t) {
      candidates.push((para.source_para_id, t))
    }
  }

  if candidates.length() == 1 {
    let (para_id, caption) = candidates[0]
    out[0] = Some(caption)
    consumed.set(para_id, true)
    return (out, consumed)
  }

  // conservative nearby-caption fallback:
  // only for a single-image slide with exactly one short non-bullet paragraph.
  let nearby_candidates : Array[(Int, String)] = []
  for para in paras {
    let t = para.text.trim().to_string()
    if t == "" {
      continue
    }
    let is_non_bullet = match para.bullet_kind {
      None => true
      Some(_) => false
    }
    if is_non_bullet &&
      t.to_array().length() <= 60 &&
      !looks_like_sentence_like_body_text(t) {
      nearby_candidates.push((para.source_para_id, t))
    }
  }

  if nearby_candidates.length() == 1 && paras.length() <= 2 {
    let (para_id, caption) = nearby_candidates[0]
    out[0] = Some(caption)
    consumed.set(para_id, true)
  }
  (out, consumed)
}

///|
fn is_caption_like_text(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" || t.to_array().length() > 120 {
    return false
  }

  let lower = t.to_lower()
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig.") ||
  lower.has_prefix("fig ") ||
  lower.has_prefix("image ") ||
  lower.has_prefix("caption:") ||
  t.has_prefix("图") ||
  t.has_prefix("图：") ||
  t.has_prefix("图 ") ||
  t.has_prefix("图片")
}

///|
fn looks_like_sentence_like_body_text(s : String) -> Bool {
  let t = s.trim().to_string()
  if t.to_array().length() < 16 {
    return false
  }

  t.contains("，") ||
  t.contains("。") ||
  t.contains(",") ||
  t.contains(". ") ||
  t.contains(";") ||
  t.contains("；")
}

///|
fn mark_image_caption_associated_paras(
  paras : Array[SlideParagraph],
  consumed_caption_para_ids : Map[Int, Bool],
  _consumed_caption_texts : Map[String, Bool],
) -> Array[SlideParagraph] {
  if consumed_caption_para_ids.length() == 0 {
    return paras
  }
  let out : Array[SlideParagraph] = []
  for para in paras {
    out.push({
      source_para_id: para.source_para_id,
      text: para.text,
      inlines: para.inlines,
      bullet_kind: para.bullet_kind,
      level: para.level,
      from_title_shape: para.from_title_shape,
      from_body_shape: para.from_body_shape,
      associated_with_image_caption: consumed_caption_para_ids.contains(
        para.source_para_id,
      ),
    })
  }
  out
}

///|
fn consumed_caption_texts(image_captions : Array[String?]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for caption in image_captions {
    match caption {
      Some(text) => {
        let normalized = normalize_slide_text(text)
        if normalized != "" {
          out.set(normalized, true)
        }
      }
      None => ()
    }
  }
  out
}

///|
fn drop_consumed_caption_paras(
  paras : Array[SlideParagraph],
  consumed_caption_para_ids : Map[Int, Bool],
) -> Array[SlideParagraph] {
  if consumed_caption_para_ids.length() == 0 {
    return paras
  }
  let out : Array[SlideParagraph] = []
  for para in paras {
    if !consumed_caption_para_ids.contains(para.source_para_id) {
      out.push(para)
    }
  }
  out
}
