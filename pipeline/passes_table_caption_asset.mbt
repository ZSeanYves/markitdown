///|
pub fn resolve_table_pass() -> IRPass {
  {
    name: "ResolveTablePass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_table_input(context, input))
    },
  }
}

///|
pub fn resolve_caption_pass() -> IRPass {
  {
    name: "ResolveCaptionPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_caption_input(context, input))
    },
  }
}

///|
pub fn resolve_asset_pass() -> IRPass {
  {
    name: "ResolveAssetPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_asset_input(context, input))
    },
  }
}

///|
pub fn collect_asset_refs_pass() -> IRPass {
  {
    name: "CollectAssetRefsPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(collect_asset_refs_input(context, input))
    },
  }
}

///|
fn table_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  table_resolved_assembly_from_blocks(document.blocks, assembly)
}

///|
fn table_resolved_assembly_from_blocks(
  blocks : Array[@core.CoreBlock],
  prior : @core.DocumentAssembly,
) -> @core.DocumentAssembly {
  let entries : Array[(@core.CoreBlock, Array[String])] = []
  collect_table_blocks_with_heading_paths(
    blocks,
    [],
    prior.heading_paths,
    entries,
  )
  let continuations : Array[@core.TableContinuation] = []
  for i in 1..<entries.length() {
    let current = entries[i].0
    let prev = entries[i - 1].0
    if tables_look_continued(prev, current, entries[i - 1].1, entries[i].1) {
      continuations.push({
        table_block_id: current.block_id,
        continues_from_block_id: Some(prev.block_id),
        relation: "adjacent_same_logical_table",
        confidence: Some(70),
      })
    }
  }
  { ..prior, table_continuations: continuations }
}

///|
fn caption_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  caption_resolved_assembly_from_blocks(document.blocks, assembly)
}

///|
fn caption_resolved_assembly_from_blocks(
  blocks : Array[@core.CoreBlock],
  prior : @core.DocumentAssembly,
) -> @core.DocumentAssembly {
  let bindings : Array[@core.CaptionBinding] = []
  collect_caption_bindings(blocks, bindings)
  { ..prior, caption_bindings: bindings }
}

///|
fn asset_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  asset_resolved_assembly_from_blocks(
    document.blocks,
    document.assets,
    assembly,
  )
}

///|
fn asset_resolved_assembly_from_blocks(
  blocks : Array[@core.CoreBlock],
  assets : Array[@core.AssetRef],
  prior : @core.DocumentAssembly,
) -> @core.DocumentAssembly {
  let bindings : Array[@core.AssetBinding] = []
  let index = build_asset_binding_index(assets)
  collect_asset_bindings(blocks, index, bindings)
  { ..prior, asset_bindings: bindings }
}

///|
fn document_assembly_or_empty(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  match document.assembly {
    Some(assembly) => assembly
    None => @core.empty_document_assembly()
  }
}

///|
fn collect_table_blocks_with_heading_paths(
  blocks : Array[@core.CoreBlock],
  current_heading_path : Array[String],
  heading_paths : Map[String, Array[String]],
  out : Array[(@core.CoreBlock, Array[String])],
) -> Unit {
  let mut heading_path = current_heading_path
  for block in blocks {
    let block_heading = match heading_paths.get(block.block_id) {
      Some(path) => path
      None =>
        if block.kind == @core.BlockKind::Heading {
          update_heading_path_local(heading_path, block)
        } else {
          heading_path
        }
    }
    if block.kind == @core.BlockKind::Table {
      out.push((block, block_heading))
    }
    if block.children.length() > 0 {
      collect_table_blocks_with_heading_paths(
        block.children,
        block_heading,
        heading_paths,
        out,
      )
    }
    heading_path = block_heading
  }
}

///|
fn update_heading_path_local(
  current : Array[String],
  block : @core.CoreBlock,
) -> Array[String] {
  let next = current.copy()
  let level = clamp_heading_level(block.attrs.get("level").unwrap_or("1"))
  while next.length() >= level {
    ignore(next.pop())
  }
  next.push(block.text)
  next
}

