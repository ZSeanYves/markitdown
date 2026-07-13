///|
fn render_debug_json_events(
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
) -> String {
  let items : Array[String] = []
  for event in events {
    items.push(render_event_json(event))
  }
  let fields : Array[String] = []
  fields.push("\"event_count\": " + events.length().to_string())
  fields.push("\"events\": " + @core.array_json(items))
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  @core.object_json(fields)
}

///|
fn render_debug_json_blocks(
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
  context : RenderContext,
) -> String {
  let block_items : Array[String] = []
  for block in blocks {
    block_items.push(render_block_json(block))
  }
  let asset_items : Array[String] = []
  let assets = context.assets.unwrap_or([])
  for asset in assets {
    asset_items.push(render_asset_json(asset))
  }
  let fields : Array[String] = []
  fields.push("\"block_count\": " + blocks.length().to_string())
  fields.push("\"blocks\": " + @core.array_json(block_items))
  fields.push("\"asset_count\": " + assets.length().to_string())
  fields.push("\"assets\": " + @core.array_json(asset_items))
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  @core.object_json(fields)
}

///|
fn render_event_json(event : @core.CoreEvent) -> String {
  let fields : Array[String] = []
  fields.push("\"kind\": " + @core.json_string(event_kind_name(event.kind)))
  fields.push("\"text\": " + @core.json_string(event.text))
  fields.push("\"source_ref\": " + render_source_ref_json(event.source_ref))
  @core.object_json(fields)
}

///|
fn event_kind_name(kind : @core.EventKind) -> String {
  match kind {
    @core.EventKind::StartDocument => "start_document"
    @core.EventKind::EndDocument => "end_document"
    @core.EventKind::StartBlock(block_kind) =>
      "start_block:" + @core.block_kind_name(block_kind)
    @core.EventKind::EndBlock(block_kind) =>
      "end_block:" + @core.block_kind_name(block_kind)
    @core.EventKind::Text => "text"
    @core.EventKind::TextLine => "text_line"
    @core.EventKind::BlankLine => "blank_line"
    @core.EventKind::Cell => "cell"
    @core.EventKind::RowBreak => "row_break"
    @core.EventKind::StructureStart => "structure_start"
    @core.EventKind::StructureEnd => "structure_end"
    @core.EventKind::Key => "key"
    @core.EventKind::Scalar => "scalar"
  }
}

///|
fn render_block_json(block : @core.CoreBlock) -> String {
  let fields : Array[String] = []
  fields.push(
    "\"kind\": " + @core.json_string(@core.block_kind_name(block.kind)),
  )
  fields.push("\"text\": " + @core.json_string(block.text))
  fields.push("\"attrs\": " + render_string_map_json(block.attrs))
  fields.push(
    "\"rich_inlines\": " + render_rich_inlines_json(block.rich_inlines),
  )
  fields.push(
    "\"source_ref\": " + render_source_ref_json(@core.block_source_ref(block)),
  )
  let child_items : Array[String] = []
  for child in block.children {
    child_items.push(render_block_json(child))
  }
  fields.push("\"children\": " + @core.array_json(child_items))
  @core.object_json(fields)
}

///|
fn render_string_map_json(entries : Map[String, String]) -> String {
  let fields : Array[String] = []
  let items = entries.to_array()
  items.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in items {
    fields.push(@core.json_string(entry.0) + ": " + @core.json_string(entry.1))
  }
  @core.object_json(fields)
}

