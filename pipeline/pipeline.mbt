///|
pub struct CoreIRBuilder {
  build : (@core.IRInput) -> @core.DocumentIR
}

///|
pub struct PassContext {
  debug : Bool
  mode_name : String
  pdf_cleanup_enabled : Bool
}

///|
pub struct IRPass {
  name : String
  run : (@core.DocumentIR, PassContext) -> @core.DocumentIR
}

///|
pub struct PassPipeline {
  passes : Array[IRPass]
}

///|
pub fn make_pass_context(
  debug : Bool,
  mode_name : String,
  pdf_cleanup_enabled? : Bool = false,
) -> PassContext {
  { debug, mode_name, pdf_cleanup_enabled }
}

///|
pub fn default_ir_builder() -> CoreIRBuilder {
  {
    build: fn(input : @core.IRInput) -> @core.DocumentIR {
      ir_input_to_document(input)
    },
  }
}

///|
pub fn ir_input_to_document(input : @core.IRInput) -> @core.DocumentIR {
  match input {
    @core.IRInput::Document(document) => {
      let next = document
      next.diagnostics.metrics.set("builder_input_kind", "document")
      next
    }
    @core.IRInput::BlockStream(blocks) => {
      let document = @core.document_from_blocks(blocks)
      document.diagnostics.metrics.set("builder_input_kind", "block_stream")
      document
    }
    @core.IRInput::EventStream(events) => {
      let document = build_document_from_events(events)
      document.diagnostics.metrics.set("builder_input_kind", "event_stream")
      document
    }
    @core.IRInput::ContainerManifest(manifest) => {
      let base = @core.empty_document_ir()
      let document = @core.document_with_diagnostics(base, manifest.diagnostics)
      document.metadata.set(
        "container_format",
        @core.JsonValue::String(manifest.container_format),
      )
      match manifest.container_path {
        Some(path) =>
          document.metadata.set("container_path", @core.JsonValue::String(path))
        None => ()
      }
      document.metadata.set(
        "container_entry_count",
        @core.JsonValue::Number(manifest.entries.length().to_string()),
      )
      document.metadata.set(
        "selected_entry_count",
        @core.JsonValue::Number(manifest.selected_entries.length().to_string()),
      )
      document.metadata.set(
        "skipped_entry_count",
        @core.JsonValue::Number(manifest.skipped_entries.length().to_string()),
      )
      document.diagnostics.metrics.set(
        "builder_input_kind", "container_manifest",
      )
      document.diagnostics.metrics.set("ir_input_kind", "container_manifest")
      document
    }
    @core.IRInput::ContainerPlan(plan) => {
      let base = @core.empty_document_ir()
      let document = @core.document_with_diagnostics(base, plan.diagnostics)
      document.blocks.append(plan.merged_blocks[:])
      document.assets.append(plan.merged_assets[:])
      document.metadata.set(
        "container_format",
        @core.JsonValue::String(plan.container_format),
      )
      match plan.container_path {
        Some(path) =>
          document.metadata.set("container_path", @core.JsonValue::String(path))
        None => ()
      }
      document.metadata.set(
        "container_entry_count",
        @core.JsonValue::Number(plan.ordered_entries.length().to_string()),
      )
      document.metadata.set(
        "selected_entry_count",
        @core.JsonValue::Number(
          plan.inner_documents_to_convert.length().to_string(),
        ),
      )
      document.metadata.set(
        "asset_plan_count",
        @core.JsonValue::Number(plan.assets_to_materialize.length().to_string()),
      )
      document.metadata.set(
        "merged_block_count",
        @core.JsonValue::Number(plan.merged_blocks.length().to_string()),
      )
      document.metadata.set(
        "skipped_entry_count",
        @core.JsonValue::Number(plan.skipped_entries.length().to_string()),
      )
      document.diagnostics.metrics.set("builder_input_kind", "container_plan")
      document.diagnostics.metrics.set("ir_input_kind", "container_plan")
      document
    }
  }
}

///|
pub fn new_pass_pipeline(passes : Array[IRPass]) -> PassPipeline {
  { passes, }
}

///|
pub fn run_pipeline(
  pipeline : PassPipeline,
  document : @core.DocumentIR,
  context : PassContext,
) -> @core.DocumentIR {
  run_pipeline_with_trace(pipeline, document, context, true)
}

///|
fn run_pipeline_with_trace(
  pipeline : PassPipeline,
  document : @core.DocumentIR,
  context : PassContext,
  trace_passes : Bool,
) -> @core.DocumentIR {
  let mut current = document
  for pass in pipeline.passes {
    current = (pass.run)(current, context)
    if trace_passes {
      current.diagnostics.pass_trace.push(pass.name)
    }
  }
  current
}

///|
pub fn default_pass_pipeline() -> PassPipeline {
  new_pass_pipeline([
    normalize_text_pass(),
    normalize_whitespace_pass(),
    merge_text_line_pass(),
    resolve_reading_order_pass(),
    remove_header_footer_pass(),
    resolve_heading_pass(),
    resolve_list_pass(),
    collect_asset_refs_pass(),
    resolve_table_pass(),
    resolve_caption_pass(),
    resolve_asset_pass(),
    assemble_section_tree_pass(),
    debug_annotation_pass(),
  ])
}

///|
pub fn build_document_with_default_pipeline(
  input : @core.IRInput,
  context : PassContext,
  trace_builder? : Bool = true,
  trace_passes? : Bool = true,
) -> @core.DocumentIR {
  let document = (default_ir_builder().build)(input)
  if trace_builder {
    document.diagnostics.pass_trace.push("builder:default_ir_builder")
  }
  run_pipeline_with_trace(
    default_pass_pipeline(),
    document,
    context,
    trace_passes,
  )
}

///|
pub fn normalize_text_pass() -> IRPass {
  {
    name: "NormalizeTextPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      @core.document_with_blocks(
        document,
        document.blocks.map(block => normalize_block_text(block)),
      )
    },
  }
}

