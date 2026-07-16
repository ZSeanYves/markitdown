///|
pub fn empty_source_ref() -> SourceRef {
  {
    file_id: None,
    format: None,
    page: None,
    bbox: None,
    line_start: None,
    line_end: None,
    byte_start: None,
    byte_end: None,
    time_start: None,
    time_end: None,
    xpath: None,
    json_pointer: None,
    yaml_path: None,
    html_path: None,
    markdown_path: None,
    container_path: None,
    entry_path: None,
    entry_index: None,
    entry_format: None,
    inner_path: None,
    sheet: None,
    cell_range: None,
    slide: None,
    shape_id: None,
    relationship_id: None,
    chapter_href: None,
    extra: Map([]),
  }
}

///|
pub fn empty_source_map() -> SourceMap {
  { document_ref: None, block_entries: [], asset_entries: [] }
}

///|
pub fn source_ref_with_lines(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  line_start : Int?,
  line_end : Int?,
) -> SourceRef {
  { ..source_ref, file_id, format, line_start, line_end }
}

///|
pub fn source_ref_with_json_pointer(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  json_pointer : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, json_pointer }
}

///|
pub fn source_ref_with_yaml_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  yaml_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, yaml_path }
}

///|
pub fn source_ref_with_html_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  html_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, html_path }
}

///|
pub fn source_ref_with_markdown_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  markdown_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, markdown_path }
}

///|
pub fn source_ref_with_container_entry(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  container_path : String?,
  entry_path : String?,
  entry_index : Int?,
  entry_format : String?,
  inner_path : String?,
) -> SourceRef {
  {
    ..source_ref,
    file_id,
    format,
    container_path,
    entry_path,
    entry_index,
    entry_format,
    inner_path,
  }
}

///|
pub fn make_container_entry(
  entry_path : String,
  entry_kind : ContainerEntryKind,
  normalized_path? : String? = None,
  entry_index? : Int? = None,
  detected_format? : String? = None,
  media_type? : String? = None,
  compressed_size? : Int? = None,
  uncompressed_size? : Int? = None,
  is_encrypted? : Bool = false,
  compression_method? : String? = None,
  crc? : String? = None,
  source_ref? : SourceRef? = None,
  security_findings? : Array[ContainerSecurityFinding] = [],
) -> ContainerEntry {
  {
    entry_path,
    normalized_path,
    entry_index,
    entry_kind,
    detected_format,
    media_type,
    compressed_size,
    uncompressed_size,
    is_encrypted,
    compression_method,
    crc,
    source_ref,
    security_findings,
  }
}

///|
pub fn container_entry_kind_name(kind : ContainerEntryKind) -> String {
  match kind {
    Document => "document"
    Asset => "asset"
    Metadata => "metadata"
    Directory => "directory"
    Unsupported => "unsupported"
    Unsafe => "unsafe"
  }
}

///|
pub fn container_security_finding_name(
  finding : ContainerSecurityFinding,
) -> String {
  match finding {
    PathTraversal => "path_traversal"
    AbsolutePath => "absolute_path"
    EncryptedEntry => "encrypted_entry"
    UnsupportedCompression => "unsupported_compression"
    CompressionRatioLimit => "compression_ratio_limit"
    DuplicateNormalizedPath => "duplicate_normalized_path"
    NestedArchive => "nested_archive"
    ExternalReference => "external_reference"
    ResourceLimitHit => "resource_limit_hit"
  }
}

///|
pub fn source_ref_with_bytes(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  byte_start : Int?,
  byte_end : Int?,
) -> SourceRef {
  { ..source_ref, file_id, format, byte_start, byte_end }
}

///|
pub fn source_ref_with_time_range(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  time_start : String?,
  time_end : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, time_start, time_end }
}

///|
pub fn source_ref_with_cell_range(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  cell_range : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, cell_range }
}

///|
pub fn source_ref_with_office_fields(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  inner_path : String?,
  sheet : String?,
  cell_range : String?,
  slide : Int?,
  shape_id : String?,
  relationship_id : String?,
) -> SourceRef {
  {
    ..source_ref,
    file_id,
    format,
    inner_path,
    sheet,
    cell_range,
    slide,
    shape_id,
    relationship_id,
  }
}

///|
pub fn source_ref_with_extra(
  source_ref : SourceRef,
  key : String,
  value : String,
) -> SourceRef {
  let next = { ..source_ref }
  next.extra.set(key, value)
  next
}
