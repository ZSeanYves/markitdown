///|
const EPUB_PARSER_NAME : String = "epub_container_parser"

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
fn epub_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::ContainerRecursive,
    true,
    @parser.StreamingGranularity::EpubSpineItem,
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
pub fn epub_container_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    EPUB_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    epub_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_epub_container_result(source, context, registry_provider)
    },
  )
}

///|
fn parse_epub_container_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry_provider : () -> @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @light_common.empty_parser_diagnostics(
    EPUB_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
    source,
    "epub",
  )
  diagnostics.metrics.set("parser_name", EPUB_PARSER_NAME)
  diagnostics.metrics.set("parser_mode", "container_recursive")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "epub")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "container_recursive")
  diagnostics.metrics.set("ir_input_kind", "container_plan")
  diagnostics.metrics.set("event_granularity", "epub_spine_item")
  diagnostics.metrics.set("event_semantics", "epub_spine_container_plan")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("manifest_seen", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("nav_seen", "false")
  diagnostics.metrics.set("ncx_seen", "false")
  diagnostics.metrics.set("cover_candidate_seen", "false")
  diagnostics.metrics.set("missing_manifest_item_count", "0")
  diagnostics.metrics.set("missing_spine_item_count", "0")
  diagnostics.metrics.set("external_resource_count", "0")
  @light_common.apply_readiness_metrics(diagnostics, "epub", "near_ready")
  diagnostics.pass_trace.push("parse:" + EPUB_PARSER_NAME)

  let container_path = epub_container_path(source)
  let pkg = try @depub.open_epub_package(bytes, container_path) |> Ok catch {
    e => Err(e.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let inspect = @depub.inspect_epub_package(pkg)
  let inventory = inspect.inventory
  let validations = @depub.collect_epub_validation_issues(pkg)
  let registry = registry_provider()

  diagnostics.metrics.set(
    "manifest_seen",
    @light_common.bool_string(inspect.manifest_count > 0),
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
    @light_common.bool_string(
      inventory.nav_path is Some(_) || inventory.nav_document_path is Some(_),
    ),
  )
  diagnostics.metrics.set(
    "ncx_seen",
    @light_common.bool_string(inventory.ncx_path is Some(_)),
  )
  diagnostics.metrics.set(
    "cover_candidate_seen",
    @light_common.bool_string(inventory.cover_candidate_count > 0),
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
  let inner_documents : Array[@core.ContainerInnerDocument] = []
  let asset_plans : Array[@core.ContainerAssetPlan] = []
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
    pkg, container_path, asset_entry_infos, merged_blocks, merged_assets, asset_plans,
    diagnostics,
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
        let inner_source = @input.input_from_bytes_with_format(
          entry_bytes,
          epub_inner_source_name(container_path, resolved_path),
          Some(detected_format),
        )
        let inner_document = match
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
        epub_absorb_child_diagnostics(diagnostics, inner_document.diagnostics)
        let rewrites = epub_rewrite_child_assets(
          inner_document.assets,
          entry,
          asset_entry_infos,
          asset_plans,
          merged_assets,
          diagnostics,
        )
        let rewritten_blocks = epub_rewrite_child_blocks(
          inner_document.blocks,
          entry,
          rewrites,
          diagnostics,
        )
        merged_blocks.append(rewritten_blocks[:])
        inner_documents.push(
          @core.make_container_inner_document(
            entry,
            inner_source.source_name,
            explicit_detected_format=Some("html"),
            inner_source_ref=Some(heading_ref),
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
  diagnostics.metrics.set("nested_archive_count", "0")
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
    Some("epub"),
    Some(container_path),
    None,
    None,
    None,
    None,
  )
  let plan = @core.make_container_plan(
    "epub",
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
      EPUB_PARSER_NAME,
      plan,
      diagnostics,
      epub_parser_capability(),
    ),
  )
}

///|
fn epub_total_uncompressed_bytes(
  entries : Array[@depub.EpubArchiveEntry],
) -> Int {
  let mut total = 0
  for entry in entries {
    total += entry.uncompressed_size
  }
  total
}

///|
fn epub_issue_tallies(issues : Array[@depub.EpubValidationIssue]) -> (Int, Int) {
  let mut missing_manifest = 0
  let mut missing_spine = 0
  for issue in issues {
    match issue.kind {
      @depub.EpubValidationIssueKind::MissingManifestItem =>
        missing_manifest += 1
      @depub.EpubValidationIssueKind::MissingSpineTarget => missing_spine += 1
      _ => ()
    }
  }
  (missing_manifest, missing_spine)
}

///|
fn epub_external_resource_count(pkg : @depub.EpubPackage) -> Int {
  let mut count = 0
  for item in pkg.manifest {
    let href = item.href.trim().to_owned().to_lower()
    if href.has_prefix("http://") ||
      href.has_prefix("https://") ||
      href.has_prefix("//") ||
      href.has_prefix("data:") {
      count += 1
    }
  }
  count
}

///|
fn epub_nav_blocks(
  pkg : @depub.EpubPackage,
  container_path : String,
) -> Array[@core.CoreBlock] {
  if pkg.nav_points.length() == 0 {
    return []
  }
  let nav_path = match pkg.nav_item {
    Some(item) => item.resolved_path
    None => return []
  }
  let nav_source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(container_path),
    Some("epub"),
    Some(container_path),
    Some(nav_path),
    None,
    Some("html"),
    None,
  )
  let blocks : Array[@core.CoreBlock] = []
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Table of Contents",
    source_ref=nav_source_ref,
  )
  heading.attrs.set("level", "1")
  blocks.push(heading)
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=nav_source_ref,
  )
  for point in pkg.nav_points {
    let item_ref = @core.source_ref_with_container_entry(
      nav_source_ref,
      Some(container_path),
      Some("epub"),
      Some(container_path),
      Some(nav_path),
      None,
      Some("html"),
      None,
    )
    let mut item = @core.make_block(
      @core.BlockKind::ListItem,
      point.label,
      source_ref=item_ref,
    )
    item = @core.block_with_rich_inlines(
      item,
      Some([
        @core.make_inline_link(point.label, point.href, source_ref=item_ref),
      ]),
    )
    list.children.push(item)
  }
  blocks.push(list)
  blocks
}

