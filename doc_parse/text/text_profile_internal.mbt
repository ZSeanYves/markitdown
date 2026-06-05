///|
/// One internal timing sample captured during profiled text parsing.
pub(all) struct TextParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal parse-stage report used for benchmark attribution.
pub(all) struct TextParseProfileReport {
  stages : Array[TextParseProfileStage]
}

///|
/// Profiled parse result pairing the normal text document with internal timing
/// breakdown data.
pub(all) struct TextProfiledDocument {
  document : TextDocument
  report : TextParseProfileReport
}

///|
priv struct TextParseProfileTotals {
  line_build_elapsed_ms : Ref[UInt64]
  paragraph_build_elapsed_ms : Ref[UInt64]
}

///|
fn new_text_parse_profile_report() -> TextParseProfileReport {
  { stages: [] }
}

///|
fn new_text_parse_profile_totals() -> TextParseProfileTotals {
  { line_build_elapsed_ms: { val: 0 }, paragraph_build_elapsed_ms: { val: 0 } }
}

///|
fn text_parse_profile_push_stage(
  report : TextParseProfileReport?,
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
fn text_parse_profile_stage_started(report : TextParseProfileReport?) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn text_parse_profile_stage_finished(
  report : TextParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      text_parse_profile_push_stage(report, name, @env.now() - started, detail)
    None => ()
  }
}

///|
fn text_parse_profile_add_elapsed(
  total : Ref[UInt64]?,
  started : UInt64,
) -> Unit {
  match total {
    Some(cell) => cell.val = cell.val + (@env.now() - started)
    None => ()
  }
}

///|
fn text_parse_profile_finish_totals(
  report : TextParseProfileReport?,
  totals : TextParseProfileTotals?,
) -> Unit {
  match totals {
    Some(values) => {
      text_parse_profile_push_stage(
        report,
        "line_build",
        values.line_build_elapsed_ms.val,
        None,
      )
      text_parse_profile_push_stage(
        report,
        "paragraph_build",
        values.paragraph_build_elapsed_ms.val,
        None,
      )
    }
    None => ()
  }
}
