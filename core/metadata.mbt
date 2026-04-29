///|
/// Metadata sidecar contract v1 for engineering consumption.
///
/// Positioning:
/// - sidecar is optional companion output to markdown, not a replacement
/// - markdown remains human-readable primary output
/// - sidecar carries structured provenance/image context for machine workflows
///
/// Stable contract (current stage):
/// - ImageBlock(ImageData) is the only semantic image entry.
/// - ImageData.caption is the primary caption value.
/// - asset nearby_caption is only a mirrored index value.
/// - If nearby_caption exists, it should equal caption.
/// - Block::Image remains legacy-compatible only.
///
/// This sidecar is intended for machine consumption:
/// - provenance / source attribution
/// - RAG chunking
/// - asset indexing
/// - image caption/origin lookup
priv struct DocumentMetadata {
  version : String
  source_name : String
  format : String
  markdown_file : String
  document : MetadataDocumentProperties?
  summary : MetadataSummary
  // Block-oriented view: aligns with markdown/IR order.
  blocks : Array[MetadataBlock]
  // Asset-oriented view: aligns with asset index and external retrieval needs.
  assets : Array[MetadataAsset]
}

///|
pub struct MetadataDocumentProperties {
  title : String?
  subject : String?
  creator : String?
  description : String?
  keywords : String?
  created : String?
  modified : String?
  application : String?
  pages : String?
  words : String?
  slides : String?
  sheets : String?
}

///|
pub fn metadata_document_properties(
  title : String?,
  subject : String?,
  creator : String?,
  description : String?,
  keywords : String?,
  created : String?,
  modified : String?,
  application : String?,
  pages : String?,
  words : String?,
  slides : String?,
  sheets : String?,
) -> MetadataDocumentProperties {
  {
    title,
    subject,
    creator,
    description,
    keywords,
    created,
    modified,
    application,
    pages,
    words,
    slides,
    sheets,
  }
}

///|
priv struct MetadataSummary {
  block_count : Int
  asset_count : Int
}

///|
priv struct MetadataBlock {
  // Stable ordinal in IR emission order.
  block_index : Int
  block_type : String
  text : String
  // Lightweight provenance, mirrors IR Origin boundary.
  origin : MetadataOrigin?
  // Only present for image blocks.
  image : MetadataImageBlock?
}

///|
priv struct MetadataImageBlock {
  path : String
  alt_text : String?
  title : String?
  // Primary semantic caption used by downstream consumers.
  caption : String?
}

///|
priv struct MetadataAsset {
  path : String
  asset_type : String
  alt_text : String?
  title : String?
  // Canonical caption for this asset (if confidently recovered).
  caption : String?
  origin : MetadataAssetOrigin?
  // Mirrored convenience value for asset-first indexing.
  nearby_caption : String?
}

///|
priv struct MetadataOrigin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  block_index : Int?
  heading_path : Array[String]?
}

///|
priv struct MetadataAssetOrigin {
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  origin_id : String?
  nearby_caption : String?
}

///|
fn build_document_metadata(
  doc : Document,
  source_name : String,
  format : String,
  markdown_file : String,
  document : MetadataDocumentProperties?,
) -> DocumentMetadata {
  let blocks = build_metadata_blocks(doc)
  let assets = build_metadata_assets(doc)

  {
    version: "1",
    source_name,
    format,
    markdown_file,
    document,
    summary: { block_count: blocks.length(), asset_count: assets.length() },
    blocks,
    assets,
  }
}

///|
fn build_metadata_blocks(doc : Document) -> Array[MetadataBlock] {
  let out : Array[MetadataBlock] = []

  for i in 0..<doc.blocks.val.length() {
    let block = doc.blocks.val[i]
    let origin = convert_block_origin(doc, i)

    match block {
      Block::ImageBlock(img) =>
        out.push({
          block_index: i,
          block_type: "image",
          text: img.caption.unwrap_or(""),
          origin,
          image: Some({
            path: img.path,
            alt_text: img.alt_text,
            title: img.title,
            caption: img.caption,
          }),
        })
      _ =>
        out.push({
          block_index: i,
          block_type: metadata_block_type(block),
          text: block_text_for_metadata(block),
          origin,
          image: None,
        })
    }
  }

  out
}