///|
fn render_source_ref_json(source_ref : @core.SourceRef?) -> String {
  match source_ref {
    None => "null"
    Some(value) => {
      let fields : Array[String] = []
      fields.push("\"file_id\": " + @core.json_string_opt(value.file_id))
      fields.push("\"format\": " + @core.json_string_opt(value.format))
      fields.push(
        "\"line_start\": " +
        value.line_start.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"line_end\": " +
        value.line_end.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"json_pointer\": " + @core.json_string_opt(value.json_pointer),
      )
      fields.push("\"xpath\": " + @core.json_string_opt(value.xpath))
      fields.push("\"yaml_path\": " + @core.json_string_opt(value.yaml_path))
      fields.push("\"html_path\": " + @core.json_string_opt(value.html_path))
      fields.push(
        "\"markdown_path\": " + @core.json_string_opt(value.markdown_path),
      )
      fields.push(
        "\"container_path\": " + @core.json_string_opt(value.container_path),
      )
      fields.push("\"entry_path\": " + @core.json_string_opt(value.entry_path))
      fields.push(
        "\"entry_index\": " +
        value.entry_index.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"entry_format\": " + @core.json_string_opt(value.entry_format),
      )
      fields.push("\"inner_path\": " + @core.json_string_opt(value.inner_path))
      fields.push("\"sheet\": " + @core.json_string_opt(value.sheet))
      fields.push("\"cell_range\": " + @core.json_string_opt(value.cell_range))
      fields.push(
        "\"slide\": " + value.slide.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push("\"shape_id\": " + @core.json_string_opt(value.shape_id))
      fields.push(
        "\"relationship_id\": " + @core.json_string_opt(value.relationship_id),
      )
      fields.push(
        "\"chapter_href\": " + @core.json_string_opt(value.chapter_href),
      )
      let extra_fields : Array[String] = []
      let extra_entries = value.extra.to_array()
      extra_entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
      for entry in extra_entries {
        extra_fields.push(
          @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
        )
      }
      fields.push("\"extra\": " + @core.object_json(extra_fields))
      @core.object_json(fields)
    }
  }
}

///|
fn render_source_map_json(source_map : @core.SourceMap?) -> String {
  match source_map {
    None => "null"
    Some(value) => {
      let block_entries : Array[String] = []
      for entry in value.block_entries {
        block_entries.push(render_source_map_entry_json(entry))
      }
      let asset_entries : Array[String] = []
      for entry in value.asset_entries {
        asset_entries.push(render_source_map_entry_json(entry))
      }
      let fields : Array[String] = []
      fields.push(
        "\"document_ref\": " + render_source_ref_json(value.document_ref),
      )
      fields.push("\"block_entries\": " + @core.array_json(block_entries))
      fields.push("\"asset_entries\": " + @core.array_json(asset_entries))
      @core.object_json(fields)
    }
  }
}

///|
fn render_source_map_entry_json(entry : @core.SourceMapEntry) -> String {
  let refs : Array[String] = []
  for source_ref in entry.refs {
    refs.push(render_source_ref_json(Some(source_ref)))
  }
  let merged_from : Array[String] = []
  for source_ref in entry.merged_from {
    merged_from.push(render_source_ref_json(Some(source_ref)))
  }
  let fields : Array[String] = []
  fields.push("\"primary_ref\": " + render_source_ref_json(entry.primary_ref))
  fields.push("\"refs\": " + @core.array_json(refs))
  fields.push("\"merged_from\": " + @core.array_json(merged_from))
  fields.push(
    "\"confidence\": " +
    entry.confidence.map(value => value.to_string()).unwrap_or("null"),
  )
  fields.push("\"relation\": " + @core.json_string_opt(entry.relation))
  @core.object_json(fields)
}

///|
fn render_rich_inlines_json(rich_inlines : Array[@core.CoreInline]?) -> String {
  match rich_inlines {
    None => "null"
    Some(inlines) => {
      let items : Array[String] = []
      for inline in inlines {
        let fields : Array[String] = []
        fields.push(
          "\"kind\": " + @core.json_string(@core.inline_kind_name(inline.kind)),
        )
        fields.push("\"text\": " + @core.json_string(inline.text))
        fields.push("\"href\": " + @core.json_string_opt(inline.href))
        fields.push("\"title\": " + @core.json_string_opt(inline.title))
        fields.push(
          "\"source_ref\": " + render_source_ref_json(inline.source_ref),
        )
        items.push(@core.object_json(fields))
      }
      @core.array_json(items)
    }
  }
}

///|
fn render_asset_json(asset : @core.AssetRef) -> String {
  let fields : Array[String] = []
  fields.push(
    "\"asset_kind\": " +
    @core.json_string(@core.asset_kind_name(asset.asset_kind)),
  )
  fields.push("\"asset_id\": " + @core.json_string(asset.asset_id))
  fields.push("\"path\": " + @core.json_string_opt(asset.path))
  fields.push("\"mime_type\": " + @core.json_string_opt(asset.mime_type))
  fields.push("\"source_ref\": " + render_source_ref_json(asset.source_ref))
  let attr_fields : Array[String] = []
  let entries = asset.attrs.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    attr_fields.push(
      @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
    )
  }
  fields.push("\"attrs\": " + @core.object_json(attr_fields))
  @core.object_json(fields)
}