///|
fn epub_cover_assets(
  pkg : @depub.EpubPackage,
  container_path : String,
  asset_entry_infos : Map[String, @depub.EpubArchiveEntry],
  merged_blocks : Array[@core.CoreBlock],
  merged_assets : Array[@core.AssetRef],
  asset_plans : Array[@core.ContainerAssetPlan],
  diagnostics : @core.Diagnostics,
) -> Unit {
  let cover_item = match pkg.cover_item {
    Some(value) => value
    None => return
  }
  let cover_path = cover_item.resolved_path
  match asset_entry_infos.get(cover_path) {
    Some(info) => {
      if merged_assets.length() >= EPUB_MAX_MATERIALIZED_ASSETS {
        diagnostics.warnings.push(
          "epub cover asset materialization limit reached",
        )
        diagnostics.degraded_features.push("epub_asset_limit_skip")
        diagnostics.fallback_trace.push(
          "epub asset skip -> materialization limit exceeded",
        )
        return
      }
      let source_ref = @core.source_ref_with_container_entry(
        @core.empty_source_ref(),
        Some(container_path),
        Some("epub"),
        Some(container_path),
        Some(cover_path),
        None,
        Some("binary"),
        None,
      )
      let output_relative_path = "assets/archive/" +
        epub_entry_id(cover_path) +
        "/image01." +
        epub_image_ext(cover_path)
      let asset = @core.make_asset_ref(
        @core.AssetKind::Image,
        "epub:" + cover_path + ":cover",
        source_ref~,
      )
      let next_asset = { ..asset, path: Some(output_relative_path) }
      let alt = epub_basename(cover_path)
      next_asset.attrs.set("alt", alt)
      next_asset.attrs.set("source_path", cover_path)
      next_asset.attrs.set("zip_entry_path", cover_path)
      next_asset.attrs.set("zip_container_format", "epub")
      next_asset.attrs.set("zip_container_path", container_path)
      merged_assets.push(next_asset)
      asset_plans.push(
        @core.make_container_asset_plan(
          cover_path,
          output_relative_path,
          media_type=cover_item.media_type,
          size=Some(info.uncompressed_size),
          copy_policy=@core.ContainerAssetCopyPolicy::MaterializeAtOutputBoundary,
          source_ref=Some(source_ref),
        ),
      )
      let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
      image.attrs.set("path", output_relative_path)
      image.attrs.set("asset_id", "epub:" + cover_path + ":cover")
      image.attrs.set("alt", alt)
      merged_blocks.push(image)
    }
    None =>
      diagnostics.warnings.push("epub cover asset entry missing: " + cover_path)
  }
}

