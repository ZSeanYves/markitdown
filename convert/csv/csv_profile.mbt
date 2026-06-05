///|
fn csv_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_CSV") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
pub struct CsvProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
pub struct CsvProfileReport {
  input_path : String
  format_label : String
  stages : Array[CsvProfileStage]
}

///|
fn new_csv_profile_report(
  input_path : String,
  format_label : String,
) -> CsvProfileReport {
  { input_path, format_label, stages: [] }
}

///|
fn csv_profile_push_stage(
  report : CsvProfileReport?,
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
pub fn csv_profile_add_stage(
  report : CsvProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  csv_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
pub fn csv_profile_render_report(report : CsvProfileReport) -> String {
  let lines : Array[String] = []
  lines.push(
    "csv_profile input=" + report.input_path + " format=" + report.format_label,
  )

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "csv_profile summary stages=" +
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
      "csv_profile stage=" +
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
