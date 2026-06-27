///|
priv struct ZipSkipReason {
  message : String
  unsupported : Bool
  nested_archive : Bool
  resource_limit : Bool
  severity_error : Bool
}

///|
fn zip_skip_reason(
  info : @dzip.ZipEntryInfo,
  report : @dzip.ZipArchiveInspectReport,
  selected_entry_count : Int,
  decoded_total : Int,
) -> ZipSkipReason? {
  if info.is_unsafe_path {
    return Some({
      message: "Skipped: unsafe entry path",
      unsupported: false,
      nested_archive: false,
      resource_limit: false,
      severity_error: true,
    })
  }
  if zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::FilenameTooLong,
    ) {
    return Some({
      message: "Skipped: normalized entry path too long",
      unsupported: false,
      nested_archive: false,
      resource_limit: false,
      severity_error: true,
    })
  }
  if zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::DirectoryDepthExceeded,
    ) {
    return Some({
      message: "Skipped: normalized entry path too deep",
      unsupported: false,
      nested_archive: false,
      resource_limit: false,
      severity_error: true,
    })
  }
  match info.normalized_path {
    Some(path) =>
      if zip_entry_has_issue(
          report,
          info.raw_name,
          @dzip.ZipValidationIssueKind::DuplicateNormalizedEntry,
        ) {
        return Some({
          message: "Skipped: duplicate normalized entry path: " + path,
          unsupported: false,
          nested_archive: false,
          resource_limit: false,
          severity_error: true,
        })
      }
    None => ()
  }
  if info.is_encrypted {
    return Some({
      message: "Skipped: encrypted entry is not supported",
      unsupported: false,
      nested_archive: false,
      resource_limit: false,
      severity_error: true,
    })
  }
  match info.compression_method {
    @dzip.CompressionMethod::Unsupported(_) =>
      return Some({
        message: "Skipped: unsupported compression method",
        unsupported: false,
        nested_archive: false,
        resource_limit: false,
        severity_error: true,
      })
    _ => ()
  }
  if zip_entry_compression_ratio(info) > ZIP_MAX_COMPRESSION_RATIO {
    return Some({
      message: "Skipped: compression ratio limit exceeded",
      unsupported: false,
      nested_archive: false,
      resource_limit: true,
      severity_error: true,
    })
  }
  if info.uncompressed_size > ZIP_MAX_SINGLE_ENTRY_BYTES {
    return Some({
      message: "Skipped: entry too large: " +
      info.uncompressed_size.to_string() +
      " bytes",
      unsupported: false,
      nested_archive: false,
      resource_limit: true,
      severity_error: false,
    })
  }
  if decoded_total + info.uncompressed_size > ZIP_MAX_TOTAL_UNCOMPRESSED_BYTES {
    return Some({
      message: "Skipped: total decoded size limit exceeded",
      unsupported: false,
      nested_archive: false,
      resource_limit: true,
      severity_error: false,
    })
  }
  if selected_entry_count >= ZIP_MAX_SELECTED_INNER_DOCUMENTS {
    return Some({
      message: "Skipped: selected inner document limit exceeded",
      unsupported: false,
      nested_archive: false,
      resource_limit: true,
      severity_error: false,
    })
  }
  None
}

///|
fn zip_skip_unsupported_reason(info : @dzip.ZipEntryInfo) -> ZipSkipReason {
  match info.extension {
    Some(ext) =>
      if info.is_nested_archive_candidate {
        {
          message: "Skipped: nested archive is not supported: " + ext,
          unsupported: true,
          nested_archive: true,
          resource_limit: false,
          severity_error: false,
        }
      } else {
        {
          message: "Skipped: unsupported file type: " + ext,
          unsupported: true,
          nested_archive: false,
          resource_limit: false,
          severity_error: false,
        }
      }
    None =>
      {
        message: "Skipped: unsupported file type: unknown",
        unsupported: true,
        nested_archive: false,
        resource_limit: false,
        severity_error: false,
      }
  }
}

