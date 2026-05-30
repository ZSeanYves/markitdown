///|
/// Final PDF stage: project convert blocks/images into unified IR.
///
/// Important contract notes:
/// - text blocks and image blocks are emitted in page object reading order
/// - `Origin` / `AssetOrigin` are lightweight provenance only
/// - image nearby caption recovery is conservative; ambiguous matches are skipped
///   rather than forcing low-confidence pairings
/// - final text-shape rules live in `pdf_ir_text_rules.mbt` in this package
priv enum PdfIrHeadingRole {
  DocumentTitle
  SectionHeading
}

///|
const DEBUG_TO_IR = false

///|
fn rebuild_page_objects(page : PdfConvertPage) -> PdfConvertPage {
  let objects = build_page_objects(page.blocks, page.images)
  { ..page, objects, }
}

///|
fn convert_pdf_blocks_to_ir(
  doc : PdfConvertDocument,
  max_heading : Int,
  source_name : String,
) -> @cor.Document {
  let out = @cor.new_document()
  let has_document_title = detect_document_title_presence_for_ir(doc)
  let mut emitted_annotations_heading = false
  let mut emitted_forms_heading = false
  let list_gate_cfg = default_pdf_layout_gate_config()
  let list_gate_ctx = build_pdf_layout_gate_doc_context(doc)

  for page in doc.pages {
    let page_tables = detect_pdf_tables(page, DEBUG_TO_IR)
    let (page_image_captions, consumed_caption_block_indices) = infer_page_image_captions(
      page,
      DEBUG_TO_IR,
    )
    let consumed_table_block_indices = table_consumed_block_indices(page_tables)
    let table_start_lookup = build_table_start_lookup(page_tables)
    let (prev_text_blocks, next_text_blocks) = build_page_object_text_neighbors(
      page.objects,
    )
    let page_font_median = page_median_font_size(page)
    let mut page_image_idx = 0
    for i = 0; i < page.objects.length(); i = i + 1 {
      match page.objects[i] {
        PdfConvertPageObject::TextBlock(block) => {
          match find_table_starting_at_block(table_start_lookup, block) {
            Some(table) => {
              emit_pdf_table_to_ir(out, source_name, page._page_index, table)
              continue
            }
            None => ()
          }

          if consumed_table_block_indices.contains(block.block_index) {
            continue
          }
          if consumed_caption_block_indices.contains(block.block_index) {
            continue
          }
          let prev = prev_text_blocks[i]
          let next = next_text_blocks[i]

          emit_text_block_to_ir(
            out,
            source_name,
            list_gate_ctx,
            list_gate_cfg,
            page,
            page._page_index,
            block,
            prev,
            next,
            page_font_median,
            has_document_title,
            max_heading,
          )
        }
        PdfConvertPageObject::Image(image) => {
          if image.path.trim() == "" {
            continue
          }
          let nearby_caption = if page_image_idx < page_image_captions.length() {
            page_image_captions[page_image_idx]
          } else {
            None
          }
          page_image_idx += 1

          let origin : @cor.Origin = {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            block_index: Some(out.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: None,
          }

          @cor.push_with_origin(
            out,
            @cor.Block::ImageBlock({
              path: image.path,
              alt_text: image.alt_text,
              title: None,
              caption: nearby_caption,
              origin: Some(origin),
            }),
            Some(origin),
          )

          @cor.set_asset_origin(out, image.path, {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            origin_id: Some(image.source_image_id),
            nearby_caption,
            object_ref: image.object_ref,
            relationship_id: None,
            source_path: None,
            row_index: None,
            column_index: None,
            key_path: None,
          })
        }
      }
    }

    let annotation_notes = collect_visible_annotation_notes(page)
    if !annotation_notes.is_empty() {
      if !emitted_annotations_heading {
        @cor.push(out, @cor.Block::Heading(2, "Annotations"))
        emitted_annotations_heading = true
      }

      emit_pdf_annotation_notes_to_ir(
        out,
        source_name,
        page._page_index,
        annotation_notes,
      )
    }

    let form_notes = collect_visible_form_notes(page)
    if !form_notes.is_empty() {
      if !emitted_forms_heading {
        @cor.push(out, @cor.Block::Heading(2, "Forms"))
        emitted_forms_heading = true
      }

      emit_pdf_form_notes_to_ir(out, source_name, page._page_index, form_notes)
    }
  }

  out
}

///|
fn normalized_optional_annotation_field(field : String?) -> String? {
  match field {
    Some(v) => {
      let t = v.trim().to_owned()
      if t == "" {
        None
      } else {
        Some(t)
      }
    }
    None => None
  }
}

///|
fn is_block_above_image(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  block._bbox.y0 >= image._bbox.y1
}

///|
fn is_block_below_image(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  block._bbox.y1 <= image._bbox.y0
}

///|
fn caption_vertical_gap(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Double {
  if is_block_above_image(block, image) {
    block._bbox.y0 - image._bbox.y1
  } else if is_block_below_image(block, image) {
    image._bbox.y0 - block._bbox.y1
  } else {
    -1.0
  }
}

///|
fn horizontal_overlap_width(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  let left = max_f64(a.x0, b.x0)
  let right = min_f64(a.x1, b.x1)
  if right > left {
    right - left
  } else {
    0.0
  }
}

///|
fn block_center_x(block : PdfConvertBlock) -> Double {
  (block._bbox.x0 + block._bbox.x1) / 2.0
}

///|
fn is_within_x_span(x : Double, rect : @model.PdfRect) -> Bool {
  x >= rect.x0 && x <= rect.x1
}

///|
fn table_consumed_block_indices(
  tables : Array[PdfTableCandidate],
) -> Map[Int, Bool] {
  let out : Map[Int, Bool] = Map([])
  for table in tables {
    for block_index in table.block_indices {
      out.set(block_index, true)
    }
  }
  out
}

///|
fn build_table_start_lookup(
  tables : Array[PdfTableCandidate],
) -> Map[Int, PdfTableCandidate] {
  let out : Map[Int, PdfTableCandidate] = Map([], capacity=tables.length())
  for table in tables {
    if out.get(table.line_start) is None {
      out.set(table.line_start, table)
    }
  }
  out
}

///|
fn find_table_starting_at_block(
  table_start_lookup : Map[Int, PdfTableCandidate],
  block : PdfConvertBlock,
) -> PdfTableCandidate? {
  table_start_lookup.get(block.line_start)
}

///|
fn emit_pdf_table_to_ir(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  table : PdfTableCandidate,
) -> Unit {
  let origin : @cor.Origin = {
    source_name: Some(source_name),
    page: Some(page_index + 1),
    slide: None,
    sheet: None,
    block_index: Some(out.blocks.val.length()),
    heading_path: None,
    line_start: Some(table.line_start + 1),
    line_end: Some(table.line_end + 1),
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: None,
  }

  @cor.push_with_origin(
    out,
    @cor.Block::RichTable({
      rows: table.rows,
      header_rows: table.header_rows,
      hints: None,
    }),
    Some(origin),
  )
}

///|
fn min_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn build_page_object_text_neighbors(
  objects : Array[PdfConvertPageObject],
) -> (Array[PdfConvertBlock?], Array[PdfConvertBlock?]) {
  let prev_text_blocks : Array[PdfConvertBlock?] = Array::makei(
    objects.length(),
    _ => None,
  )
  let next_text_blocks : Array[PdfConvertBlock?] = Array::makei(
    objects.length(),
    _ => None,
  )

  let mut prev_text : PdfConvertBlock? = None
  for i = 0; i < objects.length(); i = i + 1 {
    prev_text_blocks[i] = prev_text
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => prev_text = Some(block)
      PdfConvertPageObject::Image(_) => ()
    }
  }

  let mut next_text : PdfConvertBlock? = None
  let mut i = objects.length()
  while i > 0 {
    i = i - 1
    next_text_blocks[i] = next_text
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => next_text = Some(block)
      PdfConvertPageObject::Image(_) => ()
    }
  }

  (prev_text_blocks, next_text_blocks)
}

