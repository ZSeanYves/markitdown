///|
fn zip_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_ZIP") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
pub struct ZipProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
pub struct ZipProfileReport {
  input_path : String
  summary_lines : Array[String]
  stages : Array[ZipProfileStage]
}

///|
fn new_zip_profile_report(input_path : String) -> ZipProfileReport {
  { input_path, summary_lines: [], stages: [] }
}

///|
pub fn zip_profile_add_summary(
  report : ZipProfileReport?,
  summary : String,
) -> Unit {
  match report {
    Some(rep) =>
      if summary.trim() != "" {
        rep.summary_lines.push(summary.trim().to_owned())
      }
    None => ()
  }
}

///|
fn zip_profile_push_stage(
  report : ZipProfileReport?,
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
pub fn zip_profile_add_stage(
  report : ZipProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  zip_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
pub fn zip_profile_render_report(report : ZipProfileReport) -> String {
  let lines : Array[String] = []
  lines.push("zip_profile input=" + report.input_path)

  for summary in report.summary_lines {
    lines.push("zip_profile " + summary)
  }

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "zip_profile summary stages=" +
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
      "zip_profile stage=" +
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
