///|
fn docx_convert_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_DOCX_CONVERT") {
    Some(raw) => {
      let lower = raw.trim().to_lower()
      lower == "1" || lower == "true" || lower == "yes" || lower == "on"
    }
    None => false
  }
}

///|
priv struct DocxConvertProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
priv struct DocxConvertProfileReport {
  input_path : String
  stages : Array[DocxConvertProfileStage]
}

///|
let active_docx_convert_profile_report : Ref[DocxConvertProfileReport?] = {
  val: None,
}

///|
fn new_docx_convert_profile_report(
  input_path : String,
) -> DocxConvertProfileReport {
  { input_path, stages: [] }
}

///|
fn docx_convert_profile_push_stage(
  report : DocxConvertProfileReport?,
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
fn docx_convert_profile_add_stage(
  report : DocxConvertProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  docx_convert_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
fn docx_convert_profile_set_active(report : DocxConvertProfileReport?) -> Unit {
  active_docx_convert_profile_report.val = report
}

///|
fn docx_convert_profile_add_active_stage(
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  docx_convert_profile_add_stage(
    active_docx_convert_profile_report.val,
    name,
    elapsed_ms,
    detail,
  )
}

///|
fn docx_convert_profile_render_report(
  report : DocxConvertProfileReport,
) -> String {
  let lines : Array[String] = []
  lines.push("docx_convert_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "docx_convert_profile summary stages=" +
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
    lines.push(
      "docx_convert_profile stage=" +
      stage.name +
      " elapsed_ms=" +
      stage.elapsed_ms.to_string() +
      detail,
    )
  }

  lines.join("\n")
}

///|
fn maybe_write_docx_convert_profile_log(
  report : DocxConvertProfileReport?,
) -> Unit {
  let path = match @sys.get_env_var("MARKITDOWN_PROFILE_DOCX_CONVERT_PATH") {
    Some(raw) => raw.trim().to_owned()
    None => ""
  }
  if path == "" {
    return
  }

  match report {
    None => ()
    Some(rep) => {
      let body = docx_convert_profile_render_report(rep) + "\n"
      @fs.write_string_to_file(path, body, encoding="utf8") catch {
        _ => ()
      }
    }
  }
}
