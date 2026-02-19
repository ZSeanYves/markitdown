pub(all) enum Block {
  Heading(Int, String)
  Paragraph(String)
  Table(Array[Array[String]])
  Image(String, String) // alt, path
  BlankLine
}

pub struct Document {
  blocks : Ref[Array[Block]]
}

pub fn new_document() -> Document {
  { blocks: { val: [] } }
}

pub fn push(doc: Document, b: Block) -> Unit {
  doc.blocks.val.push(b)
}