///|
fn tables_look_continued(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
  left_heading_path : Array[String],
  right_heading_path : Array[String],
) -> Bool {
  if !string_arrays_eq_local(left_heading_path, right_heading_path) {
    return false
  }
  if table_column_count(left) != table_column_count(right) {
    return false
  }
  if left.attrs.get("header_rows").unwrap_or("0") !=
    right.attrs.get("header_rows").unwrap_or("0") {
    return false
  }
  let left_ref = @core.block_source_ref(left).unwrap_or(
    @core.empty_source_ref(),
  )
  let right_ref = @core.block_source_ref(right).unwrap_or(
    @core.empty_source_ref(),
  )
  table_location_bucket(left_ref) == table_location_bucket(right_ref) &&
  left.block_id != right.block_id
}

///|
fn table_column_count(block : @core.CoreBlock) -> Int {
  match block.attrs.get("table_column_count") {
    Some(value) =>
      @string.parse_int(value.trim()) catch {
        _ => inferred_table_column_count(block)
      }
    None => inferred_table_column_count(block)
  }
}

///|
fn inferred_table_column_count(block : @core.CoreBlock) -> Int {
  let mut width = 0
  for row in block.children {
    if row.children.length() > width {
      width = row.children.length()
    }
  }
  width
}

///|
fn table_location_bucket(source_ref : @core.SourceRef) -> String {
  [
    source_ref.file_id.unwrap_or(""),
    source_ref.format.unwrap_or(""),
    source_ref.container_path.unwrap_or(""),
    source_ref.entry_path.unwrap_or(""),
    source_ref.inner_path.unwrap_or(""),
    source_ref.sheet.unwrap_or(""),
    source_ref.page.map(i => i.to_string()).unwrap_or(""),
    source_ref.slide.map(i => i.to_string()).unwrap_or(""),
  ].join("|")
}

///|
fn collect_caption_bindings(
  blocks : Array[@core.CoreBlock],
  bindings : Array[@core.CaptionBinding],
) -> Unit {
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    if block.kind == @core.BlockKind::Image &&
      caption_text_for_block(block) != "" {
      let caption_id = block_caption_block_id(block)
      bindings.push({
        caption_block_id: caption_id,
        target_block_id: block.block_id,
        relation: "embedded_caption_attr",
        confidence: Some(95),
      })
    }
    if block.kind == @core.BlockKind::Table && i + 1 < blocks.length() {
      let next = blocks[i + 1]
      if paragraph_looks_like_caption(next) {
        bindings.push({
          caption_block_id: next.block_id,
          target_block_id: block.block_id,
          relation: "adjacent_caption_paragraph",
          confidence: Some(70),
        })
      }
    }
    if block.children.length() > 0 {
      collect_caption_bindings(block.children, bindings)
    }
    i += 1
  }
}

///|
priv struct AssetBindingIndex {
  assets_by_id : Map[String, Array[@core.AssetRef]]
  assets_by_path : Map[String, Array[@core.AssetRef]]
  assets_by_source_path : Map[String, Array[@core.AssetRef]]
  assets_by_source_ref_key : Map[String, Array[@core.AssetRef]]
}

