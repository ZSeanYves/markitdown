///|
/// One internal timing sample captured during profiled DOCX parsing.
pub(all) struct DocxParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal parse-stage report used for benchmark attribution.
pub(all) struct DocxParseProfileReport {
  stages : Array[DocxParseProfileStage]
}

///|
/// Profiled parse result pairing the normal semantic document with internal
/// timing breakdown data.
pub(all) struct DocxProfiledDocument {
  document : DocxDocument
  report : DocxParseProfileReport
}

///|
priv struct DocxParseProfileTotals {
  inline_scan_elapsed_ms : Ref[UInt64]
  hyperlink_resolution_elapsed_ms : Ref[UInt64]
  media_resolution_elapsed_ms : Ref[UInt64]
}

///|
fn new_docx_parse_profile_report() -> DocxParseProfileReport {
  { stages: [] }
}

///|
fn new_docx_parse_profile_totals() -> DocxParseProfileTotals {
  {
    inline_scan_elapsed_ms: { val: 0 },
    hyperlink_resolution_elapsed_ms: { val: 0 },
    media_resolution_elapsed_ms: { val: 0 },
  }
}

///|
fn docx_parse_profile_push_stage(
  report : DocxParseProfileReport?,
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
fn docx_parse_profile_stage_started(report : DocxParseProfileReport?) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn docx_parse_profile_stage_finished(
  report : DocxParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      docx_parse_profile_push_stage(report, name, @env.now() - started, detail)
    None => ()
  }
}

///|
fn docx_parse_profile_add_elapsed(
  total : Ref[UInt64]?,
  started : UInt64,
) -> Unit {
  match total {
    Some(cell) => cell.val = cell.val + (@env.now() - started)
    None => ()
  }
}

///|
fn docx_parse_profile_finish_totals(
  report : DocxParseProfileReport?,
  totals : DocxParseProfileTotals?,
) -> Unit {
  match totals {
    Some(values) => {
      docx_parse_profile_push_stage(
        report,
        "inline_scan",
        values.inline_scan_elapsed_ms.val,
        None,
      )
      docx_parse_profile_push_stage(
        report,
        "hyperlink_resolution",
        values.hyperlink_resolution_elapsed_ms.val,
        None,
      )
      docx_parse_profile_push_stage(
        report,
        "media_resolution",
        values.media_resolution_elapsed_ms.val,
        None,
      )
    }
    None => ()
  }
}
