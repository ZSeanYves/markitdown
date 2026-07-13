///|
pub fn assemble_section_tree_pass() -> IRPass {
  {
    name: "AssembleSectionTreePass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(assemble_section_tree_input(context, input))
    },
  }
}

///|
fn assemble_document_sections(
  blocks : Array[@core.CoreBlock],
) -> @core.DocumentAssembly {
  let assembly = {
    ..@core.empty_document_assembly(),
    root_block_ids: blocks.map(block => block.block_id),
  }
  let heading_stack : Array[(Int, String)] = []
  let current_section_ids : Array[String] = []
  let section_index_by_id : Map[String, Int] = Map([])

  fn visit(
    blocks : Array[@core.CoreBlock],
    assembly : @core.DocumentAssembly,
    heading_stack : Array[(Int, String)],
    current_section_ids : Array[String],
    section_index_by_id : Map[String, Int],
    ordinal : Int,
  ) -> Int {
    let mut local_ordinal = ordinal
    for block in blocks {
      local_ordinal += 1
      push_reading_order_entry(assembly, block, local_ordinal)
      if block.kind == @core.BlockKind::Heading {
        let level = clamp_heading_level(block.attrs.get("level").unwrap_or("1"))
        while heading_stack.length() > 0 &&
              heading_stack[heading_stack.length() - 1].0 >= level {
          ignore(heading_stack.pop())
        }
        heading_stack.push((level, block.text))
        let heading_path = heading_stack.map(entry => entry.1)
        assembly.heading_paths.set(block.block_id, heading_path)
        let section : @core.SectionNode = {
          section_id: block.block_id,
          heading_block_id: Some(block.block_id),
          title: block.text,
          level,
          heading_path,
          child_section_ids: [],
          block_ids: [block.block_id],
          source_ref: @core.block_source_ref(block),
        }
        let section_index = assembly.sections.length()
        assembly.sections.push(section)
        section_index_by_id.set(section.section_id, section_index)
        if current_section_ids.length() >= level {
          while current_section_ids.length() >= level {
            ignore(current_section_ids.pop())
          }
        }
        if current_section_ids.length() > 0 {
          let parent_index = current_section_ids.length() - 1
          let parent_id = current_section_ids[parent_index]
          append_child_section_id(
            assembly,
            section_index_by_id,
            parent_id,
            section.section_id,
          )
        }
        current_section_ids.push(section.section_id)
      } else if current_section_ids.length() > 0 {
        let current_id = current_section_ids[current_section_ids.length() - 1]
        append_section_block_id(
          assembly,
          section_index_by_id,
          current_id,
          block.block_id,
        )
        if heading_stack.length() > 0 {
          assembly.heading_paths.set(
            block.block_id,
            heading_stack.map(entry => entry.1),
          )
        }
      }
      if block.children.length() > 0 {
        local_ordinal = visit(
          block.children,
          assembly,
          heading_stack,
          current_section_ids,
          section_index_by_id,
          local_ordinal,
        )
      }
    }
    local_ordinal
  }

  ignore(
    visit(
      blocks, assembly, heading_stack, current_section_ids, section_index_by_id,
      0,
    ),
  )
  assembly
}

///|
fn assemble_document_sections_from_prior(
  blocks : Array[@core.CoreBlock],
  prior : @core.DocumentAssembly,
) -> @core.DocumentAssembly {
  let section_assembly = assemble_document_sections(blocks)
  {
    ..prior,
    root_block_ids: section_assembly.root_block_ids,
    sections: section_assembly.sections,
    heading_paths: section_assembly.heading_paths,
    reading_order: section_assembly.reading_order,
  }
}

///|
fn append_child_section_id(
  assembly : @core.DocumentAssembly,
  section_index_by_id : Map[String, Int],
  parent_id : String,
  child_id : String,
) -> Unit {
  match section_index_by_id.get(parent_id) {
    Some(index) => assembly.sections[index].child_section_ids.push(child_id)
    None => ()
  }
}

///|
fn append_section_block_id(
  assembly : @core.DocumentAssembly,
  section_index_by_id : Map[String, Int],
  section_id : String,
  block_id : String,
) -> Unit {
  match section_index_by_id.get(section_id) {
    Some(index) => assembly.sections[index].block_ids.push(block_id)
    None => ()
  }
}

///|
fn push_reading_order_entry(
  assembly : @core.DocumentAssembly,
  block : @core.CoreBlock,
  ordinal : Int,
) -> Unit {
  let source_ref = @core.block_source_ref(block).unwrap_or(
    @core.empty_source_ref(),
  )
  assembly.reading_order.push({
    block_id: block.block_id,
    ordinal,
    page: source_ref.page,
    slide: source_ref.slide,
    sheet: source_ref.sheet,
  })
}

///|
fn assemble_section_tree_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let prior = document_assembly_or_empty(document)
      let assembly = assemble_document_sections_from_prior(
        document.blocks,
        prior,
      )
      context.assembly.val = Some(assembly)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "assembly_root_block_count",
        assembly.root_block_ids.length().to_string(),
      )
      next.diagnostics.metrics.set(
        "assembly_section_count",
        assembly.sections.length().to_string(),
      )
      next.diagnostics.metrics.set(
        "assembly_heading_path_count",
        assembly.heading_paths.length().to_string(),
      )
      if @product.debug_output_mode(context.output_mode) {
        next.diagnostics.metrics.set("assembly_debug_mode", "true")
      }
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let assembly = assemble_document_sections_from_prior(
        blocks,
        context.assembly.val.unwrap_or(@core.empty_document_assembly()),
      )
      context.assembly.val = Some(assembly)
      context.diagnostics.val.metrics.set(
        "assembly_root_block_count",
        assembly.root_block_ids.length().to_string(),
      )
      context.diagnostics.val.metrics.set(
        "assembly_section_count",
        assembly.sections.length().to_string(),
      )
      context.diagnostics.val.metrics.set(
        "assembly_heading_path_count",
        assembly.heading_paths.length().to_string(),
      )
      if @product.debug_output_mode(context.output_mode) {
        context.diagnostics.val.metrics.set("assembly_debug_mode", "true")
      }
      @core.IRInput::BlockStream(blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}