///|
fn build_asset_binding_index(
  assets : Array[@core.AssetRef],
) -> AssetBindingIndex {
  let assets_by_id : Map[String, Array[@core.AssetRef]] = Map([])
  let assets_by_path : Map[String, Array[@core.AssetRef]] = Map([])
  let assets_by_source_path : Map[String, Array[@core.AssetRef]] = Map([])
  let assets_by_source_ref_key : Map[String, Array[@core.AssetRef]] = Map([])
  for asset in assets {
    asset_binding_index_push(assets_by_id, asset.asset_id, asset)
    match asset.path {
      Some(path) if path != "" =>
        asset_binding_index_push(assets_by_path, path, asset)
      _ => ()
    }
    match asset.payload {
      Some(@core.AssetPayload::SourcePath(path)) if path != "" =>
        asset_binding_index_push(assets_by_source_path, path, asset)
      _ =>
        match asset.attrs.get("source_path") {
          Some(path) if path != "" =>
            asset_binding_index_push(assets_by_source_path, path, asset)
          _ => ()
        }
    }
    let source_ref_key = asset_source_ref_key(
      asset.source_ref.unwrap_or(@core.empty_source_ref()),
    )
    if source_ref_key != "" {
      asset_binding_index_push(assets_by_source_ref_key, source_ref_key, asset)
    }
  }
  {
    assets_by_id,
    assets_by_path,
    assets_by_source_path,
    assets_by_source_ref_key,
  }
}

///|
fn asset_binding_index_push(
  index : Map[String, Array[@core.AssetRef]],
  key : String,
  asset : @core.AssetRef,
) -> Unit {
  match index.get(key) {
    Some(existing) => existing.push(asset)
    None => index.set(key, [asset])
  }
}

///|
fn collect_asset_bindings(
  blocks : Array[@core.CoreBlock],
  index : AssetBindingIndex,
  bindings : Array[@core.AssetBinding],
) -> Unit {
  for block in blocks {
    for asset in block_owned_assets(block, index) {
      bindings.push({
        asset_id: asset.asset_id,
        owner_block_id: block.block_id,
        relation: asset_binding_relation(block, asset),
        confidence: Some(90),
      })
    }
    if block.children.length() > 0 {
      collect_asset_bindings(block.children, index, bindings)
    }
  }
}

///|
fn block_owned_assets(
  block : @core.CoreBlock,
  index : AssetBindingIndex,
) -> Array[@core.AssetRef] {
  let matched : Array[@core.AssetRef] = []
  let seen : Array[String] = []
  match block.attrs.get("asset_id") {
    Some(asset_id) =>
      collect_asset_binding_candidates(
        matched,
        seen,
        index.assets_by_id.get(asset_id),
      )
    _ => ()
  }
  match block.attrs.get("path") {
    Some(path) =>
      collect_asset_binding_candidates(
        matched,
        seen,
        index.assets_by_path.get(path),
      )
    _ => ()
  }
  match block.attrs.get("source_path") {
    Some(path) =>
      collect_asset_binding_candidates(
        matched,
        seen,
        index.assets_by_source_path.get(path),
      )
    _ => ()
  }
  let block_ref = @core.block_source_ref(block).unwrap_or(
    @core.empty_source_ref(),
  )
  let source_ref_key = asset_source_ref_key(block_ref)
  if source_ref_key != "" {
    collect_asset_binding_candidates(
      matched,
      seen,
      index.assets_by_source_ref_key.get(source_ref_key),
    )
  }
  matched
}

///|
fn collect_asset_binding_candidates(
  out : Array[@core.AssetRef],
  seen : Array[String],
  candidates : Array[@core.AssetRef]?,
) -> Unit {
  match candidates {
    Some(items) =>
      for asset in items {
        if !seen.contains(asset.asset_id) {
          seen.push(asset.asset_id)
          out.push(asset)
        }
      }
    None => ()
  }
}

///|
fn asset_binding_relation(
  block : @core.CoreBlock,
  _asset : @core.AssetRef,
) -> String {
  if block.kind == @core.BlockKind::Image {
    "rendered_image_block"
  } else {
    "source_ref_related_asset"
  }
}