///|
fn render_document_metadata_json(metadata : @core.DocumentMetadata) -> String {
  let fields : Array[String] = []
  let entries = metadata.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    fields.push(@core.json_string(entry.0) + ": " + render_json_value(entry.1))
  }
  @core.object_json(fields)
}

///|
fn render_json_value(value : @core.JsonValue) -> String {
  match value {
    @core.JsonValue::String(text) => @core.json_string(text)
    @core.JsonValue::Number(text) => text
    @core.JsonValue::Bool(flag) => if flag { "true" } else { "false" }
    @core.JsonValue::Null => "null"
    @core.JsonValue::Array(items) =>
      @core.array_json(items.map(item => render_json_value(item)))
    @core.JsonValue::Object(fields) => {
      let pairs : Array[String] = []
      let entries = fields.to_array()
      entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
      for entry in entries {
        pairs.push(
          @core.json_string(entry.0) + ": " + render_json_value(entry.1),
        )
      }
      @core.object_json(pairs)
    }
  }
}

///|
fn render_diagnostics_json(diagnostics : @core.Diagnostics) -> String {
  let metric_fields : Array[String] = []
  let entries = diagnostics.metrics.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    metric_fields.push(
      @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
    )
  }
  let fields : Array[String] = []
  fields.push(
    "\"parser_name\": " + @core.json_string_opt(diagnostics.parser_name),
  )
  fields.push(
    "\"parser_mode\": " + @core.json_string_opt(diagnostics.parser_mode),
  )
  fields.push(
    "\"convert_mode\": " + @core.json_string_opt(diagnostics.convert_mode),
  )
  fields.push(
    "\"fidelity_mode\": " + @core.json_string_opt(diagnostics.fidelity_mode),
  )
  fields.push(
    "\"output_mode\": " + @core.json_string_opt(diagnostics.output_mode),
  )
  fields.push(
    "\"input_kind\": " + @core.json_string_opt(diagnostics.input_kind),
  )
  fields.push(
    "\"detected_format\": " + @core.json_string_opt(diagnostics.detected_format),
  )
  fields.push("\"warnings\": " + @core.string_array_json(diagnostics.warnings))
  fields.push("\"errors\": " + @core.string_array_json(diagnostics.errors))
  fields.push(
    "\"degraded_features\": " +
    @core.string_array_json(diagnostics.degraded_features),
  )
  fields.push(
    "\"same_mode_degradation\": " +
    @core.string_array_json(diagnostics.same_mode_degradation),
  )
  fields.push(
    "\"same_mode_strategy_switches\": " +
    @core.string_array_json(diagnostics.same_mode_strategy_switches),
  )
  fields.push(
    "\"fallback_trace\": " + @core.string_array_json(diagnostics.fallback_trace),
  )
  fields.push(
    "\"pass_trace\": " + @core.string_array_json(diagnostics.pass_trace),
  )
  let dependency_items : Array[String] = []
  for dependency in diagnostics.dependency_diagnostics {
    let dependency_fields : Array[String] = []
    dependency_fields.push("\"kind\": " + @core.json_string(dependency.kind))
    dependency_fields.push("\"title\": " + @core.json_string(dependency.title))
    dependency_fields.push(
      "\"summary\": " + @core.json_string(dependency.summary),
    )
    dependency_fields.push(
      "\"status\": " +
      @core.json_string(
        @core.dependency_diagnostic_status_name(dependency.status),
      ),
    )
    dependency_fields.push(
      "\"macos_commands\": " +
      @core.string_array_json(dependency.macos_commands),
    )
    dependency_fields.push(
      "\"ubuntu_commands\": " +
      @core.string_array_json(dependency.ubuntu_commands),
    )
    dependency_fields.push(
      "\"footer\": " + @core.json_string_opt(dependency.footer),
    )
    dependency_items.push(@core.object_json(dependency_fields))
  }
  fields.push(
    "\"dependency_diagnostics\": " + @core.array_json(dependency_items),
  )
  fields.push("\"metrics\": " + @core.object_json(metric_fields))
  @core.object_json(fields)
}
