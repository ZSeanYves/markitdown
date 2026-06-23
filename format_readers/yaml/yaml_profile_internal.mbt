///|
/// One internal timing sample captured during profiled YAML parsing.
pub struct YamlParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal parse-stage report used for benchmark attribution.
pub struct YamlParseProfileReport {
  stages : Array[YamlParseProfileStage]
}

///|
/// Profiled parse result pairing the normal semantic document with internal
/// timing breakdown data.
pub struct YamlProfiledDocument {
  document : YamlDocument
  report : YamlParseProfileReport
}

///|
priv struct YamlParseProfileTotals {
  normalize_lines_elapsed_ms : Ref[UInt64]
  scan_lines_elapsed_ms : Ref[UInt64]
  parse_mapping_elapsed_ms : Ref[UInt64]
  parse_sequence_elapsed_ms : Ref[UInt64]
  parse_scalar_elapsed_ms : Ref[UInt64]
}

///|
fn new_yaml_parse_profile_report() -> YamlParseProfileReport {
  { stages: [] }
}

///|
fn new_yaml_parse_profile_totals() -> YamlParseProfileTotals {
  {
    normalize_lines_elapsed_ms: { val: 0 },
    scan_lines_elapsed_ms: { val: 0 },
    parse_mapping_elapsed_ms: { val: 0 },
    parse_sequence_elapsed_ms: { val: 0 },
    parse_scalar_elapsed_ms: { val: 0 },
  }
}

///|
fn yaml_parse_profile_push_stage(
  report : YamlParseProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(rep) => rep.stages.push({ name, elapsed_ms, detail })
    None => ()
  }
}

///|
fn yaml_parse_profile_stage_started(report : YamlParseProfileReport?) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn yaml_parse_profile_stage_finished(
  report : YamlParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      yaml_parse_profile_push_stage(report, name, @env.now() - started, detail)
    None => ()
  }
}

///|
fn yaml_parse_profile_add_elapsed(
  total : Ref[UInt64]?,
  started : UInt64,
) -> Unit {
  match total {
    Some(cell) => cell.val = cell.val + (@env.now() - started)
    None => ()
  }
}

///|
fn yaml_parse_profile_finish_totals(
  report : YamlParseProfileReport?,
  totals : YamlParseProfileTotals?,
) -> Unit {
  match totals {
    Some(values) => {
      yaml_parse_profile_push_stage(
        report,
        "normalize_lines",
        values.normalize_lines_elapsed_ms.val,
        None,
      )
      yaml_parse_profile_push_stage(
        report,
        "scan_lines",
        values.scan_lines_elapsed_ms.val,
        None,
      )
      yaml_parse_profile_push_stage(
        report,
        "parse_mapping",
        values.parse_mapping_elapsed_ms.val,
        None,
      )
      yaml_parse_profile_push_stage(
        report,
        "parse_sequence",
        values.parse_sequence_elapsed_ms.val,
        None,
      )
      yaml_parse_profile_push_stage(
        report,
        "parse_scalar",
        values.parse_scalar_elapsed_ms.val,
        None,
      )
    }
    None => ()
  }
}
