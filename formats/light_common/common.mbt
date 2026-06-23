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
pub fn apply_readiness_metrics(
  diagnostics : @core.Diagnostics,
  format_name : String,
  readiness_status : String,
) -> Unit {
  diagnostics.metrics.set("format_family", "textlike")
  diagnostics.metrics.set("native_impl_location", "formats")
  diagnostics.metrics.set("migration_stage", "stage_b_root_pipeline")
  diagnostics.metrics.set("default_route", "not_switched")
  diagnostics.metrics.set("legacy_runtime_dependency", "none")
  diagnostics.metrics.set("legacy_behavior_reference", "reference_only")
  diagnostics.metrics.set("readiness_status", readiness_status)
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