///|
fn epub_spine_entry(
  container_path : String,
  spine_item : @depub.EpubSpineItem,
) -> @core.ContainerEntry {
  let entry_path = match spine_item.resolved_path {
    Some(path) => path
    None =>
      match spine_item.manifest_item {
        Some(item) =>
          if epub_is_external_href(item.href) {
            "(non-package spine target #" +
            spine_item.spine_index.to_string() +
            ": " +
            item.href +
            ")"
          } else {
            "(missing spine target #" +
            spine_item.spine_index.to_string() +
            ": " +
            item.id +
            ")"
          }
        None =>
          "(missing manifest item #" +
          spine_item.spine_index.to_string() +
          ": " +
          spine_item.idref +
          ")"
      }
  }
  let media_type = spine_item.manifest_item.bind(fn(item) { item.media_type })
  let source_ref = epub_entry_source_ref(
    container_path,
    entry_path,
    spine_item.spine_index,
    media_type,
  )
  let entry_kind = match spine_item.resolved_path {
    Some(_) =>
      if epub_spine_item_supported(spine_item) {
        @core.ContainerEntryKind::Document
      } else {
        @core.ContainerEntryKind::Unsupported
      }
    None =>
      match spine_item.manifest_item {
        Some(item) =>
          if epub_is_external_href(item.href) {
            @core.ContainerEntryKind::Unsupported
          } else {
            @core.ContainerEntryKind::Unsupported
          }
        None => @core.ContainerEntryKind::Unsafe
      }
  }
  let security_findings : Array[@core.ContainerSecurityFinding] = []
  match spine_item.manifest_item {
    Some(item) =>
      if epub_is_external_href(item.href) {
        security_findings.push(
          @core.ContainerSecurityFinding::ExternalReference,
        )
      }
    None => ()
  }
  @core.make_container_entry(
    entry_path,
    entry_kind,
    normalized_path=spine_item.resolved_path,
    entry_index=Some(spine_item.spine_index),
    detected_format=Some("html"),
    media_type~,
    compressed_size=None,
    uncompressed_size=None,
    source_ref=Some(source_ref),
    security_findings~,
  )
}

///|
fn epub_spine_skip_reason(
  spine_item : @depub.EpubSpineItem,
  selected_entry_count : Int,
  decoded_total : Int,
  asset_entry_infos : Map[String, @depub.EpubArchiveEntry],
) -> EpubSkipReason? {
  if !spine_item.linear {
    return Some({
      message: "Skipped: non-linear spine item",
      warning: true,
      unsupported: false,
      resource_limit: false,
      external_resource: false,
    })
  }
  match spine_item.manifest_item {
    Some(item) =>
      if epub_is_external_href(item.href) {
        return Some({
          message: "Skipped: spine item targets non-package resource: " +
          item.href,
          warning: true,
          unsupported: false,
          resource_limit: false,
          external_resource: true,
        })
      }
    None =>
      return Some({
        message: "Skipped: spine item references missing manifest item: " +
        spine_item.idref,
        warning: true,
        unsupported: false,
        resource_limit: false,
        external_resource: false,
      })
  }
  let resolved_path = match spine_item.resolved_path {
    Some(value) => value
    None =>
      return Some({
        message: "Skipped: spine item has no resolved target path: " +
        spine_item.idref,
        warning: false,
        unsupported: false,
        resource_limit: false,
        external_resource: false,
      })
  }
  if !epub_spine_item_supported(spine_item) {
    let media_type = spine_item.manifest_item
      .bind(fn(item) { item.media_type })
      .unwrap_or("(missing)")
    return Some({
      message: "Skipped: unsupported spine media type: " + media_type,
      warning: true,
      unsupported: true,
      resource_limit: false,
      external_resource: false,
    })
  }
  if selected_entry_count >= EPUB_MAX_SELECTED_SPINE_DOCUMENTS {
    return Some({
      message: "Skipped: selected spine item limit exceeded",
      warning: true,
      unsupported: false,
      resource_limit: true,
      external_resource: false,
    })
  }
  match asset_entry_infos.get(resolved_path) {
    Some(info) => {
      if info.uncompressed_size > EPUB_MAX_SINGLE_ENTRY_BYTES {
        return Some({
          message: "Skipped: spine item too large: " +
          info.uncompressed_size.to_string() +
          " bytes",
          warning: true,
          unsupported: false,
          resource_limit: true,
          external_resource: false,
        })
      }
      if decoded_total + info.uncompressed_size >
        EPUB_MAX_TOTAL_UNCOMPRESSED_BYTES {
        return Some({
          message: "Skipped: total decoded size limit exceeded",
          warning: true,
          unsupported: false,
          resource_limit: true,
          external_resource: false,
        })
      }
    }
    None =>
      return Some({
        message: "Skipped: spine item entry missing from package: " +
        resolved_path,
        warning: false,
        unsupported: false,
        resource_limit: false,
        external_resource: false,
      })
  }
  None
}

