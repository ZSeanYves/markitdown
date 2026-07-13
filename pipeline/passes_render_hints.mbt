///|
pub fn resolve_render_hints_pass() -> IRPass {
  {
    name: "ResolveRenderHintsPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_render_hints_input(context, input))
    },
  }
}

///|
fn resolve_render_hints_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let assembly = match document.assembly {
        Some(value) => value
        None => context.assembly.val.unwrap_or(@core.empty_document_assembly())
      }
      let blocks = apply_render_hints_to_blocks(
        document.blocks,
        assembly.heading_paths,
      )
      let next = @core.document_with_blocks(document, blocks)
      let next = @core.document_with_assembly(next, Some(assembly))
      next.diagnostics.metrics.set(
        "render_hint_block_count",
        blocks.length().to_string(),
      )
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) =>
      @core.IRInput::BlockStream(
        apply_render_hints_to_blocks(
          blocks,
          context.assembly.val.unwrap_or(@core.empty_document_assembly()).heading_paths,
        ),
      )
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn apply_render_hints_to_blocks(
  blocks : Array[@core.CoreBlock],
  heading_paths : Map[String, Array[String]],
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for block in blocks {
    out.push(apply_render_hints_to_block(block, heading_paths))
  }
  out
}

///|
fn apply_render_hints_to_block(
  block : @core.CoreBlock,
  heading_paths : Map[String, Array[String]],
) -> @core.CoreBlock {
  let next_children = apply_render_hints_to_blocks(
    block.children,
    heading_paths,
  )
  let next = @core.block_with_children(block, next_children)
  let next = apply_render_boundary_hint(next, heading_paths)
  let next = apply_render_appendix_hint(next)
  let next = apply_render_window_hint(next)
  apply_render_table_hint(next)
}

///|
fn apply_render_boundary_hint(
  block : @core.CoreBlock,
  heading_paths : Map[String, Array[String]],
) -> @core.CoreBlock {
  if block.kind == @core.BlockKind::Heading {
    let next = @core.block_with_attr(block, "render_boundary", "section")
    return @core.block_with_attr(next, "render_boundary_key", block.block_id)
  }
  match heading_paths.get(block.block_id) {
    Some(path) =>
      if path.length() > 0 {
        let next = @core.block_with_attr(block, "render_boundary", "section")
        @core.block_with_attr(next, "render_boundary_key", path.join(" > "))
      } else {
        block
      }
    None => block
  }
}

///|
fn apply_render_appendix_hint(block : @core.CoreBlock) -> @core.CoreBlock {
  match block.attrs.get("appendix_kind") {
    Some(kind) => @core.block_with_attr(block, "render_appendix_group", kind)
    None =>
      if block.attrs.get("appendix_ready") == Some("true") ||
        block.attrs.get("note_definition_id") is Some(_) {
        @core.block_with_attr(block, "render_appendix_group", "notes")
      } else {
        block
      }
  }
}

///|
fn apply_render_window_hint(block : @core.CoreBlock) -> @core.CoreBlock {
  if block.attrs.get("render_window_group") is Some(_) {
    return block
  }
  if block.attrs.get("slide_local") == Some("true") {
    return @core.block_with_attr(block, "render_window_group", "slide_local")
  }
  match @core.block_source_ref(block) {
    Some(source_ref) =>
      if source_ref.page is Some(page) {
        @core.block_with_attr(
          block,
          "render_window_group",
          "page:" + page.to_string(),
        )
      } else if source_ref.slide is Some(slide) {
        @core.block_with_attr(
          block,
          "render_window_group",
          "slide:" + slide.to_string(),
        )
      } else {
        match source_ref.sheet {
          Some(sheet) =>
            @core.block_with_attr(
              block,
              "render_window_group",
              "sheet:" + sheet,
            )
          None => block
        }
      }
    None => block
  }
}

///|
fn apply_render_table_hint(block : @core.CoreBlock) -> @core.CoreBlock {
  if block.kind != @core.BlockKind::Table {
    return block
  }
  if block.children.any(fn(row) {
      row.attrs.get("sparse_cell_columns") == Some("true")
    }) {
    return @core.block_with_attr(block, "render_table_mode", "sparse")
  }
  if block.attrs.get("render_html_table") == Some("true") {
    return @core.block_with_attr(block, "render_table_mode", "html_span")
  }
  @core.block_with_attr(block, "render_table_mode", "dense")
}
