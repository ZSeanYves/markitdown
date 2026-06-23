///|
pub struct CoreIRBuilder {
  build : (@core.IRInput) -> @core.DocumentIR
}

///|
pub struct PassContext {
  debug : Bool
  mode_name : String
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
pub fn make_pass_context(debug : Bool, mode_name : String) -> PassContext {
  { debug, mode_name }
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
    collect_asset_refs_pass(),
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
pub fn assemble_section_tree_pass() -> IRPass {
  {
    name: "AssembleSectionTreePass",
    run: fn(
      document : @core.DocumentIR,
      context : PassContext,
    ) -> @core.DocumentIR {
      if context.debug {
        document.diagnostics.warnings.push(
          "AssembleSectionTreePass skeleton only",
        )
      }
      document
    },
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
  let table_rows : Array[Array[String]] = []
  let table_row_refs : Array[@core.SourceRef] = []
  let table_cell_refs : Array[Array[@core.SourceRef]] = []
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
          let snapshot : Array[String] = []
          snapshot.append(current_row[:])
          table_rows.push(snapshot)
          let ref_snapshot : Array[@core.SourceRef] = []
          ref_snapshot.append(current_row_refs[:])
          table_cell_refs.push(ref_snapshot)
          let row_ref = event.source_ref.unwrap_or(
            if current_row_refs.length() > 0 {
              current_row_refs[0]
            } else {
              @core.empty_source_ref()
            },
          )
          table_row_refs.push(row_ref)
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
    let first_row_ref = table_row_refs[0]
    let last_row_ref = table_row_refs[table_row_refs.length() - 1]
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
      table_cell_span_range(table_row_refs),
    )
    let table = @core.make_block(
      @core.BlockKind::Table,
      "table",
      source_ref=table_ref,
    )
    table.attrs.set("header_rows", "1")
    document.diagnostics.metrics.set("table_count", "1")
    for i in 0..<table_rows.length() {
      let row = table_rows[i]
      let row_ref = table_row_refs[i]
      let cell_refs = table_cell_refs[i]
      let row_block = @core.make_block(
        @core.BlockKind::TableRow,
        row.join(" | "),
        source_ref=row_ref,
      )
      for cell_index in 0..<row.length() {
        let cell = row[cell_index]
        let cell_ref = if cell_index < cell_refs.length() {
          cell_refs[cell_index]
        } else {
          row_ref
        }
        row_block.children.push(
          @core.make_block(
            @core.BlockKind::TableCell,
            cell,
            source_ref=cell_ref,
          ),
        )
      }
      table.children.push(row_block)
    }
    document.blocks.push(table)
  }
  document
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
