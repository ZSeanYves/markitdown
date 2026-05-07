///|
fn yaml_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_YAML") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
pub struct YamlProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
pub struct YamlProfileReport {
  input_path : String
  stages : Array[YamlProfileStage]
}

///|
let yaml_active_profile_report : Ref[YamlProfileReport?] = { val: None }

///|
fn new_yaml_profile_report(input_path : String) -> YamlProfileReport {
  { input_path, stages: [] }
}

///|
fn yaml_profile_push_stage(
  report : YamlProfileReport?,
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
pub fn yaml_profile_add_stage(
  report : YamlProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  yaml_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
fn yaml_profile_set_active(report : YamlProfileReport?) -> Unit {
  yaml_active_profile_report.val = report
}

///|
fn yaml_profile_add_active_stage(
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  yaml_profile_push_stage(
    yaml_active_profile_report.val,
    name,
    elapsed_ms,
    detail,
  )
}

///|
pub fn yaml_profile_render_report(report : YamlProfileReport) -> String {
  let lines : Array[String] = []
  lines.push("yaml_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "yaml_profile summary stages=" +
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
      "yaml_profile stage=" +
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
