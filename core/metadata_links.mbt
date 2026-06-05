///|
priv struct MetadataLink {
  link_index : Int
  block_index : Int
  inline_index : Int
  text_start : Int
  text_end : Int
  block_type : String
  text : String
  url : String
  source_kind : String
  origin : MetadataOrigin?
}

///|
fn build_metadata_links(doc : Document, format : String) -> Array[MetadataLink] {
  let out : Array[MetadataLink] = []
  let markdown_ranges = markdown_line_ranges(doc)
  let mut next_link_index = 0

  for block_index in 0..<doc.blocks.val.length() {
    let block = doc.blocks.val[block_index]
    let origin = convert_block_origin(
      doc, block_index, format, block, markdown_ranges,
    )
    next_link_index = collect_metadata_links_from_block(
      out,
      next_link_index,
      block_index,
      metadata_block_type(block),
      metadata_link_source_kind(format),
      origin,
      block,
    )
  }

  out
}

///|
fn collect_metadata_links_from_block(
  out : Array[MetadataLink],
  next_link_index : Int,
  block_index : Int,
  block_type : String,
  source_kind : String,
  origin : MetadataOrigin?,
  block : Block,
) -> Int {
  match block {
    Block::RichHeading(_, inlines) =>
      collect_metadata_links_from_inlines(
        out, next_link_index, block_index, block_type, source_kind, origin, inlines,
      )
    Block::RichParagraph(inlines) =>
      collect_metadata_links_from_inlines(
        out, next_link_index, block_index, block_type, source_kind, origin, inlines,
      )
    Block::RichListItem(_, _, inlines) =>
      collect_metadata_links_from_inlines(
        out, next_link_index, block_index, block_type, source_kind, origin, inlines,
      )
    Block::RichBlockQuote(inlines) =>
      collect_metadata_links_from_inlines(
        out, next_link_index, block_index, block_type, source_kind, origin, inlines,
      )
    _ => next_link_index
  }
}

///|
fn collect_metadata_links_from_inlines(
  out : Array[MetadataLink],
  next_link_index : Int,
  block_index : Int,
  block_type : String,
  source_kind : String,
  origin : MetadataOrigin?,
  inlines : Array[Inline],
) -> Int {
  let mut link_index = next_link_index
  let mut text_cursor = 0

  for inline_index in 0..<inlines.length() {
    match inlines[inline_index] {
      Inline::Link(text, url) => {
        let text_start = text_cursor
        let text_end = text_start + text.length()
        out.push({
          link_index,
          block_index,
          inline_index,
          text_start,
          text_end,
          block_type,
          text,
          url,
          source_kind,
          origin,
        })
        link_index += 1
      }
      _ => ()
    }
    text_cursor += metadata_inline_text_for_link_range(inlines[inline_index]).length()
  }

  link_index
}

///|
fn metadata_inline_text_for_link_range(inline : Inline) -> String {
  match inline {
    Inline::Text(text) => text
    Inline::Break => "\n"
    Inline::Link(text, _url) => text
    Inline::NoteRef(_) => inline_text([inline])
  }
}

///|
fn metadata_link_source_kind(format : String) -> String {
  match format {
    "pdf" => "pdf_uri_annotation"
    "html" => "html_href"
    "docx" => "docx_hyperlink"
    "pptx" => "pptx_hyperlink"
    "epub" => "epub_href"
    "markdown" => "markdown_inline_link"
    _ => "inline_link"
  }
}

///|
fn serialize_links(links : Array[MetadataLink]) -> String {
  let parts : Array[String] = []
  for link in links {
    parts.push(serialize_link(link))
  }
  "[\n" + meta_indent_lines(meta_join_json_items(parts), 4) + "\n  ]"
}

///|
fn serialize_link(link : MetadataLink) -> String {
  let fields : Array[String] = []

  fields.push("\"link_index\": " + link.link_index.to_string())
  fields.push("\"block_index\": " + link.block_index.to_string())
  fields.push("\"inline_index\": " + link.inline_index.to_string())
  fields.push("\"text_start\": " + link.text_start.to_string())
  fields.push("\"text_end\": " + link.text_end.to_string())
  fields.push("\"block_type\": " + meta_json_string(link.block_type))
  fields.push("\"text\": " + meta_json_string(link.text))
  fields.push("\"url\": " + meta_json_string(link.url))
  fields.push("\"source_kind\": " + meta_json_string(link.source_kind))
  fields.push("\"origin\": " + serialize_origin_opt(link.origin))

  "{\n" + meta_indent_lines(meta_join_json_fields(fields), 2) + "\n}"
}
