///|
pub(all) enum CapabilityGroup {
  Core
  Office
  Containers
  PdfText
} derive(Eq)

///|
pub extend CapabilityGroup with Eq::{equal, not_equal}

///|
pub struct CapabilityEntry {
  format : @input.DetectedFormat
  group : CapabilityGroup
  cli_supported : Bool
}

///|
fn capability_entry(
  format : @input.DetectedFormat,
  group : CapabilityGroup,
  cli_supported? : Bool = true,
) -> CapabilityEntry {
  { format, group, cli_supported, }
}

///|
fn capability_entries() -> Array[CapabilityEntry] {
  [
    capability_entry(Txt, Core),
    capability_entry(Csv, Core),
    capability_entry(Tsv, Core),
    capability_entry(Srt, Core),
    capability_entry(Vtt, Core),
    capability_entry(Json, Core),
    capability_entry(Jsonl, Core),
    capability_entry(Ndjson, Core),
    capability_entry(Ipynb, Core),
    capability_entry(Xml, Core),
    capability_entry(Yaml, Core),
    capability_entry(Toml, Core),
    capability_entry(Html, Core),
    capability_entry(Markdown, Core),
    capability_entry(Tex, Core),
    capability_entry(Rst, Core),
    capability_entry(Asciidoc, Core),
    capability_entry(Eml, Core),
    capability_entry(Docx, Office),
    capability_entry(Pptx, Office),
    capability_entry(Xlsx, Office),
    capability_entry(Odt, Office),
    capability_entry(Ods, Office),
    capability_entry(Odp, Office),
    capability_entry(Zip, Containers),
    capability_entry(Epub, Containers),
    capability_entry(Pdf, PdfText),
  ]
}

///|
pub fn capability_group_for_format(
  format : @input.DetectedFormat,
) -> CapabilityGroup? {
  for entry in capability_entries() {
    if entry.format == format {
      return Some(entry.group)
    }
  }
  None
}

///|
pub fn cli_supported_for_capability_format(
  format : @input.DetectedFormat,
) -> Bool {
  for entry in capability_entries() {
    if entry.format == format {
      return entry.cli_supported
    }
  }
  false
}

///|
pub fn capability_group_name(group : CapabilityGroup) -> String {
  match group {
    Core => "core"
    Office => "office"
    Containers => "containers"
    PdfText => "pdf_text"
  }
}

///|
pub fn capability_registry_entries() -> Array[CapabilityEntry] {
  capability_entries()
}
