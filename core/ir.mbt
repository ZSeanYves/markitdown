///|
/// Unified IR contract used by every converter in this repository.
///
/// Why this layer exists:
/// - converter-specific parsing is inherently heterogeneous (PDF layout, OOXML trees, HTML DOM-like nodes)
/// - downstream flows (markdown emitter, metadata sidecar, regression checks) need a stable shared shape
///
/// Design boundary:
/// - this is a semantic intermediate layer, not a byte-level parser output
/// - provenance fields are lightweight provenance for engineering consumption, not fine-grained anchors
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
  // Legacy image shape kept for backward compatibility with old emitters/tests.
  // New pipelines should prefer ImageBlock(ImageData).
  Image(String, String) // alt, path
  // Canonical image block carrying structured image context.
  ImageBlock(ImageData)
  BlankLine
}

///|
/// Inline-level IR shared by rich heading/paragraph/list/quote blocks.
pub(all) enum Inline {
  Text(String)
  Break
  Link(String, String) // text, url
}

///|
/// Lightweight provenance attached to text blocks.
///
/// Semantics:
/// - source_name/page/slide/sheet indicate coarse document position
/// - block_index points to block ordinal within the emitted IR stream
/// - heading_path is optional context for hierarchical consumers
///
/// Non-goal:
/// - not a pixel/range level anchor
pub(all) struct Origin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  block_index : Int?
  heading_path : Array[String]?
} derive(Eq)

///|
/// Canonical image payload in unified IR.
///
/// Field boundary:
/// - caption: primary semantic caption, only filled when confidence is high enough
/// - origin: optional lightweight provenance for the image block itself
/// - alt_text/title: source-native hints preserved for engineering consumption
pub(all) struct ImageData {
  path : String
  alt_text : String?
  title : String?
  caption : String?
  origin : Origin?
}

///|
/// Asset-level provenance index keyed by relative asset path.
///
/// `nearby_caption` is a mirrored convenience value for asset-oriented lookup.
/// It is expected to stay aligned with `ImageData.caption` when both exist.
pub(all) struct AssetOrigin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  origin_id : String?
  nearby_caption : String?
  object_ref : String?
  relationship_id : String?
  source_path : String?
  row_index : Int?
  column_index : Int?
  key_path : String?
}

///|
/// In-memory document container.
///
/// Dual-index design:
/// - blocks + block_origins: block-oriented reading/markdown workflows
/// - asset_origins: asset-oriented indexing workflows
/// - passthrough_markdown: original markdown body for formats that should not be
///   reconstructed from semantic IR
///
/// We keep these indices side-by-side so metadata sidecar can expose both views
/// (`blocks[]` and `assets[]`) without forcing every converter to rebuild joins.
pub struct Document {
  blocks : Ref[Array[Block]]
  block_origins : Ref[Array[Origin?]]
  asset_origins : Ref[Map[String, AssetOrigin]]
  passthrough_markdown : Ref[String?]
}

///|
pub fn new_document() -> Document {
  {
    blocks: { val: [] },
    block_origins: { val: [] },
    asset_origins: { val: Map::new() },
    passthrough_markdown: { val: None },
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
pub fn set_passthrough_markdown(doc : Document, markdown : String) -> Unit {
  doc.passthrough_markdown.val = Some(markdown)
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