///|
fn epub_record_skip_diagnostic(
  diagnostics : @core.Diagnostics,
  entry_path : String,
  reason : EpubSkipReason,
) -> Unit {
  if reason.warning {
    diagnostics.warnings.push(entry_path + ": " + reason.message)
  } else {
    diagnostics.errors.push(entry_path + ": " + reason.message)
  }
  if reason.external_resource {
    diagnostics.degraded_features.push("epub_external_resource_skip")
  } else if reason.resource_limit {
    diagnostics.degraded_features.push("epub_resource_limit_skip")
  } else if reason.unsupported {
    diagnostics.degraded_features.push("epub_unsupported_spine_skip")
  } else {
    diagnostics.degraded_features.push("epub_spine_skip")
  }
  diagnostics.fallback_trace.push(
    "epub skip -> " + entry_path + " -> " + reason.message,
  )
}

///|
fn epub_parse_inner_document(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[@core.DocumentIR, String] {
  @runtime.parse_child_to_document(registry, source, format, context)
}

///|
fn epub_absorb_child_diagnostics(
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
fn epub_rewrite_child_assets(
  assets : Array[@core.AssetRef],
  entry : @core.ContainerEntry,
  asset_entry_infos : Map[String, @depub.EpubArchiveEntry],
  asset_plans : Array[@core.ContainerAssetPlan],
  merged_assets : Array[@core.AssetRef],
  diagnostics : @core.Diagnostics,
) -> Array[EpubAssetRewrite] {
  let rewrites : Array[EpubAssetRewrite] = []
  let entry_path = entry.entry_path
  for asset in assets {
    let old_path = asset.path.unwrap_or("").trim().to_owned()
    let old_asset_id = asset.asset_id
    match asset.attrs.get("source_path") {
      Some(source_path) => {
        let resolved_entry = match
          epub_resolve_asset_entry_path(entry_path, source_path) {
          Some(value) => value
          None => {
            diagnostics.warnings.push(
              "epub asset path rejected for entry `" +
              entry_path +
              "`: " +
              source_path,
            )
            continue
          }
        }
        if merged_assets.length() >= EPUB_MAX_MATERIALIZED_ASSETS {
          diagnostics.warnings.push(
            "epub asset materialization limit reached at entry `" +
            entry_path +
            "`",
          )
          diagnostics.degraded_features.push("epub_asset_limit_skip")
          diagnostics.fallback_trace.push(
            "epub asset skip -> materialization limit exceeded",
          )
          continue
        }
        match asset_entry_infos.get(resolved_entry) {
          Some(asset_info) => {
            let output_relative_path = epub_asset_output_path(
              entry_path, old_path,
            )
            let new_asset_id = "epub:" + entry_path + ":" + old_asset_id
            let next_source_ref = epub_rewrite_source_ref(
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
            next_asset.attrs.set("zip_container_format", "epub")
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
                media_type=epub_entry_media_type(asset_info.path),
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
              "epub asset entry missing for `" +
              entry_path +
              "`: " +
              resolved_entry,
            )
        }
      }
      None =>
        if epub_asset_is_remote(asset) {
          let next_source_ref = epub_rewrite_source_ref(
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
fn epub_rewrite_child_blocks(
  blocks : Array[@core.CoreBlock],
  entry : @core.ContainerEntry,
  rewrites : Array[EpubAssetRewrite],
  diagnostics : @core.Diagnostics,
) -> Array[@core.CoreBlock] {
  blocks.map(block => {
    epub_rewrite_single_block(block, entry, rewrites, diagnostics)
  })
}

///|
fn epub_rewrite_single_block(
  block : @core.CoreBlock,
  entry : @core.ContainerEntry,
  rewrites : Array[EpubAssetRewrite],
  diagnostics : @core.Diagnostics,
) -> @core.CoreBlock {
  let source_ref = epub_rewrite_source_ref(
    block.source_ref.unwrap_or(
      entry.source_ref.unwrap_or(@core.empty_source_ref()),
    ),
    entry,
    inner_path=None,
  )
  let rewritten_children = block.children.map(child => {
    epub_rewrite_single_block(child, entry, rewrites, diagnostics)
  })
  let rewritten_inlines = match block.rich_inlines {
    Some(inlines) =>
      Some(inlines.map(inline => epub_rewrite_inline(inline, entry, rewrites)))
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
    match epub_find_asset_rewrite(rewrites, old_asset_id, old_path) {
      Some(rewrite) => {
        next_block.attrs.set("path", rewrite.new_path)
        next_block.attrs.set("asset_id", rewrite.new_asset_id)
      }
      None => {
        let trimmed_old_path = old_path.trim().to_owned()
        if !epub_block_is_remote_image(block) &&
          epub_path_looks_local_candidate(trimmed_old_path) {
          match
            epub_resolve_asset_entry_path(entry.entry_path, trimmed_old_path) {
            Some(_) =>
              diagnostics.warnings.push(
                "epub local image asset could not be materialized for entry `" +
                entry.entry_path +
                "`",
              )
            None =>
              diagnostics.warnings.push(
                "epub asset path rejected for entry `" +
                entry.entry_path +
                "`: " +
                trimmed_old_path,
              )
          }
          let alt = block.attrs.get("alt").unwrap_or("image")
          return @core.make_block(@core.BlockKind::Paragraph, alt, source_ref~)
        }
      }
    }
  }
  next_block
}

///|
fn epub_rewrite_inline(
  inline : @core.CoreInline,
  entry : @core.ContainerEntry,
  rewrites : Array[EpubAssetRewrite],
) -> @core.CoreInline {
  let source_ref = epub_rewrite_source_ref(
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
  match epub_find_asset_rewrite(rewrites, "", old_path) {
    Some(rewrite) =>
      { ..inline, href: Some(rewrite.new_path), source_ref: Some(source_ref) }
    None => { ..inline, source_ref: Some(source_ref) }
  }
}

///|
fn epub_find_asset_rewrite(
  rewrites : Array[EpubAssetRewrite],
  old_asset_id : String,
  old_path : String,
) -> EpubAssetRewrite? {
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
fn epub_rewrite_source_ref(
  source_ref : @core.SourceRef,
  entry : @core.ContainerEntry,
  inner_path? : String? = None,
) -> @core.SourceRef {
  let resolved_inner_path = match inner_path {
    Some(value) => Some(value)
    None => epub_inner_path(source_ref)
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
fn epub_inner_path(source_ref : @core.SourceRef) -> String? {
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
fn epub_asset_is_remote(asset : @core.AssetRef) -> Bool {
  let path = asset.path.unwrap_or("").trim().to_owned().to_lower()
  path.has_prefix("http://") || path.has_prefix("https://")
}

///|
fn epub_block_is_remote_image(block : @core.CoreBlock) -> Bool {
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
fn epub_path_looks_local_candidate(path : String) -> Bool {
  if path == "" {
    return false
  }
  let lower = path.to_lower()
  !lower.has_prefix("http://") &&
  !lower.has_prefix("https://") &&
  !lower.has_prefix("data:")
}

///|
fn epub_resolve_asset_entry_path(
  entry_path : String,
  source_path : String,
) -> String? {
  let src = source_path.trim().to_owned()
  if src == "" {
    return None
  }
  let lower = src.to_lower()
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") ||
    lower.has_prefix("data:") ||
    src.contains("\\") ||
    src.has_prefix("/") {
    return None
  }
  if src.length() >= 2 && src[1] == ':' {
    return None
  }
  let stack : Array[String] = []
  let base_dir = epub_dirname(entry_path)
  if base_dir != "" {
    for segv in base_dir.split("/") {
      let seg = segv.trim().to_owned()
      if seg != "" {
        stack.push(seg)
      }
    }
  }
  for segv in src.split("/") {
    let seg = segv.trim().to_owned()
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if stack.length() == 0 {
        return None
      }
      ignore(stack.pop())
      continue
    }
    stack.push(seg)
  }
  if stack.length() == 0 {
    None
  } else {
    Some(stack.join("/"))
  }
}

///|
fn epub_asset_output_path(
  entry_path : String,
  child_asset_path : String,
) -> String {
  "assets/archive/" +
  epub_entry_id(entry_path) +
  "/" +
  epub_basename(child_asset_path.trim().to_owned())
}

///|
fn epub_entry_id(entry_path : String) -> String {
  entry_path
  .replace(old="\\", new="/")
  .split("/")
  .to_array()
  .map(part => part.replace(old=" ", new="_"))
  .join("_")
}

///|
fn epub_basename(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  parts.last().unwrap_or(normalized).to_owned()
}

///|
fn epub_dirname(path : String) -> String {
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
fn epub_entry_source_ref(
  container_path : String,
  entry_path : String,
  entry_index : Int,
  media_type : String?,
) -> @core.SourceRef {
  @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(container_path),
    Some("epub"),
    Some(container_path),
    Some(entry_path),
    Some(entry_index),
    Some(
      media_type
      .map(fn(value) {
        if value.contains("html") || value.contains("xhtml") {
          "html"
        } else {
          "binary"
        }
      })
      .unwrap_or("html"),
    ),
    None,
  )
}

///|
fn epub_entry_heading_block(
  source_ref : @core.SourceRef,
  text : String,
) -> @core.CoreBlock {
  let heading = @core.make_block(@core.BlockKind::Heading, text, source_ref~)
  heading.attrs.set("level", "1")
  heading.attrs.set("literal", "true")
  heading
}

///|
fn epub_skip_block(
  source_ref : @core.SourceRef,
  text : String,
) -> @core.CoreBlock {
  let block = @core.make_block(@core.BlockKind::BlockQuote, text, source_ref~)
  block.attrs.set("literal", "true")
  block
}

///|
fn epub_container_path(source : @input.InputSource) -> String {
  match source.path {
    Some(path) => {
      let parts = path.replace(old="\\", new="/").split("/").to_array()
      parts.last().unwrap_or(source.source_name).to_owned()
    }
    None => source.source_name
  }
}

///|
fn epub_inner_source_name(
  container_path : String,
  entry_path : String,
) -> String {
  container_path + "::" + entry_path
}

///|
fn epub_entry_info_index(
  infos : Array[@depub.EpubArchiveEntry],
) -> Map[String, @depub.EpubArchiveEntry] {
  let out : Map[String, @depub.EpubArchiveEntry] = Map([])
  for info in infos {
    if !out.contains(info.path) {
      out.set(info.path, info)
    }
  }
  out
}

///|
fn epub_spine_item_supported(item : @depub.EpubSpineItem) -> Bool {
  match item.manifest_item {
    Some(manifest_item) =>
      match manifest_item.media_type {
        Some(v) => {
          let media_type = v.trim().to_owned().to_lower()
          if media_type == "application/xhtml+xml" || media_type == "text/html" {
            return true
          }
          match item.resolved_path {
            Some(path) => {
              let lower = path.to_lower()
              lower.has_suffix(".xhtml") ||
              lower.has_suffix(".html") ||
              lower.has_suffix(".htm")
            }
            None => false
          }
        }
        None =>
          match item.resolved_path {
            Some(path) => {
              let lower = path.to_lower()
              lower.has_suffix(".xhtml") ||
              lower.has_suffix(".html") ||
              lower.has_suffix(".htm")
            }
            None => false
          }
      }
    None => false
  }
}

///|
fn epub_is_external_href(href : String) -> Bool {
  let lower = href.trim().to_owned().to_lower()
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("//") ||
  lower.has_prefix("data:")
}

///|
fn epub_image_ext(path : String) -> String {
  let lower = path.to_lower()
  if lower.has_suffix(".png") {
    return "png"
  }
  if lower.has_suffix(".jpg") {
    return "jpg"
  }
  if lower.has_suffix(".jpeg") {
    return "jpeg"
  }
  if lower.has_suffix(".gif") {
    return "gif"
  }
  if lower.has_suffix(".webp") {
    return "webp"
  }
  if lower.has_suffix(".svg") {
    return "svg"
  }
  "img"
}

///|
fn epub_entry_media_type(path : String) -> String? {
  let lower = path.to_lower()
  if lower.has_suffix(".png") {
    Some("image/png")
  } else if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    Some("image/jpeg")
  } else if lower.has_suffix(".gif") {
    Some("image/gif")
  } else if lower.has_suffix(".webp") {
    Some("image/webp")
  } else if lower.has_suffix(".svg") {
    Some("image/svg+xml")
  } else {
    None
  }
}

///|
fn bool_to_int_string(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}
