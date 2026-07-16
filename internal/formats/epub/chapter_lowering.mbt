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
fn epub_package_metadata(pkg : @depub.EpubPackage) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  match pkg.metadata.title {
    Some(value) => metadata.set("title", String(value))
    None => ()
  }
  match pkg.metadata.creator {
    Some(value) => metadata.set("creator", String(value))
    None => ()
  }
  match pkg.metadata.subject {
    Some(value) => metadata.set("subject", String(value))
    None => ()
  }
  match pkg.metadata.publisher {
    Some(value) => metadata.set("publisher", String(value))
    None => ()
  }
  match pkg.metadata.language {
    Some(value) => metadata.set("language", String(value))
    None => ()
  }
  match pkg.metadata.identifier {
    Some(value) => metadata.set("identifier", String(value))
    None => ()
  }
  match pkg.metadata.date {
    Some(value) => metadata.set("created", String(value))
    None => ()
  }
  match pkg.metadata.modified {
    Some(value) => metadata.set("modified", String(value))
    None => ()
  }
  metadata
}

///|
fn epub_issue_tallies(issues : Array[@depub.EpubValidationIssue]) -> (Int, Int) {
  let mut missing_manifest = 0
  let mut missing_spine = 0
  for issue in issues {
    match issue.kind {
      MissingManifestItem => missing_manifest += 1
      MissingSpineTarget => missing_spine += 1
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
    Heading,
    "Table of Contents",
    source_ref=nav_source_ref,
  )
  heading.attrs.set("level", "1")
  blocks.push(heading)
  let list = @core.make_block(List, "", source_ref=nav_source_ref)
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
    let mut item = @core.make_block(ListItem, point.label, source_ref=item_ref)
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
  diagnostics : @core.Diagnostics,
) -> Unit {
  let cover_item = match pkg.cover_item {
    Some(value) => value
    None => return
  }
  let cover_path = cover_item.resolved_path
  match asset_entry_infos.get(cover_path) {
    Some(_) => {
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
        Image,
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
      let image = @core.make_block(Image, "", source_ref~)
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
        Unsupported
      }
    None =>
      match spine_item.manifest_item {
        Some(item) =>
          if epub_is_external_href(item.href) {
            Unsupported
          } else {
            Unsupported
          }
        None => Unsafe
      }
  }
  let security_findings : Array[@core.ContainerSecurityFinding] = []
  match spine_item.manifest_item {
    Some(item) =>
      if epub_is_external_href(item.href) {
        security_findings.push(ExternalReference)
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
) -> Result[@runtime.ChildBlockProduct, String] {
  @runtime.parse_child_to_block_product(registry, source, format, context)
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
  let child_fast_markup = child.metrics.get("child_parse_preference") ==
    Some("prefer_block_stream_text_markup") &&
    child.metrics.get("child_parse_fast_path_used") == Some("true")
  if child_fast_markup {
    epub_absorb_child_metric(diagnostics, child, "child_parse_preference")
    epub_absorb_child_metric(diagnostics, child, "child_parse_preferred_format")
    epub_absorb_child_metric(diagnostics, child, "child_parse_fast_path_used")
    epub_absorb_child_metric(
      diagnostics, child, "child_parse_predecoded_text_used",
    )
  }
}

///|
fn epub_absorb_child_metric(
  diagnostics : @core.Diagnostics,
  child : @core.Diagnostics,
  key : String,
) -> Unit {
  match child.metrics.get(key) {
    Some(value) => diagnostics.metrics.set(key, value)
    None => ()
  }
}

///|
fn epub_rewrite_child_assets(
  assets : Array[@core.AssetRef],
  entry : @core.ContainerEntry,
  asset_entry_infos : Map[String, @depub.EpubArchiveEntry],
  merged_assets : Array[@core.AssetRef],
  diagnostics : @core.Diagnostics,
) -> Array[EpubAssetRewrite] {
  let rewrite_plan = epub_rewrite_plan(entry, [])
  let rewrites : Array[EpubAssetRewrite] = []
  let entry_path = entry.entry_path
  for asset in assets {
    let old_path = asset.path.unwrap_or("").trim().to_owned()
    let old_asset_id = asset.asset_id
    let source_path = match asset.payload {
      Some(SourcePath(path)) => Some(path)
      _ => asset.attrs.get("source_path")
    }
    match source_path {
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
          Some(_) => {
            let output_relative_path = epub_asset_output_path(
              entry_path, old_path,
            )
            let new_asset_id = "epub:" + entry_path + ":" + old_asset_id
            let next_source_ref = epub_rewrite_source_ref(
              asset.source_ref.unwrap_or(
                entry.source_ref.unwrap_or(@core.empty_source_ref()),
              ),
              rewrite_plan,
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
            rewrite_plan,
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
  let plan = epub_rewrite_plan(entry, rewrites)
  let rewritten : Array[@core.CoreBlock] = []
  for block in blocks {
    rewritten.push(epub_rewrite_single_block(block, plan, diagnostics))
  }
  rewritten
}

///|
priv struct EpubRewritePlan {
  entry_path : String
  entry_index : Int?
  entry_format : String?
  container_path : String?
  fallback_source_ref : @core.SourceRef
  rewrite_by_asset_id : Map[String, EpubAssetRewrite]
  rewrite_by_path : Map[String, EpubAssetRewrite]
}

///|
fn epub_rewrite_plan(
  entry : @core.ContainerEntry,
  rewrites : Array[EpubAssetRewrite],
) -> EpubRewritePlan {
  let fallback_source_ref = entry.source_ref.unwrap_or(@core.empty_source_ref())
  let rewrite_by_asset_id : Map[String, EpubAssetRewrite] = Map([])
  let rewrite_by_path : Map[String, EpubAssetRewrite] = Map([])
  for rewrite in rewrites {
    if rewrite.old_asset_id != "" &&
      !rewrite_by_asset_id.contains(rewrite.old_asset_id) {
      rewrite_by_asset_id.set(rewrite.old_asset_id, rewrite)
    }
    if rewrite.old_path != "" && !rewrite_by_path.contains(rewrite.old_path) {
      rewrite_by_path.set(rewrite.old_path, rewrite)
    }
  }
  {
    entry_path: entry.entry_path,
    entry_index: entry.entry_index,
    entry_format: entry.detected_format,
    container_path: fallback_source_ref.container_path,
    fallback_source_ref,
    rewrite_by_asset_id,
    rewrite_by_path,
  }
}

///|
fn epub_rewrite_single_block(
  block : @core.CoreBlock,
  plan : EpubRewritePlan,
  diagnostics : @core.Diagnostics,
) -> @core.CoreBlock {
  let source_ref = epub_rewrite_source_ref(
    block.source_ref.unwrap_or(plan.fallback_source_ref),
    plan,
    inner_path=None,
  )
  if block.children.length() == 0 &&
    block.rich_inlines is None &&
    block.kind != Image {
    return { ..block, source_ref: Some(source_ref) }
  }
  let rewritten_children = if block.children.length() == 0 {
    block.children
  } else {
    let children : Array[@core.CoreBlock] = []
    for child in block.children {
      children.push(epub_rewrite_single_block(child, plan, diagnostics))
    }
    children
  }
  let rewritten_inlines = match block.rich_inlines {
    Some(inlines) =>
      if inlines.length() == 0 {
        Some(inlines)
      } else {
        let rewritten : Array[@core.CoreInline] = []
        for inline in inlines {
          rewritten.push(epub_rewrite_inline(inline, plan))
        }
        Some(rewritten)
      }
    None => None
  }
  let next_block = {
    ..block,
    children: rewritten_children,
    rich_inlines: rewritten_inlines,
    source_ref: Some(source_ref),
  }
  if block.kind == Image {
    let old_path = block.attrs.get("path").unwrap_or("")
    let old_asset_id = block.attrs.get("asset_id").unwrap_or("")
    match epub_find_asset_rewrite(plan, old_asset_id, old_path) {
      Some(rewrite) => {
        next_block.attrs.set("path", rewrite.new_path)
        next_block.attrs.set("asset_id", rewrite.new_asset_id)
      }
      None => {
        let trimmed_old_path = old_path.trim().to_owned()
        if !epub_block_is_remote_image(block) &&
          epub_path_looks_local_candidate(trimmed_old_path) {
          match
            epub_resolve_asset_entry_path(plan.entry_path, trimmed_old_path) {
            Some(_) =>
              diagnostics.warnings.push(
                "epub local image asset could not be materialized for entry `" +
                plan.entry_path +
                "`",
              )
            None =>
              diagnostics.warnings.push(
                "epub asset path rejected for entry `" +
                plan.entry_path +
                "`: " +
                trimmed_old_path,
              )
          }
          let alt = block.attrs.get("alt").unwrap_or("image")
          return @core.make_block(Paragraph, alt, source_ref~)
        }
      }
    }
  }
  next_block
}

///|
fn epub_rewrite_inline(
  inline : @core.CoreInline,
  plan : EpubRewritePlan,
) -> @core.CoreInline {
  let source_ref = epub_rewrite_source_ref(
    inline.source_ref.unwrap_or(plan.fallback_source_ref),
    plan,
    inner_path=None,
  )
  if inline.kind != Image {
    return { ..inline, source_ref: Some(source_ref) }
  }
  let old_path = inline.href.unwrap_or("")
  match epub_find_asset_rewrite(plan, "", old_path) {
    Some(rewrite) =>
      { ..inline, href: Some(rewrite.new_path), source_ref: Some(source_ref) }
    None => { ..inline, source_ref: Some(source_ref) }
  }
}

///|
fn epub_find_asset_rewrite(
  plan : EpubRewritePlan,
  old_asset_id : String,
  old_path : String,
) -> EpubAssetRewrite? {
  if old_asset_id != "" {
    match plan.rewrite_by_asset_id.get(old_asset_id) {
      Some(rewrite) => return Some(rewrite)
      None => ()
    }
  }
  if old_path != "" {
    match plan.rewrite_by_path.get(old_path) {
      Some(rewrite) => return Some(rewrite)
      None => ()
    }
  }
  None
}

///|
fn epub_rewrite_source_ref(
  source_ref : @core.SourceRef,
  plan : EpubRewritePlan,
  inner_path? : String? = None,
) -> @core.SourceRef {
  let resolved_inner_path = match inner_path {
    Some(value) => Some(value)
    None => epub_inner_path(source_ref)
  }
  {
    ..source_ref,
    file_id: source_ref.file_id,
    format: source_ref.format,
    container_path: plan.container_path,
    entry_path: Some(plan.entry_path),
    entry_index: plan.entry_index,
    entry_format: plan.entry_format,
    inner_path: resolved_inner_path,
  }
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
  let heading = @core.make_block(Heading, text, source_ref~)
  heading.attrs.set("level", "1")
  heading.attrs.set("literal", "true")
  heading
}

///|
fn epub_skip_block(
  source_ref : @core.SourceRef,
  text : String,
) -> @core.CoreBlock {
  let block = @core.make_block(BlockQuote, text, source_ref~)
  block.attrs.set("literal", "true")
  block
}

///|
fn epub_container_path(source : @input.InputSource) -> String {
  match @input.input_path(source) {
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
fn epub_inner_source(
  container_path : String,
  entry_path : String,
  detected_format : @input.DetectedFormat,
  entry_bytes : Bytes,
) -> @input.InputSource {
  let source_name = epub_inner_source_name(container_path, entry_path)
  if epub_child_prefers_text_source(detected_format) {
    match
      (try @utf8.decode(entry_bytes, ignore_bom=false) |> Ok catch {
        _ => Err(())
      }) {
      Ok(text) =>
        @input.with_bytes_payload(
          @input.input_from_text_with_format(
            text,
            source_name,
            Some(detected_format),
          ),
          entry_bytes,
        )
      Err(_) =>
        @input.input_from_bytes_with_format(
          entry_bytes,
          source_name,
          Some(detected_format),
        )
    }
  } else {
    @input.input_from_bytes_with_format(
      entry_bytes,
      source_name,
      Some(detected_format),
    )
  }
}

///|
fn epub_child_prefers_text_source(
  detected_format : @input.DetectedFormat,
) -> Bool {
  match detected_format {
    Html => true
    Markdown => true
    _ => false
  }
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
fn bool_to_int_string(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}
