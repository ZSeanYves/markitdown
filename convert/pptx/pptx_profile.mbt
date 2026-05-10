///|
fn pptx_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_PPTX_CONVERT") {
    Some(raw) => {
      let lower = raw.trim().to_lower()
      lower == "1" || lower == "true" || lower == "yes" || lower == "on"
    }
    None => false
  }
}

///|
priv struct PptxConvertProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
priv struct PptxConvertProfileReport {
  input_path : String
  stages : Array[PptxConvertProfileStage]
}

///|
fn new_pptx_convert_profile_report(
  input_path : String,
) -> PptxConvertProfileReport {
  { input_path, stages: [] }
}

///|
fn pptx_convert_profile_push_stage(
  report : PptxConvertProfileReport?,
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
fn pptx_convert_profile_add_stage(
  report : PptxConvertProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  pptx_convert_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
fn pptx_convert_profile_render_report(
  report : PptxConvertProfileReport,
) -> String {
  let lines : Array[String] = []
  lines.push("pptx_convert_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "pptx_convert_profile summary stages=" +
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
      "pptx_convert_profile stage=" +
      stage.name +
      " elapsed_ms=" +
      stage.elapsed_ms.to_string() +
      detail,
    )
  }

  lines.join("\n")
}

///|
fn maybe_write_pptx_convert_profile_log(
  report : PptxConvertProfileReport?,
) -> Unit {
  let path = match @sys.get_env_var("MARKITDOWN_PROFILE_PPTX_CONVERT_PATH") {
    Some(raw) => raw.trim().to_owned()
    None => ""
  }
  if path == "" {
    return
  }

  match report {
    None => ()
    Some(rep) => {
      let body = pptx_convert_profile_render_report(rep) + "\n"
      @fs.write_string_to_file(path, body, encoding="utf8") catch {
        _ => ()
      }
    }
  }
}
