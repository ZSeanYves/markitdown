///|
fn profiled_document(
  document : @core.DocumentIR,
  context : RenderContext,
) -> @core.DocumentIR {
  let blocks = profiled_blocks(document.blocks, context)
  { ..document, blocks, }
}

///|
fn profiled_blocks(
  blocks : Array[@core.CoreBlock],
  context : RenderContext,
) -> Array[@core.CoreBlock] {
  match context.render_profile {
    @product.RenderProfile::SectionFlushMarkdown => section_flush_blocks(blocks)
    @product.RenderProfile::SparseTableMarkdown =>
      sparse_table_profile_blocks(blocks)
    @product.RenderProfile::NotesAppendixFirst =>
      notes_appendix_first_blocks(blocks)
    @product.RenderProfile::AssetManifestFirst =>
      asset_manifest_first_blocks(blocks, context)
    @product.RenderProfile::PageWindowMarkdown => page_window_blocks(blocks)
    _ => blocks
  }
}

///|
fn profiled_events(
  events : Array[@core.CoreEvent],
  context : RenderContext,
) -> Array[@core.CoreEvent] {
  ignore(context)
  events
}

///|
fn section_flush_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  flush_grouped_blocks(blocks, fn(block) {
    block.attrs
    .get("render_boundary_key")
    .unwrap_or(block.attrs.get("render_boundary").unwrap_or(""))
  })
}

///|
fn sparse_table_profile_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let next : Array[@core.CoreBlock] = []
  for block in blocks {
    let child = sparse_table_profile_block(block)
    next.push(child)
  }
  next
}

///|
fn sparse_table_profile_block(block : @core.CoreBlock) -> @core.CoreBlock {
  let next_children = sparse_table_profile_blocks(block.children)
  let next = @core.block_with_children(block, next_children)
  if next.kind == @core.BlockKind::Table &&
    next.attrs.get("render_table_mode") == Some("sparse") {
    next.attrs.set("sparse_render_enabled", "true")
  }
  next
}

///|
fn notes_appendix_first_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let appendix : Array[@core.CoreBlock] = []
  let body : Array[@core.CoreBlock] = []
  for block in blocks {
    if notes_appendix_block(block) {
      appendix.push(block)
    } else {
      body.push(block)
    }
  }
  if appendix.length() == 0 {
    return blocks
  }
  appendix + body
}

///|
fn notes_appendix_block(block : @core.CoreBlock) -> Bool {
  if block.attrs.get("render_appendix_group") is Some(group) {
    return group == "notes" || group == "comments"
  }
  block.attrs.get("appendix_ready") == Some("true") ||
  block.attrs.get("appendix_kind") is Some(_) ||
  block.attrs.get("note_definition_id") is Some(_) ||
  block.attrs.get("notes_kind") is Some(_)
}

///|
fn asset_manifest_first_blocks(
  blocks : Array[@core.CoreBlock],
  context : RenderContext,
) -> Array[@core.CoreBlock] {
  let assets = context.assets.unwrap_or([])
  if assets.length() == 0 {
    return blocks
  }
  let manifest_heading = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Heading, "Assets"),
    "level",
    "2",
  )
  manifest_heading.attrs.set("appendix_kind", "assets")
  let manifest_items : Array[@core.CoreBlock] = []
  for asset in assets {
    let suffix = match asset.path {
      Some(path) => ": " + path
      None => ""
    }
    let label = "- " + asset.asset_id + suffix
    let item = @core.make_block(@core.BlockKind::ListItem, label)
    item.attrs.set("appendix_kind", "assets")
    manifest_items.push(item)
  }
  let out : Array[@core.CoreBlock] = [manifest_heading]
  out.append(manifest_items[:])
  out.append(blocks[:])
  out
}

///|
fn page_window_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  flush_grouped_blocks(blocks, fn(block) {
    block.attrs.get("render_window_group").unwrap_or("")
  })
}

///|
fn flush_grouped_blocks(
  blocks : Array[@core.CoreBlock],
  group_key : (@core.CoreBlock) -> String,
) -> Array[@core.CoreBlock] {
  let next : Array[@core.CoreBlock] = []
  let mut pending_group = ""
  let mut wrote_group = false
  for block in blocks {
    let current_group = group_key(block)
    if wrote_group && current_group != "" && current_group != pending_group {
      next.push(render_profile_spacer_block())
    }
    next.push(block)
    if current_group != "" {
      pending_group = current_group
      wrote_group = true
    }
  }
  next
}

///|
fn render_profile_spacer_block() -> @core.CoreBlock {
  @core.block_with_attr(
    @core.make_block(@core.BlockKind::Raw, ""),
    "raw_kind",
    "markdown_literal",
  )
}
