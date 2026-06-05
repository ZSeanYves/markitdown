///|
pub struct JsonProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
pub struct JsonProfileReport {
  input_path : String
  stages : Array[JsonProfileStage]
}

///|
fn new_json_profile_report(input_path : String) -> JsonProfileReport {
  { input_path, stages: [] }
}

///|
fn json_profile_push_stage(
  report : JsonProfileReport?,
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
pub fn json_profile_add_stage(
  report : JsonProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  json_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
pub fn json_profile_render_report(report : JsonProfileReport) -> String {
  let lines : Array[String] = []
  lines.push("json_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "json_profile summary stages=" +
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
      "json_profile stage=" +
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
