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
  // Only present for RichTable blocks with explicit header semantics.
  table : MetadataTableBlock?
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
priv struct MetadataTableBlock {
  rows : Array[Array[String]]
  header_rows : Int
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
  format : String?
  source_name : String?
  page : Int?
  slide : Int?
  sheet : String?
  block_index : Int?
  heading_path : Array[String]?
  line_start : Int?
  line_end : Int?
  row_index : Int?
  column_index : Int?
  object_ref : String?
  relationship_id : String?
  key_path : String?
}

///|
priv struct MetadataAssetOrigin {
  format : String?
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
fn build_document_metadata(
  doc : Document,
  source_name : String,
  format : String,
  markdown_file : String,
  document : MetadataDocumentProperties?,
) -> DocumentMetadata {
  let blocks = build_metadata_blocks(doc, format)
  let assets = build_metadata_assets(doc, format)

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
fn build_metadata_blocks(
  doc : Document,
  format : String,
) -> Array[MetadataBlock] {
  let out : Array[MetadataBlock] = []
  let markdown_ranges = markdown_line_ranges(doc)

  for i in 0..<doc.blocks.val.length() {
    let block = doc.blocks.val[i]
    let origin = convert_block_origin(doc, i, format, block, markdown_ranges)

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
          table: None,
        })
      Block::RichTable(table) =>
        out.push({
          block_index: i,
          block_type: "table",
          text: table_text(table.rows),
          origin,
          image: None,
          table: Some({ rows: table.rows, header_rows: table.header_rows }),
        })
      _ =>
        out.push({
          block_index: i,
          block_type: metadata_block_type(block),
          text: block_text_for_metadata(block),
          origin,
          image: None,
          table: None,
        })
    }
  }

  out
}

///|
fn build_metadata_assets(
  doc : Document,
  format : String,
) -> Array[MetadataAsset] {
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
          origin: Some(convert_asset_origin(asset_origin, format)),
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
    Block::RichTable(_) => "table"
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
    Block::RichTable(table) => table_text(table.rows)
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
fn markdown_line_ranges(doc : Document) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for _ in doc.blocks.val {
    out.push((0, 0))
  }

  let markdown = match doc.passthrough_markdown.val {
    Some(text) => text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
    None => return out
  }
  let lines : Array[String] = markdown
    .split("\n")
    .map(fn(line) { line.to_owned() })
    .iter()
    .collect()
  let mut cursor = 0

  for i in 0..<doc.blocks.val.length() {
    let text = block_text_for_metadata(doc.blocks.val[i])
    if text == "" {
      continue
    }
    let block_lines : Array[String] = text
      .replace(old="\r\n", new="\n")
      .replace(old="\r", new="\n")
      .split("\n")
      .map(fn(line) { line.to_owned() })
      .iter()
      .collect()
    match find_line_sequence(lines, block_lines, cursor) {
      Some(start) => {
        let end_ = start + block_lines.length() - 1
        out[i] = (start + 1, end_ + 1)
        cursor = end_ + 1
      }
      None => ()
    }
  }

  out
}

