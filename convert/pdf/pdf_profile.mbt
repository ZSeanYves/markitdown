///|
fn pdf_convert_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_PDF_CONVERT") {
    Some(raw) => {
      let lower = raw.trim().to_lower()
      lower == "1" || lower == "true" || lower == "yes" || lower == "on"
    }
    None => false
  }
}

///|
priv struct PdfConvertProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
priv struct PdfConvertProfileReport {
  input_path : String
  stages : Array[PdfConvertProfileStage]
}

///|
let active_pdf_convert_profile_report : Ref[PdfConvertProfileReport?] = {
  val: None,
}

///|
fn new_pdf_convert_profile_report(
  input_path : String,
) -> PdfConvertProfileReport {
  { input_path, stages: [] }
}

///|
fn pdf_convert_profile_add_stage(
  report : PdfConvertProfileReport?,
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
fn pdf_convert_profile_stage_start(
  report : PdfConvertProfileReport?,
) -> UInt64? {
  match report {
    Some(_) => Some(@env.now())
    None => None
  }
}

///|
fn pdf_convert_profile_add_stage_since(
  report : PdfConvertProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  pdf_convert_profile_add_stage(report, name, @env.now() - started, detail)
}

///|
fn pdf_convert_profile_set_active(report : PdfConvertProfileReport?) -> Unit {
  active_pdf_convert_profile_report.val = report
}

///|
fn pdf_convert_profile_render_report(
  report : PdfConvertProfileReport,
) -> String {
  let lines : Array[String] = []
  lines.push("pdf_convert_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "pdf_convert_profile summary stages=" +
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
      "pdf_convert_profile stage=" +
      stage.name +
      " elapsed_ms=" +
      stage.elapsed_ms.to_string() +
      detail,
    )
  }

  lines.join("\n")
}

///|
fn maybe_write_pdf_convert_profile_log(
  report : PdfConvertProfileReport?,
) -> Unit {
  let path = match @sys.get_env_var("MARKITDOWN_PROFILE_PDF_CONVERT_PATH") {
    Some(raw) => raw.trim().to_owned()
    None => ""
  }
  if path == "" {
    return
  }

  match report {
    None => ()
    Some(rep) => {
      let body = pdf_convert_profile_render_report(rep) + "\n"
      @fs.write_string_to_file(path, body, encoding="utf8") catch {
        _ => ()
      }
    }
  }
}
