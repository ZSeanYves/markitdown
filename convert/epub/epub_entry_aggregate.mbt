///|
fn append_converted_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  subdoc : @cor.Document,
  epub_name : String,
  entry_path : String,
  entry_md : String,
) -> Unit {
  append_entry_heading(doc, final_md, epub_name, entry_path)
  final_md.write_string(trim_trailing_newlines(entry_md))
  final_md.write_string("\n\n")

  for i in 0..<subdoc.blocks.val.length() {
    let final_index = doc.blocks.val.length()
    @cor.push_with_origin(
      doc,
      rewrite_block_for_epub(
        subdoc.blocks.val[i],
        epub_name,
        entry_path,
        final_index,
      ),
      Some(
        rewrite_block_origin(
          origin_at(subdoc, i),
          epub_name,
          entry_path,
          final_index,
        ),
      ),
    )
  }

  for entry in subdoc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(doc, path, origin)
  }

  for note in subdoc.note_definitions.val {
    @cor.push_note_definition(doc, rewrite_note_definition_for_epub(note))
  }
}

///|
fn append_warning_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  epub_name : String,
  entry_path : String,
  message : String,
) -> Unit {
  append_entry_heading(doc, final_md, epub_name, entry_path)
  final_md.write_string("> ")
  final_md.write_string(message)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::BlockQuote(message),
    Some(epub_origin(epub_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn append_entry_heading(
  doc : @cor.Document,
  final_md : StringBuilder,
  epub_name : String,
  entry_path : String,
) -> Unit {
  final_md.write_string("# ")
  final_md.write_string(entry_path)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(1, entry_path),
    Some(epub_origin(epub_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn rewrite_note_definition_for_epub(
  note : @cor.NoteDefinition,
) -> @cor.NoteDefinition {
  { ..note, source_kind: @cor.NoteSourceKind::EpubFootnoteBody }
}

///|
fn origin_at(doc : @cor.Document, index : Int) -> @cor.Origin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    None
  } else {
    doc.block_origins.val[index]
  }
}

///|
fn epub_origin(
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  {
    source_name: Some(epub_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(index),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: Some(entry_path),
  }
}

///|
fn rewrite_block_origin(
  origin : @cor.Origin?,
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  match origin {
    Some(o) =>
      {
        source_name: Some(epub_name),
        page: o.page,
        slide: o.slide,
        sheet: o.sheet,
        block_index: Some(index),
        heading_path: o.heading_path,
        line_start: o.line_start,
        line_end: o.line_end,
        row_index: o.row_index,
        column_index: o.column_index,
        object_ref: o.object_ref,
        relationship_id: o.relationship_id,
        key_path: Some(entry_path),
      }
    None => epub_origin(epub_name, entry_path, index)
  }
}

///|
fn rewrite_block_for_epub(
  block : @cor.Block,
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Block {
  match block {
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({
        ..img,
        origin: Some(
          rewrite_block_origin(img.origin, epub_name, entry_path, index),
        ),
      })
    _ => block
  }
}

///|
fn trim_trailing_newlines(text : String) -> String {
  let mut end = text.length()
  while end > 0 && (text[end - 1] == '\n' || text[end - 1] == '\r') {
    end -= 1
  }
  text[:end].to_owned()
}
