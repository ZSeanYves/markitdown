///|
const ZIP_PARSER_NAME : String = "zip_container_parser"

///|
const ZIP_MAX_CONTAINER_ENTRIES : Int = 512

///|
const ZIP_MAX_TOTAL_UNCOMPRESSED_BYTES : Int = 32 * 1024 * 1024

///|
const ZIP_MAX_SINGLE_ENTRY_BYTES : Int = 8 * 1024 * 1024

///|
const ZIP_MAX_COMPRESSION_RATIO : Int = 200

///|
const ZIP_MAX_SELECTED_INNER_DOCUMENTS : Int = 128

///|
const ZIP_MAX_MATERIALIZED_ASSETS : Int = 256

///|
const ZIP_MAX_FILENAME_LENGTH : Int = 240

///|
const ZIP_MAX_DIRECTORY_DEPTH : Int = 16

///|
priv struct ZipAssetRewrite {
  old_asset_id : String
  old_path : String
  new_asset_id : String
  new_path : String
}

///|
fn zip_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::ContainerRecursive,
    true,
    @parser.StreamingGranularity::ArchiveEntry,
    true,
    false,
    false,
    false,
    false,
    false,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn zip_container_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    ZIP_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    zip_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_zip_container_result(source, context, registry_provider)
    },
  )
}

