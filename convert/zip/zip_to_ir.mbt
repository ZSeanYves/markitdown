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
    input_path, out_dir, max_heading, parse_full_pdf_entry,
  )
  let local_profile = match profile {
    Some(report) => Some(convert_core_profile_report(report))
    None => None
  }
  (doc, local_profile)
}

///|
async fn parse_full_pdf_entry(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  @pdf.parse_pdf(input_path, out_dir, max_heading, None, false, false, false)
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
