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
pub fn zip_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::ContainerRecursive,
    true,
    @parser.StreamingGranularity::ArchiveEntry,
    true,
    false,
    false,
    false,
    true,
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
fn zip_parse_with_archive_core(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  archive : @dzip.ZipArchive,
  report : @dzip.ZipArchiveInspectReport,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    ZIP_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    source,
    "zip",
  )
  diagnostics.metrics.set("parser_name", ZIP_PARSER_NAME)
  diagnostics.metrics.set("parser_mode", "container_recursive")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "zip")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "container_recursive")
  diagnostics.metrics.set("ir_input_kind", "block_stream")
  diagnostics.metrics.set("event_granularity", "archive_entry")
  diagnostics.metrics.set("event_semantics", "archive_entry_block_stream")
  diagnostics.metrics.set("manifest_seen", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("probe_artifact_reused", "false")
  diagnostics.metrics.set("process_cache_hit", "false")
  @fshared.apply_product_metrics(diagnostics, "zip")
  diagnostics.pass_trace.push("parse:" + ZIP_PARSER_NAME)
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
  let skipped_entries : Array[@core.ContainerEntry] = []
  let merged_blocks : Array[@core.CoreBlock] = []
  let merged_assets : Array[@core.AssetRef] = []
  let asset_entry_infos = zip_entry_info_index(report.inventory.entries)
  let referenced_asset_entries = zip_collect_referenced_asset_entries(
    archive, candidate_infos, registry, context, container_path,
  )
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
    if zip_entry_is_asset(info) &&
      referenced_asset_entries.get(entry_path) == Some(true) {
      continue
    }
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
        let image_format = match info.extension {
          Some(ext) => {
            let value = @input.parse_detected_format(ext)
            if zip_image_format_uses_ocr(value) {
              Some(value)
            } else {
              None
            }
          }
          None => None
        }
        match image_format {
          Some(format) => {
            let entry_bytes = match
              zip_read_entry_bytes(archive, info.raw_name) {
              Ok(value) => value
              Err(err) => {
                diagnostics.warnings.push(
                  entry_path + ": standalone image read failed: " + err,
                )
                diagnostics.degraded_features.push(
                  "zip_standalone_image_read_failed",
                )
                continue
              }
            }
            decoded_total += info.uncompressed_size
            selected_entry_count += 1
            let (asset, image_block) = zip_standalone_image_asset(
              entry, entry_path, container_path, format,
            )
            merged_assets.push(asset)
            let inner_source = zip_inner_source(
              container_path, entry_path, format, entry_bytes,
            )
            match
              zip_parse_inner_document(registry, inner_source, format, context) {
              Ok(child) => {
                zip_absorb_child_diagnostics(diagnostics, child.diagnostics)
                merged_blocks.append(
                  zip_rewrite_child_blocks(child.blocks, entry, [], diagnostics)[:],
                )
              }
              Err(err) => {
                diagnostics.warnings.push(
                  entry_path + ": standalone image OCR unavailable: " + err,
                )
                diagnostics.degraded_features.push(
                  "zip_standalone_image_ocr_failed",
                )
                diagnostics.fallback_trace.push(
                  "zip standalone image -> preserve asset after OCR failure",
                )
              }
            }
            merged_blocks.push(image_block)
            continue
          }
          None => ()
        }
        if zip_entry_is_asset(info) {
          selected_entry_count += 1
          decoded_total += info.uncompressed_size
          let (asset, image_block) = zip_standalone_image_asset(
            entry,
            entry_path,
            container_path,
            @input.DetectedFormat::Unknown,
          )
          merged_assets.push(asset)
          merged_blocks.push(image_block)
          diagnostics.metrics.set("zip_standalone_asset_only_count", "present")
          continue
        }
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
        let entry_bytes = zip_read_entry_bytes(archive, info.raw_name)
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
        let inner_source = zip_inner_source(
          container_path, entry_path, detected_format, entry_bytes,
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
        ignore(inner_source)
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
    @fshared.bool_string(resource_limit_hit),
  )

  @parser.parse_result_with_blocks_capability(
    ZIP_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    merged_blocks,
    diagnostics,
    zip_parser_capability(),
    assets=merged_assets,
    source_map=Some(@core.empty_source_map()),
  )
}

///|
pub fn zip_parse_with_archive_artifact(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  archive : @dzip.ZipArchive,
  report : @dzip.ZipArchiveInspectReport,
) -> @parser.ParseResult {
  let parsed = zip_parse_with_archive(
    source, context, registry, archive, report,
  )
  parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
  parsed
}

///|
pub fn zip_parse_with_prepared_archive(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  prepared : @dzipsource.PreparedZipArchive,
) -> @parser.ParseResult {
  zip_parse_with_archive_artifact(
    source,
    context,
    registry,
    prepared.archive,
    prepared.inspect,
  )
}

///|
pub fn zip_parse_with_archive(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  archive : @dzip.ZipArchive,
  report : @dzip.ZipArchiveInspectReport,
) -> @parser.ParseResult {
  let parsed = zip_parse_with_archive_core(
    source, context, registry, archive, report,
  )
  parsed.diagnostics.metrics.set("probe_artifact_reused", "false")
  parsed
}

///|
fn zip_read_entry_bytes(
  archive : @dzip.ZipArchive,
  raw_name : String,
) -> Result[Bytes, String] {
  try
    @dzip.read_entry(
      archive,
      raw_name,
      max_output_size=ZIP_MAX_SINGLE_ENTRY_BYTES,
    )
    |> Ok
  catch {
    e => Err(e.to_string())
  }
}

///|