///|
fn build_metadata_assets(doc : Document) -> Array[MetadataAsset] {
  let out : Array[MetadataAsset] = []

  let paths : Array[String] = []
  for entry in doc.asset_origins.val {
    let (path, _asset_origin) = entry
    paths.push(path)
  }
  paths.sort()

  for path in paths {
    match doc.asset_origins.val.get(path) {
      None => ()
      Some(asset_origin) => {
        let img = find_image_data_by_path(doc, path)

        let alt_text = match img {
          Some(v) => v.alt_text
          None => None
        }

        let title = match img {
          Some(v) => v.title
          None => None
        }

        // Asset view reuses ImageBlock data when available.
        // This keeps `assets[]` and `blocks[]` image semantics consistent.
        let caption = match img {
          Some(v) => v.caption
          None => None
        }

        out.push({
          path,
          asset_type: "image",
          alt_text,
          title,
          caption,
          origin: Some(convert_asset_origin(asset_origin)),
          nearby_caption: asset_origin.nearby_caption,
        })
      }
    }
  }

  out
}

///|
fn metadata_block_type(block : Block) -> String {
  match block {
    Block::Heading(_, _) => "heading"
    Block::RichHeading(_) => "heading"
    Block::Paragraph(_) => "paragraph"
    Block::RichParagraph(_) => "paragraph"
    Block::ListItem(_, _, _) => "list_item"
    Block::RichListItem(_, _, _) => "list_item"
    Block::BlockQuote(_) => "blockquote"
    Block::RichBlockQuote(_) => "blockquote"
    Block::CodeBlock(_) => "code_block"
    Block::Table(_) => "table"
    Block::Image(_, _) => "image"
    Block::ImageBlock(_) => "image"
    Block::BlankLine => "blank_line"
  }
}

///|
fn block_text_for_metadata(block : Block) -> String {
  match block {
    Block::Heading(_, text) => text
    Block::RichHeading(_, inlines) => inline_text(inlines)
    Block::Paragraph(text) => text
    Block::RichParagraph(inlines) => inline_text(inlines)
    Block::ListItem(_, _, text) => text
    Block::RichListItem(_, _, inlines) => inline_text(inlines)
    Block::BlockQuote(text) => text
    Block::RichBlockQuote(inlines) => inline_text(inlines)
    Block::CodeBlock(text) => text
    Block::Table(rows) => table_text(rows)
    Block::Image(_, _) => ""
    Block::ImageBlock(img) => img.caption.unwrap_or("")
    Block::BlankLine => ""
  }
}

///|
fn inline_text(inlines : Array[Inline]) -> String {
  let out = StringBuilder::new()

  for inline in inlines {
    match inline {
      Inline::Text(text) => out.write_string(text)
      Inline::Break => out.write_string("\n")
      Inline::Link(text, _url) => out.write_string(text)
    }
  }

  out.to_string()
}

///|
fn table_text(rows : Array[Array[String]]) -> String {
  let out = StringBuilder::new()

  for i in 0..<rows.length() {
    let row = rows[i]
    for j in 0..<row.length() {
      out.write_string(row[j])
      if j + 1 < row.length() {
        out.write_string(" | ")
      }
    }
    if i + 1 < rows.length() {
      out.write_string("\n")
    }
  }

  out.to_string()
}

///|
fn find_image_data_by_path(doc : Document, path : String) -> ImageData? {
  for block in doc.blocks.val {
    match block {
      Block::ImageBlock(img) => if img.path == path { return Some(img) }
      _ => ()
    }
  }
  None
}

///|
fn convert_block_origin(doc : Document, index : Int) -> MetadataOrigin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    return None
  }

  match doc.block_origins.val[index] {
    None => None
    Some(origin) =>
      Some({
        source_name: origin.source_name,
        page: origin.page,
        slide: origin.slide,
        sheet: origin.sheet,
        block_index: origin.block_index,
        heading_path: origin.heading_path,
      })
  }
}

///|
fn convert_asset_origin(asset_origin : AssetOrigin) -> MetadataAssetOrigin {
  {
    source_name: asset_origin.source_name,
    page: asset_origin.page,
    slide: asset_origin.slide,
    sheet: asset_origin.sheet,
    origin_id: asset_origin.origin_id,
    nearby_caption: asset_origin.nearby_caption,
  }
}