///|
fn emit_text_block_to_ir(
  out : @cor.Document,
  source_name : String,
  list_gate_ctx : PdfLayoutGateDocContext,
  list_gate_cfg : PdfLayoutGateConfig,
  page : PdfConvertPage,
  _page_index : Int,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  page_font_median : Double?,
  has_document_title : Bool,
  max_heading : Int,
) -> Unit {
  let text = block.text.trim().to_owned()
  if text == "" {
    return
  }

  if DEBUG_TO_IR {
    println(
      "[to-ir/input] page=" +
      _page_index.to_string() +
      " block=" +
      block.block_index.to_string() +
      " kind=" +
      debug_block_kind_for_ir(block.kind) +
      " heading_candidate=" +
      block.is_heading_candidate.to_string() +
      " text=\"" +
      text +
      "\"",
    )
  }

  match block.kind {
    PdfConvertBlockKind::Noise => ()
    PdfConvertBlockKind::Heading => {
      let heading_text = normalize_heading_text_for_ir(text)
      let (role, depth) = decide_heading_role_and_depth_for_ir(
        heading_text, block, prev, next,
      )

      if DEBUG_TO_IR {
        println(
          "[to-ir/heading] page=" +
          _page_index.to_string() +
          " block=" +
          block.block_index.to_string() +
          " role=" +
          debug_heading_role_for_ir(role) +
          " depth=" +
          depth.to_string() +
          " text=\"" +
          heading_text +
          "\"",
        )
      }

      match role {
        PdfIrHeadingRole::DocumentTitle => {
          let level = clamp_heading_level(1, max_heading)
          let block_ir = match block.rich_inlines {
            Some(inlines) => @cor.Block::RichHeading(level, inlines)
            None => @cor.Block::Heading(level, heading_text)
          }
          @cor.push_with_origin(
            out,
            block_ir,
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
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
        PdfIrHeadingRole::SectionHeading => {
          let level = map_section_depth_to_heading_level_for_ir(
            depth, has_document_title, max_heading,
          )
          let block_ir = match block.rich_inlines {
            Some(inlines) => @cor.Block::RichHeading(level, inlines)
            None => @cor.Block::Heading(level, heading_text)
          }
          @cor.push_with_origin(
            out,
            block_ir,
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
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
      }
    }
    PdfConvertBlockKind::Paragraph => {
      let pt = text.trim().to_owned()
      match try_split_run_in_numbered_heading_for_ir(pt) {
        Some((heading_text, body_text, depth)) =>
          if !should_never_emit_heading(heading_text) {
            let level = map_section_depth_to_heading_level_for_ir(
              depth, has_document_title, max_heading,
            )
            push_pdf_block_with_origin(
              out,
              source_name,
              _page_index,
              @cor.Block::Heading(level, heading_text),
            )
            if body_text != "" {
              push_pdf_block_with_origin(
                out,
                source_name,
                _page_index,
                @cor.Block::Paragraph(body_text),
              )
            }
            return
          }
        None => ()
      }
      match try_parse_bullet_list_item_for_ir(pt) {
        Some(item_text) =>
          if should_emit_pdf_bullet_list_item(
              list_gate_ctx,
              page,
              block.block_index,
              page_font_median,
              list_gate_cfg,
            ) {
            @cor.push_with_origin(
              out,
              @cor.Block::ListItem(false, 0, item_text),
              Some({
                source_name: Some(source_name),
                page: Some(_page_index + 1),
                slide: None,
                sheet: None,
                block_index: Some(out.blocks.val.length()),
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
            match block.rich_inlines {
              Some(inlines) =>
                push_pdf_block_with_origin(
                  out,
                  source_name,
                  _page_index,
                  @cor.Block::RichParagraph(inlines),
                )
              None =>
                push_pdf_block_with_origin(
                  out,
                  source_name,
                  _page_index,
                  @cor.Block::Paragraph(pt),
                )
            }
          }
        None =>
          match block.rich_inlines {
            Some(inlines) =>
              push_pdf_block_with_origin(
                out,
                source_name,
                _page_index,
                @cor.Block::RichParagraph(inlines),
              )
            None =>
              push_pdf_block_with_origin(
                out,
                source_name,
                _page_index,
                @cor.Block::Paragraph(pt),
              )
          }
      }
    }
  }
}

///|
fn push_pdf_block_with_origin(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  block : @cor.Block,
) -> Unit {
  @cor.push_with_origin(
    out,
    block,
    Some({
      source_name: Some(source_name),
      page: Some(page_index + 1),
      slide: None,
      sheet: None,
      block_index: Some(out.blocks.val.length()),
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