///|
fn zip_record_skip_diagnostic(
  diagnostics : @core.Diagnostics,
  entry_path : String,
  reason : ZipSkipReason,
) -> Unit {
  if reason.severity_error {
    diagnostics.errors.push(entry_path + ": " + reason.message)
  } else {
    diagnostics.warnings.push(entry_path + ": " + reason.message)
  }
  if reason.resource_limit {
    diagnostics.degraded_features.push("zip_resource_limit_skip")
  } else if reason.unsupported {
    diagnostics.degraded_features.push("zip_unsupported_entry_skip")
  } else {
    diagnostics.degraded_features.push("zip_security_entry_skip")
  }
  diagnostics.fallback_trace.push(
    "zip skip -> " + entry_path + " -> " + reason.message,
  )
}

///|
fn zip_parse_inner_document(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[@core.DocumentIR, String] {
  @runtime.parse_child_to_document(registry, source, format, context)
}

///|
fn zip_absorb_child_diagnostics(
  diagnostics : @core.Diagnostics,
  child : @core.Diagnostics,
) -> Unit {
  diagnostics.warnings.append(child.warnings[:])
  diagnostics.errors.append(child.errors[:])
  diagnostics.degraded_features.append(child.degraded_features[:])
  diagnostics.fallback_trace.append(child.fallback_trace[:])
  diagnostics.pass_trace.append(child.pass_trace[:])
}

///|
fn zip_rewrite_child_assets(
  assets : Array[@core.AssetRef],
  entry : @core.ContainerEntry,
  asset_entry_infos : Map[String, @dzip.ZipEntryInfo],
  merged_assets : Array[@core.AssetRef],
  diagnostics : @core.Diagnostics,
) -> Array[ZipAssetRewrite] {
  let rewrites : Array[ZipAssetRewrite] = []
  let entry_path = entry.entry_path
  for asset in assets {
    let old_path = asset.path.unwrap_or("").trim().to_owned()
    let old_asset_id = asset.asset_id
    match asset.attrs.get("source_path") {
      Some(source_path) => {
        let resolved_entry = match
          zip_resolve_asset_entry_path(entry_path, source_path) {
          Some(value) => value
          None => {
            diagnostics.warnings.push(
              "zip asset path rejected for entry `" +
              entry_path +
              "`: " +
              source_path,
            )
            continue
          }
        }
        if merged_assets.length() >= ZIP_MAX_MATERIALIZED_ASSETS {
          diagnostics.warnings.push(
            "zip asset materialization limit reached at entry `" +
            entry_path +
            "`",
          )
          diagnostics.degraded_features.push("zip_asset_limit_skip")
          diagnostics.fallback_trace.push(
            "zip asset skip -> materialization limit exceeded",
          )
          continue
        }
        match asset_entry_infos.get(resolved_entry) {
          Some(asset_info) => {
            if asset_info.is_unsafe_path {
              diagnostics.warnings.push(
                "zip asset entry is unsafe and was skipped: " + resolved_entry,
              )
              continue
            }
            let output_relative_path = zip_asset_output_path(
              entry_path, old_path,
            )
            let new_asset_id = "zip:" + entry_path + ":" + old_asset_id
            let next_source_ref = zip_rewrite_source_ref(
              asset.source_ref.unwrap_or(
                entry.source_ref.unwrap_or(@core.empty_source_ref()),
              ),
              entry,
              inner_path=None,
            )
            let next_asset = {
              ..asset,
              asset_id: new_asset_id,
              path: Some(output_relative_path),
              source_ref: Some(next_source_ref),
            }
            next_asset.attrs.set("zip_entry_path", resolved_entry)
            next_asset.attrs.set("zip_container_format", "zip")
            next_asset.attrs.set(
              "zip_container_path",
              entry.source_ref.unwrap_or(@core.empty_source_ref()).container_path.unwrap_or(
                "",
              ),
            )
            merged_assets.push(next_asset)
            rewrites.push({
              old_asset_id,
              old_path,
              new_asset_id,
              new_path: output_relative_path,
            })
          }
          None =>
            diagnostics.warnings.push(
              "zip asset entry missing for `" +
              entry_path +
              "`: " +
              resolved_entry,
            )
        }
      }
      None =>
        if zip_asset_is_remote(asset) {
          let next_source_ref = zip_rewrite_source_ref(
            asset.source_ref.unwrap_or(
              entry.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
            entry,
            inner_path=None,
          )
          merged_assets.push({ ..asset, source_ref: Some(next_source_ref) })
        }
    }
  }
  rewrites
}

///|
fn zip_rewrite_child_blocks(
  blocks : Array[@core.CoreBlock],
  entry : @core.ContainerEntry,
  rewrites : Array[ZipAssetRewrite],
  diagnostics : @core.Diagnostics,
) -> Array[@core.CoreBlock] {
  blocks.map(block => {
    zip_rewrite_single_block(block, entry, rewrites, diagnostics)
  })
}

///|
fn zip_rewrite_single_block(
  block : @core.CoreBlock,
  entry : @core.ContainerEntry,
  rewrites : Array[ZipAssetRewrite],
  diagnostics : @core.Diagnostics,
) -> @core.CoreBlock {
  let source_ref = zip_rewrite_source_ref(
    block.source_ref.unwrap_or(
      entry.source_ref.unwrap_or(@core.empty_source_ref()),
    ),
    entry,
    inner_path=None,
  )
  let rewritten_children = block.children.map(child => {
    zip_rewrite_single_block(child, entry, rewrites, diagnostics)
  })
  let rewritten_inlines = match block.rich_inlines {
    Some(inlines) =>
      Some(inlines.map(inline => zip_rewrite_inline(inline, entry, rewrites)))
    None => None
  }
  let next_block = {
    ..block,
    children: rewritten_children,
    rich_inlines: rewritten_inlines,
    source_ref: Some(source_ref),
  }
  if block.kind == @core.BlockKind::Image {
    let old_path = block.attrs.get("path").unwrap_or("")
    let old_asset_id = block.attrs.get("asset_id").unwrap_or("")
    match zip_find_asset_rewrite(rewrites, old_asset_id, old_path) {
      Some(rewrite) => {
        next_block.attrs.set("path", rewrite.new_path)
        next_block.attrs.set("asset_id", rewrite.new_asset_id)
      }
      None => {
        let trimmed_old_path = old_path.trim().to_owned()
        if !zip_block_is_remote_image(block) &&
          zip_path_looks_local_candidate(trimmed_old_path) {
          match
            zip_resolve_asset_entry_path(entry.entry_path, trimmed_old_path) {
            Some(_) =>
              diagnostics.warnings.push(
                "zip local image asset could not be materialized for entry `" +
                entry.entry_path +
                "`",
              )
            None =>
              diagnostics.warnings.push(
                "zip asset path rejected for entry `" +
                entry.entry_path +
                "`: " +
                trimmed_old_path,
              )
          }
          let alt = block.attrs.get("alt").unwrap_or("image")
          return @core.make_block(@core.BlockKind::Paragraph, alt, source_ref~)
        }
        if zip_image_block_looks_local(block) &&
          !zip_block_is_remote_image(block) {
          diagnostics.warnings.push(
            "zip local image asset could not be materialized for entry `" +
            entry.entry_path +
            "`",
          )
          let alt = block.attrs.get("alt").unwrap_or("image")
          return @core.make_block(@core.BlockKind::Paragraph, alt, source_ref~)
        }
      }
    }
  }
  next_block
}

///|
fn zip_rewrite_inline(
  inline : @core.CoreInline,
  entry : @core.ContainerEntry,
  rewrites : Array[ZipAssetRewrite],
) -> @core.CoreInline {
  let source_ref = zip_rewrite_source_ref(
    inline.source_ref.unwrap_or(
      entry.source_ref.unwrap_or(@core.empty_source_ref()),
    ),
    entry,
    inner_path=None,
  )
  if inline.kind != @core.InlineKind::Image {
    return { ..inline, source_ref: Some(source_ref) }
  }
  let old_path = inline.href.unwrap_or("")
  match zip_find_asset_rewrite(rewrites, "", old_path) {
    Some(rewrite) =>
      { ..inline, href: Some(rewrite.new_path), source_ref: Some(source_ref) }
    None => { ..inline, source_ref: Some(source_ref) }
  }
}

///|
fn zip_find_asset_rewrite(
  rewrites : Array[ZipAssetRewrite],
  old_asset_id : String,
  old_path : String,
) -> ZipAssetRewrite? {
  for rewrite in rewrites {
    if old_asset_id != "" && rewrite.old_asset_id == old_asset_id {
      return Some(rewrite)
    }
    if old_path != "" && rewrite.old_path == old_path {
      return Some(rewrite)
    }
  }
  None
}

///|
fn zip_rewrite_source_ref(
  source_ref : @core.SourceRef,
  entry : @core.ContainerEntry,
  inner_path? : String? = None,
) -> @core.SourceRef {
  let resolved_inner_path = match inner_path {
    Some(value) => Some(value)
    None => zip_inner_path(source_ref)
  }
  @core.source_ref_with_container_entry(
    source_ref,
    source_ref.file_id,
    source_ref.format,
    entry.source_ref.unwrap_or(@core.empty_source_ref()).container_path,
    Some(entry.entry_path),
    entry.entry_index,
    entry.detected_format,
    resolved_inner_path,
  )
}

///|
fn zip_inner_path(source_ref : @core.SourceRef) -> String? {
  match source_ref.json_pointer {
    Some(value) => return Some(value)
    None => ()
  }
  match source_ref.xpath {
    Some(value) => return Some(value)
    None => ()
  }
  match source_ref.yaml_path {
    Some(value) => return Some(value)
    None => ()
  }
  match source_ref.html_path {
    Some(value) => return Some(value)
    None => ()
  }
  match source_ref.markdown_path {
    Some(value) => return Some(value)
    None => ()
  }
  match source_ref.cell_range {
    Some(value) => Some(value)
    None => None
  }
}

///|
fn zip_image_block_looks_local(block : @core.CoreBlock) -> Bool {
  let path = block.attrs.get("path").unwrap_or("").trim().to_owned()
  path.has_prefix("assets/")
}

///|
fn zip_path_looks_local_candidate(path : String) -> Bool {
  if path == "" {
    return false
  }
  let lower = path.to_lower()
  !lower.has_prefix("http://") &&
  !lower.has_prefix("https://") &&
  !lower.has_prefix("data:")
}

///|
fn zip_block_is_remote_image(block : @core.CoreBlock) -> Bool {
  block.attrs.get("remote") == Some("true") ||
  block.attrs
  .get("path")
  .unwrap_or("")
  .trim()
  .to_owned()
  .to_lower()
  .has_prefix("http")
}

///|
fn zip_asset_is_remote(asset : @core.AssetRef) -> Bool {
  let path = asset.path.unwrap_or("").trim().to_owned().to_lower()
  path.has_prefix("http://") || path.has_prefix("https://")
}

///|
fn zip_resolve_asset_entry_path(
  entry_path : String,
  source_path : String,
) -> String? {
  let base_dir = zip_dirname(entry_path)
  let joined = if base_dir == "" {
    source_path.trim().to_owned()
  } else {
    base_dir + "/" + source_path.trim().to_owned()
  }
  @dzip.normalize_entry_path(joined)
}

///|
fn zip_asset_output_path(
  entry_path : String,
  child_asset_path : String,
) -> String {
  "assets/archive/" +
  zip_entry_id(entry_path) +
  "/" +
  zip_basename(child_asset_path.trim().to_owned())
}

///|
fn zip_entry_id(entry_path : String) -> String {
  entry_path
  .replace(old="\\", new="_")
  .replace(old="/", new="_")
  .replace(old=" ", new="_")
}

///|
fn zip_basename(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  parts.last().unwrap_or(normalized).to_owned()
}

///|
fn zip_dirname(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let chars = normalized.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last <= 0 {
    ""
  } else {
    normalized[:last].to_owned()
  }
}

///|
fn zip_entry_source_ref(
  container_path : String,
  entry_path : String,
  entry_index : Int,
  entry_format : String?,
) -> @core.SourceRef {
  @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(container_path),
    Some("zip"),
    Some(container_path),
    Some(entry_path),
    Some(entry_index),
    entry_format,
    None,
  )
}

///|
fn zip_entry_heading_block(
  source_ref : @core.SourceRef,
  text : String,
) -> @core.CoreBlock {
  let heading = @core.make_block(@core.BlockKind::Heading, text, source_ref~)
  heading.attrs.set("level", "1")
  heading
}

///|
fn zip_skip_block(
  source_ref : @core.SourceRef,
  text : String,
) -> @core.CoreBlock {
  let block = @core.make_block(@core.BlockKind::BlockQuote, text, source_ref~)
  block.attrs.set("literal", "true")
  block
}

///|
fn zip_container_path(source : @input.InputSource) -> String {
  match source.path {
    Some(path) => {
      let parts = path.replace(old="\\", new="/").split("/").to_array()
      parts.last().unwrap_or(source.source_name).to_owned()
    }
    None => source.source_name
  }
}

///|
fn zip_inner_source_name(
  container_path : String,
  entry_path : String,
) -> String {
  container_path + "::" + entry_path
}

///|
fn zip_entry_display_path(info : @dzip.ZipEntryInfo) -> String {
  match info.normalized_path {
    Some(path) => path
    None => info.raw_name.replace(old="\\", new="/")
  }
}

///|
fn zip_supported_inner_format(
  info : @dzip.ZipEntryInfo,
) -> @input.DetectedFormat? {
  if info.is_nested_archive_candidate {
    return None
  }
  match info.extension {
    Some(ext) => {
      let format = @input.parse_detected_format(ext)
      if format != @input.DetectedFormat::Unknown &&
        @container.container_supports_inner_format(format) {
        Some(format)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn zip_entry_format_label(info : @dzip.ZipEntryInfo) -> String? {
  match zip_supported_inner_format(info) {
    Some(format) => Some(@input.detected_format_name(format))
    None =>
      match info.extension {
        Some(ext) => Some(ext)
        None => None
      }
  }
}

///|
fn zip_entry_kind(
  info : @dzip.ZipEntryInfo,
  report : @dzip.ZipArchiveInspectReport,
) -> @core.ContainerEntryKind {
  if info.is_unsafe_path ||
    zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::DuplicateNormalizedEntry,
    ) ||
    zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::FilenameTooLong,
    ) ||
    zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::DirectoryDepthExceeded,
    ) {
    return @core.ContainerEntryKind::Unsafe
  }
  match zip_supported_inner_format(info) {
    Some(_) => @core.ContainerEntryKind::Document
    None =>
      if zip_entry_is_asset(info) {
        @core.ContainerEntryKind::Asset
      } else {
        @core.ContainerEntryKind::Unsupported
      }
  }
}

///|
fn zip_entry_is_asset(info : @dzip.ZipEntryInfo) -> Bool {
  match info.extension {
    Some(ext) =>
      ext == "png" ||
      ext == "jpg" ||
      ext == "jpeg" ||
      ext == "gif" ||
      ext == "webp" ||
      ext == "svg"
    None => false
  }
}

///|
fn zip_entry_security_findings(
  info : @dzip.ZipEntryInfo,
  report : @dzip.ZipArchiveInspectReport,
) -> Array[@core.ContainerSecurityFinding] {
  let findings : Array[@core.ContainerSecurityFinding] = []
  if info.is_unsafe_path {
    findings.push(@core.ContainerSecurityFinding::PathTraversal)
  }
  if zip_entry_has_issue(
      report,
      info.raw_name,
      @dzip.ZipValidationIssueKind::DuplicateNormalizedEntry,
    ) {
    findings.push(@core.ContainerSecurityFinding::DuplicateNormalizedPath)
  }
  if info.is_encrypted {
    findings.push(@core.ContainerSecurityFinding::EncryptedEntry)
  }
  match info.compression_method {
    @dzip.CompressionMethod::Unsupported(_) =>
      findings.push(@core.ContainerSecurityFinding::UnsupportedCompression)
    _ => ()
  }
  if info.is_nested_archive_candidate {
    findings.push(@core.ContainerSecurityFinding::NestedArchive)
  }
  if zip_entry_compression_ratio(info) > ZIP_MAX_COMPRESSION_RATIO {
    findings.push(@core.ContainerSecurityFinding::CompressionRatioLimit)
  }
  if info.uncompressed_size > ZIP_MAX_SINGLE_ENTRY_BYTES {
    findings.push(@core.ContainerSecurityFinding::ResourceLimitHit)
  }
  findings
}

///|
fn zip_entry_has_issue(
  report : @dzip.ZipArchiveInspectReport,
  raw_name : String,
  kind : @dzip.ZipValidationIssueKind,
) -> Bool {
  for issue in report.issues {
    if issue.raw_name == raw_name && issue.kind == kind {
      return true
    }
  }
  false
}

///|
fn zip_entry_info_index(
  infos : Array[@dzip.ZipEntryInfo],
) -> Map[String, @dzip.ZipEntryInfo] {
  let out : Map[String, @dzip.ZipEntryInfo] = Map([])
  for info in infos {
    match info.normalized_path {
      Some(path) => if !out.contains(path) { out.set(path, info) }
      None => ()
    }
  }
  out
}

///|
fn zip_max_compression_ratio(infos : Array[@dzip.ZipEntryInfo]) -> Int {
  let mut max_ratio = 1
  for info in infos {
    let ratio = zip_entry_compression_ratio(info)
    if ratio > max_ratio {
      max_ratio = ratio
    }
  }
  max_ratio
}

///|
fn zip_entry_compression_ratio(info : @dzip.ZipEntryInfo) -> Int {
  if zip_inventory_uses_unknown_compressed_size(info) {
    return 1
  }
  if info.compressed_size <= 0 {
    if info.uncompressed_size > 0 {
      return info.uncompressed_size
    }
    return 1
  }
  let ratio = info.uncompressed_size / info.compressed_size
  if ratio <= 0 {
    1
  } else {
    ratio
  }
}

///|
fn zip_inventory_uses_unknown_compressed_size(
  info : @dzip.ZipEntryInfo,
) -> Bool {
  info.compressed_size <= 0 &&
  info.uncompressed_size > 0 &&
  info.local_header_offset == 0 &&
  info.crc32 == 0 &&
  !info.has_data_descriptor &&
  !info.uses_zip64
}

///|
fn zip_compression_method_name(
  compression_method : @dzip.CompressionMethod,
) -> String {
  match compression_method {
    @dzip.CompressionMethod::Store => "store"
    @dzip.CompressionMethod::DeflateRaw => "deflate"
    @dzip.CompressionMethod::Unsupported(code) =>
      "unsupported:" + code.to_string()
  }
}

///|
fn zip_entry_media_type(info : @dzip.ZipEntryInfo) -> String? {
  match info.extension {
    Some(ext) =>
      if ext == "png" {
        Some("image/png")
      } else if ext == "jpg" || ext == "jpeg" {
        Some("image/jpeg")
      } else if ext == "gif" {
        Some("image/gif")
      } else if ext == "webp" {
        Some("image/webp")
      } else if ext == "svg" {
        Some("image/svg+xml")
      } else if ext == "html" || ext == "htm" {
        Some("text/html")
      } else if ext == "md" || ext == "markdown" {
        Some("text/markdown")
      } else if ext == "txt" {
        Some("text/plain")
      } else if ext == "csv" {
        Some("text/csv")
      } else if ext == "tsv" {
        Some("text/tab-separated-values")
      } else if ext == "json" || ext == "jsonl" || ext == "ndjson" {
        Some("application/json")
      } else if ext == "xml" {
        Some("application/xml")
      } else if ext == "yaml" || ext == "yml" {
        Some("application/yaml")
      } else {
        None
      }
    None => None
  }
}
