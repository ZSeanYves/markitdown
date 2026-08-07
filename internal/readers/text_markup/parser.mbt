///|
pub fn parse_tex_document(text : String) -> TextMarkupDocument {
  parse_markup_document(text, Tex)
}

///|
pub fn parse_rst_document(text : String) -> TextMarkupDocument {
  parse_markup_document(text, Rst)
}

///|
pub fn parse_asciidoc_document(text : String) -> TextMarkupDocument {
  parse_markup_document(text, Asciidoc)
}

///|
pub fn inspect_text_markup_document(
  doc : TextMarkupDocument,
  original_text : String,
) -> TextMarkupInspectReport {
  let mut heading_count = 0
  let mut list_item_count = 0
  let mut code_count = 0
  let mut table_count = 0
  let mut blockquote_count = 0
  let mut raw_count = 0
  let mut paragraph_count = 0
  for block in doc.blocks {
    match block.kind {
      Heading => heading_count += 1
      ListItem => list_item_count += 1
      Code => code_count += 1
      Table => table_count += 1
      BlockQuote => blockquote_count += 1
      Semantic =>
        if text_markup_semantic_counts_as_quote(block) {
          blockquote_count += 1
        } else {
          paragraph_count += 1
        }
      NoteDefinition => paragraph_count += 1
      Raw => raw_count += 1
      Paragraph => paragraph_count += 1
    }
  }
  {
    block_count: doc.blocks.length(),
    heading_count,
    list_item_count,
    code_count,
    table_count,
    blockquote_count,
    raw_count,
    paragraph_count,
    line_count: count_markup_lines(original_text),
    char_count: original_text.length(),
  }
}