///|
pub fn normalize_whitespace_pass() -> IRPass {
  {
    name: "NormalizeWhitespacePass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      @core.document_with_blocks(
        document,
        document.blocks.map(block => normalize_block_whitespace(block)),
      )
    },
  }
}

///|
pub fn merge_text_line_pass() -> IRPass {
  {
    name: "MergeTextLinePass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let next = @core.document_with_blocks(
        document,
        merge_text_line_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "merged_text_line_count",
        merged_text_line_count(document.blocks, next.blocks).to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_reading_order_pass() -> IRPass {
  {
    name: "ResolveReadingOrderPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let next = @core.document_with_blocks(
        document,
        resolve_reading_order_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_reading_order_block_count",
        reading_order_hint_block_count(next.blocks).to_string(),
      )
      next
    },
  }
}

///|
pub fn remove_header_footer_pass() -> IRPass {
  {
    name: "RemoveHeaderFooterPass",
    run: fn(
      document : @core.DocumentIR,
      context : PassContext,
    ) -> @core.DocumentIR {
      let removal = remove_header_footer_blocks(
        document.blocks,
        context.pdf_cleanup_enabled,
        context.debug,
      )
      let next = @core.document_with_blocks(document, removal.0)
      next.diagnostics.metrics.set(
        "removed_header_footer_count",
        removal.1.to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_heading_pass() -> IRPass {
  {
    name: "ResolveHeadingPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let next = @core.document_with_blocks(
        document,
        resolve_heading_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_heading_count",
        heading_block_count(next.blocks).to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_list_pass() -> IRPass {
  {
    name: "ResolveListPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let next = @core.document_with_blocks(
        document,
        resolve_list_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_list_count",
        list_block_count(next.blocks).to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_table_pass() -> IRPass {
  {
    name: "ResolveTablePass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let assembly = table_resolved_assembly(document)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_table_continuation_count",
        assembly.table_continuations.length().to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_caption_pass() -> IRPass {
  {
    name: "ResolveCaptionPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let assembly = caption_resolved_assembly(document)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_caption_binding_count",
        assembly.caption_bindings.length().to_string(),
      )
      next
    },
  }
}

///|
pub fn resolve_asset_pass() -> IRPass {
  {
    name: "ResolveAssetPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let assembly = asset_resolved_assembly(document)
      let next = @core.document_with_assembly(document, Some(assembly))
      next.diagnostics.metrics.set(
        "resolved_asset_binding_count",
        assembly.asset_bindings.length().to_string(),
      )
      next
    },
  }
}

///|
pub fn assemble_section_tree_pass() -> IRPass {
  {
    name: "AssembleSectionTreePass",
    run: fn(
      document : @core.DocumentIR,
      context : PassContext,
    ) -> @core.DocumentIR {
      let prior = document_assembly_or_empty(document)
      let section_assembly = assemble_document_sections(document.blocks)
      let assembly : @core.DocumentAssembly = {
        ..prior,
        root_block_ids: section_assembly.root_block_ids,
        sections: section_assembly.sections,
        heading_paths: section_assembly.heading_paths,
        reading_order: section_assembly.reading_order,
      }
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
      if context.debug {
        next.diagnostics.metrics.set("assembly_debug_mode", "true")
      }
      next
    },
  }
}

///|
fn table_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  let entries : Array[(@core.CoreBlock, Array[String])] = []
  collect_table_blocks_with_heading_paths(
    document.blocks,
    [],
    assembly.heading_paths,
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
  { ..assembly, table_continuations: continuations }
}

///|
fn caption_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  let bindings : Array[@core.CaptionBinding] = []
  collect_caption_bindings(document.blocks, bindings)
  { ..assembly, caption_bindings: bindings }
}

///|
fn asset_resolved_assembly(
  document : @core.DocumentIR,
) -> @core.DocumentAssembly {
  let assembly = document_assembly_or_empty(document)
  let bindings : Array[@core.AssetBinding] = []
  collect_asset_bindings(document.blocks, document.assets, bindings)
  { ..assembly, asset_bindings: bindings }
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
fn merge_text_line_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let merged : Array[@core.CoreBlock] = []
  let mut pending : @core.CoreBlock? = None
  for block in blocks {
    let next_block = @core.block_with_children(
      block,
      merge_text_line_blocks(block.children),
    )
    if pending is Some(current) &&
      paragraph_blocks_should_merge(current, next_block) {
      pending = Some(merge_paragraph_blocks(current, next_block))
      continue
    }
    match pending {
      Some(current) => merged.push(current)
      None => ()
    }
    pending = if paragraph_merge_candidate(next_block) {
      Some(next_block)
    } else {
      None
    }
    if !paragraph_merge_candidate(next_block) {
      merged.push(next_block)
    }
  }
  match pending {
    Some(current) => merged.push(current)
    None => ()
  }
  merged
}

///|
fn resolve_reading_order_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let ordered : Array[@core.CoreBlock] = []
  for block in blocks {
    ordered.push(
      @core.block_with_children(
        block,
        resolve_reading_order_blocks(block.children),
      ),
    )
  }
  if ordered.length() <= 1 {
    return ordered
  }
  let hinted_indexes : Array[Int] = []
  let hinted_blocks : Array[(Int, @core.CoreBlock)] = []
  for index in 0..<ordered.length() {
    if block_has_explicit_reading_order_hint(ordered[index]) {
      hinted_indexes.push(index)
      hinted_blocks.push((index, ordered[index]))
    }
  }
  if hinted_blocks.length() < 2 {
    return ordered
  }
  let reordered : Array[@core.CoreBlock] = ordered.copy()
  let mut start = 0
  while start < hinted_blocks.length() {
    let boundary = block_reading_order_boundary_key(hinted_blocks[start].1)
    let mut end = start + 1
    while end < hinted_blocks.length() &&
          block_reading_order_boundary_key(hinted_blocks[end].1) == boundary {
      end += 1
    }
    let group_indexes : Array[Int] = []
    let local_group : Array[(Int, @core.CoreBlock)] = []
    for index in start..<end {
      local_group.push(hinted_blocks[index])
      group_indexes.push(hinted_blocks[index].0)
    }
    group_indexes.sort()
    local_group.sort_by(fn(left, right) {
      let compared = compare_blocks_by_reading_order(left.1, right.1)
      if compared != 0 {
        compared
      } else if left.0 < right.0 {
        -1
      } else if left.0 > right.0 {
        1
      } else {
        0
      }
    })
    for index in 0..<local_group.length() {
      reordered[group_indexes[index]] = local_group[index].1
    }
    start = end
  }
  reordered
}

///|
fn remove_header_footer_blocks(
  blocks : Array[@core.CoreBlock],
  cleanup_enabled : Bool,
  debug : Bool,
) -> (Array[@core.CoreBlock], Int) {
  let kept : Array[@core.CoreBlock] = []
  let mut removed = 0
  for block in blocks {
    let next_children = remove_header_footer_blocks(
      block.children,
      cleanup_enabled,
      debug,
    )
    let next = @core.block_with_children(block, next_children.0)
    removed += next_children.1
    if block_is_header_footer_candidate(next) {
      if cleanup_enabled && !debug {
        removed += 1
        continue
      }
      if debug {
        next.attrs.set("header_footer_candidate", "true")
      }
    }
    kept.push(next)
  }
  (kept, removed)
}

///|
fn resolve_heading_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  blocks.map(block => resolve_heading_block(block))
}

///|
fn resolve_heading_block(block : @core.CoreBlock) -> @core.CoreBlock {
  let next_children = resolve_heading_blocks(block.children)
  let next = @core.block_with_children(block, next_children)
  if next.kind == @core.BlockKind::Heading {
    let level = clamp_heading_level(next.attrs.get("level").unwrap_or("1"))
    next.attrs.set("level", level.to_string())
    return next
  }
  if block_heading_candidate(next) {
    let promoted = @core.make_block(
      @core.BlockKind::Heading,
      next.text.trim().to_owned(),
      source_ref=next.source_ref.unwrap_or(@core.empty_source_ref()),
    )
    let promoted = @core.block_with_block_id(promoted, next.block_id)
    let promoted = if next.rich_inlines is Some(_) {
      @core.block_with_rich_inlines(promoted, next.rich_inlines)
    } else {
      promoted
    }
    let promoted = @core.block_with_children(promoted, next_children)
    let promoted = @core.block_with_signals(promoted, next.signals)
    let promoted = copy_block_attrs(next, promoted)
    promoted.attrs.set(
      "level",
      clamp_heading_level(heading_candidate_level(next).unwrap_or("1")).to_string(),
    )
    promoted
  } else {
    next
  }
}

///|
fn resolve_list_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let resolved : Array[@core.CoreBlock] = []
  let mut i = 0
  while i < blocks.length() {
    let block = resolve_list_block(blocks[i])
    if list_item_candidate(block) {
      let item_group : Array[@core.CoreBlock] = [block]
      let mut j = i + 1
      while j < blocks.length() {
        let next = resolve_list_block(blocks[j])
        if !list_item_candidate(next) {
          break
        }
        item_group.push(next)
        j += 1
      }
      resolved.append(list_item_group_to_blocks(item_group)[:])
      i = j
    } else {
      resolved.push(block)
      i += 1
    }
  }
  resolved
}

///|
fn resolve_list_block(block : @core.CoreBlock) -> @core.CoreBlock {
  if block.kind == @core.BlockKind::List {
    return @core.block_with_children(
      block,
      resolve_list_children_in_container(block.children),
    )
  }
  @core.block_with_children(block, resolve_list_blocks(block.children))
}

///|
fn resolve_list_children_in_container(
  children : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  children.map(child => {
    if child.kind == @core.BlockKind::ListItem {
      @core.block_with_children(child, resolve_list_blocks(child.children))
    } else if child.kind == @core.BlockKind::List {
      @core.block_with_children(
        child,
        resolve_list_children_in_container(child.children),
      )
    } else {
      @core.block_with_children(child, resolve_list_blocks(child.children))
    }
  })
}

///|
fn list_item_group_to_blocks(
  items : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  if items.length() == 0 {
    return []
  }
  if items.length() == 1 &&
    items[0].kind == @core.BlockKind::ListItem &&
    items[0].children.any(child => child.kind == @core.BlockKind::List) {
    return [items[0]]
  }
  let root : Array[@core.CoreBlock] = []
  let stack : Array[(Int, @core.CoreBlock, @core.CoreBlock)] = []
  for item in items {
    let level = list_item_level(item)
    let ordered = list_item_ordered(item)
    while stack.length() > 0 && level < stack[stack.length() - 1].0 {
      ignore(stack.pop())
    }
    if stack.length() == 0 {
      let list = make_list_container_for_item(item, ordered)
      list.children.push(item)
      root.push(list)
      stack.push((level, list, item))
      continue
    }
    let current = stack[stack.length() - 1]
    if level > current.0 {
      let nested = make_list_container_for_item(item, ordered)
      current.2.children.push(nested)
      nested.children.push(item)
      stack.push((level, nested, item))
      continue
    }
    let current_list = current.1
    let current_ordered = current_list.attrs.get("ordered").unwrap_or("false") ==
      "true"
    if current_ordered != ordered {
      ignore(stack.pop())
      let list = make_list_container_for_item(item, ordered)
      if stack.length() == 0 {
        root.push(list)
      } else {
        stack[stack.length() - 1].2.children.push(list)
      }
      list.children.push(item)
      stack.push((level, list, item))
      continue
    }
    current_list.children.push(item)
    ignore(stack.pop())
    stack.push((level, current_list, item))
  }
  root
}

///|
fn make_list_container_for_item(
  item : @core.CoreBlock,
  ordered : Bool,
) -> @core.CoreBlock {
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=item.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  list.attrs.set("ordered", bool_string(ordered))
  list
}

///|
fn block_heading_candidate(block : @core.CoreBlock) -> Bool {
  block.kind == @core.BlockKind::Paragraph &&
  heading_candidate_level(block) is Some(_)
}

///|
fn heading_candidate_level(block : @core.CoreBlock) -> String? {
  match block.attrs.get("heading_level") {
    Some(level) => Some(level)
    None =>
      match block.attrs.get("level") {
        Some(level) if block.attrs.get("heading_candidate") == Some("true") =>
          Some(level)
        _ => heading_signal_level(block.signals)
      }
  }
}

///|
fn heading_signal_level(signals : Array[@core.CoreSignal]) -> String? {
  for signal in signals {
    if signal.signal_type != @core.SignalType::HeadingCandidate {
      continue
    }
    match signal.payload.get("level") {
      Some(@core.JsonValue::String(level)) => return Some(level)
      Some(@core.JsonValue::Number(level)) => return Some(level)
      _ => ()
    }
  }
  None
}

///|
fn list_item_candidate(block : @core.CoreBlock) -> Bool {
  if block.kind == @core.BlockKind::ListItem {
    return true
  }
  if block.kind != @core.BlockKind::Paragraph {
    return false
  }
  if block.attrs.get("list_item_candidate") == Some("true") {
    return true
  }
  block.signals.any(fn(signal) {
    signal.signal_type == @core.SignalType::ListCandidate
  })
}

///|
fn list_item_level(block : @core.CoreBlock) -> Int {
  let raw = block.attrs.get("level").unwrap_or("0")
  let parsed = @string.parse_int(raw.trim()) catch { _ => 0 }
  if parsed < 0 {
    0
  } else {
    parsed
  }
}

///|
fn list_item_ordered(block : @core.CoreBlock) -> Bool {
  block.attrs.get("ordered").unwrap_or("false") == "true"
}

///|
fn bool_string(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn copy_block_attrs(
  from : @core.CoreBlock,
  to : @core.CoreBlock,
) -> @core.CoreBlock {
  let next = { ..to, style: from.style }
  for entry in from.attrs.to_array() {
    next.attrs.set(entry.0, entry.1)
  }
  next
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

  fn visit(
    blocks : Array[@core.CoreBlock],
    assembly : @core.DocumentAssembly,
    heading_stack : Array[(Int, String)],
    current_section_ids : Array[String],
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
          source_ref: block.source_ref,
        }
        assembly.sections.push(section)
        if current_section_ids.length() >= level {
          while current_section_ids.length() >= level {
            ignore(current_section_ids.pop())
          }
        }
        if current_section_ids.length() > 0 {
          let parent_index = current_section_ids.length() - 1
          let parent_id = current_section_ids[parent_index]
          append_child_section_id(assembly, parent_id, section.section_id)
        }
        current_section_ids.push(section.section_id)
      } else if current_section_ids.length() > 0 {
        let current_id = current_section_ids[current_section_ids.length() - 1]
        append_section_block_id(assembly, current_id, block.block_id)
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
          local_ordinal,
        )
      }
    }
    local_ordinal
  }

  ignore(visit(blocks, assembly, heading_stack, current_section_ids, 0))
  assembly
}

