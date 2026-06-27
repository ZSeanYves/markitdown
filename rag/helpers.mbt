///|
fn rag_location_metadata(
  source_refs : Array[@core.SourceRef],
) -> Map[String, @core.JsonValue] {
  let pages : Array[String] = []
  let slides : Array[String] = []
  let sheets : Array[String] = []
  let cell_ranges : Array[String] = []
  let entry_paths : Array[String] = []
  let container_paths : Array[String] = []
  let chapter_hrefs : Array[String] = []
  for source_ref in source_refs {
    append_unique_optional_string(
      pages,
      source_ref.page.map(i => i.to_string()),
    )
    append_unique_optional_string(
      slides,
      source_ref.slide.map(i => i.to_string()),
    )
    append_unique_optional_string(sheets, source_ref.sheet)
    append_unique_optional_string(cell_ranges, source_ref.cell_range)
    append_unique_optional_string(entry_paths, source_ref.entry_path)
    append_unique_optional_string(container_paths, source_ref.container_path)
    append_unique_optional_string(chapter_hrefs, source_ref.chapter_href)
  }
  let metadata : Map[String, @core.JsonValue] = Map([])
  if pages.length() > 0 {
    metadata.set("pages", string_json_array(pages))
  }
  if slides.length() > 0 {
    metadata.set("slides", string_json_array(slides))
  }
  if sheets.length() > 0 {
    metadata.set("sheets", string_json_array(sheets))
  }
  if cell_ranges.length() > 0 {
    metadata.set("cell_ranges", string_json_array(cell_ranges))
  }
  if entry_paths.length() > 0 {
    metadata.set("entry_paths", string_json_array(entry_paths))
  }
  if container_paths.length() > 0 {
    metadata.set("container_paths", string_json_array(container_paths))
  }
  if chapter_hrefs.length() > 0 {
    metadata.set("chapter_hrefs", string_json_array(chapter_hrefs))
  }
  metadata
}

///|
fn rag_metadata_fields(
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  document_format : String,
  document_title : String?,
  block_kinds : Array[String],
  source_refs : Array[@core.SourceRef],
  asset_refs : Array[String],
) -> Map[String, @core.JsonValue] {
  let metadata : Map[String, @core.JsonValue] = Map([])
  metadata.set("ordinal", @core.JsonValue::Number(ordinal.to_string()))
  metadata.set(
    "char_count",
    @core.JsonValue::Number(unicode_char_count(text).to_string()),
  )
  metadata.set(
    "heading_depth",
    @core.JsonValue::Number(heading_path.length().to_string()),
  )
  metadata.set("document_format", @core.JsonValue::String(document_format))
  match document_title {
    Some(title) if title.trim() != "" =>
      metadata.set("document_title", @core.JsonValue::String(title))
    _ => ()
  }
  metadata.set("block_kinds", string_json_array(block_kinds))
  metadata.set(
    "source_count",
    @core.JsonValue::Number(source_refs.length().to_string()),
  )
  metadata.set(
    "asset_count",
    @core.JsonValue::Number(asset_refs.length().to_string()),
  )
  metadata.set(
    "location",
    @core.JsonValue::Object(rag_location_metadata(source_refs)),
  )
  metadata
}

///|
fn metadata_title(metadata : Map[String, @core.JsonValue]) -> String? {
  for key in ["title", "subject", "description"] {
    match json_value_string(metadata.get(key)) {
      Some(value) if value.trim() != "" => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn append_unique_source_ref(
  refs : Array[@core.SourceRef],
  source_ref : @core.SourceRef?,
  enabled : Bool,
) -> Unit {
  if !enabled {
    return
  }
  match source_ref {
    Some(value) =>
      if !refs.any(existing => source_ref_eq(existing, value)) {
        refs.push(value)
      }
    None => ()
  }
}

///|
fn append_unique_optional_string(
  values : Array[String],
  value : String?,
) -> Unit {
  match value {
    Some(text) if text.trim() != "" => append_unique_string(values, text)
    _ => ()
  }
}

///|
fn append_unique_strings(
  target : Array[String],
  values : Array[String],
) -> Unit {
  for value in values {
    append_unique_string(target, value)
  }
}

///|
fn append_unique_string(values : Array[String], value : String) -> Unit {
  if !values.any(existing => existing == value) {
    values.push(value)
  }
}

///|
fn string_json_array(values : Array[String]) -> @core.JsonValue {
  @core.JsonValue::Array(values.map(value => @core.JsonValue::String(value)))
}

///|
fn json_value_string(value : @core.JsonValue?) -> String? {
  match value {
    Some(@core.JsonValue::String(text)) => Some(text)
    Some(@core.JsonValue::Number(text)) => Some(text)
    Some(@core.JsonValue::Bool(flag)) =>
      Some(if flag { "true" } else { "false" })
    _ => None
  }
}

///|
fn unicode_char_count(text : String) -> Int {
  let bytes = @encoding.encode(text, encoding=@encoding.UTF16LE)
  bytes.length() / 2
}

///|
fn make_chunk_id(
  kind : ChunkKind,
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  source_refs : Array[@core.SourceRef],
) -> String {
  let signature = chunk_kind_name(kind) +
    "|" +
    heading_path.join("/") +
    "|" +
    text +
    "|" +
    first_last_source_ref_signature(source_refs)
  let encoded = @encoding.encode(signature, encoding=@encoding.UTF16LE)
  let hash = @crypto.bytes_to_hex_string(@crypto.sha1(encoded))
  chunk_kind_name(kind) + "-" + ordinal.to_string() + "-" + hash[:8].to_owned()
}

///|
fn first_last_source_ref_signature(
  source_refs : Array[@core.SourceRef],
) -> String {
  if source_refs.length() == 0 {
    return ""
  }
  source_ref_signature(source_refs[0]) +
  "|" +
  source_ref_signature(source_refs[source_refs.length() - 1])
}

///|
fn source_ref_signature(source_ref : @core.SourceRef) -> String {
  [
    source_ref.file_id.unwrap_or(""),
    source_ref.format.unwrap_or(""),
    source_ref.page.map(i => i.to_string()).unwrap_or(""),
    source_ref.slide.map(i => i.to_string()).unwrap_or(""),
    source_ref.sheet.unwrap_or(""),
    source_ref.cell_range.unwrap_or(""),
    source_ref.entry_path.unwrap_or(""),
    source_ref.container_path.unwrap_or(""),
    source_ref.chapter_href.unwrap_or(""),
    source_ref.line_start.map(i => i.to_string()).unwrap_or(""),
    source_ref.line_end.map(i => i.to_string()).unwrap_or(""),
  ].join("|")
}

///|
fn source_ref_eq(left : @core.SourceRef, right : @core.SourceRef) -> Bool {
  source_ref_signature(left) == source_ref_signature(right)
}