///|
fn parse_zip_container_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry_provider : () -> @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @light_common.empty_parser_diagnostics(
    ZIP_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    source,
    "zip",
  )
  diagnostics.metrics.set("parser_name", ZIP_PARSER_NAME)
  diagnostics.metrics.set("parser_mode", "container_recursive")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "zip")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "container_recursive")
  diagnostics.metrics.set("ir_input_kind", "container_plan")
  diagnostics.metrics.set("event_granularity", "archive_entry")
  diagnostics.metrics.set("event_semantics", "archive_entry_container_plan")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("manifest_seen", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  @light_common.apply_readiness_metrics(diagnostics, "zip", "near_ready")
  diagnostics.pass_trace.push("parse:" + ZIP_PARSER_NAME)

  let archive = try @dzip.open_zip(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let archive = match archive {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let report = @dzip.inspect_zip_archive(archive)
  let container_path = zip_container_path(source)
  diagnostics.metrics.set(
    "container_entry_count",
    report.entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "container_file_entry_count",
    report.file_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "container_directory_entry_count",
    report.directory_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    report.total_uncompressed_size.to_string(),
  )
  diagnostics.metrics.set(
    "total_compressed_bytes",
    report.total_compressed_size.to_string(),
  )
  diagnostics.metrics.set(
    "path_traversal_count",
    report.unsafe_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "duplicate_path_count",
    report.duplicate_normalized_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "encrypted_entry_count",
    report.encrypted_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_compression_count",
    report.unsupported_compression_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_compression_ratio_observed",
    zip_max_compression_ratio(report.inventory.entries).to_string(),
  )
  diagnostics.metrics.set(
    "max_container_entries",
    ZIP_MAX_CONTAINER_ENTRIES.to_string(),
  )
  diagnostics.metrics.set(
    "max_total_uncompressed_bytes",
    ZIP_MAX_TOTAL_UNCOMPRESSED_BYTES.to_string(),
  )
  diagnostics.metrics.set(
    "max_single_entry_bytes",
    ZIP_MAX_SINGLE_ENTRY_BYTES.to_string(),
  )
  diagnostics.metrics.set(
    "max_compression_ratio",
    ZIP_MAX_COMPRESSION_RATIO.to_string(),
  )
  diagnostics.metrics.set("max_nested_archive_depth", "1")
  diagnostics.metrics.set(
    "max_filename_length",
    ZIP_MAX_FILENAME_LENGTH.to_string(),
  )
  diagnostics.metrics.set(
    "max_directory_depth",
    ZIP_MAX_DIRECTORY_DEPTH.to_string(),
  )
  diagnostics.metrics.set(
    "max_selected_inner_documents",
    ZIP_MAX_SELECTED_INNER_DOCUMENTS.to_string(),
  )
  diagnostics.metrics.set(
    "max_materialized_assets",
    ZIP_MAX_MATERIALIZED_ASSETS.to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )

  let candidate_infos = report.inventory.entries.filter(info => {
    !info.is_directory && !info.is_hidden_metadata
  })
  let ordered_entries : Array[@core.ContainerEntry] = []
  let inner_documents : Array[@core.ContainerInnerDocument] = []
  let asset_plans : Array[@core.ContainerAssetPlan] = []
  let skipped_entries : Array[@core.ContainerEntry] = []
  let merged_blocks : Array[@core.CoreBlock] = []
  let merged_assets : Array[@core.AssetRef] = []
  let registry = registry_provider()
  let asset_entry_infos = zip_entry_info_index(report.inventory.entries)
  let mut selected_entry_count = 0
  let mut unsupported_entry_count = 0
  let mut nested_archive_count = 0
  let mut decoded_total = 0
  let mut resource_limit_hit = false

  for info in candidate_infos {
    let entry_path = zip_entry_display_path(info)
    let format_label = zip_entry_format_label(info)
    let entry_source_ref = zip_entry_source_ref(
      container_path,
      entry_path,
      ordered_entries.length(),
      format_label,
    )
    let security_findings = zip_entry_security_findings(info, report)
    let entry_kind = zip_entry_kind(info, report)
    let entry = @core.make_container_entry(
      entry_path,
      entry_kind,
      normalized_path=info.normalized_path,
      entry_index=Some(ordered_entries.length()),
      detected_format=format_label,
      media_type=zip_entry_media_type(info),
      compressed_size=Some(info.compressed_size),
      uncompressed_size=Some(info.uncompressed_size),
      is_encrypted=info.is_encrypted,
      compression_method=Some(
        zip_compression_method_name(info.compression_method),
      ),
      crc=Some(info.crc32.to_string()),
      source_ref=Some(entry_source_ref),
      security_findings~,
    )
    ordered_entries.push(entry)
    merged_blocks.push(zip_entry_heading_block(entry_source_ref, entry_path))

    match zip_skip_reason(info, report, selected_entry_count, decoded_total) {
      Some(reason) => {
        if reason.nested_archive {
          nested_archive_count += 1
        }
        if reason.unsupported {
          unsupported_entry_count += 1
        }
        if reason.resource_limit {
          resource_limit_hit = true
        }
        zip_record_skip_diagnostic(diagnostics, entry_path, reason)
        skipped_entries.push(entry)
        merged_blocks.push(zip_skip_block(entry_source_ref, reason.message))
      }
      None => {
        let detected_format = match zip_supported_inner_format(info) {
          Some(value) => value
          None => {
            let reason = zip_skip_unsupported_reason(info)
            unsupported_entry_count += 1
            if reason.nested_archive {
              nested_archive_count += 1
            }
            zip_record_skip_diagnostic(diagnostics, entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(zip_skip_block(entry_source_ref, reason.message))
            continue
          }
        }
        let entry_bytes = try
          @dzip.read_entry(
            archive,
            info.raw_name,
            max_output_size=ZIP_MAX_SINGLE_ENTRY_BYTES,
          )
          |> Ok
        catch {
          e => Err(e.to_string())
        }
        let entry_bytes = match entry_bytes {
          Ok(value) => value
          Err(err) => {
            let reason = {
              message: "Skipped: read entry failed: " + err,
              unsupported: false,
              nested_archive: false,
              resource_limit: false,
              severity_error: true,
            }
            zip_record_skip_diagnostic(diagnostics, entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(zip_skip_block(entry_source_ref, reason.message))
            continue
          }
        }
        decoded_total += info.uncompressed_size
        selected_entry_count += 1
        let inner_source = @input.input_from_bytes_with_format(
          entry_bytes,
          zip_inner_source_name(container_path, entry_path),
          Some(detected_format),
        )
        let inner_document = match
          zip_parse_inner_document(
            registry, inner_source, detected_format, context,
          ) {
          Ok(value) => value
          Err(err) => {
            let reason = {
              message: "Skipped: inner document parse failed: " + err,
              unsupported: false,
              nested_archive: false,
              resource_limit: false,
              severity_error: true,
            }
            zip_record_skip_diagnostic(diagnostics, entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(zip_skip_block(entry_source_ref, reason.message))
            continue
          }
        }
        zip_absorb_child_diagnostics(diagnostics, inner_document.diagnostics)
        let rewritten_assets = zip_rewrite_child_assets(
          inner_document.assets,
          entry,
          asset_entry_infos,
          asset_plans,
          merged_assets,
          diagnostics,
        )
        let rewritten_blocks = zip_rewrite_child_blocks(
          inner_document.blocks,
          entry,
          rewritten_assets,
          diagnostics,
        )
        merged_blocks.append(rewritten_blocks[:])
        inner_documents.push(
          @core.make_container_inner_document(
            entry,
            inner_source.source_name,
            explicit_detected_format=Some(
              @input.detected_format_name(detected_format),
            ),
            inner_source_ref=Some(entry_source_ref),
          ),
        )
      }
    }
  }

  diagnostics.metrics.set(
    "selected_entry_count",
    selected_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "skipped_entry_count",
    skipped_entries.length().to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_entry_count",
    unsupported_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "nested_archive_count",
    nested_archive_count.to_string(),
  )
  diagnostics.metrics.set("asset_count", merged_assets.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.metrics.set(
    "resource_limit_hit",
    @light_common.bool_string(resource_limit_hit),
  )

  let container_source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(container_path),
    Some("zip"),
    Some(container_path),
    None,
    None,
    None,
    None,
  )
  let plan = @core.make_container_plan(
    "zip",
    ordered_entries,
    inner_documents,
    asset_plans,
    container_path=Some(container_path),
    skipped_entries~,
    merged_blocks~,
    merged_assets~,
    diagnostics~,
    source_ref=Some(container_source_ref),
  )
  Ok(
    @parser.parse_result_with_container_plan(
      ZIP_PARSER_NAME,
      plan,
      diagnostics,
      zip_parser_capability(),
    ),
  )
}

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
  asset_plans : Array[@core.ContainerAssetPlan],
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
            asset_plans.push(
              @core.make_container_asset_plan(
                resolved_entry,
                output_relative_path,
                media_type=zip_entry_media_type(asset_info),
                size=Some(asset_info.uncompressed_size),
                copy_policy=@core.ContainerAssetCopyPolicy::MaterializeAtOutputBoundary,
                source_ref=Some(next_source_ref),
              ),
            )
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