///|
fn heading_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == @core.BlockKind::Heading {
      total += 1
    }
    total += heading_block_count(block.children)
  }
  total
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
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
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
fn collect_asset_bindings(
  blocks : Array[@core.CoreBlock],
  assets : Array[@core.AssetRef],
  bindings : Array[@core.AssetBinding],
) -> Unit {
  for block in blocks {
    for asset in assets {
      if block_owns_asset(block, asset) {
        bindings.push({
          asset_id: asset.asset_id,
          owner_block_id: block.block_id,
          relation: asset_binding_relation(block, asset),
          confidence: Some(90),
        })
      }
    }
    if block.children.length() > 0 {
      collect_asset_bindings(block.children, assets, bindings)
    }
  }
}

///|
fn block_owns_asset(block : @core.CoreBlock, asset : @core.AssetRef) -> Bool {
  match block.attrs.get("asset_id") {
    Some(asset_id) if asset_id == asset.asset_id => return true
    _ => ()
  }
  match (block.attrs.get("path"), asset.path) {
    (Some(path), Some(asset_path)) if path == asset_path => return true
    _ => ()
  }
  match (block.attrs.get("source_path"), asset.attrs.get("source_path")) {
    (Some(path), Some(asset_path)) if path == asset_path => return true
    _ => ()
  }
  let block_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  let asset_ref = asset.source_ref.unwrap_or(@core.empty_source_ref())
  source_ref_equivalent_for_asset(block_ref, asset_ref)
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
fn source_ref_equivalent_for_asset(
  left : @core.SourceRef,
  right : @core.SourceRef,
) -> Bool {
  left.file_id == right.file_id &&
  left.format == right.format &&
  left.container_path == right.container_path &&
  left.entry_path == right.entry_path &&
  left.inner_path == right.inner_path &&
  left.sheet == right.sheet &&
  left.slide == right.slide &&
  left.page == right.page &&
  left.relationship_id == right.relationship_id
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
fn paragraph_merge_candidate(block : @core.CoreBlock) -> Bool {
  block.kind == @core.BlockKind::Paragraph && block.children.length() == 0
}

///|
fn paragraph_blocks_should_merge(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Bool {
  if !paragraph_merge_candidate(left) || !paragraph_merge_candidate(right) {
    return false
  }
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  if left_ref.page != right_ref.page ||
    left_ref.slide != right_ref.slide ||
    left_ref.sheet != right_ref.sheet {
    return false
  }
  if left_ref.format != Some("pdf") || right_ref.format != Some("pdf") {
    return false
  }
  let left_group = pdf_merge_group_key(left_ref)
  let right_group = pdf_merge_group_key(right_ref)
  if left_group is None || right_group is None {
    return false
  }
  if left_ref.extra.get("reading_order_index") !=
    right_ref.extra.get("reading_order_index") {
    return false
  }
  if left_group != right_group {
    return false
  }
  if block_is_header_footer_candidate(left) ||
    block_is_header_footer_candidate(right) {
    return false
  }
  true
}

///|
fn merge_paragraph_blocks(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> @core.CoreBlock {
  let merged_text = merge_text_line_strings(left.text, right.text)
  let next = { ..left, text: merged_text }
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  let merged_ref = {
    ..left_ref,
    bbox: merge_source_bbox(left_ref.bbox, right_ref.bbox),
    line_start: min_optional_int(left_ref.line_start, right_ref.line_start),
    line_end: max_optional_int(left_ref.line_end, right_ref.line_end),
  }
  { ..next, source_ref: Some(merged_ref) }
}

///|
fn merge_text_line_strings(left : String, right : String) -> String {
  let lhs = left.trim_end().to_owned()
  let rhs = right.trim_start().to_owned()
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  if lhs.has_suffix("-") && rhs != "" {
    lhs[:lhs.length() - 1].to_owned() + rhs
  } else {
    lhs + " " + rhs
  }
}

///|
fn merge_source_bbox(left : @core.BBox?, right : @core.BBox?) -> @core.BBox? {
  match (left, right) {
    (Some(lhs), Some(rhs)) =>
      Some({
        x0: if lhs.x0 < rhs.x0 {
          lhs.x0
        } else {
          rhs.x0
        },
        y0: if lhs.y0 < rhs.y0 {
          lhs.y0
        } else {
          rhs.y0
        },
        x1: if lhs.x1 > rhs.x1 {
          lhs.x1
        } else {
          rhs.x1
        },
        y1: if lhs.y1 > rhs.y1 {
          lhs.y1
        } else {
          rhs.y1
        },
      })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn min_optional_int(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (Some(lhs), Some(rhs)) => Some(if lhs < rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn max_optional_int(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (Some(lhs), Some(rhs)) => Some(if lhs > rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn compare_blocks_by_reading_order(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Int {
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  let left_rank = block_reading_order_rank(left, left_ref)
  let right_rank = block_reading_order_rank(right, right_ref)
  let rank_order = left_rank.lexical_compare(right_rank)
  if rank_order != 0 {
    return rank_order
  }
  let left_page = left_ref.page.unwrap_or(0)
  let right_page = right_ref.page.unwrap_or(0)
  if left_page < right_page {
    return -1
  } else if left_page > right_page {
    return 1
  }
  let left_slide = left_ref.slide.unwrap_or(0)
  let right_slide = right_ref.slide.unwrap_or(0)
  if left_slide < right_slide {
    return -1
  } else if left_slide > right_slide {
    return 1
  }
  0
}

///|
fn block_reading_order_boundary_key(block : @core.CoreBlock) -> String {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  source_ref.format.unwrap_or("") +
  "|" +
  source_ref.page.map(i => i.to_string()).unwrap_or("") +
  "|" +
  source_ref.slide.map(i => i.to_string()).unwrap_or("") +
  "|" +
  source_ref.sheet.unwrap_or("") +
  "|" +
  source_ref.entry_path.unwrap_or("")
}

///|
fn block_reading_order_rank(
  block : @core.CoreBlock,
  source_ref : @core.SourceRef,
) -> String {
  match source_ref.extra.get("reading_order_key") {
    Some(value) => "0|" + value
    None =>
      match source_ref.extra.get("reading_order_index") {
        Some(value) => "1|" + left_pad_numeric_string(value, 8)
        None =>
          "9|" +
          block_kind_rank(block.kind) +
          "|" +
          source_ref.page
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000") +
          "|" +
          source_ref.slide
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000") +
          "|" +
          source_ref.line_start
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000")
      }
  }
}

///|
fn left_pad_numeric_string(value : String, width : Int) -> String {
  let trimmed = value.trim().to_owned()
  let negative = trimmed.has_prefix("-")
  let digits = if negative { trimmed[1:].to_owned() } else { trimmed }
  let mut out = digits
  while out.length() < width {
    out = "0" + out
  }
  if negative {
    "-" + out
  } else {
    out
  }
}

///|
fn block_kind_rank(kind : @core.BlockKind) -> String {
  match kind {
    @core.BlockKind::Heading => "00"
    @core.BlockKind::Paragraph => "01"
    @core.BlockKind::List => "02"
    @core.BlockKind::Table => "03"
    @core.BlockKind::Image => "04"
    @core.BlockKind::Code => "05"
    @core.BlockKind::BlockQuote => "06"
    @core.BlockKind::Raw => "07"
    _ => "99"
  }
}

///|
fn block_is_header_footer_candidate(block : @core.CoreBlock) -> Bool {
  if block.attrs.get("header_footer_candidate") == Some("true") {
    return true
  }
  block.signals.any(fn(signal) {
    signal.signal_type == @core.SignalType::HeaderFooterCandidate
  })
}

///|
fn block_has_explicit_reading_order_hint(block : @core.CoreBlock) -> Bool {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  source_ref.extra.get("reading_order_key") is Some(_) ||
  source_ref.extra.get("reading_order_index") is Some(_)
}

///|
fn pdf_merge_group_key(source_ref : @core.SourceRef) -> String? {
  match source_ref.extra.get("pdf_merge_group") {
    Some(value) if value.trim() != "" => Some(value)
    _ => source_ref.extra.get("pdf_text_block_index")
  }
}

///|
fn merged_text_line_count(
  before : Array[@core.CoreBlock],
  after : Array[@core.CoreBlock],
) -> Int {
  let before_count = paragraph_leaf_count(before)
  let after_count = paragraph_leaf_count(after)
  if before_count > after_count {
    before_count - after_count
  } else {
    0
  }
}

///|
fn paragraph_leaf_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == @core.BlockKind::Paragraph && block.children.length() == 0 {
      total += 1
    }
    total += paragraph_leaf_count(block.children)
  }
  total
}

///|
fn reading_order_hint_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
    if source_ref.extra.get("reading_order_key") is Some(_) ||
      source_ref.extra.get("reading_order_index") is Some(_) {
      total += 1
    }
    total += reading_order_hint_block_count(block.children)
  }
  total
}

///|
fn list_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == @core.BlockKind::List {
      total += 1
    }
    total += list_block_count(block.children)
  }
  total
}

///|
fn append_child_section_id(
  assembly : @core.DocumentAssembly,
  parent_id : String,
  child_id : String,
) -> Unit {
  for section in assembly.sections {
    if section.section_id == parent_id {
      if !section.child_section_ids.contains(child_id) {
        section.child_section_ids.push(child_id)
      }
      return
    }
  }
}

///|
fn append_section_block_id(
  assembly : @core.DocumentAssembly,
  section_id : String,
  block_id : String,
) -> Unit {
  for section in assembly.sections {
    if section.section_id == section_id {
      if !section.block_ids.contains(block_id) {
        section.block_ids.push(block_id)
      }
      return
    }
  }
}

///|
fn push_reading_order_entry(
  assembly : @core.DocumentAssembly,
  block : @core.CoreBlock,
  ordinal : Int,
) -> Unit {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  assembly.reading_order.push({
    block_id: block.block_id,
    ordinal,
    page: source_ref.page,
    slide: source_ref.slide,
    sheet: source_ref.sheet,
  })
}

///|
fn clamp_heading_level(raw : String) -> Int {
  let parsed = @string.parse_int(raw.trim()) catch { _ => 1 }
  if parsed < 1 {
    1
  } else if parsed > 6 {
    6
  } else {
    parsed
  }
}

///|
pub fn collect_asset_refs_pass() -> IRPass {
  {
    name: "CollectAssetRefsPass",
    run: fn(
      document : @core.DocumentIR,
      _context : PassContext,
    ) -> @core.DocumentIR {
      let next = @core.document_with_assets(
        document,
        collect_document_asset_refs(document.blocks, document.assets),
      )
      next.diagnostics.metrics.set(
        "asset_count",
        next.assets.length().to_string(),
      )
      next
    },
  }
}

///|
pub fn debug_annotation_pass() -> IRPass {
  {
    name: "DebugAnnotationPass",
    run: fn(
      document : @core.DocumentIR,
      context : PassContext,
    ) -> @core.DocumentIR {
      if context.debug {
        document.diagnostics.metrics.set("debug_annotation", "enabled")
      }
      document
    },
  }
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
      block.source_ref.unwrap_or(@core.empty_source_ref()),
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
              block.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
            inline.href.unwrap_or("").trim().to_owned(),
            None,
            inline.text,
            None,
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
    Some(source_path) => next_asset.attrs.set("source_path", source_path)
    None => ()
  }
  assets.push(next_asset)
}

///|
pub fn build_document_from_events(
  events : Array[@core.CoreEvent],
) -> @core.DocumentIR {
  if generic_block_event_stream(events) {
    return build_document_from_generic_block_events(events)
  }
  build_document_from_simple_events(events)
}

///|
pub fn blocks_to_event_stream(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreEvent] {
  let events : Array[@core.CoreEvent] = []
  for block in blocks {
    append_generic_block_events(events, block)
  }
  events
}

///|
fn build_document_from_simple_events(
  events : Array[@core.CoreEvent],
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  let text_lines : Array[@core.CoreEvent] = []
  let current_row : Array[String] = []
  let current_row_refs : Array[@core.SourceRef] = []
  let table_rows : Array[@core.CoreBlock] = []
  for event in events {
    match event.kind {
      @core.EventKind::StartBlock(kind) => {
        let block = @core.make_block(
          kind,
          event.text,
          source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
        )
        if kind == @core.BlockKind::Code {
          match event.source_ref {
            Some(source_ref) =>
              match source_ref.extra.get("ir_block_attr_info") {
                Some(info) => block.attrs.set("info", info)
                None => ()
              }
            None => ()
          }
        }
        document.blocks.push(block)
      }
      @core.EventKind::TextLine | @core.EventKind::BlankLine =>
        text_lines.push(event)
      @core.EventKind::Cell => {
        current_row.push(event.text)
        current_row_refs.push(
          event.source_ref.unwrap_or(@core.empty_source_ref()),
        )
      }
      @core.EventKind::RowBreak =>
        if current_row.length() > 0 {
          let row_ref = event.source_ref.unwrap_or(
            if current_row_refs.length() > 0 {
              current_row_refs[0]
            } else {
              @core.empty_source_ref()
            },
          )
          table_rows.push(
            simple_event_table_row(current_row, current_row_refs, row_ref),
          )
          current_row.clear()
          current_row_refs.clear()
        }
      _ => ()
    }
  }
  if text_lines.length() > 0 {
    for block in paragraph_blocks_from_line_events(text_lines) {
      document.blocks.push(block)
    }
  }
  if table_rows.length() > 0 {
    let first_row = table_rows[0]
    let last_row = table_rows[table_rows.length() - 1]
    let first_row_ref = first_row.source_ref.unwrap_or(@core.empty_source_ref())
    let last_row_ref = last_row.source_ref.unwrap_or(@core.empty_source_ref())
    let table_ref = @core.source_ref_with_cell_range(
      @core.source_ref_with_lines(
        @core.empty_source_ref(),
        first_row_ref.file_id,
        first_row_ref.format,
        first_row_ref.line_start,
        last_row_ref.line_end,
      ),
      first_row_ref.file_id,
      first_row_ref.format,
      table_cell_span_range(
        table_rows.map(row => row.source_ref.unwrap_or(@core.empty_source_ref())),
      ),
    )
    let table = @core.make_block(
      @core.BlockKind::Table,
      "table",
      source_ref=table_ref,
    )
    table.attrs.set("header_rows", "1")
    table.attrs.set(
      "table_column_count",
      simple_event_table_width(table_rows).to_string(),
    )
    document.diagnostics.metrics.set("table_count", "1")
    table.children.append(table_rows[:])
    document.blocks.push(table)
  }
  document
}

///|
fn simple_event_table_row(
  current_row : Array[String],
  current_row_refs : Array[@core.SourceRef],
  row_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let row_block = @core.make_block(
    @core.BlockKind::TableRow,
    current_row.join(" | "),
    source_ref=row_ref,
  )
  for cell_index in 0..<current_row.length() {
    let cell_ref = if cell_index < current_row_refs.length() {
      current_row_refs[cell_index]
    } else {
      row_ref
    }
    row_block.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        current_row[cell_index],
        source_ref=cell_ref,
      ),
    )
  }
  row_block
}

///|
fn simple_event_table_width(rows : Array[@core.CoreBlock]) -> Int {
  let mut width = 0
  for row in rows {
    if row.children.length() > width {
      width = row.children.length()
    }
  }
  width
}

///|
fn paragraph_blocks_from_line_events(
  events : Array[@core.CoreEvent],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let current_lines : Array[String] = []
  let current_refs : Array[@core.SourceRef] = []

  fn flush_paragraph(
    blocks : Array[@core.CoreBlock],
    current_lines : Array[String],
    current_refs : Array[@core.SourceRef],
  ) -> Unit {
    if current_lines.length() == 0 {
      return
    }
    let first_ref = current_refs[0]
    let last_ref = current_refs[current_refs.length() - 1]
    let source_ref = @core.source_ref_with_bytes(
      @core.source_ref_with_lines(
        @core.empty_source_ref(),
        first_ref.file_id,
        first_ref.format,
        first_ref.line_start,
        last_ref.line_end,
      ),
      first_ref.file_id,
      first_ref.format,
      first_ref.byte_start,
      last_ref.byte_end,
    )
    blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        current_lines.join(" "),
        source_ref~,
      ),
    )
    current_lines.clear()
    current_refs.clear()
  }

  for event in events {
    match event.kind {
      @core.EventKind::TextLine => {
        current_lines.push(event.text.trim().to_owned())
        current_refs.push(event.source_ref.unwrap_or(@core.empty_source_ref()))
      }
      @core.EventKind::BlankLine =>
        flush_paragraph(blocks, current_lines, current_refs)
      _ => ()
    }
  }
  flush_paragraph(blocks, current_lines, current_refs)
  blocks
}

