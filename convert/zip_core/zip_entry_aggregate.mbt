///|
fn append_subdoc_asset_origins(
  doc : @cor.Document,
  subdoc : @cor.Document,
) -> Unit {
  for entry in subdoc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(doc, path, origin)
  }
}

///|
fn append_converted_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  subdoc : @cor.Document,
  zip_name : String,
  entry_path : String,
  entry_md : String,
) -> Unit {
  append_entry_heading(doc, final_md, zip_name, entry_path)
  final_md.write_string(trim_trailing_newlines(entry_md))
  final_md.write_string("\n\n")
  for i in 0..<subdoc.blocks.val.length() {
    let final_index = doc.blocks.val.length()
    @cor.push_with_origin(
      doc,
      rewrite_block_for_zip(
        subdoc.blocks.val[i],
        zip_name,
        entry_path,
        final_index,
      ),
      Some(
        rewrite_block_origin(
          origin_at(subdoc, i),
          zip_name,
          entry_path,
          final_index,
        ),
      ),
    )
  }
  append_subdoc_asset_origins(doc, subdoc)
}

///|
fn append_warning_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  zip_name : String,
  entry_path : String,
  message : String,
) -> Unit {
  append_entry_heading(doc, final_md, zip_name, entry_path)
  final_md.write_string("> ")
  final_md.write_string(message)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::BlockQuote(message),
    Some(zip_origin(zip_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn append_entry_heading(
  doc : @cor.Document,
  final_md : StringBuilder,
  zip_name : String,
  entry_path : String,
) -> Unit {
  final_md.write_string("# ")
  final_md.write_string(entry_path)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(1, entry_path),
    Some(zip_origin(zip_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn zip_origin(
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  {
    source_name: Some(zip_name),
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
fn origin_at(doc : @cor.Document, index : Int) -> @cor.Origin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    None
  } else {
    doc.block_origins.val[index]
  }
}

///|
fn rewrite_block_origin(
  origin : @cor.Origin?,
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  match origin {
    Some(o) =>
      {
        source_name: Some(zip_name),
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
    None => zip_origin(zip_name, entry_path, index)
  }
}

///|
fn rewrite_block_for_zip(
  block : @cor.Block,
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Block {
  match block {
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({
        ..img,
        origin: Some(
          rewrite_block_origin(img.origin, zip_name, entry_path, index),
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