///|
pub fn emit_metadata_json(
  doc : Document,
  source_name : String,
  format : String,
  markdown_file : String,
) -> String {
  emit_metadata_json_with_document_properties(
    doc,
    source_name,
    format,
    markdown_file,
    None,
  )
}

///|
pub fn emit_metadata_json_with_document_properties(
  doc : Document,
  source_name : String,
  format : String,
  markdown_file : String,
  document : MetadataDocumentProperties?,
) -> String {
  let meta = build_document_metadata(
    doc, source_name, format, markdown_file, document,
  )
  serialize_document_metadata(meta)
}

///|
fn serialize_document_metadata(meta : DocumentMetadata) -> String {
  "{\n" +
  "  \"version\": " +
  json_string(meta.version) +
  ",\n" +
  "  \"source_name\": " +
  json_string(meta.source_name) +
  ",\n" +
  "  \"format\": " +
  json_string(meta.format) +
  ",\n" +
  "  \"markdown_file\": " +
  json_string(meta.markdown_file) +
  ",\n" +
  "  \"document\": " +
  serialize_document_properties_opt(meta.document) +
  ",\n" +
  "  \"summary\": " +
  serialize_summary(meta.summary) +
  ",\n" +
  "  \"blocks\": " +
  serialize_blocks(meta.blocks) +
  ",\n" +
  "  \"assets\": " +
  serialize_assets(meta.assets) +
  "\n" +
  "}"
}

///|
fn serialize_document_properties_opt(
  document : MetadataDocumentProperties?,
) -> String {
  match document {
    None => "null"
    Some(v) => serialize_document_properties(v)
  }
}