///|
fn generic_block_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  if events.length() == 0 {
    return false
  }
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") == Some("generic_block")
    None => false
  }
}

///|
fn build_document_from_generic_block_events(
  events : Array[@core.CoreEvent],
) -> @core.DocumentIR {
  let cursor = { events, index: 0 }
  let document = @core.empty_document_ir()
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => document.blocks.push(block)
      None => cursor.index += 1
    }
  }
  document
}

///|
priv struct GenericEventCursor {
  events : Array[@core.CoreEvent]
  mut index : Int
}

///|
fn parse_generic_block_event(cursor : GenericEventCursor) -> @core.CoreBlock? {
  if cursor.index >= cursor.events.length() {
    return None
  }
  let start = cursor.events[cursor.index]
  match start.kind {
    @core.EventKind::StartBlock(kind) => {
      let source_ref = start.source_ref.unwrap_or(@core.empty_source_ref())
      cursor.index += 1
      Some(
        collect_generic_block_event_body(cursor, kind, start.text, source_ref),
      )
    }
    _ => None
  }
}

///|
fn collect_generic_block_event_body(
  cursor : GenericEventCursor,
  kind : @core.BlockKind,
  text : String,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let block = @core.make_block(
    kind,
    text,
    source_ref=strip_generic_event_ref(source_ref),
  )
  let attrs = Map([], capacity=8)
  for entry in source_ref.extra.to_array() {
    if entry.0.has_prefix("ir_block_attr_") {
      attrs.set(entry.0["ir_block_attr_".length():].to_owned(), entry.1)
    }
  }
  let inlines : Array[@core.CoreInline] = []
  let children : Array[@core.CoreBlock] = []
  let table_cells : Array[String] = []
  let table_cell_refs : Array[@core.SourceRef] = []
  while cursor.index < cursor.events.length() {
    let event = cursor.events[cursor.index]
    match event.kind {
      @core.EventKind::EndBlock(end_kind) => {
        cursor.index += 1
        if end_kind == kind {
          let rich_inlines = if inlines.length() > 0 {
            Some(inlines)
          } else {
            None
          }
          return { ..block, rich_inlines, children, attrs }
        }
      }
      @core.EventKind::StartBlock(_) =>
        match parse_generic_block_event(cursor) {
          Some(child) => children.push(child)
          None => cursor.index += 1
        }
      @core.EventKind::Text => {
        let raw_event_ref = event.source_ref.unwrap_or(source_ref)
        let event_ref = strip_generic_event_ref(raw_event_ref)
        let inline_kind = generic_inline_kind_name(
          raw_event_ref.extra.get("ir_inline_kind"),
        )
        let inline = match inline_kind {
          Some(@core.InlineKind::LineBreak) =>
            @core.make_inline_line_break(source_ref=event_ref)
          Some(@core.InlineKind::Link) =>
            @core.make_inline_link(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Image) =>
            @core.make_inline_image(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Code) =>
            @core.make_inline_code(event.text, source_ref=event_ref)
          _ => @core.make_inline_text(event.text, source_ref=event_ref)
        }
        for entry in raw_event_ref.extra.to_array() {
          if entry.0.has_prefix("ir_inline_attr_") {
            inline.attrs.set(
              entry.0["ir_inline_attr_".length():].to_owned(),
              entry.1,
            )
          }
        }
        inlines.push(inline)
        cursor.index += 1
      }
      @core.EventKind::Cell => {
        table_cells.push(event.text)
        table_cell_refs.push(
          strip_generic_event_ref(event.source_ref.unwrap_or(source_ref)),
        )
        cursor.index += 1
      }
      @core.EventKind::RowBreak => {
        let row_ref = strip_generic_event_ref(
          event.source_ref.unwrap_or(source_ref),
        )
        let row = @core.make_block(
          @core.BlockKind::TableRow,
          table_cells.join(" | "),
          source_ref=row_ref,
        )
        for index in 0..<table_cells.length() {
          row.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              table_cells[index],
              source_ref=if index < table_cell_refs.length() {
                table_cell_refs[index]
              } else {
                row_ref
              },
            ),
          )
        }
        children.push(row)
        table_cells.clear()
        table_cell_refs.clear()
        cursor.index += 1
      }
      _ => cursor.index += 1
    }
  }
  block
}