///|
fn asset_source_ref_key(source_ref : @core.SourceRef) -> String {
  let parts : Array[String] = []
  if !asset_source_ref_is_specific(source_ref) {
    return ""
  }
  asset_source_ref_key_push(parts, source_ref.file_id)
  asset_source_ref_key_push(parts, source_ref.format)
  asset_source_ref_key_push(parts, source_ref.xpath)
  asset_source_ref_key_push(parts, source_ref.json_pointer)
  asset_source_ref_key_push(parts, source_ref.yaml_path)
  asset_source_ref_key_push(parts, source_ref.html_path)
  asset_source_ref_key_push(parts, source_ref.markdown_path)
  asset_source_ref_key_push(parts, source_ref.container_path)
  asset_source_ref_key_push(parts, source_ref.entry_path)
  asset_source_ref_key_push(parts, source_ref.inner_path)
  asset_source_ref_key_push(parts, source_ref.sheet)
  asset_source_ref_key_push(parts, source_ref.slide.map(v => v.to_string()))
  asset_source_ref_key_push(parts, source_ref.page.map(v => v.to_string()))
  asset_source_ref_key_push(parts, source_ref.relationship_id)
  asset_source_ref_key_push(parts, source_ref.chapter_href)
  if parts.length() == 0 {
    ""
  } else {
    parts.join("\u001f")
  }
}

///|
fn asset_source_ref_is_specific(source_ref : @core.SourceRef) -> Bool {
  source_ref.json_pointer is Some(_) ||
  source_ref.markdown_path is Some(_) ||
  source_ref.html_path is Some(_) ||
  source_ref.yaml_path is Some(_) ||
  source_ref.xpath is Some(_) ||
  source_ref.chapter_href is Some(_) ||
  source_ref.relationship_id is Some(_) ||
  source_ref.inner_path is Some(_) ||
  source_ref.entry_path is Some(_) ||
  source_ref.sheet is Some(_) ||
  source_ref.slide is Some(_) ||
  source_ref.page is Some(_)
}

///|
fn asset_source_ref_key_push(parts : Array[String], value : String?) -> Unit {
  match value {
    Some(item) => parts.push(item)
    None => parts.push("")
  }
}

///|
fn paragraph_looks_like_caption(block : @core.CoreBlock) -> Bool {
  if block.kind != @core.BlockKind::Paragraph {
    return false
  }
  let text = block.text.trim().to_lower()
  text.has_prefix("figure") ||
  text.has_prefix("fig.") ||
  text.has_prefix("caption") ||
  text.has_prefix("table")
}

///|
fn caption_text_for_block(block : @core.CoreBlock) -> String {
  for key in ["caption", "alt", "title"] {
    match block.attrs.get(key) {
      Some(value) if value.trim() != "" => return value.trim().to_owned()
      _ => ()
    }
  }
  ""
}

///|
fn block_caption_block_id(block : @core.CoreBlock) -> String {
  match block.attrs.get("caption_block_id") {
    Some(block_id) if block_id.trim() != "" => block_id
    _ => block.block_id + ":caption"
  }
}