///|
fn serialize_document_properties(
  document : MetadataDocumentProperties,
) -> String {
  let fields : Array[String] = []

  fields.push("\"title\": " + json_string_opt(document.title))
  fields.push("\"subject\": " + json_string_opt(document.subject))
  fields.push("\"creator\": " + json_string_opt(document.creator))
  fields.push("\"description\": " + json_string_opt(document.description))
  fields.push("\"keywords\": " + json_string_opt(document.keywords))
  fields.push("\"created\": " + json_string_opt(document.created))
  fields.push("\"modified\": " + json_string_opt(document.modified))
  fields.push("\"application\": " + json_string_opt(document.application))
  fields.push("\"pages\": " + json_string_opt(document.pages))
  fields.push("\"words\": " + json_string_opt(document.words))
  fields.push("\"slides\": " + json_string_opt(document.slides))
  fields.push("\"sheets\": " + json_string_opt(document.sheets))

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_summary(summary : MetadataSummary) -> String {
  "{\n" +
  "    \"block_count\": " +
  summary.block_count.to_string() +
  ",\n" +
  "    \"asset_count\": " +
  summary.asset_count.to_string() +
  "\n" +
  "  }"
}

///|
fn serialize_blocks(blocks : Array[MetadataBlock]) -> String {
  let parts : Array[String] = []
  for block in blocks {
    parts.push(serialize_block(block))
  }
  "[\n" + indent_lines(join_json_items(parts), 4) + "\n  ]"
}

///|
fn serialize_assets(assets : Array[MetadataAsset]) -> String {
  let parts : Array[String] = []
  for asset in assets {
    parts.push(serialize_asset(asset))
  }
  "[\n" + indent_lines(join_json_items(parts), 4) + "\n  ]"
}

///|
fn serialize_block(block : MetadataBlock) -> String {
  let fields : Array[String] = []

  fields.push("\"block_index\": " + block.block_index.to_string())
  fields.push("\"block_type\": " + json_string(block.block_type))
  fields.push("\"text\": " + json_string(block.text))
  fields.push("\"origin\": " + serialize_origin_opt(block.origin))
  fields.push("\"image\": " + serialize_image_block_opt(block.image))

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_asset(asset : MetadataAsset) -> String {
  let fields : Array[String] = []

  fields.push("\"path\": " + json_string(asset.path))
  fields.push("\"asset_type\": " + json_string(asset.asset_type))
  fields.push("\"alt_text\": " + json_string_opt(asset.alt_text))
  fields.push("\"title\": " + json_string_opt(asset.title))
  fields.push("\"caption\": " + json_string_opt(asset.caption))
  fields.push("\"origin\": " + serialize_asset_origin_opt(asset.origin))
  fields.push("\"nearby_caption\": " + json_string_opt(asset.nearby_caption))

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_image_block_opt(image : MetadataImageBlock?) -> String {
  match image {
    None => "null"
    Some(img) => serialize_image_block(img)
  }
}

///|
fn serialize_image_block(image : MetadataImageBlock) -> String {
  let fields : Array[String] = []

  fields.push("\"path\": " + json_string(image.path))
  fields.push("\"alt_text\": " + json_string_opt(image.alt_text))
  fields.push("\"title\": " + json_string_opt(image.title))
  fields.push("\"caption\": " + json_string_opt(image.caption))

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_origin_opt(origin : MetadataOrigin?) -> String {
  match origin {
    None => "null"
    Some(v) => serialize_origin(v)
  }
}

///|
fn serialize_origin(origin : MetadataOrigin) -> String {
  let fields : Array[String] = []

  fields.push("\"source_name\": " + json_string_opt(origin.source_name))
  fields.push("\"page\": " + json_int_opt(origin.page))
  fields.push("\"slide\": " + json_int_opt(origin.slide))
  fields.push("\"sheet\": " + json_string_opt(origin.sheet))
  fields.push("\"block_index\": " + json_int_opt(origin.block_index))
  fields.push(
    "\"heading_path\": " + serialize_string_array_opt(origin.heading_path),
  )

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_asset_origin_opt(origin : MetadataAssetOrigin?) -> String {
  match origin {
    None => "null"
    Some(v) => serialize_asset_origin(v)
  }
}

///|
fn serialize_asset_origin(origin : MetadataAssetOrigin) -> String {
  let fields : Array[String] = []

  fields.push("\"source_name\": " + json_string_opt(origin.source_name))
  fields.push("\"page\": " + json_int_opt(origin.page))
  fields.push("\"slide\": " + json_int_opt(origin.slide))
  fields.push("\"sheet\": " + json_string_opt(origin.sheet))
  fields.push("\"origin_id\": " + json_string_opt(origin.origin_id))
  fields.push("\"nearby_caption\": " + json_string_opt(origin.nearby_caption))

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_string_array_opt(xs : Array[String]?) -> String {
  match xs {
    None => "null"
    Some(arr) => serialize_string_array(arr)
  }
}

///|
fn serialize_string_array(xs : Array[String]) -> String {
  let parts : Array[String] = []
  for x in xs {
    parts.push(json_string(x))
  }
  "[" + join_json_items_inline(parts) + "]"
}

///|
fn json_string_opt(v : String?) -> String {
  match v {
    None => "null"
    Some(s) => json_string(s)
  }
}

///|
fn json_int_opt(v : Int?) -> String {
  match v {
    None => "null"
    Some(i) => i.to_string()
  }
}

///|
fn json_string(s : String) -> String {
  "\"" + escape_json_string(s) + "\""
}

///|
fn escape_json_string(s : String) -> String {
  let out = StringBuilder::new()
  for c in s.to_array() {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn join_json_items(items : Array[String]) -> String {
  let out = StringBuilder::new()
  for i in 0..<items.length() {
    out.write_string(items[i])
    if i + 1 < items.length() {
      out.write_string(",\n")
    }
  }
  out.to_string()
}

///|
fn join_json_items_inline(items : Array[String]) -> String {
  let out = StringBuilder::new()
  for i in 0..<items.length() {
    out.write_string(items[i])
    if i + 1 < items.length() {
      out.write_string(", ")
    }
  }
  out.to_string()
}

///|
fn join_json_fields(fields : Array[String]) -> String {
  let out = StringBuilder::new()
  for i in 0..<fields.length() {
    out.write_string(fields[i])
    if i + 1 < fields.length() {
      out.write_string(",\n")
    }
  }
  out.to_string()
}

///|
fn indent_lines(s : String, spaces : Int) -> String {
  let prefix = repeat_spaces(spaces)
  let lines = s.split("\n").to_array()
  let out = StringBuilder::new()

  for i in 0..<lines.length() {
    out.write_string(prefix)
    out.write_string(lines[i].to_owned())
    if i + 1 < lines.length() {
      out.write_string("\n")
    }
  }

  out.to_string()
}

///|
fn repeat_spaces(n : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<n {
    out.write_string(" ")
  }
  out.to_string()
}
