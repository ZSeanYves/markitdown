///|
pub(all) enum Block {
  Heading(Int, String)
  RichHeading(Int, Array[Inline])
  Paragraph(String)
  RichParagraph(Array[Inline])
  ListItem(Bool, Int, String) // ordered, level, text
  RichListItem(Bool, Int, Array[Inline]) // ordered, level, inlines
  BlockQuote(String)
  RichBlockQuote(Array[Inline])
  CodeBlock(String)
  Table(Array[Array[String]])
  Image(String, String) // alt, path
  ImageBlock(ImageData)
  BlankLine
}

///|
pub(all) enum Inline {
  Text(String)
  Break
  Link(String, String) // text, url
}

///|
pub(all) struct Origin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  block_index : Int?
  heading_path : Array[String]?
} derive(Eq)

///|
pub(all) struct ImageData {
  path : String
  alt_text : String?
  title : String?
  caption : String?
  origin : Origin?
}

///|
pub(all) struct AssetOrigin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  origin_id : String?
  nearby_caption : String?
}

///|
pub struct Document {
  blocks : Ref[Array[Block]]
  block_origins : Ref[Array[Origin?]]
  asset_origins : Ref[Map[String, AssetOrigin]]
}

///|
pub fn new_document() -> Document {
  {
    blocks: { val: [] },
    block_origins: { val: [] },
    asset_origins: { val: Map::new() },
  }
}

///|
pub fn push(doc : Document, b : Block) -> Unit {
  push_with_origin(doc, b, None)
}

///|
pub fn push_with_origin(doc : Document, b : Block, origin : Origin?) -> Unit {
  doc.blocks.val.push(b)
  doc.block_origins.val.push(origin)
}

///|
pub fn set_asset_origin(
  doc : Document,
  asset_path : String,
  origin : AssetOrigin,
) -> Unit {
  if asset_path.trim() == "" {
    return
  }
  doc.asset_origins.val.set(asset_path, origin)
}

///|
pub impl Show for Origin with to_string(self : Origin) -> String {
  let out = StringBuilder::new()
  out.write_string("Origin{")

  out.write_string("source_name=")
  match self.source_name {
    Some(v) => out.write_string(v)
    None => out.write_string("None")
  }

  out.write_string(", page=")
  match self.page {
    Some(v) => out.write_string(v.to_string())
    None => out.write_string("None")
  }

  out.write_string(", slide=")
  match self.slide {
    Some(v) => out.write_string(v.to_string())
    None => out.write_string("None")
  }

  out.write_string(", sheet=")
  match self.sheet {
    Some(v) => out.write_string(v)
    None => out.write_string("None")
  }

  out.write_string(", block_index=")
  match self.block_index {
    Some(v) => out.write_string(v.to_string())
    None => out.write_string("None")
  }

  out.write_string(", heading_path=")
  match self.heading_path {
    Some(arr) => {
      out.write_string("[")
      for i in 0..<arr.length() {
        out.write_string(arr[i])
        if i + 1 < arr.length() {
          out.write_string(", ")
        }
      }
      out.write_string("]")
    }
    None => out.write_string("None")
  }

  out.write_string("}")
  out.to_string()
}

///|
pub impl Show for Origin with output(self : Origin, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
