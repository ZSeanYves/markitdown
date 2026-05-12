///|
fn collect_shape_paragraphs(
  shapes : Array[PptxShape],
) -> Array[PptxTextParagraph] {
  let out : Array[PptxTextParagraph] = []
  for shape in shapes {
    for para in shape.text_paragraphs {
      out.push(para)
    }
    for child_para in collect_shape_paragraphs(shape.children) {
      out.push(child_para)
    }
  }
  out
}

///|
fn collect_shape_tables(shapes : Array[PptxShape]) -> Array[PptxTable] {
  let out : Array[PptxTable] = []
  for shape in shapes {
    match shape.table {
      Some(table) => out.push(table)
      None => ()
    }
    for child in collect_shape_tables(shape.children) {
      out.push(child)
    }
  }
  out
}

///|
fn collect_shape_media_refs(shapes : Array[PptxShape]) -> Array[PptxMediaRef] {
  let out : Array[PptxMediaRef] = []
  for shape in shapes {
    match shape.media_ref {
      Some(media) => out.push(media)
      None => ()
    }
    for child in collect_shape_media_refs(shape.children) {
      out.push(child)
    }
  }
  out
}

///|
fn collect_shape_hyperlinks(shapes : Array[PptxShape]) -> Array[PptxHyperlink] {
  let out : Array[PptxHyperlink] = []
  for shape in shapes {
    for link in shape.hyperlink_refs {
      out.push(link)
    }
    for child in collect_shape_hyperlinks(shape.children) {
      out.push(child)
    }
  }
  out
}

///|
fn collect_note_hyperlinks(notes : PptxNotes?) -> Array[PptxHyperlink] {
  match notes {
    Some(note_doc) => collect_hyperlinks_from_paragraphs(note_doc.paragraphs)
    None => []
  }
}

///|
fn parse_pptx_slide(
  pkg : @ox.OoxmlPackage,
  entry : PptxSlideEntry,
  index : Int,
  author_map : Map[String, PptxCommentAuthor],
) -> PptxSlide raise {
  let slide_xml = @ox.read_part_bytes(pkg, entry.part_name) catch {
    e => raise PptxError::ParseError("malformed slide xml: " + e.to_string())
  }
  if !contains_bytes(slide_xml, pat("<p:sld")) {
    raise PptxError::ParseError(
      "malformed slide xml: missing <p:sld> in " + entry.part_name,
    )
  }

  let issues : Array[PptxValidationIssue] = []
  let rels = read_pptx_relationship_index(pkg, entry.part_name)
  let ctx : PptxShapeParseContext = {
    pkg,
    rels,
    source_part: entry.part_name,
    issues,
  }
  let shape_tree = parse_pptx_shape_tree(slide_xml, ctx)
  let paragraphs = collect_shape_paragraphs(shape_tree)
  let tables = collect_shape_tables(shape_tree)
  let media_refs = collect_shape_media_refs(shape_tree)
  let hyperlink_refs = collect_shape_hyperlinks(shape_tree)
  let comments = parse_pptx_slide_comments(pkg, rels, author_map, issues)
  let notes = parse_pptx_notes(pkg, rels, issues)
  for link in collect_note_hyperlinks(notes) {
    hyperlink_refs.push(link)
  }

  {
    index,
    slide_id: entry.slide_id,
    relationship_id: entry.rel_id,
    part_path: entry.part_name,
    hidden: entry.hidden,
    relationships: rels,
    shape_tree,
    paragraphs,
    tables,
    media_refs,
    hyperlink_refs,
    comments,
    notes,
    issues,
  }
}
