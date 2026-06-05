///|
/// One internal timing sample captured during profiled XLSX parsing.
pub(all) struct XlsxParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal parse-stage report used for benchmark attribution.
pub(all) struct XlsxParseProfileReport {
  stages : Array[XlsxParseProfileStage]
}

///|
/// Profiled parse result pairing the normal workbook model with internal
/// timing breakdown data.
pub(all) struct XlsxProfiledWorkbook {
  workbook : XlsxWorkbook
  report : XlsxParseProfileReport
}

///|
fn new_xlsx_parse_profile_report() -> XlsxParseProfileReport {
  { stages: [] }
}

///|
fn xlsx_parse_profile_push_stage(
  report : XlsxParseProfileReport?,
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
fn xlsx_parse_profile_stage_started(report : XlsxParseProfileReport?) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn xlsx_parse_profile_stage_finished(
  report : XlsxParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      xlsx_parse_profile_push_stage(report, name, @env.now() - started, detail)
    None => ()
  }
}
