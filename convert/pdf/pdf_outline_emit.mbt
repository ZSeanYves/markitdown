///|
fn append_pdf_outlines_to_ir(
  out : @cor.Document,
  outlines : Array[@model.PdfOutlineItem],
  source_name : String,
) -> Unit {
  if !has_renderable_pdf_outline_items(outlines) {
    return
  }
  if pdf_outlines_are_redundant_with_visible_headings(out, outlines) {
    return
  }
  @cor.push(out, @cor.Block::Heading(2, "Bookmarks"))
  emit_pdf_outline_items_to_ir(out, source_name, outlines, 0)
}

///|
fn has_renderable_pdf_outline_items(
  items : Array[@model.PdfOutlineItem],
) -> Bool {
  for item in items {
    if render_pdf_outline_item_text(item) is Some(_) {
      return true
    }
    if has_renderable_pdf_outline_items(item.children) {
      return true
    }
  }
  false
}

///|
fn pdf_outlines_are_redundant_with_visible_headings(
  out : @cor.Document,
  outlines : Array[@model.PdfOutlineItem],
) -> Bool {
  let heading_texts = visible_pdf_heading_texts(out)
  if heading_texts.is_empty() {
    return false
  }

  let outline_titles = Array::new()
  collect_outline_titles_for_redundancy_check(outlines, outline_titles)
  if outline_titles.is_empty() {
    return false
  }

  for title in outline_titles {
    let mut matched = false
    for heading in heading_texts {
      if heading == title {
        matched = true
        break
      }
    }
    if !matched {
      return false
    }
  }

  true
}

///|
fn visible_pdf_heading_texts(out : @cor.Document) -> Array[String] {
  let headings = Array::new()
  for block in out.blocks.val {
    match block {
      @cor.Block::Heading(_, text) =>
        if text.trim() != "" {
          headings.push(text.trim().to_owned())
        }
      _ => ()
    }
  }
  headings
}

///|
fn collect_outline_titles_for_redundancy_check(
  items : Array[@model.PdfOutlineItem],
  out : Array[String],
) -> Unit {
  for item in items {
    let title = item.title.trim().to_owned()
    if title == "" || item.page_index is None {
      out.clear()
      return
    }
    out.push(title)
    if !item.children.is_empty() {
      collect_outline_titles_for_redundancy_check(item.children, out)
      if out.is_empty() {
        return
      }
    }
  }
}

///|
fn emit_pdf_outline_items_to_ir(
  out : @cor.Document,
  source_name : String,
  items : Array[@model.PdfOutlineItem],
  level : Int,
) -> Unit {
  for item in items {
    match render_pdf_outline_item_text(item) {
      Some(text) => {
        let origin : @cor.Origin = {
          source_name: Some(source_name),
          page: item.page_index.map(fn(idx) { idx + 1 }),
          slide: None,
          sheet: None,
          block_index: Some(out.blocks.val.length()),
          heading_path: Some(["Bookmarks"]),
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
          @cor.Block::ListItem(false, level, text),
          Some(origin),
        )
      }
      None => ()
    }

    if !item.children.is_empty() {
      emit_pdf_outline_items_to_ir(out, source_name, item.children, level + 1)
    }
  }
}

///|
fn render_pdf_outline_item_text(item : @model.PdfOutlineItem) -> String? {
  let title = item.title.trim().to_owned()
  let target = render_outline_target(item)

  match (title, target) {
    ("", Some(dest)) => Some(dest)
    ("", None) => None
    (title, Some(dest)) => Some(title + " -> " + dest)
    (title, None) => Some(title)
  }
}

///|
fn render_outline_target(item : @model.PdfOutlineItem) -> String? {
  let page_target = match item.page_index {
    Some(page_index) =>
      if page_index >= 0 {
        Some("page " + (page_index + 1).to_string())
      } else {
        None
      }
    None => None
  }
  let dest_target = match normalized_named_destination_label(item.dest) {
    Some(dest) => Some("destination " + dest)
    None => None
  }

  match (dest_target, page_target) {
    (Some(dest), Some(page)) => Some(dest + " -> " + page)
    (Some(dest), None) => Some(dest)
    (None, Some(page)) => Some(page)
    (None, None) => None
  }
}
