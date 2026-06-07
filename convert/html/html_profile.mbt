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
  parser_issue_count : Ref[Int]
  parser_warning_count : Ref[Int]
  parser_error_count : Ref[Int]
  parser_script_count : Ref[Int]
  parser_style_count : Ref[Int]
  parser_unsafe_url_count : Ref[Int]
  parser_duplicate_attr_count : Ref[Int]
  parser_unexpected_closing_count : Ref[Int]
  parser_unclosed_count : Ref[Int]
  parser_used_fallback : Ref[Bool]
  parser_skipped_large_input : Ref[Bool]
  parser_analysis_attempted : Ref[Bool]
  parser_analysis_used : Ref[Bool]
  parser_scope_from_events : Ref[Bool]
  parser_skip_range_count : Ref[Int]
  parser_scope_fallback_reason : Ref[String]
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
    parser_issue_count: { val: 0 },
    parser_warning_count: { val: 0 },
    parser_error_count: { val: 0 },
    parser_script_count: { val: 0 },
    parser_style_count: { val: 0 },
    parser_unsafe_url_count: { val: 0 },
    parser_duplicate_attr_count: { val: 0 },
    parser_unexpected_closing_count: { val: 0 },
    parser_unclosed_count: { val: 0 },
    parser_used_fallback: { val: false },
    parser_skipped_large_input: { val: false },
    parser_analysis_attempted: { val: false },
    parser_analysis_used: { val: false },
    parser_scope_from_events: { val: false },
    parser_skip_range_count: { val: 0 },
    parser_scope_fallback_reason: { val: "" },
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
fn html_profile_start_tick(report : HtmlProfileReport?) -> UInt64? {
  match report {
    Some(_) => Some(@env.now())
    None => None
  }
}

///|
fn html_active_profile_start_tick() -> UInt64? {
  html_profile_start_tick(html_active_profile_report.val)
}

///|
fn html_profile_elapsed_since(started : UInt64?) -> UInt64 {
  match started {
    Some(tick) => @env.now() - tick
    None => 0
  }
}

///|
fn html_profile_set_parser_issue_summary(
  report : HtmlProfileReport?,
  summary : HtmlParserIssueSummary,
) -> Unit {
  match report {
    Some(rep) => {
      rep.parser_issue_count.val = summary.issue_count
      rep.parser_warning_count.val = summary.warning_count
      rep.parser_error_count.val = summary.error_count
      rep.parser_script_count.val = summary.script_count
      rep.parser_style_count.val = summary.style_count
      rep.parser_unsafe_url_count.val = summary.unsafe_url_count
      rep.parser_duplicate_attr_count.val = summary.duplicate_attribute_count
      rep.parser_unexpected_closing_count.val = summary.unexpected_closing_count
      rep.parser_unclosed_count.val = summary.unclosed_element_count
    }
    None => ()
  }
}

///|
fn html_profile_mark_parser_fallback(report : HtmlProfileReport?) -> Unit {
  match report {
    Some(rep) => rep.parser_used_fallback.val = true
    None => ()
  }
}

///|
fn html_profile_mark_parser_skipped_large_input(
  report : HtmlProfileReport?,
) -> Unit {
  match report {
    Some(rep) => rep.parser_skipped_large_input.val = true
    None => ()
  }
}

///|
fn html_profile_mark_parser_analysis_attempted(
  report : HtmlProfileReport?,
) -> Unit {
  match report {
    Some(rep) => rep.parser_analysis_attempted.val = true
    None => ()
  }
}

///|
fn html_profile_mark_parser_analysis_used(report : HtmlProfileReport?) -> Unit {
  match report {
    Some(rep) => rep.parser_analysis_used.val = true
    None => ()
  }
}

///|
fn html_profile_set_scope_observability(
  report : HtmlProfileReport?,
  scope_from_events : Bool,
  skip_range_count : Int,
  fallback_reason : String,
) -> Unit {
  match report {
    Some(rep) => {
      rep.parser_scope_from_events.val = scope_from_events
      rep.parser_skip_range_count.val = skip_range_count
      rep.parser_scope_fallback_reason.val = fallback_reason
    }
    None => ()
  }
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
    report.asset_export_elapsed_ms.val.to_string() +
    " parser_issue_count=" +
    report.parser_issue_count.val.to_string() +
    " parser_warning_count=" +
    report.parser_warning_count.val.to_string() +
    " parser_error_count=" +
    report.parser_error_count.val.to_string() +
    " parser_script_count=" +
    report.parser_script_count.val.to_string() +
    " parser_style_count=" +
    report.parser_style_count.val.to_string() +
    " parser_unsafe_url_count=" +
    report.parser_unsafe_url_count.val.to_string() +
    " parser_duplicate_attr_count=" +
    report.parser_duplicate_attr_count.val.to_string() +
    " parser_unexpected_closing_count=" +
    report.parser_unexpected_closing_count.val.to_string() +
    " parser_unclosed_count=" +
    report.parser_unclosed_count.val.to_string() +
    " parser_used_fallback=" +
    report.parser_used_fallback.val.to_string() +
    " parser_skipped_large_input=" +
    report.parser_skipped_large_input.val.to_string() +
    " parser_analysis_attempted=" +
    report.parser_analysis_attempted.val.to_string() +
    " parser_analysis_used=" +
    report.parser_analysis_used.val.to_string() +
    " parser_scope_from_events=" +
    report.parser_scope_from_events.val.to_string() +
    " parser_skip_range_count=" +
    report.parser_skip_range_count.val.to_string() +
    " parser_scope_fallback_reason=" +
    report.parser_scope_fallback_reason.val,
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
