///|
pub(all) enum DebugOutputKind {
  HumanReadable
  Json
} derive(Eq)

///|
pub(all) struct DebugSection {
  name : String
  kind : String
  available : Bool
  summary : String?
  data_json : String
}

///|
pub(all) struct DebugReport {
  version : String
  source_name : String
  detected_format : String
  command_mode : String
  mut status : String
  mut summary : String
  sections : Array[DebugSection]
  warnings : Array[String]
  errors : Array[String]
}

///|
pub fn new_debug_report(
  source_name : String,
  detected_format : String,
  command_mode : String,
) -> DebugReport {
  {
    version: "1",
    source_name,
    detected_format,
    command_mode,
    status: "ok",
    summary: "",
    sections: [],
    warnings: [],
    errors: [],
  }
}

///|
pub fn debug_report_add_section(
  report : DebugReport,
  section : DebugSection,
) -> Unit {
  report.sections.push(section)
}

///|
pub fn debug_report_add_warning(report : DebugReport, warning : String) -> Unit {
  if warning.trim() != "" {
    report.warnings.push(warning.trim().to_owned())
  }
}

///|
pub fn debug_report_add_error(report : DebugReport, err : String) -> Unit {
  if err.trim() != "" {
    report.errors.push(err.trim().to_owned())
    report.status = "error"
  }
}

///|
pub fn render_debug_report(
  report : DebugReport,
  output_kind : DebugOutputKind,
) -> String {
  match output_kind {
    DebugOutputKind::Json => render_debug_report_json(report)
    DebugOutputKind::HumanReadable => render_debug_report_text(report)
  }
}

///|
fn render_debug_report_text(report : DebugReport) -> String {
  let lines : Array[String] = []
  lines.push("# Debug Report")
  lines.push("")
  lines.push("source_name: " + report.source_name)
  lines.push("detected_format: " + report.detected_format)
  lines.push("command_mode: " + report.command_mode)
  lines.push("status: " + report.status)
  if report.summary.trim() != "" {
    lines.push("summary: " + report.summary)
  }

  if report.warnings.length() > 0 {
    lines.push("")
    lines.push("warnings:")
    for warning in report.warnings {
      lines.push("- " + warning)
    }
  }

  if report.errors.length() > 0 {
    lines.push("")
    lines.push("errors:")
    for err in report.errors {
      lines.push("- " + err)
    }
  }

  for section in report.sections {
    lines.push("")
    lines.push("## " + section.name)
    lines.push("kind: " + section.kind)
    lines.push("available: " + section.available.to_string())
    match section.summary {
      Some(text) =>
        if text.trim() != "" {
          lines.push("summary: " + text.trim().to_owned())
        }
      None => ()
    }
    lines.push("```json")
    lines.push(section.data_json)
    lines.push("```")
  }

  lines.join("\n")
}

///|
fn render_debug_report_json(report : DebugReport) -> String {
  let fields : Array[String] = []
  fields.push("\"version\": " + json_string(report.version))
  fields.push("\"source_name\": " + json_string(report.source_name))
  fields.push("\"detected_format\": " + json_string(report.detected_format))
  fields.push("\"command_mode\": " + json_string(report.command_mode))
  fields.push("\"status\": " + json_string(report.status))
  fields.push("\"summary\": " + json_string(report.summary))
  fields.push("\"sections\": " + render_sections_json(report.sections))
  fields.push("\"warnings\": " + render_string_array_json(report.warnings))
  fields.push("\"errors\": " + render_string_array_json(report.errors))
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
fn render_sections_json(sections : Array[DebugSection]) -> String {
  let parts : Array[String] = []
  for section in sections {
    parts.push(render_section_json(section))
  }
  "[\n" + indent_lines(join_json_items(parts), 4) + "\n  ]"
}

///|
fn render_section_json(section : DebugSection) -> String {
  let fields : Array[String] = []
  fields.push("\"name\": " + json_string(section.name))
  fields.push("\"kind\": " + json_string(section.kind))
  fields.push("\"available\": " + bool_json(section.available))
  fields.push("\"summary\": " + json_string_opt(section.summary))
  fields.push("\"data\": " + section.data_json)
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn debug_section(
  name : String,
  kind : String,
  available : Bool,
  summary : String?,
  data_json : String,
) -> DebugSection {
  { name, kind, available, summary, data_json }
}

///|
pub fn json_string(s : String) -> String {
  "\"" + escape_json_string(s) + "\""
}

///|
pub fn json_string_opt(s : String?) -> String {
  match s {
    Some(v) => json_string(v)
    None => "null"
  }
}

///|
pub fn bool_json(v : Bool) -> String {
  if v {
    "true"
  } else {
    "false"
  }
}

///|
pub fn int_json(v : Int) -> String {
  v.to_string()
}

///|
pub fn uint64_json(v : UInt64) -> String {
  v.to_string()
}

///|
pub fn string_array_json(values : Array[String]) -> String {
  render_string_array_json(values)
}

///|
pub fn string_kv_json(entries : Array[(String, String)]) -> String {
  let fields : Array[String] = []
  for entry in entries {
    let (key, value) = entry
    fields.push(json_string(key) + ": " + json_string(value))
  }
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn string_int_kv_json(entries : Array[(String, Int)]) -> String {
  let fields : Array[String] = []
  for entry in entries {
    let (key, value) = entry
    fields.push(json_string(key) + ": " + value.to_string())
  }
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn string_bool_kv_json(entries : Array[(String, Bool)]) -> String {
  let fields : Array[String] = []
  for entry in entries {
    let (key, value) = entry
    fields.push(json_string(key) + ": " + bool_json(value))
  }
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn string_optional_kv_json(entries : Array[(String, String?)]) -> String {
  let fields : Array[String] = []
  for entry in entries {
    let (key, value) = entry
    fields.push(json_string(key) + ": " + json_string_opt(value))
  }
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn object_json(fields : Array[String]) -> String {
  "{\n" + indent_lines(join_json_fields(fields), 2) + "\n}"
}

///|
pub fn array_json(items : Array[String]) -> String {
  "[\n" + indent_lines(join_json_items(items), 2) + "\n]"
}

///|
fn render_string_array_json(values : Array[String]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(json_string(value))
  }
  "[\n" + indent_lines(join_json_items(items), 2) + "\n]"
}

///|
fn escape_json_string(s : String) -> String {
  let out = StringBuilder::new()
  for ch in s {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn indent_lines(text : String, spaces : Int) -> String {
  let prefix = repeat_space(spaces)
  let lines = text.split("\n")
  let out : Array[String] = []
  for line in lines {
    if line == "" {
      out.push("")
    } else {
      out.push(prefix + line.to_owned())
    }
  }
  out.join("\n")
}

///|
fn repeat_space(n : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<n {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn join_json_fields(fields : Array[String]) -> String {
  fields.join(",\n")
}

///|
fn join_json_items(items : Array[String]) -> String {
  items.join(",\n")
}
