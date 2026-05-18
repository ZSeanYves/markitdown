///|
pub(all) enum ZipInspectEntryKind {
  Supported
  NestedArchive
  Unsupported
  Directory
  HiddenMetadata
  UnsafePath
  EntryLimitExceeded
  EntryTooLarge
  TotalDecodedLimitExceeded
} derive(Eq)

///|
pub(all) enum ZipInspectAction {
  Convert
  Skip
  Warn
  Fail
} derive(Eq)

///|
pub struct ZipInspectEntry {
  raw_name : String
  normalized_path : String?
  entry_kind : ZipInspectEntryKind
  action : ZipInspectAction
  compression_method : @zipraw.CompressionMethod
  compressed_size : Int
  uncompressed_size : Int
  flags : Int
  has_data_descriptor : Bool
  is_encrypted : Bool
  uses_zip64 : Bool
  local_header_offset : Int
  crc32 : Int
  dispatch_format : String?
  note : String?
}

///|
pub struct ZipInspectReport {
  source_name : String
  entry_count : Int
  entries : Array[ZipInspectEntry]
}

///|
pub fn inspect_zip(input_path : String) -> ZipInspectReport raise {
  convert_core_inspect_report(@zipcore.inspect_zip(input_path))
}

///|
pub async fn parse_zip(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  parse_zip_with_profile(input_path, out_dir, max_heading).0
}

///|
pub async fn parse_zip_with_profile(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> (@cor.Document, ZipProfileReport?) {
  let (doc, profile) = @zipcore.parse_zip_with_profile(
    input_path, out_dir, max_heading, delegate_pdf_entry,
  )
  let local_profile = match profile {
    Some(report) => Some(convert_core_profile_report(report))
    None => None
  }
  (doc, local_profile)
}

///|
fn convert_core_inspect_entry_kind(
  kind : @zipcore.ZipInspectEntryKind,
) -> ZipInspectEntryKind {
  match kind {
    @zipcore.ZipInspectEntryKind::Supported => ZipInspectEntryKind::Supported
    @zipcore.ZipInspectEntryKind::NestedArchive =>
      ZipInspectEntryKind::NestedArchive
    @zipcore.ZipInspectEntryKind::Unsupported =>
      ZipInspectEntryKind::Unsupported
    @zipcore.ZipInspectEntryKind::Directory => ZipInspectEntryKind::Directory
    @zipcore.ZipInspectEntryKind::HiddenMetadata =>
      ZipInspectEntryKind::HiddenMetadata
    @zipcore.ZipInspectEntryKind::UnsafePath => ZipInspectEntryKind::UnsafePath
    @zipcore.ZipInspectEntryKind::EntryLimitExceeded =>
      ZipInspectEntryKind::EntryLimitExceeded
    @zipcore.ZipInspectEntryKind::EntryTooLarge =>
      ZipInspectEntryKind::EntryTooLarge
    @zipcore.ZipInspectEntryKind::TotalDecodedLimitExceeded =>
      ZipInspectEntryKind::TotalDecodedLimitExceeded
  }
}

///|
fn convert_core_inspect_action(
  action : @zipcore.ZipInspectAction,
) -> ZipInspectAction {
  match action {
    @zipcore.ZipInspectAction::Convert => ZipInspectAction::Convert
    @zipcore.ZipInspectAction::Skip => ZipInspectAction::Skip
    @zipcore.ZipInspectAction::Warn => ZipInspectAction::Warn
    @zipcore.ZipInspectAction::Fail => ZipInspectAction::Fail
  }
}

///|
fn convert_core_inspect_entry(
  entry : @zipcore.ZipInspectEntry,
) -> ZipInspectEntry {
  {
    raw_name: entry.raw_name,
    normalized_path: entry.normalized_path,
    entry_kind: convert_core_inspect_entry_kind(entry.entry_kind),
    action: convert_core_inspect_action(entry.action),
    compression_method: entry.compression_method,
    compressed_size: entry.compressed_size,
    uncompressed_size: entry.uncompressed_size,
    flags: entry.flags,
    has_data_descriptor: entry.has_data_descriptor,
    is_encrypted: entry.is_encrypted,
    uses_zip64: entry.uses_zip64,
    local_header_offset: entry.local_header_offset,
    crc32: entry.crc32,
    dispatch_format: entry.dispatch_format,
    note: entry.note,
  }
}

///|
fn convert_core_inspect_report(
  report : @zipcore.ZipInspectReport,
) -> ZipInspectReport {
  let entries : Array[ZipInspectEntry] = []
  for entry in report.entries {
    entries.push(convert_core_inspect_entry(entry))
  }
  { source_name: report.source_name, entry_count: report.entry_count, entries }
}

///|
fn convert_core_profile_stage(
  stage : @zipcore.ZipProfileStage,
) -> ZipProfileStage {
  { name: stage.name, elapsed_ms: stage.elapsed_ms, detail: stage.detail }
}

///|
fn convert_core_profile_report(
  report : @zipcore.ZipProfileReport,
) -> ZipProfileReport {
  let stages : Array[ZipProfileStage] = []
  for stage in report.stages {
    stages.push(convert_core_profile_stage(stage))
  }
  { input_path: report.input_path, summary_lines: report.summary_lines, stages }
}

///|
async fn delegate_pdf_entry(
  input_path : String,
  out_dir : String,
  _max_heading : Int,
) -> @cor.Document {
  let worker_cli = resolve_worker_cli_path(
    "ZIP PDF entry conversion", "pdf", "MARKITDOWN_PDF_CLI",
  ) catch {
    e => raise @cor.AppError(e.to_string())
  }
  let output_md = out_dir + "/entry.md"
  let args : Array[String] = ["normal", input_path, output_md]
  let delegated = @process.collect_output(worker_cli, args) catch {
    e =>
      raise @cor.AppError(
        "launch pdf failed: " +
        e.to_string() +
        ". Run `moon build pdf --target native` or set MARKITDOWN_PDF_CLI",
      )
  }
  match delegated {
    (0, _stdout, _stderr) => ()
    (code, stdout, stderr) => {
      let stderr_text = stderr.text().trim().to_owned()
      let stdout_text = stdout.text().trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "pdf exited with code " + code.to_string()
      }
      raise @cor.AppError(strip_error_prefix(raw_message))
    }
  }

  let markdown = @fs.read_file_to_string(output_md, encoding="utf8") catch {
    e => raise @cor.AppError("zip pdf delegation read failed: " + e.to_string())
  }
  let doc = @cor.new_document()
  @cor.set_passthrough_markdown(doc, markdown)
  doc
}