///|
fn append_generic_block_events(
  events : Array[@core.CoreEvent],
  block : @core.CoreBlock,
) -> Unit {
  let source_ref = generic_block_event_source_ref(
    block.source_ref.unwrap_or(@core.empty_source_ref()),
    block,
  )
  events.push({
    kind: @core.EventKind::StartBlock(block.kind),
    text: block.text,
    source_ref: Some(source_ref),
  })
  match block.rich_inlines {
    Some(inlines) =>
      for inline in inlines {
        let inline_ref = generic_inline_event_source_ref(
          inline.source_ref.unwrap_or(
            block.source_ref.unwrap_or(@core.empty_source_ref()),
          ),
          inline,
        )
        let text = match inline.kind {
          @core.InlineKind::LineBreak => ""
          _ => inline.text
        }
        events.push({
          kind: @core.EventKind::Text,
          text,
          source_ref: Some(inline_ref),
        })
      }
    None => ()
  }
  if block.kind == @core.BlockKind::Table {
    for row in block.children {
      for cell in row.children {
        events.push({
          kind: @core.EventKind::Cell,
          text: cell.text,
          source_ref: Some(
            strip_generic_event_ref(
              cell.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
          ),
        })
      }
      events.push({
        kind: @core.EventKind::RowBreak,
        text: "",
        source_ref: Some(
          strip_generic_event_ref(
            row.source_ref.unwrap_or(@core.empty_source_ref()),
          ),
        ),
      })
    }
  } else {
    for child in block.children {
      append_generic_block_events(events, child)
    }
  }
  events.push({
    kind: @core.EventKind::EndBlock(block.kind),
    text: "",
    source_ref: Some(source_ref),
  })
}

///|
fn generic_block_event_source_ref(
  source_ref : @core.SourceRef,
  block : @core.CoreBlock,
) -> @core.SourceRef {
  let next = strip_generic_event_ref(source_ref)
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_block_kind", @core.block_kind_name(block.kind))
  for entry in block.attrs.to_array() {
    next.extra.set("ir_block_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn generic_inline_event_source_ref(
  source_ref : @core.SourceRef,
  inline : @core.CoreInline,
) -> @core.SourceRef {
  let next = strip_generic_event_ref(source_ref)
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_inline_kind", @core.inline_kind_name(inline.kind))
  match inline.href {
    Some(href) => next.extra.set("ir_inline_href", href)
    None => ()
  }
  match inline.title {
    Some(title) => next.extra.set("ir_inline_title", title)
    None => ()
  }
  for entry in inline.attrs.to_array() {
    next.extra.set("ir_inline_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn strip_generic_event_ref(source_ref : @core.SourceRef) -> @core.SourceRef {
  let next = {
    ..source_ref,
    extra: Map([], capacity=source_ref.extra.length()),
  }
  for entry in source_ref.extra.to_array() {
    if !entry.0.has_prefix("ir_") {
      next.extra.set(entry.0, entry.1)
    }
  }
  next
}

///|
fn generic_inline_kind_name(kind : String?) -> @core.InlineKind? {
  match kind {
    Some("text") => Some(@core.InlineKind::Text)
    Some("line_break") => Some(@core.InlineKind::LineBreak)
    Some("link") => Some(@core.InlineKind::Link)
    Some("image") => Some(@core.InlineKind::Image)
    Some("code") => Some(@core.InlineKind::Code)
    _ => None
  }
}

///|
fn table_cell_span_range(row_refs : Array[@core.SourceRef]) -> String? {
  if row_refs.length() == 0 {
    return None
  }
  let first = row_refs[0].cell_range.unwrap_or("")
  let last = row_refs[row_refs.length() - 1].cell_range.unwrap_or("")
  let first_start = cell_range_start(first)
  let last_end = cell_range_end(last)
  if first_start == "" || last_end == "" {
    None
  } else {
    Some(first_start + ":" + last_end)
  }
}

///|
fn cell_range_start(cell_range : String) -> String {
  let trimmed = cell_range.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  match trimmed.split_once(":") {
    Some((head, _)) => head.trim().to_owned()
    None => trimmed
  }
}

///|
fn cell_range_end(cell_range : String) -> String {
  let trimmed = cell_range.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  match trimmed.split_once(":") {
    Some((_, tail)) => tail.trim().to_owned()
    None => trimmed
  }
}

///|
fn normalize_block_text(block : @core.CoreBlock) -> @core.CoreBlock {
  @core.block_with_children(
    { ..block, text: block.text.trim().to_owned() },
    block.children.map(child => normalize_block_text(child)),
  )
}

///|
fn normalize_block_whitespace(block : @core.CoreBlock) -> @core.CoreBlock {
  let next_text = match block.kind {
    @core.BlockKind::Code
    | @core.BlockKind::Raw
    | @core.BlockKind::BlockQuote
    | @core.BlockKind::TableCell => block.text
    _ => collapse_whitespace(block.text)
  }
  @core.block_with_children(
    { ..block, text: next_text },
    block.children.map(child => normalize_block_whitespace(child)),
  )
}

///|
fn collapse_whitespace(text : String) -> String {
  let out : Array[Char] = []
  let mut prev_space = false
  for ch in text.to_array() {
    let is_space = ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'
    if is_space {
      if !prev_space {
        out.push(' ')
      }
    } else {
      out.push(ch)
    }
    prev_space = is_space
  }
  String::from_array(out).trim().to_owned()
}