///|
fn find_line_sequence(
  lines : Array[String],
  needle : Array[String],
  from : Int,
) -> Int? {
  if needle.length() == 0 {
    return None
  }
  let mut i = from
  while i + needle.length() <= lines.length() {
    let mut ok = true
    for j in 0..<needle.length() {
      if lines[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn infer_block_line_range(
  format : String,
  _block : Block,
  index : Int,
  markdown_ranges : Array[(Int, Int)],
) -> (Int?, Int?) {
  if format == "markdown" {
    if index >= 0 && index < markdown_ranges.length() {
      let (start, end_) = markdown_ranges[index]
      if start > 0 && end_ >= start {
        return (Some(start), Some(end_))
      }
    }
  }

  (None, None)
}

///|
fn infer_block_key_path(format : String) -> String? {
  if format == "json" || format == "yaml" {
    Some("$")
  } else {
    None
  }
}

///|
fn int_opt_or(primary : Int?, fallback : Int?) -> Int? {
  match primary {
    Some(_) => primary
    None => fallback
  }
}

///|
fn string_opt_or(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(_) => primary
    None => fallback
  }
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
fn convert_block_origin(
  doc : Document,
  index : Int,
  format : String,
  block : Block,
  markdown_ranges : Array[(Int, Int)],
) -> MetadataOrigin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    return None
  }

  match doc.block_origins.val[index] {
    None => None
    Some(origin) => {
      let (inferred_line_start, inferred_line_end) = infer_block_line_range(
        format, block, index, markdown_ranges,
      )
      Some({
        format: Some(format),
        source_name: origin.source_name,
        page: origin.page,
        slide: origin.slide,
        sheet: origin.sheet,
        block_index: origin.block_index,
        heading_path: origin.heading_path,
        line_start: int_opt_or(origin.line_start, inferred_line_start),
        line_end: int_opt_or(origin.line_end, inferred_line_end),
        row_index: origin.row_index,
        column_index: origin.column_index,
        object_ref: origin.object_ref,
        relationship_id: origin.relationship_id,
        key_path: string_opt_or(origin.key_path, infer_block_key_path(format)),
      })
    }
  }
}

///|
fn convert_asset_origin(
  asset_origin : AssetOrigin,
  format : String,
) -> MetadataAssetOrigin {
  {
    format: Some(format),
    source_name: asset_origin.source_name,
    page: asset_origin.page,
    slide: asset_origin.slide,
    sheet: asset_origin.sheet,
    origin_id: asset_origin.origin_id,
    nearby_caption: asset_origin.nearby_caption,
    object_ref: asset_origin.object_ref,
    relationship_id: asset_origin.relationship_id,
    source_path: asset_origin.source_path,
    row_index: asset_origin.row_index,
    column_index: asset_origin.column_index,
    key_path: asset_origin.key_path,
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
  push_json_table_field(fields, "table", block.table)

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
fn serialize_table_block(table : MetadataTableBlock) -> String {
  let fields : Array[String] = []

  fields.push("\"rows\": " + serialize_string_matrix(table.rows))
  fields.push("\"header_rows\": " + table.header_rows.to_string())

  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_string_matrix(rows : Array[Array[String]]) -> String {
  let parts : Array[String] = []
  for row in rows {
    parts.push(serialize_string_array(row))
  }
  "[\n" + indent_lines(join_json_items(parts), 2) + "\n]"
}

///|
fn push_json_table_field(
  fields : Array[String],
  name : String,
  value : MetadataTableBlock?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + serialize_table_block(v))
    None => ()
  }
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

  push_json_string_field(fields, "format", origin.format)
  fields.push("\"source_name\": " + json_string_opt(origin.source_name))
  fields.push("\"page\": " + json_int_opt(origin.page))
  fields.push("\"slide\": " + json_int_opt(origin.slide))
  fields.push("\"sheet\": " + json_string_opt(origin.sheet))
  fields.push("\"block_index\": " + json_int_opt(origin.block_index))
  fields.push(
    "\"heading_path\": " + serialize_string_array_opt(origin.heading_path),
  )
  push_json_int_field(fields, "line_start", origin.line_start)
  push_json_int_field(fields, "line_end", origin.line_end)
  push_json_int_field(fields, "row_index", origin.row_index)
  push_json_int_field(fields, "column_index", origin.column_index)
  push_json_string_field(fields, "object_ref", origin.object_ref)
  push_json_string_field(fields, "relationship_id", origin.relationship_id)
  push_json_string_field(fields, "key_path", origin.key_path)

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

  push_json_string_field(fields, "format", origin.format)
  fields.push("\"source_name\": " + json_string_opt(origin.source_name))
  fields.push("\"page\": " + json_int_opt(origin.page))
  fields.push("\"slide\": " + json_int_opt(origin.slide))
  fields.push("\"sheet\": " + json_string_opt(origin.sheet))
  fields.push("\"origin_id\": " + json_string_opt(origin.origin_id))
  fields.push("\"nearby_caption\": " + json_string_opt(origin.nearby_caption))
  push_json_string_field(fields, "object_ref", origin.object_ref)
  push_json_string_field(fields, "relationship_id", origin.relationship_id)
  push_json_string_field(fields, "source_path", origin.source_path)
  push_json_int_field(fields, "row_index", origin.row_index)
  push_json_int_field(fields, "column_index", origin.column_index)
  push_json_string_field(fields, "key_path", origin.key_path)

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
fn push_json_string_field(
  fields : Array[String],
  name : String,
  value : String?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + json_string(v))
    None => ()
  }
}

///|
fn push_json_int_field(
  fields : Array[String],
  name : String,
  value : Int?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + v.to_string())
    None => ()
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
