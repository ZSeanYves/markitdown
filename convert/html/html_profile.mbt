///|
fn html_profile_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_HTML") {
    Some(raw) => {
      let lower = raw.trim().to_lower()
      lower == "1" || lower == "true" || lower == "yes" || lower == "on"
    }
    None => false
  }
}

///|
priv struct HtmlProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
priv struct HtmlProfileReport {
  input_path : String
  stages : Array[HtmlProfileStage]
  local_asset_count : Ref[Int]
  remote_asset_count : Ref[Int]
  unresolved_local_asset_count : Ref[Int]
  cached_asset_count : Ref[Int]
  asset_discovery_elapsed_ms : Ref[UInt64]
  asset_export_elapsed_ms : Ref[UInt64]
}

///|
let html_active_profile_report : Ref[HtmlProfileReport?] = { val: None }

///|
fn new_html_profile_report(input_path : String) -> HtmlProfileReport {
  {
    input_path,
    stages: [],
    local_asset_count: { val: 0 },
    remote_asset_count: { val: 0 },
    unresolved_local_asset_count: { val: 0 },
    cached_asset_count: { val: 0 },
    asset_discovery_elapsed_ms: { val: 0 },
    asset_export_elapsed_ms: { val: 0 },
  }
}

///|
fn html_profile_push_stage(
  report : HtmlProfileReport?,
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
fn html_profile_add_stage(
  report : HtmlProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  html_profile_push_stage(report, name, elapsed_ms, detail)
}

///|
fn html_profile_set_active(report : HtmlProfileReport?) -> Unit {
  html_active_profile_report.val = report
}

///|
fn profile_html_local_asset_exported() -> Unit {
  match html_active_profile_report.val {
    Some(rep) => rep.local_asset_count.val = rep.local_asset_count.val + 1
    None => ()
  }
}

///|
fn profile_html_remote_asset_candidate() -> Unit {
  match html_active_profile_report.val {
    Some(rep) => rep.remote_asset_count.val = rep.remote_asset_count.val + 1
    None => ()
  }
}

///|
fn profile_html_unresolved_local_asset() -> Unit {
  match html_active_profile_report.val {
    Some(rep) =>
      rep.unresolved_local_asset_count.val = rep.unresolved_local_asset_count.val +
        1
    None => ()
  }
}

///|
fn profile_html_cached_asset_hit() -> Unit {
  match html_active_profile_report.val {
    Some(rep) => rep.cached_asset_count.val = rep.cached_asset_count.val + 1
    None => ()
  }
}

///|
fn profile_html_asset_discovery_elapsed_ms(elapsed_ms : UInt64) -> Unit {
  match html_active_profile_report.val {
    Some(rep) =>
      rep.asset_discovery_elapsed_ms.val = rep.asset_discovery_elapsed_ms.val +
        elapsed_ms
    None => ()
  }
}

///|
fn profile_html_asset_export_elapsed_ms(elapsed_ms : UInt64) -> Unit {
  match html_active_profile_report.val {
    Some(rep) =>
      rep.asset_export_elapsed_ms.val = rep.asset_export_elapsed_ms.val +
        elapsed_ms
    None => ()
  }
}

///|
fn html_profile_render_report(report : HtmlProfileReport) -> String {
  let lines : Array[String] = []
  lines.push("html_profile input=" + report.input_path)

  let mut total_elapsed_ms : UInt64 = 0
  for stage in report.stages {
    total_elapsed_ms = total_elapsed_ms + stage.elapsed_ms
  }
  lines.push(
    "html_profile summary stages=" +
    report.stages.length().to_string() +
    " total_elapsed_ms=" +
    total_elapsed_ms.to_string() +
    " local_asset_count=" +
    report.local_asset_count.val.to_string() +
    " remote_asset_count=" +
    report.remote_asset_count.val.to_string() +
    " unresolved_local_asset_count=" +
    report.unresolved_local_asset_count.val.to_string() +
    " cached_asset_count=" +
    report.cached_asset_count.val.to_string() +
    " asset_discovery_elapsed_ms=" +
    report.asset_discovery_elapsed_ms.val.to_string() +
    " asset_export_elapsed_ms=" +
    report.asset_export_elapsed_ms.val.to_string(),
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
      "html_profile stage=" +
      stage.name +
      " elapsed_ms=" +
      stage.elapsed_ms.to_string() +
      detail,
    )
  }

  lines.join("\n")
}

///|
fn maybe_write_html_profile_log(report : HtmlProfileReport?) -> Unit {
  let path = match @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH") {
    Some(raw) => raw.trim().to_owned()
    None => ""
  }
  if path == "" {
    return
  }

  match report {
    None => ()
    Some(rep) => {
      let body = html_profile_render_report(rep) + "\n"
      @fs.write_string_to_file(path, body, encoding="utf8") catch {
        _ => ()
      }
    }
  }
}
