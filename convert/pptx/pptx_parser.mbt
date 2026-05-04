///|
/// PPTX parser
/// Strategy:
/// - resolve slide order from ppt/presentation.xml + rels
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - classify slide paragraphs into heading / list item / paragraph
///
/// Explainability boundary:
/// - this module orchestrates per-slide flow and provenance wiring
/// - fine-grained reading-order and classification heuristics live in submodules
/// - image-caption pairing is kept conservative and isolated from text classification
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
  for slide in slides {
    let path = slide.part_name
    let slide_heading = if slide.hidden {
      "Slide " + idx.to_string() + " (hidden)"
    } else {
      "Slide " + idx.to_string()
    }
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(clamp_heading(2, max_heading), slide_heading),
      Some({
        source_name: Some(src),
        page: None,
        slide: Some(idx),
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

    let xml = p.read_bytes_required(path)
    let rel_ctx = build_slide_rel_context(p, path)
    let images = export_slide_images(p, rel_ctx, xml, out_dir, idx, image_idx)
    let paras = extract_slide_paragraphs(xml, rel_ctx.hyperlinks)
    let tables = collect_explicit_table_frames(xml, rel_ctx.hyperlinks)
    let (image_captions, consumed_caption_para_ids) = infer_slide_image_captions(
      images, paras,
    )
    let blocks = classify_slide_paragraphs(
      drop_consumed_caption_paras(paras, consumed_caption_para_ids),
    )
    let note_paras = extract_speaker_notes(p, rel_ctx)

    for i in 0..<images.length() {
      let img = images[i]
      let nearby_caption = image_captions[i]
      @cor.push_with_origin(
        doc,
        @cor.Block::ImageBlock({
          path: img._path,
          alt_text: Some(img._alt_text),
          title: img._title,
          caption: nearby_caption,
          origin: Some({
            source_name: Some(src),
            page: None,
            slide: Some(idx),
            sheet: None,
            block_index: None,
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: None,
          }),
        }),
        Some({
          source_name: Some(src),
          page: None,
          slide: Some(idx),
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
      @cor.set_asset_origin(doc, img._path, {
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        origin_id: Some(
          "slide-" + idx.to_string() + "-image-" + (i + 1).to_string(),
        ),
        nearby_caption,
        object_ref: img._object_ref,
        relationship_id: img._relationship_id,
        source_path: img._source_path,
        row_index: None,
        column_index: None,
        key_path: None,
      })
    }

    if blocks.length() == 0 &&
      images.length() == 0 &&
      tables.length() == 0 &&
      note_paras.length() == 0 {
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
          line_start: None,
          line_end: None,
          row_index: None,
          column_index: None,
          object_ref: None,
          relationship_id: None,
          key_path: None,
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
                line_start: None,
                line_end: None,
                row_index: None,
                column_index: None,
                object_ref: None,
                relationship_id: None,
                key_path: None,
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
                line_start: None,
                line_end: None,
                row_index: None,
                column_index: None,
                object_ref: None,
                relationship_id: None,
                key_path: None,
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
                line_start: None,
                line_end: None,
                row_index: None,
                column_index: None,
                object_ref: None,
                relationship_id: None,
                key_path: None,
              }),
            )
            prev_was_list = true
          }
        }
      }

      for table in tables {
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

        @cor.push_with_origin(
          doc,
          @cor.Block::RichTable({
            rows: table.rows,
            header_rows: table.header_rows,
          }),
          Some({
            source_name: Some(src),
            page: None,
            slide: Some(idx),
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: Some(0),
            column_index: Some(0),
            object_ref: table.object_ref,
            relationship_id: slide.rel_id,
            key_path: None,
          }),
        )
        prev_was_list = false
      }

      if note_paras.length() > 0 {
        @cor.push_with_origin(
          doc,
          @cor.Block::Heading(clamp_heading(3, max_heading), "Speaker Notes"),
          Some({
            source_name: Some(src),
            page: None,
            slide: Some(idx),
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: Some([slide_heading]),
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: rel_ctx.notes_part,
            relationship_id: rel_ctx.notes_relationship_id,
            key_path: rel_ctx.notes_part,
          }),
        )

        let note_blocks = classify_slide_paragraphs(note_paras)
        for block in note_blocks {
          match block {
            PptxBlock::Heading(text, inlines) => {
              let heading = if has_link_inline(inlines) {
                @cor.Block::RichHeading(clamp_heading(4, max_heading), inlines)
              } else {
                @cor.Block::Heading(clamp_heading(4, max_heading), text)
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
                  heading_path: Some([slide_heading, "Speaker Notes"]),
                  line_start: None,
                  line_end: None,
                  row_index: None,
                  column_index: None,
                  object_ref: rel_ctx.notes_part,
                  relationship_id: rel_ctx.notes_relationship_id,
                  key_path: rel_ctx.notes_part,
                }),
              )
            }
            PptxBlock::Paragraph(text, inlines) => {
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
                  heading_path: Some([slide_heading, "Speaker Notes"]),
                  line_start: None,
                  line_end: None,
                  row_index: None,
                  column_index: None,
                  object_ref: rel_ctx.notes_part,
                  relationship_id: rel_ctx.notes_relationship_id,
                  key_path: rel_ctx.notes_part,
                }),
              )
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
                  heading_path: Some([slide_heading, "Speaker Notes"]),
                  line_start: None,
                  line_end: None,
                  row_index: None,
                  column_index: None,
                  object_ref: rel_ctx.notes_part,
                  relationship_id: rel_ctx.notes_relationship_id,
                  key_path: rel_ctx.notes_part,
                }),
              )
            }
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
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
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
    let t = para.text.trim().to_owned()
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
    let t = para.text.trim().to_owned()
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
  let t = s.trim().to_owned()
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
  let t = s.trim().to_owned()
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
