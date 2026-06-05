///|
/// One internal timing sample captured during profiled JSON parsing.
pub(all) struct JsonParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal parse-stage report used for benchmark attribution.
pub(all) struct JsonParseProfileReport {
  stages : Array[JsonParseProfileStage]
}

///|
/// Profiled parse result pairing the normal JSON document with internal timing
/// breakdown data.
pub(all) struct JsonProfiledDocument {
  document : JsonDocument
  report : JsonParseProfileReport
}

///|
priv struct JsonParseProfileTotals {
  parse_object_elapsed_ms : Ref[UInt64]
  parse_array_elapsed_ms : Ref[UInt64]
  parse_string_elapsed_ms : Ref[UInt64]
  parse_number_elapsed_ms : Ref[UInt64]
}

///|
fn new_json_parse_profile_report() -> JsonParseProfileReport {
  { stages: [] }
}

///|
fn new_json_parse_profile_totals() -> JsonParseProfileTotals {
  {
    parse_object_elapsed_ms: { val: 0 },
    parse_array_elapsed_ms: { val: 0 },
    parse_string_elapsed_ms: { val: 0 },
    parse_number_elapsed_ms: { val: 0 },
  }
}

///|
fn json_parse_profile_push_stage(
  report : JsonParseProfileReport?,
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
fn json_parse_profile_stage_started(report : JsonParseProfileReport?) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn json_parse_profile_stage_finished(
  report : JsonParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      json_parse_profile_push_stage(report, name, @env.now() - started, detail)
    None => ()
  }
}

///|
fn json_parse_profile_add_elapsed(
  total : Ref[UInt64]?,
  started : UInt64,
) -> Unit {
  match total {
    Some(cell) => cell.val = cell.val + (@env.now() - started)
    None => ()
  }
}

///|
fn json_parse_profile_finish_totals(
  report : JsonParseProfileReport?,
  totals : JsonParseProfileTotals?,
) -> Unit {
  match totals {
    Some(values) => {
      json_parse_profile_push_stage(
        report,
        "parse_object",
        values.parse_object_elapsed_ms.val,
        None,
      )
      json_parse_profile_push_stage(
        report,
        "parse_array",
        values.parse_array_elapsed_ms.val,
        None,
      )
      json_parse_profile_push_stage(
        report,
        "parse_string",
        values.parse_string_elapsed_ms.val,
        None,
      )
      json_parse_profile_push_stage(
        report,
        "parse_number",
        values.parse_number_elapsed_ms.val,
        None,
      )
    }
    None => ()
  }
}
