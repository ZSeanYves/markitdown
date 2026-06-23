///|
/// One internal timing sample captured during profiled Markdown scanning.
pub(all) struct MarkdownParseProfileStage {
  name : String
  elapsed_ms : UInt64
  detail : String?
}

///|
/// Internal scan-stage report used for benchmark attribution.
pub(all) struct MarkdownParseProfileReport {
  stages : Array[MarkdownParseProfileStage]
}

///|
/// Profiled scan result pairing the normal Markdown document with internal
/// timing breakdown data.
pub(all) struct MarkdownProfiledDocument {
  document : MarkdownDocument
  report : MarkdownParseProfileReport
}

///|
priv struct MarkdownParseProfileTotals {
  fence_scan_elapsed_ms : Ref[UInt64]
  block_classify_elapsed_ms : Ref[UInt64]
  validation_issues_elapsed_ms : Ref[UInt64]
}

///|
fn new_markdown_parse_profile_report() -> MarkdownParseProfileReport {
  { stages: [] }
}

///|
fn new_markdown_parse_profile_totals() -> MarkdownParseProfileTotals {
  {
    fence_scan_elapsed_ms: { val: 0 },
    block_classify_elapsed_ms: { val: 0 },
    validation_issues_elapsed_ms: { val: 0 },
  }
}

///|
fn markdown_parse_profile_push_stage(
  report : MarkdownParseProfileReport?,
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
fn markdown_parse_profile_stage_started(
  report : MarkdownParseProfileReport?,
) -> UInt64 {
  match report {
    Some(_) => @env.now()
    None => 0
  }
}

///|
fn markdown_parse_profile_stage_finished(
  report : MarkdownParseProfileReport?,
  name : String,
  started : UInt64,
  detail : String?,
) -> Unit {
  match report {
    Some(_) =>
      markdown_parse_profile_push_stage(
        report,
        name,
        @env.now() - started,
        detail,
      )
    None => ()
  }
}

///|
fn markdown_parse_profile_add_elapsed(
  total : Ref[UInt64]?,
  started : UInt64,
) -> Unit {
  match total {
    Some(cell) => cell.val = cell.val + (@env.now() - started)
    None => ()
  }
}

///|
fn markdown_parse_profile_finish_totals(
  report : MarkdownParseProfileReport?,
  totals : MarkdownParseProfileTotals?,
) -> Unit {
  match totals {
    Some(values) => {
      markdown_parse_profile_push_stage(
        report,
        "fence_scan",
        values.fence_scan_elapsed_ms.val,
        None,
      )
      markdown_parse_profile_push_stage(
        report,
        "block_classify",
        values.block_classify_elapsed_ms.val,
        None,
      )
      markdown_parse_profile_push_stage(
        report,
        "validation_issues",
        values.validation_issues_elapsed_ms.val,
        None,
      )
    }
    None => ()
  }
}
