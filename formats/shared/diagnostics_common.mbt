///|
pub fn input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
pub fn requested_mode_name(context : @parser.ParseContext) -> String {
  match context.requested_mode {
    Some(mode) => @parser.mode_name(mode)
    None => "default"
  }
}

///|
pub fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
pub fn empty_parser_diagnostics(
  parser_name : String,
  parser_mode : @parser.ParserMode,
  source : @input.InputSource,
  format_name : String,
) -> @core.Diagnostics {
  @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(parser_name),
      Some(@parser.mode_name(parser_mode)),
    ),
    Some(input_kind_name(source.kind)),
    Some(format_name),
  )
}

///|
pub fn init_parser_route_metrics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
  format_name : String,
  parser_name : String,
  parser_mode : @parser.ParserMode,
  effective_mode : @parser.ParserMode,
  ir_input_kind : String,
  event_granularity : String,
  event_semantics : String,
) -> Unit {
  diagnostics.metrics.set("parser_name", parser_name)
  diagnostics.metrics.set("parser_mode", @parser.mode_name(parser_mode))
  diagnostics.metrics.set("input_kind", input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", format_name)
  diagnostics.metrics.set("requested_mode", requested_mode_name(context))
  diagnostics.metrics.set("effective_mode", @parser.mode_name(effective_mode))
  diagnostics.metrics.set("ir_input_kind", ir_input_kind)
  diagnostics.metrics.set("event_granularity", event_granularity)
  diagnostics.metrics.set("event_semantics", event_semantics)
}

///|
pub fn init_parser_route_metrics_with_granularity(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
  format_name : String,
  parser_name : String,
  parser_mode : @parser.ParserMode,
  effective_mode : @parser.ParserMode,
  ir_input_kind : String,
  event_granularity : @parser.StreamingGranularity,
  event_semantics : String,
) -> Unit {
  init_parser_route_metrics(
    diagnostics,
    source,
    context,
    format_name,
    parser_name,
    parser_mode,
    effective_mode,
    ir_input_kind,
    @parser.streaming_granularity_name(event_granularity),
    event_semantics,
  )
}

///|
pub fn init_parser_product_mode_metrics(
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> Unit {
  diagnostics.metrics.set(
    "fidelity_mode",
    @product.fidelity_mode_name(context.fidelity_mode),
  )
  diagnostics.metrics.set(
    "output_mode",
    @product.output_mode_name(context.output_mode),
  )
}

///|
pub fn init_parser_count_metrics(
  diagnostics : @core.Diagnostics,
  warning_count? : String = "0",
  degraded_feature_count? : String = "0",
  fallback_count? : String = "0",
  asset_count? : String = "0",
) -> Unit {
  diagnostics.metrics.set("warning_count", warning_count)
  diagnostics.metrics.set("degraded_feature_count", degraded_feature_count)
  diagnostics.metrics.set("fallback_count", fallback_count)
  diagnostics.metrics.set("asset_count", asset_count)
}

///|
pub fn refresh_parser_count_metrics(
  diagnostics : @core.Diagnostics,
  builder_input_kind : String,
) -> Unit {
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set("builder_input_kind", builder_input_kind)
}

///|
pub fn apply_product_metrics(
  diagnostics : @core.Diagnostics,
  format_name : String,
) -> Unit {
  if diagnostics.metrics.get("format_family") == None {
    diagnostics.metrics.set("format_family", "textlike")
  }
  if diagnostics.metrics.get("native_impl_location") == None {
    diagnostics.metrics.set("native_impl_location", "formats")
  }
  if diagnostics.metrics.get("product_path_enabled") == None {
    diagnostics.metrics.set("product_path_enabled", "true")
  }
  diagnostics.metrics.set("format_contract", format_name)
}

///|
pub fn count_blocks_by_kind(
  blocks : Array[@core.CoreBlock],
  kind : @core.BlockKind,
) -> Int {
  let mut count = 0
  for block in blocks {
    if block.kind == kind {
      count += 1
    }
  }
  count
}

///|
pub fn bool_string(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
pub fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
pub fn clamp_int(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

///|
pub fn count_physical_lines(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut count = 1
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  count
}
