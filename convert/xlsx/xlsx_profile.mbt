///|
fn xlsx_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_XLSX") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
pub struct XlsxProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
pub struct XlsxProfileReport {
  input_path : String
  stages : Array[XlsxProfileStage]
}

///|
fn new_xlsx_profile_report(input_path : String) -> XlsxProfileReport {
  { input_path, stages: [] }
}

///|
fn xlsx_profile_push_stage(
  report : XlsxProfileReport?,
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
pub fn xlsx_profile_add_stage(
  report : XlsxProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  xlsx_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
fn xlsx_profile_record_sheet(
  report : XlsxProfileReport?,
  sheet : XlsxSheetModel,
) -> Unit {
  let mut table_cells = 0
  for row in sheet.table_rows {
    table_cells = table_cells + row.length()
  }
  xlsx_profile_push_stage(
    report,
    "worksheet_summary:" + sheet.name,
    0,
    Some(
      "supported=" +
      sheet.is_supported_worksheet.to_string() +
      " has_xml=" +
      sheet.has_sheet_xml.to_string() +
      " cells=" +
      sheet.cells.length().to_string() +
      " merged_ranges=" +
      sheet.merged_ranges.length().to_string() +
      " table_rows=" +
      sheet.table_rows.length().to_string() +
      " table_cells=" +
      table_cells.to_string() +
      " used_range=" +
      sheet.used_min_row.to_string() +
      "," +
      sheet.used_min_col.to_string() +
      "-" +
      sheet.used_max_row.to_string() +
      "," +
      sheet.used_max_col.to_string(),
    ),
  )
}

///|
pub fn xlsx_profile_render_report(report : XlsxProfileReport) -> String {
  let lines : Array[String] = []
  lines.push("xlsx_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "xlsx_profile summary stages=" +
    report.stages.length().to_string() +
    " total_elapsed_ms=" +
    total_elapsed_ms.to_string(),
  )

  for stage in report.stages {
    let detail = match stage.detail {
      Some(text) =>
        if text.trim() == "" {
          ""
        } else {
          " detail=" + text.trim().to_owned()
        }
      None => ""
    }
    let pct = if total_elapsed_ms == 0 {
      "0.0"
    } else {
      ((stage.elapsed_ms.to_int().to_double() *
      1000.0 /
      total_elapsed_ms.to_int().to_double())
      .to_int()
      .to_double() /
      10.0).to_string()
    }
    lines.push(
      "xlsx_profile stage=" +
      stage.name +
      " elapsed_ms=" +
      stage.elapsed_ms.to_string() +
      " pct=" +
      pct +
      detail,
    )
  }

  lines.join("\n")
}