///|
fn resolve_worker_cli_path(
  capability_name : String,
  package_name : String,
  env_name : String,
) -> String raise {
  match @sys.get_env_var(env_name) {
    Some(raw) => {
      let override_path = raw.trim().to_owned()
      if override_path == "" {
        raise @cor.AppError(
          env_name +
          " is set but empty; run `moon build " +
          package_name +
          " --target native` or point " +
          env_name +
          " at an executable " +
          package_name +
          " binary",
        )
      } else if @fs.path_exists(override_path) {
        override_path
      } else {
        raise @cor.AppError(
          env_name +
          " points to a missing path: " +
          override_path +
          ". Run `moon build " +
          package_name +
          " --target native` or fix " +
          env_name,
        )
      }
    }
    None => {
      for candidate in worker_cli_candidates(package_name) {
        if candidate != "" && @fs.path_exists(candidate) {
          return candidate
        }
      }
      raise @cor.AppError(
        capability_name +
        " is provided by " +
        package_name +
        "; run `moon build " +
        package_name +
        " --target native` or set " +
        env_name,
      )
    }
  }
}

///|
fn worker_cli_candidates(package_name : String) -> Array[String] {
  let out : Array[String] = []
  add_worker_cli_candidate(out, infer_sibling_worker_path(package_name))
  add_worker_cli_candidate(
    out,
    Some(
      "_build/native/debug/build/" + package_name + "/" + package_name + ".exe",
    ),
  )
  add_worker_cli_candidate(
    out,
    Some(
      "_build/native/release/build/" +
      package_name +
      "/" +
      package_name +
      ".exe",
    ),
  )
  add_worker_cli_candidate(
    out,
    Some("target/native/debug/build/" + package_name + "/" + package_name),
  )
  add_worker_cli_candidate(
    out,
    Some("target/native/release/build/" + package_name + "/" + package_name),
  )
  out
}

///|
fn add_worker_cli_candidate(out : Array[String], path : String?) -> Unit {
  match path {
    Some(candidate) => {
      let normalized = candidate.trim().to_owned()
      if normalized == "" {
        return
      }
      for existing in out {
        if existing == normalized {
          return
        }
      }
      out.push(normalized)
    }
    None => ()
  }
}

///|
fn infer_sibling_worker_path(package_name : String) -> String? {
  let cli_args = @sys.get_cli_args()
  if cli_args.length() == 0 {
    return None
  }

  let argv0 = cli_args[0].trim().to_owned()
  if argv0 == "" || (!argv0.contains("/") && !argv0.contains("\\")) {
    return None
  }

  let current_dir = dirname_of_path(argv0)
  let build_dir = dirname_of_path(current_dir)
  Some(join_path(join_path(build_dir, package_name), package_name + ".exe"))
}

///|
fn join_path(dir : String, file : String) -> String {
  let base = dir.trim().to_owned()
  if base == "" || base == "." {
    file
  } else if base.has_suffix("/") {
    base + file
  } else {
    base + "/" + file
  }
}

///|
fn strip_error_prefix(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix("error: ") {
    trimmed[7:].trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}