///|
fn string_arrays_eq_local(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
pub fn collect_document_asset_refs(
  blocks : Array[@core.CoreBlock],
  existing_assets : Array[@core.AssetRef],
) -> Array[@core.AssetRef] {
  let assets : Array[@core.AssetRef] = []
  assets.append(existing_assets[:])
  collect_block_asset_refs(blocks, assets)
  assets
}

///|
fn collect_block_asset_refs(
  blocks : Array[@core.CoreBlock],
  assets : Array[@core.AssetRef],
) -> Unit {
  for block in blocks {
    collect_single_block_asset_ref(block, assets)
    if block.children.length() > 0 {
      collect_block_asset_refs(block.children, assets)
    }
  }
}

///|
fn collect_single_block_asset_ref(
  block : @core.CoreBlock,
  assets : Array[@core.AssetRef],
) -> Unit {
  if block.kind == @core.BlockKind::Image {
    let alt = block.attrs.get("alt").unwrap_or("image")
    collect_image_asset_ref(
      assets,
      @core.block_source_ref(block).unwrap_or(@core.empty_source_ref()),
      block.attrs.get("path").unwrap_or("").trim().to_owned(),
      block.attrs.get("asset_id"),
      alt,
      block.attrs.get("source_path"),
    )
  }
  match block.rich_inlines {
    Some(inlines) =>
      for inline in inlines {
        if inline.kind == @core.InlineKind::Image {
          collect_image_asset_ref(
            assets,
            inline.source_ref.unwrap_or(
              @core.block_source_ref(block).unwrap_or(@core.empty_source_ref()),
            ),
            inline.href.unwrap_or("").trim().to_owned(),
            inline.attrs.get("asset_id"),
            inline.text,
            inline.attrs.get("source_path"),
          )
        }
      }
    None => ()
  }
}

///|
fn collect_image_asset_ref(
  assets : Array[@core.AssetRef],
  source_ref : @core.SourceRef,
  path : String,
  asset_id_opt : String?,
  alt : String,
  source_path_opt : String?,
) -> Unit {
  if path == "" {
    return
  }
  let lowered_path = path.to_lower()
  if lowered_path.has_prefix("http://") ||
    lowered_path.has_prefix("https://") ||
    lowered_path.has_prefix("data:") {
    return
  }
  let asset_id = asset_id_opt.unwrap_or(
    "image-" + (assets.length() + 1).to_string(),
  )
  for existing in assets {
    if existing.asset_id == asset_id || existing.path == Some(path) {
      return
    }
  }
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = { ..asset, path: Some(path) }
  next_asset.attrs.set("alt", alt)
  match source_path_opt {
    Some(source_path) =>
      next_asset.payload = Some(@core.AssetPayload::SourcePath(source_path))
    None => ()
  }
  assets.push(next_asset)
}

///|
fn collect_asset_refs_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let assets = collect_document_asset_refs(document.blocks, document.assets)
      context.assets.val = assets
      let next = @core.document_with_assets(document, assets)
      next.diagnostics.metrics.set("asset_count", assets.length().to_string())
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let assets = collect_document_asset_refs(blocks, context.assets.val)
      context.assets.val = assets
      context.diagnostics.val.metrics.set(
        "asset_count",
        assets.length().to_string(),
      )
      @core.IRInput::BlockStream(blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn resolve_table_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let assembly = table_resolved_assembly(document)
      context.assembly.val = Some(assembly)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_table_continuation_count",
        assembly.table_continuations.length().to_string(),
      )
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let assembly = table_resolved_assembly_from_blocks(
        blocks,
        context.assembly.val.unwrap_or(@core.empty_document_assembly()),
      )
      context.assembly.val = Some(assembly)
      context.diagnostics.val.metrics.set(
        "resolved_table_continuation_count",
        assembly.table_continuations.length().to_string(),
      )
      @core.IRInput::BlockStream(blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn resolve_caption_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let assembly = caption_resolved_assembly(document)
      context.assembly.val = Some(assembly)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_caption_binding_count",
        assembly.caption_bindings.length().to_string(),
      )
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let assembly = caption_resolved_assembly_from_blocks(
        blocks,
        context.assembly.val.unwrap_or(@core.empty_document_assembly()),
      )
      context.assembly.val = Some(assembly)
      context.diagnostics.val.metrics.set(
        "resolved_caption_binding_count",
        assembly.caption_bindings.length().to_string(),
      )
      @core.IRInput::BlockStream(blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn resolve_asset_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let assembly = asset_resolved_assembly(document)
      context.assembly.val = Some(assembly)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_asset_binding_count",
        assembly.asset_bindings.length().to_string(),
      )
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let assembly = asset_resolved_assembly_from_blocks(
        blocks,
        context.assets.val,
        context.assembly.val.unwrap_or(@core.empty_document_assembly()),
      )
      context.assembly.val = Some(assembly)
      context.diagnostics.val.metrics.set(
        "resolved_asset_binding_count",
        assembly.asset_bindings.length().to_string(),
      )
      @core.IRInput::BlockStream(blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}
