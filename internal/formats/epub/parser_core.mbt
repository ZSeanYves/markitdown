///|
const EPUB_PARSER_NAME : String = "epub_parser"

///|
const EPUB_MAX_CONTAINER_ENTRIES : Int = 512

///|
const EPUB_MAX_TOTAL_UNCOMPRESSED_BYTES : Int = 32 * 1024 * 1024

///|
const EPUB_MAX_SINGLE_ENTRY_BYTES : Int = 8 * 1024 * 1024

///|
const EPUB_MAX_SELECTED_SPINE_DOCUMENTS : Int = 128

///|
const EPUB_MAX_MATERIALIZED_ASSETS : Int = 256

///|
const EPUB_MAX_FILENAME_LENGTH : Int = 240

///|
const EPUB_MAX_DIRECTORY_DEPTH : Int = 16

///|
priv struct EpubAssetRewrite {
  old_asset_id : String
  old_path : String
  new_asset_id : String
  new_path : String
}

///|
priv struct EpubSkipReason {
  message : String
  warning : Bool
  unsupported : Bool
  resource_limit : Bool
  external_resource : Bool
}

///|
pub fn epub_parser_capability() -> @parser.ParserCapability {
  @parser.package_with_block_route_parser_capability(
    @parser.StreamingGranularity::EpubSpineItem,
    true,
    false,
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
fn epub_parse_with_package_core(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  pkg : @depub.EpubPackage,
  inspect : @depub.EpubInspectReport,
) -> @parser.ParseResult {
  let requested_container = context.requested_mode ==
    Some(@parser.ParserMode::ContainerRecursive)
  let effective_mode = if requested_container {
    @parser.ParserMode::ContainerRecursive
  } else {
    @parser.ParserMode::PackageSinglePass
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    EPUB_PARSER_NAME,
    effective_mode,
    source,
    "epub",
  )
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "epub",
    EPUB_PARSER_NAME,
    effective_mode,
    effective_mode,
    "block_stream",
    "epub_spine_item",
    "epub_spine_block_stream",
  )
  @fshared.init_parser_count_metrics(diagnostics)
  diagnostics.metrics.set("manifest_seen", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("nav_seen", "false")
  diagnostics.metrics.set("ncx_seen", "false")
  diagnostics.metrics.set("cover_candidate_seen", "false")
  diagnostics.metrics.set("missing_manifest_item_count", "0")
  diagnostics.metrics.set("missing_spine_item_count", "0")
  diagnostics.metrics.set("external_resource_count", "0")
  diagnostics.metrics.set("probe_artifact_reused", "false")
  diagnostics.metrics.set("process_cache_hit", "false")
  @fshared.apply_product_metrics(diagnostics, "epub")
  diagnostics.pass_trace.push("parse:" + EPUB_PARSER_NAME)

  let container_path = epub_container_path(source)
  let inventory = inspect.inventory
  let validations = @depub.collect_epub_validation_issues(pkg)

  diagnostics.metrics.set(
    "manifest_seen",
    @fshared.bool_string(inspect.manifest_count > 0),
  )
  diagnostics.metrics.set(
    "container_entry_count",
    inventory.part_count.to_string(),
  )
  diagnostics.metrics.set(
    "container_file_entry_count",
    inventory.part_count.to_string(),
  )
  diagnostics.metrics.set("container_directory_entry_count", "0")
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    epub_total_uncompressed_bytes(pkg.entries).to_string(),
  )
  diagnostics.metrics.set("total_compressed_bytes", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_path_count", "0")
  diagnostics.metrics.set(
    "encrypted_entry_count",
    bool_to_int_string(inventory.has_encryption),
  )
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("max_compression_ratio_observed", "1")
  diagnostics.metrics.set(
    "max_container_entries",
    EPUB_MAX_CONTAINER_ENTRIES.to_string(),
  )
  diagnostics.metrics.set(
    "max_total_uncompressed_bytes",
    EPUB_MAX_TOTAL_UNCOMPRESSED_BYTES.to_string(),
  )
  diagnostics.metrics.set(
    "max_single_entry_bytes",
    EPUB_MAX_SINGLE_ENTRY_BYTES.to_string(),
  )
  diagnostics.metrics.set("max_compression_ratio", "1")
  diagnostics.metrics.set("max_nested_archive_depth", "1")
  diagnostics.metrics.set(
    "max_filename_length",
    EPUB_MAX_FILENAME_LENGTH.to_string(),
  )
  diagnostics.metrics.set(
    "max_directory_depth",
    EPUB_MAX_DIRECTORY_DEPTH.to_string(),
  )
  diagnostics.metrics.set(
    "max_selected_inner_documents",
    EPUB_MAX_SELECTED_SPINE_DOCUMENTS.to_string(),
  )
  diagnostics.metrics.set(
    "max_materialized_assets",
    EPUB_MAX_MATERIALIZED_ASSETS.to_string(),
  )
  diagnostics.metrics.set("spine_item_count", inventory.spine_count.to_string())
  diagnostics.metrics.set(
    "nav_seen",
    @fshared.bool_string(
      inventory.nav_path is Some(_) || inventory.nav_document_path is Some(_),
    ),
  )
  diagnostics.metrics.set(
    "ncx_seen",
    @fshared.bool_string(inventory.ncx_path is Some(_)),
  )
  diagnostics.metrics.set(
    "cover_candidate_seen",
    @fshared.bool_string(inventory.cover_candidate_count > 0),
  )

  let issue_tallies = epub_issue_tallies(validations)
  diagnostics.metrics.set(
    "missing_manifest_item_count",
    issue_tallies.0.to_string(),
  )
  diagnostics.metrics.set(
    "missing_spine_item_count",
    issue_tallies.1.to_string(),
  )
  diagnostics.metrics.set(
    "external_resource_count",
    epub_external_resource_count(pkg).to_string(),
  )

  let ordered_entries : Array[@core.ContainerEntry] = []
  let skipped_entries : Array[@core.ContainerEntry] = []
  let merged_blocks : Array[@core.CoreBlock] = []
  let merged_assets : Array[@core.AssetRef] = []
  let asset_entry_infos = epub_entry_info_index(pkg.entries)
  let mut selected_entry_count = 0
  let mut unsupported_entry_count = 0
  let mut decoded_total = 0
  let mut resource_limit_hit = false

  let nav_heading_blocks = epub_nav_blocks(pkg, container_path)
  merged_blocks.append(nav_heading_blocks[:])
  let cover_assets = epub_cover_assets(
    pkg, container_path, asset_entry_infos, merged_blocks, merged_assets, diagnostics,
  )
  ignore(cover_assets)

  for spine_item in pkg.spine {
    if !spine_item.linear {
      continue
    }
    let entry = epub_spine_entry(container_path, spine_item)
    ordered_entries.push(entry)

    let heading_ref = entry.source_ref.unwrap_or(@core.empty_source_ref())
    merged_blocks.push(epub_entry_heading_block(heading_ref, entry.entry_path))

    match
      epub_spine_skip_reason(
        spine_item, selected_entry_count, decoded_total, asset_entry_infos,
      ) {
      Some(reason) => {
        if reason.unsupported {
          unsupported_entry_count += 1
        }
        if reason.resource_limit {
          resource_limit_hit = true
        }
        epub_record_skip_diagnostic(diagnostics, entry.entry_path, reason)
        skipped_entries.push(entry)
        merged_blocks.push(epub_skip_block(heading_ref, reason.message))
      }
      None => {
        let resolved_path = match spine_item.resolved_path {
          Some(value) => value
          None => {
            let reason = {
              message: "Skipped: spine item has no resolved target path: " +
              spine_item.idref,
              warning: false,
              unsupported: false,
              resource_limit: false,
              external_resource: false,
            }
            epub_record_skip_diagnostic(diagnostics, entry.entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(epub_skip_block(heading_ref, reason.message))
            continue
          }
        }
        let detected_format = @input.DetectedFormat::Html
        let entry_bytes = try
          @depub.read_part_bytes(pkg, resolved_path) |> Ok
        catch {
          e => Err(e.to_string())
        }
        let entry_bytes = match entry_bytes {
          Ok(value) => value
          Err(err) => {
            let reason = {
              message: "Skipped: read spine item failed: " + err,
              warning: false,
              unsupported: false,
              resource_limit: false,
              external_resource: false,
            }
            epub_record_skip_diagnostic(diagnostics, entry.entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(epub_skip_block(heading_ref, reason.message))
            continue
          }
        }
        selected_entry_count += 1
        decoded_total += entry_bytes.length()
        let inner_source = epub_inner_source(
          container_path, resolved_path, detected_format, entry_bytes,
        )
        let inner_child = match
          epub_parse_inner_document(
            registry, inner_source, detected_format, context,
          ) {
          Ok(value) => value
          Err(err) => {
            let reason = {
              message: "Skipped: inner spine parse failed: " + err,
              warning: false,
              unsupported: false,
              resource_limit: false,
              external_resource: false,
            }
            epub_record_skip_diagnostic(diagnostics, entry.entry_path, reason)
            skipped_entries.push(entry)
            merged_blocks.push(epub_skip_block(heading_ref, reason.message))
            continue
          }
        }
        epub_absorb_child_diagnostics(diagnostics, inner_child.diagnostics)
        let rewrites = epub_rewrite_child_assets(
          inner_child.assets,
          entry,
          asset_entry_infos,
          merged_assets,
          diagnostics,
        )
        let rewritten_blocks = epub_rewrite_child_blocks(
          inner_child.blocks,
          entry,
          rewrites,
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
  diagnostics.metrics.set("nested_archive_count", "0")
  diagnostics.metrics.set("asset_count", merged_assets.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
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
    EPUB_PARSER_NAME,
    effective_mode,
    merged_blocks,
    diagnostics,
    epub_parser_capability(),
    metadata=epub_package_metadata(pkg),
    assets=merged_assets,
    source_map=Some(@core.empty_source_map()),
  )
}

///|
pub fn epub_parse_with_package(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  pkg : @depub.EpubPackage,
  inspect : @depub.EpubInspectReport,
) -> @parser.ParseResult {
  let parsed = epub_parse_with_package_core(
    source, context, registry, pkg, inspect,
  )
  parsed.diagnostics.metrics.set("probe_artifact_reused", "false")
  parsed
}

///|
pub fn epub_parse_with_package_artifact(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  pkg : @depub.EpubPackage,
  inspect : @depub.EpubInspectReport,
) -> @parser.ParseResult {
  let parsed = epub_parse_with_package_core(
    source, context, registry, pkg, inspect,
  )
  parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
  parsed
}
